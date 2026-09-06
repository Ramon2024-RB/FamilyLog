import 'package:flutter/material.dart';

import '../../models/family/family_member.dart';
import 'widgets/add_family_member_dialog.dart';

enum FamilyMemberDetailAction { updated, deleted }

class FamilyMemberDetailResult {
  const FamilyMemberDetailResult({required this.action, this.member});

  final FamilyMemberDetailAction action;
  final FamilyMember? member;
}

class FamilyMemberDetailPage extends StatefulWidget {
  const FamilyMemberDetailPage({super.key, required this.member});

  final FamilyMember member;

  @override
  State<FamilyMemberDetailPage> createState() => _FamilyMemberDetailPageState();
}

class _FamilyMemberDetailPageState extends State<FamilyMemberDetailPage> {
  late FamilyMember _member;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _closePage();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Familienmitglied'),
          leading: IconButton(
            tooltip: 'Zurück',
            onPressed: _closePage,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Bearbeiten',
              onPressed: _editMember,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  _member.initials,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _member.fullName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _member.roleLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_member.isCurrentUser) ...[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Das bist du',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              'Familie',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.badge_outlined,
              title: 'Rolle',
              value: _member.roleLabel,
            ),
            const SizedBox(height: 10),
            const _InfoCard(
              icon: Icons.family_restroom,
              title: 'Familienraum',
              value: 'Familie Vidal',
            ),
            const SizedBox(height: 28),
            Text(
              'FamilyLog',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.chat_bubble_outline,
              title: 'Nachricht senden',
              subtitle: 'Privaten FamilyLog-Chat öffnen',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.task_alt,
              title: 'Aufgaben',
              subtitle: 'Zugewiesene Familienaufgaben anzeigen',
              onTap: () {},
            ),
            if (_member.role == FamilyMemberRole.child ||
                _member.role == FamilyMemberRole.senior) ...[
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.shield_outlined,
                title: 'FamilyLog Safety',
                subtitle: _member.role == FamilyMemberRole.child
                    ? 'Sicherheitseinstellungen für dieses Kind'
                    : 'Hilfe- und Sicherheitseinstellungen',
                onTap: () {},
              ),
            ],
            const SizedBox(height: 32),
            if (!_member.isCurrentUser)
              OutlinedButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Mitglied entfernen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            if (_member.isCurrentUser)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dein eigener Account kann hier nicht aus dem '
                        'Familienraum entfernt werden.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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

  Future<void> _editMember() async {
    final updatedMember = await showDialog<FamilyMember>(
      context: context,
      builder: (context) {
        return AddFamilyMemberDialog(existingMember: _member);
      },
    );

    if (updatedMember == null || !mounted) {
      return;
    }

    setState(() {
      _member = updatedMember;
      _hasChanges = true;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Änderungen gespeichert.')));
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mitglied entfernen?'),
          content: Text(
            '${_member.fullName} wirklich aus Familie Vidal entfernen?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Entfernen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    Navigator.of(context).pop(
      FamilyMemberDetailResult(
        action: FamilyMemberDetailAction.deleted,
        member: _member,
      ),
    );
  }

  void _closePage() {
    if (_hasChanges) {
      Navigator.of(context).pop(
        FamilyMemberDetailResult(
          action: FamilyMemberDetailAction.updated,
          member: _member,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

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
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
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
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
