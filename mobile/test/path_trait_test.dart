import 'package:finni_app/features/path/path_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Характер игрока дорожки — чистая функция computeTrait, без БД
/// и провайдеров. Порядок приоритета: saver → smart → caring.
void main() {
  group('computeTrait', () {
    test('Бережливый: копилка выросла на 30+ монет', () {
      expect(
        computeTrait(
            savedDelta: 30,
            quizCorrect: 0,
            quizTotal: 0,
            forestNeed: 0,
            forestWant: 0),
        'saver',
      );
      expect(
        computeTrait(
            savedDelta: 100,
            quizCorrect: 0,
            quizTotal: 0,
            forestNeed: 0,
            forestWant: 0),
        'saver',
      );
    });

    test('Сообразительный: ≥75% уроков решены с первого раза', () {
      // Граница ровно 75% — засчитывается.
      expect(
        computeTrait(
            savedDelta: 0,
            quizCorrect: 3,
            quizTotal: 4,
            forestNeed: 0,
            forestWant: 0),
        'smart',
      );
      // Ниже 75% — нет.
      expect(
        computeTrait(
            savedDelta: 0,
            quizCorrect: 1,
            quizTotal: 2,
            forestNeed: 0,
            forestWant: 0),
        isNull,
      );
      // Без уроков характер по ответам не даётся (деление на ноль).
      expect(
        computeTrait(
            savedDelta: 0,
            quizCorrect: 0,
            quizTotal: 0,
            forestNeed: 0,
            forestWant: 0),
        isNull,
      );
    });

    test('Заботливый: в лесу нужное выбирали чаще хотелок', () {
      expect(
        computeTrait(
            savedDelta: 0,
            quizCorrect: 0,
            quizTotal: 0,
            forestNeed: 2,
            forestWant: 1),
        'caring',
      );
      // Поровну — не считается.
      expect(
        computeTrait(
            savedDelta: 0,
            quizCorrect: 0,
            quizTotal: 0,
            forestNeed: 1,
            forestWant: 1),
        isNull,
      );
      // Ноль выборов — не считается.
      expect(
        computeTrait(
            savedDelta: 0,
            quizCorrect: 0,
            quizTotal: 0,
            forestNeed: 0,
            forestWant: 0),
        isNull,
      );
    });

    test('Приоритет: Бережливый важнее Сообразительного и Заботливого', () {
      expect(
        computeTrait(
            savedDelta: 30,
            quizCorrect: 4,
            quizTotal: 4,
            forestNeed: 3,
            forestWant: 0),
        'saver',
      );
    });

    test('Приоритет: Сообразительный важнее Заботливого', () {
      expect(
        computeTrait(
            savedDelta: 0,
            quizCorrect: 4,
            quizTotal: 4,
            forestNeed: 3,
            forestWant: 0),
        'smart',
      );
    });

    test('Ничего не подошло — null (старый характер сохраняется)', () {
      expect(
        computeTrait(
            savedDelta: 29,
            quizCorrect: 1,
            quizTotal: 2,
            forestNeed: 0,
            forestWant: 3),
        isNull,
      );
    });
  });
}
