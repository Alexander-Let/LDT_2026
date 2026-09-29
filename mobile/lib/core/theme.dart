import 'package:flutter/material.dart';

/// Токены дизайна из Figma «segee».
/// Две темы: dark (по макетам) и light (черновик для будущего).
class AppColors {
  final Color bg;         // фон экранов      #2A2A2A
  final Color card;       // карточки         #3D3D3D
  final Color cardDeep;   // глубокие панели  #1D1D1D
  final Color stroke;     // рамки            #212736
  final Color text;
  final Color textDim;
  final Color purple;     // акцент           #634ABF
  final Color gold;       // награды          #F4B52D
  final Color green;      // успех            #1AE977
  final Color red;        // опасность        #8B1111
  final Color orange;     // кнопки           #F75900
  final Color satiety;    // сытость          #FF9EB7
  final Color mood;       // настроение       #33A7AF
  final Color coins;      // монеты           #FFBF33

  // Жёлтые слайды (создание персонажа)
  static const yellowBg = Color(0xFFFFD979);
  static const yellowCircle = Color(0xFFFFC100);
  static const yellowButton = Color(0xFFF75900);
  static const yellowInput = Color(0xFFFFEEB9);

  // Точные цвета макета «segee» v2
  static const figmaBg = Color(0xFF2A2A2A);      // фон экранов
  static const figmaCard = Color(0xFF3D3D3D);    // карточки (Ещё и др.)
  static const figmaCardDeep = Color(0xFF1D1D1D);// ячейки статуса, товаров
  static const figmaChip = Color(0xFF383838);    // карточки целей, кнопки ВЫБРАТЬ
  static const figmaTaskCard = Color(0xFF212736);// карточки заданий
  static const figmaHeaderPurple = Color(0xFF634ABF); // Задания
  static const figmaHeaderBlue = Color(0xFF2C8AEA);   // Дневник/Справка
  static const figmaHeaderGold = Color(0xFFFFBD52);   // Цели
  static const figmaNavGreen = Color(0xFF41C23B);     // активная вкладка, +N
  static const figmaPathActive = Color(0xFF558953);   // активный этап
  static const figmaBtnGreen = Color(0xFF74AA7A);     // ЗАБРАТЬ НАГРАДУ
  static const figmaBtnStart = Color(0xFF40C974);     // НАЧАТЬ
  static const figmaCoral = Color(0xFFFF7B69);        // карточка урока
  static const figmaTextMuted = Color(0xFFCFD8EF);    // неактивный текст задания
  static const figmaTextDimmer = Color(0xFF80A0BA);   // «Награда: …»
  static const figmaDivider = Color(0xFF717171);      // разделители
  static const figmaSpecGold = Color(0xFFF5BF68);     // рамка спецакции
  static const figmaSpecText = Color(0xFF844F12);     // текст цены спецакции
  static const figmaBowlTop = Color(0xFF1D1D1D);      // «чаша» градиент (верх)
  static const figmaBowlBottom = Color(0xFF538143);   // «чаша» градиент (низ)
  static const figmaStrokePink = Color(0xFFFF9EB7);   // рамка сытости
  static const figmaStrokeMood = Color(0xFF56C05D);   // рамка настроения
  static const figmaStrokeCoins = Color(0xFFB47537);  // рамка монет
  static const figmaOrangeText = Color(0xFFFFA853);   // «деняжек»
  static const figmaTrack = Color(0xFF5C5B65);        // трек прогресса

  const AppColors({
    required this.bg,
    required this.card,
    required this.cardDeep,
    required this.stroke,
    required this.text,
    required this.textDim,
    required this.purple,
    required this.gold,
    required this.green,
    required this.red,
    required this.orange,
    required this.satiety,
    required this.mood,
    required this.coins,
  });

  static const dark = AppColors(
    bg: Color(0xFF2A2A2A),
    card: Color(0xFF3D3D3D),
    cardDeep: Color(0xFF1D1D1D),
    stroke: Color(0xFF212736),
    text: Color(0xFFFFFFFF),
    textDim: Color(0xFFB9B9B9),
    purple: Color(0xFF634ABF),
    gold: Color(0xFFF4B52D),
    green: Color(0xFF1AE977),
    red: Color(0xFF8B1111),
    orange: Color(0xFFF75900),
    satiety: Color(0xFFFF9EB7),
    mood: Color(0xFF33A7AF),
    coins: Color(0xFFFFBF33),
  );
}

/// Радиусы из макетов.
class AppRadii {
  static const card = 12.0;
  static const button = 13.0;
  static const chip = 30.0;
  static const sheet = 40.0;
  static const bubble = 20.0;
}

/// Шрифты из макетов: Jersey 10 (цены и крупные цифры), всё остальное —
/// Nunito (подключён в assets/fonts: Regular/Medium/Bold/ExtraBold).
class AppFonts {
  static const String display = 'Jersey10'; // крупные цифры
  static const String label = 'Nunito';     // подписи, кнопки
  static const String price = 'Jersey10';   // цены
  static const String header = 'Nunito';    // заголовки
  static const String body = 'Nunito';      // основной текст
}

class AppTextStyles {
  /// Заголовок экрана (Comic Sans MS 28).
  static TextStyle header({Color? color, double size = 28, String? fontFamily}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        fontFamily: fontFamily ?? AppFonts.header,
      );

  /// Подпись/кнопка (Impact 22, uppercase снаружи).
  static TextStyle label({Color? color, double size = 22, String? fontFamily}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        fontFamily: fontFamily ?? AppFonts.label,
      );

  /// Крупная цифра (Jaro).
  static TextStyle number({Color? color, double size = 32, String? fontFamily}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
        fontFamily: fontFamily ?? AppFonts.display,
      );

  /// Цена (Jersey 10).
  static TextStyle price({Color? color, double size = 24, String? fontFamily}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
        fontFamily: fontFamily ?? AppFonts.price,
      );

  /// Основной текст (Inter 17/22).
  static TextStyle body({Color? color, double size = 17, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color, fontFamily: AppFonts.body);
}

ThemeData buildAppTheme([AppColors c = AppColors.dark]) {
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: c.purple,
    onPrimary: Colors.white,
    secondary: c.gold,
    onSecondary: Colors.black,
    error: c.red,
    onError: Colors.white,
    surface: c.card,
    onSurface: c.text,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: 'Nunito', // дефолт всего, кроме Jersey 10 (цены/крупные цифры)
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.cardDeep,
      contentTextStyle: AppTextStyles.body(color: c.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
    ),
  );
}

/// Текущая палитра (приложение всегда в тёмной теме).
extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.dark;
}
