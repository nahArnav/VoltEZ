import 'package:flutter/material.dart';
import '../../shared/models/models.dart';
import 'api_service.dart';

/// ─── Request / Response DTOs ────────────────────────────────────────────────

/// Request payload for POST /routes/recommendations.
class RouteRecommendationRequest {
  const RouteRecommendationRequest({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.batteryCapacityKwh,
    required this.connectorType,
    required this.currentSOC,
    required this.reserveSOC,
    required this.preference,
    this.vehicleId = '',
    this.originName,
    this.destinationName,
    this.routeDistanceKm,
    this.routeDurationMinutes,
    this.routePolyline,
  });

  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String vehicleMake;
  final String vehicleModel;
  final double batteryCapacityKwh;
  final String connectorType;
  final double currentSOC;
  final double reserveSOC;
  final String preference;
  final String vehicleId;
  final String? originName;
  final String? destinationName;
  final double? routeDistanceKm;
  final int? routeDurationMinutes;
  final String? routePolyline;

  /// Serialize to JSON for the Dio request body.
  Map<String, dynamic> toJson() => {
    'origin': {
      'lat': originLat,
      'lng': originLng,
      if (originName != null) 'name': originName,
    },
    'destination': {
      'lat': destLat,
      'lng': destLng,
      if (destinationName != null) 'name': destinationName,
    },
    'vehicle': {
      'make': vehicleMake,
      'model': vehicleModel,
      'batteryCapacityKwh': batteryCapacityKwh,
      'connectorType': connectorType,
    },
    'currentSOC': currentSOC,
    'reserveSOC': reserveSOC,
    'preference': preference,
    if (routeDistanceKm != null) 'route_distance_km': routeDistanceKm,
    if (routeDurationMinutes != null)
      'route_duration_minutes': routeDurationMinutes,
    if (routePolyline != null) 'route_polyline': routePolyline,
  };
}

/// Single recommendation item returned by the backend.
class RouteRecommendationResult {
  const RouteRecommendationResult({
    required this.charger,
    required this.reason,
    required this.estimatedCost,
    this.estimatedPricePerKwh,
    required this.estimatedTimeMinutes,
    required this.confidenceScore,
    this.detourMinutes = 0,
    this.detourDistanceKm = 0,
    this.predictedWaitMinutes = 0,
    this.reliabilityScore = 0.0,
    this.connectorCompatible = true,
    this.factors = const [],
    this.probabilityUnavailable = 0,
    this.predictedDemand = 0,
    this.routeFeasible = true,
    this.estimatedTotalTripMinutes = 0,
    this.modelSources = const {},
  });

  final Charger charger;
  final String reason;
  final double estimatedCost;
  final double? estimatedPricePerKwh;
  final int estimatedTimeMinutes;
  final double confidenceScore;
  final int detourMinutes;
  final double detourDistanceKm;
  final int predictedWaitMinutes;
  final double reliabilityScore;
  final bool connectorCompatible;
  final List<RecommendationReason> factors;
  final double probabilityUnavailable;
  final double predictedDemand;
  final bool routeFeasible;
  final double estimatedTotalTripMinutes;
  final Map<String, String> modelSources;

  /// Parse from the JSON contract returned by POST /routes/recommendations.
  factory RouteRecommendationResult.fromJson(Map<String, dynamic> json) {
    final chargerJson = json['charger'] as Map<String, dynamic>;
    final charger = Charger.fromJson(chargerJson);
    return RouteRecommendationResult(
      charger: charger,
      reason: json['reason'] as String? ?? '',
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
      estimatedPricePerKwh: (json['estimated_price_per_kwh'] as num?)
          ?.toDouble(),
      estimatedTimeMinutes:
          ((json['estimated_charge_minutes'] as num?)?.toDouble() ?? 0).round(),
      confidenceScore: (json['ranking_score'] as num?)?.toDouble() ?? 0,
      detourMinutes: json['detourMinutes'] as int? ?? 0,
      detourDistanceKm: (json['estimated_detour_km'] as num?)?.toDouble() ?? 0,
      predictedWaitMinutes:
          ((json['predicted_wait_minutes'] as num?)?.toDouble() ?? 0).round(),
      reliabilityScore:
          (json['predicted_reliability'] as num?)?.toDouble() ??
          (charger.reliabilityScore > 1
              ? charger.reliabilityScore / 100
              : charger.reliabilityScore),
      connectorCompatible: json['connectorCompatible'] as bool? ?? true,
      probabilityUnavailable:
          (json['probability_unavailable'] as num?)?.toDouble() ?? 0,
      predictedDemand: (json['predicted_demand'] as num?)?.toDouble() ?? 0,
      routeFeasible: json['route_feasible'] as bool? ?? true,
      estimatedTotalTripMinutes:
          (json['estimated_total_trip_minutes'] as num?)?.toDouble() ?? 0,
      modelSources:
          (json['model_sources'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
    );
  }
}

class RouteRecommendationPayload {
  const RouteRecommendationPayload({
    required this.recommendations,
    this.routePlan,
  });

  final List<RouteRecommendationResult> recommendations;
  final OptimizedRoutePlan? routePlan;
}

/// ─── Abstract Service ───────────────────────────────────────────────────────

/// Abstraction boundary for route recommendations.
///
/// Consume this interface everywhere in the app. The DI root wires the live
/// backend implementation; tests may inject their own explicit adapter.
abstract class RouteRecommendationApi {
  /// Fetch route-aware charging stop recommendations.
  ///
  /// Returns results sorted by [confidenceScore] descending.
  Future<RouteRecommendationPayload> getRecommendations(
    RouteRecommendationRequest request,
  );
}

/// ─── Live (Dio) Implementation ──────────────────────────────────────────────

/// Live implementation backed by [ApiService].
/// Wire this in once the backend POST /routes/recommendations is ready.
class LiveRouteRecommendationApi implements RouteRecommendationApi {
  LiveRouteRecommendationApi(this._api);

  final ApiService _api;

  @override
  Future<RouteRecommendationPayload> getRecommendations(
    RouteRecommendationRequest request,
  ) async {
    final response = await _api.getRouteRecommendations(
      originLat: request.originLat,
      originLng: request.originLng,
      destinationLat: request.destLat,
      destinationLng: request.destLng,
      vehicleId: request.vehicleId,
      currentSOC: request.currentSOC,
      targetSOC: 80,
      reserveSOC: request.reserveSOC,
      preference: request.preference,
      routeDistanceKm: request.routeDistanceKm,
      routeDurationMinutes: request.routeDurationMinutes,
      routePolyline: request.routePolyline,
    );
    final body = response.data as Map<String, dynamic>;
    final rows = body['recommendations'] as List<dynamic>? ?? const [];

    final recommendations = rows.map((item) {
      final json = item as Map<String, dynamic>;
      final charger = Charger.fromJson(json['charger'] as Map<String, dynamic>);
      final reachable = json['reachable'] as bool? ?? false;
      final distance =
          (json['distance_to_charger_km'] as num?)?.toDouble() ?? 0;
      final ranking = (json['ranking_score'] as num?)?.toDouble() ?? 0;
      final detourKm = (json['estimated_detour_km'] as num?)?.toDouble() ?? 0;
      final normalizedReliability = charger.reliabilityScore > 1
          ? charger.reliabilityScore / 100
          : charger.reliabilityScore;
      final predictedReliability =
          (json['predicted_reliability'] as num?)?.toDouble() ??
          normalizedReliability;
      final predictedWait =
          ((json['predicted_wait_minutes'] as num?)?.toDouble() ?? 0).round();
      final unavailableProbability =
          (json['probability_unavailable'] as num?)?.toDouble() ?? 0;
      final predictedDemand =
          (json['predicted_demand'] as num?)?.toDouble() ?? 0;
      final routeFeasible = json['route_feasible'] as bool? ?? true;

      return RouteRecommendationResult(
        charger: charger,
        reason: !reachable
            ? 'Outside the safe range at your current state of charge.'
            : routeFeasible
            ? '${distance.toStringAsFixed(1)} km away on a battery-feasible route.'
            : 'Reachable now, but another charging stop is required to finish the trip.',
        estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
        estimatedPricePerKwh: (json['estimated_price_per_kwh'] as num?)
            ?.toDouble(),
        estimatedTimeMinutes:
            ((json['estimated_charge_minutes'] as num?)?.toDouble() ?? 0)
                .round(),
        confidenceScore: (ranking / 1000).clamp(0.0, 1.0),
        detourMinutes: (detourKm * 60 / 35).round(),
        detourDistanceKm: detourKm,
        predictedWaitMinutes: predictedWait,
        reliabilityScore: predictedReliability.clamp(0.0, 1.0),
        probabilityUnavailable: unavailableProbability,
        predictedDemand: predictedDemand,
        routeFeasible: routeFeasible,
        estimatedTotalTripMinutes:
            (json['estimated_total_trip_minutes'] as num?)?.toDouble() ?? 0,
        modelSources:
            (json['model_sources'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
        // The backend already hard-filters by connector IDs and active ports.
        connectorCompatible: true,
        factors: [
          RecommendationReason(
            icon: reachable ? Icons.route_rounded : Icons.warning_amber_rounded,
            label: reachable ? 'Reachable' : 'Low battery range',
            description:
                '${distance.toStringAsFixed(1)} km from your starting point',
            color: reachable
                ? const Color(0xFF34D399)
                : const Color(0xFFEF4444),
          ),
          RecommendationReason(
            icon: Icons.verified_rounded,
            label: 'Reliability',
            description:
                '${(predictedReliability * 100).round()}% predicted working probability',
            color: const Color(0xFF00E5FF),
          ),
          RecommendationReason(
            icon: Icons.schedule_rounded,
            label: 'Predicted wait',
            description:
                '$predictedWait min wait · ${(unavailableProbability * 100).round()}% unavailable risk',
            color: const Color(0xFFFBBF24),
          ),
          RecommendationReason(
            icon: Icons.insights_rounded,
            label: 'Demand forecast',
            description:
                '${predictedDemand.toStringAsFixed(1)} expected requests in the forecast window',
            color: const Color(0xFFA78BFA),
          ),
        ],
      );
    }).toList();
    final routePlan = body['route_plan'];
    return RouteRecommendationPayload(
      recommendations: recommendations,
      routePlan: routePlan is Map<String, dynamic>
          ? OptimizedRoutePlan.fromJson(routePlan)
          : null,
    );
  }
}
