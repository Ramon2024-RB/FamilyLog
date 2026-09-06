import 'package:flutter/material.dart';

import '../../models/profile/user_profile.dart';
import '../../stores/backend_family_store.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.backendFamilyStore,
    required this.currentProfile,
  });

  final BackendFamilyStore backendFamilyStore;
  final UserProfile currentProfile;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  @override
  void initState() {
    super.initState();
    widget.backendFamilyStore.addListener(_onFamilyChanged);
  }

  @override
  void didUpdateWidget(covariant TodayPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.backendFamilyStore != widget.backendFamilyStore) {
      oldWidget.backendFamilyStore.removeListener(_onFamilyChanged);
      widget.backendFamilyStore.addListener(_onFamilyChanged);
    }
  }

  @override
  void dispose() {
    widget.backendFamilyStore.removeListener(_onFamilyChanged);
    super.dispose();
  }

  void _onFamilyChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = widget.backendFamilyStore.selectedFamily;
    final members = widget.backendFamilyStore.members;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyLog'),
        actions: [
          IconButton(
            tooltip: 'Benachrichtigungen',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.backendFamilyStore.loadFamilySpaces();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              _greetingFor(now),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(now),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 24),
            if (family != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.family_restroom,
                        color: theme.colorScheme.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            family.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            members.length == 1
                                ? '1 Mitglied'
                                : '${members.length} Mitglieder',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            Text(
              'Heute',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const _EmptySectionCard(
              icon: Icons.today_outlined,
              title: 'Heute ist noch nichts geplant',
              subtitle:
                  'Termine, Aufgaben und andere Familienaktivitäten '
                  'erscheinen später hier.',
            ),
            const SizedBox(height: 28),
            Text(
              'Als Nächstes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const _EmptySectionCard(
              icon: Icons.event_outlined,
              title: 'Noch keine kommenden Einträge',
              subtitle:
                  'Sobald wir Kalender und Aufgaben anbinden, '
                  'siehst du hier die nächsten wichtigen Dinge.',
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FamilyLog Safety',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Schnelle Hilfe für Kinder und Senioren – '
                          'nur wenn sie wirklich gebraucht wird.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greetingFor(DateTime dateTime) {
    final firstName = widget.currentProfile.firstName.trim();
    final nameSuffix = firstName.isEmpty ? '' : ', $firstName';

    if (dateTime.hour < 11) {
      return 'Guten Morgen$nameSuffix';
    }

    if (dateTime.hour < 18) {
      return 'Guten Tag$nameSuffix';
    }

    return 'Guten Abend$nameSuffix';
  }

  String _formatDate(DateTime dateTime) {
    const weekdays = [
      'MONTAG',
      'DIENSTAG',
      'MITTWOCH',
      'DONNERSTAG',
      'FREITAG',
      'SAMSTAG',
      'SONNTAG',
    ];

    const months = [
      'JANUAR',
      'FEBRUAR',
      'MÄRZ',
      'APRIL',
      'MAI',
      'JUNI',
      'JULI',
      'AUGUST',
      'SEPTEMBER',
      'OKTOBER',
      'NOVEMBER',
      'DEZEMBER',
    ];

    final weekday = weekdays[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];

    return '$weekday, ${dateTime.day}. $month';
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
