import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';

class VoltezApp extends StatelessWidget {
  const VoltezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}