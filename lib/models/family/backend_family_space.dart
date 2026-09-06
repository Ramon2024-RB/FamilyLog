class BackendFamilySpace {
  const BackendFamilySpace({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BackendFamilySpace.fromMap(Map<String, dynamic> map) {
    return BackendFamilySpace(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  BackendFamilySpace copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BackendFamilySpace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
