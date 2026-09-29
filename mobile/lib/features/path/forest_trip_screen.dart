import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pet_skins.dart';
import '../../core/theme.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../providers.dart';
import 'forest_scenarios.dart';
import 'path_controller.dart';

/// «Поход» в бесконечном лесу — цепочка событий «какую вещь купить при
/// условии»: ситуация → выбор из 3 вариантов → объяснение (как этапы
/// дорожки). Верный выбор помогает питомцу, неверный — мягкая учебная
/// неудача: монетки потрачены, вещь не пригодилась (ТЗ 2.5.9). После всех
/// событий — старый финал: выбор, куда деть остаток монет.
class ForestTripScreen extends ConsumerStatefulWidget {
  const ForestTripScreen({super.key});

  @override
  ConsumerState<ForestTripScreen> createState() => _ForestTripScreenState();
}

class _ForestTripScreenState extends ConsumerState<ForestTripScreen> {
  /// Номер текущего события похода (0-based).
  int _step = 0;

  /// true, пока идёт списание/диалог — защита от двойного тапа.
  bool _busy = false;

  /// Сценарии этого похода (ротация по номеру круга леса).
  List<ForestScenario> _scenarios() =>
      tripScenarios(ref.read(pathControllerProvider).valueOrNull?.cycle ?? 0);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    // cycle следим через watch: при смене круга леса набор событий обновится.
    final cycle = ref.watch(pathControllerProvider).valueOrNull?.cycle ?? 0;
    final scenarios = tripScenarios(cycle);
    final scenario = scenarios[_step.clamp(0, scenarios.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.figmaBg,
      body: SafeArea(
        child: Column(
          children: [
            // Шапка: ✕ (выход без completeNode) + мысль персонажа + его арт.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Назад',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'В походе случается всякое! Выбери вещь, '
                        'которая НУЖНА именно сейчас.',
                        style: AppTextStyles.body(
                          color: const Color(0xFF3D3D3D),
                          size: 15,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    petSkinAsset(game?.pet.appearance.skin),
                    height: 56,
                    errorBuilder: (_, _, _) =>
                        const Text('🐆', style: TextStyle(fontSize: 36)),
                  ),
                ],
              ),
            ),
            // Индикатор прогресса похода.
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Событие ${_step + 1} из ${scenarios.length}',
                style: AppTextStyles.body(color: c.textDim, size: 13),
              ),
            ),
            // Текущая ситуация + варианты.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        scenario.condition,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.header(color: c.text, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < scenario.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Opacity(
                          opacity: _busy ? 0.6 : 1,
                          child: _ForestOptionCard(
                            option: scenario.options[i],
                            onTap: _busy
                                ? null
                                : () => _pickOption(scenario, i),
                          ),
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

  /// Тап по варианту: нехватка монет — объяснение без списания, событие
  /// не засчитано (остаёмся на нём); верный выбор — трата + эффекты
  /// питомцу; неверный — трата без эффектов (учебная неудача).
  Future<void> _pickOption(ForestScenario scenario, int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final option = scenario.options[index];
      final game = ref.read(gameStateControllerProvider.notifier);
      final balance =
          ref.read(gameStateControllerProvider).valueOrNull?.balance ?? 0;

      // Не хватает монет — ничего не списываем: ребёнок остаётся на этом
      // же событии и может вернуться позже с монетами.
      if (balance < option.price) {
        await _showNoCoins();
        return;
      }

      final correct = index == scenario.correctIndex;
      final String spendLine = correct
          ? 'Поход: ${option.name}.'
          : 'Поход: ${option.name} (не пригодилось).';
      final ok = await game.spendCoins(option.price, spendLine);
      // Страховка от гонки: баланс мог измениться между проверкой и тратой.
      if (!ok) {
        if (!mounted) return;
        await _showNoCoins();
        return;
      }
      if (correct && option.effects.isNotEmpty) {
        // addPetStats принимает только satiety/mood/intellect — сценарии
        // используют только эти ключи (см. forest_scenarios.dart).
        await game.addPetStats(
          satiety: option.effects['satiety'] ?? 0,
          mood: option.effects['mood'] ?? 0,
          intellect: option.effects['intellect'] ?? 0,
          line: 'Поход: ${option.name} пригодился.',
        );
      }
      if (!mounted) return;

      // Объяснение выбора, затем — следующее событие или финал похода.
      await showDialog<void>(
        context: context,
        builder: (_) => _ForestResultDialog(
          text: correct ? scenario.rightText : scenario.wrongText,
        ),
      );
      if (!mounted) return;
      await _nextOrFinish();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Диалог при нехватке монет: без списания, событие не засчитано.
  Future<void> _showNoCoins() => showDialog<void>(
        context: context,
        builder: (_) => const _ForestResultDialog(
          text: 'Не хватает монет — выполни задания дорожки и возвращайся!',
        ),
      );

  /// Следующее событие, а после последнего — короткий переход «В поход!»
  /// и финальный выбор остатка монет.
  Future<void> _nextOrFinish() async {
    if (_step + 1 < _scenarios().length) {
      setState(() => _step += 1);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => const _ForestResultDialog(
        text: '🎒 Вещи собраны — Финни готов!',
        buttonText: 'В поход!',
      ),
    );
    if (!mounted) return;
    await _finishTrip();
  }

  /// Завершение похода: сначала выбор, куда деть остаток монет
  /// (копилка / нужное / хотелка / ничего), затем объяснение результата
  /// и только потом completeNode + закрытие экрана.
  Future<void> _finishTrip() async {
    final balance =
        ref.read(gameStateControllerProvider).valueOrNull?.balance ?? 0;
    final choice = await showDialog<ForestChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ForestChoiceDialog(canPay: balance >= 10),
    );
    if (!mounted) return;

    final game = ref.read(gameStateControllerProvider.notifier);
    final path = ref.read(pathControllerProvider.notifier);
    // null — «Ничего не делать»: без объяснения, сразу завершаем точку.
    String? explanation;

    if (choice == ForestChoice.save) {
      await path.recordForestChoice(ForestChoice.save);
      final res = await game.deposit(10);
      explanation = res.error != null
          ? '${res.error}\nПока нечего откладывать — выполни задания дорожки!'
          : 'Отлично! Копилка растёт — большая цель становится ближе. '
              'Откладывать понемногу — верный путь к мечте.';
    } else if (choice == ForestChoice.need) {
      // Выбор учитываем даже при нехватке монет — поэтому до траты.
      await path.recordForestChoice(ForestChoice.need);
      final ok = await game.spendCoins(10, 'Поход: куплено нужное за 10 монет.');
      if (ok) {
        await game.addPetStats(
            satiety: 12, line: 'Поход: питомец поел нужной еды.');
        explanation = 'Питомец сыт и здоров — нужное всегда важнее хотелок!';
      } else {
        explanation = 'Не хватает монет — подкопи на заданиях!';
      }
    } else if (choice == ForestChoice.want) {
      await path.recordForestChoice(ForestChoice.want);
      final ok = await game.spendCoins(10, 'Поход: хотелка за 10 монет.');
      if (ok) {
        await game.addPetStats(
            mood: 12, line: 'Поход: хотелка подняла настроение.');
        explanation =
            'Весело! Но помни: сначала нужное и копилка — и только потом хотелки.';
      } else {
        explanation = 'Не хватает монет — подкопи на заданиях!';
      }
    }
    if (!mounted) return;

    final text = explanation;
    if (text != null) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ForestResultDialog(text: text),
      );
      if (!mounted) return;
    }

    await ref.read(pathControllerProvider.notifier).completeNode();
    if (mounted) Navigator.of(context).pop();
  }
}

/// Большая карточка-вариант: эмодзи, название и цена. Высота от 48dp —
/// удобна для детского тапа.
class _ForestOptionCard extends StatelessWidget {
  final ForestOption option;
  final VoidCallback? onTap;

  const _ForestOptionCard({required this.option, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: AppColors.figmaChip,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.name,
                  style: AppTextStyles.body(
                      color: c.text, size: 17, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              // Цифра — Jersey 10 (шрифт цен), слово «монет» — Nunito:
              // у Jersey 10 нет кириллицы.
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${option.price}',
                      style: AppTextStyles.price(color: c.coins, size: 20),
                    ),
                    TextSpan(
                      text: ' монет',
                      style: AppTextStyles.body(
                          color: c.coins, size: 14, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Диалог выбора: что сделать с остатком монет после закупки в поход.
/// Кнопки с ценой приглушены, если монет не хватает, но остаются
/// нажимаемыми — нехватка потом объясняется (учебная «безопасная ошибка»).
class _ForestChoiceDialog extends StatelessWidget {
  final bool canPay;

  const _ForestChoiceDialog({required this.canPay});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.cardDeep,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Осталось немного монет. Что сделаем с ними?',
              textAlign: TextAlign.center,
              style: AppTextStyles.header(
                  color: AppColors.figmaHeaderGold, size: 20),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: canPay ? 1 : 0.5,
              child: AppButton(
                text: '🐷 Отложить в копилку (−10)',
                variant: AppButtonVariant.purple,
                width: double.infinity,
                onPressed: () => Navigator.of(context).pop(ForestChoice.save),
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: canPay ? 1 : 0.5,
              child: AppButton(
                text: '🍲 Купить нужное (−10)',
                variant: AppButtonVariant.success,
                width: double.infinity,
                onPressed: () => Navigator.of(context).pop(ForestChoice.need),
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: canPay ? 1 : 0.5,
              child: AppButton(
                text: '🎀 Взять хотелку (−10)',
                width: double.infinity,
                onPressed: () => Navigator.of(context).pop(ForestChoice.want),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: c.textDim,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Ничего не делать',
                style: AppTextStyles.body(color: c.textDim, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Маленький диалог с объяснением результата выбора и кнопкой «Понятно!»
/// (текст кнопки можно заменить — например, на «В поход!»).
class _ForestResultDialog extends StatelessWidget {
  final String text;
  final String buttonText;

  const _ForestResultDialog({required this.text, this.buttonText = 'Понятно!'});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.cardDeep,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: c.text, size: 16),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: buttonText,
              variant: AppButtonVariant.success,
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
