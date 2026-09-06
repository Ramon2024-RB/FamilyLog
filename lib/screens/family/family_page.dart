import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/family/family_member.dart';
import '../../stores/family_store.dart';
import 'family_member_detail_page.dart';
import 'invite_family_member_page.dart';
import 'manage_family_page.dart';
import 'widgets/add_family_member_dialog.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key, required this.familyStore});

  final FamilyStore familyStore;

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  @override
  void initState() {
    super.initState();
    widget.familyStore.addListener(_onFamilyChanged);
  }

  @override
  void dispose() {
    widget.familyStore.removeListener(_onFamilyChanged);
    super.dispose();
  }

  void _onFamilyChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = widget.familyStore.family;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familie'),
        actions: [
          IconButton(
            tooltip: 'Familie verwalten',
            onPressed: _openManageFamily,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _FamilyHeader(
            familyName: family.name,
            description: family.description,
            memberCount: family.memberCount,
            imagePath: family.imagePath,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mitglieder',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${family.memberCount}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...family.members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemberCard(
                member: member,
                onTap: () => _openMember(member),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _showAddMemberOptions,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Mitglied hinzufügen'),
          ),
        ],
      ),
    );
  }

  Future<void> _openManageFamily() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ManageFamilyPage(familyStore: widget.familyStore);
        },
      ),
    );
  }

  Future<void> _showAddMemberOptions() async {
    final action = await showModalBottomSheet<_AddMemberAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  child: Text(
                    'Mitglied hinzufügen',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _AddMemberOption(
                  icon: Icons.send_outlined,
                  title: 'FamilyLog-Nutzer einladen',
                  subtitle:
                      'Erstelle einen Einladungscode für ein Familienmitglied.',
                  onTap: () {
                    Navigator.of(context).pop(_AddMemberAction.invite);
                  },
                ),
                const SizedBox(height: 8),
                _AddMemberOption(
                  icon: Icons.person_add_alt_outlined,
                  title: 'Person lokal anlegen',
                  subtitle: 'Füge eine Person hinzu, die keinen eigenen Account benötigt.',
                  onTap: () {
                    Navigator.of(context).pop(_AddMemberAction.createLocal);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _AddMemberAction.invite:
        await _openInvitationPage();

      case _AddMemberAction.createLocal:
        await _addLocalMember();
    }
  }

  Future<void> _openInvitationPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return InviteFamilyMemberPage(familyStore: widget.familyStore);
        },
      ),
    );
  }

  Future<void> _addLocalMember() async {
    final member = await showDialog<FamilyMember>(
      context: context,
      builder: (context) {
        return const AddFamilyMemberDialog();
      },
    );

    if (member == null || !mounted) {
      return;
    }

    await widget.familyStore.addMember(member);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${member.fullName} wurde hinzugefügt.')),
    );
  }

  Future<void> _openMember(FamilyMember member) async {
    final result = await Navigator.of(context).push<FamilyMemberDetailResult>(
      MaterialPageRoute(
        builder: (context) {
          return FamilyMemberDetailPage(member: member);
        },
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    switch (result.action) {
      case FamilyMemberDetailAction.updated:
        final updatedMember = result.member;

        if (updatedMember == null) {
          return;
        }

        await widget.familyStore.updateMember(updatedMember);

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedMember.fullName} wurde aktualisiert.'),
          ),
        );

      case FamilyMemberDetailAction.deleted:
        final deletedMember = result.member;

        if (deletedMember == null) {
          return;
        }

        await widget.familyStore.removeMember(deletedMember.id);

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${deletedMember.fullName} wurde entfernt.')),
        );
    }
  }
}

enum _AddMemberAction { invite, createLocal }

class _AddMemberOption extends StatelessWidget {
  const _AddMemberOption({
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
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({
    required this.familyName,
    required this.description,
    required this.memberCount,
    required this.imagePath,
  });

  final String familyName;
  final String? description;
  final int memberCount;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _FamilyHeaderImage(imagePath: imagePath),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  familyName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '$memberCount Mitglieder',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
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

class _FamilyHeaderImage extends StatelessWidget {
  const _FamilyHeaderImage({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentImagePath = imagePath;

    final hasImage =
        currentImagePath != null && File(currentImagePath).existsSync();

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(
              File(currentImagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.family_restroom,
                  size: 34,
                  color: theme.colorScheme.primary,
                );
              },
            )
          : Icon(
              Icons.family_restroom,
              size: 34,
              color: theme.colorScheme.primary,
            ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});

  final FamilyMember member;
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
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(
                  member.initials,
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (member.isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Du',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      member.roleLabel,
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
