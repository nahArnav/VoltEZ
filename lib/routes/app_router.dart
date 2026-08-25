import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Shell & Screens
import '../screens/shell/main_shell_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/station_onboarding_wizard_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/availability_scheduler_screen.dart';
import '../screens/earnings/earnings_screen.dart';
import '../screens/dashboard/ai_recommendations_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/dashboard/charger_management_screen.dart';
import '../screens/chargers/add_edit_chargers_screen.dart';
import '../services/business_api.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final BusinessApi _sharedApi = BusinessApi(
    baseUrl: 'https://api.yourdomain.com',
    getAuthToken: () => '',
  );

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    routes: [
      // -----------------------------------------------------------------------
      // AUTHENTICATION & ONBOARDING ROUTES
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _buildCustomTransitionPage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => _buildCustomTransitionPage(
          state: state,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => _buildCustomTransitionPage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding-wizard',
        name: 'onboarding-wizard',
        pageBuilder: (context, state) {
          final hostName = state.uri.queryParameters['hostName'] ?? 'Host';
          return _buildCustomTransitionPage(
            state: state,
            child: StationOnboardingWizardScreen(hostName: hostName),
          );
        },
      ),

      // -----------------------------------------------------------------------
      // HARDWARE ROUTES
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/chargers',
        name: 'chargers',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _buildCustomTransitionPage(
          state: state,
          child: ChargerManagementScreen(api: _sharedApi),
        ),
        routes: [
          GoRoute(
            path: 'add-edit',
            name: 'add-edit-charger',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => _buildCustomTransitionPage(
              state: state,
              child: const AddEditChargerScreen(),
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // PERSISTENT BOTTOM NAV SHELL (Removed 'const' from NoTransitionPage)
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard Overview
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: DashboardScreen(),
                ),
              ),
            ],
          ),

          // Branch 1: Availability & Dispatch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dispatch',
                name: 'dispatch',
                pageBuilder: (context, state) {
                  final initialChargerId = state.uri.queryParameters['chargerId'];
                  return NoTransitionPage(
                    child: AvailabilitySchedulerScreen(
                      api: _sharedApi,
                      initialChargerId: initialChargerId,
                    ),
                  );
                },
              ),
            ],
          ),

          // Branch 2: Financial Analytics & Earnings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/earnings',
                name: 'earnings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: EarningsScreen(),
                ),
              ),
            ],
          ),

          // Branch 3: AI Insights & Recommendations
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai-insights',
                name: 'ai-insights',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AiRecommendationsScreen(),
                ),
              ),
            ],
          ),

          // Branch 4: Station Host Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Custom Slide & Fade Transition
  static CustomTransitionPage<void> _buildCustomTransitionPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideIn = Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final fadeIn = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        return SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fadeIn,
            child: child,
          ),
        );
      },
    );
  }
}