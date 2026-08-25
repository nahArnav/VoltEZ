import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile_model.dart';

class ProfileService {
  static const String baseUrl = 'https://api.yourdomain.com/v1';

  // In production, fetch auth token from FlutterSecureStorage / SharedPreferences
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    // 'Authorization': 'Bearer <YOUR_TOKEN>',
  };

  Future<UserProfile> fetchProfile() async {
    final uri = Uri.parse('$baseUrl/user/profile');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return UserProfile.fromJson(data);
    } else {
      throw Exception('Failed to load profile (${response.statusCode})');
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
    required String businessName,
  }) async {
    final uri = Uri.parse('$baseUrl/user/profile');
    final response = await http.put(
      uri,
      headers: _headers,
      body: json.encode({
        'name': name,
        'email': email,
        'phone': phone,
        'businessName': businessName,
      }),
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }

  Future<bool> updatePreferences(UserPreferences preferences) async {
    final uri = Uri.parse('$baseUrl/user/preferences');
    final response = await http.patch(
      uri,
      headers: _headers,
      body: json.encode(preferences.toJson()),
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }

  Future<bool> logout() async {
    final uri = Uri.parse('$baseUrl/auth/logout');
    try {
      final response = await http.post(uri, headers: _headers);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return true; // Allow client logout even if backend call fails
    }
  }
}