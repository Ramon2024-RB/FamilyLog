import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile/user_profile.dart';

class ProfileService {
  ProfileService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserProfile.fromMap(response);
  }

  Future<UserProfile> updateCurrentProfile({
    required String firstName,
    required String lastName,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Kein Benutzer angemeldet.');
    }

    final response = await _client
        .from('profiles')
        .update({
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id)
        .select()
        .single();

    return UserProfile.fromMap(response);
  }
}
