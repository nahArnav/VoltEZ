import 'package:flutter_test/flutter_test.dart';
import 'package:voltez_frontend/core/network/server_config.dart';

void main() {
  test('normalizes the deployed Render root URL', () {
    expect(
      ServerConfig.normalizeUrl('https://voltez-sb0w.onrender.com/'),
      'https://voltez-sb0w.onrender.com/api/v1',
    );
  });

  test('does not duplicate an existing API prefix', () {
    expect(
      ServerConfig.normalizeUrl(
        'https://voltez-sb0w.onrender.com/api/v1/',
      ),
      'https://voltez-sb0w.onrender.com/api/v1',
    );
  });
}
