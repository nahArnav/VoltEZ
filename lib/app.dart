import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/auth/auth_provider.dart';
import 'core/routing/app_router.dart';

class VoltezApp extends StatelessWidget {
  const VoltezApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final router = AppRouter(auth).router;

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
      routerConfig: router,
    );
  }
}
