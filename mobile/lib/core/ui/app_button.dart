import 'package:flutter/material.dart';

import '../../core/theme.dart';

enum AppButtonVariant { primary, success, purple, ghost }

/// Кнопка из макетов: радиус 13, подпись Impact 20 uppercase.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (variant) {
      AppButtonVariant.primary => (c.orange, Colors.white),
      AppButtonVariant.success => (c.green, Colors.black),
      AppButtonVariant.purple => (c.purple, Colors.white),
      AppButtonVariant.ghost => (c.card, c.text),
    };
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: height),
      child: Material(
        color: onPressed == null ? c.cardDeep : bg,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: Padding(
            // Длинные подписи переносятся на 2 строки — кнопка растёт
            // (minHeight), текст не вылезает за края.
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Center(
              child: Text(
                text.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTextStyles.label(color: onPressed == null ? c.textDim : fg, size: 21),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
