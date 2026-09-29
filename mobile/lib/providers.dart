import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/network/api_exception.dart';
import 'core/storage/local_db.dart';
import 'core/sync_status.dart';
import 'data/api/backend_api.dart';
import 'data/engine/game_engine.dart' as engine;
import 'data/engine/phase_flow.dart' as flow;
import 'data/models/content_bundle.dart';
import 'data/models/game_state.dart';
import 'data/models/pending_bonus.dart';
import 'data/models/profile.dart';
import 'data/repositories/content_repository.dart';
import 'data/repositories/game_state_repository.dart';
import 'data/repositories/profile_repository.dart';

// ---------- infrastructure ----------

final localDbProvider = Provider<LocalDb>(
  (ref) => throw UnimplementedError('localDbProvider must be overridden in main()'),
);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi(ref.watch(apiClientProvider)));

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    db: ref.watch(localDbProvider),
    apiClient: ref.watch(apiClientProvider),
    api: ref.watch(backendApiProvider),
  ),
);

final gameStateRepositoryProvider = Provider<GameStateRepository>(
  (ref) => GameStateRepository(
    db: ref.watch(localDbProvider),
    api: ref.watch(backendApiProvider),
    profiles: ref.watch(profileRepositoryProvider),
  ),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(
    db: ref.watch(localDbProvider),
    api: ref.watch(backendApiProvider),
  ),
);

/// Результат последней попытки синхронизации/healthz — индикатор онлайна
/// с текстом ошибки для диагностики.
final syncStatusProvider = StateProvider<SyncState>((ref) => SyncState.unknown);

// ---------- content ----------

final contentBundleProvider = FutureProvider<ContentBundle>(
  (ref) => ref.watch(contentRepositoryProvider).load(),
);

/// Распарсенный игровой контент (null пока грузится).
final gameContentProvider = Provider<GameContent?>(
  (ref) => ref.watch(contentBundleProvider).valueOrNull?.payload,
);

final backendHealthProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(backendApiProvider).healthz();
  } catch (_) {
    return false;
  }
});

// ---------- profile ----------

class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final repo = ref.watch(profileRepositoryProvider);
    final profile = await repo.loadLocal();
    if (profile != null) {
      unawaited(_postBootstrap(profile));
    }
    return profile;
  }

  Future<void> _postBootstrap(Profile profile) async {
    final repo = ref.read(profileRepositoryProvider);
    try {
      final refreshed = await repo.refreshFromServer(profile);
      if (refreshed != null) {
        state = AsyncData(refreshed);
      }
      // Локального состояния нет (переустановка) — пробуем забрать с сервера.
      if (await ref.read(gameStateRepositoryProvider).loadLocal() == null) {
        final server = await ref.read(backendApiProvider).getMyState();
        if (server.state.isNotEmpty) {
          await ref
              .read(gameStateRepositoryProvider)
              .savePulled(GameState.fromJson(server.state), server.stateVersion);
          ref.invalidate(gameStateControllerProvider);
        }
      }
      ref.read(syncStatusProvider.notifier).state = SyncState.online;
    } on ApiException catch (e) {
      ref.read(syncStatusProvider.notifier).state =
          SyncState(SyncStatus.offline, e.fullText);
    } catch (_) {
      ref.read(syncStatusProvider.notifier).state =
          const SyncState(SyncStatus.offline, 'Неизвестная ошибка синхронизации');
    }
  }

  Future<void> createProfile(String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).createProfile(displayName),
    );
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final refreshed = await ref.read(profileRepositoryProvider).refreshFromServer(current);
    if (refreshed != null) state = AsyncData(refreshed);
  }

  /// После смены адреса сервера: регистрируем/обновляем профиль на новом
  /// сервере и обновляем своё состояние.
  Future<void> reconnect() async {
    final updated = await ref.read(profileRepositoryProvider).onServerChanged();
    if (updated != null) state = AsyncData(updated);
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);

// ---------- game state / engine ----------

class GameStateController extends AsyncNotifier<GameState> {
  /// Съеденные виды еды (kv) — настроение даётся за первый вид каждого.
  static const _foodEatenKey = 'food_eaten_v1';

  @override
  Future<GameState> build() async {
    final local = await ref.watch(gameStateRepositoryProvider).loadLocal();
    var state = local ?? GameState.empty();
    // Затухание показателей: сытость −3 и настроение −2 каждые 5 минут
    // реального времени (питомец не живёт вечно).
    final now = DateTime.now();
    final last = DateTime.tryParse(state.lastStatsAt ?? '');
    if (last != null) {
      final ticks = now.difference(last).inMinutes ~/ 5;
      if (ticks > 0) {
        state = state.copyWith(
          pet: state.pet.copyWith(
            satiety: clampStat(state.pet.satiety - 3 * ticks),
            mood: clampStat(state.pet.mood - 2 * ticks),
          ),
          lastStatsAt: now.toIso8601String(),
        );
        await ref.read(gameStateRepositoryProvider).saveLocal(state);
      }
    }
    // Автоподключение к серверу при старте: если профиль ещё локальный
    // (pendingRemote), sync() сам зарегистрирует его на сервере и запушит
    // состояние; при пустом профиле sync безвредно вернёт offline.
    unawaited(_syncInBackground());
    return state;
  }

  GameContent? get _content => ref.read(gameContentProvider);

  Future<void> _persist(GameState next) async {
    // Гарантия: шкалы питомца всегда в пределах 0..100.
    next = next.copyWith(
      lastStatsAt: DateTime.now().toIso8601String(),
      pet: next.pet.copyWith(
        satiety: clampStat(next.pet.satiety),
        mood: clampStat(next.pet.mood),
        intellect: clampStat(next.pet.intellect),
        cleanliness: clampStat(next.pet.cleanliness),
        health: clampStat(next.pet.health),
        comfort: clampStat(next.pet.comfort),
      ),
    );
    state = AsyncData(next);
    final repo = ref.read(gameStateRepositoryProvider);
    await repo.saveLocal(next);
    unawaited(_syncInBackground());
  }

  Future<void> _syncInBackground() async {
    final syncState = await ref.read(gameStateRepositoryProvider).sync();
    ref.read(syncStatusProvider.notifier).state = syncState;
  }

  Future<void> syncNow() => _syncInBackground();

  // ----- питомец -----
  Future<void> createPet({
    required String petName,
    required String fur,
    required String ears,
    String? character,
    String? skin,
  }) =>
      _persist(GameState.withPet(
        petName: petName,
        fur: fur,
        ears: ears,
        character: character,
        skin: skin,
      ));

  // ----- фазы -----
  Future<void> completePhase() async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) return;
    await _persist(flow.advancePhase(current, content));
  }

  /// Демо-режим: прыжок к итогам периода.
  Future<void> skipToResults() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _persist(flow.jumpToResults(current));
  }

  Future<int> accrueSalaryAndContinue() async {
    final content = _content;
    var current = state.valueOrNull;
    if (content == null || current == null) return 0;
    final result = engine.accrueSalary(current, content);
    current = result.state;
    await _persist(flow.advancePhase(current, content));
    return result.amount;
  }

  Future<int> accruePassiveAndContinue() async {
    final content = _content;
    var current = state.valueOrNull;
    if (content == null || current == null) return 0;
    final result = engine.accruePassiveIncome(current, content);
    current = result.state;
    await _persist(flow.advancePhase(current, content));
    return result.total;
  }

  // ----- профессия -----
  Future<void> chooseProfession(String professionId) async {
    final content = _content;
    final current = state.valueOrNull;
    final profession = content?.professionById(professionId);
    if (content == null || current == null || profession == null) return;
    await _persist(engine.chooseProfession(current, profession, content));
  }

  // ----- планирование -----
  Future<engine.PlanResult> applyPlan(BasketValues plan) async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) {
      return engine.PlanResult(
        state: current ?? GameState.empty(),
        blocked: true,
        blockLine: 'Контент ещё загружается',
        reward: 0,
        rewardLine: '',
      );
    }
    final result = engine.applyPlan(current, plan, content);
    if (!result.blocked) await _persist(result.state);
    return result;
  }

  // ----- магазин -----
  Future<engine.PurchaseResult> buyItem(ShopItem item) async {
    final content = _content;
    var current = state.valueOrNull;
    if (content == null || current == null) {
      return engine.PurchaseResult(
        state: current ?? GameState.empty(),
        pricePaid: 0,
        feedbackLine: 'Контент ещё загружается',
        error: 'Контент ещё загружается',
      );
    }
    // «Сравнение товаров перед покупкой» — очки Исследователю (первый раз за период).
    current = engine.noteItemCompared(current);
    final result = engine.purchaseItem(current, item, content);
    if (result.success) {
      await _persist(result.state);
      // Настроение поднимается и за первую съеденную еду каждого вида.
      if (item.category == 'Питание') {
        final db = ref.read(localDbProvider);
        final raw = await db.kvGet(_foodEatenKey);
        final eaten = raw == null
            ? <String>{}
            : (jsonDecode(raw) as List).map((e) => '$e').toSet();
        if (eaten.add(item.id)) {
          await db.kvSet(_foodEatenKey, jsonEncode(eaten.toList()));
          await addPetStats(mood: 10, line: 'Попробовал новую еду — вкусно!');
        }
      }
    }
    return result;
  }

  bool shouldTriggerC2(ShopItem item) {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) return false;
    return engine.shouldTriggerC2(current, item, content);
  }

  Future<void> resolveShopC2() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _persist(engine.resolveShopC2(current));
  }

  // ----- копилка -----
  Future<engine.DepositResult> deposit(int amount) async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) {
      return engine.DepositResult(
        state: current ?? GameState.empty(),
        deposited: 0,
        reactionLine: '',
        error: 'Контент ещё загружается',
      );
    }
    final result = engine.deposit(current, amount, content);
    if (result.error == null) await _persist(result.state);
    return result;
  }

  Future<String?> withdraw(int amount) async {
    final current = state.valueOrNull;
    if (current == null) return 'Нет данных';
    final result = engine.withdraw(current, amount);
    if (result.error == null) await _persist(result.state);
    return result.error;
  }

  Future<void> declineWithdraw() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _persist(engine.declineWithdraw(current));
  }

  Future<void> selectGoal(String? goalId) async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) return;
    await _persist(engine.selectGoal(current, content.goalById(goalId), content));
  }

  // ----- Хитрик / события -----
  Future<void> resolveHitrik(HitrikScene scene, SceneOption option) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _persist(engine.resolveHitrik(current, scene, option));
  }

  Future<engine.EventResolution> resolveEvent(GameEvent event, SceneOption option) async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) {
      return engine.EventResolution(
        state: current ?? GameState.empty(),
        outcomeText: '',
        coinsDelta: 0,
      );
    }
    final result = engine.resolveEvent(current, event, option, content);
    await _persist(result.state);
    return result;
  }

  // ----- задания -----
  Future<void> completeTaskReward(String code, int reward, String line) async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) return;
    await _persist(engine.completeTaskReward(current, code, reward, line, content));
  }

  // ----- итоги периода -----
  Future<engine.ResultsData> computeResults() async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) {
      // Заглушка до загрузки контента (экран итогов ждёт данные).
      return engine.computeResults(current ?? GameState.empty(), content ?? _fallbackContent());
    }
    return engine.computeResults(current, content);
  }

  /// Применить итоги и перейти к анонсу/финалу.
  Future<engine.ResultsData> applyResultsAndContinue() async {
    final content = _content;
    var current = state.valueOrNull;
    if (content == null || current == null) {
      return computeResults();
    }
    final data = engine.computeResults(current, content);
    current = engine.applyResults(current, content, data);
    await _persist(flow.advancePhase(current, content));
    return data;
  }

  /// Анонс показан — начинаем следующий период.
  Future<void> announceDone() async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) return;
    await _persist(flow.advancePhase(current, content));
  }

  // ----- откат -----
  Future<void> useRollback() async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) return;
    await _persist(engine.useRollback(current, content));
  }

  // ----- демо-режим -----
  Future<void> setDemoMode(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _persist(current.copyWith(demoMode: enabled).addHistory(
          enabled ? 'Демо-режим включён.' : 'Демо-режим выключен.',
        ));
  }

  // ----- бонусы родителя -----
  /// Неприменённые бонусы с сервера: начисляем на баланс и помечаем applied.
  /// Возвращает число применённых бонусов.
  Future<int> applyParentBonuses() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasPet()) return 0;
    final List<PendingBonus> bonuses;
    try {
      bonuses = await ref.read(backendApiProvider).listMyBonuses();
    } catch (_) {
      return 0;
    }
    var next = current;
    var appliedCount = 0;
    for (final bonus in bonuses) {
      if (next.appliedBonuses.contains(bonus.id)) continue;
      next = next.copyWith(
        balance: next.balance + bonus.amount,
        appliedBonuses: [...next.appliedBonuses, bonus.id],
      ).addHistory('Бонус от родителя: ${bonus.reason} (+${bonus.amount}).');
      try {
        await ref.read(backendApiProvider).applyBonus(bonus.id);
        appliedCount++;
      } catch (_) {
        // Сервер не подтвердил — оставим начисление локальным, повторим позже.
      }
    }
    if (appliedCount > 0) {
      await _persist(next);
    }
    return appliedCount;
  }

  /// Локальный бонус родителя (без привязки к серверу): та же механика
  /// показа ребёнку — сразу на баланс с записью в историю.
  Future<String?> grantLocalParentBonus(int amount, String reason) async {
    final content = _content;
    final current = state.valueOrNull;
    if (content == null || current == null) return 'Контент ещё загружается';
    final error = engine.validateParentBonus(amount, content);
    if (error != null) return error;
    await _persist(
      current
          .copyWith(balance: current.balance + amount)
          .addHistory('Родитель начислил $amount монет за $reason.'),
    );
    return null;
  }

  // ----- прогресс -----
  Future<void> markGlossarySeen(String termId) async {
    final current = state.valueOrNull;
    if (current == null || current.glossarySeen.contains(termId)) return;
    await _persist(
      current.copyWith(glossarySeen: [...current.glossarySeen, termId]),
    );
  }

  // ----- награды нового UI (карточки, дорожка знаний) -----
  /// Начислить монеты на баланс с записью в историю.
  Future<void> addCoins(int amount, String line) async {
    final current = state.valueOrNull;
    if (current == null || amount <= 0) return;
    await _persist(
      current.copyWith(balance: current.balance + amount).addHistory(line),
    );
  }

  /// Трата монет вне магазина (выбор в лесу). Отрицательный баланс
  /// запрещён: при нехватке возвращает false и ничего не меняет.
  Future<bool> spendCoins(int amount, String line) async {
    final current = state.valueOrNull;
    if (current == null || amount <= 0 || current.balance < amount) {
      return false;
    }
    await _persist(
      current.copyWith(balance: current.balance - amount).addHistory(line),
    );
    return true;
  }

  /// Изменить показатели питомца (еда/настроение из карточек наград).
  Future<void> addPetStats({
    int satiety = 0,
    int mood = 0,
    int intellect = 0,
    required String line,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _persist(
      current
          .copyWith(
            pet: current.pet.copyWith(
              satiety: clampStat(current.pet.satiety + satiety),
              mood: clampStat(current.pet.mood + mood),
              intellect: clampStat(current.pet.intellect + intellect),
            ),
          )
          .addHistory(line),
    );
  }

  /// Пополнить прогресс цели (карточка «цели»).
  Future<void> addGoalProgress(int amount, String line) async {
    final current = state.valueOrNull;
    if (current == null || current.goalId == null || amount <= 0) return;
    await _persist(
      current.copyWith(goalSaved: current.goalSaved + amount).addHistory(line),
    );
  }

  // ----- сброс -----
  Future<void> reset() async {
    await ref.read(gameStateRepositoryProvider).clearLocal();
    state = AsyncData(GameState.empty());
  }
}

/// Контент-заглушка для computeResults до загрузки бандла (не используется
/// в реальном flow — экраны ждут gameContentProvider).
GameContent _fallbackContent() => GameContent.fromJson(const {
      'schema': 2,
      'economy': {
        'mandatory_expenses': {'total_per_period': 60, 'items': []},
        'dev_score': {
          'max_per_period': 50,
          'rules': [],
          'stages': [
            {'id': 'baby', 'name': 'Малыш', 'score_min': 0, 'min_period': 1},
          ],
        },
      },
      'periods': [
        {'number': 1, 'title': '', 'features': {}},
      ],
    });

final gameStateControllerProvider =
    AsyncNotifierProvider<GameStateController, GameState>(GameStateController.new);
