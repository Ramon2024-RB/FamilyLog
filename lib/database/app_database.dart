import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/family/family_member.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'familylog.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE family_members (
            id TEXT PRIMARY KEY,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            role TEXT NOT NULL,
            profile_image_path TEXT,
            is_current_user INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<List<FamilyMember>> getFamilyMembers() async {
    final db = await database;

    final rows = await db.query('family_members', orderBy: 'rowid ASC');

    return rows.map(_familyMemberFromMap).toList();
  }

  Future<void> insertFamilyMember(FamilyMember member) async {
    final db = await database;

    await db.insert(
      'family_members',
      _familyMemberToMap(member),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFamilyMember(FamilyMember member) async {
    final db = await database;

    await db.update(
      'family_members',
      _familyMemberToMap(member),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<void> deleteFamilyMember(String memberId) async {
    final db = await database;

    await db.delete('family_members', where: 'id = ?', whereArgs: [memberId]);
  }

  Future<void> insertInitialFamilyMembers(List<FamilyMember> members) async {
    final db = await database;

    final batch = db.batch();

    for (final member in members) {
      batch.insert(
        'family_members',
        _familyMemberToMap(member),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }

  Map<String, Object?> _familyMemberToMap(FamilyMember member) {
    return {
      'id': member.id,
      'first_name': member.firstName,
      'last_name': member.lastName,
      'role': member.role.name,
      'profile_image_path': member.profileImagePath,
      'is_current_user': member.isCurrentUser ? 1 : 0,
    };
  }

  FamilyMember _familyMemberFromMap(Map<String, Object?> map) {
    return FamilyMember(
      id: map['id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      role: _roleFromString(map['role'] as String),
      profileImagePath: map['profile_image_path'] as String?,
      isCurrentUser: (map['is_current_user'] as int) == 1,
    );
  }

  FamilyMemberRole _roleFromString(String value) {
    return FamilyMemberRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => FamilyMemberRole.adult,
    );
  }
}
