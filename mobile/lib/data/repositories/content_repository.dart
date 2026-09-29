import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/network/api_exception.dart';
import '../../core/storage/local_db.dart';
import '../api/backend_api.dart';
import '../models/content_bundle.dart';

/// Контент-бандл: стартуем на встроенном asset (schema v2), кэшируем raw JSON
/// в SQLite, при наличии сети обновляем с сервера, если версия новее локальной.
class ContentRepository {
  static const String _assetPath = 'assets/content/bundle.json';

  final LocalDb db;
  final BackendApi api;

  ContentRepository({required this.db, required this.api});

  Future<ContentBundle> load() async {
    var local = await _loadCached();
    final asset = await _loadFromAssets();
    // Встроенный бандл новее закэшированного (или кэш битый/пустой,
    // или в нём пропали товары) — берём ассет, иначе на телефоне вечно
    // живёт старая схема и магазин/цели приходят пустыми.
    final localBroken =
        local != null && local.payload.shopItems.isEmpty && asset.payload.shopItems.isNotEmpty;
    if (local == null || asset.version > local.version || localBroken) {
      local = asset;
      await _cache(local.version, jsonEncode(local.payload.raw));
    }

    try {
      final remote = await api.getContentBundle();
      if (remote.version > local.version) {
        await _cache(remote.version, jsonEncode(remote.payload.raw));
        return remote;
      }
      return local;
    } on ApiException {
      // Офлайн — работаем на локальной копии.
      return local;
    }
  }

  Future<ContentBundle?> _loadCached() async {
    final row = await db.getContentRow();
    if (row == null) return null;
    try {
      return ContentBundle(
        version: row['version'] as int? ?? 0,
        payload: GameContent.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      // Кэш не читается (битый JSON, старая схема и т.п.) — стартуем
      // на встроенном ассете.
      return null;
    }
  }

  Future<ContentBundle> _loadFromAssets() async {
    final raw = await rootBundle.loadString(_assetPath);
    final payload = GameContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    // Версия встроенного бандла v2 (см. backend/migrations/00004_content_v2.sql).
    return ContentBundle(version: 2, payload: payload);
  }

  Future<void> _cache(int version, String rawPayload) => db.upsertContent(
        version: version,
        payload: rawPayload,
      );
}
