class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
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

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
