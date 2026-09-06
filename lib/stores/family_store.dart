import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/family/family_member.dart';
import '../models/family/family_space.dart';

class FamilyStore extends ChangeNotifier {
  FamilyStore({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  final List<FamilyMember> _members = [];

  bool _isLoading = true;

  bool get isLoading => _isLoading;

  List<FamilyMember> get members => List.unmodifiable(_members);

  FamilySpace get family {
    return FamilySpace(
      id: 'family_vidal',
      name: 'Familie Vidal',
      description: 'Unser gemeinsamer Familienraum',
      members: members,
    );
  }

  int get memberCount => _members.length;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final storedMembers = await _database.getFamilyMembers();

    if (storedMembers.isEmpty) {
      final initialMembers = _createInitialMembers();

      await _database.insertInitialFamilyMembers(initialMembers);

      _members
        ..clear()
        ..addAll(initialMembers);
    } else {
      _members
        ..clear()
        ..addAll(storedMembers);
    }

    _isLoading = false;
    notifyListeners();
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

  List<FamilyMember> _createInitialMembers() {
    return const [
      FamilyMember(
        id: 'ramon',
        firstName: 'Ramon',
        lastName: 'Vidal',
        role: FamilyMemberRole.owner,
        isCurrentUser: true,
      ),
      FamilyMember(
        id: 'lara',
        firstName: 'Lara',
        lastName: 'Vidal',
        role: FamilyMemberRole.admin,
      ),
      FamilyMember(
        id: 'alex',
        firstName: 'Alex',
        lastName: 'Vidal',
        role: FamilyMemberRole.child,
      ),
      FamilyMember(
        id: 'oma',
        firstName: 'Oma',
        lastName: '',
        role: FamilyMemberRole.senior,
      ),
    ];
  }
}
