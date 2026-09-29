import 'package:finni_app/features/path/forest_scenarios.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сценарии лесного похода — чистые данные и ротация tripScenarios,
/// без БД и провайдеров.
void main() {
  group('forestScenarios', () {
    test('сценариев не меньше 6', () {
      expect(forestScenarios.length, greaterThanOrEqualTo(6));
    });

    test('у каждого ровно 3 опции, correctIndex в диапазоне, '
        'эффекты только у правильной опции', () {
      for (final s in forestScenarios) {
        expect(s.options, hasLength(3), reason: s.condition);
        expect(s.correctIndex, inInclusiveRange(0, s.options.length - 1),
            reason: s.condition);
        for (var i = 0; i < s.options.length; i++) {
          final o = s.options[i];
          if (i == s.correctIndex) {
            expect(o.effects, isNotEmpty,
                reason: '${s.condition} → ${o.name} (правильная)');
          } else {
            expect(o.effects, isEmpty,
                reason: '${s.condition} → ${o.name} (неправильная)');
          }
        }
      }
    });

    test('цены всех опций больше 0 и не больше 20 монет', () {
      for (final s in forestScenarios) {
        for (final o in s.options) {
          expect(o.price, greaterThan(0), reason: '${s.condition} → ${o.name}');
          expect(o.price, lessThanOrEqualTo(20),
              reason: '${s.condition} → ${o.name}');
        }
      }
    });
  });

  group('tripScenarios', () {
    test('возвращает 2 разных сценария на поход', () {
      for (var cycle = 0; cycle < forestScenarios.length; cycle++) {
        final pair = tripScenarios(cycle);
        expect(pair, hasLength(2), reason: 'cycle $cycle');
        expect(identical(pair[0], pair[1]), isFalse,
            reason: 'cycle $cycle: события похода не должны повторяться');
      }
    });

    test('ротация по cycle: пары при 0..3 различаются '
        'и вместе покрывают все сценарии', () {
      final pairs = <String>{};
      final seen = <ForestScenario>{};
      for (var cycle = 0; cycle < 4; cycle++) {
        final pair = tripScenarios(cycle);
        pairs.add(pair.map((s) => s.condition).join(' | '));
        seen.addAll(pair);
      }
      expect(pairs, hasLength(4));
      expect(seen, hasLength(forestScenarios.length));
    });
  });
}
