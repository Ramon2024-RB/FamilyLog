enum BackendFamilyMemberRole { owner, admin, adult, child, senior }

class BackendFamilyMember {
  const BackendFamilyMember({
    required this.id,
    required this.familyId,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.avatarUrl,
  });

  final String id;
  final String familyId;
  final String? userId;
  final String firstName;
  final String lastName;
  final BackendFamilyMemberRole role;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName {
    final parts = [
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty);

    return parts.join(' ');
  }

  String get initials {
    final firstInitial = firstName.trim().isNotEmpty
        ? firstName.trim()[0].toUpperCase()
        : '';

    final lastInitial = lastName.trim().isNotEmpty
        ? lastName.trim()[0].toUpperCase()
        : '';

    return '$firstInitial$lastInitial';
  }

  bool get hasAccount => userId != null;

  String get roleLabel {
    switch (role) {
      case BackendFamilyMemberRole.owner:
        return 'Familieninhaber';
      case BackendFamilyMemberRole.admin:
        return 'Administrator';
      case BackendFamilyMemberRole.adult:
        return 'Erwachsener';
      case BackendFamilyMemberRole.child:
        return 'Kind';
      case BackendFamilyMemberRole.senior:
        return 'Senior';
    }
  }

  factory BackendFamilyMember.fromMap(Map<String, dynamic> map) {
    return BackendFamilyMember(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      userId: map['user_id'] as String?,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      role: _roleFromString(map['role'] as String),
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static BackendFamilyMemberRole _roleFromString(String role) {
    switch (role) {
      case 'owner':
        return BackendFamilyMemberRole.owner;
      case 'admin':
        return BackendFamilyMemberRole.admin;
      case 'adult':
        return BackendFamilyMemberRole.adult;
      case 'child':
        return BackendFamilyMemberRole.child;
      case 'senior':
        return BackendFamilyMemberRole.senior;
      default:
        throw StateError('Unbekannte Familienrolle: $role');
    }
  }
}
