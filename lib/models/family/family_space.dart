import 'family_member.dart';

class FamilySpace {
  const FamilySpace({
    required this.id,
    required this.name,
    required this.members,
    this.description,
    this.imagePath,
  });

  final String id;
  final String name;
  final List<FamilyMember> members;
  final String? description;
  final String? imagePath;

  int get memberCount => members.length;

  FamilySpace copyWith({
    String? id,
    String? name,
    List<FamilyMember>? members,
    String? description,
    String? imagePath,
  }) {
    return FamilySpace(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
