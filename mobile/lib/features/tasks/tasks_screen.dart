import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui/app_snackbar.dart';
import '../../providers.dart';
import '../main/main_shell.dart';
import '../path/path_controller.dart';

/// «Задания» — по макету «segee» (iPhone 17 - 4): фиолетовая шапка с
/// артом-картой, тёмная часть со скруглённым верхом, карточки #212736
/// (r12), кнопки r30 («ВЫПОЛНИТЬ» фиолет., «ЗАБРАТЬ НАГРАДУ» зелёная),
/// внизу «1 / 3» + «ПОЛУЧИТЬ НАГРАДУ» (фиолет., во всю ширину).
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  static const _storyTasks = [
    ('Пройти 1 этап «Дороги знаний»', 'Награда: 100 монеточек'),
    ('Пройти 1 уровень «Похода»', 'Награда: 100 монеточек'),
    ('Выполняй активности в течении 3 дней', 'Награда: 100 монеточек'),
  ];

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  /// Сюжетные задания, награда по которым уже забрана (kv `story_claimed_i`).
  final Set<int> _claimed = {};

  @override
  void initState() {
    super.initState();
    _loadClaimed();
  }

  Future<void> _loadClaimed() async {
    final db = ref.read(localDbProvider);
    for (var i = 0; i < TasksScreen._storyTasks.length; i++) {
      if (await db.kvGet('story_claimed_$i') != null && mounted) {
        setState(() => _claimed.add(i));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    final pathNotifier = ref.read(pathControllerProvider.notifier);
    final path = ref.watch(pathControllerProvider).valueOrNull;

    // Сюжетные задания зачитываются автоматически по прогрессу дорожки.
    // Демо-режим (ТЗ 2.5.8): ВСЕ сюжетные задания доступны сразу.
    final demo = game?.demoMode == true;
    final storyDone = [
      demo || pathNotifier.stagesCompleted >= 1, // «Пройти 1 этап Дороги знаний»
      demo || (path?.cycle ?? 0) >= 1, // «Пройти 1 уровень Похода»
      demo, // «3 дня активности» — позже (учёт дней); в демо — сразу
    ];

    final daily = game == null
        ? const <(String, bool)>[]
        : [
            ('Накормить питомца', game.pet.satiety >= 80),
            ('Пополни копилку', game.savings > 0 || game.goalSaved > 0),
            ('Купить предметы в магазине', game.periodPurchases.isNotEmpty),
          ];
    final doneCount = daily.where((t) => t.$2).length;
    final allDone = daily.length == 3 && doneCount == 3;

    return Scaffold(
      backgroundColor: AppColors.figmaBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Фиолетовый прямоугольник-«фон» сверху: при свайпе вниз
              // уезжает вверх, как продолжение серого фона.
              Container(
                height: 200,
                color: AppColors.figmaHeaderPurple,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 230,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Image.asset(
                          'assets/bg/board_tasks.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.centerRight,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Задания',
                          style: AppTextStyles.header(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              // Серый бокс со скруглённым верхом — весь контент.
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.figmaBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сюжетные задания',
                        style: AppTextStyles.header(color: c.text)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < TasksScreen._storyTasks.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StoryCard(
                          index: i,
                          title: TasksScreen._storyTasks[i].$1,
                          reward: TasksScreen._storyTasks[i].$2,
                          done: storyDone[i],
                          claimed: _claimed.contains(i),
                          onClaimed: () => setState(() => _claimed.add(i)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text('Ежедневные задания',
                        style: AppTextStyles.header(color: c.text)),
                    const SizedBox(height: 8),
                    for (final (title, done) in daily)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DailyCard(title: title, done: done),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('$doneCount / ${daily.length}',
                            style: AppTextStyles.label(color: c.text, size: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BigButton(
                            text: 'ПОЛУЧИТЬ НАГРАДУ',
                            color: allDone
                                ? AppColors.figmaHeaderPurple
                                : AppColors.figmaCard,
                            onTap: allDone ? () => _claimDaily(context, ref) : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claimDaily(BuildContext context, WidgetRef ref) async {
    final db = ref.read(localDbProvider);
    final today = _todayKey();
    final claimed = await db.kvGet('daily_reward_$today');
    if (!context.mounted) return;
    if (claimed != null) {
      showAppSnackBar(context, 'Награда за сегодня уже получена');
      return;
    }
    // Вылетают 2 случайные карточки — выбираем одну (макет 117:59).
    final cards = [RewardCard.draw(), RewardCard.draw()];
    final chosen = await Navigator.of(context).push<RewardCard>(
      MaterialPageRoute(builder: (_) => RewardPickScreen(cards: cards)),
    );
    if (chosen == null || !context.mounted) return;
    await chosen.apply(ref);
    await db.kvSet('daily_reward_$today', '1');
    // Настроение — за выполнение ежедневных заданий.
    await ref
        .read(gameStateControllerProvider.notifier)
        .addPetStats(mood: 10, line: 'Ежедневные задания выполнены — отличный день!');
    if (!context.mounted) return;
    showAppSnackBar(context, 'Получено: ${chosen.description}');
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}

/// Карточка сюжетного задания: невыполненная — фиолетовая «ВЫПОЛНИТЬ»
/// (переход на Дорожку), выполненная — зелёная «ЗАБРАТЬ НАГРАДУ»,
/// награда забрана — зелёный контур карточки и серая кнопка «ВЫПОЛНЕНО».
class _StoryCard extends ConsumerWidget {
  final int index;
  final String title;
  final String reward;
  final bool done;
  final bool claimed;
  final VoidCallback onClaimed;

  const _StoryCard({
    required this.index,
    required this.title,
    required this.reward,
    required this.done,
    required this.claimed,
    required this.onClaimed,
  });

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final db = ref.read(localDbProvider);
    final key = 'story_claimed_$index';
    if (await db.kvGet(key) != null) {
      if (context.mounted) {
        showAppSnackBar(context, 'Награда уже получена');
      }
      return;
    }
    await ref
        .read(gameStateControllerProvider.notifier)
        .addCoins(100, 'Сюжетное задание «$title»: +100 монет.');
    await ref
        .read(gameStateControllerProvider.notifier)
        .addPetStats(mood: 10, line: 'Сюжетное задание выполнено — настроение выросло!');
    await db.kvSet(key, '1');
    onClaimed();
    if (!context.mounted) return;
    showAppSnackBar(context, '+100 монеточек!');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.figmaTaskCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: claimed ? AppColors.figmaNavGreen : AppColors.figmaCard,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body(
                        color: done ? c.text : AppColors.figmaTextMuted,
                        size: 16,
                        weight: FontWeight.w700)),
                Text(reward,
                    style: AppTextStyles.body(color: AppColors.figmaTextDimmer, size: 13)),
              ],
            ),
          ),
          if (claimed)
            _SmallPill(
              text: 'Выполнено',
              color: AppColors.figmaCard,
              onTap: () {},
            )
          else
            _SmallPill(
              text: done ? 'Забрать награду' : 'Выполнить',
              color: done ? AppColors.figmaBtnGreen : AppColors.figmaHeaderPurple,
              onTap: done
                  ? () => _claim(context, ref)
                  : () => ref.read(mainTabProvider.notifier).state = 2,
            ),
        ],
      ),
    );
  }
}

/// Карточка ежедневного задания.
class _DailyCard extends StatelessWidget {
  final String title;
  final bool done;

  const _DailyCard({required this.title, required this.done});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.figmaTaskCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? AppColors.figmaNavGreen : AppColors.figmaCard,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_box : Icons.check_box_outline_blank,
            color: done ? c.green : c.textDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: AppTextStyles.body(
                    color: done ? c.textDim : c.text, size: 16)),
          ),
        ],
      ),
    );
  }
}

/// Круглая кнопка-пилюля r30 (Impact 20).
class _SmallPill extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _SmallPill({required this.text, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(text.toUpperCase(),
            style: AppTextStyles.label(color: Colors.white, size: 14)),
      ),
    );
  }
}

/// Большая кнопка во всю ширину (r12).
class _BigButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _BigButton({required this.text, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(text, style: AppTextStyles.label(color: Colors.white, size: 16)),
        ),
      ),
    );
  }
}

// ---------- Карточки наград ----------

enum CardType { food, money, event, goal }

class RewardCard {
  final CardType type;
  final int quality; // 0 обычная, 1 редкая, 2 эпическая

  const RewardCard(this.type, this.quality);

  static RewardCard draw() {
    final r = Random();
    final roll = r.nextInt(100);
    final quality = roll < 60 ? 0 : roll < 90 ? 1 : 2;
    return RewardCard(CardType.values[r.nextInt(CardType.values.length)], quality);
  }

  String get typeLabel => switch (type) {
        CardType.food => 'Еда',
        CardType.money => 'Деньги',
        CardType.event => 'Ивент',
        CardType.goal => 'Цель',
      };

  String get qualityLabel => switch (quality) {
        0 => 'Обычная',
        1 => 'Редкая',
        _ => 'Эпическая',
      };

  /// Обложка карты из Figma «segee» (Frame 2–5).
  String get backAsset => switch (type) {
        CardType.food => 'assets/bg/card_green.png',
        CardType.money => 'assets/bg/card_purple.png',
        CardType.event => 'assets/bg/card_blue.png',
        CardType.goal => 'assets/bg/card_brown.png',
      };

  String get description => switch (type) {
        CardType.food => ['+20 к сытости', '+35 к сытости', '+50 к сытости'][quality],
        CardType.money => ['+40 монет', '+70 монет', '+100 монет'][quality],
        CardType.event => ['+15 к настроению (ивент)', '+25 к настроению (ивент)', '+35 к настроению (ивент)'][quality],
        CardType.goal => ['+50 к цели', '+100 к цели', '+150 к цели'][quality],
      };

  Future<void> apply(WidgetRef ref) async {
    final controller = ref.read(gameStateControllerProvider.notifier);
    final q = quality;
    switch (type) {
      case CardType.food:
        await controller.addPetStats(
            satiety: [20, 35, 50][q], line: 'Карточка «Еда» ($qualityLabel): вкусно!');
      case CardType.money:
        await controller.addCoins([40, 70, 100][q], 'Карточка «Деньги» ($qualityLabel).');
      case CardType.event:
        await controller.addPetStats(
            mood: [15, 25, 35][q], line: 'Карточка «Ивент» ($qualityLabel): приключение!');
      case CardType.goal:
        await controller.addGoalProgress(
            [50, 100, 150][q], 'Карточка «Цель» ($qualityLabel).');
    }
  }
}

/// Окно выбора награды по макету 117:59: тёмный экран, ✕, заголовок
/// «ВЫБИРИ НАГРАДУ за выполненные ежедневные задания», две карточки
/// рядом (обложки из Figma), между ними «ИЛИ», под каждой «ВЫБРАТЬ».
class RewardPickScreen extends StatelessWidget {
  final List<RewardCard> cards;

  const RewardPickScreen({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.figmaBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ВЫБИРИ НАГРАДУ\nза выполненные\nежедневные задания',
                textAlign: TextAlign.center,
                style: AppTextStyles.header(color: Colors.white),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _PickCard(card: cards[0])),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('ИЛИ',
                            style: AppTextStyles.label(color: Colors.white, size: 20)),
                      ),
                    ),
                    Expanded(child: _PickCard(card: cards[1])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PickButton(
                      onTap: () => Navigator.of(context).pop(cards[0]),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: _PickButton(
                      onTap: () => Navigator.of(context).pop(cards[1]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка награды: обложка из Figma на весь размер, сверху — эмодзи,
/// вид, качество и описание.
class _PickCard extends StatelessWidget {
  final RewardCard card;

  const _PickCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            card.backAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF3D502A)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  size: const Size(44, 44),
                  painter: _CardTypeIconPainter(type: card.type),
                ),
                const SizedBox(height: 8),
                Text(card.typeLabel,
                    style: AppTextStyles.label(color: Colors.white, size: 18)),
                Text(card.qualityLabel,
                    style: AppTextStyles.body(color: Colors.white70, size: 12)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    card.description,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                        color: Colors.white, size: 13, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка «ВЫБРАТЬ» (#383838, r30).
class _PickButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PickButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.figmaChip,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text('ВЫБРАТЬ',
              style: AppTextStyles.label(color: Colors.white, size: 18)),
        ),
      ),
    );
  }
}

/// Векторные иконки типов наград (вместо эмодзи): еда — бургер, деньги —
/// монета, ивент — кубик, цель — мишень.
class _CardTypeIconPainter extends CustomPainter {
  final CardType type;

  const _CardTypeIconPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = Colors.white;
    switch (type) {
      case CardType.food:
        // Булочка.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.76, h * 0.26),
              Radius.circular(w * 0.14)),
          paint,
        );
        // Котлета.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.10, h * 0.46, w * 0.80, h * 0.16),
              Radius.circular(w * 0.06)),
          paint,
        );
        // Нижняя булочка.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.14, h * 0.66, w * 0.72, h * 0.18),
              Radius.circular(w * 0.05)),
          paint,
        );
      case CardType.money:
        // Монета: круг + внутренний ободок.
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44,
            paint..style = PaintingStyle.fill);
        canvas.drawCircle(
            Offset(w / 2, h / 2),
            w * 0.30,
            Paint()
              ..color = const Color(0xFF634ABF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.06);
      case CardType.event:
        // Кубик.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.76, h * 0.76),
              Radius.circular(w * 0.14)),
          paint,
        );
        final dot = Paint()..color = const Color(0xFF634ABF);
        canvas.drawCircle(Offset(w * 0.34, h * 0.34), w * 0.06, dot);
        canvas.drawCircle(Offset(w * 0.66, h * 0.34), w * 0.06, dot);
        canvas.drawCircle(Offset(w * 0.34, h * 0.66), w * 0.06, dot);
        canvas.drawCircle(Offset(w * 0.66, h * 0.66), w * 0.06, dot);
      case CardType.goal:
        // Мишень: три концентрических круга.
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, paint);
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44,
            Paint()..color = Colors.white);
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.28,
            Paint()..color = const Color(0xFF634ABF));
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.14, paint..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _CardTypeIconPainter oldDelegate) =>
      oldDelegate.type != type;
}
