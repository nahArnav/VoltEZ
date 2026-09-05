import '../network/api_service.dart';

/// Backend-issued session tokens returned after a successful authentication.
class AuthTokenPair {
  const AuthTokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokenPair.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw const FormatException(
        'The authentication server did not return a complete session.',
      );
    }

    return AuthTokenPair(accessToken: accessToken, refreshToken: refreshToken);
  }
}

/// Repository boundary for authentication exchanges with the VoltEZ backend.
class AuthRepository {
  const AuthRepository(this._api);

  final ApiService _api;

  Future<AuthTokenPair> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    final response = await _api.googleLogin(idToken: idToken, role: role);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid authentication response.');
    }
    return AuthTokenPair.fromJson(data);
  }
}
