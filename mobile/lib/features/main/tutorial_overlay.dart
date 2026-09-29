import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';
import '../../core/ui/app_button.dart';

/// Ключ kv-флага «обучалка уже показана» (показ один раз при первом входе).
const tutorialSeenKey = 'tutorial_seen_v1';

/// Начальная инструкция по разделам приложения (ТЗ 2.5.1): 6 страниц —
/// по одной на вкладку. Показывается один раз из MainShell и повторно
/// по кнопке «Как играть?» в разделе «Ещё».
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key});

  /// Полноэкранный диалог обучалки. Закрывается кнопкой «Дальше»/«Понятно!»
  /// или «Пропустить» — любой выход считается прочтением.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Обучение',
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => const TutorialOverlay(),
    );
  }

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _TutorialPage(
      icon: 'assets/icons/Home.svg',
      title: 'Главная',
      text: 'Здесь живёт твой питомец.\nПотяни панель снизу вверх — там магазин!',
    ),
    _TutorialPage(
      icon: 'assets/icons/Chart.svg',
      title: 'Цели',
      text: 'Выбирай цель и копи на неё монетки в копилке.',
    ),
    _TutorialPage(
      icon: 'assets/icons/Discovery.svg',
      title: 'Дорожка',
      text: 'Проходи уроки-задания, отвечай на вопросы и получай монетки.',
    ),
    _TutorialPage(
      icon: 'assets/icons/Game.svg',
      title: 'Задания',
      text: 'Сюжетные и ежедневные задания с наградами.',
    ),
    _TutorialPage(
      icon: 'assets/icons/2 User.svg',
      title: 'Родителям',
      text: 'Раздел для мамы и папы: прогресс, настройки и привязка устройства.',
    ),
    _TutorialPage(
      icon: 'assets/icons/Category.svg',
      title: 'Ещё',
      text: 'Дневник и словарик терминов.',
    ),
  ];

  bool get _isLast => _page == _pages.length - 1;

  void _close() => Navigator.of(context).pop();

  void _next() {
    if (_isLast) {
      _close();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: AppColors.figmaBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Пропустить',
                            style: AppTextStyles.label(
                                color: c.textDim, size: 16)),
                        const SizedBox(width: 6),
                        Icon(Icons.close, color: c.textDim, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? AppColors.figmaNavGreen
                            : AppColors.figmaDivider,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              AppButton(
                text: _isLast ? 'Понятно!' : 'Дальше',
                variant: AppButtonVariant.success,
                width: double.infinity,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Одна страница обучалки: иконка вкладки в зелёном круге (как активная
/// вкладка в навбаре), название и 1–2 коротких предложения.
class _TutorialPage extends StatelessWidget {
  final String icon;
  final String title;
  final String text;

  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.figmaNavGreen,
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                width: 64,
                height: 64,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(title, style: AppTextStyles.header(color: c.text)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: c.textDim, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}
