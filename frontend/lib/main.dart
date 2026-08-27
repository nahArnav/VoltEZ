import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/auth/auth_provider.dart';
import 'core/providers/charger_discovery_provider.dart';
import 'core/providers/route_planner_provider.dart';
import 'core/providers/booking_provider.dart';
import 'core/providers/session_provider.dart';
import 'core/providers/business_provider.dart';
import 'core/network/api_service.dart';
import 'core/network/booking_api.dart';
import 'core/network/server_config.dart';
import 'core/network/session_api.dart';
import 'core/network/session_websocket.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialBaseUrl = await ServerConfig.loadSavedBaseUrl();
  final api = ApiService(baseUrl: initialBaseUrl);
  final serverConfig = ServerConfig(api: api, initialUrl: initialBaseUrl);
  final auth = AuthProvider(api: api)..restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerConfig>.value(value: serverConfig),
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(
          create: (_) => ChargerDiscoveryProvider(api: api),
        ),
        ChangeNotifierProvider(
          create: (_) => BusinessProvider(api: api),
        ),
        ChangeNotifierProvider(create: (_) => RoutePlannerProvider(api: api)),
        ChangeNotifierProvider(
          create: (_) => BookingProvider(bookingApi: LiveBookingApi(api)),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(
            sessionApi: LiveSessionApi(api),
            webSocket: LiveSessionWebSocket(
              baseUrlGetter: () => serverConfig.wsBaseUrl,
              userIdGetter: () => auth.user?.id,
              tokenGetter: () => api.token,
            ),
          ),
        ),
      ],
      child: const VoltezApp(),
    ),
  );
}
