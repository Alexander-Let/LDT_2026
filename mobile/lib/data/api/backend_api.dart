import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/content_bundle.dart';
import '../models/parent_session.dart';
import '../models/pending_bonus.dart';
import '../models/profile.dart';

class ProfileStateResponse {
  final Map<String, dynamic> state;
  final int stateVersion;
  final String? updatedAt;

  const ProfileStateResponse({
    required this.state,
    required this.stateVersion,
    this.updatedAt,
  });

  factory ProfileStateResponse.fromJson(Map<String, dynamic> json) =>
      ProfileStateResponse(
        state: json['state'] is Map
            ? (json['state'] as Map).cast<String, dynamic>()
            : const {},
        stateVersion: (json['state_version'] as num?)?.toInt() ?? 0,
        updatedAt: json['updated_at'] as String?,
      );
}

/// Ответ `POST /v1/profiles/attach` — привязка устройства к существующему
/// профилю по коду (восстановление прогресса на новом устройстве).
class AttachResult {
  final String profileId;
  final String displayName;
  final String linkCode;

  /// На сервере есть сохранённое состояние — можно забирать
  /// `GET /v1/profiles/me/state` и заменять локальное.
  final bool hasState;

  const AttachResult({
    required this.profileId,
    required this.displayName,
    required this.linkCode,
    required this.hasState,
  });

  factory AttachResult.fromJson(Map<String, dynamic> json) => AttachResult(
        profileId: json['profile_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        linkCode: json['link_code'] as String? ?? '',
        hasState: json['has_state'] as bool? ?? false,
      );
}

/// Типизированные обёртки над всеми эндпоинтами бэкенда.
///
/// Детские вызовы авторизуются автоматически (device_token из [ApiClient]).
/// Родительские принимают parent_token явным параметром.
class BackendApi {
  final ApiClient _client;

  BackendApi(this._client);

  Dio get _dio => _client.dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // ---------- health ----------

  Future<bool> healthz() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/healthz');
        return response.data?['status'] == 'ok';
      });

  // ---------- profiles (ребёнок) ----------

  Future<ProfileIdentity> createProfile({
    required String deviceToken,
    required String displayName,
  }) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/profiles',
          data: {'device_token': deviceToken, 'display_name': displayName},
        );
        return ProfileIdentity.fromJson(response.data ?? const {});
      });

  /// Привязка этого устройства к чужому профилю по link_code
  /// (второе устройство / переустановка). Эндпоинт публичный: токен
  /// передаётся в теле, после успеха работает как Bearer на /v1/profiles/me.
  Future<AttachResult> attachProfile({
    required String deviceToken,
    required String linkCode,
  }) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/profiles/attach',
          data: {'device_token': deviceToken, 'link_code': linkCode},
        );
        return AttachResult.fromJson(response.data ?? const {});
      });

  Future<ProfileHeader> getMyProfile() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/v1/profiles/me');
        return ProfileHeader.fromJson(response.data ?? const {});
      });

  Future<ProfileStateResponse> getMyState() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/v1/profiles/me/state');
        return ProfileStateResponse.fromJson(response.data ?? const {});
      });

  Future<ProfileStateResponse> putMyState({
    required Map<String, dynamic> state,
    required int baseVersion,
  }) =>
      _guard(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '/v1/profiles/me/state',
          data: {'state': state, 'base_version': baseVersion},
        );
        return ProfileStateResponse.fromJson(response.data ?? const {});
      });

  Future<List<PendingBonus>> listMyBonuses() => _guard(() async {
        final response = await _dio.get<List<dynamic>>('/v1/profiles/me/bonuses');
        final data = response.data ?? const [];
        return data
            .whereType<Map>()
            .map((e) => PendingBonus.fromJson(e.cast<String, dynamic>()))
            .toList();
      });

  Future<Bonus> applyBonus(int id) => _guard(() async {
        final response = await _dio
            .post<Map<String, dynamic>>('/v1/profiles/me/bonuses/$id/applied');
        return Bonus.fromJson(response.data ?? const {});
      });

  // ---------- content ----------

  Future<ContentBundle> getContentBundle() => _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>('/v1/content/bundle');
        return ContentBundle.fromJson(response.data ?? const {});
      });

  // ---------- parents ----------

  Future<ParentOtpResult> requestParentOtp({required String email}) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/parents/otp',
          data: {'email': email, 'consent': true},
        );
        return ParentOtpResult.fromJson(response.data ?? const {});
      });

  Future<ParentSession> createParentSession({
    required String email,
    required String code,
  }) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/parents/session',
          data: {'email': email, 'code': code},
        );
        return ParentSession.fromJson(response.data ?? const {});
      });

  Future<LinkedChild> linkChild({
    required String parentToken,
    required String linkCode,
  }) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/parents/links',
          data: {'link_code': linkCode},
          options: Options(extra: {'auth_token': parentToken}),
        );
        return LinkedChild.fromJson(response.data ?? const {});
      });

  Future<List<LinkedChild>> listChildren({required String parentToken}) =>
      _guard(() async {
        final response = await _dio.get<List<dynamic>>(
          '/v1/parents/children',
          options: Options(extra: {'auth_token': parentToken}),
        );
        final data = response.data ?? const [];
        return data
            .whereType<Map>()
            .map((e) => LinkedChild.fromJson(e.cast<String, dynamic>()))
            .toList();
      });

  Future<ChildSummary> childSummary({
    required String parentToken,
    required String profileId,
  }) =>
      _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/v1/parents/children/$profileId/summary',
          options: Options(extra: {'auth_token': parentToken}),
        );
        return ChildSummary.fromJson(response.data ?? const {});
      });

  Future<Bonus> createChildBonus({
    required String parentToken,
    required String profileId,
    required int amount,
    required String reason,
  }) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/parents/children/$profileId/bonuses',
          data: {'amount': amount, 'reason': reason},
          options: Options(extra: {'auth_token': parentToken}),
        );
        return Bonus.fromJson(response.data ?? const {});
      });
}
