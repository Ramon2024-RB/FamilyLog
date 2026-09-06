import 'package:flutter/material.dart';

import '../../stores/backend_family_store.dart';

class ManageFamilyPage extends StatefulWidget {
  const ManageFamilyPage({super.key, required this.backendFamilyStore});

  final BackendFamilyStore backendFamilyStore;

  @override
  State<ManageFamilyPage> createState() => _ManageFamilyPageState();
}

class _ManageFamilyPageState extends State<ManageFamilyPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final family = widget.backendFamilyStore.selectedFamily;

    _nameController = TextEditingController(text: family?.name ?? '');

    _descriptionController = TextEditingController(
      text: family?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = widget.backendFamilyStore.selectedFamily;

    if (family == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Familie verwalten')),
        body: const Center(child: Text('Keine Familie ausgewählt.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Familie verwalten')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.family_restroom,
                  size: 52,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Familienraum',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Das Familienbild richten wir anschließend '
              'über den gemeinsamen Cloud-Speicher ein.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Familienname',
                hintText: 'Zum Beispiel Familie Vidal',
                prefixIcon: Icon(Icons.family_restroom),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte einen Familiennamen eingeben';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                hintText: 'Beschreibe euren Familienraum',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 54),
                  child: Icon(Icons.notes),
                ),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSaving ? 'Wird gespeichert...' : 'Änderungen speichern',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
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
                  Icon(
                    Icons.cloud_done_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Familienname und Beschreibung werden '
                      'im gemeinsamen Familienraum gespeichert '
                      'und stehen damit allen berechtigten '
                      'Familienmitgliedern zur Verfügung.',
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.backendFamilyStore.updateSelectedFamily(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Änderungen konnten nicht gespeichert werden.'),
        ),
      );
    }
  }
}
