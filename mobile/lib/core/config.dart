class AppConfig {
  /// Base URL бэкенда — продакшн-сервер, подключение жёсткое (без экрана
  /// настроек). Переопределить можно только через
  /// --dart-define=API_BASE_URL=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://135.106.186.240:8080',
  );

  // Короткие таймауты: при недоступном сервере приложение обязано быстро
  // перейти в офлайн-режим, а не висеть на сетевом вызове.
  static const Duration connectTimeout = Duration(seconds: 4);
  static const Duration receiveTimeout = Duration(seconds: 8);
  static const Duration sendTimeout = Duration(seconds: 8);
}
