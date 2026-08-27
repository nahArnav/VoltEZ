import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

/// User representation returned by GET /users/me
class AuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String? phone;
  final String? role;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.phone,
    this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
    );
  }
}

/// Authentication state model
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final AuthUser? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    AuthUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// StateNotifier managing login, register, token refresh, and user profile sync
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(const AuthState(isLoading: true)) {
    // Register auto-logout redirect callback with ApiClient
    _apiClient.onUnauthorized(() {
      state = const AuthState(isAuthenticated: false);
    });

    _initializeAuth();
  }

  /// Check stored credentials on app startup
  Future<void> _initializeAuth() async {
    try {
      final isAuth = await _apiClient.isAuthenticated;
      if (!isAuth) {
        state = const AuthState(isAuthenticated: false, isLoading: false);
        return;
      }

      final user = await _fetchCurrentUser();
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: user,
      );
    } catch (_) {
      await _apiClient.clearTokens();
      state = const AuthState(isAuthenticated: false, isLoading: false);
    }
  }

  /// Sign in with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final accessToken = response.data['access_token'] as String;
        final refreshToken = response.data['refresh_token'] as String;

        await _apiClient.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        final user = await _fetchCurrentUser();
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: user,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid response from server',
      );
      return false;
    } on DioException catch (e) {
      final message = e.response?.data?['detail'] ?? 'Login failed. Please check credentials.';
      state = state.copyWith(
        isLoading: false,
        errorMessage: message.toString(),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Register a new account
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          'display_name': displayName.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final accessToken = response.data['access_token'] as String?;
        final refreshToken = response.data['refresh_token'] as String?;

        if (accessToken != null && refreshToken != null) {
          await _apiClient.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          final user = await _fetchCurrentUser();
          state = AuthState(
            isAuthenticated: true,
            isLoading: false,
            user: user,
          );
          return true;
        }

        // If register does not return tokens, perform login directly
        return await login(email: email, password: password);
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Registration failed.',
      );
      return false;
    } on DioException catch (e) {
      final message = e.response?.data?['detail'] ?? 'Registration failed.';
      state = state.copyWith(
        isLoading: false,
        errorMessage: message.toString(),
      );
      return false;
    }
  }

  /// Fetch user profile from GET /users/me
  Future<AuthUser?> _fetchCurrentUser() async {
    try {
      final response = await _apiClient.get('/users/me');
      if (response.statusCode == 200 && response.data != null) {
        return AuthUser.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {
      // Fall through to return null
    }
    return null;
  }

  /// Update user profile details
  Future<bool> updateProfile({
    String? displayName,
    String? phone,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/users/me',
        data: {
          if (displayName != null) 'display_name': displayName.trim(),
          if (phone != null) 'phone': phone.trim(),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        state = state.copyWith(
          user: AuthUser.fromJson(response.data as Map<String, dynamic>),
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sign out and clear stored session tokens
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _apiClient.clearTokens();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}

/// Global Riverpod Provider for authentication state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ApiClient.instance);
});