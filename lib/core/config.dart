/// Environment configuration for VoltEZ Business Owner app.
///
/// Usage: Build with `--dart-define ENV=staging` or `--dart-define ENV=production`.
/// Defaults to `development` (localhost) when no flag is provided.
class AppConfig {
  AppConfig._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'development');

  /// Current environment name.
  static String get environment => _env;

  /// Whether this is a production build.
  static bool get isProduction => _env == 'production';

  /// Whether this is a staging build.
  static bool get isStaging => _env == 'staging';

  /// Whether this is a development (local) build.
  static bool get isDevelopment => _env == 'development';

  /// FastAPI backend base URL resolved from build-time environment flag.
  static String get apiBaseUrl {
    switch (_env) {
      case 'production':
        return 'https://api.voltez.app/api/v1';
      case 'staging':
        return 'https://voltez-api.onrender.com/api/v1';
      default:
        return 'http://localhost:8000/api/v1';
    }
  }

  /// Google Maps Geocoding API key (injected via `--dart-define MAPS_KEY=...`).
  static const String mapsApiKey = String.fromEnvironment('MAPS_KEY', defaultValue: '');

  /// Firebase Cloud Messaging VAPID key for web push (optional).
  static const String fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY', defaultValue: '');
}
