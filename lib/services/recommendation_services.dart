import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';

class RecommendationService {
  // Replace with your actual backend base URL
  static const String baseUrl = 'https://api.yourdomain.com/v1';

  Future<List<Recommendation>> fetchRecommendations() async {
    final uri = Uri.parse('$baseUrl/recommendations');
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Recommendation.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load recommendations (${response.statusCode})');
    }
  }

  Future<bool> updateStatus(String id, String status, {double? updatedPrice}) async {
    final uri = Uri.parse('$baseUrl/recommendations/$id/status');
    final payload = {
      'status': status,
      if (updatedPrice != null) 'price': updatedPrice,
    };

    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }
}