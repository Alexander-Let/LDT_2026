import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Вид иконки шкалы состояния (векторные, без эмодзи).
enum StatIconKind { heart, smile, drop }

/// Панель состояния питомца — 1-в-1 по фотке макета «segee»:
/// слева две ячейки (Сытость #FF9EB7, Настроение #56C05D): иконка + название
/// слева, процент крупно справа, под ними тонкий прогресс-бар во всю ширину;
/// справа ячейка монет с золотой монеткой, выпирающей из короба.
class StatusBar extends StatelessWidget {
  final int satiety;
  final int mood;
  final int balance;

  /// Подпись второй шкалы: обычно «Настроение», в лесном походе — «Водичка».
  final String moodLabel;

  const StatusBar({
    super.key,
    required this.satiety,
    required this.mood,
    required this.balance,
    this.moodLabel = 'Настроение',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _StatCell(
                icon: StatIconKind.heart,
                label: 'Сытость',
                value: satiety,
                color: AppColors.figmaStrokePink,
              ),
              const SizedBox(height: 10),
              _StatCell(
                icon: moodLabel == 'Водичка' ? StatIconKind.drop : StatIconKind.smile,
                label: moodLabel,
                value: mood,
                // Водичка в лесном походе — синяя (капля), настроение —
                // зелёное (смайлик).
                color: moodLabel == 'Водичка'
                    ? AppColors.figmaHeaderBlue
                    : AppColors.figmaStrokeMood,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _CoinsCell(balance: balance)),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final StatIconKind icon;
  final String label;
  final int value;
  final Color color;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.figmaCardDeep,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CustomPaint(
                size: const Size(19, 19),
                painter: StatIconPainter(kind: icon, color: color),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(color: Colors.white, size: 16),
                ),
              ),
              Text('$value%',
                  style: AppTextStyles.number(color: Colors.white, size: 19)),
            ],
          ),
          const SizedBox(height: 2),
          // Тонкий прогресс-бар во всю ширину ячейки — всегда в цвет
          // шкалы (как сердечко и рамка), без жёлтого/красного переключения.
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: value.clamp(0, 100) / 100,
                backgroundColor: AppColors.figmaTrack,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinsCell extends StatelessWidget {
  final int balance;

  const _CoinsCell({required this.balance});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 106,
        decoration: BoxDecoration(
          color: AppColors.figmaCardDeep,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.figmaStrokeCoins, width: 1.5),
        ),
        child: Stack(
          children: [
            // Золотая монетка слева, помещается в короб целиком (арт
            // прозрачный — монета «Р» из LST/moneta.png).
            Positioned(
              left: 6,
              top: 12,
              child: Image.asset(
                'assets/pet/coin_single.png',
                width: 76,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.paid, color: Color(0xFFFFBF33), size: 60),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Text('Деняжек',
                  style: AppTextStyles.label(color: AppColors.figmaOrangeText, size: 20)),
            ),
            Positioned(
              right: 8,
              bottom: 2,
              child: Text('$balance',
                  style: AppTextStyles.number(color: Colors.white, size: 56)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Векторные иконки шкал состояния (без эмодзи): сердце (сытость),
/// смайлик (настроение), капля (водичка в походе).
class StatIconPainter extends CustomPainter {
  final StatIconKind kind;
  final Color color;

  const StatIconPainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case StatIconKind.heart:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.92)
          ..cubicTo(w * 0.10, h * 0.60, w * 0.02, h * 0.34, w * 0.20, h * 0.18)
          ..cubicTo(w * 0.34, h * 0.06, w * 0.47, h * 0.14, w * 0.5, h * 0.28)
          ..cubicTo(w * 0.53, h * 0.14, w * 0.66, h * 0.06, w * 0.80, h * 0.18)
          ..cubicTo(w * 0.98, h * 0.34, w * 0.90, h * 0.60, w * 0.5, h * 0.92)
          ..close();
        canvas.drawPath(path, paint);
      case StatIconKind.smile:
        canvas.drawCircle(
            Offset(w / 2, h / 2), w * 0.46, paint..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.10);
        final fg = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(w * 0.36, h * 0.40), w * 0.055, fg);
        canvas.drawCircle(Offset(w * 0.64, h * 0.40), w * 0.055, fg);
        final smile = Path()
          ..moveTo(w * 0.30, h * 0.60)
          ..quadraticBezierTo(w * 0.5, h * 0.78, w * 0.70, h * 0.60);
        canvas.drawPath(
            smile,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.08
              ..strokeCap = StrokeCap.round);
      case StatIconKind.drop:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.04)
          ..cubicTo(w * 0.72, h * 0.36, w * 0.88, h * 0.52, w * 0.88, h * 0.66)
          ..cubicTo(w * 0.88, h * 0.86, w * 0.70, h * 0.96, w * 0.5, h * 0.96)
          ..cubicTo(w * 0.30, h * 0.96, w * 0.12, h * 0.86, w * 0.12, h * 0.66)
          ..cubicTo(w * 0.12, h * 0.52, w * 0.28, h * 0.36, w * 0.5, h * 0.04)
          ..close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StatIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
