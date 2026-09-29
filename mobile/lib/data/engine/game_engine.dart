import 'dart:math';

import '../models/content_bundle.dart';
import '../models/game_state.dart';
import 'phase_flow.dart';

/// Чистая игровая логика (без UI): деньги, СР, архетипы, откат, перки.
/// Все функции возвращают НОВОЕ состояние; записи в history — на каждое
/// изменение баланса (ТЗ 2.5.4).

// ---------- Профессии / доход ----------

/// Выбор профессии: перк Творца (+2) при творческой профессии.
GameState chooseProfession(GameState s, Profession p, GameContent c) {
  final changed = s.professionId != null && s.professionId != p.id;
  var next = s.copyWith(
    professionId: p.id,
    professionChanged: changed || s.professionId == null,
  );
  if (p.id == 'artist' || p.id == 'illustrator') {
    next = next.addArchetypePoints(const {'creator': 2});
  }
  return next.addHistory('Выбрана профессия «${p.name}» (зарплата ${p.salary} монет).');
}

/// Зарплата по профессии (+10 если куплен абонемент в спортзал item_13).
({GameState state, int amount}) accrueSalary(GameState s, GameContent c) {
  final profession = c.professionById(s.professionId);
  if (profession == null) return (state: s, amount: 0);
  var amount = profession.salary;
  if (s.ownsItem('item_13')) amount += 10;
  final next = s.copyWith(balance: s.balance + amount).addHistory(
        'Зарплата за работу «${profession.name}»: +$amount монет.',
      );
  return (state: next, amount: amount);
}

/// Источники пассивного дохода (владение предметами из economy.passive_income).
List<(ShopItem, int)> passiveIncomeSources(GameState s, GameContent c) {
  final result = <(ShopItem, int)>[];
  for (final source in c.economy.passiveIncome.sources) {
    if (s.ownsItem(source.itemId)) {
      final item = c.shopItemById(source.itemId);
      if (item != null) result.add((item, source.coinsPerPeriod));
    }
  }
  return result;
}

({GameState state, int total}) accruePassiveIncome(GameState s, GameContent c) {
  final sources = passiveIncomeSources(s, c);
  final total = sources.fold<int>(0, (sum, e) => sum + e.$2);
  if (total <= 0) return (state: s, total: total);
  final next = s.copyWith(balance: s.balance + total).addHistory(
        'Пассивный доход: +$total монет.',
      );
  return (state: next, total: total);
}

// ---------- Магазин ----------

class PurchaseResult {
  final GameState state;
  final String? error;
  final int pricePaid;
  final String feedbackLine;

  const PurchaseResult({
    required this.state,
    required this.pricePaid,
    required this.feedbackLine,
    this.error,
  });

  bool get success => error == null;
}

/// Блокировка по периоду отключена (MVP): весь ассортимент доступен
/// сразу, серая ячейка в макете означает «нет в наличии», а не
/// «откроется позже». Функцию сохраняем — фильтр магазина и проверка
/// в purchaseItem используют одну точку, вернём периодность позже.
bool isItemLocked(ShopItem item, GameState s) => false;

/// Финальная цена с учётом скидки магазина (события) и перка Творца
/// (аксессуары −10). Перк Исследователя (−5 на один товар) применяется
/// при покупке (см. purchaseItem).
int itemPrice(ShopItem item, GameState s, {bool useExplorerDiscount = false}) {
  var price = item.price + s.shopDiscount;
  if (s.archetypeFixed == 'creator' && item.category == 'Украшение') {
    price -= 10;
  }
  if (useExplorerDiscount && s.archetypeFixed == 'explorer') {
    price -= 5;
  }
  return price < 0 ? 0 : price;
}

/// Триггер встроенного задания C2: покупка необязательного до первого
/// обязательного расхода периода.
bool shouldTriggerC2(GameState s, ShopItem item, GameContent c) {
  if (item.type != ShopItemType.optional) return false;
  final mandatoryIds = c.economy.mandatoryItems.map((e) => e.itemId).toSet();
  return !s.periodPurchases.any(mandatoryIds.contains);
}

/// «Сначала нужное» в C2: +8 монет.
GameState resolveShopC2(GameState s) => s
    .copyWith(balance: s.balance + 8)
    .addHistory('Задание C2: выбрал «сначала нужное»: +8 монет.');

/// Сравнение товаров перед покупкой (первая карточка товара за период)
/// — очки Исследователю.
GameState noteItemCompared(GameState s) {
  if (s.explorerDiscountUsed) return s;
  return s
      .addArchetypePoints(const {'explorer': 3})
      .copyWith(explorerDiscountUsed: true);
}

PurchaseResult purchaseItem(GameState s, ShopItem item, GameContent c) {
  final feedback = c.economy.purchaseFeedback;
  if (isItemLocked(item, s)) {
    return PurchaseResult(
      state: s,
      pricePaid: 0,
      feedbackLine: item.lockLabel ?? 'Откроется позже',
      error: item.lockLabel ?? 'Этот товар ещё недоступен',
    );
  }
  // Одноразовые предметы (всё кроме обязательных расходов).
  if (item.type != ShopItemType.mandatory && s.ownsItem(item.id)) {
    return PurchaseResult(
      state: s,
      pricePaid: 0,
      feedbackLine: 'Уже куплено',
      error: '«${item.name}» уже куплено — оно твоё!',
    );
  }

  final useExplorer = !s.explorerDiscountUsed;
  final price = itemPrice(item, s, useExplorerDiscount: useExplorer);
  if (s.balance < price) {
    final missing = price - s.balance;
    final line = feedback.notEnoughCoins.replaceAll('{n}', '$missing');
    return PurchaseResult(
      state: s,
      pricePaid: price,
      feedbackLine: line,
      error: line,
    );
  }

  var next = s.copyWith(
    balance: s.balance - price,
    // Настроение не поднимается покупками: сытость/прочее — по effects,
    // mood — только от заданий, дорожки, леса и первой еды (см. UI).
    pet: s.pet.withEffects(
      item.effects.map((k, v) => MapEntry(k, k == 'mood' ? 0 : v)),
    ),
    periodPurchases: [...s.periodPurchases, item.id],
    explorerDiscountUsed: useExplorer && s.archetypeFixed == 'explorer'
        ? true
        : s.explorerDiscountUsed,
  );

  // Факт по корзинам.
  next = next.copyWith(
    fact: item.type == ShopItemType.mandatory
        ? next.fact.copyWith(need: next.fact.need + price)
        : next.fact.copyWith(want: next.fact.want + price),
  );

  // Одноразовые предметы → владение + разблокировки.
  if (item.type != ShopItemType.mandatory) {
    next = next.copyWith(ownedItems: [...next.ownedItems, item.id]);
    // Аксессуары.
    const accessoryByItem = {'item_06': 'bow', 'item_20': 'trophy'};
    final accessory = accessoryByItem[item.id];
    if (accessory != null) {
      next = next.copyWith(
        pet: next.pet.copyWith(
          appearance: next.pet.appearance.copyWith(accessory: accessory),
        ),
      ).addArchetypePoints(const {'creator': 2});
    }
    // Курсы — очки Исследователю.
    if (item.category == 'Обучение') {
      next = next.addArchetypePoints(const {'explorer': 2});
    }
  }

  // Обязательная покупка: «Спасибо! {показатель} в порядке» — плейсхолдер
  // заменяем названием показателя из эффектов товара (сытость, здоровье…).
  var line = item.type == ShopItemType.mandatory
      ? feedback.mandatoryBought
      : feedback.optionalBought;
  if (item.type == ShopItemType.mandatory && line.contains('{показатель}')) {
    const statLabels = {
      'satiety': 'Сытость',
      'cleanliness': 'Чистота',
      'health': 'Здоровье',
      'mood': 'Настроение',
      'comfort': 'Комфорт',
      'intellect': 'Умность',
    };
    final key = item.effects.isEmpty ? null : item.effects.keys.first;
    final label = key == null ? 'Покупка' : (statLabels[key] ?? key);
    line = line.replaceAll('{показатель}', label);
  }
  next = next.addHistory('Куплено «${item.name}» за $price монет.');
  return PurchaseResult(state: next, pricePaid: price, feedbackLine: line);
}

// ---------- Планирование ----------

class PlanResult {
  final GameState state;
  final bool blocked;
  final String? blockLine;
  final int reward;
  final String rewardLine;

  const PlanResult({
    required this.state,
    required this.blocked,
    required this.reward,
    required this.rewardLine,
    this.blockLine,
  });
}

/// Сохранение плана с встроенным заданием A1 (нужное ≥ 60).
PlanResult applyPlan(GameState s, BasketValues plan, GameContent c) {
  final mandatoryTotal = c.economy.mandatoryTotalPerPeriod;
  final taskA1 = c.taskByCode('A1');

  if (plan.total > s.balance) {
    return PlanResult(
      state: s,
      blocked: true,
      blockLine: 'Сумма плана (${plan.total}) больше баланса (${s.balance}). '
          'Поправь распределение.',
      reward: 0,
      rewardLine: '',
    );
  }
  if (plan.need < mandatoryTotal) {
    return PlanResult(
      state: s,
      blocked: true,
      blockLine: taskA1?.data['trigger_line']
              ?.toString()
              .replaceAll('{n}', '${plan.need}') ??
          'Нужно минимум $mandatoryTotal монет на обязательное.',
      reward: 0,
      rewardLine: '',
    );
  }

  // Награды A1.
  var reward = 0;
  var line = '';
  if (plan.save >= 20) {
    reward = 15;
    line = 'Отличный план! Нужное закрыто, копилка не пустая';
  } else if (plan.save == 0) {
    reward = 10;
    line = 'Нужное закрыто — хорошо. Но копилка пустая. Отложишь хоть немного?';
  } else {
    reward = 12;
    line = 'Неплохо! Маленький взнос — но уже начало';
  }

  var next = s.copyWith(
    plan: plan,
    balance: s.balance + reward,
    completedTasks: s.completedTasks.contains('A1')
        ? s.completedTasks
        : [...s.completedTasks, 'A1'],
  );
  next = next.addHistory('План на период ${s.period}: нужное ${plan.need}, '
      'хочу ${plan.want}, коплю ${plan.save}${plan.reserve > 0 ? ', резерв ${plan.reserve}' : ''}.');
  if (reward > 0) {
    next = next.addHistory('Награда за планирование (задание A1): +$reward монет.');
  }
  return PlanResult(state: next, blocked: false, reward: reward, rewardLine: line);
}

// ---------- Копилка ----------

class DepositResult {
  final GameState state;
  final String? error;
  final int deposited; // фактически зачислено (с перком Мечтателя)
  final String reactionLine;

  const DepositResult({
    required this.state,
    required this.deposited,
    required this.reactionLine,
    this.error,
  });
}

/// Проверка лимита родительского бонуса (1..100 по контракту).
String? validateParentBonus(int amount, GameContent c) {
  final rules = c.economy.parentBonus;
  if (amount < rules.minAmount || amount > rules.maxAmount) {
    return 'Сумма от ${rules.minAmount} до ${rules.maxAmount} монет.';
  }
  return null;
}

/// Пополнение копилки. Перк Мечтателя: +10% к взносу.
DepositResult deposit(GameState s, int amount, GameContent c) {
  if (amount <= 0) {
    return DepositResult(
      state: s,
      deposited: 0,
      reactionLine: '',
      error: 'Выбери сумму больше нуля.',
    );
  }
  if (amount > s.balance) {
    return DepositResult(
      state: s,
      deposited: 0,
      reactionLine: '',
      error: 'На балансе только ${s.balance} монет.',
    );
  }
  var credited = amount;
  if (s.archetypeFixed == 'dreamer') {
    credited = (amount * 1.1).round();
  }
  var next = s.copyWith(
    balance: s.balance - amount,
    savings: s.savings + credited,
    goalSaved: s.goalId == null ? s.goalSaved : s.goalSaved + credited,
    fact: s.fact.copyWith(save: s.fact.save + amount),
  );
  // Архетип: взнос > 20 → Мечтателю.
  if (amount > 20) {
    next = next.addArchetypePoints(const {'dreamer': 3});
  }
  next = next.addHistory('В копилку положено $amount монет'
      '${credited > amount ? ' (перк Мечтателя: зачислено $credited)' : ''}.');

  String line = '';
  for (final r in c.economy.savingsDepositReactions) {
    if (r.matches(amount)) {
      line = r.line;
      break;
    }
  }
  return DepositResult(state: next, deposited: credited, reactionLine: line);
}

/// Снятие из копилки (после подтверждения в UI).
({GameState state, String? error}) withdraw(GameState s, int amount) {
  if (amount <= 0) return (state: s, error: 'Выбери сумму больше нуля.');
  if (amount > s.savings) {
    return (state: s, error: 'В копилке только ${s.savings} монет.');
  }
  final goalSaved = s.goalSaved - amount < 0 ? 0 : s.goalSaved - amount;
  final next = s.copyWith(
    balance: s.balance + amount,
    savings: s.savings - amount,
    goalSaved: goalSaved,
  ).addHistory('Из копилки снято $amount монет.');
  return (state: next, error: null);
}

/// Отказ от снятия (подтверждение закрыто кнопкой «Оставить») → Мечтателю.
GameState declineWithdraw(GameState s) =>
    s.addArchetypePoints(const {'dreamer': 2}).addHistory('Отказался снимать деньги из копилки.');

/// Выбор цели: goal_01 → Мечтателю +2; разблокировка аксессуара цели.
GameState selectGoal(GameState s, GoalItem? goal, GameContent c) {
  var next = s.copyWith(
    goalId: goal?.id,
    // Накопленное в копилке сразу идёт в прогресс новой цели
    // (ребёнок копил до выбора цели — деньги не теряются).
    goalSaved: goal == null
        ? 0
        : s.goalId == goal.id
            ? s.goalSaved
            : s.savings.clamp(0, goal.cost),
  );
  if (goal == null) return next;
  if (goal.id == 'goal_01') {
    next = next.addArchetypePoints(const {'dreamer': 2});
    next = next.copyWith(
      pet: next.pet.copyWith(
        appearance: next.pet.appearance.copyWith(accessory: 'helmet'),
      ),
    );
  }
  if (goal.id == 'goal_03') {
    next = next.copyWith(
      pet: next.pet.copyWith(
        appearance: next.pet.appearance.copyWith(accessory: 'party_hat'),
      ),
    );
  }
  return next.addHistory('Цель выбрана: «${goal.name}» (${goal.cost} монет).');
}

// ---------- Хитрик / события ----------

GameState resolveHitrik(GameState s, HitrikScene scene, SceneOption option) {
  var next = s.copyWith(
    balance: max(0, s.balance + option.coinsDelta),
    hitrikResults: [...s.hitrikResults, '${scene.id}:${option.correct ? 'resist' : 'buy'}'],
  ).addArchetypePoints(option.archetypePoints);
  final text = option.consequence ?? option.reaction ?? '';
  next = next.addHistory(
    'Хитрик («${scene.trigger}»): ${option.text} → $text (${option.coinsDelta >= 0 ? '+' : ''}${option.coinsDelta} монет).',
  );
  return next;
}

class EventResolution {
  final GameState state;
  final String outcomeText;
  final int coinsDelta;

  const EventResolution({
    required this.state,
    required this.outcomeText,
    required this.coinsDelta,
  });
}

EventResolution resolveEvent(
  GameState s,
  GameEvent event,
  SceneOption option,
  GameContent c,
) {
  var coins = option.coinsDelta;
  var outcome = option.outcome ?? option.reaction ?? '';

  // Ярмарка (период 5): исход зависит от архетипа.
  final byArchetype = option.extras['outcomes_by_archetype'];
  if (byArchetype is Map) {
    final archetypeId = s.archetypeFixed ?? currentLeader(s, c) ?? 'responsible';
    final outcomeDef = byArchetype[archetypeId];
    if (outcomeDef is Map) {
      final range = outcomeDef['coins_range'];
      if (range is List && range.length == 2) {
        coins = Random().nextInt((range[1] as num).toInt() - (range[0] as num).toInt() + 1) +
            (range[0] as num).toInt();
      } else {
        coins = (outcomeDef['coins'] as num?)?.toInt() ?? 0;
      }
      if (outcomeDef['note'] != null) outcome = '${outcomeDef['note']}';
    }
    final investment = (option.extras['investment'] as num?)?.toInt() ?? 0;
    coins -= investment;
  }

  // Перк Авантюриста: турнир (ev_4a) без подготовки → победа.
  if (event.id == 'ev_4a' && option.id == 'a' && s.archetypeFixed == 'adventurer') {
    coins = 45; // −15 + 60
    outcome = 'Перк Авантюриста: победа без подготовки! +45 монет';
  }

  var next = s.copyWith(
    balance: max(0, s.balance + coins),
    resolvedEventIds: [...s.resolvedEventIds, event.id],
  ).addArchetypePoints(option.archetypePoints);

  // Резерв покрыл расход → Ответственному.
  if (coins < 0 && s.plan.reserve >= -coins) {
    next = next
        .copyWith(reserveUsedByEvent: true)
        .addArchetypePoints(const {'responsible': 2});
  }

  // Отложенные эффекты.
  final pending = [
    ...next.pendingEffects,
    ...option.delayedEffects.map(
      (e) => PendingEffect(
        targetPeriod: e.absolutePeriod ?? (event.period + e.periods),
        coinsDelta: e.coinsDelta,
        source: event.title,
      ),
    ),
  ];
  next = next.copyWith(pendingEffects: pending);

  next = next.addHistory(
    'Событие «${event.title}»: ${option.text} → $outcome (${coins >= 0 ? '+' : ''}$coins монет).',
  );
  final petLine = event.petLine?.replaceAll('{архетип}',
          c.archetypeById(s.archetypeFixed)?.name ?? currentLeaderName(s, c) ?? '') ??
      '';
  if (petLine.isNotEmpty) {
    next = next.addHistory(petLine);
  }
  return EventResolution(state: next, outcomeText: outcome, coinsDelta: coins);
}

// ---------- Задания ----------

/// Начисление награды за задание (общая механика).
GameState completeTaskReward(GameState s, String code, int reward, String line, GameContent c) {
  if (s.completedTasks.contains(code)) return s;
  var next = s.copyWith(
    balance: s.balance + reward,
    completedTasks: [...s.completedTasks, code],
  );
  if (reward > 0) {
    next = next.addHistory('Задание «$code»: $line (+$reward монет).');
  } else {
    next = next.addHistory('Задание «$code»: $line.');
  }
  return next;
}

// ---------- Итоги периода ----------

class SrBreakdownEntry {
  final DevScoreRule rule;
  final bool earned;

  const SrBreakdownEntry({required this.rule, required this.earned});
}

class ResultsData {
  final List<SrBreakdownEntry> srBreakdown;
  final int srEarned; // уже с капом max_per_period
  final bool mandatoryAllClosed;
  final String? missedMandatoryName;
  final bool planMatchesFact;
  final bool savingsPositive;
  final bool taskCompletedThisPeriod;
  final bool resistedHitrikThisPeriod;
  final bool courseBoughtThisPeriod;
  final String? stageBefore;
  final String? stageAfter;
  final bool stageChanged;
  final String? archetypeLeader;
  final String? archetypeFixedNow;
  final Archetype? perkActivated;
  final bool rollbackAvailable;
  final int responsibleCashback;
  final bool ironWillAward;
  final int srTotalAfter;

  const ResultsData({
    required this.srBreakdown,
    required this.srEarned,
    required this.mandatoryAllClosed,
    required this.missedMandatoryName,
    required this.planMatchesFact,
    required this.savingsPositive,
    required this.taskCompletedThisPeriod,
    required this.resistedHitrikThisPeriod,
    required this.courseBoughtThisPeriod,
    required this.stageBefore,
    required this.stageAfter,
    required this.stageChanged,
    required this.archetypeLeader,
    required this.archetypeFixedNow,
    required this.perkActivated,
    required this.rollbackAvailable,
    required this.responsibleCashback,
    required this.ironWillAward,
    required this.srTotalAfter,
  });
}

String? currentLeader(GameState s, GameContent c) {
  if (s.archetypeScores.isEmpty) return null;
  final order = c.archetypes.map((a) => a.id).toList();
  var leaderId = order.first;
  var best = -1;
  for (final id in order) {
    final v = s.archetypeScores[id] ?? 0;
    if (v > best) {
      best = v;
      leaderId = id;
    }
  }
  return best > 0 ? leaderId : null;
}

String? currentLeaderName(GameState s, GameContent c) =>
    c.archetypeById(currentLeader(s, c))?.name;

/// Высчитать итоги периода (без применения).
ResultsData computeResults(GameState s, GameContent c) {
  final devScore = c.economy.devScore;
  final def = c.periodDef(s.period);

  // Обязательные расходы периода (базовые позиции economy.mandatory_expenses).
  final mandatoryIds = c.economy.mandatoryItems.map((e) => e.itemId).toList();
  final missedId = mandatoryIds.where((id) => !s.boughtThisPeriod(id)).firstOrNull;
  final mandatoryAllClosed = missedId == null;
  final missedName = missedId == null ? null : c.shopItemById(missedId)?.name;

  // Факт ≈ план (±10%) по сумме корзин.
  final planTotal = s.plan.total;
  final factTotal = s.fact.total;
  final planMatchesFact = planTotal > 0 &&
      (factTotal - planTotal).abs() <= (planTotal * 0.1).ceil();
  final savingsPositive = s.fact.save > 0;
  final taskCompletedThisPeriod =
      c.tasks.any((t) => t.period == s.period && s.completedTasks.contains(t.code));
  final resistedHitrikThisPeriod = s.hitrikResults
      .any((r) => r.endsWith(':resist') && c.hitrikScenes.any(
          (h) => h.period == s.period && r.startsWith('${h.id}:')));
  final courseBoughtThisPeriod = s.periodPurchases.any((id) {
    final item = c.shopItemById(id);
    return item != null && item.category == 'Обучение';
  });

  final conditions = <String, bool>{
    'mandatory_closed': mandatoryAllClosed,
    'fact_matches_plan': planMatchesFact,
    'savings_positive': savingsPositive,
    'task_completed': taskCompletedThisPeriod,
    'resisted_hitrik': resistedHitrikThisPeriod,
    'course_bought': courseBoughtThisPeriod,
  };

  final breakdown = <SrBreakdownEntry>[
    for (final rule in devScore.rules)
      SrBreakdownEntry(
        rule: rule,
        earned: s.period >= rule.fromPeriod && (conditions[rule.id] ?? false),
      ),
  ];
  final rawSum = breakdown.where((e) => e.earned).fold<int>(0, (sum, e) => sum + e.rule.points);
  final srEarned = rawSum > devScore.maxPerPeriod ? devScore.maxPerPeriod : rawSum;

  // Стадия с учётом min_period.
  String? stageFor(int srValue, int period) {
    StageDef? best;
    for (final stage in devScore.stages) {
      if (srValue < stage.scoreMin) continue;
      if (stage.scoreMax != null && srValue > stage.scoreMax!) continue;
      if (period < stage.minPeriod) continue;
      best = stage;
    }
    return best?.id;
  }

  final srAfter = s.sr + srEarned;
  final stageBefore = stageFor(s.sr, s.period) ?? s.srStage;
  final stageAfter = stageFor(srAfter, s.period) ?? s.srStage;

  // Архетип: лидер периода + фиксация при доминировании N периодов.
  final leader = def.archetypeScalesActive ? currentLeader(s, c) : null;
  final history = [...s.archetypeHistory, ?leader];
  String? fixedNow = s.archetypeFixed;
  final dominance = c.archetypeRules.dominancePeriods;
  if (fixedNow == null && leader != null && history.length >= dominance) {
    final tail = history.sublist(history.length - dominance);
    if (tail.every((id) => id == leader)) {
      fixedNow = leader;
    }
  }

  final rules = c.economy.rollback;
  final rollbackAvailable =
      def.hasRollback && s.period >= rules.availableFromPeriod && !s.rollback.usedThisPeriod;

  final responsibleCashback =
      s.archetypeFixed == 'responsible' && mandatoryAllClosed ? 5 : 0;

  final ironWillAward = s.period == 5 && s.rollback.totalUses == 0 && !s.crownAwarded;

  return ResultsData(
    srBreakdown: breakdown,
    srEarned: srEarned,
    mandatoryAllClosed: mandatoryAllClosed,
    missedMandatoryName: missedName,
    planMatchesFact: planMatchesFact,
    savingsPositive: savingsPositive,
    taskCompletedThisPeriod: taskCompletedThisPeriod,
    resistedHitrikThisPeriod: resistedHitrikThisPeriod,
    courseBoughtThisPeriod: courseBoughtThisPeriod,
    stageBefore: stageBefore,
    stageAfter: stageAfter,
    stageChanged: stageBefore != stageAfter,
    archetypeLeader: leader,
    archetypeFixedNow: fixedNow,
    perkActivated: fixedNow != null && fixedNow != s.archetypeFixed
        ? c.archetypeById(fixedNow)
        : null,
    rollbackAvailable: rollbackAvailable,
    responsibleCashback: responsibleCashback,
    ironWillAward: ironWillAward,
    srTotalAfter: srAfter,
  );
}

/// Применить итоги периода.
GameState applyResults(GameState s, GameContent c, ResultsData data) {
  var next = s.copyWith(
    sr: data.srTotalAfter,
    srStage: data.stageAfter ?? s.srStage,
    archetypeHistory: [
      ...s.archetypeHistory,
      if (data.archetypeLeader != null) data.archetypeLeader!,
    ],
    archetypeFixed: data.archetypeFixedNow,
  );
  if (data.srEarned > 0) {
    next = next.addHistory('Счётчик развития: +${data.srEarned} (итого ${data.srTotalAfter}).');
  }
  if (data.stageChanged && data.stageAfter != null) {
    final stageName =
        c.economy.devScore.stages.firstWhere((e) => e.id == data.stageAfter).name;
    next = next.addHistory('Финни вырос: новая стадия «$stageName»! 🎉');
  }
  if (data.responsibleCashback > 0) {
    next = next.copyWith(balance: next.balance + data.responsibleCashback).addHistory(
          'Перк Ответственного: кешбэк +${data.responsibleCashback} монет.',
        );
  }
  if (data.ironWillAward) {
    next = next
        .copyWith(
          balance: next.balance + c.economy.rollback.noRollbackBonusCoins,
          crownAwarded: true,
          pet: next.pet.copyWith(
            appearance: next.pet.appearance.copyWith(
              accessory: c.economy.rollback.noRollbackAccessory,
            ),
          ),
        )
        .addHistory(
          '«Железная воля»: 5 периодов без отката! +${c.economy.rollback.noRollbackBonusCoins} монет и аксессуар ${c.economy.rollback.noRollbackAccessoryEmoji}.',
        );
  }
  return next;
}

// ---------- Откат времени ----------

/// Откат периода: сброс баланса/покупок/плана/факта; сохранение СР,
/// накоплений, архетипов, предметов и последствий событий.
GameState useRollback(GameState s, GameContent c) {
  final rules = c.economy.rollback;
  final def = c.periodDef(s.period);
  if (!def.hasRollback || s.period < rules.availableFromPeriod || s.rollback.usedThisPeriod) {
    return s;
  }
  final flow = buildFlow(s, c);
  final restartPhase = flow.indexWhere((p) => p.kind == 'profession') >= 0
      ? 'profession'
      : flow.first.id;
  return s
      .copyWith(
        phase: restartPhase,
        balance: def.startBalance,
        plan: const BasketValues(),
        fact: const BasketValues(),
        periodPurchases: const [],
        reserveUsedByEvent: false,
        explorerDiscountUsed: false,
        shopDiscount: 0,
        rollback: s.rollback.copyWith(
          usedThisPeriod: true,
          usedPeriods: [...s.rollback.usedPeriods, s.period],
          totalUses: s.rollback.totalUses + 1,
        ),
      )
      .addHistory('Откат времени: период ${s.period} начат заново.');
}
