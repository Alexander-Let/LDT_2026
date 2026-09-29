import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/sync_status.dart';
import '../../core/theme.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../providers.dart';
import '../path/path_controller.dart';
import 'attach_flow.dart';

/// Режим для взрослых (ТЗ 2.5.12): код привязки ребёнка, восстановление
/// прогресса по коду и ЛОКАЛЬНАЯ сводка прогресса (без сети и без
/// негативных оценок). Email/OTP и родительская сессия убраны.
class ParentsScreen extends ConsumerWidget {
  const ParentsScreen({super.key});

  /// Восстановление прогресса по коду привязки (сценарий второго
  /// устройства / переустановки). Sheet общий с экраном первого запуска.
  Future<void> _restoreByCode(BuildContext context) async {
    final outcome = await AttachCodeSheet.show(context);
    if (!context.mounted || outcome == null || !outcome.ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(outcome.restored
          ? 'Прогресс восстановлен'
          : 'Профиль привязан, но сохранения на сервере пока нет'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final profile = ref.watch(profileControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Родителям')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Код привязки ребёнка — виден всегда: по нему восстанавливается
          // прогресс на втором устройстве.
          if (profile != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Код привязки ребёнка',
                      style: AppTextStyles.label(color: c.text, size: 18)),
                  const SizedBox(height: 6),
                  if (profile.linkCode.isEmpty)
                    Text(
                      'Появится после подключения к серверу',
                      style: AppTextStyles.body(color: c.textDim, size: 16),
                    )
                  else
                    // Крупно, «монospace»-стиль (дисплейный шрифт + разрядка),
                    // можно выделить и продиктовать.
                    SelectableText(
                      profile.linkCode,
                      style: AppTextStyles.number(color: c.gold, size: 40)
                          .copyWith(letterSpacing: 6),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Введите этот код на втором устройстве, чтобы восстановить прогресс.',
                    style: AppTextStyles.body(color: c.textDim, size: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              text: 'Восстановить прогресс по коду',
              variant: AppButtonVariant.ghost,
              onPressed: () => _restoreByCode(context),
            ),
            const SizedBox(height: 12),
          ],
          // Связь с сервером: статус + ручное подключение (регистрация
          // профиля, если он ещё локальный, и push состояния).
          const _ServerCard(),
          const SizedBox(height: 12),
          // Демо-режим (ТЗ 2.5.13): тестовый профиль, задания и этапы
          // без календарных сроков и ожидания.
          const _DemoCard(),
          const SizedBox(height: 12),
          const _LocalProgressCard(),
          const SizedBox(height: 12),
          // Сброс тестового профиля (Прил. А п.12, ТЗ 3.6) — деструктивно,
          // с подтверждением.
          const _ResetCard(),
        ],
      ),
    );
  }
}

/// Блок «Сервер»: строка статуса (профиль + итог последней синхронизации)
/// и кнопка «Подключиться к серверу» с индикатором прогресса.
class _ServerCard extends ConsumerStatefulWidget {
  const _ServerCard();

  @override
  ConsumerState<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends ConsumerState<_ServerCard> {
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      // reconnect() внутри вызывает ProfileRepository.onServerChanged()
      // (повторная регистрация при pendingRemote / refresh) и обновляет
      // состояние profileControllerProvider — UI увидит свежий linkCode.
      await ref.read(profileControllerProvider.notifier).reconnect();
      await ref.read(gameStateControllerProvider.notifier).syncNow();
      if (!mounted) return;
      final profile = ref.read(profileControllerProvider).valueOrNull;
      final sync = ref.read(syncStatusProvider);
      final ok = sync.status == SyncStatus.online &&
          profile != null &&
          !profile.pendingRemote;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (profile.linkCode.isEmpty
                ? 'Подключено к серверу'
                : 'Подключено к серверу. Код привязки: ${profile.linkCode}')
            : 'Нет связи с сервером: ${sync.error ?? 'попробуйте позже'}'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = ref.watch(profileControllerProvider).valueOrNull;
    final sync = ref.watch(syncStatusProvider);

    final String status;
    if (profile == null) {
      status = 'Профиль ещё не создан';
    } else if (profile.pendingRemote) {
      status = 'Ожидает регистрации на сервере';
    } else if (profile.linkCode.isNotEmpty) {
      status = 'Подключено';
    } else {
      status = 'Не подключено';
    }
    final detail = switch (sync.status) {
      SyncStatus.online => 'Связь с сервером есть',
      SyncStatus.offline => sync.error ?? 'Нет связи с сервером',
      SyncStatus.unknown => 'Связь ещё не проверялась',
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сервер', style: AppTextStyles.label(color: c.text, size: 18)),
          const SizedBox(height: 6),
          Text(status, style: AppTextStyles.body(color: c.text, size: 16)),
          Text(detail, style: AppTextStyles.body(color: c.textDim, size: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Подключиться к серверу',
                  variant: AppButtonVariant.ghost,
                  height: 44,
                  onPressed: _busy ? null : _connect,
                ),
              ),
              if (_busy) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Блок «Демо-режим» (ТЗ 2.5.13): переключатель с подтверждением при
/// включении — в демо задания и этапы доступны подряд, без ожидания.
class _DemoCard extends ConsumerWidget {
  const _DemoCard();

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Включить демо-режим?'),
          content: const Text(
            'В демо все задания сценария и этапы доступны сразу, '
            'без ожидания и календарных сроков.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Включить'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref.read(gameStateControllerProvider.notifier).setDemoMode(enable);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    final demo = game?.demoMode ?? false;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Демо-режим',
                    style: AppTextStyles.label(color: c.text, size: 18)),
                const SizedBox(height: 4),
                Text(
                  'Задания и этапы — без ожидания',
                  style: AppTextStyles.body(color: c.textDim, size: 14),
                ),
              ],
            ),
          ),
          Switch(
            value: demo,
            // Без игрового состояния переключать нечего.
            onChanged:
                game == null ? null : (v) => _toggle(context, ref, v),
          ),
        ],
      ),
    );
  }
}

/// «Сбросить прогресс» (ТЗ 3.6, Прил. А п.12): удаляет профиль, игровое
/// состояние, токены и kv-флаги прогресса, затем ведёт по пути первого
/// запуска (splash → создание питомца).
class _ResetCard extends ConsumerWidget {
  const _ResetCard();

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить все данные и начать заново?'),
        content: const Text(
          'Профиль, питомец, прогресс дорожки и накопления будут удалены '
          'безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Удалить',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // Полный сброс: профиль + состояние + токены (ProfileRepository.reset),
    // затем ВСЕ kv-флаги (обучалка, дорожка, ежедневные награды, съеденная
    // еда) — демо-профиль сбрасывается целиком (ТЗ 2.5.13).
    await ref.read(profileRepositoryProvider).reset();
    final db = ref.read(localDbProvider);
    await db.kvClearAll();

    // Инвалидируем провайдеры, держащие прогресс. gameContentProvider
    // не трогаем — это контент, а не прогресс.
    ref.invalidate(gameStateControllerProvider);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(pathControllerProvider);
    ref.read(syncStatusProvider.notifier).state = SyncState.unknown;

    if (!context.mounted) return;
    // Splash сам решит: профиля нет → экран создания питомца (первый запуск).
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.splash, (_) => false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AppCard(
      color: c.cardDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Опасная зона',
              style: AppTextStyles.label(color: c.red, size: 16)),
          const SizedBox(height: 8),
          AppButton(
            text: 'Сбросить прогресс',
            variant: AppButtonVariant.ghost,
            height: 44,
            onPressed: () => _reset(context, ref),
          ),
        ],
      ),
    );
  }
}

/// «Прогресс ребёнка» — локальная сводка без сети (ТЗ 2.5.12): питомец,
/// этапы дорожки, баланс/копилка и цель. Только факты, без оценок.
class _LocalProgressCard extends ConsumerWidget {
  const _LocalProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    final path = ref.read(pathControllerProvider.notifier);
    final content = ref.watch(gameContentProvider);

    // Обычные этапы дорожки — все, кроме зацикленного «похода» (isGrind).
    final totalStages = stages.where((s) => !s.isGrind).length;
    final goal = content?.goalById(game?.goalId);

    return AppCard(
      color: c.cardDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Прогресс ребёнка',
              style: AppTextStyles.label(color: c.gold, size: 16)),
          const SizedBox(height: 8),
          if (game == null)
            Text('Нет данных', style: AppTextStyles.body(color: c.textDim))
          else ...[
            Text(
              'Питомец: ${game.pet.name.isEmpty ? '—' : game.pet.name}',
              style: AppTextStyles.body(color: c.text, size: 15),
            ),
            Text('Этапы дорожки: ${path.stagesCompleted} из $totalStages',
                style: AppTextStyles.body(color: c.textDim, size: 14)),
            Text(
                'Баланс: ${game.balance} · Копилка: ${game.savings}',
                style: AppTextStyles.body(color: c.textDim, size: 14)),
            Text(
              goal == null
                  ? 'Цель: не выбрана'
                  : 'Цель: ${goal.name} — ${game.goalSaved} из ${goal.cost}',
              style: AppTextStyles.body(color: c.textDim, size: 14),
            ),
            Text('Период: ${game.period}',
                style: AppTextStyles.body(color: c.textDim, size: 14)),
          ],
        ],
      ),
    );
  }
}
