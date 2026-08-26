import 'dart:convert';
import '../services/api_client.dart';
import '../models/recommendation.dart';

/// Recommendation service using the centralized ApiClient with JWT auth.
class RecommendationService {
  final _api = ApiClient.instance;

  /// Fetch charging recommendations based on location and vehicle.
  /// Backend expects POST /recommendations/ with a JSON body.
  Future<List<Recommendation>> fetchRecommendations({
    required double latitude,
    required double longitude,
    required String vehicleId,
    required double currentSoc,
    required double targetSoc,
    double radiusMeters = 5000.0,
    double reserveSoc = 0.1,
  }) async {
    final response = await _api.post(
      '/recommendations/',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'vehicle_id': vehicleId,
        'current_soc': currentSoc,
        'target_soc': targetSoc,
        'radius_meters': radiusMeters,
        'reserve_soc': reserveSoc,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final List<dynamic> data =
          (response.data['recommendations'] as List<dynamic>?) ?? [];
      return data
          .map((item) => Recommendation.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'Failed to load recommendations (${response.statusCode})');
    }
  }
}