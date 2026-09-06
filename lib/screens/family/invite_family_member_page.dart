import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/family/family_invitation.dart';
import '../../stores/backend_family_store.dart';

class InviteFamilyMemberPage extends StatefulWidget {
  const InviteFamilyMemberPage({super.key, required this.backendFamilyStore});

  final BackendFamilyStore backendFamilyStore;

  @override
  State<InviteFamilyMemberPage> createState() => _InviteFamilyMemberPageState();
}

class _InviteFamilyMemberPageState extends State<InviteFamilyMemberPage> {
  FamilyInvitation? _invitation;
  FamilyInvitationRole _selectedRole = FamilyInvitationRole.adult;

  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = widget.backendFamilyStore.selectedFamily;
    final invitation = _invitation;

    if (family == null) {
      return const Scaffold(
        body: Center(child: Text('Keine Familie ausgewählt.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mitglied einladen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 46,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  family.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lade ein Familienmitglied in euren '
                  'gemeinsamen Familienraum ein.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (invitation == null) ...[
            Text(
              'Rolle auswählen',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lege fest, welche Rolle das Familienmitglied '
              'nach dem Beitritt erhält.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _RoleSelector(
              selectedRole: _selectedRole,
              onChanged: (role) {
                setState(() {
                  _selectedRole = role;
                });
              },
            ),
            const SizedBox(height: 20),
            _EmptyInvitationCard(
              isCreating: _isCreating,
              onCreate: _createInvitation,
            ),
          ] else
            _InvitationCard(
              invitation: invitation,
              familyName: family.name,
              role: _selectedRole,
              onCopy: () => _copyCode(invitation.manualCode),
              onShare: () => _shareInvitation(invitation, family.name),
              onCreateAnother: _createAnotherInvitation,
            ),
          const SizedBox(height: 28),
          Text(
            'So funktioniert es',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            number: '1',
            text: 'Wähle die Rolle des neuen Familienmitglieds.',
          ),
          const SizedBox(height: 10),
          const _InfoRow(
            number: '2',
            text:
                'FamilyLog erstellt einen persönlichen '
                'Einladungscode und QR-Code.',
          ),
          const SizedBox(height: 10),
          const _InfoRow(
            number: '3',
            text:
                'Das Familienmitglied öffnet FamilyLog und '
                'scannt den QR-Code oder gibt den kurzen '
                'Code ein.',
          ),
          const SizedBox(height: 10),
          const _InfoRow(
            number: '4',
            text:
                'Vor dem Beitritt wird die Familie noch '
                'einmal angezeigt und bestätigt.',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Jede Einladung ist nur einmal '
                    'verwendbar und 7 Tage gültig.',
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
    );
  }

  Future<void> _createInvitation() async {
    if (_isCreating) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final invitation = await widget.backendFamilyStore.createInvitation(
        role: _selectedRole,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _invitation = invitation;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einladung wurde erstellt.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _createAnotherInvitation() {
    setState(() {
      _invitation = null;
      _selectedRole = FamilyInvitationRole.adult;
    });
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einladungscode wurde kopiert.')),
    );
  }

  Future<void> _shareInvitation(
    FamilyInvitation invitation,
    String familyName,
  ) async {
    final text =
        '''
Du wurdest zu "$familyName" in FamilyLog eingeladen.

Dein Einladungscode:
${invitation.manualCode}

Öffne FamilyLog und gib diesen Code ein, um der Familie beizutreten.

Alternativ kannst du den QR-Code direkt in FamilyLog scannen.

Die Einladung ist einmal verwendbar und 7 Tage gültig.
''';

    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Einladung zu $familyName'),
    );
  }

  String _errorMessage(Object error) {
    final message = error.toString();

    if (message.contains('Not allowed to create invitations')) {
      return 'Du darfst für diese Familie keine '
          'Einladungen erstellen.';
    }

    if (message.contains('Not authenticated')) {
      return 'Du bist nicht mehr angemeldet.';
    }

    return 'Die Einladung konnte nicht erstellt werden.';
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selectedRole, required this.onChanged});

  final FamilyInvitationRole selectedRole;
  final ValueChanged<FamilyInvitationRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: FamilyInvitationRole.values.map((role) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RoleCard(
            role: role,
            isSelected: role == selectedRole,
            onTap: () => onChanged(role),
          ),
        );
      }).toList(),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final FamilyInvitationRole role;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                _roleIcon(role),
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleDescription(role),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(FamilyInvitationRole role) {
    switch (role) {
      case FamilyInvitationRole.admin:
        return Icons.admin_panel_settings_outlined;
      case FamilyInvitationRole.adult:
        return Icons.person_outline;
      case FamilyInvitationRole.child:
        return Icons.child_care_outlined;
      case FamilyInvitationRole.senior:
        return Icons.elderly_outlined;
    }
  }

  String _roleDescription(FamilyInvitationRole role) {
    switch (role) {
      case FamilyInvitationRole.admin:
        return 'Kann die Familie später mitverwalten.';
      case FamilyInvitationRole.adult:
        return 'Normales erwachsenes Familienmitglied.';
      case FamilyInvitationRole.child:
        return 'Für ein Kind mit angepassten Rechten.';
      case FamilyInvitationRole.senior:
        return 'Für ältere Familienmitglieder.';
    }
  }
}

class _EmptyInvitationCard extends StatelessWidget {
  const _EmptyInvitationCard({
    required this.isCreating,
    required this.onCreate,
  });

  final bool isCreating;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.key_outlined, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Einladung erstellen',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'FamilyLog erstellt einen einmalig '
            'verwendbaren Einladungscode für diese Person.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isCreating ? null : onCreate,
              icon: isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_link),
              label: Text(
                isCreating
                    ? 'Einladung wird erstellt...'
                    : 'Einladung erstellen',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.familyName,
    required this.role,
    required this.onCopy,
    required this.onShare,
    required this.onCreateAnother,
  });

  final FamilyInvitation invitation;
  final String familyName;
  final FamilyInvitationRole role;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 42,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Einladung bereit',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            role.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'EINLADUNGSCODE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            invitation.manualCode,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Zum manuellen Eingeben',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _expirationText(invitation.expiresAt),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              // Bewusst der lange sichere Token.
              data: invitation.code,
              version: QrVersions.auto,
              size: 210,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Mit FamilyLog scannen',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Einladung teilen'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Einladungscode kopieren'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onCreateAnother,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Weitere Person einladen'),
            ),
          ),
        ],
      ),
    );
  }

  String _expirationText(DateTime expiresAt) {
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    final localExpiresAt = expiresAt.toLocal();

    return 'Gültig bis ${localExpiresAt.day}. '
        '${months[localExpiresAt.month - 1]} '
        '${localExpiresAt.year}, '
        '${localExpiresAt.hour.toString().padLeft(2, '0')}:'
        '${localExpiresAt.minute.toString().padLeft(2, '0')} Uhr';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(text),
          ),
        ),
      ],
    );
  }
}
