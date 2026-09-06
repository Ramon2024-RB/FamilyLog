import 'package:flutter/material.dart';

import '../../stores/backend_family_store.dart';
import 'create_family_space_page.dart';
import 'join_family_page.dart';

class NoFamilyPage extends StatelessWidget {
  const NoFamilyPage({super.key, required this.backendFamilyStore});

  final BackendFamilyStore backendFamilyStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      Icons.family_restroom,
                      size: 54,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Willkommen bei FamilyLog',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Erstelle einen neuen Familienraum oder tritt '
                    'einer bestehenden Familie bei.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () {
                        _createFamily(context);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Familie erstellen'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _joinFamily(context);
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Familie beitreten'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Deine Familienräume sind nur für '
                          'Mitglieder sichtbar.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createFamily(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return CreateFamilySpacePage(backendFamilyStore: backendFamilyStore);
        },
      ),
    );
  }

  Future<void> _joinFamily(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return const JoinFamilyPage();
        },
      ),
    );
  }
}
