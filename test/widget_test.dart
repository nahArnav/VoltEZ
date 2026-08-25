import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:voltez_frontend/app.dart';
import 'package:voltez_frontend/core/auth/auth_provider.dart';
import 'package:voltez_frontend/core/providers/charger_discovery_provider.dart';
import 'package:voltez_frontend/core/providers/route_planner_provider.dart';
import 'package:voltez_frontend/core/providers/booking_provider.dart';
import 'package:voltez_frontend/core/providers/session_provider.dart';
import 'package:voltez_frontend/shared/models/models.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider()..demoLogin(AccountRole.driver),
          ),
          ChangeNotifierProvider(
            create: (_) => ChargerDiscoveryProvider(),
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