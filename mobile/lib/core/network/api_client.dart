import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';

/// Тонкая обёртка над Dio: baseUrl, подстановка Bearer device_token
/// и логирование запросов в debug-режиме.
class ApiClient {
  final Dio dio;

  /// Токен устройства ребёнка. Подставляется в Authorization для всех
  /// детских эндпоинтов; родительские вызовы передают токен явно
  /// через [RequestOptions.extra] (`auth_token`).
  String? deviceToken;

  ApiClient({String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            sendTimeout: AppConfig.sendTimeout,
            contentType: 'application/json',
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = options.extra['auth_token'] as String? ?? deviceToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: false,
          logPrint: (obj) => debugPrint('[api] $obj'),
        ),
      );
    }
  }

  /// Смена адреса сервера на лету (без пересоздания клиента):
  /// действует на все последующие запросы.
  void updateBaseUrl(String baseUrl) {
    dio.options.baseUrl = baseUrl;
  }
}
