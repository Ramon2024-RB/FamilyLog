import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_family_page.dart';
import '../../models/family/backend_family_member.dart';
import '../../stores/backend_family_store.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key, required this.backendFamilyStore});

  final BackendFamilyStore backendFamilyStore;

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  @override
  void initState() {
    super.initState();
    widget.backendFamilyStore.addListener(_onFamilyChanged);
  }

  Future<void> _openManageFamily() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ManageFamilyPage(
            backendFamilyStore: widget.backendFamilyStore,
          );
        },
      ),
    );
  }

  @override
  void didUpdateWidget(covariant FamilyPage oldWidget) {
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

    if (family == null) {
      return const Scaffold(
        body: Center(child: Text('Keine Familie ausgewählt.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familie'),
        actions: [
          IconButton(
            tooltip: 'Familie verwalten',
            onPressed: _openManageFamily,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.backendFamilyStore.loadSelectedFamilyMembers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _FamilyHeader(
              familyName: family.name,
              description: family.description,
              memberCount: members.length,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mitglieder',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${members.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.backendFamilyStore.isLoadingMembers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (members.isEmpty)
              _EmptyMembersCard()
            else
              ...members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MemberCard(
                    member: member,
                    isCurrentUser: _isCurrentUser(member),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showAddMemberInfo,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Mitglied hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentUser(BackendFamilyMember member) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return currentUserId != null && member.userId == currentUserId;
  }

  Future<void> _showAddMemberInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_outlined, size: 42),
                const SizedBox(height: 16),
                Text(
                  'Mitglieder über Supabase',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Als Nächstes bauen wir hier das echte Einladen '
                  'von FamilyLog-Nutzern und das Anlegen von '
                  'Familienmitgliedern ohne eigenen Account ein.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({
    required this.familyName,
    required this.description,
    required this.memberCount,
  });

  final String familyName;
  final String description;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.family_restroom,
              size: 34,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  familyName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  memberCount == 1 ? '1 Mitglied' : '$memberCount Mitglieder',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
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

class _EmptyMembersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'In dieser Familie wurden noch keine Mitglieder gefunden.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.isCurrentUser});

  final BackendFamilyMember member;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Text(
                member.initials,
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Du',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    member.roleLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (member.hasAccount) ...[
                    const SizedBox(height: 3),
                    Text(
                      'FamilyLog-Account verbunden',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
