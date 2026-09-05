import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltez_frontend/core/auth/auth_repository.dart';
import 'package:voltez_frontend/core/network/api_service.dart';

class _RecordingApiService extends ApiService {
  String? receivedIdToken;
  String? receivedRole;

  @override
  Future<Response> googleLogin({
    required String idToken,
    required String role,
  }) async {
    receivedIdToken = idToken;
    receivedRole = role;
    return Response(
      requestOptions: RequestOptions(path: '/auth/google'),
      statusCode: 200,
      data: {
        'access_token': 'voltez-access-token',
        'refresh_token': 'voltez-refresh-token',
        'token_type': 'bearer',
      },
    );
  }
}

void main() {
  test('exchanges the Google ID token through the API service', () async {
    final api = _RecordingApiService();
    final repository = AuthRepository(api);

    final tokens = await repository.signInWithGoogle(
      idToken: 'signed-google-id-token',
      role: 'driver',
    );

    expect(api.receivedIdToken, 'signed-google-id-token');
    expect(api.receivedRole, 'driver');
    expect(tokens.accessToken, 'voltez-access-token');
    expect(tokens.refreshToken, 'voltez-refresh-token');
  });
}
