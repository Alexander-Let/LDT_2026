import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/routes.dart';
import '../../core/theme.dart';
import '../main/tutorial_overlay.dart';

/// «Ещё» — по макету «segee» (iPhone 17 - 6): заголовок + ряды-карточки
/// #3D3D3D (r13) с квадратом-иконкой 41×41 (r12) и подписью. Иконки —
/// Iconly Bulk (SVG из Context/design), подпись одной строкой 20pt.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text('Еще', style: AppTextStyles.header(color: c.text)),
            const SizedBox(height: 24),
            _MoreRow(
              icon: 'assets/icons/Game.svg',
              iconColor: AppColors.figmaNavGreen,
              text: 'Как играть?',
              onTap: () => TutorialOverlay.show(context),
            ),
            _MoreRow(
              icon: 'assets/icons/Document.svg',
              iconColor: AppColors.figmaHeaderBlue,
              text: 'Финансовый дневник',
              onTap: () => Navigator.of(context).pushNamed(Routes.diary),
            ),
            _MoreRow(
              icon: 'assets/icons/Info Square.svg',
              iconColor: AppColors.figmaHeaderBlue,
              text: 'Справка',
              onTap: () => Navigator.of(context).pushNamed(Routes.glossary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final String text;
  final VoidCallback onTap;

  const _MoreRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.figmaCard,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    width: 24,
                    height: 24,
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(color: Colors.white, size: 20),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
