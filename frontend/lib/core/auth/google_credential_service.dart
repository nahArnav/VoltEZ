import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Retrieves a Google ID token from Android Credential Manager.
///
/// The native Android implementation uses GoogleIdTokenCredential and returns
/// only its signed ID token. No Google client secret belongs in the app.
class GoogleCredentialService {
  const GoogleCredentialService();

  static const MethodChannel _channel = MethodChannel(
    'com.voltez.app/google_auth',
  );

  Future<String> getIdToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw PlatformException(
        code: 'unsupported_platform',
        message: 'Google sign-in is currently available on Android only.',
      );
    }

    final idToken = await _channel.invokeMethod<String>('getGoogleIdToken');
    if (idToken == null || idToken.isEmpty) {
      throw PlatformException(
        code: 'missing_id_token',
        message: 'Google did not return an ID token.',
      );
    }
    return idToken;
  }

  Future<void> clearCredentialState() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('clearGoogleCredentialState');
  }
}
