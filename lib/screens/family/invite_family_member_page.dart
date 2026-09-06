import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/family/family_invitation.dart';
import '../../stores/family_store.dart';

class InviteFamilyMemberPage extends StatefulWidget {
  const InviteFamilyMemberPage({super.key, required this.familyStore});

  final FamilyStore familyStore;

  @override
  State<InviteFamilyMemberPage> createState() => _InviteFamilyMemberPageState();
}

class _InviteFamilyMemberPageState extends State<InviteFamilyMemberPage> {
  FamilyInvitation? _invitation;
  bool _isCreating = false;
  bool _isRevoking = false;

  @override
  void initState() {
    super.initState();

    final activeInvitations = widget.familyStore.activeInvitations;

    if (activeInvitations.isNotEmpty) {
      _invitation = activeInvitations.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = widget.familyStore.family;
    final invitation = _invitation;

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
          if (invitation == null)
            _EmptyInvitationCard(
              isCreating: _isCreating,
              onCreate: _createInvitation,
            )
          else
            _InvitationCard(
              invitation: invitation,
              familyName: family.name,
              isRevoking: _isRevoking,
              onCopy: () => _copyCode(invitation.code),
              onShare: () => _shareInvitation(invitation, family.name),
              onRevoke: _revokeInvitation,
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
            text: 'Erstelle einen persönlichen Einladungscode.',
          ),
          const SizedBox(height: 10),
          const _InfoRow(
            number: '2',
            text:
                'Teile den Code oder zeige den QR-Code '
                'dem Familienmitglied.',
          ),
          const SizedBox(height: 10),
          const _InfoRow(
            number: '3',
            text:
                'Später kann die Einladung direkt in FamilyLog '
                'angenommen werden.',
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
                    'Einladungscodes sind 7 Tage gültig und können '
                    'jederzeit widerrufen werden.',
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
    setState(() {
      _isCreating = true;
    });

    try {
      final invitation = await widget.familyStore.createInvitation();

      if (!mounted) {
        return;
      }

      setState(() {
        _invitation = invitation;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
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
${invitation.code}

Öffne FamilyLog und gib diesen Code ein, um der Familie beizutreten.

Der Einladungscode ist 7 Tage gültig.
''';

    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Einladung zu $familyName'),
    );
  }

  Future<void> _revokeInvitation() async {
    final invitation = _invitation;

    if (invitation == null) {
      return;
    }

    setState(() {
      _isRevoking = true;
    });

    try {
      await widget.familyStore.revokeInvitation(invitation.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _invitation = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einladung wurde widerrufen.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRevoking = false;
        });
      }
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
            'Noch keine aktive Einladung',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Erstelle einen Code, um jemanden in eure Familie einzuladen.',
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
                    ? 'Code wird erstellt...'
                    : 'Einladungscode erstellen',
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
    required this.isRevoking,
    required this.onCopy,
    required this.onShare,
    required this.onRevoke,
  });

  final FamilyInvitation invitation;
  final String familyName;
  final bool isRevoking;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onRevoke;

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
          Text(
            'DEIN EINLADUNGSCODE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            invitation.code,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _expirationText(invitation),
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
              data: invitation.code,
              version: QrVersions.auto,
              size: 210,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'QR-Code scannen',
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
              label: const Text('Code kopieren'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: isRevoking ? null : onRevoke,
              icon: const Icon(Icons.link_off),
              label: Text(
                isRevoking ? 'Wird widerrufen...' : 'Einladung widerrufen',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _expirationText(FamilyInvitation invitation) {
    final expiresAt = invitation.expiresAt;

    if (expiresAt == null) {
      return 'Ohne Ablaufdatum';
    }

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

    return 'Gültig bis ${expiresAt.day}. '
        '${months[expiresAt.month - 1]} ${expiresAt.year}';
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
