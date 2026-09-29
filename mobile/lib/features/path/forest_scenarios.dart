/// Сценарии лесного похода («Бесконечный лес»): ребёнок видит условие
/// («Небо затянуло тучами — скоро дождь») и выбирает, какую вещь купить.
/// Верный выбор помогает питомцу (эффекты к показателям), неверный —
/// мягкая учебная неудача: монетки потрачены, а вещь не пригодилась
/// (ТЗ 2.5.9: у неудачи есть объяснение и подсказка, как исправить).
library;

/// Вариант покупки в событии похода.
class ForestOption {
  final String emoji;
  final String name;
  final int price;

  /// Эффекты для питомца — как у товаров магазина ({'satiety': 12} и т.п.).
  /// Применяются через GameStateController.addPetStats, поэтому используются
  /// только ключи satiety / mood / intellect. У «бесполезных» вещей — пусто.
  final Map<String, int> effects;

  const ForestOption({
    required this.emoji,
    required this.name,
    required this.price,
    this.effects = const {},
  });
}

/// Одно событие похода: условие, 3 варианта (ровно один подходящий)
/// и объяснения для верного/неверного выбора.
class ForestScenario {
  /// Условие-ситуация («В лесу темнеет…»).
  final String condition;

  /// Три варианта на выбор; правильный — [correctIndex].
  final List<ForestOption> options;

  final int correctIndex;

  /// Объяснение при верном выборе: почему вещь нужна + что она дала питомцу.
  final String rightText;

  /// Мягкое объяснение при неверном выборе: без запугивания, с подсказкой,
  /// как поступить в следующий раз.
  final String wrongText;

  const ForestScenario({
    required this.condition,
    required this.options,
    required this.correctIndex,
    required this.rightText,
    required this.wrongText,
  });
}

/// Все события похода. Неправильные варианты — хотелки и бесполезное
/// (бантик, сладости, шарик, наклейки): приятно, но при условии не поможет.
const forestScenarios = <ForestScenario>[
  ForestScenario(
    condition: 'Небо затянуло тучами — скоро пойдёт дождь!',
    options: [
      ForestOption(emoji: '🎀', name: 'Бантик', price: 5),
      ForestOption(emoji: '🎈', name: 'Воздушный шарик', price: 8),
      ForestOption(
        emoji: '🌧️',
        name: 'Дождевик',
        price: 12,
        effects: {'mood': 8},
      ),
    ],
    correctIndex: 2,
    rightText: 'Точно! Дождевик не дал Финни промокнуть: под дождём сухо '
        'и даже весело. Настроение +8!',
    wrongText: 'Это приятно, но от дождя не спасёт. Монетки потрачены, '
        'а дождевика нет… В следующий раз подумай, что НУЖНО при таком '
        'условии!',
  ),
  ForestScenario(
    condition: 'Финни проголодался перед дальней дорогой.',
    options: [
      ForestOption(emoji: '🍬', name: 'Леденец', price: 5),
      ForestOption(
        emoji: '🥪',
        name: 'Бутерброд',
        price: 10,
        effects: {'satiety': 12},
      ),
      ForestOption(emoji: '⭐', name: 'Наклейки', price: 6),
    ],
    correctIndex: 1,
    rightText: 'Молодец! Бутерброд дал Финни силы на весь поход — '
        'сытость +12. Настоящая еда важнее сладостей!',
    wrongText: 'Это вкусно и красиво, но сил для дороги не даст. Монетки '
        'потрачены, а Финни всё ещё голодный… В следующий раз выбери то, '
        'что НУЖНО!',
  ),
  ForestScenario(
    condition: 'В лесу быстро темнеет — скоро ничего не будет видно!',
    options: [
      ForestOption(
        emoji: '🔦',
        name: 'Фонарик',
        price: 15,
        effects: {'mood': 8},
      ),
      ForestOption(emoji: '🎀', name: 'Бантик', price: 5),
      ForestOption(emoji: '🍫', name: 'Шоколадка', price: 7),
    ],
    correctIndex: 0,
    rightText: 'Верно! С фонариком в темноте не страшно — Финни видит '
        'дорогу. Настроение +8!',
    wrongText: 'Это здорово, но темноту не разгонит. Монетки потрачены, '
        'а света нет… Подумай, что НУЖНО, когда вокруг темно!',
  ),
  ForestScenario(
    condition: 'Финни ковырял землю и испачкал лапы.',
    options: [
      ForestOption(emoji: '🎈', name: 'Воздушный шарик', price: 8),
      ForestOption(
        emoji: '🧻',
        name: 'Влажные салфетки',
        price: 8,
        effects: {'mood': 6},
      ),
      ForestOption(emoji: '🍭', name: 'Леденец', price: 5),
    ],
    correctIndex: 1,
    rightText: 'Отлично! Лапы снова чистые — Финни доволен и готов '
        'к приключениям. Настроение +6!',
    wrongText: 'Это весело, но лапы чище не станут. Монетки потрачены, '
        'а грязь осталась… В следующий раз подумай, что НУЖНО при таком '
        'условии!',
  ),
  ForestScenario(
    condition: 'Впереди долгая дорога — Финни нужны силы.',
    options: [
      ForestOption(emoji: '🍰', name: 'Пирожное', price: 9),
      ForestOption(emoji: '⭐', name: 'Наклейки', price: 6),
      ForestOption(
        emoji: '🍲',
        name: 'Каша в термосе',
        price: 12,
        effects: {'satiety': 12},
      ),
    ],
    correctIndex: 2,
    rightText: 'Правильно! Каша — настоящая еда: сытость +12, и Финни '
        'бодр весь день. Сладости кончаются быстро, а сил не прибавляют!',
    wrongText: 'Вкусно, но сил надолго не хватит. Монетки потрачены, '
        'а Финни скоро снова проголодается… Выбирай то, что НУЖНО '
        'для дороги!',
  ),
  ForestScenario(
    condition: 'Ночью в лесу холодно — пора устраиваться спать!',
    options: [
      ForestOption(emoji: '🍦', name: 'Мороженое', price: 6),
      ForestOption(
        emoji: '🛏️',
        name: 'Тёплый плед',
        price: 14,
        effects: {'mood': 10},
      ),
      ForestOption(emoji: '⭐', name: 'Наклейки', price: 6),
    ],
    correctIndex: 1,
    rightText: 'Точно! Под тёплым пледом Финни согрелся и сладко выспался. '
        'Настроение +10!',
    wrongText: 'Это приятно, но холодную ночь не согреет. Монетки '
        'потрачены, а Финни мёрзнет… Подумай, что НУЖНО, когда холодно!',
  ),
  ForestScenario(
    condition: 'У ручья кружат тучи комаров — жужжат и кусаются!',
    options: [
      ForestOption(
        emoji: '🧴',
        name: 'Спрей от комаров',
        price: 11,
        effects: {'mood': 8},
      ),
      ForestOption(emoji: '🎈', name: 'Воздушный шарик', price: 8),
      ForestOption(emoji: '🍬', name: 'Конфеты', price: 5),
    ],
    correctIndex: 0,
    rightText: 'Верно! Спрей прогнал комаров — Финни больше никто '
        'не кусает. Настроение +8!',
    wrongText: 'Это весело, но комаров не прогонит. Монетки потрачены, '
        'а комары всё жужжат… В следующий раз подумай, что НУЖНО при '
        'таком условии!',
  ),
  ForestScenario(
    condition: 'Дорога длинная, и Финни загрустил.',
    options: [
      ForestOption(emoji: '🍭', name: 'Леденец', price: 5),
      ForestOption(emoji: '⭐', name: 'Наклейки', price: 6),
      ForestOption(
        emoji: '🧸',
        name: 'Любимая игрушка',
        price: 10,
        effects: {'mood': 12},
      ),
    ],
    correctIndex: 2,
    rightText: 'Отлично! С любимой игрушкой дорога сразу стала веселее — '
        'настроение +12!',
    wrongText: 'Это ненадолго отвлечёт, но грусть не прогонит. Монетки '
        'потрачены, а Финни всё ещё скучает… Выбирай то, что действительно '
        'НУЖНО!',
  ),
];

/// Два события на один поход. Ротация по кругу леса (cycle): каждый круг
/// пара смещается на 2, так за 4 круга ребёнок увидит все сценарии.
/// (В Dart % всегда неотрицателен, так что любой cycle безопасен.)
List<ForestScenario> tripScenarios(int cycle) {
  final len = forestScenarios.length;
  return [
    forestScenarios[(cycle * 2) % len],
    forestScenarios[(cycle * 2 + 1) % len],
  ];
}
