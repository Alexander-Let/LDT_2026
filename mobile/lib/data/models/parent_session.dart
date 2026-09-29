// Родительский раздел: OTP-флоу и данные детей.

class ParentOtpResult {
  final String? expiresAt;

  /// Код возвращается только при APP_ENV=dev на сервере (писем в прототипе нет).
  final String? devCode;

  const ParentOtpResult({this.expiresAt, this.devCode});

  factory ParentOtpResult.fromJson(Map<String, dynamic> json) => ParentOtpResult(
        expiresAt: json['expires_at'] as String?,
        devCode: json['dev_code'] as String?,
      );
}

class ParentSession {
  final String token;
  final String? expiresAt;

  const ParentSession({required this.token, this.expiresAt});

  factory ParentSession.fromJson(Map<String, dynamic> json) => ParentSession(
        token: json['parent_token'] as String? ?? '',
        expiresAt: json['expires_at'] as String?,
      );
}

class LinkedChild {
  final String profileId;
  final String displayName;
  final String? linkedAt;
  final int stateVersion;
  final String? updatedAt;

  const LinkedChild({
    required this.profileId,
    required this.displayName,
    this.linkedAt,
    this.stateVersion = 0,
    this.updatedAt,
  });

  factory LinkedChild.fromJson(Map<String, dynamic> json) => LinkedChild(
        profileId: json['profile_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        linkedAt: json['linked_at'] as String?,
        stateVersion: (json['state_version'] as num?)?.toInt() ?? 0,
        updatedAt: json['updated_at'] as String?,
      );
}

/// Ответ `GET /v1/parents/children/{profile_id}/summary`.
class ChildSummary {
  final String profileId;
  final String displayName;
  final Map<String, dynamic> state;
  final int stateVersion;
  final String? updatedAt;

  const ChildSummary({
    required this.profileId,
    required this.displayName,
    required this.state,
    required this.stateVersion,
    this.updatedAt,
  });

  factory ChildSummary.fromJson(Map<String, dynamic> json) => ChildSummary(
        profileId: json['profile_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        state: json['state'] is Map
            ? (json['state'] as Map).cast<String, dynamic>()
            : const {},
        stateVersion: (json['state_version'] as num?)?.toInt() ?? 0,
        updatedAt: json['updated_at'] as String?,
      );
}
