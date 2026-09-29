import 'package:dio/dio.dart';

enum ApiErrorCode {
  invalidRequest,
  unauthorized,
  notFound,
  versionConflict,
  internal,
  network,
  unknown,
}

/// Типизированная ошибка бэкенда.
///
/// Сервер всегда отвечает в формате `{"error":{"code","message"}}`;
/// при 409 дополнительно приходят `current_version` и `current_state`.
/// Для сетевых сбоев [detail] содержит точную причину от Dio
/// (тип ошибки + нижележащее исключение) — важно для диагностики на устройстве.
class ApiException implements Exception {
  final ApiErrorCode code;
  final String message;
  final String? detail;
  final int? statusCode;
  final int? currentVersion;
  final Map<String, dynamic>? currentState;

  const ApiException(
    this.code,
    this.message, {
    this.detail,
    this.statusCode,
    this.currentVersion,
    this.currentState,
  });

  bool get isNetworkError => code == ApiErrorCode.network;

  /// Полное описание ошибки для раздела взрослых.
  String get fullText => detail == null ? message : '$message ($detail)';

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      // Нет ответа: таймаут, нет сети, хост недоступен — считаем «офлайн».
      final rawDetail = (e.error ?? e.message)?.toString() ?? '';
      final detail = rawDetail.isEmpty ? e.type.name : '${e.type.name}: $rawDetail';
      return ApiException(ApiErrorCode.network, 'Нет соединения с сервером', detail: detail);
    }
    final data = response.data;
    Map<String, dynamic>? errorBody;
    if (data is Map) {
      final raw = data['error'];
      if (raw is Map) errorBody = raw.cast<String, dynamic>();
    }
    final codeString = errorBody?['code'] as String? ?? 'internal';
    final message = errorBody?['message'] as String? ?? 'Ошибка сервера';
    final code = switch (codeString) {
      'invalid_request' => ApiErrorCode.invalidRequest,
      'unauthorized' => ApiErrorCode.unauthorized,
      'not_found' => ApiErrorCode.notFound,
      'version_conflict' => ApiErrorCode.versionConflict,
      'internal' => ApiErrorCode.internal,
      _ => ApiErrorCode.unknown,
    };
    int? currentVersion;
    Map<String, dynamic>? currentState;
    if (data is Map) {
      final rawVersion = data['current_version'];
      if (rawVersion is int) currentVersion = rawVersion;
      final rawState = data['current_state'];
      if (rawState is Map) currentState = rawState.cast<String, dynamic>();
    }
    return ApiException(
      code,
      message,
      statusCode: response.statusCode,
      currentVersion: currentVersion,
      currentState: currentState,
    );
  }

  @override
  String toString() => 'ApiException($code, $message)';
}
