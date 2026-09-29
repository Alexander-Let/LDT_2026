import '../models/content_bundle.dart';
import '../models/game_state.dart';

/// Фаза периода. id — уникален внутри периода ('hitrik:hitrik_p2_shop',
/// 'event:ev_2a'), kind — тип экрана, refId — id сцены/события.
class Phase {
  final String id;
  final String kind;
  final String? refId;

  const Phase(this.id, this.kind, [this.refId]);
}

/// Порядок фаз периода (конечный автомат движка).
/// Период 1: intro_dialog → profession → course → interview → minigame →
/// salary → planning → shop → savings → tasks → results.
/// Периоды 2–5: passive_income (если есть источники) → tour (период 2) →
/// profession → course?/interview? (при смене профессии) → minigame → salary →
/// hitrik «после зарплаты» → события → planning → hitrik «в магазине» →
/// shop → savings → tasks → results.
List<Phase> buildFlow(GameState s, GameContent c) {
  final def = c.periodDef(s.period);
  final phases = <Phase>[];

  if (s.period == 1) phases.add(const Phase('intro_dialog', 'intro_dialog'));

  final sources = c.economy.passiveIncome.sources
      .where((src) => s.ownsItem(src.itemId) && src.coinsPerPeriod > 0);
  if (sources.isNotEmpty) phases.add(const Phase('passive_income', 'passive_income'));

  if (s.period == 2) phases.add(const Phase('tour', 'tour'));

  phases.add(const Phase('profession', 'profession'));

  final profession = c.professionById(s.professionId);
  final showCourse = profession != null &&
      (s.period == 1 || s.professionChanged) &&
      profession.course.screens.isNotEmpty;
  if (showCourse) {
    phases.add(const Phase('course', 'course'));
  }
  if (profession != null &&
      (s.period == 1 || s.professionChanged) &&
      profession.interview.options.isNotEmpty) {
    phases.add(const Phase('interview', 'interview'));
  }

  if (profession != null) phases.add(const Phase('minigame', 'minigame'));
  phases.add(const Phase('salary', 'salary'));

  // Хитрик «после зарплаты» (и финальный испытания без привязки к магазину).
  for (final scene in c.hitrikScenes) {
    if (scene.period != s.period) continue;
    if (s.hitrikResults.any((r) => r.startsWith('${scene.id}:'))) continue;
    if (!scene.trigger.contains('агазин')) {
      phases.add(Phase('hitrik:${scene.id}', 'hitrik', scene.id));
    }
  }

  // Случайные события периода (не разрешённые ранее).
  var eventsLeft = def.randomEventsCount;
  for (final ev in c.events) {
    if (eventsLeft <= 0) break;
    if (ev.period != s.period) continue;
    if (s.resolvedEventIds.contains(ev.id)) continue;
    phases.add(Phase('event:${ev.id}', 'event', ev.id));
    eventsLeft--;
  }

  phases.add(const Phase('planning', 'planning'));

  // Хитрик «в магазине» — перед покупками.
  for (final scene in c.hitrikScenes) {
    if (scene.period != s.period) continue;
    if (s.hitrikResults.any((r) => r.startsWith('${scene.id}:'))) continue;
    if (scene.trigger.contains('агазин')) {
      phases.add(Phase('hitrik:${scene.id}', 'hitrik', scene.id));
    }
  }

  phases
    ..add(const Phase('shop', 'shop'))
    ..add(const Phase('savings', 'savings'))
    ..add(const Phase('tasks', 'tasks'))
    ..add(const Phase('results', 'results'));
  return phases;
}

/// Переход к следующей фазе. После 'results' → 'announce' (или 'finale'
/// в периоде 5); после 'announce' → новый период; после 'finale' → 'done'.
GameState advancePhase(GameState s, GameContent c) {
  if (s.phase == 'results') {
    return s.copyWith(phase: s.period >= 5 ? 'finale' : 'announce');
  }
  if (s.phase == 'announce') return advancePeriod(s, c);
  if (s.phase == 'finale') return s.copyWith(phase: 'done');

  final flow = buildFlow(s, c);
  final index = flow.indexWhere((p) => p.id == s.phase);
  if (index < 0) {
    // Фаза не найдена (например, профессия не выбрана) — идём к первой подходящей.
    return s.copyWith(phase: flow.first.id);
  }
  if (index + 1 >= flow.length) {
    return s.copyWith(phase: 'results');
  }
  return s.copyWith(phase: flow[index + 1].id);
}

/// Начало нового периода: стартовый баланс, отложенные эффекты событий,
/// бонус за неиспользованный откат, сброс периодных полей.
GameState advancePeriod(GameState s, GameContent c) {
  if (s.period >= 5) return s.copyWith(phase: 'finale');

  final nextPeriod = s.period + 1;
  final nextDef = c.periodDef(nextPeriod);
  var next = s.copyWith(
    period: nextPeriod,
    balance: nextDef.startBalance,
    plan: const BasketValues(),
    fact: const BasketValues(),
    periodPurchases: const [],
    reserveUsedByEvent: false,
    explorerDiscountUsed: false,
    professionChanged: false,
    shopDiscount: 0,
    rollback: s.rollback.copyWith(usedThisPeriod: false),
  );

  // Отложенные эффекты событий, назначенные на этот период.
  final applyNow = next.pendingEffects.where((e) => e.targetPeriod == nextPeriod).toList();
  if (applyNow.isNotEmpty) {
    for (final e in applyNow) {
      next = next.copyWith(balance: next.balance + e.coinsDelta).addHistory(
            e.coinsDelta >= 0
                ? 'Событие «${e.source}»: +${e.coinsDelta} монет (обещанное возвращение).'
                : 'Событие «${e.source}»: ${e.coinsDelta} монет (отложенные последствия).',
          );
    }
    next = next.copyWith(
      pendingEffects:
          next.pendingEffects.where((e) => e.targetPeriod != nextPeriod).toList(),
    );
  }

  // Бонус за неиспользованный откат.
  final rules = c.economy.rollback;
  final def = c.periodDef(s.period);
  if (def.hasRollback &&
      s.period >= rules.availableFromPeriod &&
      !s.rollback.usedThisPeriod) {
    next = next.copyWith(balance: next.balance + rules.unusedBonusCoins).addHistory(
          'Откат не использован в периоде ${s.period}: +${rules.unusedBonusCoins} монет.',
        );
  }

  final flow = buildFlow(next, c);
  return next.copyWith(phase: flow.first.id);
}

/// Демо-режим: прыжок к итогам периода.
GameState jumpToResults(GameState s) => s.copyWith(phase: 'results');
