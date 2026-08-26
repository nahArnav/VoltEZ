import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/models.dart';
import '../network/api_service.dart';

/// Auth state managed via ChangeNotifier (Provider).
/// Handles login, logout, role persistence, and token storage.
class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', accessToken);
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', accessToken);
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
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

  // ─── Quick login (for demo/testing — skips backend) ───
  void demoLogin(AccountRole role) {
    _user = User(
      id: 'demo',
      name: role == AccountRole.driver ? 'Demo Driver' : 'ABC Motors',
      email: role == AccountRole.driver ? 'driver@voltez.in' : 'business@voltez.in',
      role: role,
    );
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // ─── Logout ───
  Future<void> logout() async {
    _user = null;
    _error = null;
    _api.setToken(null);
    _api.setRefreshToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }

  // ─── Restore session from storage ───
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final refreshToken = prefs.getString('refresh_token');
    if (token != null) {
      _api.setToken(token);
      _api.setRefreshToken(refreshToken);
      try {
        final response = await _api.getMe();
        _user = User.fromJson(response.data as Map<String, dynamic>);
      } catch (_) {
        // Token expired or invalid
        await prefs.remove('auth_token');
        _api.setToken(null);
      }
      notifyListeners();
    }
  }
}
