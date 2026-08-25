import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/auth/auth_provider.dart';
import 'core/providers/charger_discovery_provider.dart';
import 'core/providers/route_planner_provider.dart';
import 'core/providers/booking_provider.dart';
import 'core/providers/session_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..restoreSession()),
        ChangeNotifierProvider(create: (_) => ChargerDiscoveryProvider()),
        ChangeNotifierProvider(create: (_) => RoutePlannerProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: const VoltezApp(),
    ),
  );
}
