import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile/user_profile.dart';
import '../screens/auth/auth_welcome_page.dart';
import '../screens/auth/sign_in_page.dart';
import '../screens/auth/sign_up_page.dart';
import '../screens/family/no_family_page.dart';
import '../screens/main/main_shell.dart';
import '../services/auth/auth_service.dart';
import '../services/profile/profile_service.dart';
import '../stores/backend_family_store.dart';

class FamilyLogApp extends StatefulWidget {
  const FamilyLogApp({super.key});

  @override
  State<FamilyLogApp> createState() => _FamilyLogAppState();
}

class _FamilyLogAppState extends State<FamilyLogApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final BackendFamilyStore _backendFamilyStore;
  late final AuthService _authService;
  late final ProfileService _profileService;
  late final StreamSubscription<AuthState> _authSubscription;

  UserProfile? _currentProfile;
  bool _isLoadingProfile = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();

    _backendFamilyStore = BackendFamilyStore();
    _backendFamilyStore.addListener(_handleBackendFamilyStoreChanged);

    _authService = AuthService();
    _profileService = ProfileService();

    _authSubscription = _authService.authStateChanges.listen((_) {
      _handleAuthStateChanged();
    });

    if (_authService.isSignedIn) {
      _loadSignedInData();
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();

    _backendFamilyStore.removeListener(_handleBackendFamilyStoreChanged);

    _backendFamilyStore.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF5D6FC0);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'FamilyLog',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9BA8FF),
          brightness: Brightness.dark,
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_authService.isSignedIn) {
      return AuthWelcomePage(onSignIn: _openSignIn, onSignUp: _openSignUp);
    }

    if (_isLoadingProfile || _backendFamilyStore.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profileError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Daten konnten nicht geladen werden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(_profileError!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loadSignedInData,
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_currentProfile == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Für diesen Account wurde kein Profil gefunden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loadSignedInData,
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_backendFamilyStore.hasFamilies) {
      return NoFamilyPage(backendFamilyStore: _backendFamilyStore);
    }

    return MainShell(
      backendFamilyStore: _backendFamilyStore,
      currentProfile: _currentProfile!,
    );
  }

  Future<void> _handleAuthStateChanged() async {
    if (!_authService.isSignedIn) {
      _backendFamilyStore.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentProfile = null;
        _profileError = null;
        _isLoadingProfile = false;
      });

      return;
    }

    await _loadSignedInData();
  }

  Future<void> _loadSignedInData() async {
    if (!_authService.isSignedIn) {
      return;
    }

    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    try {
      final profile = await _profileService.getCurrentProfile();

      if (profile == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentProfile = null;
        });

        return;
      }

      await _backendFamilyStore.loadFamilySpaces();

      if (_backendFamilyStore.error != null) {
        throw StateError(_backendFamilyStore.error!);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentProfile = profile;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _profileError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  void _handleBackendFamilyStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _openSignIn() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) {
          return SignInPage(authService: _authService);
        },
      ),
    );
  }

  void _openSignUp() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) {
          return SignUpPage(authService: _authService);
        },
      ),
    );
  }
}
