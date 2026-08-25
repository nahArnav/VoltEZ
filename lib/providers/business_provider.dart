import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

// ── Models ──────────────────────────────────────────────────

class BusinessProfile {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String category;

  const BusinessProfile({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
    );
  }
}

class ChargerPort {
  final String id;
  final String portNumber;
  final String connectorType;
  final double maxPowerKw;
  final String status;

  const ChargerPort({
    required this.id,
    required this.portNumber,
    required this.connectorType,
    required this.maxPowerKw,
    required this.status,
  });

  factory ChargerPort.fromJson(Map<String, dynamic> json) {
    return ChargerPort(
      id: json['id']?.toString() ?? '',
      portNumber: json['port_number']?.toString() ?? '1',
      connectorType: json['connector_type'] as String? ?? 'CCS2',
      maxPowerKw: (json['max_power_kw'] as num?)?.toDouble() ?? 22.0,
      status: json['status'] as String? ?? 'AVAILABLE',
    );
  }
}

class ChargerStation {
  final String id;
  final String name;
  final String status;
  final List<ChargerPort> ports;

  const ChargerStation({
    required this.id,
    required this.name,
    required this.status,
    required this.ports,
  });

  factory ChargerStation.fromJson(Map<String, dynamic> json) {
    return ChargerStation(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      ports: (json['ports'] as List<dynamic>?)
              ?.map((p) => ChargerPort.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class RevenueAnalytics {
  final double totalRevenue;
  final int totalSessions;
  final double avgDurationMinutes;
  final List<Map<String, dynamic>> dailyMetrics;

  const RevenueAnalytics({
    required this.totalRevenue,
    required this.totalSessions,
    required this.avgDurationMinutes,
    required this.dailyMetrics,
  });

  factory RevenueAnalytics.fromJson(Map<String, dynamic> json) {
    return RevenueAnalytics(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      avgDurationMinutes: (json['avg_duration_minutes'] as num?)?.toDouble() ?? 0.0,
      dailyMetrics: (json['daily_metrics'] as List<dynamic>?)
              ?.map((m) => m as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}

class PricingRecommendation {
  final String id;
  final int zoneId;
  final double recommendedDiscount;
  final String description;
  final double confidenceScore;
  final bool isAccepted;

  const PricingRecommendation({
    required this.id,
    required this.zoneId,
    required this.recommendedDiscount,
    required this.description,
    required this.confidenceScore,
    this.isAccepted = false,
  });

  factory PricingRecommendation.fromJson(Map<String, dynamic> json) {
    return PricingRecommendation(
      id: json['id']?.toString() ?? '',
      zoneId: json['zone_id'] as int? ?? 0,
      recommendedDiscount: (json['recommended_discount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      isAccepted: json['is_accepted'] as bool? ?? false,
    );
  }
}

// ── State Model ─────────────────────────────────────────────

class BusinessState {
  final bool isLoading;
  final BusinessProfile? profile;
  final List<ChargerStation> chargers;
  final RevenueAnalytics? analytics;
  final List<PricingRecommendation> recommendations;
  final String? errorMessage;

  const BusinessState({
    this.isLoading = false,
    this.profile,
    this.chargers = const [],
    this.analytics,
    this.recommendations = const [],
    this.errorMessage,
  });

  BusinessState copyWith({
    bool? isLoading,
    BusinessProfile? profile,
    List<ChargerStation>? chargers,
    RevenueAnalytics? analytics,
    List<PricingRecommendation>? recommendations,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BusinessState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      chargers: chargers ?? this.chargers,
      analytics: analytics ?? this.analytics,
      recommendations: recommendations ?? this.recommendations,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ── Notifier ────────────────────────────────────────────────

class BusinessNotifier extends StateNotifier<BusinessState> {
  final ApiClient _apiClient;

  BusinessNotifier(this._apiClient) : super(const BusinessState());

  /// Load complete business dashboard data (profile, chargers, analytics)
  Future<void> loadDashboardData({String period = '7d'}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _apiClient.get('/businesses/me'),
        _apiClient.get('/businesses/me/chargers'),
        _apiClient.get('/businesses/me/analytics/revenue?period=$period'),
      ]);

      final profile = results[0].data != null
          ? BusinessProfile.fromJson(results[0].data as Map<String, dynamic>)
          : null;

      final chargers = (results[1].data as List<dynamic>?)
              ?.map((c) => ChargerStation.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [];

      final analytics = results[2].data != null
          ? RevenueAnalytics.fromJson(results[2].data as Map<String, dynamic>)
          : null;

      state = state.copyWith(
        isLoading: false,
        profile: profile,
        chargers: chargers,
        analytics: analytics,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard data: $e',
      );
    }
  }

  /// Onboard a new business station with initial chargers
  Future<bool> createBusinessOnboarding({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String category,
    required List<Map<String, dynamic>> ports,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final businessResponse = await _apiClient.post(
        '/businesses',
        data: {
          'name': name,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'category': category,
        },
      );

      if (businessResponse.statusCode == 201 || businessResponse.statusCode == 200) {
        final businessId = businessResponse.data['id'];

        if (ports.isNotEmpty) {
          await _apiClient.post(
            '/chargers',
            data: {
              'business_id': businessId,
              'name': '$name Primary Hub',
              'ports': ports,
            },
          );
        }

        await loadDashboardData();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Onboarding submission failed: $e',
      );
      return false;
    }
  }

  /// Update active status of a charger
  Future<bool> updateChargerStatus(String chargerId, String status) async {
    try {
      final response = await _apiClient.patch(
        '/chargers/$chargerId/status',
        data: {'status': status},
      );

      if (response.statusCode == 200) {
        final updatedChargers = state.chargers.map((charger) {
          if (charger.id == chargerId) {
            return ChargerStation(
              id: charger.id,
              name: charger.name,
              status: status,
              ports: charger.ports,
            );
          }
          return charger;
        }).toList();

        state = state.copyWith(chargers: updatedChargers);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch dynamic pricing recommendations from the ML engine
  Future<void> fetchPricingRecommendations({required int zoneId}) async {
    try {
      final response = await _apiClient.get(
        '/pricing/recommendations',
        queryParameters: {'zone_id': zoneId},
      );

      if (response.statusCode == 200 && response.data != null) {
        final recs = (response.data as List<dynamic>)
            .map((r) => PricingRecommendation.fromJson(r as Map<String, dynamic>))
            .toList();
        state = state.copyWith(recommendations: recs);
      }
    } catch (_) {}
  }

  /// Accept an AI pricing recommendation
  Future<bool> acceptPricingRecommendation(String recommendationId) async {
    try {
      final response = await _apiClient.post(
        '/pricing/recommendations/$recommendationId/accept',
      );

      if (response.statusCode == 200) {
        final updatedRecs = state.recommendations.map((rec) {
          if (rec.id == recommendationId) {
            return PricingRecommendation(
              id: rec.id,
              zoneId: rec.zoneId,
              recommendedDiscount: rec.recommendedDiscount,
              description: rec.description,
              confidenceScore: rec.confidenceScore,
              isAccepted: true,
            );
          }
          return rec;
        }).toList();

        state = state.copyWith(recommendations: updatedRecs);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Query live Gemini AI Copilot
  Future<String> queryAiCopilot(String query) async {
    try {
      final response = await _apiClient.post(
        '/businesses/me/copilot-query',
        data: {'query': query},
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data['response'] as String? ?? 'No response generated.';
      }
      return 'Unable to process query at this time.';
    } catch (e) {
      return 'AI Copilot service unavailable: $e';
    }
  }
}

// ── Riverpod Provider ───────────────────────────────────────

final businessProvider =
    StateNotifierProvider<BusinessNotifier, BusinessState>((ref) {
  return BusinessNotifier(ApiClient.instance);
});