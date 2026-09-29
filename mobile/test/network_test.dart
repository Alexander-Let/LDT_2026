import 'package:dio/dio.dart';
import 'package:finni_app/core/config.dart';
import 'package:finni_app/core/network/api_client.dart';
import 'package:finni_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiClient: дефолтный base URL и смена адреса на лету', () {
    final client = ApiClient();
    expect(client.dio.options.baseUrl, AppConfig.apiBaseUrl);
    client.updateBaseUrl('http://192.168.3.4:8080');
    expect(client.dio.options.baseUrl, 'http://192.168.3.4:8080');
    client.updateBaseUrl('http://10.0.2.2:8080');
    expect(client.dio.options.baseUrl, 'http://10.0.2.2:8080');
  });

  test('ApiClient: короткие таймауты (недоступный сервер → быстрый офлайн)', () {
    final client = ApiClient();
    expect(client.dio.options.connectTimeout, const Duration(seconds: 4));
    expect(client.dio.options.receiveTimeout, const Duration(seconds: 8));
    expect(client.dio.options.sendTimeout, const Duration(seconds: 8));
  });

  test('ApiException: сетевая ошибка содержит точный detail', () {
    final exception = ApiException.fromDio(
      DioException(
        type: DioExceptionType.connectionError,
        error: 'Connection refused (192.168.3.4:8080)',
        requestOptions: RequestOptions(path: '/healthz'),
      ),
    );
    expect(exception.code, ApiErrorCode.network);
    expect(exception.isNetworkError, isTrue);
    expect(exception.fullText, contains('Connection refused (192.168.3.4:8080)'));
    expect(exception.fullText, contains('connectionError'));
  });

  test('ApiException: таймаут соединения — сетевая ошибка с detail', () {
    final exception = ApiException.fromDio(
      DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/v1/profiles'),
      ),
    );
    expect(exception.code, ApiErrorCode.network);
    expect(exception.detail, isNotNull);
  });

  test('ApiException: 409 version_conflict парсит current_version/current_state', () {
    final exception = ApiException.fromDio(
      DioException(
        type: DioExceptionType.badResponse,
        response: Response<Map<String, dynamic>>(
          statusCode: 409,
          data: const {
            'error': {'code': 'version_conflict', 'message': 'версия устарела'},
            'current_version': 4,
            'current_state': {'balance': 100},
          },
          requestOptions: RequestOptions(path: '/v1/profiles/me/state'),
        ),
        requestOptions: RequestOptions(path: '/v1/profiles/me/state'),
      ),
    );
    expect(exception.code, ApiErrorCode.versionConflict);
    expect(exception.currentVersion, 4);
    expect(exception.currentState?['balance'], 100);
  });
}
