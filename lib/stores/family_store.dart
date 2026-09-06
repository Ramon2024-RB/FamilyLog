import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/family/family_member.dart';
import '../models/family/family_profile.dart';
import '../models/family/family_space.dart';

class FamilyStore extends ChangeNotifier {
  FamilyStore({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  final List<FamilyMember> _members = [];

  FamilyProfile? _profile;
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  List<FamilyMember> get members => List.unmodifiable(_members);

  FamilyProfile? get profileOrNull => _profile;

  bool get hasLocalFamily => _profile != null;

  FamilyProfile get profile {
    final currentProfile = _profile;

    if (currentProfile == null) {
      throw StateError('Es ist keine lokale Familie geladen.');
    }

    return currentProfile;
  }

  FamilySpace? get familyOrNull {
    final currentProfile = _profile;

    if (currentProfile == null) {
      return null;
    }

    return FamilySpace(
      id: currentProfile.id,
      name: currentProfile.name,
      description: currentProfile.description,
      imagePath: currentProfile.imagePath,
      members: members,
    );
  }

  FamilySpace get family {
    final currentFamily = familyOrNull;

    if (currentFamily == null) {
      throw StateError('Es ist keine lokale Familie geladen.');
    }

    return currentFamily;
  }

  int get memberCount => _members.length;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final storedMembers = await _database.getFamilyMembers();
      final storedProfile = await _database.getFamilyProfile();

      _members
        ..clear()
        ..addAll(storedMembers);

      _profile = storedProfile;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMember(FamilyMember member) async {
    await _database.insertFamilyMember(member);

    _members.add(member);
    notifyListeners();
  }

  Future<void> updateMember(FamilyMember updatedMember) async {
    final index = _members.indexWhere(
      (member) => member.id == updatedMember.id,
    );

    if (index == -1) {
      return;
    }

    await _database.updateFamilyMember(updatedMember);

    _members[index] = updatedMember;
    notifyListeners();
  }

  Future<void> removeMember(String memberId) async {
    final memberIndex = _members.indexWhere((member) => member.id == memberId);

    if (memberIndex == -1) {
      return;
    }

    final member = _members[memberIndex];

    if (member.isCurrentUser) {
      return;
    }

    await _database.deleteFamilyMember(memberId);

    _members.removeAt(memberIndex);
    notifyListeners();
  }

  Future<void> updateFamilyProfile(FamilyProfile updatedProfile) async {
    await _database.saveFamilyProfile(updatedProfile);

    _profile = updatedProfile;
    notifyListeners();
  }
}
