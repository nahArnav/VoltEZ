import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/models/models.dart';
import '../network/api_service.dart';
import '../services/notification_service.dart';

/// Auth state managed via ChangeNotifier (Provider).
/// Handles login, logout, role persistence, and token storage.
class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
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
  Future<bool> updateProfile({
    required String name,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.updateMe({
        'name': name.trim(),
        if (phone != null) 'phone': phone.trim(),
      });

      _user = User.fromJson(
        response.data as Map<String, dynamic>,
      );

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
