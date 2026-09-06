import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scan_family_invitation_page.dart';

class JoinFamilyPage extends StatefulWidget {
  const JoinFamilyPage({super.key});

  @override
  State<JoinFamilyPage> createState() => _JoinFamilyPageState();
}

class _JoinFamilyPageState extends State<JoinFamilyPage> {
  final _codeController = TextEditingController();

  bool _isChecking = false;
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
          Container(
            width: 84,
            height: 84,
            margin: const EdgeInsets.symmetric(horizontal: 120),
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
            'Gib den Einladungscode ein, den du von einem '
            'Familienmitglied erhalten hast.',
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
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: 'Einladungscode',
              hintText: 'FAM-ABC123',
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
              onPressed: _scanQrCode,
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
                    'Einladungscodes beginnen mit „FAM-“ und '
                    'sind 7 Tage gültig.',
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

    _codeController.text = scannedCode;

    setState(() {
      _errorText = null;
    });

    await _checkCode();
  }

  Future<void> _checkCode() async {
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

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) {
      return;
    }

    setState(() {
      _isChecking = false;
    });

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.cloud_outlined),
          title: const Text('Backend folgt'),
          content: Text(
            'Der Code $code hat das richtige Format.\n\n'
            'Sobald FamilyLog mit dem Server verbunden ist, '
            'wird hier geprüft, zu welcher Familie diese '
            'Einladung gehört.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _isValidCodeFormat(String code) {
    return RegExp(r'^FAM-[A-HJ-NP-Z2-9]{6}$').hasMatch(code);
  }
}
