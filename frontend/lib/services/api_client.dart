import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config.dart';

/// Singleton Dio HTTP client for the VoltEZ Platform API.
///
/// Features:
/// - Persistent secure storage via [FlutterSecureStorage]
/// - Automatic JWT Bearer authorization injection
/// - Request locking queue with automatic POST /auth/refresh on 401
/// - Failed request replay after token refresh
/// - Request/response debug logging in development mode
class ApiClient {
  static const String _accessTokenKey = 'voltez_access_token';
  static const String _refreshTokenKey = 'voltez_refresh_token';

  late final Dio _dio;
  late final Dio _refreshDio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  VoidCallback? _onUnauthorized;

  ApiClient._internal() {
    final baseOptions = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio = Dio(baseOptions);

    // Dedicated Dio instance for refresh calls to prevent recursive interceptor loops
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  static final ApiClient instance = ApiClient._internal();

  Dio get dio => _dio;

  void _setupInterceptors() {
    // QueuedInterceptorsWrapper locks parallel incoming requests while token refresh executes
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await _storage.read(key: _accessTokenKey);
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final isRefreshRequest = error.requestOptions.path.contains('/auth/refresh');
            if (isRefreshRequest) {
              await _handleAuthFailure();
              return handler.next(error);
            }

            final refreshToken = await _storage.read(key: _refreshTokenKey);
            if (refreshToken == null || refreshToken.isEmpty) {
              await _handleAuthFailure();
              return handler.next(error);
            }

            try {
              // Attempt token refresh with the backend
              final response = await _refreshDio.post(
                '/auth/refresh',
                data: {'refresh_token': refreshToken},
              );

              if (response.statusCode == 200 && response.data != null) {
                final newAccessToken = response.data['access_token'] as String;
                final newRefreshToken = response.data['refresh_token'] as String?;

                await saveTokens(
                  accessToken: newAccessToken,
                  refreshToken: newRefreshToken ?? refreshToken,
                );

                // Replay the original failed request with the new access token
                final retryOptions = error.requestOptions;
                retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

                final clonedResponse = await _dio.fetch(retryOptions);
                return handler.resolve(clonedResponse);
              } else {
                await _handleAuthFailure();
                return handler.next(error);
              }
            } catch (refreshError) {
              await _handleAuthFailure();
              return handler.next(error);
            }
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => debugPrint('[VoltEZ-API] $o'),
        ),
      );
    }
  }

  // ── Auth & Token Lifecycle Management ──────────────────────

  /// Save access and refresh tokens in secure storage.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  /// Check whether an active access token is currently persisted.
  Future<bool> get isAuthenticated async {
    final token = await _storage.read(key: _accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Retrieve the current access token.
  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  /// Retrieve the current refresh token.
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  /// Purge all stored tokens.
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  /// Register redirect/navigation action for unrecoverable 401s (e.g. navigate to login).
  void onUnauthorized(VoidCallback callback) {
    _onUnauthorized = callback;
  }

  Future<void> _handleAuthFailure() async {
    await clearTokens();
    _onUnauthorized?.call();
  }

  // ── Convenience Typed HTTP Methods ─────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
}