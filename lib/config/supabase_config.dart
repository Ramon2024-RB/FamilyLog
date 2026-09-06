class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://iymgnfqopfaprfwgfasu.supabase.co';

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
}
