import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:voltez_frontend/app.dart';
import 'package:voltez_frontend/core/auth/auth_provider.dart';
import 'package:voltez_frontend/core/providers/charger_discovery_provider.dart';
import 'package:voltez_frontend/core/providers/route_planner_provider.dart';
import 'package:voltez_frontend/core/providers/booking_provider.dart';
import 'package:voltez_frontend/core/providers/session_provider.dart';
import 'package:voltez_frontend/core/providers/business_provider.dart';
import 'package:voltez_frontend/core/network/api_service.dart';
import 'package:voltez_frontend/core/network/server_config.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>(
            create: (_) => ApiService(baseUrl: 'http://localhost:8000'),
          ),
          ChangeNotifierProxyProvider<ApiService, ServerConfig>(
            create: (ctx) => ServerConfig(api: ctx.read<ApiService>(), initialUrl: 'http://localhost:8000'),
            update: (_, api, _) => ServerConfig(api: api, initialUrl: 'http://localhost:8000'),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => ChargerDiscoveryProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => BusinessProvider(api: ctx.read<ApiService>()),
          ),
          ChangeNotifierProvider(
            create: (_) => RoutePlannerProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => BookingProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => SessionProvider(),
          ),
        ],
        child: const VoltezApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(VoltezApp), findsOneWidget);
  });
}
