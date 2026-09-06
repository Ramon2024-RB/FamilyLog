import 'package:flutter/material.dart';

import '../../models/profile/user_profile.dart';
import '../../stores/backend_family_store.dart';
import '../calendar/calendar_page.dart';
import '../chat/chat_page.dart';
import '../family/family_page.dart';
import '../more/more_page.dart';
import '../today/today_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.backendFamilyStore,
    required this.currentProfile,
  });

  final BackendFamilyStore backendFamilyStore;
  final UserProfile currentProfile;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(
        backendFamilyStore: widget.backendFamilyStore,
        currentProfile: widget.currentProfile,
      ),
      const ChatPage(),
      const CalendarPage(),
      FamilyPage(backendFamilyStore: widget.backendFamilyStore),
      const MorePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Heute',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.family_restroom_outlined),
            selectedIcon: Icon(Icons.family_restroom),
            label: 'Familie',
          ),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Mehr'),
        ],
      ),
    );
  }
}
