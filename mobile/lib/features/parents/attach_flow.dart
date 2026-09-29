import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme.dart';
import '../../core/ui/app_button.dart';
import '../../data/models/game_state.dart';
import '../../providers.dart';

/// Итог попытки привязки по коду.
class AttachOutcome {
  /// attach прошёл — устройство привязано к профилю по коду.
  final bool ok;

  /// Состояние подтянуто с сервера и записано локально (прогресс
  /// восстановлен). false, если на сервере сохранения ещё нет.
  final bool restored;

  /// Текст ошибки для показа пользователю (null при успехе/отмене).
  final String? error;

  const AttachOutcome._({required this.ok, required this.restored, this.error});

  factory AttachOutcome.ok({required bool restored}) =>
      AttachOutcome._(ok: true, restored: restored);

  factory AttachOutcome.error(String message) =>
      AttachOutcome._(ok: false, restored: false, error: message);

  /// Пользователь отменил замену существующего питомца — не ошибка.
  factory AttachOutcome.cancelled() =>
      const AttachOutcome._(ok: false, restored: false);
}

/// Оркестратор привязки: проверка сервера/ввода → подтверждение замены
/// (если уже есть питомец) → POST /v1/profiles/attach → загрузка state
/// с сервера и полная замена локального состояния.
///
/// Локальный прогресс не теряется ни при какой ошибке (ТЗ 3.1): замена
/// происходит только после успешных attach и GET state.
Future<AttachOutcome> attachByCode(
  WidgetRef ref,
  BuildContext context,
  String rawCode,
) async {
  final code = rawCode.trim().toUpperCase();
  if (code.length != 6) {
    return AttachOutcome.error('Введи код из 6 символов');
  }

  // Сервер жёстко задан в AppConfig (продакшн), экрана настроек нет —
  // отдельная проверка адреса не нужна, AppConfig.apiBaseUrl всегда задан.

  // На устройстве уже есть питомец — спрашиваем ДО attach, чтобы не
  // менять привязку и прогресс без согласия.
  final local = await ref.read(gameStateRepositoryProvider).loadLocal();
  if ((local?.hasPet() ?? false) && context.mounted) {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заменить прогресс?'),
        content: const Text(
          'На этом устройстве уже есть питомец. Заменить прогресс данными '
          'с другого устройства?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Заменить', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (agreed != true) return AttachOutcome.cancelled();
  }

  try {
    final result = await ref.read(profileRepositoryProvider).attachProfile(code);
    var restored = false;
    if (result.hasState) {
      final server = await ref.read(backendApiProvider).getMyState();
      if (server.state.isNotEmpty) {
        // Полная замена локального состояния серверным: dirty = false,
        // версия — серверная, дальше обычный sync продолжит с неё.
        await ref.read(gameStateRepositoryProvider).savePulled(
              GameState.fromJson(server.state),
              server.stateVersion,
            );
        restored = true;
      }
    }
    // Перезапуск загрузки профиля/состояния — тот же паттерн, что после
    // синка в ProfileController (_postBootstrap): invalidate провайдеров.
    ref.invalidate(gameStateControllerProvider);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(contentBundleProvider);
    return AttachOutcome.ok(restored: restored);
  } on ApiException catch (e) {
    if (e.code == ApiErrorCode.notFound) {
      return AttachOutcome.error('Код не найден. Проверь и введи ещё раз');
    }
    // 404 без JSON-тела («404 page not found») — на сервере старая
    // версия бэкенда, где эндпоинта /v1/profiles/attach ещё нет.
    if (e.statusCode == 404) {
      return AttachOutcome.error('На сервере старая версия бэкенда — '
          'обнови его (docker compose up --build) и попробуй снова');
    }
    if (e.isNetworkError) {
      return AttachOutcome.error(
          'Нет связи с сервером. Проверь интернет и попробуй ещё раз');
    }
    return AttachOutcome.error('Не получилось привязать: ${e.message}');
  } catch (_) {
    return AttachOutcome.error('Не получилось привязать. Попробуй ещё раз');
  }
}

/// Общий bottom sheet ввода кода привязки (6 символов, uppercase).
/// Используется на экране первого запуска и в разделе «Для взрослых».
class AttachCodeSheet extends ConsumerStatefulWidget {
  const AttachCodeSheet({super.key});

  /// Показать sheet. Вернёт [AttachOutcome] или null, если его просто
  /// закрыли (свайп/тап мимо).
  static Future<AttachOutcome?> show(BuildContext context) {
    return showModalBottomSheet<AttachOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.dark.card,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      ),
      builder: (_) => const AttachCodeSheet(),
    );
  }

  @override
  ConsumerState<AttachCodeSheet> createState() => _AttachCodeSheetState();
}

class _AttachCodeSheetState extends ConsumerState<AttachCodeSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await attachByCode(ref, context, _controller.text);
    if (!mounted) return;
    // Успех или отмена замены — закрываем sheet, исход разбирает вызывающий.
    if (outcome.ok || outcome.error == null) {
      Navigator.of(context).pop(outcome);
      return;
    }
    setState(() {
      _busy = false;
      _error = outcome.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      // Клавиатура поднимает sheet над собой.
      padding: EdgeInsets.fromLTRB(
          20, 24, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Восстановить прогресс',
            textAlign: TextAlign.center,
            style: AppTextStyles.header(color: c.text, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Введите код из 6 символов — он показан на первом устройстве '
            'в разделе «Для взрослых».',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: c.textDim, size: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_busy,
            maxLength: 6,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            style: AppTextStyles.number(color: c.gold, size: 36)
                .copyWith(letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC123',
              hintStyle: AppTextStyles.number(color: c.textDim, size: 36)
                  .copyWith(letterSpacing: 8),
              filled: true,
              fillColor: c.cardDeep,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: c.red, size: 16),
            ),
          ],
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            AppButton(text: 'Привязать', onPressed: _submit),
        ],
      ),
    );
  }
}

/// Код на сервере хранится в верхнем регистре — ввод сразу uppercase.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
