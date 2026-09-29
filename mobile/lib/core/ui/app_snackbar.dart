import 'package:flutter/material.dart';

/// Короткое всплывающее сообщение снизу: не перекрывает игру дольше
/// пары секунд (см. баг «надписи снизу не дают проходить уровни»).
void showAppSnackBar(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      ),
    );
}
