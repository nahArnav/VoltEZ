import 'package:flutter/foundation.dart';

/// Environment configuration for the VoltEZ Platform.
///
/// Build flags:
/// - `flutter run --dart-define ENV=staging`
/// - `flutter run --dart-define ENV=production`
/// - `flutter run --dart-define MAPS_KEY=your_key`
/// - `flutter run --dart-define FCM_VAPID_KEY=your_key`
class AppConfig {
  AppConfig._();

  static const String _env = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  /// Current environment name (`development`, `staging`, `production`).
  static String get environment => _env.toLowerCase();

  /// Whether this is a production build.
  static bool get isProduction => environment == 'production';

  /// Whether this is a staging build.
  static bool get isStaging => environment == 'staging';

  /// Whether this is a local development build.
  static bool get isDevelopment => environment == 'development';

  /// Whether debug tools/logs should be enabled.
  static bool get isDebug => !isProduction;

  /// FastAPI backend base URL resolved from build-time environment flags.
  static String get apiBaseUrl {
    switch (environment) {
      case 'production':
        return 'https://api.voltez.app/api/v1';
      case 'staging':
        return 'https://voltez-backend.onrender.com/api/v1';
      case 'development':
      default:
        // Android emulators route host machine loopback through 10.0.2.2
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          return 'http://10.0.2.2:8000/api/v1';
        }
        return 'http://localhost:8000/api/v1';
    }
  }

  /// Google Maps API key (injected via `--dart-define MAPS_KEY=...`).
  static const String mapsApiKey = String.fromEnvironment(
    'MAPS_KEY',
    defaultValue: '',
  );

  /// Firebase Cloud Messaging VAPID key for web push notifications.
  static const String fcmVapidKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue: '',
  );
}