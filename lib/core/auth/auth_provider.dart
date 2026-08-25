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

      // Store token
      final token = data['token'] as String?;
      if (token != null) {
        _api.setToken(token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
      }

      // Parse user
      if (data['user'] != null) {
        _user = User.fromJson(data['user'] as Map<String, dynamic>);
      } else {
        // Fallback: create from email
        _user = User(
          id: 'temp',
          name: email.split('@').first,
          email: email,
          role: AccountRole.driver,
        );
      }

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
  Future<bool> signup(String name, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.signup(name, email, password);
      final data = response.data as Map<String, dynamic>;

      final token = data['token'] as String?;
      if (token != null) {
        _api.setToken(token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
      }

      if (data['user'] != null) {
        _user = User.fromJson(data['user'] as Map<String, dynamic>);
      } else {
        _user = User(id: 'temp', name: name, email: email, role: AccountRole.driver);
      }

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
        avatarUrl: _user!.avatarUrl,
        role: role,
      );
      notifyListeners();
    }
  }

  // ─── Quick login (for demo/testing — skips backend) ───
  void demoLogin(AccountRole role) {
    _user = User(
      id: 'demo-${role.name}',
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  // ─── Restore session from storage ───
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _api.setToken(token);
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
