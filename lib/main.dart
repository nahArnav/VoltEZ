import 'package:flutter/material.dart';
import 'screens/shell/main_screen_screen.dart';

void main() {
  runApp(const VoltezApp());
}

class VoltezApp extends StatelessWidget {
  const VoltezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voltez Station Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF05090E),
      ),
      home: const MainShellScreen(),
    );
  }
}