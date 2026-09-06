import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/family/family_invitation.dart';
import '../../stores/backend_family_store.dart';
import 'scan_family_invitation_page.dart';

class JoinFamilyPage extends StatefulWidget {
  const JoinFamilyPage({super.key, required this.backendFamilyStore});

  final BackendFamilyStore backendFamilyStore;

  @override
  State<JoinFamilyPage> createState() => _JoinFamilyPageState();
}

class _JoinFamilyPageState extends State<JoinFamilyPage> {
  final _codeController = TextEditingController();

  bool _isChecking = false;
  bool _isJoining = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Familie beitreten')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                Icons.family_restroom,
                size: 42,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Einer Familie beitreten',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gib den kurzen Einladungscode ein, den du von '
            'einem Familienmitglied erhalten hast.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              LengthLimitingTextInputFormatter(40),
            ],
            decoration: InputDecoration(
              labelText: 'Einladungscode',
              hintText: 'AB12-CD34',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.key_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() {
                  _errorText = null;
                });
              }
            },
            onSubmitted: (_) {
              _checkCode();
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isChecking ? null : _checkCode,
              child: _isChecking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Einladung prüfen'),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'ODER',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isChecking ? null : _scanQrCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QR-Code scannen'),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Du kannst den kurzen Einladungscode '
                    'eingeben oder den QR-Code direkt mit '
                    'FamilyLog scannen. Jede Einladung ist '
                    'nur einmal verwendbar.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQrCode() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) {
          return const ScanFamilyInvitationPage();
        },
      ),
    );

    if (!mounted || scannedCode == null) {
      return;
    }

    _codeController.text = scannedCode.trim().toUpperCase();

    setState(() {
      _errorText = null;
    });

    await _checkCode();
  }

  Future<void> _checkCode() async {
    if (_isChecking || _isJoining) {
      return;
    }

    final code = _codeController.text.trim().toUpperCase();

    if (!_isValidCodeFormat(code)) {
      setState(() {
        _errorText = 'Bitte gib einen gültigen FamilyLog-Code ein.';
      });

      return;
    }

    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    try {
      final preview = await widget.backendFamilyStore.previewInvitation(code);

      if (!mounted) {
        return;
      }

      await _showInvitationPreview(code: code, preview: preview);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _showInvitationPreview({
    required String code,
    required FamilyInvitationPreview preview,
  }) async {
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.family_restroom,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Einladung gefunden',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            preview.familyName,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (preview.familyDescription.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              preview.familyDescription,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _PreviewInfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Deine Rolle',
                            value: preview.role.label,
                          ),
                          const SizedBox(height: 10),
                          _PreviewInfoRow(
                            icon: Icons.schedule_outlined,
                            label: 'Gültig bis',
                            value: _expirationText(preview.expiresAt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Möchtest du dieser Familie beitreten?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isJoining
                            ? null
                            : () async {
                                setSheetState(() {
                                  _isJoining = true;
                                });

                                final success = await _joinFamily(
                                  code,
                                  sheetContext,
                                );

                                if (!success && sheetContext.mounted) {
                                  setSheetState(() {
                                    _isJoining = false;
                                  });
                                }
                              },
                        icon: _isJoining
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.group_add_outlined),
                        label: Text(
                          _isJoining
                              ? 'Beitritt läuft...'
                              : 'Familie beitreten',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isJoining
                            ? null
                            : () {
                                Navigator.of(sheetContext).pop();
                              },
                        child: const Text('Abbrechen'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _joinFamily(String code, BuildContext sheetContext) async {
    try {
      await widget.backendFamilyStore.joinFamilyWithInvitation(code);

      if (!mounted) {
        return true;
      }

      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du bist der Familie beigetreten.')),
      );

      Navigator.of(context).pop(true);

      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));

      return false;
    }
  }

  bool _isValidCodeFormat(String code) {
    final manualCode = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$');

    final secureQrCode = RegExp(r'^FAM-[A-Z0-9]{32}$');

    return manualCode.hasMatch(code) || secureQrCode.hasMatch(code);
  }

  String _errorMessage(Object error) {
    final message = error.toString();

    if (message.contains('Invalid invitation')) {
      return 'Dieser Einladungscode ist ungültig.';
    }

    if (message.contains('Invitation expired')) {
      return 'Diese Einladung ist abgelaufen.';
    }

    if (message.contains('Invitation already used')) {
      return 'Diese Einladung wurde bereits verwendet.';
    }

    if (message.contains('Invitation revoked')) {
      return 'Diese Einladung wurde widerrufen.';
    }

    if (message.contains('Already a family member')) {
      return 'Du bist bereits Mitglied dieser Familie.';
    }

    if (message.contains('Not authenticated')) {
      return 'Du bist nicht mehr angemeldet.';
    }

    if (message.contains('Profile not found')) {
      return 'Dein FamilyLog-Profil konnte nicht '
          'gefunden werden.';
    }

    return 'Die Einladung konnte nicht geprüft werden.';
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

    return '${localExpiresAt.day}. '
        '${months[localExpiresAt.month - 1]} '
        '${localExpiresAt.year}, '
        '${localExpiresAt.hour.toString().padLeft(2, '0')}:'
        '${localExpiresAt.minute.toString().padLeft(2, '0')} Uhr';
  }
}

class _PreviewInfoRow extends StatelessWidget {
  const _PreviewInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
