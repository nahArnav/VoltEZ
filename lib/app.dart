import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'core/theme/app_theme.dart';

class VoltezApp extends StatelessWidget {
  const VoltezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voltez',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}