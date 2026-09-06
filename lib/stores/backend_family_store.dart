import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/family/backend_family_member.dart';
import '../models/family/backend_family_space.dart';
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

  String? _error;
  String? _selectedFamilyId;
  String? _selectedFamilyImageUrl;

  List<BackendFamilySpace> get familySpaces => List.unmodifiable(_familySpaces);

  List<BackendFamilyMember> get members => List.unmodifiable(_members);

  bool get isLoading => _isLoading;
  bool get isLoadingMembers => _isLoadingMembers;
  bool get isUpdatingFamilyImage => _isUpdatingFamilyImage;

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

    notifyListeners();
  }
}
