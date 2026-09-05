import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/models/models.dart';
import 'auth_repository.dart';
import 'google_credential_service.dart';
import '../network/api_service.dart';
import '../services/notification_service.dart';

/// Auth state managed via ChangeNotifier (Provider).
/// Handles login, logout, role persistence, and token storage.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    ApiService? api,
    AuthRepository? repository,
    GoogleCredentialService? googleCredentialService,
  }) : _api = api ?? ApiService(),
       _googleCredentialService =
           googleCredentialService ?? const GoogleCredentialService() {
    _repository = repository ?? AuthRepository(_api);
  }

  final ApiService _api;
  late final AuthRepository _repository;
  final GoogleCredentialService _googleCredentialService;
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'voltez_access_token';
  static const _refreshKey = 'voltez_refresh_token';

  // ─── State ───
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  AccountRole? get currentRole => _user?.role;

  // ─── Login ───
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.login(email, password);
      final data = response.data as Map<String, dynamic>;

      // Backend returns: { access_token, refresh_token, token_type: "bearer" }
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      if (accessToken != null) {
        _api.setToken(accessToken);
        _api.setRefreshToken(refreshToken);
        await _storage.write(key: _accessKey, value: accessToken);
        if (refreshToken != null) {
          await _storage.write(key: _refreshKey, value: refreshToken);
        }
      }

      // Fetch the authoritative profile; never fabricate an authenticated user.
      final userResponse = await _api.getMe();
      _user = User.fromJson(userResponse.data as Map<String, dynamic>);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Google Sign-In ───
  // Credential Manager -> Google ID token -> backend -> VoltEZ JWT session.
  Future<bool> signInWithGoogle({required AccountRole role}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final googleIdToken = await _googleCredentialService.getIdToken();
      final tokens = await _repository.signInWithGoogle(
        idToken: googleIdToken,
        role: role.name,
      );

      await _startSession(tokens);
      _isLoading = false;
      notifyListeners();
      return true;
    } on PlatformException catch (e) {
      _error = switch (e.code) {
        'google_sign_in_cancelled' => 'Google sign-in was cancelled.',
        'no_google_credential' =>
          'No Google account is available on this device.',
        _ => e.message ?? 'Google sign-in failed. Please try again.',
      };
    } catch (e) {
      _error = _authenticationError(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> _startSession(AuthTokenPair tokens) async {
    _api.setToken(tokens.accessToken);
    _api.setRefreshToken(tokens.refreshToken);
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);

    try {
      final userResponse = await _api.getMe();
      _user = User.fromJson(userResponse.data as Map<String, dynamic>);
    } catch (_) {
      _api.setToken(null);
      _api.setRefreshToken(null);
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      rethrow;
    }
  }

  String _authenticationError(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final detail = responseData['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
      }
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'The VoltEZ server timed out. Please try again.',
        DioExceptionType.connectionError =>
          'Unable to reach the VoltEZ server. Check your connection.',
        _ => 'Google authentication was rejected by the server.',
      };
    }
    if (error is FormatException) return error.message;
    return 'Google sign-in failed. Please try again.';
  }

  // ─── Signup ───
  // Backend: POST /auth/register → returns UserResponse
  Future<bool> signup(
    String name,
    String email,
    String password, {
    required AccountRole role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.register(
        name: name,
        email: email,
        password: password,
        role: role.name,
      );
      final userData = response.data as Map<String, dynamic>;

      // Backend returns user object, then we need to login separately
      final loginResponse = await _api.login(email, password);
      final loginData = loginResponse.data as Map<String, dynamic>;

      final accessToken = loginData['access_token'] as String?;
      final refreshToken = loginData['refresh_token'] as String?;
      if (accessToken != null) {
        _api.setToken(accessToken);
        _api.setRefreshToken(refreshToken);
        await _storage.write(key: _accessKey, value: accessToken);
        if (refreshToken != null) {
          await _storage.write(key: _refreshKey, value: refreshToken);
        }
      }

      _user = User.fromJson(userData);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Update Profile ───
  Future<bool> updateProfile({required String name, String? phone}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.updateMe({
        'name': name.trim(),
        if (phone != null) 'phone': phone.trim(),
      });

      _user = User.fromJson(response.data as Map<String, dynamic>);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Set Role (after role selection) ───
  void setRole(AccountRole role) {
    if (_user != null) {
      _user = User(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phone: _user!.phone,
        role: role,
      );
      notifyListeners();
    }
  }

  // ─── Logout ───
  Future<void> logout() async {
    _user = null;
    _error = null;
    _api.setToken(null);
    _api.setRefreshToken(null);
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    try {
      await _googleCredentialService.clearCredentialState();
    } on PlatformException {
      // The VoltEZ session is already cleared; native sign-out is best effort.
    }
    await NotificationService.instance.clear();
    notifyListeners();
  }

  // ─── Restore session from storage ───
  Future<void> restoreSession() async {
    final token = await _storage.read(key: _accessKey);
    final refreshToken = await _storage.read(key: _refreshKey);
    if (token != null) {
      _api.setToken(token);
      _api.setRefreshToken(refreshToken);
      try {
        final response = await _api.getMe();
        _user = User.fromJson(response.data as Map<String, dynamic>);
      } catch (_) {
        // Token expired or invalid
        await _storage.delete(key: _accessKey);
        await _storage.delete(key: _refreshKey);
        _api.setToken(null);
        _api.setRefreshToken(null);
      }
      notifyListeners();
    }
  }
}
