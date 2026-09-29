import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finni_app/data/models/game_state.dart';
import 'package:finni_app/features/home/home_screen.dart';
import 'package:finni_app/features/shop/shop_view.dart';
import 'package:finni_app/providers.dart';

/// Контроллер без БД/сети — для теста геометрии главного экрана.
class FakeGameController extends GameStateController {
  @override
  Future<GameState> build() async => GameState.empty();
}

/// Устройство с высотой статус-бара: SafeArea не должен съедать верх
/// свёрнутой панели (регрессия — «парящая» подпись на реальном
/// устройстве).
const deviceMedia = MediaQueryData(
  size: Size(390, 844),
  padding: EdgeInsets.only(top: 60, bottom: 20),
  viewPadding: EdgeInsets.only(top: 60, bottom: 20),
  viewInsets: EdgeInsets.zero,
  devicePixelRatio: 3,
);

Future<void> pumpHome(WidgetTester tester, {(String, String)? storyTask}) {
  return tester.pumpWidget(ProviderScope(
    overrides: [
      gameStateControllerProvider.overrideWith(FakeGameController.new),
      gameContentProvider.overrideWithValue(null),
      if (storyTask != null)
        debugStoryTaskProvider.overrideWithValue(storyTask),
    ],
    child: const MaterialApp(
      home: MediaQuery(data: deviceMedia, child: HomeScreen()),
    ),
  ));
}

void main() {
  /// Подсказки «Магазин ↑» больше нет — над свёрнутой шторкой живёт
  /// только баннер задания (bottom: _panelHeight + 12). Проверяем, что
  /// баннер не пересекается с панелью: низ второй строки баннера выше
  /// верхнего края панели на 12 (якорь) + 10 (нижний padding баннера)
  /// = 22 номинально, допускаем разброс метрик шрифта.
  testWidgets('баннер задания над панелью, пересечений нет',
      (tester) async {
    await pumpHome(
      tester,
      storyTask: ('Пройти 1 этап «Дороги знаний»', '100 монеточек'),
    );
    await tester.pump();

    // Вторая (нижняя) строка баннера — низ баннера ниже неё ровно
    // на padding 10.
    final bannerBottomLine =
        tester.getRect(find.text('Пройти 1 этап «Дороги знаний»'));
    final panel = tester.getRect(find.byType(ShopView));

    final gap = panel.top - bannerBottomLine.bottom;
    expect(gap, greaterThanOrEqualTo(16));
    expect(gap, lessThanOrEqualTo(28));
  });

  /// Подсказки «Магазин ↑» больше нет: магазин открывается тапом по
  /// самой свёрнутой панели (у ShopView в свёрнутом виде onTap —
  /// onTapOpen). Шторка разворачивается на весь экран.
  testWidgets('тап по свёрнутой панели открывает магазин', (tester) async {
    await pumpHome(tester);
    await tester.pump();

    // Панель свёрнута внизу; тапаем в её центр.
    final center = tester.getCenter(find.byType(ShopView));
    await tester.tapAt(center);
    // pumpAndSettle тут не подходит: зверёк «дышит» вечным
    // repeat(reverse: true) — кадры никогда не заканчиваются.
    // Тикер шторки стартует на ПЕРВОМ кадре после animateTo
    // (elapsed 0), поэтому качаем дважды: первый pump «заводит»
    // тикер, второй доигрывает анимацию 250 мс с запасом.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final panel = tester.getRect(find.byType(ShopView));
    // Тестовая поверхность 800×600: свёрнутая панель 140+40=180,
    // развёрнутая — весь body (600). Порог посередине.
    expect(panel.height, greaterThan(400));
  });
}
