import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/family/backend_family_member.dart';
import '../../models/family/backend_family_space.dart';

class FamilySpaceService {
  FamilySpaceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _familyImagesBucket = 'family-images';

  Future<BackendFamilySpace> createFamilySpace({
    required String name,
    String description = '',
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Kein Benutzer angemeldet.');
    }

    final familyId = await _client.rpc(
      'create_family_space',
      params: {
        'family_name': name.trim(),
        'family_description': description.trim(),
      },
    );

    if (familyId == null) {
      throw StateError('Der Familienraum konnte nicht erstellt werden.');
    }

    final response = await _client
        .from('family_spaces')
        .select()
        .eq('id', familyId.toString())
        .single();

    return BackendFamilySpace.fromMap(response);
  }

  Future<List<BackendFamilySpace>> getMyFamilySpaces() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return [];
    }

    final memberships = await _client
        .from('family_memberships')
        .select('family_id')
        .eq('user_id', user.id);

    if (memberships.isEmpty) {
      return [];
    }

    final familyIds = memberships
        .map((membership) => membership['family_id'] as String)
        .toList();

    final response = await _client
        .from('family_spaces')
        .select()
        .inFilter('id', familyIds)
        .order('created_at');

    return response
        .map((family) => BackendFamilySpace.fromMap(family))
        .toList();
  }

  Future<List<BackendFamilyMember>> getFamilyMembers(String familyId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return [];
    }

    final response = await _client
        .from('family_members')
        .select()
        .eq('family_id', familyId)
        .order('created_at');

    return response
        .map((member) => BackendFamilyMember.fromMap(member))
        .toList();
  }

  Future<BackendFamilySpace> updateFamilySpace({
    required String familyId,
    required String name,
    required String description,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Kein Benutzer angemeldet.');
    }

    final response = await _client
        .from('family_spaces')
        .update({
          'name': name.trim(),
          'description': description.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', familyId)
        .select()
        .single();

    return BackendFamilySpace.fromMap(response);
  }

  Future<BackendFamilySpace> uploadFamilyImage({
    required String familyId,
    required File imageFile,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Kein Benutzer angemeldet.');
    }

    final extension = _fileExtension(imageFile.path);
    final storagePath = '$familyId/family.$extension';

    await _client.storage
        .from(_familyImagesBucket)
        .upload(
          storagePath,
          imageFile,
          fileOptions: const FileOptions(upsert: true, cacheControl: '3600'),
        );

    final response = await _client
        .from('family_spaces')
        .update({
          'image_url': storagePath,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', familyId)
        .select()
        .single();

    return BackendFamilySpace.fromMap(response);
  }

  Future<BackendFamilySpace> removeFamilyImage({
    required String familyId,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Kein Benutzer angemeldet.');
    }

    final familyResponse = await _client
        .from('family_spaces')
        .select('image_url')
        .eq('id', familyId)
        .single();

    final storagePath = familyResponse['image_url'] as String?;

    if (storagePath != null && storagePath.trim().isNotEmpty) {
      await _client.storage.from(_familyImagesBucket).remove([storagePath]);
    }

    final response = await _client
        .from('family_spaces')
        .update({
          'image_url': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', familyId)
        .select()
        .single();

    return BackendFamilySpace.fromMap(response);
  }

  Future<String?> createFamilyImageSignedUrl(BackendFamilySpace family) async {
    final storagePath = family.imageUrl;

    if (storagePath == null || storagePath.trim().isEmpty) {
      return null;
    }

    return _client.storage
        .from(_familyImagesBucket)
        .createSignedUrl(storagePath, 60 * 60);
  }

  String _fileExtension(String filePath) {
    final fileName = filePath.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'jpg';
    }

    final extension = fileName.substring(dotIndex + 1).toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return extension;
      default:
        return 'jpg';
    }
  }
}
