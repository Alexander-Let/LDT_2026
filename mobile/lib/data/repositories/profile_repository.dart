import 'dart:math';

import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/local_db.dart';
import '../api/backend_api.dart';
import '../models/parent_session.dart';
import '../models/profile.dart';

/// Загрузка/создание профиля: device_token живёт в secure storage,
/// остальное — в таблице `profile` (одна строка).
class ProfileRepository {
  static const String _tokenKey = 'device_token';
  static const String _parentTokenKey = 'parent_token';
  static const String _parentEmailKey = 'parent_email';

  final LocalDb db;
  final ApiClient apiClient;
  final BackendApi api;
  final FlutterSecureStorage secure;

  ProfileRepository({
    required this.db,
    required this.apiClient,
    required this.api,
    this.secure = const FlutterSecureStorage(),
  });

  Future<Profile?> loadLocal() async {
    final row = await db.getProfileRow();
    if (row == null) return null;
    final token = row['device_token'] as String;
    // Токен должен быть в secure storage; если там пусто (редкий случай
    // рассинхрона) — восстанавливаем из базы.
    if (await secure.read(key: _tokenKey) == null) {
      await secure.write(key: _tokenKey, value: token);
    }
    apiClient.deviceToken = token;
    final profile = Profile(
      deviceToken: token,
      profileId: row['profile_id'] as String,
      displayName: row['display_name'] as String,
      linkCode: row['link_code'] as String? ?? '',
      stateVersion: row['state_version'] as int? ?? 0,
      pendingRemote: (row['pending_remote'] as int? ?? 0) == 1,
    );
    if (profile.pendingRemote) {
      // Сети не было при создании — пробуем зарегистрироваться на сервере.
      unawaited(retryRemoteCreate(profile));
    }
    return profile;
  }

  /// Создание профиля НЕ блокирует UI сетью: локальная запись появляется
  /// сразу (pendingRemote), а регистрация на сервере идёт в фоне
  /// (POST /v1/profiles идемпотентен по device_token, повтор безопасен).
  Future<Profile> createProfile(String displayName) async {
    final existingToken = await secure.read(key: _tokenKey);
    final token = existingToken ?? _generateToken();
    await secure.write(key: _tokenKey, value: token);
    apiClient.deviceToken = token;
    final profile = Profile(
      deviceToken: token,
      profileId: 'local-${_generateToken(length: 16)}',
      displayName: displayName,
      linkCode: '',
      stateVersion: 0,
      pendingRemote: true,
    );
    await _save(profile);
    unawaited(retryRemoteCreate(profile));
    return profile;
  }

  /// device_token из secure storage; если его ещё нет (attach до создания
  /// профиля на свежей установке) — генерируем и сохраняем, как при
  /// обычном создании профиля.
  Future<String> ensureDeviceToken() async {
    final existing = await secure.read(key: _tokenKey);
    if (existing != null && existing.isNotEmpty) {
      apiClient.deviceToken = existing;
      return existing;
    }
    final token = _generateToken();
    await secure.write(key: _tokenKey, value: token);
    apiClient.deviceToken = token;
    return token;
  }

  /// Привязка устройства к существующему профилю по link_code
  /// (восстановление прогресса на втором устройстве). После успеха
  /// локальная запись профиля заменяется привязанной (pendingRemote = false),
  /// а device_token этого устройства становится Bearer для /v1/profiles/me.
  Future<AttachResult> attachProfile(String linkCode) async {
    final token = await ensureDeviceToken();
    final result = await api.attachProfile(deviceToken: token, linkCode: linkCode);
    await _save(Profile(
      deviceToken: token,
      profileId: result.profileId,
      displayName: result.displayName,
      linkCode: result.linkCode,
      stateVersion: 0,
      pendingRemote: false,
    ));
    return result;
  }

  /// После смены адреса сервера: пересоздаём удалённый профиль
  /// (если он ещё локальный) и подтягиваем свежие данные.
  Future<Profile?> onServerChanged() async {
    final local = await loadLocal();
    if (local == null) return null;
    if (local.pendingRemote) {
      return retryRemoteCreate(local);
    }
    return refreshFromServer(local);
  }

  /// Повторная регистрация на сервере для профиля, созданного без сети.
  /// POST /v1/profiles идемпотентен по хэшу device_token — безопасен.
  Future<Profile?> retryRemoteCreate(Profile local) async {
    try {
      final identity = await api.createProfile(
        deviceToken: local.deviceToken,
        displayName: local.displayName,
      );
      final updated = local.copyWith(
        profileId: identity.profileId,
        displayName: identity.displayName,
        linkCode: identity.linkCode,
        pendingRemote: false,
      );
      await _save(updated);
      return updated;
    } catch (_) {
      return null;
    }
  }

  /// Фоновое обновление link_code/state_version с сервера.
  Future<Profile?> refreshFromServer(Profile local) async {
    try {
      final header = await api.getMyProfile();
      final updated = local.copyWith(
        profileId: header.profileId,
        linkCode: header.linkCode,
        stateVersion: header.stateVersion,
        pendingRemote: false,
      );
      await _save(updated);
      return updated;
    } on ApiException catch (e) {
      // 401 при локально «созданном» профиле — сервер его ещё не знает.
      if (e.code == ApiErrorCode.unauthorized && local.pendingRemote) {
        return retryRemoteCreate(local);
      }
      return null;
    }
  }

  Future<void> _save(Profile profile) => db.upsertProfile(
        deviceToken: profile.deviceToken,
        profileId: profile.profileId,
        displayName: profile.displayName,
        linkCode: profile.linkCode,
        stateVersion: profile.stateVersion,
        pendingRemote: profile.pendingRemote,
      );

  /// Деструктивный сброс: локальный профиль, состояние, токены (ТЗ 2.5.12/3.5).
  Future<void> reset() async {
    await secure.delete(key: _tokenKey);
    await db.deleteProfile();
    await db.deleteGameState();
    await db.kvDelete(_parentTokenKey);
    await db.kvDelete(_parentEmailKey);
    apiClient.deviceToken = null;
  }

  // ---------- родительская сессия (kv) ----------

  Future<String?> getParentToken() => db.kvGet(_parentTokenKey);

  Future<String?> getParentEmail() => db.kvGet(_parentEmailKey);

  Future<void> saveParentSession(ParentSession session, String email) async {
    await db.kvSet(_parentTokenKey, session.token);
    await db.kvSet(_parentEmailKey, email);
  }

  Future<void> clearParentSession() async {
    await db.kvDelete(_parentTokenKey);
    await db.kvDelete(_parentEmailKey);
  }

  static String _generateToken({int length = 64}) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}
