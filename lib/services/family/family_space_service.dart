import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/family/backend_family_member.dart';
import '../../models/family/backend_family_space.dart';

class FamilySpaceService {
  FamilySpaceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
}
