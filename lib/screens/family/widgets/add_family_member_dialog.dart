import 'package:flutter/material.dart';

import '../../../models/family/family_member.dart';

class AddFamilyMemberDialog extends StatefulWidget {
  const AddFamilyMemberDialog({super.key, this.existingMember});

  final FamilyMember? existingMember;

  @override
  State<AddFamilyMemberDialog> createState() => _AddFamilyMemberDialogState();
}

class _AddFamilyMemberDialogState extends State<AddFamilyMemberDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late FamilyMemberRole _selectedRole;

  bool get _isEditing => widget.existingMember != null;

  @override
  void initState() {
    super.initState();

    final member = widget.existingMember;

    _firstNameController = TextEditingController(text: member?.firstName ?? '');

    _lastNameController = TextEditingController(text: member?.lastName ?? '');

    _selectedRole = member?.role ?? FamilyMemberRole.adult;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Mitglied bearbeiten' : 'Mitglied hinzufügen'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Vorname',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte einen Vornamen eingeben';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nachname',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<FamilyMemberRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rolle',
                  border: OutlineInputBorder(),
                ),
                items: FamilyMemberRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(_roleLabel(role)),
                  );
                }).toList(),
                onChanged: (role) {
                  if (role == null) {
                    return;
                  }

                  setState(() {
                    _selectedRole = role;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Speichern' : 'Hinzufügen'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final existingMember = widget.existingMember;

    final member = FamilyMember(
      id:
          existingMember?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      role: _selectedRole,
      profileImagePath: existingMember?.profileImagePath,
      isCurrentUser: existingMember?.isCurrentUser ?? false,
    );

    Navigator.of(context).pop(member);
  }

  String _roleLabel(FamilyMemberRole role) {
    switch (role) {
      case FamilyMemberRole.owner:
        return 'Familieninhaber';
      case FamilyMemberRole.admin:
        return 'Administrator';
      case FamilyMemberRole.adult:
        return 'Erwachsener';
      case FamilyMemberRole.child:
        return 'Kind';
      case FamilyMemberRole.senior:
        return 'Senior';
    }
  }
}
