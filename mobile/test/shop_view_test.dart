import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finni_app/data/models/content_bundle.dart';
import 'package:finni_app/data/models/game_state.dart';
import 'package:finni_app/features/shop/shop_view.dart';
import 'package:finni_app/providers.dart';

/// Регрессионный тест: сетка товаров магазина реально рендерится.
///
/// Раньше первый ряд (_ItemsRow) был Row из Expanded(ShopItemCell) со
/// StackFit.expand внутри — внутри ListView у ряда неограниченная высота,
/// и в релизной сборке это молча убирало отрисовку всего списка (магазин
/// был «пустым» и в лесу, и на главной). AspectRatio на ячейках это чинит;
/// тест ловит поломку. Контент собирается прямо в коде (без rootBundle —
/// реальный файловый/ассетный ввод-вывод в зоне FakeAsync не завершается).
class _FakeGameStateController extends GameStateController {
  @override
  Future<GameState> build() async => GameState.empty();
}

GameContent _testContent() => GameContent.fromJson(const {
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
      'shop_items': [
        {'id': 'i1', 'name': 'Еда', 'emoji': '🍖', 'type': 'mandatory', 'price': 25, 'category': 'Питание'},
        {'id': 'i2', 'name': 'Лекарство', 'emoji': '💊', 'type': 'mandatory', 'price': 20, 'category': 'Здоровье'},
        {'id': 'i3', 'name': 'Дом', 'emoji': '🏠', 'type': 'mandatory', 'price': 30, 'category': 'Жильё'},
        {'id': 'i4', 'name': 'Мяч', 'emoji': '⚽', 'type': 'optional', 'price': 30, 'category': 'Развлечение'},
        {'id': 'i5', 'name': 'Бант', 'emoji': '🎀', 'type': 'optional', 'price': 10, 'category': 'Украшение'},
        {'id': 'i6', 'name': 'Колесо', 'emoji': '🎡', 'type': 'optional', 'price': 20, 'category': 'Досуг'},
        {'id': 'i7', 'name': 'Звезда', 'emoji': '⭐', 'type': 'optional', 'price': 5, 'category': 'Украшение'},
      ],
    });

Widget _wrap(GameContent content, ShopView view) => ProviderScope(
      overrides: [
        gameContentProvider.overrideWithValue(content),
        gameStateControllerProvider
            .overrideWith(() => _FakeGameStateController()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, height: 800, child: view),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('ShopView рендерит товары, цены и баннер спецакции',
      (tester) async {
    final content = _testContent();

    await _pump(tester, _wrap(content, const ShopView(showSpec: true)));

    // Шапка и панель состояния.
    expect(find.text('Магазин'), findsOneWidget);
    expect(find.text('Деняжек'), findsOneWidget);
    expect(find.text('Сытость'), findsOneWidget);
    // Баннер спецакции.
    expect(find.text('СПЕЦАКЦИЯ'), findsOneWidget);
    // Цены первого ряда — реальные цены контента.
    expect(find.text('25'), findsWidgets);
    // Эмодзи товаров на месте.
    expect(find.text('🍖'), findsWidgets);
    expect(find.text('⭐'), findsWidgets);
    // Плейсхолдер «Товары появятся…» не должен показываться.
    expect(find.textContaining('Товары появятся'), findsNothing);
  });

  testWidgets('ShopView в лесу (showSpec: false, Водичка) рендерит сетку',
      (tester) async {
    final content = _testContent();

    await _pump(
        tester, _wrap(content, const ShopView(showSpec: false, moodLabel: 'Водичка')));

    expect(find.text('Водичка'), findsOneWidget);
    expect(find.text('СПЕЦАКЦИЯ'), findsNothing);
    expect(find.textContaining('Товары появятся'), findsNothing);
    expect(find.text('🍖'), findsWidgets);
  });
}
