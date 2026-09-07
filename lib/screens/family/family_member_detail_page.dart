import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/family/backend_family_member.dart';
import '../../stores/backend_family_store.dart';

class FamilyMemberDetailPage extends StatefulWidget {
  const FamilyMemberDetailPage({
    super.key,
    required this.backendFamilyStore,
    required this.member,
    required this.familyName,
  });

  final BackendFamilyStore backendFamilyStore;
  final BackendFamilyMember member;
  final String familyName;

  @override
  State<FamilyMemberDetailPage> createState() => _FamilyMemberDetailPageState();
}

class _FamilyMemberDetailPageState extends State<FamilyMemberDetailPage> {
  late BackendFamilyMember _member;

  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
  }

  bool get _isCurrentUser {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return userId != null && _member.userId == userId;
  }

  BackendFamilyMember? get _currentUserMember {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      return null;
    }

    for (final member in widget.backendFamilyStore.members) {
      if (member.userId == userId) {
        return member;
      }
    }

    return null;
  }

  bool get _currentUserIsOwner {
    return _currentUserMember?.role == BackendFamilyMemberRole.owner;
  }

  bool get _currentUserIsAdmin {
    return _currentUserMember?.role == BackendFamilyMemberRole.admin;
  }

  bool get _canManageMember {
    if (_isCurrentUser) {
      return false;
    }

    if (_member.role == BackendFamilyMemberRole.owner) {
      return false;
    }

    if (_currentUserIsOwner) {
      return true;
    }

    if (_currentUserIsAdmin && _member.role != BackendFamilyMemberRole.admin) {
      return true;
    }

    return false;
  }

  bool get _canAssignAdmin {
    return _currentUserIsOwner;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Familienmitglied')),
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
          if (_isCurrentUser) ...[
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
          _InfoCard(
            icon: Icons.family_restroom,
            title: 'Familienraum',
            value: widget.familyName,
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: _member.hasAccount
                ? Icons.verified_user_outlined
                : Icons.person_outline,
            title: 'FamilyLog-Account',
            value: _member.hasAccount ? 'Verbunden' : 'Nicht verbunden',
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
          if (_member.role == BackendFamilyMemberRole.child ||
              _member.role == BackendFamilyMemberRole.senior) ...[
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.shield_outlined,
              title: 'FamilyLog Safety',
              subtitle: _member.role == BackendFamilyMemberRole.child
                  ? 'Sicherheitseinstellungen für dieses Kind'
                  : 'Hilfe- und Sicherheitseinstellungen',
              onTap: () {},
            ),
          ],
          if (_canManageMember) ...[
            const SizedBox(height: 32),
            Text(
              'Verwaltung',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.manage_accounts_outlined,
              title: 'Rolle ändern',
              subtitle: 'Berechtigungen dieses Mitglieds ändern',
              onTap: _isSaving || _isDeleting ? () {} : _changeRole,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving || _isDeleting ? null : _confirmDelete,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_remove_outlined),
              label: Text(
                _isDeleting ? 'Wird entfernt...' : 'Mitglied entfernen',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
          if (_isCurrentUser) ...[
            const SizedBox(height: 32),
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
                      'Dein eigener Account kann hier nicht '
                      'aus dem Familienraum entfernt werden.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeRole() async {
    final selectedRole = await showModalBottomSheet<BackendFamilyMemberRole>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rolle ändern',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _member.fullName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (_canAssignAdmin)
                  _RoleTile(
                    role: BackendFamilyMemberRole.admin,
                    currentRole: _member.role,
                  ),
                _RoleTile(
                  role: BackendFamilyMemberRole.adult,
                  currentRole: _member.role,
                ),
                _RoleTile(
                  role: BackendFamilyMemberRole.child,
                  currentRole: _member.role,
                ),
                _RoleTile(
                  role: BackendFamilyMemberRole.senior,
                  currentRole: _member.role,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedRole == null || selectedRole == _member.role || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.backendFamilyStore.updateMemberRole(
        memberId: _member.id,
        role: _databaseRole(selectedRole),
      );

      final refreshedMember = _findRefreshedMember(_member.id);

      if (!mounted) {
        return;
      }

      setState(() {
        if (refreshedMember != null) {
          _member = refreshedMember;
        }
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Rolle wurde geändert.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mitglied entfernen?'),
          content: Text(
            '${_member.fullName} wirklich aus '
            '${widget.familyName} entfernen?\n\n'
            'Die Person verliert damit den Zugriff auf '
            'diesen Familienraum.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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

    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.backendFamilyStore.removeMember(memberId: _member.id);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  BackendFamilyMember? _findRefreshedMember(String memberId) {
    for (final member in widget.backendFamilyStore.members) {
      if (member.id == memberId) {
        return member;
      }
    }

    return null;
  }

  String _databaseRole(BackendFamilyMemberRole role) {
    switch (role) {
      case BackendFamilyMemberRole.owner:
        return 'owner';
      case BackendFamilyMemberRole.admin:
        return 'admin';
      case BackendFamilyMemberRole.adult:
        return 'adult';
      case BackendFamilyMemberRole.child:
        return 'child';
      case BackendFamilyMemberRole.senior:
        return 'senior';
    }
  }

  String _errorMessage(Object error) {
    final message = error.toString();

    if (message.contains('Owner cannot be modified')) {
      return 'Der Familieninhaber kann nicht '
          'bearbeitet werden.';
    }

    if (message.contains('Owner cannot be removed')) {
      return 'Der Familieninhaber kann nicht '
          'entfernt werden.';
    }

    if (message.contains('Only owner can assign admin')) {
      return 'Nur der Familieninhaber kann '
          'Administratoren festlegen.';
    }

    if (message.contains('Admin cannot modify admin')) {
      return 'Administratoren können andere '
          'Administratoren nicht bearbeiten.';
    }

    if (message.contains('Admin cannot remove admin')) {
      return 'Administratoren können andere '
          'Administratoren nicht entfernen.';
    }

    if (message.contains('Cannot remove yourself')) {
      return 'Du kannst dich hier nicht selbst '
          'entfernen.';
    }

    if (message.contains('Not allowed')) {
      return 'Du hast dafür keine Berechtigung.';
    }

    return 'Die Änderung konnte nicht gespeichert werden.';
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role, required this.currentRole});

  final BackendFamilyMemberRole role;
  final BackendFamilyMemberRole currentRole;

  @override
  Widget build(BuildContext context) {
    final selected = role == currentRole;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconForRole(role)),
      title: Text(_labelForRole(role)),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).pop(role);
      },
    );
  }

  String _labelForRole(BackendFamilyMemberRole role) {
    switch (role) {
      case BackendFamilyMemberRole.owner:
        return 'Familieninhaber';
      case BackendFamilyMemberRole.admin:
        return 'Administrator';
      case BackendFamilyMemberRole.adult:
        return 'Erwachsener';
      case BackendFamilyMemberRole.child:
        return 'Kind';
      case BackendFamilyMemberRole.senior:
        return 'Senior';
    }
  }

  IconData _iconForRole(BackendFamilyMemberRole role) {
    switch (role) {
      case BackendFamilyMemberRole.owner:
        return Icons.workspace_premium_outlined;
      case BackendFamilyMemberRole.admin:
        return Icons.admin_panel_settings_outlined;
      case BackendFamilyMemberRole.adult:
        return Icons.person_outline;
      case BackendFamilyMemberRole.child:
        return Icons.child_care_outlined;
      case BackendFamilyMemberRole.senior:
        return Icons.elderly_outlined;
    }
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
