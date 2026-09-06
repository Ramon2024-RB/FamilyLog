enum FamilyInvitationStatus { active, used, expired, revoked }

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.familyId,
    required this.code,
    required this.createdAt,
    required this.status,
    this.expiresAt,
  });

  final String id;
  final String familyId;
  final String code;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final FamilyInvitationStatus status;

  bool get isExpired {
    final expiration = expiresAt;

    if (expiration == null) {
      return false;
    }

    return DateTime.now().isAfter(expiration);
  }

  bool get isUsable {
    return status == FamilyInvitationStatus.active && !isExpired;
  }

  FamilyInvitation copyWith({
    String? id,
    String? familyId,
    String? code,
    DateTime? createdAt,
    DateTime? expiresAt,
    FamilyInvitationStatus? status,
  }) {
    return FamilyInvitation(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }
}
