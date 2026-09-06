class FamilyProfile {
  const FamilyProfile({
    required this.id,
    required this.name,
    required this.description,
    this.imagePath,
  });

  final String id;
  final String name;
  final String description;
  final String? imagePath;

  FamilyProfile copyWith({
    String? id,
    String? name,
    String? description,
    String? imagePath,
  }) {
    return FamilyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
