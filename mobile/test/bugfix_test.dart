import 'dart:convert';
import 'dart:io';

import 'package:finni_app/data/engine/game_engine.dart' as engine;
import 'package:finni_app/data/engine/phase_flow.dart' as flow;
import 'package:finni_app/data/engine/templates.dart';
import 'package:finni_app/data/models/content_bundle.dart';
import 'package:finni_app/data/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

GameContent loadContent() {
  final raw = File('assets/content/bundle.json').readAsStringSync();
  return GameContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  final content = loadContent();

  group('Подстановка плейсхолдеров', () {
    test('fillTemplate: {key} и [key] подставляются', () {
      expect(fillTemplate('Привет! Я {имя}.', {'имя': 'Финни'}), 'Привет! Я Финни.');
      expect(fillTemplate('Я [Питомец]!', {'Питомец': 'Финни'}), 'Я Финни!');
      expect(fillTemplate('Не хватает {n} монет', {'n': 5}), 'Не хватает 5 монет');
      expect(fillTemplate('Срок ~{k} недель', {'k': 12}), 'Срок ~12 недель');
    });

    test('hasUnfilledPlaceholders ловит сырые скобки', () {
      expect(hasUnfilledPlaceholders('Я {имя}'), isTrue);
      expect(hasUnfilledPlaceholders('Тут [N] монет'), isTrue);
      expect(hasUnfilledPlaceholders('Всё чисто'), isFalse);
    });

    test('Реплика появления питомца: после подстановки нет скобок', () {
      final lines = content.periodDef(1).stringList('appearance_dialog');
      expect(lines, isNotEmpty);
      for (final line in lines) {
        final filled = fillTemplate(line, {'имя': 'Финни', 'Питомец': 'Финни'});
        expect(hasUnfilledPlaceholders(filled), isFalse, reason: line);
      }
    });

    test('Ключевые шаблоны бандла заполняются без остатка', () {
      final cases = <String, Map<String, Object?>>{
        content.economy.passiveIncome.totalLineTemplate: {'total': 28},
        content.economy.parentBonus.childNotificationTemplate: {'amount': 20, 'reason': 'За помощь по дому'},
        content.economy.purchaseFeedback.notEnoughCoins: {'n': 7},
        content.economy.savingsWithdrawal.confirmTemplate: {'n': 10, 'm': 30, 'l': 170, 'k': 2},
        content.taskByCode('A1')!.data['trigger_line'] as String: {'n': 40},
        content.taskByCode('B1')!.data['prompt'] as String: {'n': 80},
        content.taskByCode('B1')!.data['eta_template'] as String: {'k': 14},
      };
      cases.forEach((template, values) {
        final filled = fillTemplate(template, values);
        expect(hasUnfilledPlaceholders(filled), isFalse, reason: template);
      });
    });
  });

  group('Регрессия: кнопка «Слушаю» запускает курс', () {
    test('Период 1: profession → «Слушаю» (completePhase) → course', () {
      var s = GameState.withPet(petName: 'Финни', fur: 'Оранжевый', ears: 'Круглые')
          .copyWith(phase: 'profession');
      s = engine.chooseProfession(s, content.professionById('artist')!, content);
      expect(s.professionId, 'artist');
      expect(s.professionChanged, isTrue);
      s = flow.advancePhase(s, content);
      expect(s.phase, 'course');
    });

    test('Период 3, смена профессии: profession → «Слушаю» → course', () {
      var s = GameState.withPet(petName: 'Финни', fur: 'Оранжевый', ears: 'Круглые')
          .copyWith(phase: 'profession', period: 3, professionId: 'courier', ownedItems: const ['item_11']);
      s = engine.chooseProfession(s, content.professionById('illustrator')!, content);
      expect(s.professionChanged, isTrue);
      s = flow.advancePhase(s, content);
      expect(s.phase, 'course');
    });

    test('Период 2 без смены: profession → «Слушаю» → minigame (курс не нужен)', () {
      var s = GameState.withPet(petName: 'Финни', fur: 'Оранжевый', ears: 'Круглые')
          .copyWith(phase: 'profession', period: 2, professionId: 'courier');
      s = engine.chooseProfession(s, content.professionById('courier')!, content);
      expect(s.professionChanged, isFalse);
      s = flow.advancePhase(s, content);
      expect(s.phase, 'minigame');
    });
  });
}
