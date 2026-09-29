/// Ответ `POST /v1/profiles`.
class ProfileIdentity {
  final String profileId;
  final String displayName;
  final String linkCode;
  final String? createdAt;

  const ProfileIdentity({
    required this.profileId,
    required this.displayName,
    required this.linkCode,
    this.createdAt,
  });

  factory ProfileIdentity.fromJson(Map<String, dynamic> json) => ProfileIdentity(
        profileId: json['profile_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        linkCode: json['link_code'] as String? ?? '',
        createdAt: json['created_at'] as String?,
      );
}

/// Ответ `GET /v1/profiles/me`.
class ProfileHeader {
  final String profileId;
  final String displayName;
  final String linkCode;
  final int stateVersion;
  final String? updatedAt;

  const ProfileHeader({
    required this.profileId,
    required this.displayName,
    required this.linkCode,
    required this.stateVersion,
    this.updatedAt,
  });

  factory ProfileHeader.fromJson(Map<String, dynamic> json) => ProfileHeader(
        profileId: json['profile_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        linkCode: json['link_code'] as String? ?? '',
        stateVersion: json['state_version'] as int? ?? 0,
        updatedAt: json['updated_at'] as String?,
      );
}

/// Локальная запись профиля (одна строка в таблице `profile`).
class Profile {
  final String deviceToken;
  final String profileId;
  final String displayName;
  final String linkCode;
  final int stateVersion;

  /// Профиль создан только локально (не было сети при первом запуске);
  /// создание на сервере повторяется при появлении сети. POST /v1/profiles
  /// идемпотентен по device_token, повтор безопасен.
  final bool pendingRemote;

  const Profile({
    required this.deviceToken,
    required this.profileId,
    required this.displayName,
    required this.linkCode,
    required this.stateVersion,
    required this.pendingRemote,
  });

  Profile copyWith({
    String? profileId,
    String? displayName,
    String? linkCode,
    int? stateVersion,
    bool? pendingRemote,
  }) =>
      Profile(
        deviceToken: deviceToken,
        profileId: profileId ?? this.profileId,
        displayName: displayName ?? this.displayName,
        linkCode: linkCode ?? this.linkCode,
        stateVersion: stateVersion ?? this.stateVersion,
        pendingRemote: pendingRemote ?? this.pendingRemote,
      );
}
