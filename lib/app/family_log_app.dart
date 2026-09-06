import 'package:flutter/material.dart';

import '../screens/main/main_shell.dart';

class FamilyLogApp extends StatelessWidget {
  const FamilyLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF5D6FC0);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FamilyLog',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9BA8FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainShell(),
    );
  }
}
