enum FamilyInvitationRole {
  admin,
  adult,
  child,
  senior;

  String get databaseValue => name;

  String get label {
    switch (this) {
      case FamilyInvitationRole.admin:
        return 'Administrator';
      case FamilyInvitationRole.adult:
        return 'Erwachsenes Familienmitglied';
      case FamilyInvitationRole.child:
        return 'Kind';
      case FamilyInvitationRole.senior:
        return 'Senior';
    }
  }

  static FamilyInvitationRole fromDatabaseValue(String value) {
    return FamilyInvitationRole.values.firstWhere(
      (role) => role.databaseValue == value,
      orElse: () => FamilyInvitationRole.adult,
    );
  }
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.code,
    required this.manualCode,
    required this.expiresAt,
  });

  final String id;

  /// Sicherer Token für QR-Code und später Einladungslinks.
  final String code;

  /// Kurzer Code für die manuelle Eingabe.
  final String manualCode;

  final DateTime expiresAt;

  factory FamilyInvitation.fromMap(Map<String, dynamic> map) {
    return FamilyInvitation(
      id: map['invitation_id'] as String,
      code: map['invitation_code'] as String,
      manualCode: map['manual_code'] as String,
      expiresAt: DateTime.parse(map['expires_at'] as String),
    );
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  bool get isUsable => !isExpired;
}

class FamilyInvitationPreview {
  const FamilyInvitationPreview({
    required this.familyName,
    required this.familyDescription,
    required this.role,
    required this.expiresAt,
  });

  final String familyName;
  final String familyDescription;
  final FamilyInvitationRole role;
  final DateTime expiresAt;

  factory FamilyInvitationPreview.fromMap(Map<String, dynamic> map) {
    return FamilyInvitationPreview(
      familyName: map['family_name'] as String,
      familyDescription: (map['family_description'] as String?) ?? '',
      role: FamilyInvitationRole.fromDatabaseValue(
        map['invitation_role'] as String,
      ),
      expiresAt: DateTime.parse(map['expires_at'] as String),
    );
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }
}
