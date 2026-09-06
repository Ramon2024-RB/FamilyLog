import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../models/family/family_profile.dart';
import '../../stores/family_store.dart';

class ManageFamilyPage extends StatefulWidget {
  const ManageFamilyPage({super.key, required this.familyStore});

  final FamilyStore familyStore;

  @override
  State<ManageFamilyPage> createState() => _ManageFamilyPageState();
}

class _ManageFamilyPageState extends State<ManageFamilyPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String? _imagePath;
  bool _isSaving = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();

    final profile = widget.familyStore.profile;

    _nameController = TextEditingController(text: profile.name);

    _descriptionController = TextEditingController(text: profile.description);

    _imagePath = profile.imagePath;
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
                  _FamilyImage(imagePath: _imagePath),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: theme.colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isPickingImage ? null : _pickImage,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _isPickingImage
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.photo_camera_outlined,
                                  size: 20,
                                  color: theme.colorScheme.onPrimary,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
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
            TextButton.icon(
              onPressed: _isPickingImage ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _imagePath == null
                    ? 'Familienbild auswählen'
                    : 'Familienbild ändern',
              ),
            ),
            if (_imagePath != null) ...[
              TextButton.icon(
                onPressed: _isPickingImage ? null : _removeImage,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Familienbild entfernen'),
              ),
            ],
            const SizedBox(height: 24),
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
              onPressed: _isSaving || _isPickingImage ? null : _save,
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
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Diese Angaben gelten für euren gemeinsamen '
                      'Familienraum und werden allen Mitgliedern angezeigt.',
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

  Future<void> _pickImage() async {
    setState(() {
      _isPickingImage = true;
    });

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (pickedImage == null) {
        return;
      }

      final savedImagePath = await _copyImageToAppStorage(pickedImage);

      if (!mounted) {
        return;
      }

      setState(() {
        _imagePath = savedImagePath;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Das Familienbild konnte nicht ausgewählt werden.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<String> _copyImageToAppStorage(XFile pickedImage) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();

    final familyImagesDirectory = Directory(
      path.join(documentsDirectory.path, 'family_images'),
    );

    if (!await familyImagesDirectory.exists()) {
      await familyImagesDirectory.create(recursive: true);
    }

    final extension = path.extension(pickedImage.path).isEmpty
        ? '.jpg'
        : path.extension(pickedImage.path);

    final fileName =
        'family_${DateTime.now().millisecondsSinceEpoch}$extension';

    final destinationPath = path.join(familyImagesDirectory.path, fileName);

    final savedImage = await File(pickedImage.path).copy(destinationPath);

    return savedImage.path;
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final currentProfile = widget.familyStore.profile;

      final updatedProfile = FamilyProfile(
        id: currentProfile.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imagePath: _imagePath,
      );

      await widget.familyStore.updateFamilyProfile(updatedProfile);

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

class _FamilyImage extends StatelessWidget {
  const _FamilyImage({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentImagePath = imagePath;

    final hasImage =
        currentImagePath != null && File(currentImagePath).existsSync();

    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(
              File(currentImagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.family_restroom,
                  size: 52,
                  color: theme.colorScheme.primary,
                );
              },
            )
          : Icon(
              Icons.family_restroom,
              size: 52,
              color: theme.colorScheme.primary,
            ),
    );
  }
}
