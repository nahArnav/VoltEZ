import 'package:flutter/material.dart';
import 'routes/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoltezApp());
}

class VoltezApp extends StatelessWidget {
  const VoltezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Voltez Station Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF05090E),
      ),
      routerConfig: AppRouter.router,
    );
  }
}