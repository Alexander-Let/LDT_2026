import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/game_state.dart';
import '../../providers.dart';
import '../path/path_controller.dart';

/// Эмоциональное состояние питомца для облачка мыслей (ТЗ 2.5.9).
///
/// ВНИМАНИЕ: модель питомца в game_state.dart называется `PetState` —
/// это имя занято, поэтому здесь `PetEmotion`/`PetThought`.
enum PetEmotion { happy, hungrySad, saverProud, sick, sleepy }

/// Одна «мысль» питомца: эмоция + эмодзи + текст простыми словами
/// (дети 7–11): сначала причина (что случилось), затем следующий шаг
/// (что ребёнку делать).
class PetThought {
  final PetEmotion type;
  final String emoji;
  final String text;

  const PetThought({
    required this.type,
    required this.emoji,
    required this.text,
  });
}

/// Чистая функция выбора мысли по состоянию игры. Приоритет — первое
/// сработавшее условие: базовые нужды (еда/здоровье/настроение) важнее
/// похвалы за копилку.
PetThought computePetThought(GameState game, {required bool isSaver}) {
  if (game.pet.satiety < 30) {
    return const PetThought(
      type: PetEmotion.hungrySad,
      emoji: '🥪',
      text: 'Финни хочет есть! Купи еду в магазине — потяни панель внизу вверх.',
    );
  }
  if (game.pet.health < 30) {
    return const PetThought(
      type: PetEmotion.sick,
      emoji: '😷',
      text: 'Финни нездоров. Купи витамины в магазине!',
    );
  }
  if (game.pet.mood < 30) {
    return const PetThought(
      type: PetEmotion.sleepy,
      emoji: '🥺',
      text: 'Финни грустит… Подними ему настроение — загляни в магазин!',
    );
  }
  if (isSaver || game.savings > 0) {
    return const PetThought(
      type: PetEmotion.saverProud,
      emoji: '📊',
      text: 'Финни гордится: ты копишь на цель! Так держать!',
    );
  }
  return const PetThought(
    type: PetEmotion.happy,
    emoji: '🎉',
    text: 'Финни рад тебя видеть! Загляни в Дорожку знаний — там монетки.',
  );
}

/// Текущая мысль питомца. Следит за игровым состоянием и характером
/// игрока (trait == 'saver' из «Дорожки знаний» — «Бережливый»).
/// Пока состояние не загружено (null) — нейтральное приветствие.
final petThoughtProvider = Provider<PetThought>((ref) {
  final game = ref.watch(gameStateControllerProvider).valueOrNull;
  final isSaver =
      ref.watch(pathControllerProvider).valueOrNull?.trait == 'saver';
  if (game == null) {
    return const PetThought(
      type: PetEmotion.happy,
      emoji: '🎉',
      text: 'Финни рад тебя видеть!',
    );
  }
  return computePetThought(game, isSaver: isSaver);
});

/// Облачко мыслей над головой питомца: белый бабл (радиус 16) с
/// эмодзи и текстом, снизу — хвостик из двух убывающих кружков
/// «мысли» к питомцу. Слегка покачивается (±3 px, ~2 с), содержимое
/// сменяется плавно (AnimatedSwitcher, 300 мс).
///
/// Самодостаточный виджет: сам следит за [petThoughtProvider],
/// ширина ограничена ~260 (ConstrainedBox).
class ThoughtBubble extends ConsumerStatefulWidget {
  const ThoughtBubble({super.key});

  @override
  ConsumerState<ThoughtBubble> createState() => _ThoughtBubbleState();
}

class _ThoughtBubbleState extends ConsumerState<ThoughtBubble>
    with SingleTickerProviderStateMixin {
  /// Покачивание облачка (repeat reverse: -3 … +3 px по вертикали).
  late final AnimationController _sway;

  @override
  void initState() {
    super.initState();
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thought = ref.watch(petThoughtProvider);
    return AnimatedBuilder(
      animation: _sway,
      builder: (context, child) => Transform.translate(
        // -3..+3 px: repeat(reverse) плавно качает туда-обратно.
        offset: Offset(0, -3 + 6 * _sway.value),
        child: child,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Сам бабл.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              // Плавная смена текста/эмодзи при смене эмоции.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Row(
                  key: ValueKey(thought.type),
                  children: [
                    Text(
                      thought.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        thought.text,
                        style: AppTextStyles.body(
                          color: const Color(0xFF3D3D3D),
                          size: 15,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Хвостик «мысли» к питомцу: два убывающих кружка.
            const SizedBox(height: 2),
            Align(
              alignment: const Alignment(0.2, 0),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: const Alignment(0.35, 0),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
