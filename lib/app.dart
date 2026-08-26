import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/auth/auth_provider.dart';
import 'core/routing/app_router.dart';

class VoltezApp extends StatefulWidget {
  const VoltezApp({super.key});

  @override
  State<VoltezApp> createState() => _VoltezAppState();
}

class _VoltezAppState extends State<VoltezApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter(context.read<AuthProvider>()).router;
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style for dark theme
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.card,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return MaterialApp.router(
      title: 'VoltEZ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router!,
    );
  }
}
