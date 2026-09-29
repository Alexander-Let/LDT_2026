import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/ui/status_bar.dart';
import '../../data/engine/game_engine.dart' as engine;
import '../../data/models/content_bundle.dart';
import '../../data/models/game_state.dart';
import '../../providers.dart';

/// Магазин — 1-в-1 по макету «segee» (iPhone 17 - 2). Шапка (✕ + заголовок)
/// и панель состояния ЗАФИКСИРОВАНЫ — не уезжают при скролле. Скроллится
/// только сетка товаров: 3 ячейки, баннер СПЕЦАКЦИЯ, дальше ячейки.
/// Используется: (1) в шторке на Главной (свайп вверх по панели состояния
/// разворачивает до верха экрана; [showHeader] переключает шапку ↔
/// свёрнутый вид с ручкой; подсказка «Магазин ↑» живёт снаружи, в
/// HomeScreen, над серой панелью), (2) в лесу (без спецакций).
///
/// Жест шторки — ОДИН на всё тело магазина (не на отдельные куски): он
/// стабилен при переключении шапка ↔ ручка посреди свайпа, поэтому один
/// непрерывный свайп всегда доводит панель до конца (без «ступеней»).
/// В развёрнутом виде скролл-лист перехватывает жест над собой: тянуть
/// за шторку можно только за верхнюю часть (шапка, шкалы, зазор).
class ShopView extends ConsumerWidget {
  final bool showSpec;

  /// Кнопка ✕ — закрыть магазин (свернуть шторку); null — без кнопки.
  final VoidCallback? onClose;

  /// Подпись второй шкалы статуса («Настроение» / в лесу «Водичка»).
  final String moodLabel;

  /// Контроллер скролла из шторки (DraggableScrollableSheet).
  final ScrollController? scrollController;

  /// false — свёрнутый вид: ручка вместо шапки (панель состояния та же).
  final bool showHeader;

  /// Скруглённый верхний край (шторка на Главной).
  final bool roundedTop;

  /// Тап по свёрнутой панели — развернуть шторку.
  final VoidCallback? onTapOpen;

  /// Свайп по ручке/шапке/свёрнутой панели — управление шторкой (главная).
  final GestureDragUpdateCallback? onPanelDragUpdate;
  final GestureDragEndCallback? onPanelDragEnd;

  /// true — список товаров временно не скроллится (шторка свёрнута),
  /// чтобы жест ушёл в drag-колбэки шторки.
  final bool lockScroll;

  const ShopView({
    super.key,
    this.showSpec = true,
    this.onClose,
    this.moodLabel = 'Настроение',
    this.scrollController,
    this.showHeader = true,
    this.roundedTop = false,
    this.onTapOpen,
    this.onPanelDragUpdate,
    this.onPanelDragEnd,
    this.lockScroll = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    final content = ref.watch(gameContentProvider);

    final items = content?.shopItems ?? const <ShopItem>[];
    final available = game == null
        ? const <ShopItem>[]
        : items.where((i) => !engine.isItemLocked(i, game)).toList();

    final spec = showSpec ? _firstRequired(items) : null;

    // Порядок как в макете: первый ряд из 3, баннер СПЕЦАКЦИЯ, остальные.
    final firstRow = available.take(3).toList();
    final rest = available.skip(3).toList();
    // Иконки «двух ед» в баннере — следующие по списку товары.
    final bonus = [
      if (rest.isNotEmpty) rest.first,
      if (rest.length > 1) rest[1],
    ];

    final body = Column(
      children: [
        // Шапка: ✕ слева, «Магазин» по центру — НЕ скроллится.
        // Row (не Stack): крестик и заголовок физически не могут
        // наложиться друг на друга. В свёрнутой шторке — ручка +
        // полупрозрачная подсказка «Магазин ↑» над панелью состояния.
        // Шапка: «Магазин» по центру, ✕ СПРАВА — НЕ скроллится.
        // Row (не Stack): крестик и заголовок физически не могут
        // наложиться друг на друга. В свёрнутой шторке — ручка.
        if (showHeader)
          SizedBox(
            height: 56,
            child: Row(
              children: [
                // Симметричная заглушка — заголовок строго по центру.
                const SizedBox(width: 48),
                Expanded(
                  child: Center(
                    child: Text('Магазин',
                        style: AppTextStyles.header(color: Colors.white, size: 26)),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          )
        else
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3D3D3D),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        // Панель состояния: Сытость/Настроение (в лесу — Водичка) + монеты.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: StatusBar(
            satiety: game?.pet.satiety ?? 0,
            mood: game?.pet.mood ?? 0,
            balance: game?.balance ?? 0,
            moodLabel: moodLabel,
          ),
        ),
        // Зазор между панелью состояния и товарами — в ОБОИХ видах (по
        // фидбеку «в свёрнутом состоянии между СНД и товарами должен
        // быть зазор»): товары не начинаются вплотную к шкалам. По центру
        // зазора — полосочка-ручка; в свёрнутой шторке она ниже видимого
        // края панели (home_screen обрезает панель по высоте _panelHeight,
        // продлив её под панель вкладок). Серая полоска-разделитель над
        // товарами убрана по фидбеку.
        SizedBox(
          height: 40,
          child: showHeader
              ? Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D3D3D),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        // Сетка товаров — единственная скроллящаяся часть.
        Expanded(
          child: content == null
              ? Center(
                  child: Text('Загружаем товары…',
                      style: AppTextStyles.body(color: Colors.white70)),
                )
              : available.isEmpty
                  ? Center(
                      child: Text('Товары появятся в начале первого периода',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(color: Colors.white70)),
                    )
                  : ListView(
                      controller: scrollController,
                      // Clamping (не bounce): перетягивание вниз на самом
                      // верху списка сразу даёт overscroll → шторка
                      // закрывается ОДНИМ свайпом, а не после отскока.
                      physics: lockScroll
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        _ItemsRow(items: firstRow, state: game!),
                        // Отступ как между обычными товарами (12).
                        if (spec != null) ...[
                          const SizedBox(height: 12),
                          _SpecBanner(item: spec, state: game, bonus: bonus),
                        ],
                        if (rest.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _ItemsGrid(items: rest, state: game),
                        ],
                      ],
                    ),
        ),
      ],
    );

    // Один жест на всё тело магазина — в ОБЕИХ стадиях (шапка ↔ свёрнутый
    // вид меняются ВНУТРИ, обёртка не трогается): свайп не рвётся посреди
    // движения, панель открывается/закрывается за ОДИН свайп. Тап —
    // только в свёрнутом виде (развернуть). В развёрнутом виде жест над
    // списком товаров перехватывает скролл-лист: закрыть можно, потянув
    // только за верхнюю часть (шапка, шкалы, зазор с ручкой).
    final panel = onPanelDragUpdate != null
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: showHeader ? null : onTapOpen,
            onVerticalDragUpdate: onPanelDragUpdate,
            onVerticalDragEnd: onPanelDragEnd,
            child: body,
          )
        : body;

    if (!roundedTop) return panel;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(color: AppColors.figmaBg, child: panel),
    );
  }
}

/// Магазин отдельным полноэкранным экраном (например, для отладки): серый
/// фон вкладки, шапка с ✕ видна всегда.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen(), fullscreenDialog: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.figmaBg,
      body: SafeArea(
        bottom: false,
        child: ShopView(
          showSpec: true,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// Ряд из 3 ячеек.
class _ItemsRow extends StatelessWidget {
  final List<ShopItem> items;
  final GameState state;

  const _ItemsRow({required this.items, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          // AspectRatio ограничивает высоту ячейки: ListView даёт ряду
          // неограниченную высоту, без этого StackFit.expand в ячейке
          // в релизе молча ломал отрисовку всего списка (пустой магазин).
          Expanded(child: AspectRatio(aspectRatio: 1, child: ShopItemCell(item: items[i], state: state))),
        ],
        // добивка пустыми, если товаров < 3
        for (var i = items.length; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          const Expanded(child: AspectRatio(aspectRatio: 1, child: SizedBox())),
        ],
      ],
    );
  }
}

/// Остальные ячейки сеткой по 3.
class _ItemsGrid extends StatelessWidget {
  final List<ShopItem> items;
  final GameState state;

  const _ItemsGrid({required this.items, required this.state});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => ShopItemCell(item: items[i], state: state),
    );
  }
}

/// Ячейка товара по макету: фон — готовая картинка из Figma (тёмная
/// карточка со зелёной «чашей»), цена крупно и ПО ЦЕНТРУ сверху,
/// по центру — круг-слот с эмодзи. Серая ячейка = товара нет в ассортименте.
class ShopItemCell extends ConsumerWidget {
  final ShopItem item;
  final GameState state;

  const ShopItemCell({super.key, required this.item, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = engine.isItemLocked(item, state);
    final price = engine.itemPrice(item, state);
    return GestureDetector(
      onTap: locked ? null : () => _buy(context, ref, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Container(
          color: locked ? const Color(0xFF111111) : AppColors.figmaCardDeep,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фон ячейки — картинка из Figma (непрозрачная, 236×236).
              if (!locked)
                Image.asset(
                  'assets/shop/cell.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              // Цена — по центру, крупно (Jersey 10).
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                child: Center(
                  child: Text(
                    '$price',
                    style: AppTextStyles.price(
                      color: locked ? const Color(0xFF808080) : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 66,
                  height: 66,
                  margin: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: locked ? AppColors.figmaTrack : Colors.white,
                    ),
                  ),
                  child: Center(
                    child: locked
                        ? const Icon(Icons.lock, color: Color(0xFF808080), size: 26)
                        : Text(item.emoji, style: const TextStyle(fontSize: 32)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Баннер «СПЕЦАКЦИЯ» между рядами товаров: фон — готовая картинка из
/// Figma (тёмная плашка с золотым градиентом снизу), крупная цена слева,
/// справа ДВЕ еды в слотах с «+» между ними (как в макете). Сверху и снизу
/// баннер прижат соседними ячейками.
class _SpecBanner extends ConsumerWidget {
  final ShopItem item;
  final GameState state;
  final List<ShopItem> bonus;

  const _SpecBanner({
    required this.item,
    required this.state,
    this.bonus = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = engine.itemPrice(item, state);
    return GestureDetector(
      onTap: () => _buy(context, ref, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 120,
          decoration: const BoxDecoration(
            color: AppColors.figmaCardDeep,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/shop/spec_bar.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('СПЕЦАКЦИЯ',
                              style: AppTextStyles.label(color: Colors.white, size: 17)),
                          const Spacer(),
                          Text(
                            '$price',
                            style: AppTextStyles.price(
                                color: AppColors.figmaSpecGold, size: 54),
                          ),
                        ],
                      ),
                    ),
                    // Два слота с едой и «+» между ними (по макету).
                    for (var i = 0; i < 2; i++) ...[
                      Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: AppColors.figmaCardDeep,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Center(
                          child: i < bonus.length
                              ? Text(bonus[i].emoji,
                                  style: const TextStyle(fontSize: 28))
                              : const Text('🍔', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                      if (i == 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('+',
                              style: AppTextStyles.label(
                                  color: Colors.white, size: 24)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ShopItem? _firstRequired(List<ShopItem> items) {
  for (final i in items) {
    if (i.type.isRequiredKind) return i;
  }
  return items.isEmpty ? null : items.first;
}

Future<void> _buy(BuildContext context, WidgetRef ref, ShopItem item) async {
  final result = await ref.read(gameStateControllerProvider.notifier).buyItem(item);
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    result.success ? result.feedbackLine : (result.error ?? 'Не получилось'),
  );
}
