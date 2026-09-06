import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../stores/backend_family_store.dart';

class ManageFamilyPage extends StatefulWidget {
  const ManageFamilyPage({super.key, required this.backendFamilyStore});

  final BackendFamilyStore backendFamilyStore;

  @override
  State<ManageFamilyPage> createState() => _ManageFamilyPageState();
}

class _ManageFamilyPageState extends State<ManageFamilyPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

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

    widget.backendFamilyStore.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.backendFamilyStore.removeListener(_onStoreChanged);

    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
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

    final imageUrl = widget.backendFamilyStore.selectedFamilyImageUrl;

    final isUpdatingImage = widget.backendFamilyStore.isUpdatingFamilyImage;

    return Scaffold(
      appBar: AppBar(title: const Text('Familie verwalten')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholder(theme);
                            },
                          )
                        : _buildPlaceholder(theme),
                  ),
                  if (isUpdatingImage)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: IconButton.filled(
                      onPressed: isUpdatingImage ? null : _pickFamilyImage,
                      tooltip: 'Familienbild auswählen',
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Familienbild',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Das Bild wird im gemeinsamen Familienraum '
              'gespeichert.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (imageUrl != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: isUpdatingImage ? null : _removeFamilyImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Familienbild entfernen'),
                ),
              ),
            ],
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
                      'Familienbild, Familienname und Beschreibung '
                      'werden im gemeinsamen Familienraum gespeichert.',
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

  Widget _buildPlaceholder(ThemeData theme) {
    return Icon(
      Icons.family_restroom,
      size: 54,
      color: theme.colorScheme.primary,
    );
  }

  Future<void> _pickFamilyImage() async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (pickedImage == null) {
        return;
      }

      await widget.backendFamilyStore.uploadSelectedFamilyImage(
        File(pickedImage.path),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Familienbild wurde gespeichert.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Das Familienbild konnte nicht gespeichert werden.'),
        ),
      );
    }
  }

  Future<void> _removeFamilyImage() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Familienbild entfernen?'),
          content: const Text(
            'Das aktuelle Familienbild wird aus dem '
            'gemeinsamen Familienraum entfernt.',
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
              child: const Text('Entfernen'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    try {
      await widget.backendFamilyStore.removeSelectedFamilyImage();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Familienbild wurde entfernt.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Das Familienbild konnte nicht entfernt werden.'),
        ),
      );
    }
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
