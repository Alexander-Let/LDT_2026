import 'dart:convert';
import 'dart:io';

import 'package:finni_app/data/models/content_bundle.dart';
import 'package:finni_app/data/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

GameContent loadContent() {
  final raw = File('assets/content/bundle.json').readAsStringSync();
  return GameContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  test('Контент-бандл v2 парсится целиком', () {
    final content = loadContent();
    expect(content.schema, 2);
    expect(content.professions.length, 8);
    expect(content.shopItems.length, 27);
    expect(content.goals.length, 3);
    expect(content.tasks.length, 12);
    expect(content.hitrikScenes.length, 5);
    expect(content.events.length, 7);
    expect(content.archetypes.length, 5);
    expect(content.glossary.length, 16);
    expect(content.periods.length, 5);
    expect(content.economy.mandatoryTotalPerPeriod, 60);
    expect(content.economy.parentBonus.maxAmount, 100);
  });

  test('GameState v2 round-trip json', () {
    final original = GameState.withPet(petName: 'Финни', fur: 'Синий', ears: 'Острые')
        .copyWith(
          balance: 250,
          savings: 40,
          goalId: 'goal_01',
          goalSaved: 40,
          period: 3,
          phase: 'shop',
          sr: 65,
          srStage: 'teen',
          archetypeScores: const {'dreamer': 5, 'explorer': 3},
        );
    final restored = GameState.fromJson(original.toJson());
    expect(restored.balance, 250);
    expect(restored.savings, 40);
    expect(restored.goalId, 'goal_01');
    expect(restored.period, 3);
    expect(restored.phase, 'shop');
    expect(restored.sr, 65);
    expect(restored.pet.name, 'Финни');
    expect(restored.pet.appearance.fur, 'Синий');
    expect(restored.pet.appearance.ears, 'Острые');
    expect(restored.toJson()['schema'], GameState.schemaVersion);
  });

  test('Миграция v1 → v2 сохраняет питомца и деньги', () {
    final v1 = {
      'schema': 1,
      'balance': 120,
      'savings': 30,
      'goal_id': 'goal_03',
      'goal_saved': 30,
      'pet': {
        'name': 'Шарик',
        'color': 'mint',
        'accessory': 'bow',
        'stage': 'baby',
        'mood': 80,
        'satiety': 80,
      },
      'completed_tasks': ['budget_week'],
    };
    final migrated = GameState.fromJson(v1);
    expect(migrated.balance, 120);
    expect(migrated.savings, 30);
    expect(migrated.goalId, 'goal_03');
    expect(migrated.pet.name, 'Шарик');
    expect(migrated.pet.appearance.fur, 'Зелёный');
    expect(migrated.pet.appearance.accessory, 'bow');
    expect(migrated.period, 1);
    expect(migrated.toJson()['schema'], 2);
  });
}
