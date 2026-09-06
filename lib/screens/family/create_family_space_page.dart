import 'package:flutter/material.dart';

import '../../models/family/backend_family_space.dart';
import '../../stores/backend_family_store.dart';

class CreateFamilySpacePage extends StatefulWidget {
  const CreateFamilySpacePage({super.key, required this.backendFamilyStore});

  final BackendFamilyStore backendFamilyStore;

  @override
  State<CreateFamilySpacePage> createState() => _CreateFamilySpacePageState();
}

class _CreateFamilySpacePageState extends State<CreateFamilySpacePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familie erstellen')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.family_restroom, size: 64),
              const SizedBox(height: 24),
              Text(
                'Neuen Familienraum erstellen',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gib deiner Familie einen Namen und optional eine Beschreibung.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Familienname',
                  hintText: 'z. B. Familie Vidal',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte gib einen Familiennamen ein.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  hintText: 'z. B. Unser gemeinsamer Familienraum',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _createFamily,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _isSaving ? 'Familie wird erstellt ...' : 'Familie erstellen',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createFamily() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final BackendFamilySpace family = await widget.backendFamilyStore
          .createFamilySpace(
            name: _nameController.text,
            description: _descriptionController.text,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(family);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Familie konnte nicht erstellt werden.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
