import 'package:finni_app/data/models/game_state.dart';
import 'package:finni_app/features/home/pet_thought.dart';
import 'package:flutter_test/flutter_test.dart';

/// Собирает GameState с питомцем и нужными показателями
/// (как в engine_test/models_test: withPet + copyWith).
GameState makeGame({
  int satiety = 50,
  int health = 50,
  int mood = 50,
  int savings = 0,
}) {
  final base = GameState.withPet(
    petName: 'Финни',
    fur: 'Оранжевый',
    ears: 'Круглые',
  );
  return base.copyWith(
    savings: savings,
    pet: base.pet.copyWith(
      satiety: satiety,
      health: health,
      mood: mood,
    ),
  );
}

void main() {
  group('computePetThought', () {
    test('голод (сытость < 30) → hungrySad', () {
      final thought = computePetThought(makeGame(satiety: 20), isSaver: false);
      expect(thought.type, PetEmotion.hungrySad);
      expect(thought.emoji, '🥪');
      expect(thought.text, contains('магазине'));
    });

    test('болезнь (здоровье < 30) → sick', () {
      final thought = computePetThought(makeGame(health: 20), isSaver: false);
      expect(thought.type, PetEmotion.sick);
      expect(thought.emoji, '😷');
      expect(thought.text, contains('витамины'));
    });

    test('грусть (настроение < 30) → sleepy', () {
      final thought = computePetThought(makeGame(mood: 20), isSaver: false);
      expect(thought.type, PetEmotion.sleepy);
      expect(thought.emoji, '🥺');
    });

    test('копилка (savings > 0) → saverProud', () {
      final thought = computePetThought(makeGame(savings: 100), isSaver: false);
      expect(thought.type, PetEmotion.saverProud);
      expect(thought.emoji, '📊');
    });

    test('характер «Бережливый» без копилки → saverProud', () {
      final thought = computePetThought(makeGame(), isSaver: true);
      expect(thought.type, PetEmotion.saverProud);
    });

    test('всё в норме, копилки нет → happy', () {
      final thought = computePetThought(makeGame(), isSaver: false);
      expect(thought.type, PetEmotion.happy);
      expect(thought.emoji, '🎉');
      expect(thought.text, contains('Дорожку знаний'));
    });

    test('приоритет: голод важнее копилки', () {
      final thought =
          computePetThought(makeGame(satiety: 10, savings: 500), isSaver: true);
      expect(thought.type, PetEmotion.hungrySad);
    });

    test('приоритет: болезнь важнее грусти', () {
      final thought =
          computePetThought(makeGame(health: 10, mood: 10), isSaver: false);
      expect(thought.type, PetEmotion.sick);
    });
  });
}
