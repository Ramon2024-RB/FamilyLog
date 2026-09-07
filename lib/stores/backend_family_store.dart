import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/family/backend_family_member.dart';
import '../models/family/backend_family_space.dart';
import '../models/family/family_invitation.dart';
import '../services/family/family_space_service.dart';

class BackendFamilyStore extends ChangeNotifier {
  BackendFamilyStore({FamilySpaceService? familySpaceService})
    : _familySpaceService = familySpaceService ?? FamilySpaceService();

  final FamilySpaceService _familySpaceService;

  final List<BackendFamilySpace> _familySpaces = [];
  final List<BackendFamilyMember> _members = [];

  bool _isLoading = false;
  bool _isLoadingMembers = false;
  bool _isUpdatingFamilyImage = false;
  bool _isCreatingInvitation = false;
  bool _isJoiningFamily = false;
  bool _isUpdatingMember = false;

  String? _error;
  String? _selectedFamilyId;
  String? _selectedFamilyImageUrl;

  List<BackendFamilySpace> get familySpaces => List.unmodifiable(_familySpaces);

  List<BackendFamilyMember> get members => List.unmodifiable(_members);

  bool get isLoading => _isLoading;
  bool get isLoadingMembers => _isLoadingMembers;
  bool get isUpdatingFamilyImage => _isUpdatingFamilyImage;
  bool get isCreatingInvitation => _isCreatingInvitation;
  bool get isJoiningFamily => _isJoiningFamily;
  bool get isUpdatingMember => _isUpdatingMember;

  String? get error => _error;
  String? get selectedFamilyId => _selectedFamilyId;
  String? get selectedFamilyImageUrl => _selectedFamilyImageUrl;

  bool get hasFamilies => _familySpaces.isNotEmpty;

  int get memberCount => _members.length;

  BackendFamilySpace? get selectedFamily {
    final selectedId = _selectedFamilyId;

    if (selectedId == null) {
      return null;
    }

    for (final family in _familySpaces) {
      if (family.id == selectedId) {
        return family;
      }
    }

    return null;
  }

  Future<void> loadFamilySpaces() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final families = await _familySpaceService.getMyFamilySpaces();

      _familySpaces
        ..clear()
        ..addAll(families);

      if (_familySpaces.isEmpty) {
        _selectedFamilyId = null;
        _members.clear();
        _selectedFamilyImageUrl = null;
      } else {
        final selectedStillExists = _familySpaces.any(
          (family) => family.id == _selectedFamilyId,
        );

        if (!selectedStillExists) {
          _selectedFamilyId = _familySpaces.first.id;
        }

        await _loadSelectedFamilyMembers();
        await _loadSelectedFamilyImage();
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSelectedFamilyMembers() async {
    _error = null;
    await _loadSelectedFamilyMembers();
  }

  Future<void> _loadSelectedFamilyMembers() async {
    final familyId = _selectedFamilyId;

    if (familyId == null) {
      _members.clear();
      notifyListeners();
      return;
    }

    _isLoadingMembers = true;
    notifyListeners();

    try {
      final members = await _familySpaceService.getFamilyMembers(familyId);

      _members
        ..clear()
        ..addAll(members);
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoadingMembers = false;
      notifyListeners();
    }
  }

  Future<void> loadSelectedFamilyImage() async {
    _error = null;

    try {
      await _loadSelectedFamilyImage();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> _loadSelectedFamilyImage() async {
    final family = selectedFamily;

    if (family == null || family.imageUrl == null) {
      _selectedFamilyImageUrl = null;
      notifyListeners();
      return;
    }

    _selectedFamilyImageUrl = await _familySpaceService
        .createFamilyImageSignedUrl(family);

    notifyListeners();
  }

  Future<BackendFamilySpace> createFamilySpace({
    required String name,
    String description = '',
  }) async {
    _error = null;

    try {
      final family = await _familySpaceService.createFamilySpace(
        name: name,
        description: description,
      );

      _familySpaces.add(family);
      _selectedFamilyId = family.id;
      _selectedFamilyImageUrl = null;

      await _loadSelectedFamilyMembers();

      notifyListeners();

      return family;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<BackendFamilySpace> updateSelectedFamily({
    required String name,
    required String description,
  }) async {
    final familyId = _selectedFamilyId;

    if (familyId == null) {
      throw StateError('Keine Familie ausgewählt.');
    }

    _error = null;

    try {
      final updatedFamily = await _familySpaceService.updateFamilySpace(
        familyId: familyId,
        name: name,
        description: description,
      );

      _replaceFamily(updatedFamily);

      notifyListeners();

      return updatedFamily;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateMemberRole({
    required String memberId,
    required String role,
  }) async {
    _isUpdatingMember = true;
    _error = null;
    notifyListeners();

    try {
      await _familySpaceService.updateFamilyMemberRole(
        memberId: memberId,
        role: role,
      );

      await _loadSelectedFamilyMembers();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isUpdatingMember = false;
      notifyListeners();
    }
  }

  Future<void> removeMember({required String memberId}) async {
    _isUpdatingMember = true;
    _error = null;
    notifyListeners();

    try {
      await _familySpaceService.removeFamilyMember(memberId: memberId);

      await _loadSelectedFamilyMembers();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isUpdatingMember = false;
      notifyListeners();
    }
  }

  Future<FamilyInvitation> createInvitation({
    FamilyInvitationRole role = FamilyInvitationRole.adult,
  }) async {
    final familyId = _selectedFamilyId;

    if (familyId == null) {
      throw StateError('Keine Familie ausgewählt.');
    }

    _isCreatingInvitation = true;
    _error = null;
    notifyListeners();

    try {
      return await _familySpaceService.createFamilyInvitation(
        familyId: familyId,
        role: role,
      );
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isCreatingInvitation = false;
      notifyListeners();
    }
  }

  Future<FamilyInvitationPreview> previewInvitation(String code) async {
    _error = null;

    try {
      return await _familySpaceService.getFamilyInvitationPreview(code);
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<String> joinFamilyWithInvitation(String code) async {
    _isJoiningFamily = true;
    _error = null;
    notifyListeners();

    try {
      final familyId = await _familySpaceService.joinFamilyWithInvitation(code);

      final families = await _familySpaceService.getMyFamilySpaces();

      _familySpaces
        ..clear()
        ..addAll(families);

      final joinedFamilyExists = _familySpaces.any(
        (family) => family.id == familyId,
      );

      if (joinedFamilyExists) {
        _selectedFamilyId = familyId;
      } else if (_familySpaces.isNotEmpty) {
        _selectedFamilyId = _familySpaces.first.id;
      } else {
        _selectedFamilyId = null;
      }

      _members.clear();
      _selectedFamilyImageUrl = null;

      if (_selectedFamilyId != null) {
        await _loadSelectedFamilyMembers();
        await _loadSelectedFamilyImage();
      }

      return familyId;
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isJoiningFamily = false;
      notifyListeners();
    }
  }

  Future<void> uploadSelectedFamilyImage(File imageFile) async {
    final familyId = _selectedFamilyId;

    if (familyId == null) {
      throw StateError('Keine Familie ausgewählt.');
    }

    _isUpdatingFamilyImage = true;
    _error = null;
    notifyListeners();

    try {
      final updatedFamily = await _familySpaceService.uploadFamilyImage(
        familyId: familyId,
        imageFile: imageFile,
      );

      _replaceFamily(updatedFamily);

      await _loadSelectedFamilyImage();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isUpdatingFamilyImage = false;
      notifyListeners();
    }
  }

  Future<void> removeSelectedFamilyImage() async {
    final familyId = _selectedFamilyId;

    if (familyId == null) {
      throw StateError('Keine Familie ausgewählt.');
    }

    _isUpdatingFamilyImage = true;
    _error = null;
    notifyListeners();

    try {
      final updatedFamily = await _familySpaceService.removeFamilyImage(
        familyId: familyId,
      );

      _replaceFamily(updatedFamily);
      _selectedFamilyImageUrl = null;
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isUpdatingFamilyImage = false;
      notifyListeners();
    }
  }

  Future<void> selectFamily(String familyId) async {
    final exists = _familySpaces.any((family) => family.id == familyId);

    if (!exists || _selectedFamilyId == familyId) {
      return;
    }

    _selectedFamilyId = familyId;
    _members.clear();
    _selectedFamilyImageUrl = null;

    notifyListeners();

    await _loadSelectedFamilyMembers();
    await _loadSelectedFamilyImage();
  }

  void _replaceFamily(BackendFamilySpace updatedFamily) {
    final index = _familySpaces.indexWhere(
      (family) => family.id == updatedFamily.id,
    );

    if (index != -1) {
      _familySpaces[index] = updatedFamily;
    }
  }

  void clear() {
    _familySpaces.clear();
    _members.clear();

    _selectedFamilyId = null;
    _selectedFamilyImageUrl = null;
    _error = null;

    _isLoading = false;
    _isLoadingMembers = false;
    _isUpdatingFamilyImage = false;
    _isCreatingInvitation = false;
    _isJoiningFamily = false;
    _isUpdatingMember = false;

    notifyListeners();
  }
}
