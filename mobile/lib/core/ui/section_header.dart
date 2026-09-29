import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Цветная шапка экрана в стиле макетов «segee»: цветной блок, слева
/// заголовок (Comic Sans 24), справа — арт (картинка) или эмодзи.
class SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final String emoji;
  final String? artAsset;
  final double height;

  const SectionHeader({
    super.key,
    required this.title,
    required this.color,
    this.emoji = '',
    this.artAsset,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (artAsset != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 260,
              child: Image.asset(
                artAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(title, style: AppTextStyles.header(color: Colors.white)),
            ),
          ),
          if (emoji.isNotEmpty && artAsset == null)
            Positioned(
              right: 20,
              bottom: 12,
              child: Text(emoji, style: const TextStyle(fontSize: 72)),
            ),
        ],
      ),
    );
  }
}

/// Тёмная часть контента со скруглённым верхом (наплывает на шапку).
class RoundedBody extends StatelessWidget {
  final Widget child;

  const RoundedBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.figmaBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: child,
    );
  }
}
