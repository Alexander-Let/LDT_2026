import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pet_growth.dart';
import '../../core/storage/local_db.dart';
import '../../providers.dart';

/// Прогресс «Дорожки знаний» (не часть игрового состояния v2 — храним
/// отдельно в kv). Прогресс хранится ПО ЭТАПАМ — переключение этапа
/// ничего не сбрасывает.
class PathProgress {
  /// Текущий открытый этап: 0..4 — обычные, 5 — лес (поход, бесконечный).
  final int stage;

  /// Пройденные точки каждого этапа.
  final List<int> nodes;

  /// Сколько кругов пройдено в лесу (новые цели покупок + смена картинки).
  final int cycle;

  final DateTime? cooldownUntil;

  /// Учёт ответов на вопросы этапа (характер «Сообразительный»):
  /// correct — решённые с ПЕРВОЙ попытки.
  final int quizCorrect;
  final int quizTotal;

  /// Выборы в лесном походе: копилка / нужное / хотелки
  /// (характер «Заботливый»).
  final int forestSave;
  final int forestNeed;
  final int forestWant;

  /// Копилка на старте этапа — по приросту считается «Бережливый».
  final int stageStartSavings;

  /// Характер игрока ('saver' / 'smart' / 'caring') — бонусы к наградам.
  final String? trait;

  /// Индексы обычных этапов, чья теория уже показана (слайды перед
  /// этапом — path_theory.dart). JSON-ключ 'theory_seen'.
  final Set<int> theorySeen;

  PathProgress({
    this.stage = 0,
    List<int>? nodes,
    this.cycle = 0,
    this.cooldownUntil,
    this.quizCorrect = 0,
    this.quizTotal = 0,
    this.forestSave = 0,
    this.forestNeed = 0,
    this.forestWant = 0,
    this.stageStartSavings = 0,
    this.trait,
    this.theorySeen = const {},
  }) : nodes = nodes ?? List.filled(stages.length, 0);

  int get node => nodes[stage];

  factory PathProgress.fromJson(Map<String, dynamic> json) {
    // --- Миграция сейвов ---
    // Старый формат: 4 этапа (3 обычных + лес с индексом 3). Новый: 6
    // этапов (5 обычных + лес с индексом 5) — добавлены «Откуда деньги?»
    // и «Хитрости и безопасность». Признак старого сейва: список nodes
    // длины 4 или его отсутствие (эпоха формата 'floor').
    final rawNodes = json['nodes'];
    final isLegacy = rawNodes is! List || rawNodes.length == _legacyStageCount;

    /// Индекс этапа из JSON: в старом сейве лес был stage 3 → теперь
    /// последний (5). Обычные этапы 0..2 не меняются.
    int parseStage() {
      var s = ((json['stage'] ?? json['floor']) as num?)?.toInt() ?? 0;
      if (isLegacy && s == _legacyForestIndex) s = stages.length - 1;
      if (s < 0) return 0;
      if (s >= stages.length) return stages.length - 1;
      return s;
    }

    List<int> parseNodes() {
      if (rawNodes is List) {
        final raw = rawNodes.whereType<num>().map((e) => e.toInt()).toList();
        if (isLegacy) {
          // Старый сейв: этапы 0..2 — как были; прогресс леса (был
          // индекс 3) переносим в последний индекс (5); новые обычные
          // этапы 4 и 5 (индексы 3 и 4) дополняем нулями.
          return List.generate(stages.length, (i) {
            if (i < _legacyForestIndex) return i < raw.length ? raw[i] : 0;
            if (i == stages.length - 1) {
              return raw.length > _legacyForestIndex
                  ? raw[_legacyForestIndex]
                  : 0;
            }
            return 0;
          });
        }
        return List.generate(stages.length, (i) => i < raw.length ? raw[i] : 0);
      }
      // Миграция со старого формата (один node на текущий этап).
      final node = (json['node'] as num?)?.toInt() ?? 0;
      final list = List<int>.filled(stages.length, 0);
      list[parseStage()] = node;
      return list;
    }

    return PathProgress(
      stage: parseStage(),
      nodes: parseNodes(),
      cycle: (json['cycle'] as num?)?.toInt() ?? 0,
      cooldownUntil: json['cooldown_until'] == null
          ? null
          : DateTime.tryParse('${json['cooldown_until']}'),
      quizCorrect: (json['quiz_correct'] as num?)?.toInt() ?? 0,
      quizTotal: (json['quiz_total'] as num?)?.toInt() ?? 0,
      forestSave: (json['forest_save'] as num?)?.toInt() ?? 0,
      forestNeed: (json['forest_need'] as num?)?.toInt() ?? 0,
      forestWant: (json['forest_want'] as num?)?.toInt() ?? 0,
      stageStartSavings: (json['stage_start_savings'] as num?)?.toInt() ?? 0,
      trait: json['trait'] as String?,
      theorySeen: (json['theory_seen'] as List?)
              ?.whereType<num>()
              .map((e) => e.toInt())
              .toSet() ??
          const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'nodes': nodes,
        'cycle': cycle,
        'cooldown_until': cooldownUntil?.toIso8601String(),
        'quiz_correct': quizCorrect,
        'quiz_total': quizTotal,
        'forest_save': forestSave,
        'forest_need': forestNeed,
        'forest_want': forestWant,
        'stage_start_savings': stageStartSavings,
        'trait': trait,
        'theory_seen': theorySeen.toList(),
      };

  PathProgress copyWith({
    int? stage,
    List<int>? nodes,
    int? cycle,
    int? quizCorrect,
    int? quizTotal,
    int? forestSave,
    int? forestNeed,
    int? forestWant,
    int? stageStartSavings,
    Set<int>? theorySeen,
    Object? trait = _sentinel,
    Object? cooldownUntil = _sentinel,
  }) =>
      PathProgress(
        stage: stage ?? this.stage,
        nodes: nodes ?? this.nodes,
        cycle: cycle ?? this.cycle,
        quizCorrect: quizCorrect ?? this.quizCorrect,
        quizTotal: quizTotal ?? this.quizTotal,
        forestSave: forestSave ?? this.forestSave,
        forestNeed: forestNeed ?? this.forestNeed,
        forestWant: forestWant ?? this.forestWant,
        stageStartSavings: stageStartSavings ?? this.stageStartSavings,
        theorySeen: theorySeen ?? this.theorySeen,
        trait: identical(trait, _sentinel) ? this.trait : trait as String?,
        cooldownUntil: identical(cooldownUntil, _sentinel)
            ? this.cooldownUntil
            : cooldownUntil as DateTime?,
      );

  PathProgress withNode(int stageIndex, int node) {
    final next = List<int>.of(nodes);
    next[stageIndex] = node;
    return copyWith(nodes: next);
  }
}

const Object _sentinel = Object();

/// Параметры этапов: 5 обычных этапов (бюджет → сбережения → покупки →
/// доходы → безопасность) и ПОСЛЕДНИМ — лес, бесконечный поход
/// с двумя зацикленными локациями (день/вечер).
class PathStageDef {
  final String title;
  final List<String> assets; // фоновые панорамы (у леса — две, чередуются)
  final int nodes;
  final int rewardPerNode;
  final bool isGrind;

  const PathStageDef({
    required this.title,
    required this.assets,
    required this.nodes,
    required this.rewardPerNode,
    this.isGrind = false,
  });
}

const stages = [
  PathStageDef(
    title: 'Этап 1',
    assets: ['assets/bg/fone.png'],
    nodes: 8,
    rewardPerNode: 25,
  ),
  PathStageDef(
    title: 'Этап 2',
    assets: ['assets/bg/aotan2.png'],
    nodes: 8,
    rewardPerNode: 30,
  ),
  PathStageDef(
    title: 'Этап 3',
    assets: ['assets/bg/stage3_space.jpg'],
    nodes: 8,
    rewardPerNode: 35,
  ),
  // Этап 4 — доходы и заработок.
  PathStageDef(
    title: 'Откуда деньги?',
    assets: ['assets/bg/otap3.png'],
    nodes: 8,
    rewardPerNode: 40,
  ),
  // Этап 5 — финансовая безопасность.
  PathStageDef(
    title: 'Хитрости и безопасность',
    assets: ['assets/bg/ada2.png'],
    nodes: 8,
    rewardPerNode: 45,
  ),
  // Лес — всегда ПОСЛЕДНИЙ этап (сейчас индекс 5).
  PathStageDef(
    title: 'Лес (поход)',
    assets: ['assets/bg/forest_fone.png'],
    nodes: 6,
    rewardPerNode: 40,
    isGrind: true,
  ),
];

/// Раскладка СТАРЫХ сейвов: 4 этапа (3 обычных + лес с индексом 3).
/// Используется в PathProgress.fromJson для миграции на 6 этапов.
const _legacyStageCount = 4;
const _legacyForestIndex = 3;

/// Кулдаун между заданиями — только в походе (лес): зверёк «идёт»
/// до следующей точки.
const pathCooldown = Duration(seconds: 30);

/// Тип выбора в лесном походе: копилка / нужное / хотелки.
enum ForestChoice { save, need, want }

/// Характер игрока по итогам этапа. Приоритет: «Бережливый» (копилка
/// выросла на 30+) → «Сообразительный» (≥75% уроков с первого раза) →
/// «Заботливый» (в лесу нужное чаще хотелок). Ничего не подошло — null
/// (старый характер сохраняется).
String? computeTrait({
  required int savedDelta,
  required int quizCorrect,
  required int quizTotal,
  required int forestNeed,
  required int forestWant,
}) {
  if (savedDelta >= 30) return 'saver';
  if (quizTotal > 0 && quizCorrect * 4 >= quizTotal * 3) return 'smart';
  if (forestNeed > forestWant && forestNeed > 0) return 'caring';
  return null;
}

/// Название характера для UI.
String traitTitle(String trait) => switch (trait) {
      'saver' => 'Бережливый',
      'smart' => 'Сообразительный',
      'caring' => 'Заботливый',
      _ => trait,
    };

/// Строка бонуса характера для попапа перехода этапа.
String traitBonusLine(String trait) => switch (trait) {
      'saver' => '+1 монета к каждой награде за урок',
      'smart' => '+5 настроения питомцу за урок',
      'caring' => '+5 сытости питомцу за урок',
      _ => '',
    };

/// Итоги завершённого этапа для попапа перехода: чему научились,
/// статистика решений игрока и характер с бонусом (счётчики — ДО сброса).
class StageTransition {
  /// Индекс и название завершённого этапа.
  final int finishedStage;
  final String finishedTitle;

  /// true — лес завершил круг (а не обычный переход на следующий этап).
  final bool isNewCycle;

  /// Статистика этапа: уроки с первого раза, прирост копилки, выборы в лесу.
  final int quizCorrect;
  final int quizTotal;
  final int savedDelta;
  final int forestSave;
  final int forestNeed;
  final int forestWant;

  /// Характер после этапа (null — пока не заработан).
  final String? trait;

  /// true — характер получен или изменён именно на этом этапе.
  final bool traitIsNew;

  /// Рост питомца: стадия ДО и ПОСЛЕ этапа (null — не считался).
  /// Попап показывает «Финни подрос!», только если growthTo > growthFrom.
  final int? growthFrom;
  final int? growthTo;

  const StageTransition({
    required this.finishedStage,
    required this.finishedTitle,
    required this.isNewCycle,
    required this.quizCorrect,
    required this.quizTotal,
    required this.savedDelta,
    required this.forestSave,
    required this.forestNeed,
    required this.forestWant,
    required this.trait,
    required this.traitIsNew,
    this.growthFrom,
    this.growthTo,
  });
}

class PathController extends AsyncNotifier<PathProgress> {
  static const _kvKey = 'path_progress_v1';

  LocalDb get _db => ref.read(localDbProvider);

  @override
  Future<PathProgress> build() async {
    final raw = await _db.kvGet(_kvKey);
    if (raw == null || raw.isEmpty) return PathProgress();
    try {
      return PathProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PathProgress();
    }
  }

  Future<void> _save(PathProgress next) async {
    state = AsyncData(next);
    await _db.kvSet(_kvKey, jsonEncode(next.toJson()));
  }

  PathProgress get _p => state.valueOrNull ?? PathProgress();
  PathStageDef get currentStage => stages[_p.stage];

  /// Награда за точку с учётом характера: «Бережливый» даёт +1 монету.
  int get nodeReward =>
      currentStage.rewardPerNode + (_p.trait == 'saver' ? 1 : 0);

  /// Актуальная картинка этапа — готовый фон-дизайн (fone / forest_fone).
  String get currentAsset => currentStage.assets.first;

  /// В походе (лесу) между заданиями — кулдаун. На обычных этапах — нет.
  /// В демо-режиме (ТЗ 2.5.13) ожидания нет — этапы идут подряд.
  /// gameStateControllerProvider читаем через ref.read внутри getter,
  /// чтобы не создавать циклическую зависимость провайдеров.
  bool get onCooldown {
    if (!currentStage.isGrind) return false;
    if (ref.read(gameStateControllerProvider).valueOrNull?.demoMode == true) {
      return false;
    }
    final until = _p.cooldownUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  Duration get cooldownRemaining {
    final until = _p.cooldownUntil;
    if (until == null) return Duration.zero;
    final r = until.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  /// Все точки текущего этапа пройдены.
  bool get stageComplete => _p.node >= stages[_p.stage].nodes;

  /// Сколько ОБЫЧНЫХ этапов пройдено (для сюжетных заданий и роста
  /// питомца). Лес (isGrind) не считается; число этапов не зашито.
  int get stagesCompleted {
    var n = 0;
    for (var i = 0; i < stages.length; i++) {
      if (!stages[i].isGrind && _p.nodes[i] >= stages[i].nodes) n++;
    }
    return n;
  }

  /// Учёт ответа на вопрос точки: total растёт всегда, correct — только
  /// при верном ответе с ПЕРВОЙ попытки (характер «Сообразительный»).
  Future<void> recordQuizResult(bool firstTryCorrect) async {
    final p = state.valueOrNull;
    if (p == null) return;
    await _save(p.copyWith(
      quizTotal: p.quizTotal + 1,
      quizCorrect: p.quizCorrect + (firstTryCorrect ? 1 : 0),
    ));
  }

  /// Учёт выбора в походе (вызывает ForestTripScreen): влияет на
  /// характер «Заботливый» (нужное чаще хотелок).
  Future<void> recordForestChoice(ForestChoice kind) async {
    final p = state.valueOrNull;
    if (p == null) return;
    await _save(switch (kind) {
      ForestChoice.save => p.copyWith(forestSave: p.forestSave + 1),
      ForestChoice.need => p.copyWith(forestNeed: p.forestNeed + 1),
      ForestChoice.want => p.copyWith(forestWant: p.forestWant + 1),
    });
  }

  /// Задание пройдено: монеты на баланс + настроение, переход к следующей
  /// точке. В лесу — с кулдауном («зверёк идёт»), на обычных этапах — сразу.
  /// Бонусы характера: «Бережливый» +1 монета (в nodeReward),
  /// «Сообразительный» +5 настроения, «Заботливый» +5 сытости.
  Future<void> completeNode() async {
    if (onCooldown || stageComplete) return;
    final current = _p;
    final stage = stages[current.stage];
    final game = ref.read(gameStateControllerProvider.notifier);
    final reward = nodeReward;
    final mood = current.trait == 'smart' ? 15 : 10;
    final satiety = current.trait == 'caring' ? 5 : 0;
    var coinsLine = 'Дорожка знаний: +$reward монет.';
    var petLine = 'Задание дорожки выполнено — зверёк доволен!';
    if (current.trait == 'saver') {
      coinsLine += ' Характер «Бережливый»: +1 монета.';
    }
    if (current.trait == 'smart') {
      petLine += ' Характер «Сообразительный»: +5 настроения.';
    }
    if (current.trait == 'caring') {
      petLine += ' Характер «Заботливый»: +5 сытости.';
    }
    await game.addCoins(reward, coinsLine);
    await game.addPetStats(mood: mood, satiety: satiety, line: petLine);
    // Демо-режим (ТЗ 2.5.13): в лесу кулдаун не ставим — точка
    // продвигается сразу, как на обычных этапах, без ожидания.
    final demo =
        ref.read(gameStateControllerProvider).valueOrNull?.demoMode == true;
    if (stage.isGrind && !demo) {
      await _save(current.copyWith(
        cooldownUntil: DateTime.now().add(pathCooldown),
      ));
    } else {
      await _save(current.withNode(current.stage, current.node + 1));
    }
  }

  /// Кулдаун в лесу истёк — зверёк дошёл до следующей точки (настроение +).
  Future<void> advance() async {
    final current = _p;
    if (onCooldown) return;
    if (current.cooldownUntil == null) return;
    final stage = stages[current.stage];
    if (current.node + 1 < stage.nodes) {
      await _save(
        current
            .withNode(current.stage, current.node + 1)
            .copyWith(cooldownUntil: null),
      );
      await ref
          .read(gameStateControllerProvider.notifier)
          .addPetStats(mood: 5, line: 'Зверёк дошёл до следующей точки леса.');
    } else {
      await _save(current.copyWith(cooldownUntil: null));
    }
  }

  /// Завершить этап: обычные → следующий этап; лес → круг заново
  /// (новые цели по покупкам + другая картинка леса через cycle).
  /// Возвращает итоги этапа для попапа (null, если этап ещё не пройден).
  /// По итогам считается и сохраняется характер игрока, а счётчики
  /// поведения обнуляются для нового этапа.
  Future<StageTransition?> finishStage() async {
    if (!stageComplete) return null;
    final current = _p;
    final savings =
        ref.read(gameStateControllerProvider).valueOrNull?.savings ?? 0;
    final savedDelta = savings - current.stageStartSavings;
    final newTrait = computeTrait(
      savedDelta: savedDelta,
      quizCorrect: current.quizCorrect,
      quizTotal: current.quizTotal,
      forestNeed: current.forestNeed,
      forestWant: current.forestWant,
    );
    // Рост питомца: стадия ДО и ПОСЛЕ этапа. stagesCompleted уже включает
    // только что пройденный этап (его точки закрыты до вызова), поэтому
    // «до» — на этап меньше. Лес рост не двигает: from == to, и попап
    // блок роста не показывает.
    final completed = stagesCompleted;
    final growthTo = growthStage(completed);
    final growthFrom =
        stages[current.stage].isGrind ? growthTo : growthStage(completed - 1);
    final transition = StageTransition(
      finishedStage: current.stage,
      finishedTitle: stages[current.stage].title,
      isNewCycle: stages[current.stage].isGrind,
      quizCorrect: current.quizCorrect,
      quizTotal: current.quizTotal,
      savedDelta: savedDelta,
      forestSave: current.forestSave,
      forestNeed: current.forestNeed,
      forestWant: current.forestWant,
      trait: newTrait ?? current.trait,
      traitIsNew: newTrait != null && newTrait != current.trait,
      growthFrom: growthFrom,
      growthTo: growthTo,
    );
    // Счётчики — за этап: обнуляем, копилку на старте нового этапа
    // запоминаем, характер сохраняем (null — оставляем старый).
    final reset = current.copyWith(
      quizCorrect: 0,
      quizTotal: 0,
      forestSave: 0,
      forestNeed: 0,
      forestWant: 0,
      stageStartSavings: savings,
      trait: newTrait ?? current.trait,
    );
    if (!stages[current.stage].isGrind && current.stage < stages.length - 1) {
      await _save(reset.copyWith(stage: current.stage + 1));
    } else {
      await _save(PathProgress(
        stage: stages.length - 1,
        nodes: current.nodes,
        cycle: current.cycle + 1,
        stageStartSavings: savings,
        trait: newTrait ?? current.trait,
        // Метки прочитанной теории переносим — круг леса не должен
        // их сбрасывать (счётчики этапа тут обнуляются намеренно).
        theorySeen: current.theorySeen,
      ).withNode(stages.length - 1, 0));
    }
    return transition;
  }

  /// Этап открыт, если все предыдущие обычные этапы пройдены. Лес
  /// открыт всегда, но НЕ открывает задним числом обычные этапы —
  /// проверка идёт по пройденным точкам, а не по индексу текущего.
  bool isStageUnlocked(int s) {
    if (s < 0 || s >= stages.length) return false;
    // Демо-режим (ТЗ 2.5.13): все этапы открыты, чтобы жюри могло
    // зайти на любой урок без прохождения предыдущих.
    if (ref.read(gameStateControllerProvider).valueOrNull?.demoMode == true) {
      return true;
    }
    if (stages[s].isGrind) return true;
    for (var i = 0; i < s; i++) {
      if (_p.nodes[i] < stages[i].nodes) return false;
    }
    return true;
  }

  /// Выбор этапа: обычные — только пройденные/текущий; лес — всегда.
  Future<void> selectStage(int stage) async {
    if (!isStageUnlocked(stage)) return;
    await _save(_p.copyWith(stage: stage));
  }

  /// Теория этапа (слайды перед этапом, path_theory.dart) уже показана?
  bool isTheorySeen(int stageIndex) => _p.theorySeen.contains(stageIndex);

  /// Отметить теорию этапа как показанную. Вызывается при закрытии
  /// диалога теории любым способом; теория показывается один раз на этап.
  Future<void> markTheorySeen(int stageIndex) async {
    final p = state.valueOrNull;
    if (p == null || p.theorySeen.contains(stageIndex)) return;
    await _save(p.copyWith(theorySeen: {...p.theorySeen, stageIndex}));
  }
}

final pathControllerProvider =
    AsyncNotifierProvider<PathController, PathProgress>(PathController.new);

/// Демо-просмотр произвольной точки дорожки (ТЗ 2.5.13): индекс точки,
/// открытой тапом не по текущему прогрессу. null — обычный режим
/// (вопрос текущей точки, прогресс двигается). Ставится в path_screen
/// перед открытием PathTaskScreen, сбрасывается при закрытии задания.
final demoNodeOverrideProvider = StateProvider<int?>((ref) => null);
