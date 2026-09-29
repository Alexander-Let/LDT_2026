import 'dart:convert';
import 'dart:io';

import 'package:finni_app/data/engine/game_engine.dart' as engine;
import 'package:finni_app/data/engine/phase_flow.dart' as flow;
import 'package:finni_app/data/models/content_bundle.dart';
import 'package:finni_app/data/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

GameContent loadContent() {
  final raw = File('assets/content/bundle.json').readAsStringSync();
  return GameContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Состояние начала периода 1 с выбранной профессией и зарплатой.
GameState startPeriod(int period, GameContent c,
    {String professionId = 'courier', int balance = 0}) {
  var s = GameState.withPet(petName: 'Финни', fur: 'Оранжевый', ears: 'Круглые')
      .copyWith(period: period, balance: balance, phase: 'profession');
  final prof = c.professionById(professionId)!;
  s = engine.chooseProfession(s, prof, c);
  return s;
}

void main() {
  final content = loadContent();

  group('Счётчик развития (СР)', () {
    test('Все правила периода 1: максимум и кап 50', () {
      var s = startPeriod(1, content, balance: 100);
      // Планирование ДО покупок (нужное ≥ 60, коплю ≥ 20 → награда 15).
      final planResult = engine.applyPlan(
        s,
        const BasketValues(need: 60, want: 0, save: 20),
        content,
      );
      expect(planResult.blocked, isFalse);
      s = planResult.state;
      // Покупаем обязательные и копим по плану.
      for (final id in ['item_01', 'item_02', 'item_03']) {
        final item = content.shopItemById(id)!;
        final r = engine.purchaseItem(s, item, content);
        expect(r.success, isTrue);
        s = r.state;
      }
      s = engine.deposit(s, 20, content).state;
      s = engine.completeTaskReward(s, 'A2', 15, 'ок', content);

      final data = engine.computeResults(s, content);
      // mandatory 15 + plan≈fact 10 + savings 8 + task 5 = 38.
      expect(data.srEarned, 38);
      expect(data.srTotalAfter, 38);
    });

    test('Кап: не больше 50 за период', () {
      var s = startPeriod(3, content, balance: 130);
      s = engine.applyPlan(s, const BasketValues(need: 60, want: 40, save: 20), content).state;
      for (final id in ['item_01', 'item_02', 'item_03']) {
        s = engine.purchaseItem(s, content.shopItemById(id)!, content).state;
      }
      s = engine.deposit(s, 20, content).state;
      s = engine.purchaseItem(s, content.shopItemById('item_10')!, content).state;
      s = s.copyWith(hitrikResults: const ['hitrik_p3_social:resist']);
      s = engine.completeTaskReward(s, 'B1', 15, 'ок', content);

      final data = engine.computeResults(s, content);
      // 15+10+8+5+5+7 = 50 → кап 50.
      expect(data.srEarned, 50);
    });

    test('Переход стадий с учётом min_period', () {
      // СР 65 в периоде 1 — переход в «Подросток» заблокирован.
      var s = startPeriod(1, content).copyWith(sr: 65);
      var data = engine.computeResults(s, content);
      expect(data.stageAfter, 'baby');

      // Те же 65 в периоде 2 — переход разрешён.
      s = startPeriod(2, content).copyWith(sr: 65);
      data = engine.computeResults(s, content);
      expect(data.stageAfter, 'teen');

      // 120 до периода 4 — «Профи» заблокирован.
      s = startPeriod(3, content).copyWith(sr: 120);
      data = engine.computeResults(s, content);
      expect(data.stageAfter, isNot('pro'));

      s = startPeriod(4, content).copyWith(sr: 120);
      data = engine.computeResults(s, content);
      expect(data.stageAfter, 'pro');
    });
  });

  group('Откат времени', () {
    test('Сбрасывает баланс/покупки/план/факт; сохраняет СР/накопления/предметы', () {
      var s = startPeriod(2, content, balance: 100);
      s = engine.purchaseItem(s, content.shopItemById('item_09')!, content).state;
      s = engine.purchaseItem(s, content.shopItemById('item_01')!, content).state;
      s = engine.applyPlan(s, const BasketValues(need: 60, save: 20), content).state;
      s = engine.deposit(s, 20, content).state;
      s = s.copyWith(sr: 45);

      final rolled = engine.useRollback(s, content);
      expect(rolled.balance, 0);
      expect(rolled.periodPurchases, isEmpty);
      expect(rolled.plan.total, 0);
      expect(rolled.fact.total, 0);
      expect(rolled.savings, s.savings);
      expect(rolled.sr, 45);
      expect(rolled.ownsItem('item_09'), isTrue);
      expect(rolled.rollback.usedThisPeriod, isTrue);
      expect(rolled.rollback.totalUses, 1);
    });

    test('Доступен только с периода 2 и один раз', () {
      final p1 = startPeriod(1, content, balance: 50);
      expect(engine.useRollback(p1, content).rollback.totalUses, 0);

      var p2 = startPeriod(2, content, balance: 50);
      p2 = engine.useRollback(p2, content);
      expect(p2.rollback.usedThisPeriod, isTrue);
      expect(engine.useRollback(p2, content).rollback.totalUses, 1);
    });
  });

  group('Перки архетипов', () {
    test('Мечтатель: +10% к взносу в копилку', () {
      var s = startPeriod(2, content, balance: 100).copyWith(archetypeFixed: 'dreamer');
      final r = engine.deposit(s, 30, content);
      expect(r.error, isNull);
      expect(r.deposited, 33);
      expect(r.state.savings, 33);
      expect(r.state.balance, 70);
    });

    test('Исследователь: скидка 5 монет на один товар за период', () {
      var s = startPeriod(2, content, balance: 100).copyWith(archetypeFixed: 'explorer');
      final price = engine.itemPrice(content.shopItemById('item_05')!, s,
          useExplorerDiscount: true);
      expect(price, 25); // 30 − 5
      final r = engine.purchaseItem(s, content.shopItemById('item_05')!, content);
      expect(r.pricePaid, 25);
      // Повторная скидка в том же периоде не даётся.
      final price2 = engine.itemPrice(content.shopItemById('item_07')!, r.state,
          useExplorerDiscount: !r.state.explorerDiscountUsed);
      expect(price2, 20);
    });
  });

  group('Родительский бонус', () {
    test('Лимит 1..100 монет', () {
      expect(engine.validateParentBonus(0, content), isNotNull);
      expect(engine.validateParentBonus(101, content), isNotNull);
      expect(engine.validateParentBonus(50, content), isNull);
    });
  });

  group('Планирование (A1)', () {
    test('Нужное < 60 блокирует план с репликой', () {
      final s = startPeriod(1, content, balance: 100);
      final r = engine.applyPlan(s, const BasketValues(need: 40, save: 20), content);
      expect(r.blocked, isTrue);
      expect(r.blockLine, contains('60'));
      expect(r.state.completedTasks.contains('A1'), isFalse);
    });

    test('Награды по таблице A1', () {
      var s = startPeriod(1, content, balance: 100);
      var r = engine.applyPlan(s, const BasketValues(need: 60, save: 20), content);
      expect(r.reward, 15);
      expect(r.state.completedTasks.contains('A1'), isTrue);

      s = startPeriod(1, content, balance: 60);
      r = engine.applyPlan(s, const BasketValues(need: 60), content);
      expect(r.reward, 10);

      s = startPeriod(1, content, balance: 70);
      r = engine.applyPlan(s, const BasketValues(need: 60, save: 10), content);
      expect(r.reward, 12);
    });
  });

  group('Фазы периодов', () {
    test('Период 1 начинается с диалога и заканчивается итогами', () {
      final s = GameState.withPet(petName: 'Ф', fur: 'Оранжевый', ears: 'Круглые')
          .copyWith(professionId: 'courier');
      final phases = flow.buildFlow(s, content);
      expect(phases.first.kind, 'intro_dialog');
      expect(phases.last.kind, 'results');
      expect(phases.map((p) => p.kind), contains('profession'));
      expect(phases.map((p) => p.kind), contains('minigame'));
      expect(phases.map((p) => p.kind), isNot(contains('hitrik')));
    });

    test('Период 2: тур, Хитрик и события в потоке', () {
      final s = GameState.withPet(petName: 'Ф', fur: 'Оранжевый', ears: 'Круглые')
          .copyWith(period: 2, phase: 'tour', professionId: 'courier');
      final phases = flow.buildFlow(s, content);
      expect(phases.first.kind, 'tour');
      expect(phases.where((p) => p.kind == 'hitrik').length, 2);
      expect(phases.where((p) => p.kind == 'event').length, 2);
      expect(phases.indexWhere((p) => p.kind == 'salary'),
          lessThan(phases.indexWhere((p) => p.kind == 'hitrik' && p.id.contains('salary'))));
    });

    test('Пассивный доход появляется когда куплен источник', () {
      final noItems = GameState.withPet(petName: 'Ф', fur: 'Оранжевый', ears: 'Круглые')
          .copyWith(period: 3, professionId: 'courier');
      expect(flow.buildFlow(noItems, content).map((p) => p.kind),
          isNot(contains('passive_income')));

      final withBike = noItems.copyWith(ownedItems: const ['item_09']);
      expect(flow.buildFlow(withBike, content).map((p) => p.kind),
          contains('passive_income'));
    });

    test('advancePeriod: бонус за неиспользованный откат и сброс периодных полей', () {
      var s = GameState.withPet(petName: 'Ф', fur: 'Оранжевый', ears: 'Круглые')
          .copyWith(period: 2, phase: 'announce', professionId: 'courier', balance: 40);
      final next = flow.advancePeriod(s, content);
      expect(next.period, 3);
      expect(next.balance, 10); // 0 старт + 10 бонус
      expect(next.phase, isNot('announce'));
    });
  });

  group('События', () {
    test('Отложенные эффекты попадают в pendingEffects', () {
      final ev = content.events.firstWhere((e) => e.id == 'ev_2b');
      final optionA = ev.options.firstWhere((o) => o.id == 'a');
      final s = startPeriod(2, content, balance: 50);
      final r = engine.resolveEvent(s, ev, optionA, content);
      expect(r.coinsDelta, -20);
      expect(r.state.pendingEffects.any((e) => e.targetPeriod == 3 && e.coinsDelta == 25),
          isTrue);
    });

    test('Резерв покрывает расход → Ответственному +2', () {
      final ev = content.events.firstWhere((e) => e.id == 'ev_3a');
      final optionA = ev.options.firstWhere((o) => o.id == 'a');
      var s = startPeriod(3, content, balance: 100);
      s = s.copyWith(plan: const BasketValues(need: 60, want: 10, save: 10, reserve: 30));
      final r = engine.resolveEvent(s, ev, optionA, content);
      expect(r.state.reserveUsedByEvent, isTrue);
      expect(r.state.archetypeScores['responsible'], 5); // +3 за выбор, +2 за резерв
    });
  });

  group('Хитрик', () {
    test('Устоял: +монеты и пометка resist', () {
      final scene = content.hitrikScenes.firstWhere((h) => h.id == 'hitrik_p2_shop');
      final resist = scene.options.firstWhere((o) => o.correct);
      final s = startPeriod(2, content, balance: 50);
      final r = engine.resolveHitrik(s, scene, resist);
      expect(r.balance, 60);
      expect(r.hitrikResults.contains('hitrik_p2_shop:resist'), isTrue);
      expect(r.archetypeScores['explorer'], 3);
    });
  });
}
