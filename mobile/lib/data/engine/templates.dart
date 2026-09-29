/// Централизованная подстановка плейсхолдеров в тексты контента.
///
/// В бандле v2 плейсхолдеры записаны как `{имя}` / `{n}` и т.п.
/// (в спеке встречается и `[N]`-нотация — поддерживаем обе,
/// чтобы в выводимом UI никогда не было «сырых» скобок).
library;

/// Заполняет шаблон значениями: `{key}` и `[key]` → value.
/// Неизвестные плейсхолдеры остаются как есть (видны в тестах).
String fillTemplate(String template, Map<String, Object?> values) {
  var result = template;
  for (final entry in values.entries) {
    result = result
        .replaceAll('{${entry.key}}', '${entry.value}')
        .replaceAll('[${entry.key}]', '${entry.value}');
  }
  return result;
}

/// Остались ли в тексте неподставленные плейсхолдеры `{...}`/`[...]`.
bool hasUnfilledPlaceholders(String text) =>
    RegExp(r'[\{\[][^\}\]]{1,30}[\}\]]').hasMatch(text);
