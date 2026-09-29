import 'package:finni_app/features/path/path_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Миграция сейвов «Дорожки знаний» и метка прочитанной теории.
/// Старый формат: 4 этапа (3 обычных + лес с индексом 3); новый —
/// 6 этапов (5 обычных + лес с индексом 5). Тесты чистые: только
/// PathProgress.fromJson / copyWith / toJson, без БД и провайдеров
/// (PathController требует LocalDb — здесь не используется).
void main() {
  group('PathProgress.fromJson — миграция старых сейвов', () {
    test('Старый сейв (4 этапа, лес = stage 3): лес переезжает в stage 5', () {
      final p = PathProgress.fromJson({
        'stage': 3,
        'nodes': [8, 8, 8, 0],
      });
      expect(p.stage, 5); // лес теперь последний этап
      expect(p.nodes.length, 6);
      expect(p.nodes[0], 8);
      expect(p.nodes[1], 8);
      expect(p.nodes[2], 8);
      expect(p.nodes[3], 0); // новый этап 4 — с нуля
      expect(p.nodes[4], 0); // новый этап 5 — с нуля
      expect(p.nodes[5], 0); // прогресс леса (был 0)
    });

    test('Старый сейв с прогрессом леса: он переносится в nodes[5]', () {
      final p = PathProgress.fromJson({
        'stage': 2,
        'nodes': [8, 8, 5, 3],
      });
      expect(p.stage, 2); // обычные этапы 0..2 не меняются
      expect(p.nodes, [8, 8, 5, 0, 0, 3]);
    });

    test('Эпоха floor (без списка nodes): stage 3 → лес (5)', () {
      final p = PathProgress.fromJson({'floor': 3, 'node': 4});
      expect(p.stage, 5);
      expect(p.nodes, [0, 0, 0, 0, 0, 4]);
    });

    test('Новый формат (nodes length 6) — без изменений', () {
      final p = PathProgress.fromJson({
        'stage': 5,
        'nodes': [8, 8, 8, 8, 2, 0],
        'cycle': 3,
      });
      expect(p.stage, 5);
      expect(p.nodes, [8, 8, 8, 8, 2, 0]);
      expect(p.cycle, 3);
    });
  });

  group('theorySeen — метка прочитанной теории этапа', () {
    test('По умолчанию и при отсутствии ключа theory_seen — пусто', () {
      expect(PathProgress().theorySeen, isEmpty);
      expect(PathProgress.fromJson({'stage': 0}).theorySeen, isEmpty);
    });

    test('copyWith + toJson/fromJson сохраняют метки', () {
      final p = PathProgress().copyWith(theorySeen: {0, 3});
      final restored = PathProgress.fromJson(p.toJson());
      expect(restored.theorySeen, {0, 3});
    });
  });
}
