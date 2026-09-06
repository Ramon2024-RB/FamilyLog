enum FamilyMemberRole { owner, admin, adult, child, senior }

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.profileImagePath,
    this.isCurrentUser = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final FamilyMemberRole role;
  final String? profileImagePath;
  final bool isCurrentUser;

  String get fullName {
    final trimmedLastName = lastName.trim();

    if (trimmedLastName.isEmpty) {
      return firstName;
    }

    return '$firstName $trimmedLastName';
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

  String get roleLabel {
    switch (role) {
      case FamilyMemberRole.owner:
        return 'Familieninhaber';
      case FamilyMemberRole.admin:
        return 'Administrator';
      case FamilyMemberRole.adult:
        return 'Erwachsener';
      case FamilyMemberRole.child:
        return 'Kind';
      case FamilyMemberRole.senior:
        return 'Senior';
    }
  }

  FamilyMember copyWith({
    String? id,
    String? firstName,
    String? lastName,
    FamilyMemberRole? role,
    String? profileImagePath,
    bool? isCurrentUser,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
