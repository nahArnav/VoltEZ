import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../../shared/models/models.dart';

// ─── Auth ───
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/role_selection_screen.dart';

// ─── Driver side (Person 1) ───
import '../../features/driver/home/driver_home_screen.dart';
import '../../features/driver/map/driver_map_screen.dart';
import '../../features/driver/onboarding/driver_onboarding_screen.dart';
import '../../features/driver/recommendations/route_planner_screen.dart';
import '../../features/driver/charger_details/charger_details_screen.dart';
import '../../features/driver/booking/booking_screen.dart';
import '../../features/driver/booking/booking_confirmation_screen.dart';
import '../../features/driver/session/charging_session_screen.dart';
import '../../features/driver/route_planner/route_planner_input_screen.dart';
import '../../features/driver/payment/payment_screen.dart';
import '../../features/driver/history/booking_history_screen.dart';

// ─── Business side (Person 2) ───
import '../../features/business/dashboard/dashboard_screen.dart';

/// App-wide router.
/// Routes are organized by feature ownership.
class AppRouter {
  AppRouter(this._auth);

  final AuthProvider _auth;

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: _auth,
    redirect: (context, state) {
      final isLoggedIn = _auth.isLoggedIn;
      final isAuthRoute = state.matchedLocation == '/splash' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/role-selection';

      // If not logged in and not on auth routes, go to login
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Authenticated users cannot revisit auth/role screens and mutate local role state.
      if (isLoggedIn && isAuthRoute) {
        return _auth.currentRole == AccountRole.owner
            ? '/business/dashboard'
            : '/driver/home';
      }

      return null;
    },
    routes: [
      // ─── Auth Routes ───
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      // ─── Driver Routes (Person 1) ───
      GoRoute(
        path: '/driver/home',
        builder: (context, state) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: '/driver/map',
        builder: (context, state) => const DriverMapScreen(),
      ),
      GoRoute(
        path: '/driver/charger/:id',
        builder: (context, state) => ChargerDetailsScreen(
          chargerId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/driver/booking',
        builder: (context, state) => const BookingScreen(),
      ),
      GoRoute(
        path: '/driver/session',
        builder: (context, state) => const ChargingSessionScreen(),
      ),
      GoRoute(
        path: '/driver/route-planner',
        builder: (context, state) => const RoutePlannerInputScreen(),
      ),
      GoRoute(
        path: '/driver/recommendations',
        builder: (context, state) => const RoutePlannerScreen(),
      ),
      GoRoute(
        path: '/driver/payment',
        builder: (context, state) => const PaymentScreen(),
      ),
      GoRoute(
        path: '/driver/booking-confirmation',
        builder: (context, state) => const BookingConfirmationScreen(),
      ),
      GoRoute(
        path: '/driver/history',
        builder: (context, state) => const DriverHistoryScreen(),
      ),
      GoRoute(
        path: '/driver/onboarding',
        builder: (context, state) => const DriverOnboardingScreen(),
      ),

      // ─── Business Routes (Person 2) ───
      GoRoute(
        path: '/business/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/business/chargers',
        builder: (context, state) => const DashboardScreen(initialTab: 1),
      ),
      GoRoute(
        path: '/business/availability',
        builder: (context, state) => const DashboardScreen(initialTab: 1),
      ),
      GoRoute(
        path: '/business/bookings',
        builder: (context, state) => const DashboardScreen(initialTab: 2),
      ),
      GoRoute(
        path: '/business/analytics',
        builder: (context, state) => const DashboardScreen(initialTab: 3),
      ),
      GoRoute(
        path: '/business/profile',
        builder: (context, state) => const DashboardScreen(initialTab: 4),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.matchedLocation}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}
