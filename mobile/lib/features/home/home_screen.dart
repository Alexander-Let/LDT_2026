import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/pet_growth.dart';
import '../../core/pet_skins.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../main/main_shell.dart';
import '../path/path_controller.dart';
import '../shop/shop_view.dart';
import 'pet_thought.dart';

/// Зеркало tasks_screen: список сюжетных заданий продублирован здесь,
/// т.к. `TasksScreen._storyTasks` приватен. Награда — короткая строка
/// («100 монеточек» вместо «Награда: 100 монеточек»). Держать синхронно
/// с TasksScreen._storyTasks.
const _storyTasksMirror = [
  ('Пройти 1 этап «Дороги знаний»', '100 монеточек'),
  ('Пройти 1 уровень «Похода»', '100 монеточек'),
  ('Выполняй активности в течении 3 дней', '100 монеточек'),
];

/// Тестовый хук: в виджет-тестах нет SQLite, поэтому «текущее задание»
/// для баннера задаётся напрямую (null — читать kv из БД, как обычно).
@visibleForTesting
final debugStoryTaskProvider = Provider<(String, String)?>((ref) => null);

/// Первое незакрытое сюжетное задание (награда ещё не забрана — флаг
/// kv `story_claimed_$i`, как в tasks_screen) для баннера на главном
/// экране. null — все задания закрыты или БД недоступна (тесты).
final _currentStoryTaskProvider = FutureProvider<(String, String)?>((ref) async {
  final debug = ref.watch(debugStoryTaskProvider);
  if (debug != null) return debug;
  try {
    final db = ref.read(localDbProvider);
    for (var i = 0; i < _storyTasksMirror.length; i++) {
      if (await db.kvGet('story_claimed_$i') == null) {
        return _storyTasksMirror[i];
      }
    }
  } catch (_) {
    // localDbProvider не переопределён (тесты) — баннер скрыт.
  }
  return null;
});

/// Главный экран по макету «segee» (iPhone 17 - 1): комната на весь
/// экран, зверёк стоит на полу по центру («дышит»), внизу — панель
/// состояния. Магазин — шторка поверх комнаты: один свайп вверх по
/// панели состояния разворачивает её до самого верха экрана; один свайп
/// вниз ЗА ВЕРХНЮЮ ЧАСТЬ (шапка, шкалы, зазор с ручкой) или ✕ — сворачивает
/// обратно. За список товаров тянуть нельзя — он скроллится. Панель
/// вкладок при этом остаётся на месте — шторка живёт внутри вкладки.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bob;

  /// 0 — шторка свёрнута (видна только панель состояния), 1 — до верха.
  late final AnimationController _panel;

  /// Скролл списка товаров (когда шторка развёрнута).
  late final ScrollController _shopScroll;

  /// Высота ВИДИМОЙ части свёрнутой панели: ручка (21) + шкалы (106) +
  /// верхняя часть зазора (13). Зазор (40) между шкалами и товарами есть
  /// всегда — в свёрнутом виде видны только его первые 13; его середина
  /// с полосочкой-ручкой (144.5–149.5 от верха панели) и сами товары
  /// (с 171) оказываются в зоне _underNav под панелью вкладок. Панель
  /// продлена на _underNav и сдвинута вниз на ту же величину — верхний
  /// край на месте, низ под навигацией.
  static const double _panelHeight = 140;

  /// На сколько свёрнутая панель заезжает ПОД панель вкладок: середина
  /// зазора с полосочкой и начало списка товаров. Scaffold рисует
  /// bottomNavigationBar ПОВЕРХ body, поэтому эта зона на экране не
  /// видна. Должна быть ≥ 40: контент шторки (ручка 21 + шкалы 106 +
  /// зазор 40 + воздух 4 = 171) иначе не влезает в высоту панели.
  static const double _underNav = 40;

  /// Полный диапазон развёртывания (высота экрана минус свёрнутая панель).
  double _dragRange = 600;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _panel = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _shopScroll = ScrollController();
  }

  @override
  void dispose() {
    _bob.dispose();
    _panel.dispose();
    _shopScroll.dispose();
    super.dispose();
  }

  bool get _expanded => _panel.value > 0.9;

  void _openShop() {
    _panel.animateTo(1.0, curve: Curves.easeOut);
  }

  void _closeShop() {
    _panel.animateTo(0.0, curve: Curves.easeOut);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _panel.stop();
    _panel.value =
        (_panel.value - details.delta.dy / _dragRange).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v < -400) {
      _openShop();
    } else if (v > 400) {
      _closeShop();
    } else if (_panel.value > 0.5) {
      _openShop();
    } else {
      _closeShop();
    }
  }

  /// Overscroll списка шторку НЕ закрывает: закрытие — только жестом за
  /// верхнюю часть (шапка/шкалы/зазор) или по ✕ (см. ShopView: один
  /// GestureDetector на всё тело, свайп не рвётся при смене шапки ↔ ручки).

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    // Контент нужен для текста плашки демо-режима (demoMode.banner).
    final content = ref.watch(gameContentProvider);
    // Стадия роста питомца (ТЗ 2.5.10) по числу пройденных этапов
    // «Дорожки знаний». Getter stagesCompleted живёт на контроллере
    // (у PathProgress его нет), поэтому на состояние подписываемся,
    // а значение читаем с notifier — пересчёт при каждом изменении.
    final pathState = ref.watch(pathControllerProvider);
    final stagesCompleted = pathState.valueOrNull == null
        ? 0
        : ref.read(pathControllerProvider.notifier).stagesCompleted;
    final neckAsset = growthNeckAsset(growthStage(stagesCompleted));
    // Имя питомца над головой; пустое (питомец ещё не создан) не рисуем.
    final petName = game?.pet.name ?? '';
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _dragRange = constraints.maxHeight - _panelHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Комната (арт из Figma) на весь экран.
              Image.asset(
                'assets/bg/room_figma.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white),
              ),
              // Зверёк стоит на полу по центру, слегка «дышит»; над ним —
              // облачко мыслей (ТЗ 2.5.9) и имя.
              Positioned(
                left: 0,
                right: 0,
                bottom: 210,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Облачко мыслей: само следит за petThoughtProvider,
                    // ширина ~260 (ConstrainedBox внутри виджета).
                    const ThoughtBubble(),
                    const SizedBox(height: 6),
                    // Имя питомца: Nunito ExtraBold 20, белое, с мягкой
                    // тенью — читается на светлой комнате.
                    if (petName.isNotEmpty)
                      Text(
                        petName,
                        style: AppTextStyles.body(
                          color: Colors.white,
                          size: 20,
                          weight: FontWeight.w800,
                        ).copyWith(
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Питомец + элемент роста на шее (ТЗ 2.5.10). Весь
                    // стек — внутри _bob-трансформаций, «дышит» вместе
                    // с персонажем.
                    AnimatedBuilder(
                      animation: _bob,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, 8 * _bob.value),
                        child: Transform.scale(
                          scaleY: 1 + 0.02 * _bob.value,
                          child: child,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Image.asset(
                            petSkinAsset(game?.pet.appearance.skin),
                            height: 280,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.pets, size: 120),
                          ),
                          // Шарфик/воротничок стадий 2–3: по центру
                          // горизонтали. Верх SVG держим там же, где был
                          // при ширине 126 (bottom 112): tap2 (161×126) —
                          // bottom 171, tap3 (132×85) — bottom 161.
                          if (neckAsset != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: neckAsset.contains('tap3') ? 131 : 141,
                              child: Center(
                                child: SvgPicture.asset(
                                  neckAsset,
                                  width: 50,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Шапка с текущей целью (макет v7): тёмная полоса поверх
              // комнаты. Развёрнутая шторка накрывает её — панель ниже
              // в списке слоёв Stack.
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _GoalHeader(),
              ),
              // Плашка демо-режима (ТЗ 2.5.13): маленькая, под шапкой
              // цели справа — не перекрывает ни шапку, ни облачко мыслей.
              if (game?.demoMode == true)
                Positioned(
                  top: 100,
                  right: 12,
                  child: _DemoBadge(
                    text: content?.economy.demoMode.banner ?? '🔧 ДЕМО-РЕЖИМ',
                  ),
                ),
              // Баннер текущего задания над свёрнутой шторкой (bottom:
              // _panelHeight + 12 — на 12 выше верхнего края панели).
              // Плавно скрывается при разворачивании магазина и не
              // перехватывает жесты шторки (IgnorePointer по прозрачности).
              // Подсказки «Магазин ↑» больше нет — магазин открывается
              // тапом/свайпом по самой свёрнутой панели.
              Positioned(
                left: 16,
                right: 16,
                bottom: _panelHeight + 12,
                child: AnimatedBuilder(
                  animation: _panel,
                  builder: (context, child) {
                    final opacity =
                        (1 - _panel.value * 1.5).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: IgnorePointer(
                        ignoring: opacity < 1,
                        child: child,
                      ),
                    );
                  },
                  child: const _TaskBanner(),
                ),
              ),
              // Шторка магазина. Свёрнутая панель продлена на _underNav
              // вниз (под панель вкладок): её серый фон доходит до края,
              // а средняя полосочка скрыта под навигацией.
              AnimatedBuilder(
                animation: _panel,
                builder: (context, _) {
                  final h = lerpDouble(
                    _panelHeight + _underNav,
                    constraints.maxHeight,
                    _panel.value,
                  )!;
                  // bottom: -_underNav * (1 - value): свёрнутая панель
                  // заезжает под панель вкладок (полосочка и товары скрыты
                  // под навигацией), верхний край при этом на месте.
                  // Развёрнутая — ровно на весь body, как раньше.
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: -_underNav * (1 - _panel.value),
                    height: h,
                    // Шапка не залезает под статус-бар: отступ сверху
                    // нужен ТОЛЬКО в развёрнутом виде. В свёрнутом
                    // SafeArea съедал бы верх панели на высоту
                    // статус-бара: серый фон уезжал вниз.
                    // Padding снизу НЕ нужен: серый фон ShopView
                    // сам заполняет панель до края, а зазор между
                    // шкалами и панелью вкладок — это серый хвост
                    // панели (Expanded-список под товарами).
                    child: SafeArea(
                      top: _expanded,
                      bottom: false,
                      child: ShopView(
                        scrollController: _shopScroll,
                        showHeader: _expanded,
                        onClose: _expanded ? _closeShop : null,
                        onTapOpen: _openShop,
                        onPanelDragUpdate: _onDragUpdate,
                        onPanelDragEnd: _onDragEnd,
                        lockScroll: !_expanded,
                        roundedTop: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Шапка с текущей целью (макет v7, рендер 440×956): тёмная полоса
/// высотой ~90 под статус-баром со скруглёнными НИЖНИМИ углами (r20).
/// Слева круглый аватар с эмодзи цели, далее «ЦЕЛЬ: НАЗВАНИЕ» (золотом)
/// и «saved / cost» (белым), справа крупно «percent%» (золотом), а когда
/// цель достигнута — зелёная галочка + «Готово!». Процент — как в
/// goals_screen (saved / cost * 100, clamp 0..100). Цель не выбрана —
/// заглушка 🎯.
class _GoalHeader extends ConsumerWidget {
  const _GoalHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    final content = ref.watch(gameContentProvider);
    final selected = content?.goalById(game?.goalId);
    final cost = selected?.cost ?? 0;
    final saved = game?.goalSaved ?? 0;
    final percent =
        cost <= 0 ? 0 : ((saved / cost) * 100).clamp(0, 100).round();
    final done = cost > 0 && saved >= cost;

    return Container(
      // Плашка заканчивается округло: скруглены только нижние углы.
      decoration: const BoxDecoration(
        color: AppColors.figmaCardDeep,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 90,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Кружок цели — как в goals_screen (Color(0xFF2A2A2A)).
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2A2A2A),
                  ),
                  child: Center(
                    child: Text(
                      selected?.emoji ?? '🎯',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected == null
                            ? 'ЦЕЛЬ: не выбрана'
                            : 'ЦЕЛЬ: ${selected.name.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.number(
                          color: AppColors.figmaHeaderGold,
                          size: 24,
                        ),
                      ),
                      Text(
                        selected == null
                            ? 'Выбери во вкладке Цели'
                            : '$saved / $cost',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (done)
                  // Цель выполнена: зелёная галочка + «Готово!» вместо «N%».
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.figmaNavGreen, size: 24),
                      const SizedBox(width: 6),
                      Text(
                        'Готово!',
                        style: AppTextStyles.number(
                          color: AppColors.figmaNavGreen,
                          size: 28,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '$percent%',
                    style: AppTextStyles.number(
                      color: AppColors.figmaHeaderGold,
                      size: 36,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Баннер текущего задания (макет v7): тёмно-синяя скруглённая карточка
/// над шторкой магазина. Две строки по центру: «Текущее задание:
/// <награда>» (награда золотом) и название первого незакрытого
/// сюжетного задания. Тап — переход на вкладку «Задания» (индекс 3).
/// Все задания закрыты (или БД недоступна) — баннер скрыт.
class _TaskBanner extends ConsumerWidget {
  const _TaskBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(_currentStoryTaskProvider).valueOrNull;
    if (task == null) return const SizedBox.shrink();
    final (title, reward) = task;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(mainTabProvider.notifier).state = 3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.figmaTaskCard,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                style: AppTextStyles.body(color: Colors.white, size: 16),
                children: [
                  const TextSpan(text: 'Текущее задание: '),
                  TextSpan(
                    text: reward,
                    style: AppTextStyles.body(
                      color: AppColors.figmaHeaderGold,
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                color: Colors.white,
                size: 16,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плашка демо-режима (ТЗ 2.5.13): полупрозрачная тёмная «пилюля»,
/// Nunito 12. IgnorePointer — не перехватывает жесты комнаты/шторки.
class _DemoBadge extends StatelessWidget {
  final String text;

  const _DemoBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Text(
          text,
          style: AppTextStyles.body(
            color: Colors.white,
            size: 12,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
