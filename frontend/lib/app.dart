import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    // GoRouter owns listeners and route state. Create it once for the app
    // lifetime; recreating it from build() can tear down an active route tree
    // during auth notifications and trigger Flutter's _dependents assertion.
    _appRouter = AppRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style for light theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.card,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'VoltEZ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _appRouter.router,
    );
  }
}
