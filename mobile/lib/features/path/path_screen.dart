import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/pet_growth.dart';
import '../../core/theme.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../data/models/game_state.dart';
import '../../providers.dart';
import 'forest_trip_screen.dart';
import 'path_controller.dart';
import 'path_theory.dart';

/// «Дорожка знаний» в духе Duolingo: панорама этапа — длинная картинка,
/// которую можно двигать влево-вправо; по мере прохождения заданий
/// картинка сама сдвигается к текущей точке. 5 обычных этапов + лес:
/// задание леса — поход в магазин (ForestTripScreen). Первой точкой
/// обычного этапа идёт теория (кружок «Т» со слайдами path_theory.dart):
/// пока теория не прочитана, точки викторин заблокированы.
class PathScreen extends ConsumerStatefulWidget {
  const PathScreen({super.key});

  @override
  ConsumerState<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends ConsumerState<PathScreen> {
  Timer? _ticker;
  final _scroll = ScrollController();

  /// Последний момент, когда пользователь САМ трогал панораму.
  /// Автоподъезд к текущей точке — только после 20 с бездействия
  /// (либо при смене этапа / завершении кулдауна).
  DateTime _lastUserScroll = DateTime.now().subtract(
    const Duration(seconds: 30),
  );

  /// Этап, к которому панорама уже подъезжала (чтобы при смене чипа
  /// подъезжать сразу, а не ждать 20 с).
  int? _seenStage;

  /// Точка (этап:номер), к которой панорама уже подъезжала. Смена точки
  /// = задание выполнено → подъезжаем СРАЗУ, не дожидаясь 20-секундного
  /// «кулдауна» свободного скролла.
  String? _seenNodeKey;

  /// Ширина одной точки пути (панорама считается от неё).
  static const double nodeWidth = 140.0;

  /// Цвет линии пути по этапам: синий, зелёный, жёлтый, оранжевый,
  /// голубой, в лесу — фиолетовый.
  static const _lineColors = [
    Color(0xFF5B8DEF),
    Color(0xFF7ED957),
    Color(0xFFF4B52D),
    Color(0xFFFF8A5C),
    Color(0xFF4FC3F7),
    Color(0xFFB678E0),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _tick() {
    final notifier = ref.read(pathControllerProvider.notifier);
    // Кулдаун закончился — зверёк дошёл до следующей точки.
    final p = ref.read(pathControllerProvider).valueOrNull;
    var advanced = false;
    if (p != null &&
        p.cooldownUntil != null &&
        notifier.cooldownRemaining == Duration.zero) {
      notifier.advance();
      advanced = true;
    }
    if (mounted && notifier.onCooldown) setState(() {});
    // Панорама свободная: возвращаем к текущей точке только после
    // 20 секунд бездействия или если кулдаун только что закончился.
    final idle =
        DateTime.now().difference(_lastUserScroll) >
        const Duration(seconds: 20);
    if (advanced || idle) _scrollToCurrent();
  }

  void _scrollToCurrent() {
    final p = ref.read(pathControllerProvider).valueOrNull;
    if (p == null || !_scroll.hasClients) return;
    // У обычных этапов первой точкой идёт теория («Т»), поэтому точка
    // викторины с номером node стоит на позиции node + 1. В лесу точки
    // «Т» нет — позиция совпадает с номером.
    final pos = stages[p.stage].isGrind ? p.node : p.node + 1;
    final target = (pos * nodeWidth - 80).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if ((_scroll.offset - target).abs() < 8) return;
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = ref.watch(pathControllerProvider).valueOrNull;
    final game = ref.watch(gameStateControllerProvider).valueOrNull;

    if (progress == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final stage = stages[progress.stage];
    final notifier = ref.read(pathControllerProvider.notifier);

    // Смена этапа (чипы) или первый показ — сразу подъезжаем к точке,
    // не дожидаясь таймера бездействия.
    if (_seenStage != progress.stage) {
      _seenStage = progress.stage;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }

    // Задание выполнено (точка сменилась) — сбрасываем «кулдаун»
    // свободного скролла и подъезжаем к следующей точке сразу.
    final nodeKey = '${progress.stage}:${progress.node}';
    if (_seenNodeKey != null && _seenNodeKey != nodeKey) {
      _lastUserScroll = DateTime.now().subtract(const Duration(seconds: 30));
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
    _seenNodeKey = nodeKey;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Верхний блок перехода (по макету): ряд чипов обычных
            // этапов (цифры 1..5) + на всю ширину чип «Бесконечный лес».
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Обычные этапы — все, кроме последнего (лес).
                      for (var i = 0; i < stages.length - 1; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: i < stages.length - 2 ? 6 : 0),
                            child: _StageChip(
                              label: '${i + 1}',
                              active: i == progress.stage,
                              enabled: notifier.isStageUnlocked(i),
                              onTap: () => notifier.selectStage(i),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StageChip(
                    label: 'Бесконечный лес',
                    active: stage.isGrind,
                    enabled: true,
                    onTap: () => notifier.selectStage(stages.length - 1),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(child: _pathBody(c, stage, progress, notifier, game)),
          ],
        ),
      ),
    );
  }

  Widget _pathBody(
    AppColors c,
    PathStageDef stage,
    PathProgress progress,
    PathController notifier,
    GameState? game,
  ) {
    final complete = notifier.stageComplete;
    // Демо-режим (ТЗ 2.5.13): на любую точку можно зайти — тап по
    // чужой точке открывает урок на просмотр (без сдвига прогресса).
    final demo = game?.demoMode == true;
    // Обычные этапы: первой точкой на дорожке идёт теория (кружок «Т»),
    // поэтому точек на одну больше, чем заданий этапа. В лесу точки
    // «Т» нет — механика леса не меняется.
    final theoryNode = !stage.isGrind;
    final pointCount = stage.nodes + (theoryNode ? 1 : 0);
    final contentWidth = pointCount * nodeWidth + 40;
    final theorySeen = theoryNode && notifier.isTheorySeen(progress.stage);

    return Stack(
      children: [
        // Панорама с точками: двигается влево-вправо (drag + автоподъезд
        // к текущей точке). Внутри — отступы со всех сторон и
        // скругление (как в макете SVG: r21), двигаемая часть внутри.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              children: [
                // Свайп пользователя фиксируем: по нему панорама свободная
                // и 20 секунд не возвращается к текущей точке.
                NotificationListener<UserScrollNotification>(
                  onNotification: (n) {
                    if (n.direction != ScrollDirection.idle) {
                      _lastUserScroll = DateTime.now();
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      width: contentWidth,
                      height: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Фон этапа — готовая картинка-дизайн. Берётся из
                          // PathStageDef.assets текущего этапа через
                          // notifier.currentAsset (новые этапы 4–5: otap3.png,
                          // ada2.png), растянута на всю панораму (cover).
                          Image.asset(
                            notifier.currentAsset,
                            fit: BoxFit.cover,
                            width: contentWidth,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: c.cardDeep),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  c.bg.withValues(alpha: 0.15),
                                  c.bg.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                          // Полоса пути: скруглённая волнистая линия + точки.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: SizedBox(
                                width: pointCount * nodeWidth,
                                height: 240,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _PathWavePainter(
                                          nodes: pointCount,
                                          nodeWidth: nodeWidth,
                                          amplitude: 44,
                                          color: _lineColors[progress.stage],
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        // Первая точка этапа — теория:
                                        // буква «Т», всегда доступна,
                                        // тап открывает слайды теории.
                                        if (theoryNode)
                                          SizedBox(
                                            width: nodeWidth,
                                            child: Center(
                                              child: _PathNode(
                                                index: 0,
                                                offsetY: -44.0,
                                                theory: true,
                                                state: theorySeen
                                                    ? _NodeState.done
                                                    : _NodeState.current,
                                                lineColor:
                                                    _lineColors[progress.stage],
                                                reward: notifier.nodeReward,
                                                onTap: () => _showTheory(
                                                    progress.stage),
                                              ),
                                            ),
                                          ),
                                        for (var i = 0; i < stage.nodes; i++)
                                          SizedBox(
                                            width: nodeWidth,
                                            child: Center(
                                              child: _PathNode(
                                                index: i,
                                                // Волна идёт по позициям
                                                // точек: с точкой «Т» точка
                                                // викторины i — на позиции i+1.
                                                offsetY: (theoryNode ? i + 1 : i)
                                                        .isEven
                                                    ? -44.0
                                                    : 44.0,
                                                // Пока теория этапа не
                                                // прочитана — непройденные
                                                // точки викторин визуально
                                                // locked (пройденные и
                                                // завершённый этап не
                                                // трогаем — старые сейвы).
                                                // В демо замок не рисуем:
                                                // точки и так открыты.
                                                state: !demo &&
                                                        theoryNode &&
                                                        !theorySeen &&
                                                        !complete &&
                                                        i >= progress.node
                                                    ? _NodeState.locked
                                                    : i < progress.node
                                                    ? _NodeState.done
                                                    : i == progress.node &&
                                                          !complete
                                                    ? _NodeState.current
                                                    : demo
                                                    ? _NodeState.current
                                                    : _NodeState.locked,
                                                lineColor:
                                                    _lineColors[progress.stage],
                                                // nodeReward — с бонусом
                                                // «Бережливого» (+1 монета).
                                                reward: notifier.nodeReward,
                                                onTap: notifier.onCooldown ||
                                                        (!demo &&
                                                            (complete ||
                                                                i !=
                                                                    progress
                                                                        .node))
                                                    ? null
                                                    : () => _openNode(
                                                        context,
                                                        stage,
                                                        override:
                                                            demo &&
                                                                    i !=
                                                                        progress
                                                                            .node
                                                            ? i
                                                            : null,
                                                      ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Нижняя панель: мысль + закупка (в лесу), кулдаун, завершение.
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stage.isGrind) _forestCard(c, progress, game),
                      // Подсказка: пока теория этапа не прочитана, точки
                      // викторин закрыты — зовём тапнуть кружок «Т».
                      if (theoryNode && !theorySeen)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            color: c.cardDeep,
                            child: Text(
                              'Сначала изучи теорию — жми на кружок «Т»!',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                  color: c.textDim, size: 14),
                            ),
                          ),
                        ),
                      if (notifier.onCooldown)
                        _cooldownCard(c, notifier.cooldownRemaining),
                      if (complete)
                        AppButton(
                          text: stage.isGrind ? 'Новый круг' : 'Следующий этап',
                          variant: AppButtonVariant.success,
                          onPressed: () => _finishStage(notifier),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Тап по текущей точке: обычные этапы — вопрос, лес — поход в магазин.
  /// [override] — демо-просмотр чужой точки: PathTaskScreen покажет её
  /// вопрос, но прогресс не сдвинет (см. demoNodeOverrideProvider).
  Future<void> _openNode(BuildContext context, PathStageDef stage,
      {int? override}) async {
    if (stage.isGrind) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ForestTripScreen()));
      return;
    }
    // Подстраховка: теория этапа ещё не прочитана — сначала теория,
    // и только потом вопрос (обычно её читают тапом по точке «Т»).
    final notifier = ref.read(pathControllerProvider.notifier);
    final p = ref.read(pathControllerProvider).valueOrNull;
    if (p != null && !notifier.isTheorySeen(p.stage)) {
      await _showTheory(p.stage);
      if (!context.mounted) return;
    }
    ref.read(demoNodeOverrideProvider.notifier).state = override;
    Navigator.of(context).pushNamed(Routes.pathTask);
  }

  /// Диалог теории этапа (слайды, path_theory.dart). Закрытие ЛЮБЫМ
  /// способом — кнопкой «Поехали!» или тапом мимо — отмечает теорию
  /// прочитанной (markTheorySeen).
  Future<void> _showTheory(int stageIndex) async {
    if (stageIndex < 0 || stageIndex >= pathTheory.length) return;
    final slides = pathTheory[stageIndex];
    if (slides.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _TheoryDialog(slides: slides),
    );
    if (!mounted) return;
    await ref.read(pathControllerProvider.notifier).markTheorySeen(stageIndex);
  }

  /// Завершение этапа/круга: переход + попап с итогами (чему научились,
  /// статистика решений за этап, характер с бонусом).
  Future<void> _finishStage(PathController notifier) async {
    final t = await notifier.finishStage();
    if (t == null || !mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _StageTransitionDialog(t),
    );
  }

  /// Карточка леса: мысль-подсказка + кнопка похода. Сама механика —
  /// сценарии «какую вещь купить при условии» в ForestTripScreen
  /// (чек-лист товаров упразднён вместе со старым лесным магазином).
  Widget _forestCard(AppColors c, PathProgress progress, GameState? game) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        color: c.cardDeep,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💭 В походе случаются события — выбирай, какая вещь '
              'понадобится. Ошибся — потеряешь монетки!',
              style: AppTextStyles.body(color: c.text, size: 14),
            ),
            const SizedBox(height: 8),
            AppButton(
              text: 'В поход!',
              variant: AppButtonVariant.success,
              height: 44,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ForestTripScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cooldownCard(AppColors c, Duration remaining) {
    final secs = remaining.inSeconds.clamp(0, 9999);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        color: c.cardDeep,
        child: Column(
          children: [
            Text(
              'Зверёк идёт до следующей точки…',
              style: AppTextStyles.body(color: c.textDim, size: 14),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: secs / pathCooldown.inSeconds,
                minHeight: 8,
                backgroundColor: c.card,
                valueColor: AlwaysStoppedAnimation(c.purple),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$secs с',
              style: AppTextStyles.number(color: c.text, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Чип этапа: r8, неактивный #383838, активный зелёный #558953 (по макету).
class _StageChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _StageChip({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: active
              ? AppColors.figmaPathActive
              : enabled
              ? AppColors.figmaChip
              : c.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body(
              color: enabled ? Colors.white : c.textDim,
              size: 18,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Попап перехода на новый этап/круг: «чему научились» + статистика
/// решений игрока за этап + характер с бонусом (или подсказка, как его
/// получить).
class _StageTransitionDialog extends StatelessWidget {
  final StageTransition t;

  const _StageTransitionDialog(this.t);

  /// «Чему научились» по индексу завершённого этапа (5 — лес).
  /// Индексы совпадают с stages: 0..4 — обычные этапы, 5 — лес.
  static const _lessons = [
    'Ты научился отличать доходы от расходов и делить монеты на нужное, хотелки и копилку.',
    'Ты узнал, как копилка и цель помогают накопить на мечту.',
    'Ты научился смотреть на цену и сравнивать перед покупкой.',
    'Ты узнал, откуда берутся деньги и чем заработок отличается от подарка.',
    'Ты научился распознавать хитрости мошенников и беречь пароли и коды.',
    'Ты снова сходил в поход и потренировался выбирать!',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final forestChoices = t.forestSave + t.forestNeed + t.forestWant;
    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.isNewCycle ? 'Круг леса пройден!' : 'Этап «${t.finishedTitle}» пройден!',
              textAlign: TextAlign.center,
              style: AppTextStyles.header(color: c.text, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              _lessons[t.finishedStage.clamp(0, _lessons.length - 1)],
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: c.text, size: 16),
            ),
            // Рост питомца — только если на этом этапе стадия ВЫРОСЛА
            // (growthFrom/growthTo заполняет PathController.finishStage).
            if (t.growthFrom != null &&
                t.growthTo != null &&
                t.growthTo! > t.growthFrom!) ...[
              const SizedBox(height: 12),
              Text(
                '🎉 Финни подрос! Стадия ${t.growthTo}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                    color: c.green, size: 18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                growthExplanation(t.growthTo!),
                textAlign: TextAlign.center,
                style: AppTextStyles.body(color: c.text, size: 16),
              ),
            ],
            // Строки статистики — только по совершённым решениям (> 0).
            if (t.quizTotal > 0)
              _stat(c, 'Уроков с первого раза: ${t.quizCorrect} из ${t.quizTotal}'),
            if (t.savedDelta > 0)
              _stat(c, 'Отложено в копилку: ${t.savedDelta} монет'),
            if (forestChoices > 0)
              _stat(c, 'В лесу выборов: копилка ×${t.forestSave}, '
                  'нужное ×${t.forestNeed}, хотелки ×${t.forestWant}'),
            const SizedBox(height: 12),
            if (t.trait != null) ...[
              Text(
                'Характер: ${traitTitle(t.trait!)}'
                '${t.traitIsNew ? ' — новый!' : ''}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                    color: c.gold, size: 18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                traitBonusLine(t.trait!),
                textAlign: TextAlign.center,
                style: AppTextStyles.body(color: c.text, size: 16),
              ),
            ] else
              Text(
                'Копи, отвечай на уроки и заботься о питомце — '
                'получишь характер с бонусом!',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(color: c.textDim, size: 16),
              ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Дальше',
              variant: AppButtonVariant.success,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(AppColors c, String line) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          line,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: c.text, size: 16),
        ),
      );
}

enum _NodeState { done, current, locked }

/// Скруглённая волнистая линия пути (как в макете): плавные дуги через
/// точки, чередующиеся выше/ниже центра.
class _PathWavePainter extends CustomPainter {
  final int nodes;
  final double nodeWidth;
  final double amplitude;
  final Color color;

  const _PathWavePainter({
    required this.nodes,
    required this.nodeWidth,
    required this.amplitude,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cy = size.height / 2;
    double yAt(int i) => cy + (i.isEven ? -amplitude : amplitude);
    double xAt(int i) => nodeWidth / 2 + i * nodeWidth;

    final path = Path()..moveTo(xAt(0), yAt(0));
    for (var i = 1; i < nodes; i++) {
      final x0 = xAt(i - 1);
      final x1 = xAt(i);
      final y0 = yAt(i - 1);
      final y1 = yAt(i);
      final mx = (x0 + x1) / 2;
      path.cubicTo(mx, y0, mx, y1, x1, y1);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathWavePainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.color != color;
}

class _PathNode extends StatelessWidget {
  final int index;
  final double offsetY;
  final _NodeState state;
  final Color lineColor;
  final int reward;
  final VoidCallback? onTap;

  /// Точка теории (первый узел обычного этапа): вместо иконки — буква
  /// «Т», награды под точкой нет, прочитанная заливается цветом этапа.
  final bool theory;

  const _PathNode({
    required this.index,
    required this.offsetY,
    required this.state,
    required this.lineColor,
    required this.reward,
    this.onTap,
    this.theory = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, ring, icon, fg) = switch (state) {
      // Прочитанная теория — заливка цветом этапа (в отличие от зелёных
      // пройденных точек викторин).
      _NodeState.done when theory => (
        lineColor,
        Colors.white,
        Icons.check,
        Colors.white,
      ),
      _NodeState.done => (c.green, Colors.white, Icons.check, Colors.white),
      _NodeState.current => (
        Colors.white,
        lineColor,
        Icons.play_arrow,
        lineColor,
      ),
      _NodeState.locked => (
        c.card.withValues(alpha: 0.8),
        c.textDim,
        Icons.lock,
        c.textDim,
      ),
    };
    final size = state == _NodeState.current ? 84.0 : 66.0;
    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ring,
                  width: state == _NodeState.current ? 5 : 3,
                ),
                boxShadow: state == _NodeState.current
                    ? [
                        BoxShadow(
                          color: lineColor.withValues(alpha: 0.7),
                          blurRadius: 22,
                        ),
                      ]
                    : null,
              ),
              child: theory
                  ? Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Text(
                          'Т',
                          style: AppTextStyles.header(
                            color: fg,
                            size: state == _NodeState.current ? 34 : 26,
                          ),
                        ),
                        // Теория прочитана — маленькая галочка у кружка.
                        if (state == _NodeState.done)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 14,
                                color: lineColor,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Icon(
                      icon,
                      color: fg,
                      size: state == _NodeState.current ? 44 : 32,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          // У точки теории награды нет, но место под подпись оставляем,
          // чтобы кружки стояли на одной высоте с соседними.
          Text(
            theory ? '' : '+$reward',
            style: AppTextStyles.price(
              color: state == _NodeState.locked ? c.textDim : Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Диалог теории перед этапом: слайды (PageView) с эмодзи, заголовком
/// и текстом, индикатор точек и кнопка «Дальше» → на последнем слайде
/// «Поехали!». В стиле _StageTransitionDialog (Dialog, тёмная карточка).
/// Закрытие любым способом засчитывается как прочтение (см. _showTheory).
class _TheoryDialog extends StatefulWidget {
  final List<TheorySlide> slides;

  const _TheoryDialog({required this.slides});

  @override
  State<_TheoryDialog> createState() => _TheoryDialogState();
}

class _TheoryDialogState extends State<_TheoryDialog> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _index == widget.slides.length - 1;
    return Dialog(
      backgroundColor: AppColors.figmaCardDeep,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _page,
                itemCount: widget.slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final s = widget.slides[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.emoji, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        s.title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.header(color: c.text, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.text,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(color: c.text, size: 16),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Индикатор точек: активная — золотая.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.slides.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index
                          ? c.gold
                          : c.textDim.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              text: last ? 'Поехали!' : 'Дальше',
              variant: AppButtonVariant.success,
              onPressed: () {
                if (last) {
                  Navigator.of(context).pop();
                } else {
                  _page.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
