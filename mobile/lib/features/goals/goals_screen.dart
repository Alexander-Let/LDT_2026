import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pet_skins.dart';
import '../../core/theme.dart';
import '../../core/ui/app_snackbar.dart';
import '../../data/models/content_bundle.dart';
import '../../providers.dart';

/// «Цели» — по макету «segee» (iPhone 17 - 7): золотая шапка
/// с питомцем и облачком-мыслью о цели, тёмная часть (во всю высоту
/// остатка экрана) с карточкой прогресса, «Пополнить» + поле своей суммы
/// + кнопки +10/+20/+50, выбор цели. Сначала предлагаем выбрать цель,
/// пополнять копилку можно только после выбора.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _amountController = TextEditingController();

  /// Выбранная сумма пополнения (чипы или вписанная вручную).
  int _amount = 10;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _deposit(int amount) async {
    final result = await ref.read(gameStateControllerProvider.notifier).deposit(amount);
    if (!mounted) return;
    showAppSnackBar(
      context,
      result.error ??
          (result.reactionLine.isNotEmpty
              ? result.reactionLine
              : 'В копилку +${result.deposited}'),
    );
  }

  void _depositFromInput() {
    final raw = _amountController.text.trim();
    final amount = int.tryParse(raw) ?? 0;
    if (amount <= 0) {
      showAppSnackBar(context, 'Впиши сумму больше нуля');
      return;
    }
    _deposit(amount);
    _amountController.clear();
    setState(() => _amount = 10);
  }

  /// Снятие из копилки (ТЗ 2.5.7): только после отдельного диалога
  /// с показом последствий. Движок: savings → balance, прогресс цели
  /// уменьшается (не ниже нуля), запись в историю.
  Future<void> _withdrawFlow() async {
    final game = ref.read(gameStateControllerProvider).valueOrNull;
    final savings = game?.savings ?? 0;
    if (game == null || savings <= 0) return;
    final amount = await _askWithdrawAmount(savings, game.goalSaved);
    if (amount == null || !mounted) return;
    final error =
        await ref.read(gameStateControllerProvider.notifier).withdraw(amount);
    if (!mounted) return;
    showAppSnackBar(
      context,
      error ?? 'Снято из копилки: $amount Д — монеты снова на руках',
    );
  }

  /// Диалог снятия: поле суммы + живой текст последствий («было X,
  /// станет Y»). Возвращает сумму или null (отмена).
  Future<int?> _askWithdrawAmount(int savings, int goalSaved) {
    final controller = TextEditingController();
    var amount = 0;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Прогресс цели после снятия — как в engine.withdraw (не ниже 0).
          final after = goalSaved - amount < 0 ? 0 : goalSaved - amount;
          final valid = amount > 0 && amount <= savings;
          return AlertDialog(
            title: const Text('Снять из копилки'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  onChanged: (raw) => setDialogState(
                      () => amount = int.tryParse(raw.trim()) ?? 0),
                  decoration: InputDecoration(
                    hintText: 'сумма (в копилке $savings)',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  amount <= 0
                      ? 'Монеты вернутся на баланс.'
                      : goalSaved > 0
                          ? 'Монеты вернутся на баланс, но до цели станет '
                              'дальше: было $goalSaved, станет $after.'
                          : 'Монеты вернутся на баланс: на руках станет +$amount.',
                  style: AppTextStyles.body(
                      color: context.colors.textDim, size: 14),
                ),
                if (amount > savings)
                  Text(
                    'В копилке только $savings монет.',
                    style: AppTextStyles.body(color: Colors.redAccent, size: 14),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: valid ? () => Navigator.pop(context, amount) : null,
                child: const Text('Снять'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final game = ref.watch(gameStateControllerProvider).valueOrNull;
    final content = ref.watch(gameContentProvider);

    final goals = content?.goals ?? const <GoalItem>[];
    final selected = content?.goalById(game?.goalId);
    final cost = selected?.cost ?? 0;
    final saved = game?.goalSaved ?? 0;
    final percent = cost <= 0 ? 0 : ((saved / cost) * 100).clamp(0, 100).round();
    final done = cost > 0 && saved >= cost;

    return Scaffold(
      backgroundColor: AppColors.figmaBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Золотой прямоугольник-«фон» сверху: при свайпе вниз уезжает
              // вверх, как продолжение серого фона. Зверёк «стоит» на серой
              // части (низ картинки касается её края), в мыльном пузыре над
              // ним — эмодзи и название текущей цели (строго по центру
              // пузыря: центр шарика на 25.5% высоты картинки).
              Container(
                height: 340,
                color: AppColors.figmaHeaderGold,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 24,
                      top: 20,
                      child: Text('Цели',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        petSkinGoalsAsset(game?.pet.appearance.skin),
                        height: 270,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.pets, size: 120, color: Colors.white),
                      ),
                    ),
                    // Цель внутри мыльного пузыря: центр шарика на 25.5%
                    // высоты картинки зверька, картинка 270px прижата
                    // к низу 340px контейнера → центр пузыря на
                    // 70 + 0.255*270 = 138.85px от верха (alignment
                    // y = 2*(138.85/340) - 1 ≈ -0.18). Align центрирует
                    // колонку независимо от высоты текста (1 или 2 строки).
                    Positioned.fill(
                      child: Align(
                        alignment: const Alignment(0, -0.18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selected?.emoji ?? '🎯',
                              style: const TextStyle(fontSize: 52),
                            ),
                            if (selected != null)
                              Text(
                                selected.name,
                                style: AppTextStyles.body(
                                    color: const Color(0xFF844F12),
                                    size: 16,
                                    weight: FontWeight.w700),
                              )
                            else
                              Text(
                                'Какая будет цель?',
                                style: AppTextStyles.body(
                                    color: const Color(0xFF844F12),
                                    size: 16,
                                    weight: FontWeight.w700),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Серый бокс со скруглённым верхом — весь контент.
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.figmaBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Карточка прогресса цели.
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.figmaChip,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          if (selected == null)
                            Text('Выбери цель — и начинай копить!',
                                style: AppTextStyles.body(color: c.textDim, size: 16))
                          else ...[
                            if (done)
                              // Зелёная плашка-акцент вместо гигантской
                              // пиксельной цифры (display-шрифт цифр
                              // не вяжется с остальным текстом экрана).
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.figmaNavGreen
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.figmaNavGreen),
                                ),
                                child: Text(
                                  'Цель достигнута! 🎉',
                                  style: AppTextStyles.body(
                                    color: AppColors.figmaNavGreen,
                                    size: 26,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else
                              Text(
                                '$percent%',
                                style: AppTextStyles.number(
                                  color: AppColors.figmaSpecGold,
                                  size: 56,
                                ),
                              ),
                            Text('$saved / $cost',
                                style: AppTextStyles.number(color: c.text, size: 18)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: SizedBox(
                                height: 6,
                                child: LinearProgressIndicator(
                                  value: cost <= 0 ? 0 : (saved / cost).clamp(0.0, 1.0),
                                  backgroundColor: AppColors.figmaTrack,
                                  valueColor: AlwaysStoppedAnimation(
                                      done ? c.green : AppColors.figmaSpecGold),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Пополнение копилки: чипы суммы + своё значение +
                    // большая кнопка «Пополнить копилку».
                    Text('Пополнить копилку',
                        style: AppTextStyles.header(color: c.text, size: 22)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final amount in [10, 20, 50, 100])
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: amount == 100 ? 0 : 8),
                              child: _AmountChip(
                                amount: amount,
                                selected: _amount == amount &&
                                    _amountController.text.isEmpty,
                                onTap: () => setState(() {
                                  _amount = amount;
                                  _amountController.clear();
                                }),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: selected == null ? 0.4 : 1,
                      child: TextField(
                        controller: _amountController,
                        enabled: selected != null,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        onChanged: (raw) => setState(() {
                          _amount = int.tryParse(raw.trim()) ?? 0;
                        }),
                        onSubmitted: (_) => _depositFromInput(),
                        decoration: InputDecoration(
                          hintText: selected == null
                              ? 'сначала выбери цель'
                              : 'или впиши свою сумму',
                          hintStyle:
                              AppTextStyles.body(color: c.textDim, size: 14),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide:
                                const BorderSide(color: Colors.white, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide:
                                const BorderSide(color: Colors.white, width: 1),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide:
                                const BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        style: AppTextStyles.number(color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: (selected == null || _amount <= 0)
                          ? null
                          : () => _deposit(_amount),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: (selected == null || _amount <= 0)
                              ? AppColors.figmaCard
                              : AppColors.figmaNavGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'ПОПОЛНИТЬ КОПИЛКУ${_amount > 0 ? '  +$_amount' : ''}',
                            style: AppTextStyles.label(
                                color: (selected == null || _amount <= 0)
                                    ? c.textDim
                                    : Colors.white,
                                size: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'На руках: ${game?.balance ?? 0} Д — столько можно положить',
                      style: AppTextStyles.body(color: c.textDim, size: 13),
                    ),
                    const SizedBox(height: 10),
                    // Снятие из копилки — спокойная кнопка, приглушена,
                    // когда копилка пуста. Снятие только через диалог
                    // с подтверждением последствий (см. _withdrawFlow).
                    Opacity(
                      opacity: (game?.savings ?? 0) > 0 ? 1 : 0.4,
                      child: GestureDetector(
                        onTap:
                            (game?.savings ?? 0) > 0 ? _withdrawFlow : null,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.figmaCard,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              'СНЯТЬ ИЗ КОПИЛКИ',
                              style: AppTextStyles.label(
                                  color: c.textDim, size: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'В копилке: ${game?.savings ?? 0} Д',
                      style: AppTextStyles.body(color: c.textDim, size: 13),
                    ),
                    const SizedBox(height: 12),
                    Text('Выбор цели', style: AppTextStyles.header(color: c.text)),
                    const SizedBox(height: 8),
                    for (final goal in goals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: goal.id == game?.goalId
                                ? c.purple
                                : AppColors.figmaChip,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: InkWell(
                            onTap: () => ref
                                .read(gameStateControllerProvider.notifier)
                                .selectGoal(goal.id),
                            borderRadius: BorderRadius.circular(9),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF2A2A2A),
                                    ),
                                    child: Center(
                                      child: Text(goal.emoji,
                                          style:
                                              const TextStyle(fontSize: 18)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(goal.name,
                                            style: AppTextStyles.body(
                                                color: c.text, size: 16,
                                                weight: FontWeight.w700)),
                                        Text('Нужно: ${goal.cost}',
                                            style: AppTextStyles.body(
                                                color: AppColors.figmaTextMuted,
                                                size: 14)),
                                      ],
                                    ),
                                  ),
                                  if (goal.id == game?.goalId)
                                    const Icon(Icons.check_circle, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (goals.isEmpty)
                      Text('Цели появятся, когда загрузится контент',
                          style: AppTextStyles.body(color: c.textDim)),
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

/// Чип суммы пополнения (r20, зелёный; выбранный — ярче и с обводкой).
class _AmountChip extends StatelessWidget {
  final int amount;
  final bool selected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4FD947)
              : AppColors.figmaNavGreen,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text('+ $amount',
              style: AppTextStyles.number(color: Colors.white, size: 18)),
        ),
      ),
    );
  }
}
