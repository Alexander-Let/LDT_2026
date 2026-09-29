import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/section_header.dart';
import '../../providers.dart';

/// Финансовый дневник (по макету iPhone 17 - 16): синяя шапка с артом,
/// тёмная часть со скруглённым верхом, история операций.
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    final history = (game?.history ?? const []).reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.figmaHeaderBlue,
      body: SafeArea(
        bottom: false,
        child: game == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Stack(
                    children: [
                      const SectionHeader(
                        title: 'Финансовый дневник',
                        color: AppColors.figmaHeaderBlue,
                        artAsset: 'assets/bg/header_art.png',
                        height: 160,
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  // Серый блок — на весь остаток экрана (до самого низа).
                  Expanded(
                    child: RoundedBody(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          AppCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _sum('Баланс', '${game.balance}', c.coins, context),
                                _sum('Копилка', '${game.savings}', c.green, context),
                                _sum('Цель', '${game.goalSaved}', c.gold, context),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (history.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text('Пока пусто — соверши первую операцию!',
                                    style: AppTextStyles.body(color: c.textDim)),
                              ),
                            )
                          else
                            for (final entry in history)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Text(entry.text,
                                      style: AppTextStyles.body(
                                          color: c.text, size: 14)),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sum(String label, String value, Color color, BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Text(label, style: AppTextStyles.body(color: c.textDim, size: 13)),
        Text(value, style: AppTextStyles.number(color: color, size: 28)),
      ],
    );
  }
}
