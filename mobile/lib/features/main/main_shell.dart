import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../goals/goals_screen.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../parents/parents_screen.dart';
import '../path/path_screen.dart';
import '../tasks/tasks_screen.dart';
import 'tutorial_overlay.dart';

/// Индекс активной вкладки — экраны могут переключать вкладку изнутри
/// (например, сюжетные задания ведут на «Дорожку знаний»).
final mainTabProvider = StateProvider<int>((ref) => 0);

/// Основной каркас: 6 вкладок — Главная, Цели, Дорожка, Задания, Родителям,
/// Ещё. Панель в цвет фона вкладок (#2A2A2A), сверху тонкая светлая
/// линия, активная вкладка — белая иконка Iconly Bulk в зелёном круге (#41C23B).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  static const _tabs = [
    HomeScreen(),
    GoalsScreen(),
    PathScreen(),
    TasksScreen(),
    ParentsScreen(),
    MoreScreen(),
  ];

  static const _labels = ['Главная', 'Цели', 'Дорожка', 'Задания', 'Родителям', 'Ещё'];

  /// Иконки вкладок — Iconly Bulk (SVG, см. Context/design/iconly_src).
  static const _icons = [
    'assets/icons/Home.svg',
    'assets/icons/Chart.svg',
    'assets/icons/Discovery.svg',
    'assets/icons/Game.svg',
    'assets/icons/2 User.svg',
    'assets/icons/Category.svg',
  ];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // MainShell появляется после создания питомца — сплэш уже позади,
    // обучалку можно показать поверх первого кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  /// Первый вход: если флага нет — показать обучалку по разделам.
  /// Любое закрытие («Дальше»/«Понятно!»/«Пропустить») помечает прочитанным.
  Future<void> _maybeShowTutorial() async {
    final db = ref.read(localDbProvider);
    final seen = await db.kvGet(tutorialSeenKey);
    if (!mounted || (seen != null && seen.isNotEmpty)) return;
    await TutorialOverlay.show(context);
    await db.kvSet(tutorialSeenKey, '1');
  }

  /// Выбор вкладки: «Родителям» (4) — только через барьер-пример.
  /// Разблокировка не запоминается: пример спрашивается при КАЖДОМ тапе
  /// на вкладку (ТЗ 2.5.12).
  void _selectTab(int i) {
    if (i == 4) {
      _showParentsGate();
      return;
    }
    ref.read(mainTabProvider.notifier).state = i;
  }

  Future<void> _showParentsGate() async {
    final a = 6 + Random().nextInt(4); // 6..9
    final b = 6 + Random().nextInt(4);
    final answer = TextEditingController();
    var wrong = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AppColors.figmaCard,
          title: const Text('Для взрослых'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Реши пример, чтобы войти: $a × $b = ?',
                  style: AppTextStyles.body(color: Colors.white, size: 17)),
              const SizedBox(height: 8),
              TextField(
                controller: answer,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: AppTextStyles.body(color: Colors.white, size: 20),
                onSubmitted: (_) => _checkGate(ctx, a, b, answer.text, setDialog,
                    () => wrong = true),
              ),
              if (wrong)
                Text('Неверно, попробуй ещё раз',
                    style: AppTextStyles.body(color: Colors.redAccent, size: 14)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => _checkGate(ctx, a, b, answer.text, setDialog,
                  () => wrong = true),
              child: const Text('Войти'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      ref.read(mainTabProvider.notifier).state = 4;
    }
  }

  void _checkGate(BuildContext ctx, int a, int b, String raw,
      void Function(void Function()) setDialog, VoidCallback markWrong) {
    if (int.tryParse(raw.trim()) == a * b) {
      Navigator.of(ctx).pop(true);
    } else {
      setDialog(markWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(mainTabProvider);
    return Scaffold(
      body: IndexedStack(index: tab, children: MainShell._tabs),
      bottomNavigationBar: _NavBar(
        selected: tab,
        onSelect: _selectTab,
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _NavBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.figmaBg,
        border: Border(top: BorderSide(color: AppColors.figmaDivider, width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 6, 8, 6 + bottom),
        child: Row(
          children: [
            for (var i = 0; i < MainShell._labels.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == selected
                              ? AppColors.figmaNavGreen
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            MainShell._icons[i],
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              i == selected
                                  ? Colors.white
                                  : const Color(0xFF9A9A9A),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        MainShell._labels[i],
                        // 6 вкладок теснее: подпись 11pt, без переноса
                        // («Родителям» в 12pt не влезает в ~57dp на 360dp).
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(
                          color: i == selected ? Colors.white : const Color(0xFF9A9A9A),
                          size: 11,
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
}
