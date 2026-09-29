/// Игровое состояние v2 (schema: 2). Серверу непрозрачно — формат наш.
///
/// Миграция из v1: при чтении старого state (schema 1) поля переносятся
/// в новую структуру с дефолтами (питомец сохраняется, баланс/копилка —
/// тоже; игровой прогресс по периодам начинается с нуля).
library;

const Object _undefined = Object();

int clampStat(int value) => value.clamp(0, 100).toInt();

// ---------- Питомец ----------

class PetAppearance {
  final String fur; // Оранжевый | Синий | Зелёный
  final String ears; // Круглые | Острые | Висячие
  final String? accessory; // null | bow | helmet | party_hat | crown | trophy

  /// Путь к арту персонажа (см. core/pet_skins.dart). null — первый скин.
  final String? skin;

  const PetAppearance({required this.fur, required this.ears, this.accessory, this.skin});

  factory PetAppearance.fromJson(Map<String, dynamic> json) => PetAppearance(
        fur: json['fur'] as String? ?? 'Оранжевый',
        ears: json['ears'] as String? ?? 'Круглые',
        accessory: json['accessory'] as String?,
        skin: json['skin'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'fur': fur,
        'ears': ears,
        'accessory': accessory,
        'skin': skin,
      };

  PetAppearance copyWith({String? fur, String? ears, Object? accessory = _undefined, Object? skin = _undefined}) =>
      PetAppearance(
        fur: fur ?? this.fur,
        ears: ears ?? this.ears,
        accessory: identical(accessory, _undefined) ? this.accessory : accessory as String?,
        skin: identical(skin, _undefined) ? this.skin : skin as String?,
      );
}

class PetState {
  final String name;
  final PetAppearance appearance;

  /// Характер (выбор на жёлтом слайде «Каким он(она) будет»), например "3-2-4".
  final String? character;

  /// Шесть показателей 0..100 (ТЗ).
  final int satiety;
  final int cleanliness;
  final int health;
  final int mood;
  final int comfort;
  final int intellect;

  const PetState({
    required this.name,
    required this.appearance,
    this.character,
    required this.satiety,
    required this.cleanliness,
    required this.health,
    required this.mood,
    required this.comfort,
    required this.intellect,
  });

  factory PetState.fromJson(Map<String, dynamic> json) => PetState(
        name: json['name'] as String? ?? 'Финни',
        appearance: json['appearance'] is Map
            ? PetAppearance.fromJson((json['appearance'] as Map).cast<String, dynamic>())
            : const PetAppearance(fur: 'Оранжевый', ears: 'Круглые'),
        character: json['character'] as String?,
        satiety: clampStat((json['satiety'] as num?)?.toInt() ?? 50),
        cleanliness: clampStat((json['cleanliness'] as num?)?.toInt() ?? 50),
        health: clampStat((json['health'] as num?)?.toInt() ?? 50),
        mood: clampStat((json['mood'] as num?)?.toInt() ?? 50),
        comfort: clampStat((json['comfort'] as num?)?.toInt() ?? 50),
        intellect: clampStat((json['intellect'] as num?)?.toInt() ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'appearance': appearance.toJson(),
        'character': character,
        'satiety': satiety,
        'cleanliness': cleanliness,
        'health': health,
        'mood': mood,
        'comfort': comfort,
        'intellect': intellect,
      };

  PetState copyWith({
    String? name,
    PetAppearance? appearance,
    String? character,
    int? satiety,
    int? cleanliness,
    int? health,
    int? mood,
    int? comfort,
    int? intellect,
  }) =>
      PetState(
        name: name ?? this.name,
        appearance: appearance ?? this.appearance,
        character: character ?? this.character,
        satiety: satiety ?? this.satiety,
        cleanliness: cleanliness ?? this.cleanliness,
        health: health ?? this.health,
        mood: mood ?? this.mood,
        comfort: comfort ?? this.comfort,
        intellect: intellect ?? this.intellect,
      );

  /// Применить эффекты товара {satiety: +30, ...} (с ограничением 0..100).
  PetState withEffects(Map<String, int> effects) => copyWith(
        satiety: clampStat(satiety + (effects['satiety'] ?? 0)),
        cleanliness: clampStat(cleanliness + (effects['cleanliness'] ?? 0)),
        health: clampStat(health + (effects['health'] ?? 0)),
        mood: clampStat(mood + (effects['mood'] ?? 0)),
        comfort: clampStat(comfort + (effects['comfort'] ?? 0)),
        intellect: clampStat(intellect + (effects['intellect'] ?? 0)),
      );
}

// ---------- Журнал / записи ----------

class HistoryEntry {
  final String at;
  final String text;

  const HistoryEntry({required this.at, required this.text});

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        at: json['at'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'at': at, 'text': text};
}

class PendingEffect {
  final int targetPeriod;
  final int coinsDelta;
  final String source;

  const PendingEffect({
    required this.targetPeriod,
    required this.coinsDelta,
    required this.source,
  });

  factory PendingEffect.fromJson(Map<String, dynamic> json) => PendingEffect(
        targetPeriod: (json['target_period'] as num?)?.toInt() ?? 0,
        coinsDelta: (json['coins_delta'] as num?)?.toInt() ?? 0,
        source: json['source'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'target_period': targetPeriod,
        'coins_delta': coinsDelta,
        'source': source,
      };
}

// ---------- План / факт ----------

class BasketValues {
  final int need;
  final int want;
  final int save;
  final int reserve;

  const BasketValues({
    this.need = 0,
    this.want = 0,
    this.save = 0,
    this.reserve = 0,
  });

  factory BasketValues.fromJson(Map<String, dynamic> json) => BasketValues(
        need: (json['need'] as num?)?.toInt() ?? 0,
        want: (json['want'] as num?)?.toInt() ?? 0,
        save: (json['save'] as num?)?.toInt() ?? 0,
        reserve: (json['reserve'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'need': need,
        'want': want,
        'save': save,
        'reserve': reserve,
      };

  int get total => need + want + save + reserve;

  BasketValues copyWith({int? need, int? want, int? save, int? reserve}) => BasketValues(
        need: need ?? this.need,
        want: want ?? this.want,
        save: save ?? this.save,
        reserve: reserve ?? this.reserve,
      );
}

// ---------- Откат ----------

class RollbackState {
  final bool usedThisPeriod;
  final List<int> usedPeriods;
  final int totalUses;

  const RollbackState({
    required this.usedThisPeriod,
    required this.usedPeriods,
    required this.totalUses,
  });

  factory RollbackState.fromJson(Map<String, dynamic> json) => RollbackState(
        usedThisPeriod: json['used_this_period'] as bool? ?? false,
        usedPeriods: json['used_periods'] is List
            ? (json['used_periods'] as List).whereType<num>().map((e) => e.toInt()).toList()
            : const [],
        totalUses: (json['total_uses'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'used_this_period': usedThisPeriod,
        'used_periods': usedPeriods,
        'total_uses': totalUses,
      };

  RollbackState copyWith({bool? usedThisPeriod, List<int>? usedPeriods, int? totalUses}) =>
      RollbackState(
        usedThisPeriod: usedThisPeriod ?? this.usedThisPeriod,
        usedPeriods: usedPeriods ?? this.usedPeriods,
        totalUses: totalUses ?? this.totalUses,
      );
}

// ---------- GameState ----------

class GameState {
  static const int schemaVersion = 2;

  // --- прогресс цикла ---
  final int period; // 1..5
  final String phase; // текущая фаза (см. engine/phase_flow)
  final String? professionId;
  final bool professionChanged; // нужны ли курс+собеседование в этом периоде

  // --- развитие ---
  final int sr;
  final String srStage; // baby | teen | pro

  // --- деньги ---
  final int balance;
  final int savings;
  final String? goalId;
  final int goalSaved;
  final int shopDiscount; // модификатор цен текущего периода (события)

  final BasketValues plan;
  final BasketValues fact;
  final bool reserveUsedByEvent;
  final bool explorerDiscountUsed; // перк Исследователя: скидка 5 на один товар

  // --- питомец ---
  final PetState pet;

  // --- инвентарь / прогресс ---
  final List<String> ownedItems; // одноразовые предметы (курсы, велосипед, ...)
  final List<String> periodPurchases; // покупки текущего периода (все)
  final List<String> completedTasks; // коды заданий
  final List<String> hitrikResults; // id сцен + ':buy' | ':resist'
  final List<String> resolvedEventIds;
  final List<PendingEffect> pendingEffects; // отложенные эффекты событий

  // --- архетипы ---
  final Map<String, int> archetypeScores; // 5 шкал
  final List<String> archetypeHistory; // лидер каждого завершённого периода
  final String? archetypeFixed;

  // --- откат ---
  final RollbackState rollback;

  // --- прочее ---
  final List<String> glossarySeen;
  final List<HistoryEntry> history;
  final List<int> appliedBonuses; // id серверных бонусов
  final bool demoMode;
  final bool crownAwarded;
  final bool accessoryUnlockNotified;

  /// ISO-метка последнего тика затухания сытости/настроения (клиентское
  /// поле — на сервере непрозрачно, расчёт трат — наша забота).
  final String? lastStatsAt;

  const GameState({
    required this.period,
    required this.phase,
    required this.professionId,
    required this.professionChanged,
    required this.sr,
    required this.srStage,
    required this.balance,
    required this.savings,
    required this.goalId,
    required this.goalSaved,
    required this.shopDiscount,
    required this.plan,
    required this.fact,
    required this.reserveUsedByEvent,
    required this.explorerDiscountUsed,
    required this.pet,
    required this.ownedItems,
    required this.periodPurchases,
    required this.completedTasks,
    required this.hitrikResults,
    required this.resolvedEventIds,
    required this.pendingEffects,
    required this.archetypeScores,
    required this.archetypeHistory,
    required this.archetypeFixed,
    required this.rollback,
    required this.glossarySeen,
    required this.history,
    required this.appliedBonuses,
    required this.demoMode,
    required this.crownAwarded,
    required this.accessoryUnlockNotified,
    this.lastStatsAt,
  });

  /// Свежий профиль до создания питомца.
  factory GameState.empty() => const GameState(
        period: 1,
        phase: 'intro_dialog',
        professionId: null,
        professionChanged: false,
        sr: 0,
        srStage: 'baby',
        balance: 0,
        savings: 0,
        goalId: null,
        goalSaved: 0,
        shopDiscount: 0,
        plan: BasketValues(),
        fact: BasketValues(),
        reserveUsedByEvent: false,
        explorerDiscountUsed: false,
        pet: PetState(
          name: '',
          appearance: PetAppearance(fur: 'Оранжевый', ears: 'Круглые'),
          satiety: 50,
          cleanliness: 50,
          health: 50,
          mood: 50,
          comfort: 50,
          intellect: 0,
        ),
        ownedItems: [],
        periodPurchases: [],
        completedTasks: [],
        hitrikResults: [],
        resolvedEventIds: [],
        pendingEffects: [],
        archetypeScores: {},
        archetypeHistory: [],
        archetypeFixed: null,
        rollback: RollbackState(
          usedThisPeriod: false,
          usedPeriods: [],
          totalUses: 0,
        ),
        glossarySeen: [],
        history: [],
        appliedBonuses: [],
        demoMode: false,
        crownAwarded: false,
        accessoryUnlockNotified: false,
      );

  factory GameState.withPet({
    required String petName,
    required String fur,
    required String ears,
    String? character,
    String? skin,
  }) =>
      GameState.empty().copyWith(
        pet: PetState(
          name: petName,
          appearance: PetAppearance(fur: fur, ears: ears, skin: skin),
          character: character,
          satiety: 60,
          cleanliness: 60,
          health: 70,
          mood: 80,
          comfort: 50,
          intellect: 0,
        ),
      );

  // ---------- парсинг с миграцией ----------

  factory GameState.fromJson(Map<String, dynamic> json) {
    final schema = (json['schema'] as num?)?.toInt() ?? 1;
    if (schema < 2) return GameState._fromV1(json);

    Map<String, int> parseScores(Object? raw) => raw is Map
        ? raw.map((k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0))
        : const <String, int>{};

    return GameState(
      period: (json['period'] as num?)?.toInt() ?? 1,
      phase: json['phase'] as String? ?? 'intro_dialog',
      professionId: json['profession_id'] as String?,
      professionChanged: json['profession_changed'] as bool? ?? false,
      sr: (json['sr'] as num?)?.toInt() ?? 0,
      srStage: json['sr_stage'] as String? ?? 'baby',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      savings: (json['savings'] as num?)?.toInt() ?? 0,
      goalId: json['goal_id'] as String?,
      goalSaved: (json['goal_saved'] as num?)?.toInt() ?? 0,
      shopDiscount: (json['shop_discount'] as num?)?.toInt() ?? 0,
      plan: BasketValues.fromJson(
        (json['plan'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      fact: BasketValues.fromJson(
        (json['fact'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      reserveUsedByEvent: json['reserve_used_by_event'] as bool? ?? false,
      explorerDiscountUsed: json['explorer_discount_used'] as bool? ?? false,
      pet: json['pet'] is Map && (json['pet'] as Map)['name'] != null
          ? PetState.fromJson((json['pet'] as Map).cast<String, dynamic>())
          : GameState.empty().pet,
      ownedItems: json['owned_items'] is List
          ? (json['owned_items'] as List).whereType<String>().toList()
          : const [],
      periodPurchases: json['period_purchases'] is List
          ? (json['period_purchases'] as List).whereType<String>().toList()
          : const [],
      completedTasks: json['completed_tasks'] is List
          ? (json['completed_tasks'] as List).whereType<String>().toList()
          : const [],
      hitrikResults: json['hitrik_results'] is List
          ? (json['hitrik_results'] as List).whereType<String>().toList()
          : const [],
      resolvedEventIds: json['resolved_event_ids'] is List
          ? (json['resolved_event_ids'] as List).whereType<String>().toList()
          : const [],
      pendingEffects: json['pending_effects'] is List
          ? (json['pending_effects'] as List)
              .whereType<Map>()
              .map((e) => PendingEffect.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      archetypeScores: parseScores(json['archetype_scores']),
      archetypeHistory: json['archetype_history'] is List
          ? (json['archetype_history'] as List).whereType<String>().toList()
          : const [],
      archetypeFixed: json['archetype_fixed'] as String?,
      rollback: RollbackState.fromJson(
        (json['rollback'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      glossarySeen: json['glossary_seen'] is List
          ? (json['glossary_seen'] as List).whereType<String>().toList()
          : const [],
      history: json['history'] is List
          ? (json['history'] as List)
              .whereType<Map>()
              .map((e) => HistoryEntry.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      appliedBonuses: json['applied_bonuses'] is List
          ? (json['applied_bonuses'] as List).whereType<num>().map((e) => e.toInt()).toList()
          : const [],
      demoMode: json['demo_mode'] as bool? ?? false,
      crownAwarded: json['crown_awarded'] as bool? ?? false,
      accessoryUnlockNotified: json['accessory_unlock_notified'] as bool? ?? false,
      lastStatsAt: json['last_stats_at'] as String?,
    );
  }

  /// Миграция v1 → v2: сохраняем питомца, деньги, имя; прогресс периодов
  /// начинается заново (каркасной игры у периодов не было).
  factory GameState._fromV1(Map<String, dynamic> json) {
    final petJson = json['pet'] is Map
        ? (json['pet'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    const furMap = {'orange': 'Оранжевый', 'sky': 'Синий', 'mint': 'Зелёный'};
    final oldColor = petJson['color'] as String? ?? 'orange';
    final oldAccessory = petJson['accessory'] as String?;
    const accMap = {'bow': 'bow', 'glasses': null, 'none': null};
    final appearance = PetAppearance(
      fur: furMap[oldColor] ?? 'Оранжевый',
      ears: 'Круглые',
      accessory: accMap.containsKey(oldAccessory) ? accMap[oldAccessory] : null,
    );
    final migrated = GameState.withPet(
      petName: petJson['name'] as String? ?? 'Финни',
      fur: appearance.fur,
      ears: appearance.ears,
    );
    return migrated.copyWith(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      savings: (json['savings'] as num?)?.toInt() ?? 0,
      goalId: json['goal_id'] as String?,
      goalSaved: (json['goal_saved'] as num?)?.toInt() ?? 0,
      pet: migrated.pet.copyWith(appearance: appearance),
      completedTasks: const [],
      history: json['history'] is List
          ? (json['history'] as List)
              .whereType<Map>()
              .map((e) => HistoryEntry.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      appliedBonuses: json['applied_bonuses'] is List
          ? (json['applied_bonuses'] as List).whereType<num>().map((e) => e.toInt()).toList()
          : const [],
      glossarySeen: json['glossary_seen'] is List
          ? (json['glossary_seen'] as List).whereType<String>().toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'period': period,
        'phase': phase,
        'profession_id': professionId,
        'profession_changed': professionChanged,
        'sr': sr,
        'sr_stage': srStage,
        'balance': balance,
        'savings': savings,
        'goal_id': goalId,
        'goal_saved': goalSaved,
        'shop_discount': shopDiscount,
        'plan': plan.toJson(),
        'fact': fact.toJson(),
        'reserve_used_by_event': reserveUsedByEvent,
        'explorer_discount_used': explorerDiscountUsed,
        'pet': pet.toJson(),
        'owned_items': ownedItems,
        'period_purchases': periodPurchases,
        'completed_tasks': completedTasks,
        'hitrik_results': hitrikResults,
        'resolved_event_ids': resolvedEventIds,
        'pending_effects': pendingEffects.map((e) => e.toJson()).toList(),
        'archetype_scores': archetypeScores,
        'archetype_history': archetypeHistory,
        'archetype_fixed': archetypeFixed,
        'rollback': rollback.toJson(),
        'glossary_seen': glossarySeen,
        'history': history.map((e) => e.toJson()).toList(),
        'applied_bonuses': appliedBonuses,
        'demo_mode': demoMode,
        'crown_awarded': crownAwarded,
        'accessory_unlock_notified': accessoryUnlockNotified,
        'last_stats_at': lastStatsAt,
      };

  // ---------- copyWith ----------

  GameState copyWith({
    int? period,
    String? phase,
    Object? professionId = _undefined,
    bool? professionChanged,
    int? sr,
    String? srStage,
    int? balance,
    int? savings,
    Object? goalId = _undefined,
    int? goalSaved,
    int? shopDiscount,
    BasketValues? plan,
    BasketValues? fact,
    bool? reserveUsedByEvent,
    bool? explorerDiscountUsed,
    PetState? pet,
    List<String>? ownedItems,
    List<String>? periodPurchases,
    List<String>? completedTasks,
    List<String>? hitrikResults,
    List<String>? resolvedEventIds,
    List<PendingEffect>? pendingEffects,
    Map<String, int>? archetypeScores,
    List<String>? archetypeHistory,
    Object? archetypeFixed = _undefined,
    RollbackState? rollback,
    List<String>? glossarySeen,
    List<HistoryEntry>? history,
    List<int>? appliedBonuses,
    bool? demoMode,
    bool? crownAwarded,
    bool? accessoryUnlockNotified,
    String? lastStatsAt,
  }) =>
      GameState(
        period: period ?? this.period,
        phase: phase ?? this.phase,
        professionId:
            identical(professionId, _undefined) ? this.professionId : professionId as String?,
        professionChanged: professionChanged ?? this.professionChanged,
        sr: sr ?? this.sr,
        srStage: srStage ?? this.srStage,
        balance: balance ?? this.balance,
        savings: savings ?? this.savings,
        goalId: identical(goalId, _undefined) ? this.goalId : goalId as String?,
        goalSaved: goalSaved ?? this.goalSaved,
        shopDiscount: shopDiscount ?? this.shopDiscount,
        plan: plan ?? this.plan,
        fact: fact ?? this.fact,
        reserveUsedByEvent: reserveUsedByEvent ?? this.reserveUsedByEvent,
        explorerDiscountUsed: explorerDiscountUsed ?? this.explorerDiscountUsed,
        pet: pet ?? this.pet,
        ownedItems: ownedItems ?? this.ownedItems,
        periodPurchases: periodPurchases ?? this.periodPurchases,
        completedTasks: completedTasks ?? this.completedTasks,
        hitrikResults: hitrikResults ?? this.hitrikResults,
        resolvedEventIds: resolvedEventIds ?? this.resolvedEventIds,
        pendingEffects: pendingEffects ?? this.pendingEffects,
        archetypeScores: archetypeScores ?? this.archetypeScores,
        archetypeHistory: archetypeHistory ?? this.archetypeHistory,
        archetypeFixed:
            identical(archetypeFixed, _undefined) ? this.archetypeFixed : archetypeFixed as String?,
        rollback: rollback ?? this.rollback,
        glossarySeen: glossarySeen ?? this.glossarySeen,
        history: history ?? this.history,
        appliedBonuses: appliedBonuses ?? this.appliedBonuses,
        demoMode: demoMode ?? this.demoMode,
        crownAwarded: crownAwarded ?? this.crownAwarded,
        accessoryUnlockNotified:
            accessoryUnlockNotified ?? this.accessoryUnlockNotified,
        lastStatsAt: lastStatsAt ?? this.lastStatsAt,
      );

  // ---------- хелперы ----------

  bool hasPet() => pet.name.isNotEmpty;

  GameState addHistory(String text) => copyWith(
        history: [
          ...history,
          HistoryEntry(at: DateTime.now().toIso8601String(), text: text),
        ],
      );

  GameState addArchetypePoints(Map<String, int> points) {
    if (points.isEmpty) return this;
    final scores = Map<String, int>.from(archetypeScores);
    points.forEach((key, value) {
      scores[key] = (scores[key] ?? 0) + value;
    });
    return copyWith(archetypeScores: scores);
  }

  bool ownsItem(String itemId) => ownedItems.contains(itemId);

  bool boughtThisPeriod(String itemId) => periodPurchases.contains(itemId);
}
