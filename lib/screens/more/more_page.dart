import 'package:flutter/material.dart';

import '../family/join_family_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const ListTile(
            leading: Icon(Icons.task_alt),
            title: Text('Aufgaben'),
            subtitle: Text('Familienaufgaben planen und verteilen'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.shopping_cart_outlined),
            title: Text('Einkaufslisten'),
            subtitle: Text('Gemeinsam einkaufen und Listen verwalten'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.celebration_outlined),
            title: Text('Familienereignisse'),
            subtitle: Text('Feiern, Ausflüge und gemeinsame Planungen'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.photo_library_outlined),
            title: Text('Erinnerungen'),
            subtitle: Text('Fotos, Alben und Familienmomente'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: const Text('Familie beitreten'),
            subtitle: const Text('Mit Einladungscode oder QR-Code beitreten'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return const JoinFamilyPage();
                  },
                ),
              );
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('FamilyLog Safety'),
            subtitle: Text('Sicherheit und Hilfe innerhalb der Familie'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Einstellungen'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
