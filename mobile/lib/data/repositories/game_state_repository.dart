import 'dart:convert';

import '../../core/network/api_exception.dart';
import '../../core/sync_status.dart';
import '../../core/storage/local_db.dart';
import '../api/backend_api.dart';
import '../models/game_state.dart';
import 'profile_repository.dart';

/// Локальное игровое состояние + синхронизация с бэкендом (optimistic locking).
class GameStateRepository {
  static const int _maxMergeAttempts = 3;

  final LocalDb db;
  final BackendApi api;
  final ProfileRepository profiles;

  GameStateRepository({
    required this.db,
    required this.api,
    required this.profiles,
  });

  Future<GameState?> loadLocal() async {
    final row = await db.getGameStateRow();
    if (row == null) return null;
    try {
      return GameState.fromJson(jsonDecode(row['json'] as String) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// Локальная версия серверной state_version (для base_version в PUT).
  Future<int> localVersion() async =>
      (await db.getGameStateRow())?['state_version'] as int? ?? 0;

  Future<void> saveLocal(GameState state, {bool dirty = true}) async {
    final version = await localVersion();
    await db.upsertGameState(
      json: jsonEncode(state.toJson()),
      stateVersion: version,
      dirty: dirty,
    );
  }

  Future<void> savePulled(GameState state, int serverVersion) async {
    await db.upsertGameState(
      json: jsonEncode(state.toJson()),
      stateVersion: serverVersion,
      dirty: false,
    );
  }

  Future<void> clearLocal() => db.deleteGameState();

  /// Синхронизация: dirty-локальные изменения отправляются через PUT,
  /// при 409 состояние сливается с серверным и запрос повторяется.
  /// Возвращает итог с текстом ошибки для диагностики.
  Future<SyncState> sync() async {
    final profile = await profiles.loadLocal();
    if (profile == null) {
      return const SyncState(SyncStatus.offline, 'Локальный профиль ещё не создан');
    }
    if (profile.pendingRemote) {
      // Профиль создан без сети: сначала регистрируем его на сервере
      // (POST /v1/profiles идемпотентен по device_token, повтор безопасен).
      // Иначе sync не делал ничего до перезапуска приложения — профиль
      // так и оставался локальным («не подключается автоматически»).
      final registered = await profiles.retryRemoteCreate(profile);
      if (registered == null) {
        return const SyncState(
          SyncStatus.offline,
          'Нет связи с сервером: профиль ещё не зарегистрирован',
        );
      }
      // Регистрация прошла — продолжаем sync обычным путём.
    }

    final row = await db.getGameStateRow();
    final localJson = row?['json'] as String?;
    final isDirty = (row?['dirty'] as int? ?? 0) == 1;

    try {
      final server = await api.getMyState();

      if (localJson != null && isDirty) {
        var merged = _merge(jsonDecode(localJson) as Map<String, dynamic>, server.state);
        var baseVersion = server.stateVersion;
        for (var attempt = 0; attempt < _maxMergeAttempts; attempt++) {
          try {
            final saved = await api.putMyState(state: merged, baseVersion: baseVersion);
            await savePulled(GameState.fromJson(merged), saved.stateVersion);
            return SyncState.online;
          } on ApiException catch (e) {
            if (e.code != ApiErrorCode.versionConflict || e.currentState == null) rethrow;
            // 409: аккуратно сливаем чужие изменения и повторяем PUT.
            merged = _merge(merged, e.currentState!);
            baseVersion = e.currentVersion ?? baseVersion;
          }
        }
        return const SyncState(SyncStatus.offline, 'Не удалось разрешить конфликт версий');
      }

      // Локальных изменений нет — забираем серверное состояние (мульти-девайс).
      if (localJson == null && server.state.isNotEmpty) {
        await savePulled(GameState.fromJson(server.state), server.stateVersion);
      }
      return SyncState.online;
    } on ApiException catch (e) {
      return SyncState(SyncStatus.offline, e.fullText);
    }
  }

  /// Мерж при конфликте версий: берём серверное состояние как основу
  /// (чтобы не потерять поля, которых нет локально — например, баланс,
  /// изменённый с другого устройства), и накладываем поверх локальные поля
  /// (у локальных изменений приоритет).
  Map<String, dynamic> _merge(Map<String, dynamic> local, Map<String, dynamic> server) {
    final merged = Map<String, dynamic>.from(server);
    local.forEach((key, value) {
      if (value != null) merged[key] = value;
    });
    return merged;
  }
}
