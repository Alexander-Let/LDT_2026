import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_db.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await LocalDb.open();
  // Адрес сервера жёстко задан в AppConfig (продакшн), настройки нет.
  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  runApp(
    ProviderScope(
      overrides: [
        localDbProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
      ],
      child: const FinniApp(),
    ),
  );
}
