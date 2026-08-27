import 'dart:convert';
import '../services/api_client.dart';
import '../models/user_profile_model.dart';

/// Profile service using the centralized ApiClient with JWT auth.
class ProfileService {
  final _api = ApiClient.instance;

  Future<UserProfile> fetchProfile() async {
    final response = await _api.get('/users/me');

    if (response.statusCode == 200 && response.data != null) {
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw Exception('Failed to load profile (${response.statusCode})');
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (phone != null) payload['phone'] = phone;

    final response = await _api.patch('/users/me', data: payload);
    return response.statusCode == 200;
  }

  Future<void> logout() async {
    // Clear stored tokens — no backend logout endpoint exists
    await _api.clearTokens();
  }
}