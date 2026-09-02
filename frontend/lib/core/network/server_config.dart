import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

/// ServerConfig manages the active backend base URL and allows runtime reconfiguration
/// without rebuilding the app.
class ServerConfig extends ChangeNotifier {
  ServerConfig({
    required ApiService api,
    String? initialUrl,
  })  : _api = api,
        _activeUrl = initialUrl ?? _defaultBaseUrl;

  static const String _storageKey = 'voltez_custom_server_url';
  static const String _storageVersionKey = 'voltez_server_config_version';
  static const String _storageVersion = 'render-sb0w-v1';

  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://voltez-sb0w.onrender.com/api/v1',
  );

  static const Set<String> _legacyDefaultHosts = {
    '127.0.0.1',
    'localhost',
    '10.0.2.2',
    'voltez-backend.onrender.com',
    'api.voltez.app',
  };

  final ApiService _api;
  String _activeUrl;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  /// Current active HTTP API base URL (e.g. `http://10.98.69.20:8000/api/v1`).
  String get activeUrl => _activeUrl;

  /// Corresponding WebSocket base URL (e.g. `ws://10.98.69.20:8000/api/v1`).
  String get wsBaseUrl => httpToWsUrl(_activeUrl);

  bool get isTesting => _isTesting;
  String? get testResult => _testResult;
  bool? get testSuccess => _testSuccess;

  /// Convert an HTTP/HTTPS API URL to its WebSocket counterpart.
  static String httpToWsUrl(String httpUrl) {
    var url = httpUrl.trim();
    if (url.startsWith('https://')) {
      return url.replaceFirst('https://', 'wss://');
    } else if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'ws://');
    } else {
      return 'ws://$url';
    }
  }

  /// Normalize any user input (e.g. `192.168.1.5:8001` -> `http://192.168.1.5:8001/api/v1`).
  static String normalizeUrl(String input) {
    var trimmed = input.trim();
    if (trimmed.isEmpty) return _defaultBaseUrl;

    // Add protocol if missing
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }

    // Strip trailing slash
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }

    // Ensure /api/v1 suffix if not present
    if (!trimmed.endsWith('/api/v1')) {
      trimmed = '$trimmed/api/v1';
    }

    return trimmed;
  }

  /// Load persisted custom base URL from secure storage.
  static Future<String> loadSavedBaseUrl() async {
    try {
      const storage = FlutterSecureStorage();
      final saved = await storage.read(key: _storageKey);
      final storedVersion = await storage.read(key: _storageVersionKey);
      if (saved != null && saved.trim().isNotEmpty) {
        final normalized = normalizeUrl(saved.trim());
        final savedHost = Uri.tryParse(normalized)?.host;

        // Existing installs may have persisted a loopback address or the old
        // Render hostname. Migrate those once so an updated APK connects to
        // the deployed API without requiring the user to clear app storage.
        if (storedVersion != _storageVersion &&
            savedHost != null &&
            _legacyDefaultHosts.contains(savedHost)) {
          await storage.write(key: _storageKey, value: _defaultBaseUrl);
          await storage.write(
            key: _storageVersionKey,
            value: _storageVersion,
          );
          return _defaultBaseUrl;
        }

        await storage.write(key: _storageVersionKey, value: _storageVersion);
        return normalized;
      }
      await storage.write(key: _storageVersionKey, value: _storageVersion);
    } catch (_) {}
    return _defaultBaseUrl;
  }

  /// Persist and apply a new server URL at runtime.
  Future<void> updateServerUrl(String newUrl) async {
    final normalized = normalizeUrl(newUrl);
    _activeUrl = normalized;
    _api.setBaseUrl(normalized);

    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: _storageKey, value: normalized);
    } catch (_) {}

    notifyListeners();
  }

  /// Reset to the compile-time default URL.
  Future<void> resetToDefault() async {
    _activeUrl = _defaultBaseUrl;
    _api.setBaseUrl(_defaultBaseUrl);

    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: _storageKey);
    } catch (_) {}

    notifyListeners();
  }

  /// Test connectivity to a given server URL.
  Future<bool> testConnection(String targetUrl) async {
    _isTesting = true;
    _testResult = 'Testing connection...';
    _testSuccess = null;
    notifyListeners();

    final normalized = normalizeUrl(targetUrl);
    final stopwatch = Stopwatch()..start();

    try {
      final testDio = Dio(
        BaseOptions(
          baseUrl: normalized,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      // Attempt to ping docs or health or root
      final rootUrl = normalized.replaceAll('/api/v1', '');
      Response? res;
      try {
        res = await testDio.get('$rootUrl/docs');
      } catch (_) {
        res = await testDio.get('/auth/login');
      }

      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;

      if (res.statusCode != null && res.statusCode! < 500) {
        _testSuccess = true;
        _testResult = 'Connected successfully (${ms}ms) [HTTP ${res.statusCode}]';
      } else {
        _testSuccess = false;
        _testResult = 'Server returned HTTP ${res.statusCode}';
      }
    } catch (e) {
      stopwatch.stop();
      _testSuccess = false;
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          _testResult = 'Connection timed out (Host unreachable)';
        } else if (e.type == DioExceptionType.connectionError) {
          _testResult = 'Connection refused / unreachable. Check IP & Wi-Fi';
        } else {
          _testResult = 'Error: ${e.message ?? e.toString()}';
        }
      } else {
        _testResult = 'Failed: $e';
      }
    } finally {
      _isTesting = false;
      notifyListeners();
    }

    return _testSuccess ?? false;
  }
}
