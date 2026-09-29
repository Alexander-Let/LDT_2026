/// Скины персонажей (PNG-арты от дизайнера, `pts_png`).
/// Порядок = порядок в карусели выбора; по умолчанию выбран ПЕРВЫЙ.
library;

/// 9 артов персонажей. Индекс выбранного скина хранится в
/// `PetAppearance.skin` (путь к ассету — переживает переименования
/// списка лучше сырого индекса).
const List<String> petSkins = [
  'assets/pet/amyr_tiger.png',
  'assets/pet/chery_red_pand.png',
  'assets/pet/grey_tider.png',
  'assets/pet/manul.png',
  'assets/pet/med_manul.png',
  'assets/pet/red_pand.png',
  'assets/pet/sand_tiger.png',
  'assets/pet/snow_bars.png',
  'assets/pet/sumicry_bars.png',
];

/// Названия персонажей (по порядку [petSkins]) — вместо «Персонаж N из 9».
const List<String> petSkinNames = [
  'Амурский тигр',
  'Черничная-красная панда',
  'Серый тигр',
  'Манул',
  'Медовый манул',
  'Красная панда',
  'Песчаный тигр',
  'Снежный барс',
  'Сумеречный барс',
];

/// Ассет персонажа по сохранённому значению; неизвестное/пустое —
/// первый персонаж (дефолт).
String petSkinAsset(String? skin) =>
    petSkins.contains(skin) ? skin! : petSkins.first;

/// Ассет «зверёк с мыльным пузырём» для золотой шапки экрана «Цели»:
/// тот же персонаж, что в [petSkinAsset], с префиксом `goals_`
/// (basename совпадает с обычным артом). Дефолт — первый скин.
String petSkinGoalsAsset(String? skin) =>
    'assets/pet/goals_${petSkinAsset(skin).split('/').last}';
