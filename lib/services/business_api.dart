import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BusinessApi {
  final String baseUrl;
  final String Function() getAuthToken;
  final http.Client _client;

  BusinessApi({
    required this.baseUrl,
    required this.getAuthToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${getAuthToken()}',
      };

  // GET /businesses/me
  Future<BusinessSnapshot> loadDashboard() async {
    final uri = Uri.parse('$baseUrl/businesses/me');
    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return BusinessSnapshot.fromJson(data);
    } else {
      throw Exception(
        'Failed to load dashboard data [${response.statusCode}]: ${response.body}',
      );
    }
  }

  // GET /businesses/me/analytics/revenue?period=7d|30d
  Future<RevenueAnalytics> getRevenueAnalytics({String period = '7d'}) async {
    final uri = Uri.parse('$baseUrl/businesses/me/analytics/revenue').replace(
      queryParameters: {'period': period},
    );

    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return RevenueAnalytics.fromJson(data);
    } else {
      throw Exception(
        'Failed to load revenue analytics [${response.statusCode}]: ${response.body}',
      );
    }
  }

  // POST /businesses/me/recommendations/{id}/action
  Future<void> recommendationAction(String id, String action) async {
    final uri = Uri.parse('$baseUrl/businesses/me/recommendations/$id/action');
    final response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode({'action': action}),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Failed to perform recommendation action: ${response.statusCode}',
      );
    }
  }

  // POST /businesses/me/bookings/{id}/cancel
  Future<void> cancelBooking(String id) async {
    final uri = Uri.parse('$baseUrl/businesses/me/bookings/$id/cancel');
    final response = await _client.post(uri, headers: _headers);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to cancel booking: ${response.statusCode}');
    }
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class BusinessSnapshot {
  const BusinessSnapshot({
    required this.businessName,
    required this.verification,
    required this.revenue,
    required this.utilization,
    required this.chargers,
    required this.bookings,
    required this.recommendations,
  });

  final String businessName;
  final String verification;
  final double revenue;
  final double utilization;
  final List<Charger> chargers;
  final List<Booking> bookings;
  final List<Recommendation> recommendations;

  factory BusinessSnapshot.fromJson(Map<String, dynamic> json) {
    return BusinessSnapshot(
      businessName: json['businessName'] ?? json['business_name'] ?? '',
      verification: json['verification'] ?? 'unverified',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      utilization: (json['utilization'] as num?)?.toDouble() ?? 0.0,
      chargers: (json['chargers'] as List<dynamic>?)
              ?.map((item) => Charger.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      bookings: (json['bookings'] as List<dynamic>?)
              ?.map((item) => Booking.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((item) =>
                  Recommendation.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class RevenueAnalytics {
  final String period;
  final double totalRevenue;
  final List<RevenuePoint> points;

  const RevenueAnalytics({
    required this.period,
    required this.totalRevenue,
    required this.points,
  });

  factory RevenueAnalytics.fromJson(Map<String, dynamic> json) {
    return RevenueAnalytics(
      period: json['period'] ?? '7d',
      totalRevenue: (json['total_revenue'] ?? json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      points: (json['points'] ?? json['data_points'] as List<dynamic>?)
              ?.map((e) => RevenuePoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class RevenuePoint {
  final DateTime timestamp;
  final double amount;

  const RevenuePoint({
    required this.timestamp,
    required this.amount,
  });

  factory RevenuePoint.fromJson(Map<String, dynamic> json) {
    return RevenuePoint(
      timestamp: DateTime.tryParse(json['timestamp'] ?? json['date'] ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Charger {
  const Charger({
    required this.id,
    required this.name,
    required this.power,
    required this.status,
    required this.reliability,
    required this.ports,
  });

  final String id;
  final String name;
  final int power;
  final String status;
  final double reliability;
  final List<Port> ports;

  factory Charger.fromJson(Map<String, dynamic> json) {
    return Charger(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      power: (json['power'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'unknown',
      reliability: (json['reliability'] as num?)?.toDouble() ?? 0.0,
      ports: (json['ports'] as List<dynamic>?)
              ?.map((p) => Port.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class Port {
  const Port({
    required this.name,
    required this.status,
  });

  final String name;
  final String status;

  factory Port.fromJson(Map<String, dynamic> json) {
    return Port(
      name: json['name'] ?? '',
      status: json['status'] ?? 'unknown',
    );
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.vehicle,
    required this.slot,
    required this.status,
    required this.amount,
  });

  final String id;
  final String vehicle;
  final String slot;
  final String status;
  final double amount;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? '',
      vehicle: json['vehicle'] ?? '',
      slot: json['slot'] ?? '',
      status: json['status'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.type,
    required this.title,
    required this.recommendedStartAt,
    required this.recommendedEndAt,
    required this.suggestedPrice,
    required this.forecastDemand,
    required this.nearbySupply,
    required this.predictedUtilization,
    required this.confidence,
    required this.reason,
    required this.status,
  });

  final String id;
  final String type;
  final String title;
  final String recommendedStartAt;
  final String recommendedEndAt;
  final double suggestedPrice;
  final int forecastDemand;
  final int nearbySupply;
  final double predictedUtilization;
  final double confidence;
  final String reason;
  final String status;

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      recommendedStartAt: json['recommendedStartAt'] ?? json['recommended_start_at'] ?? '',
      recommendedEndAt: json['recommendedEndAt'] ?? json['recommended_end_at'] ?? '',
      suggestedPrice: (json['suggestedPrice'] ?? json['suggested_price'] as num?)?.toDouble() ?? 0.0,
      forecastDemand: (json['forecastDemand'] ?? json['forecast_demand'] as num?)?.toInt() ?? 0,
      nearbySupply: (json['nearbySupply'] ?? json['nearby_supply'] as num?)?.toInt() ?? 0,
      predictedUtilization: (json['predictedUtilization'] ?? json['predicted_utilization'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}