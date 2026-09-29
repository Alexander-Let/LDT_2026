/// Ответ `GET /v1/profiles/me/bonuses`.
class PendingBonus {
  final int id;
  final int amount;
  final String reason;
  final String? createdAt;

  const PendingBonus({
    required this.id,
    required this.amount,
    required this.reason,
    this.createdAt,
  });

  factory PendingBonus.fromJson(Map<String, dynamic> json) => PendingBonus(
        id: (json['id'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
        createdAt: json['created_at'] as String?,
      );
}

/// Ответ `POST .../bonuses/{id}/applied` и `POST .../children/{id}/bonuses`.
class Bonus {
  final int bonusId;
  final String profileId;
  final int amount;
  final String reason;
  final String? createdAt;
  final String? appliedAt;

  const Bonus({
    required this.bonusId,
    required this.profileId,
    required this.amount,
    required this.reason,
    this.createdAt,
    this.appliedAt,
  });

  factory Bonus.fromJson(Map<String, dynamic> json) => Bonus(
        bonusId: (json['bonus_id'] as num?)?.toInt() ?? 0,
        profileId: json['profile_id'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
        createdAt: json['created_at'] as String?,
        appliedAt: json['applied_at'] as String?,
      );
}
