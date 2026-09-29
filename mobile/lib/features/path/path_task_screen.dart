import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_snackbar.dart';
import 'path_controller.dart';
import 'path_questions.dart';

/// Запасной вопрос дорожки — показываем, пока прогресс грузится.
/// Основные вопросы — в path_questions.dart (по этапу и точке).
class PathTask {
  final String question;
  final List<String> options;
  final int correctIndex;

  const PathTask({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

const placeholderTask = PathTask(
  question: 'Что такое доход?',
  options: [
    'Деньги, которые ты получаешь',
    'Деньги, которые ты тратишь',
    'Вещи из магазина',
    'Долг другу',
  ],
  correctIndex: 0,
);

class PathTaskScreen extends ConsumerStatefulWidget {
  const PathTaskScreen({super.key});

  @override
  ConsumerState<PathTaskScreen> createState() => _PathTaskScreenState();
}

class _PathTaskScreenState extends ConsumerState<PathTaskScreen> {
  int? _picked;
  bool _resolved = false;

  /// Вопрос текущей точки из бандла: этап зажат в диапазон списка
  /// вопросов (в лесу этот экран не открывается), точка — по модулю
  /// длины списка на всякий случай. В демо-просмотре чужой точки
  /// (demoNodeOverrideProvider) берём вопрос именно её.
  PathQuestion? _question(PathProgress? progress) {
    if (progress == null) return null;
    final list =
        pathQuestions[progress.stage.clamp(0, pathQuestions.length - 1)];
    final node = ref.read(demoNodeOverrideProvider) ?? progress.node;
    return list[node % list.length];
  }

  /// Демо-просмотр чужой точки: override задан и не совпадает с текущим
  /// прогрессом — задание только показываем, ничего не записываем.
  bool get _demoView {
    final override = ref.read(demoNodeOverrideProvider);
    if (override == null) return false;
    return override != ref.read(pathControllerProvider).valueOrNull?.node;
  }

  void _pick(int i) {
    if (_resolved) return;
    final correctIndex =
        _question(ref.read(pathControllerProvider).valueOrNull)
                ?.correctIndex ??
            placeholderTask.correctIndex;
    final firstPick = _picked == null;
    setState(() {
      _picked = i;
      if (i == correctIndex) _resolved = true;
    });
    // В учёт характера идёт только ПЕРВЫЙ выбор ответа. В демо-просмотре
    // чужой точки ответы не записываем — статистика характера не портится.
    if (firstPick && !_demoView) {
      ref
          .read(pathControllerProvider.notifier)
          .recordQuizResult(i == correctIndex);
    }
  }

  Future<void> _claim() async {
    // Демо-просмотр чужой точки: прогресс и баланс не трогаем.
    if (_demoView) {
      ref.read(demoNodeOverrideProvider.notifier).state = null;
      if (!mounted) return;
      showAppSnackBar(context, 'Демо-просмотр урока — прогресс не изменился');
      Navigator.of(context).pop();
      return;
    }
    final reward = ref.read(pathControllerProvider.notifier).nodeReward;
    await ref.read(pathControllerProvider.notifier).completeNode();
    ref.read(demoNodeOverrideProvider.notifier).state = null;
    if (!mounted) return;
    showAppSnackBar(context, 'Задание выполнено! +$reward монет');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _question(ref.watch(pathControllerProvider).valueOrNull);
    final question = q?.question ?? placeholderTask.question;
    final options = q?.options ?? placeholderTask.options;
    final correct = _picked == (q?.correctIndex ?? placeholderTask.correctIndex);
    return Scaffold(
      appBar: AppBar(title: const Text('Задание')),
      body: Padding(
        // Отступ снизу с учётом системной жестовой панели — кнопка
        // «Забрать награду» не прилипает к краю экрана.
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Text(
                question,
                style: AppTextStyles.body(color: c.text, size: 22, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionButton(
                  text: options[i],
                  state: !_resolved || _picked != i
                      ? (_picked == i ? _OptionState.picked : _OptionState.idle)
                      : (correct ? _OptionState.correct : _OptionState.wrong),
                  onTap: () => _pick(i),
                ),
              ),
            if (_picked != null) ...[
              const SizedBox(height: 8),
              if (!_resolved)
                Text(
                  'Не совсем, попробуй ещё раз!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: c.red, size: 16, weight: FontWeight.w700),
                ),
              // Объяснение — после ЛЮБОГО ответа, чтобы ребёнок понял,
              // почему так (у запасного вопроса объяснения нет).
              if (q != null) ...[
                const SizedBox(height: 8),
                AppCard(
                  color: c.cardDeep,
                  child: Text(
                    q.explanation,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: c.text, size: 16),
                  ),
                ),
              ],
            ],
            const Spacer(),
            if (_resolved)
              AppButton(
                text: 'Забрать награду',
                variant: AppButtonVariant.success,
                onPressed: _claim,
              ),
          ],
        ),
      ),
    );
  }
}

enum _OptionState { idle, picked, correct, wrong }

class _OptionButton extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionButton({required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final variant = switch (state) {
      _OptionState.idle => AppButtonVariant.ghost,
      _OptionState.picked => AppButtonVariant.purple,
      _OptionState.correct => AppButtonVariant.success,
      _OptionState.wrong => AppButtonVariant.primary,
    };
    return AppButton(text: text, variant: variant, onPressed: onTap);
  }
}
