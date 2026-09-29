/// Модели контент-бандла v2 (schema: 2).
/// Парсинг толерантный: сервер может отдавать новые поля — мы их игнорируем,
/// новые версии секций дополняются здесь.
library;

// ---------- Экономика ----------

class Economy {
  final int mandatoryTotalPerPeriod;
  final List<MandatoryExpenseItem> mandatoryItems;
  final DevScore devScore;
  final RollbackRules rollback;
  final PassiveIncome passiveIncome;
  final ParentBonusRules parentBonus;
  final List<BudgetBasket> budgetBaskets;
  final String planningReminder;
  final PurchaseFeedback purchaseFeedback;
  final List<SavingsReaction> savingsDepositReactions;
  final SavingsWithdrawal savingsWithdrawal;
  final AppearanceDef appearance;
  final DemoModeDef demoMode;
  final ParentSectionDef parentSection;

  const Economy({
    required this.mandatoryTotalPerPeriod,
    required this.mandatoryItems,
    required this.devScore,
    required this.rollback,
    required this.passiveIncome,
    required this.parentBonus,
    required this.budgetBaskets,
    required this.planningReminder,
    required this.purchaseFeedback,
    required this.savingsDepositReactions,
    required this.savingsWithdrawal,
    required this.appearance,
    required this.demoMode,
    required this.parentSection,
  });

  factory Economy.fromJson(Map<String, dynamic> json) {
    final mandatory = json['mandatory_expenses'] as Map? ?? const {};
    return Economy(
      mandatoryTotalPerPeriod: (mandatory['total_per_period'] as num?)?.toInt() ?? 60,
      mandatoryItems: mandatory['items'] is List
          ? (mandatory['items'] as List)
              .whereType<Map>()
              .map((e) => MandatoryExpenseItem.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      devScore: DevScore.fromJson(
        (json['dev_score'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      rollback: RollbackRules.fromJson(
        (json['rollback'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      passiveIncome: PassiveIncome.fromJson(
        (json['passive_income'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      parentBonus: ParentBonusRules.fromJson(
        (json['parent_bonus'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      budgetBaskets: json['budget_baskets'] is List
          ? (json['budget_baskets'] as List)
              .whereType<Map>()
              .map((e) => BudgetBasket.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      planningReminder: json['planning_reminder'] as String? ?? '',
      purchaseFeedback: PurchaseFeedback.fromJson(
        (json['purchase_feedback'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      savingsDepositReactions: json['savings_deposit_reactions'] is List
          ? (json['savings_deposit_reactions'] as List)
              .whereType<Map>()
              .map((e) => SavingsReaction.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      savingsWithdrawal: SavingsWithdrawal.fromJson(
        (json['savings_withdrawal'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      appearance: AppearanceDef.fromJson(
        (json['appearance'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      demoMode: DemoModeDef.fromJson(
        (json['demo_mode'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      parentSection: ParentSectionDef.fromJson(
        (json['parent_section'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class MandatoryExpenseItem {
  final String itemId;
  final int price;

  const MandatoryExpenseItem({required this.itemId, required this.price});

  factory MandatoryExpenseItem.fromJson(Map<String, dynamic> json) =>
      MandatoryExpenseItem(
        itemId: json['item_id'] as String? ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
      );
}

class DevScore {
  final int maxPerPeriod;
  final List<DevScoreRule> rules;
  final List<StageDef> stages;

  const DevScore({required this.maxPerPeriod, required this.rules, required this.stages});

  factory DevScore.fromJson(Map<String, dynamic> json) => DevScore(
        maxPerPeriod: (json['max_per_period'] as num?)?.toInt() ?? 50,
        rules: json['rules'] is List
            ? (json['rules'] as List)
                .whereType<Map>()
                .map((e) => DevScoreRule.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
        stages: json['stages'] is List
            ? (json['stages'] as List)
                .whereType<Map>()
                .map((e) => StageDef.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
      );
}

class DevScoreRule {
  final String id;
  final String condition;
  final int points;
  final int fromPeriod;

  const DevScoreRule({
    required this.id,
    required this.condition,
    required this.points,
    required this.fromPeriod,
  });

  factory DevScoreRule.fromJson(Map<String, dynamic> json) => DevScoreRule(
        id: json['id'] as String? ?? '',
        condition: json['condition'] as String? ?? '',
        points: (json['points'] as num?)?.toInt() ?? 0,
        fromPeriod: (json['from_period'] as num?)?.toInt() ?? 1,
      );
}

class StageDef {
  final String id;
  final String name;
  final int scoreMin;
  final int? scoreMax;
  final int minPeriod;

  const StageDef({
    required this.id,
    required this.name,
    required this.scoreMin,
    required this.scoreMax,
    required this.minPeriod,
  });

  factory StageDef.fromJson(Map<String, dynamic> json) => StageDef(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        scoreMin: (json['score_min'] as num?)?.toInt() ?? 0,
        scoreMax: (json['score_max'] as num?)?.toInt(),
        minPeriod: (json['min_period'] as num?)?.toInt() ?? 1,
      );
}

class RollbackRules {
  final int availableFromPeriod;
  final int usesPerPeriod;
  final int unusedBonusCoins;
  final int noRollbackStreakPeriods;
  final int noRollbackBonusCoins;
  final String noRollbackAccessory;
  final String noRollbackAccessoryEmoji;

  const RollbackRules({
    required this.availableFromPeriod,
    required this.usesPerPeriod,
    required this.unusedBonusCoins,
    required this.noRollbackStreakPeriods,
    required this.noRollbackBonusCoins,
    required this.noRollbackAccessory,
    required this.noRollbackAccessoryEmoji,
  });

  factory RollbackRules.fromJson(Map<String, dynamic> json) {
    final unused = (json['unused_bonus'] as Map?)?.cast<String, dynamic>() ?? const {};
    final streak =
        (json['no_rollback_streak_bonus'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RollbackRules(
      availableFromPeriod: (json['available_from_period'] as num?)?.toInt() ?? 2,
      usesPerPeriod: 1,
      unusedBonusCoins: (unused['coins'] as num?)?.toInt() ?? 10,
      noRollbackStreakPeriods: (streak['periods'] as num?)?.toInt() ?? 5,
      noRollbackBonusCoins: (streak['coins'] as num?)?.toInt() ?? 50,
      noRollbackAccessory: streak['accessory'] as String? ?? 'crown',
      noRollbackAccessoryEmoji: streak['accessory_emoji'] as String? ?? '👑',
    );
  }
}

class PassiveIncome {
  final String screenTitle;
  final String totalLineTemplate;
  final String petLine;
  final String button;
  final List<PassiveSource> sources;

  const PassiveIncome({
    required this.screenTitle,
    required this.totalLineTemplate,
    required this.petLine,
    required this.button,
    required this.sources,
  });

  factory PassiveIncome.fromJson(Map<String, dynamic> json) => PassiveIncome(
        screenTitle: json['screen_title'] as String? ?? '💰 Пассивный доход',
        totalLineTemplate:
            json['total_line_template'] as String? ?? 'Итого пришло само: +{total} монет',
        petLine: json['pet_line'] as String? ?? '',
        button: json['button'] as String? ?? 'Отлично!',
        sources: json['sources'] is List
            ? (json['sources'] as List)
                .whereType<Map>()
                .map((e) => PassiveSource.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
      );
}

class PassiveSource {
  final String itemId;
  final int coinsPerPeriod;

  const PassiveSource({required this.itemId, required this.coinsPerPeriod});

  factory PassiveSource.fromJson(Map<String, dynamic> json) => PassiveSource(
        itemId: json['item_id'] as String? ?? '',
        coinsPerPeriod: (json['coins_per_period'] as num?)?.toInt() ?? 0,
      );
}

class ParentBonusRules {
  final int minAmount;
  final int maxAmount;
  final List<String> reasons;
  final String childNotificationTemplate;

  const ParentBonusRules({
    required this.minAmount,
    required this.maxAmount,
    required this.reasons,
    required this.childNotificationTemplate,
  });

  factory ParentBonusRules.fromJson(Map<String, dynamic> json) => ParentBonusRules(
        minAmount: (json['min_amount'] as num?)?.toInt() ?? 1,
        maxAmount: (json['max_amount'] as num?)?.toInt() ?? 100,
        reasons: json['reasons'] is List
            ? (json['reasons'] as List).whereType<String>().toList()
            : const [],
        childNotificationTemplate:
            json['child_notification_template'] as String? ??
                'Родитель начислил {amount} монет за {reason}',
      );
}

class BudgetBasket {
  final String id; // needs | wants | save | reserve
  final String name;
  final String emoji;
  final String hint;

  const BudgetBasket({
    required this.id,
    required this.name,
    required this.emoji,
    required this.hint,
  });

  factory BudgetBasket.fromJson(Map<String, dynamic> json) => BudgetBasket(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        hint: json['hint'] as String? ?? '',
      );
}

class PurchaseFeedback {
  final String mandatoryBought;
  final String optionalBought;
  final String notEnoughCoins;
  final List<String> notEnoughCoinsOptions;

  const PurchaseFeedback({
    required this.mandatoryBought,
    required this.optionalBought,
    required this.notEnoughCoins,
    required this.notEnoughCoinsOptions,
  });

  factory PurchaseFeedback.fromJson(Map<String, dynamic> json) => PurchaseFeedback(
        mandatoryBought: json['mandatory_bought'] as String? ?? '',
        optionalBought: json['optional_bought'] as String? ?? '',
        notEnoughCoins: json['not_enough_coins'] as String? ?? '',
        notEnoughCoinsOptions: json['not_enough_coins_options'] is List
            ? (json['not_enough_coins_options'] as List).whereType<String>().toList()
            : const [],
      );
}

class SavingsReaction {
  final int rangeMin;
  final int? rangeMax;
  final String line;

  const SavingsReaction({required this.rangeMin, required this.rangeMax, required this.line});

  factory SavingsReaction.fromJson(Map<String, dynamic> json) {
    final range = json['range'] as List? ?? const [];
    return SavingsReaction(
      rangeMin: range.isNotEmpty ? (range[0] as num?)?.toInt() ?? 0 : 0,
      rangeMax: range.length > 1 ? (range[1] as num?)?.toInt() : null,
      line: json['line'] as String? ?? '',
    );
  }

  bool matches(int value) =>
      value >= rangeMin && (rangeMax == null || value <= rangeMax!);
}

class SavingsWithdrawal {
  final String introLine;
  final String confirmTemplate;
  final String declineButton;

  const SavingsWithdrawal({
    required this.introLine,
    required this.confirmTemplate,
    required this.declineButton,
  });

  factory SavingsWithdrawal.fromJson(Map<String, dynamic> json) => SavingsWithdrawal(
        introLine: json['intro_line'] as String? ?? '',
        confirmTemplate: json['confirm_template'] as String? ?? '',
        declineButton: json['decline_button'] as String? ?? 'Оставить',
      );
}

class AppearanceDef {
  final List<String> furColors;
  final List<String> earShapes;
  final List<UnlockableAccessory> unlockableAccessories;

  const AppearanceDef({
    required this.furColors,
    required this.earShapes,
    required this.unlockableAccessories,
  });

  factory AppearanceDef.fromJson(Map<String, dynamic> json) => AppearanceDef(
        furColors: json['fur_colors'] is List
            ? (json['fur_colors'] as List).whereType<String>().toList()
            : const ['Оранжевый'],
        earShapes: json['ear_shapes'] is List
            ? (json['ear_shapes'] as List).whereType<String>().toList()
            : const ['Круглые'],
        unlockableAccessories: json['unlockable_accessories'] is List
            ? (json['unlockable_accessories'] as List)
                .whereType<Map>()
                .map((e) => UnlockableAccessory.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
      );
}

class UnlockableAccessory {
  final String id;
  final String name;
  final String emoji;
  final String unlock;

  const UnlockableAccessory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.unlock,
  });

  factory UnlockableAccessory.fromJson(Map<String, dynamic> json) =>
      UnlockableAccessory(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        unlock: json['unlock'] as String? ?? '',
      );
}

class DemoModeDef {
  final String banner;
  final List<String> bannerButtons;

  const DemoModeDef({required this.banner, required this.bannerButtons});

  factory DemoModeDef.fromJson(Map<String, dynamic> json) => DemoModeDef(
        banner: json['banner'] as String? ?? '🔧 ДЕМО-РЕЖИМ АКТИВЕН',
        bannerButtons: json['banner_buttons'] is List
            ? (json['banner_buttons'] as List).whereType<String>().toList()
            : const [],
      );
}

class ParentSectionDef {
  final List<String> principles;

  const ParentSectionDef({required this.principles});

  factory ParentSectionDef.fromJson(Map<String, dynamic> json) => ParentSectionDef(
        principles: json['principles'] is List
            ? (json['principles'] as List).whereType<String>().toList()
            : const [],
      );
}

// ---------- Профессии ----------

class Profession {
  final String id;
  final String name;
  final String emoji;
  final int salary;
  final int workHours;
  final List<int> periods;
  final String? requiredCourseItem;
  final String hook;
  final String hint;
  final String afterChoiceLine;
  final String salaryLine;
  final CourseDef course;
  final InterviewDef interview;
  final MinigameDef minigame;

  const Profession({
    required this.id,
    required this.name,
    required this.emoji,
    required this.salary,
    required this.workHours,
    required this.periods,
    required this.requiredCourseItem,
    required this.hook,
    required this.hint,
    required this.afterChoiceLine,
    required this.salaryLine,
    required this.course,
    required this.interview,
    required this.minigame,
  });

  factory Profession.fromJson(Map<String, dynamic> json) => Profession(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '💼',
        salary: (json['salary'] as num?)?.toInt() ?? 0,
        workHours: (json['work_hours'] as num?)?.toInt() ?? 0,
        periods: json['periods'] is List
            ? (json['periods'] as List).whereType<num>().map((e) => e.toInt()).toList()
            : const [],
        requiredCourseItem: json['required_course_item'] as String?,
        hook: json['hook'] as String? ?? '',
        hint: json['hint'] as String? ?? '',
        afterChoiceLine: json['after_choice_line'] as String? ?? '',
        salaryLine: json['salary_line'] as String? ?? '',
        course: CourseDef.fromJson(
          (json['course'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        interview: InterviewDef.fromJson(
          (json['interview'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        minigame: MinigameDef.fromJson(
          (json['minigame'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

class CourseDef {
  final String format; // full | short
  final List<CourseScreenDef> screens;

  const CourseDef({required this.format, required this.screens});

  factory CourseDef.fromJson(Map<String, dynamic> json) => CourseDef(
        format: json['format'] as String? ?? 'short',
        screens: json['screens'] is List
            ? (json['screens'] as List)
                .whereType<Map>()
                .map((e) => CourseScreenDef.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
      );
}

class CourseScreenDef {
  final int n;
  final String? scene;
  final List<String> lines;
  final InteractiveDef? interactive;

  const CourseScreenDef({
    required this.n,
    required this.scene,
    required this.lines,
    required this.interactive,
  });

  factory CourseScreenDef.fromJson(Map<String, dynamic> json) => CourseScreenDef(
        n: (json['n'] as num?)?.toInt() ?? 0,
        scene: json['scene'] as String?,
        lines:
            json['lines'] is List ? (json['lines'] as List).whereType<String>().toList() : const [],
        interactive: json['interactive'] is Map
            ? InteractiveDef.fromJson((json['interactive'] as Map).cast<String, dynamic>())
            : null,
      );
}

/// Интерактив курса. Поддерживаемые типы (см. engine/UI):
/// choose_one, route_order, distribute_coins, tap_to_sell, tap_envelope,
/// choose_tool, count_income, priority_pick, tap_to_continue.
class InteractiveDef {
  final String type;
  final String prompt;
  final List<SceneOption> options;
  final int? total;
  final List<String> baskets;
  final String? completionLine;
  final List<RoutePoint> points;
  final List<String> correctOrder;
  final Map<String, String> reactions;
  final List<String> correctFirst; // priority_pick
  final Map<String, dynamic> extras; // исходный JSON интерактива

  const InteractiveDef({
    required this.type,
    required this.prompt,
    required this.options,
    required this.total,
    required this.baskets,
    required this.completionLine,
    required this.points,
    required this.correctOrder,
    required this.reactions,
    required this.correctFirst,
    required this.extras,
  });

  factory InteractiveDef.fromJson(Map<String, dynamic> json) => InteractiveDef(
        type: json['type'] as String? ?? 'tap_to_continue',
        prompt: json['prompt'] as String? ?? '',
        options: parseOptions(json['options']),
        total: (json['total'] as num?)?.toInt(),
        baskets: json['baskets'] is List
            ? (json['baskets'] as List).whereType<String>().toList()
            : const [],
        completionLine: json['completion_line'] as String?,
        points: json['points'] is List
            ? (json['points'] as List)
                .whereType<Map>()
                .map((e) => RoutePoint.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
        correctOrder: json['correct_order'] is List
            ? (json['correct_order'] as List).whereType<String>().toList()
            : const [],
        reactions: json['reactions'] is Map
            ? (json['reactions'] as Map).map((k, v) => MapEntry('$k', '$v'))
            : const {},
        correctFirst: json['correct_first'] is List
            ? (json['correct_first'] as List).whereType<String>().toList()
            : (json['correct'] is List
                ? (json['correct'] as List).whereType<String>().toList()
                : (json['correct'] is String ? [json['correct'] as String] : const [])),
        extras: json,
      );
}

class RoutePoint {
  final String id;
  final String distance;

  const RoutePoint({required this.id, required this.distance});

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
        id: json['id'] as String? ?? '',
        distance: json['distance'] as String? ?? '',
      );
}

/// Универсальная опция выбора (курсы, собеседования, Хитрик, события, задания).
class SceneOption {
  final String id;
  final String text;
  final bool correct;
  final String? reaction;
  final String? consequence;
  final String? outcome;
  final int coinsDelta;
  final Map<String, int> archetypePoints;
  final int? reward;
  final bool retry;
  final String? petHintOnError;
  final String? unlocks;
  final List<DelayedEffect> delayedEffects;

  /// Полный исходный JSON опции — для специфичных механик
  /// (ярмарка outcomes_by_archetype, ингредиенты и т.п.).
  final Map<String, dynamic> extras;

  const SceneOption({
    required this.id,
    required this.text,
    required this.correct,
    this.reaction,
    this.consequence,
    this.outcome,
    this.coinsDelta = 0,
    this.archetypePoints = const {},
    this.reward,
    this.retry = false,
    this.petHintOnError,
    this.unlocks,
    this.delayedEffects = const [],
    this.extras = const {},
  });

  factory SceneOption.fromJson(Map<String, dynamic> json) => SceneOption(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? json['label'] as String? ?? '',
        correct: json['correct'] as bool? ?? false,
        reaction: json['reaction'] as String?,
        consequence: json['consequence'] as String?,
        outcome: json['outcome'] as String?,
        coinsDelta: (json['coins_delta'] as num?)?.toInt() ?? 0,
        archetypePoints: json['archetype_points'] is Map
            ? (json['archetype_points'] as Map)
                .map((k, v) => MapEntry('$k', contentInt(v)))
            : const {},
        reward: (json['reward'] as num?)?.toInt(),
        retry: json['retry'] as bool? ?? false,
        petHintOnError: json['pet_hint_on_error'] as String?,
        unlocks: json['unlocks'] as String?,
        delayedEffects: json['delayed_effects'] is List
            ? (json['delayed_effects'] as List)
                .whereType<Map>()
                .map((e) => DelayedEffect.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
        extras: json,
      );
}

class DelayedEffect {
  /// Относительная отсрочка в периодах (поле periods).
  final int periods;

  /// Абсолютный целевой период (поле period в контенте v2).
  final int? absolutePeriod;
  final int coinsDelta;
  final int shopDiscountDelta;

  const DelayedEffect({
    required this.periods,
    this.absolutePeriod,
    this.coinsDelta = 0,
    this.shopDiscountDelta = 0,
  });

  factory DelayedEffect.fromJson(Map<String, dynamic> json) => DelayedEffect(
        periods: (json['periods'] as num?)?.toInt() ?? 0,
        absolutePeriod: (json['period'] as num?)?.toInt(),
        coinsDelta: (json['coins_delta'] as num?)?.toInt() ?? 0,
        shopDiscountDelta: (json['shop_discount_delta'] as num?)?.toInt() ?? 0,
      );
}

List<SceneOption> parseOptions(Object? raw) => raw is List
    ? raw.whereType<Map>().map((e) => SceneOption.fromJson(e.cast<String, dynamic>())).toList()
    : const [];

class InterviewDef {
  final String format; // full | short
  final String? npc;
  final String? question;
  final List<SceneOption> options;
  final String? hiredLine;

  const InterviewDef({
    required this.format,
    required this.npc,
    required this.question,
    required this.options,
    required this.hiredLine,
  });

  factory InterviewDef.fromJson(Map<String, dynamic> json) => InterviewDef(
        format: json['format'] as String? ?? 'short',
        npc: json['npc'] as String?,
        question: json['question'] as String?,
        options: parseOptions(json['options']),
        hiredLine: json['hired_line'] as String?,
      );
}

class MinigameDef {
  final String type;
  final String task;
  final Map<String, dynamic> params;

  const MinigameDef({required this.type, required this.task, required this.params});

  factory MinigameDef.fromJson(Map<String, dynamic> json) => MinigameDef(
        type: json['type'] as String? ?? '',
        task: json['task'] as String? ?? '',
        params: json['params'] is Map
            ? (json['params'] as Map).cast<String, dynamic>()
            : const {},
      );
}

// ---------- Товары / цели ----------

enum ShopItemType {
  mandatory,
  optional,
  situational,
  reward;

  static ShopItemType fromString(String? v) => switch (v) {
        'optional' => ShopItemType.optional,
        'situational' => ShopItemType.situational,
        'reward' => ShopItemType.reward,
        _ => ShopItemType.mandatory,
      };

  String get label => switch (this) {
        ShopItemType.mandatory => 'Обязательный',
        ShopItemType.optional => 'Хотелка',
        ShopItemType.situational => 'На всякий случай',
        ShopItemType.reward => 'Награда',
      };

  bool get isRequiredKind => this == ShopItemType.mandatory;
}

class ShopItem {
  final String id;
  final String name;
  final String emoji;
  final ShopItemType type;
  final int price;
  final String category;
  final Map<String, int> effects; // satiety/cleanliness/health/mood/comfort/intellect
  final int availableFromPeriod;
  final String? unlocks;
  final int passiveIncomePerPeriod;
  final String? lockLabel;

  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    required this.price,
    required this.category,
    required this.effects,
    required this.availableFromPeriod,
    required this.unlocks,
    required this.passiveIncomePerPeriod,
    required this.lockLabel,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🛍️',
        type: ShopItemType.fromString(json['type'] as String?),
        price: (json['price'] as num?)?.toInt() ?? 0,
        category: json['category'] as String? ?? '',
        effects: json['effects'] is Map
            ? (json['effects'] as Map)
                .map((k, v) => MapEntry('$k', contentInt(v)))
            : const {},
        availableFromPeriod: (json['available_from_period'] as num?)?.toInt() ?? 1,
        unlocks: json['unlocks'] as String?,
        passiveIncomePerPeriod:
            (json['passive_income_per_period'] as num?)?.toInt() ?? 0,
        lockLabel: json['lock_label'] as String?,
      );
}

class GoalItem {
  final String id;
  final String name;
  final String emoji;
  final int cost;
  final String petLine;
  final String rewardEffect;

  const GoalItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.petLine,
    required this.rewardEffect,
  });

  factory GoalItem.fromJson(Map<String, dynamic> json) => GoalItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🎯',
        cost: (json['cost'] as num?)?.toInt() ?? 0,
        petLine: json['pet_line'] as String? ?? '',
        rewardEffect: json['reward_effect'] as String? ?? '',
      );
}

// ---------- Задания ----------

enum TaskTopic {
  budget,
  saving,
  payments;

  String get label => switch (this) {
        TaskTopic.budget => 'Бюджет',
        TaskTopic.saving => 'Копилка',
        TaskTopic.payments => 'Платежи',
      };

  static TaskTopic fromString(String? value) => switch (value) {
        'saving' => TaskTopic.saving,
        'payments' => TaskTopic.payments,
        _ => TaskTopic.budget,
      };
}

class GameTask {
  final String code; // A1..G2
  final int period;
  final TaskTopic topic;
  final String title;
  final String format;
  final String? trigger;
  final Map<String, dynamic> data;
  final List<TaskOutcome> outcomes;
  final String? explanation;

  const GameTask({
    required this.code,
    required this.period,
    required this.topic,
    required this.title,
    required this.format,
    required this.trigger,
    required this.data,
    required this.outcomes,
    required this.explanation,
  });

  factory GameTask.fromJson(Map<String, dynamic> json) => GameTask(
        code: json['code'] as String? ?? '',
        period: (json['period'] as num?)?.toInt() ?? 1,
        topic: TaskTopic.fromString(json['topic'] as String?),
        title: json['title'] as String? ?? '',
        format: json['format'] as String? ?? 'story_choice',
        trigger: json['trigger'] is String ? json['trigger'] as String : null,
        data: json['data'] is Map
            ? (json['data'] as Map).cast<String, dynamic>()
            : const {},
        outcomes: json['outcomes'] is List
            ? (json['outcomes'] as List)
                .whereType<Map>()
                .map((e) => TaskOutcome.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
        explanation: json['explanation'] as String?,
      );
}

class TaskOutcome {
  final String condition;
  final String line;
  final int reward;

  const TaskOutcome({required this.condition, required this.line, required this.reward});

  factory TaskOutcome.fromJson(Map<String, dynamic> json) => TaskOutcome(
        condition: json['condition'] as String? ?? '',
        line: json['line'] as String? ?? '',
        reward: (json['reward'] as num?)?.toInt() ?? 0,
      );
}

// ---------- Хитрик / события ----------

class HitrikScene {
  final String id;
  final int period;
  final String trigger;
  final String scene;
  final String hitrikLine;
  final String prompt;
  final List<SceneOption> options;
  final String? explanation;

  const HitrikScene({
    required this.id,
    required this.period,
    required this.trigger,
    required this.scene,
    required this.hitrikLine,
    required this.prompt,
    required this.options,
    required this.explanation,
  });

  factory HitrikScene.fromJson(Map<String, dynamic> json) => HitrikScene(
        id: json['id'] as String? ?? '',
        period: (json['period'] as num?)?.toInt() ?? 1,
        trigger: json['trigger'] as String? ?? '',
        scene: json['scene'] as String? ?? '',
        hitrikLine: json['hitrik_line'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        options: parseOptions(json['options']),
        explanation: json['explanation'] as String?,
      );
}

class GameEvent {
  final String id;
  final int period;
  final String title;
  final String emoji;
  final String situation;
  final String prompt;
  final List<SceneOption> options;
  final String? petLine;
  final bool rollbackAvailable;

  const GameEvent({
    required this.id,
    required this.period,
    required this.title,
    required this.emoji,
    required this.situation,
    required this.prompt,
    required this.options,
    required this.petLine,
    required this.rollbackAvailable,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
        id: json['id'] as String? ?? '',
        period: (json['period'] as num?)?.toInt() ?? 1,
        title: json['title'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '❗',
        situation: json['situation'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        options: parseOptions(json['options']),
        petLine: json['pet_line'] as String?,
        rollbackAvailable: json['rollback_available'] as bool? ?? false,
      );
}

// ---------- Архетипы ----------

class Archetype {
  final String id;
  final String name;
  final String emoji;
  final PerkDef perk;
  final String finalLine;

  const Archetype({
    required this.id,
    required this.name,
    required this.emoji,
    required this.perk,
    required this.finalLine,
  });

  factory Archetype.fromJson(Map<String, dynamic> json) => Archetype(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '✨',
        perk: PerkDef.fromJson(
          (json['perk'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        finalLine: json['final_line'] as String? ?? '',
      );
}

class PerkDef {
  final String id;
  final String name;
  final int param;
  final String description;

  const PerkDef({
    required this.id,
    required this.name,
    required this.param,
    required this.description,
  });

  factory PerkDef.fromJson(Map<String, dynamic> json) => PerkDef(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        param: (json['param'] as num?)?.toInt() ?? 0,
        description: json['description'] as String? ?? '',
      );
}

class ArchetypeRules {
  final int activeFromPeriod;
  final int dominancePeriods;

  const ArchetypeRules({required this.activeFromPeriod, required this.dominancePeriods});

  factory ArchetypeRules.fromJson(Map<String, dynamic> json) => ArchetypeRules(
        activeFromPeriod: (json['active_from_period'] as num?)?.toInt() ?? 2,
        dominancePeriods: (json['dominance_periods'] as num?)?.toInt() ?? 3,
      );
}

// ---------- Глоссарий ----------

class GlossaryTerm {
  final String id;
  final String term;
  final String emoji;
  final String text;

  const GlossaryTerm({
    required this.id,
    required this.term,
    required this.emoji,
    required this.text,
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) => GlossaryTerm(
        id: json['id'] as String? ?? '',
        term: json['term'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '📖',
        text: json['text'] as String? ?? '',
      );
}

// ---------- Периоды ----------

class PeriodDef {
  final int number;
  final String title;
  final int startBalance;
  final Map<String, dynamic> features;
  final Map<String, dynamic> petLines;
  final List<String> summaryBlocks;
  final List<String> nextPeriodTeaser;
  final String? nextPeriodButton;

  const PeriodDef({
    required this.number,
    required this.title,
    required this.startBalance,
    required this.features,
    required this.petLines,
    required this.summaryBlocks,
    required this.nextPeriodTeaser,
    required this.nextPeriodButton,
  });

  factory PeriodDef.fromJson(Map<String, dynamic> json) => PeriodDef(
        number: (json['number'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        startBalance: (json['start_balance'] as num?)?.toInt() ?? 0,
        features: json['features'] is Map
            ? (json['features'] as Map).cast<String, dynamic>()
            : const {},
        petLines: json['pet_lines'] is Map
            ? (json['pet_lines'] as Map).cast<String, dynamic>()
            : const {},
        summaryBlocks: json['summary_blocks'] is List
            ? (json['summary_blocks'] as List).whereType<String>().toList()
            : const [],
        nextPeriodTeaser: json['next_period_teaser'] is List
            ? (json['next_period_teaser'] as List).whereType<String>().toList()
            : (json['next_period_teaser'] is String ? [json['next_period_teaser'] as String] : const []),
        nextPeriodButton: json['next_period_button'] as String?,
      );

  bool get hasHitrik => features['hitrik'] == true;
  int get randomEventsCount => (features['random_events'] as num?)?.toInt() ?? 0;
  bool get hasRollback => features['rollback'] == true;
  bool get hasPassiveIncome => features['passive_income'] == true;
  bool get archetypeScalesActive => features['archetype_scales'] == true;

  List<String> get professions => features['professions'] is List
      ? (features['professions'] as List).whereType<String>().toList()
      : const [];

  List<String> get newShopItems => features['new_shop_items'] is List
      ? (features['new_shop_items'] as List).whereType<String>().toList()
      : const [];

  String? get newBudgetBasket => features['new_budget_basket'] as String?;

  List<String> stringList(String key) => petLines[key] is List
      ? (petLines[key] as List).whereType<String>().toList()
      : const [];

  String? string(String key) => petLines[key] as String?;
}

// ---------- Бандл ----------

/// Ответ `GET /v1/content/bundle` с payload schema 2.
class ContentBundle {
  final int version;
  final String? publishedAt;
  final GameContent payload;

  const ContentBundle({required this.version, required this.payload, this.publishedAt});

  factory ContentBundle.fromJson(Map<String, dynamic> json) => ContentBundle(
        version: (json['version'] as num?)?.toInt() ?? 0,
        publishedAt: json['published_at'] as String?,
        payload: GameContent.fromJson(
          (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

class GameContent {
  final int schema;
  final Economy economy;
  final List<Profession> professions;
  final List<ShopItem> shopItems;
  final List<GoalItem> goals;
  final List<GameTask> tasks;
  final List<HitrikScene> hitrikScenes;
  final List<GameEvent> events;
  final List<Archetype> archetypes;
  final ArchetypeRules archetypeRules;
  final List<GlossaryTerm> glossary;
  final List<PeriodDef> periods;

  /// Исходный payload (для кэширования в SQLite без пересериализации).
  final Map<String, dynamic> raw;

  const GameContent({
    required this.schema,
    required this.economy,
    required this.professions,
    required this.shopItems,
    required this.goals,
    required this.tasks,
    required this.hitrikScenes,
    required this.events,
    required this.archetypes,
    required this.archetypeRules,
    required this.glossary,
    required this.periods,
    required this.raw,
  });

  factory GameContent.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) from) => raw is List
        ? raw.whereType<Map>().map((e) => from(e.cast<String, dynamic>())).toList()
        : <T>[];
    return GameContent(
      schema: (json['schema'] as num?)?.toInt() ?? 2,
      economy: Economy.fromJson(
        (json['economy'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      professions: list(json['professions'], Profession.fromJson),
      shopItems: list(json['shop_items'], ShopItem.fromJson),
      goals: list(json['goals'], GoalItem.fromJson),
      tasks: list(json['tasks'], GameTask.fromJson),
      hitrikScenes: list(json['hitrik_scenes'], HitrikScene.fromJson),
      events: list(json['events'], GameEvent.fromJson),
      archetypes: list(json['archetypes'], Archetype.fromJson),
      archetypeRules: ArchetypeRules.fromJson(
        (json['archetype_rules'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      glossary: list(json['glossary'], GlossaryTerm.fromJson),
      periods: list(json['periods'], PeriodDef.fromJson),
      raw: json,
    );
  }

  Profession? professionById(String? id) {
    for (final p in professions) {
      if (p.id == id) return p;
    }
    return null;
  }

  ShopItem? shopItemById(String? id) {
    for (final i in shopItems) {
      if (i.id == id) return i;
    }
    return null;
  }

  GoalItem? goalById(String? id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  GameTask? taskByCode(String? code) {
    for (final t in tasks) {
      if (t.code == code) return t;
    }
    return null;
  }

  PeriodDef periodDef(int number) =>
      periods.firstWhere((p) => p.number == number, orElse: () => periods.first);

  Archetype? archetypeById(String? id) {
    for (final a in archetypes) {
      if (a.id == id) return a;
    }
    return null;
  }

  GlossaryTerm? glossaryById(String? id) {
    for (final g in glossary) {
      if (g.id == id) return g;
    }
    return null;
  }
}

/// Толерантное приведение к int (контент может содержать строки).
int contentInt(Object? v) =>
    v is num ? v.toInt() : (v is String ? (int.tryParse(v) ?? 0) : 0);
