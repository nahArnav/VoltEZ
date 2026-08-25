import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/models/models.dart';

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
    this.originName,
    this.destinationName,
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
  final String? originName;
  final String? destinationName;

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
      };
}

/// Single recommendation item returned by the backend.
class RouteRecommendationResult {
  const RouteRecommendationResult({
    required this.charger,
    required this.reason,
    required this.estimatedCost,
    required this.estimatedTimeMinutes,
    required this.confidenceScore,
    this.detourMinutes = 0,
    this.predictedWaitMinutes = 0,
    this.reliabilityScore = 0.0,
    this.connectorCompatible = true,
    this.factors = const [],
  });

  final Charger charger;
  final String reason;
  final double estimatedCost;
  final int estimatedTimeMinutes;
  final double confidenceScore;
  final int detourMinutes;
  final int predictedWaitMinutes;
  final double reliabilityScore;
  final bool connectorCompatible;
  final List<RecommendationReason> factors;

  /// Parse from the JSON contract returned by POST /routes/recommendations.
  factory RouteRecommendationResult.fromJson(Map<String, dynamic> json) {
    final chargerJson = json['charger'] as Map<String, dynamic>;
    return RouteRecommendationResult(
      charger: Charger.fromJson(chargerJson),
      reason: json['reason'] as String? ?? '',
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0,
      estimatedTimeMinutes: json['estimatedTimeMinutes'] as int? ?? 0,
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0,
      detourMinutes: json['detourMinutes'] as int? ?? 0,
      predictedWaitMinutes: json['predictedWaitMinutes'] as int? ?? 0,
      reliabilityScore:
          (json['reliabilityScore'] as num?)?.toDouble() ?? 0.0,
      connectorCompatible: json['connectorCompatible'] as bool? ?? true,
    );
  }
}

/// ─── Abstract Service ───────────────────────────────────────────────────────

/// Abstraction boundary for route recommendations.
///
/// Consume this interface everywhere in the app. Swap the implementation
/// at the DI root — [LiveRouteRecommendationApi] for real backend,
/// [MockRouteRecommendationApi] for offline / test builds.
abstract class RouteRecommendationApi {
  /// Fetch route-aware charging stop recommendations.
  ///
  /// Returns results sorted by [confidenceScore] descending.
  Future<List<RouteRecommendationResult>> getRecommendations(
    RouteRecommendationRequest request,
  );
}

/// ─── Live (Dio) Implementation ──────────────────────────────────────────────

/// Live implementation backed by [ApiService].
/// Wire this in once the backend POST /routes/recommendations is ready.
class LiveRouteRecommendationApi implements RouteRecommendationApi {
  LiveRouteRecommendationApi(this._api);

  // ignore: unused_field
  final dynamic _api;

  @override
  Future<List<RouteRecommendationResult>> getRecommendations(
    RouteRecommendationRequest request,
  ) async {
    // TODO: Wire to _api.getRouteRecommendations(...) once backend is live.
    throw UnimplementedError(
      'LiveRouteRecommendationApi is not connected yet. '
      'Use MockRouteRecommendationApi for development.',
    );
  }
}

/// ─── Mock Implementation ────────────────────────────────────────────────────

/// Mock adapter returning realistic per-charger recommendations.
///
/// All cost / time / detour / wait / reliability values are computed
/// dynamically from the request's SOC, vehicle capacity, and price-per-kWh.
class MockRouteRecommendationApi implements RouteRecommendationApi {
  @override
  Future<List<RouteRecommendationResult>> getRecommendations(
    RouteRecommendationRequest request,
  ) async {
    // Simulate network + analysis latency
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    final neededKwh = request.batteryCapacityKwh *
        (request.currentSOC - request.reserveSOC) /
        100;

    final isCCS = request.connectorType == 'ccs2';

    final mockResults = [
      _buildRecommendation1(request, neededKwh, isCCS),
      _buildRecommendation2(request, neededKwh, isCCS),
      _buildRecommendation3(request, neededKwh, isCCS),
    ];

    mockResults.sort(
      (a, b) => b.confidenceScore.compareTo(a.confidenceScore),
    );
    return mockResults;
  }

  // ─── Recommendation 1: Phoenix Mall — Best Overall ───

  RouteRecommendationResult _buildRecommendation1(
    RouteRecommendationRequest request,
    double neededKwh,
    bool isCCS,
  ) {
    final cost = neededKwh * 14;
    final chargeMin = (neededKwh / 60 * 60).round(); // 60 kW charger

    return RouteRecommendationResult(
      charger: const Charger(
        id: 1, businessId: 1,
        name: 'Phoenix Mall Charger',
        address: 'Phoenix Mall, Lower Parel, Mumbai',
        latitude: 19.0760,
        longitude: 72.8777,
        powerKw: 60,
        accessType: 'public',
        basePrice: 14,
        status: 'active',
        reliabilityScore: 0.92,
        amenities: 'WiFi,Food Court,Parking',
      ),
      reason:
          'Best balance of speed and cost for your ${request.vehicleMake} ${request.vehicleModel}.',
      estimatedCost: cost.roundToDouble(),
      estimatedTimeMinutes: chargeMin,
      confidenceScore: 0.94,
      detourMinutes: 6,
      predictedWaitMinutes: 0,
      reliabilityScore: 0.98,
      connectorCompatible: isCCS,
      factors: [
        RecommendationReason(
          icon: Icons.check_circle_rounded,
          label: 'Compatible',
          description: 'CCS2 connector matches your ${request.vehicleMake}',
          color: const Color(0xFF34D399),
        ),
        RecommendationReason(
          icon: Icons.bolt_rounded,
          label: 'Fast Charging',
          description: '60 kW DC — charges in ~$chargeMin min',
          color: const Color(0xFF00E5FF),
        ),
        RecommendationReason(
          icon: Icons.schedule_rounded,
          label: 'No Queue Expected',
          description: '3 of 4 slots currently open',
          color: const Color(0xFF34D399),
        ),
        RecommendationReason(
          icon: Icons.verified_rounded,
          label: 'High Reliability',
          description: '98% uptime over the last 30 days',
          color: const Color(0xFF34D399),
        ),
        RecommendationReason(
          icon: Icons.navigation_rounded,
          label: 'Short Detour',
          description: 'Only 6 min off your direct route',
          color: const Color(0xFF00E5FF),
        ),
        RecommendationReason(
          icon: Icons.currency_rupee,
          label: 'Fair Pricing',
          description: '₹14/kWh — competitive for this area',
          color: const Color(0xFF6366F1),
        ),
      ],
    );
  }

  // ─── Recommendation 2: Bandra Hub — Fastest ───

  RouteRecommendationResult _buildRecommendation2(
    RouteRecommendationRequest request,
    double neededKwh,
    bool isCCS,
  ) {
    final cost = neededKwh * 22;
    final chargeMin = (neededKwh / 150 * 60).round(); // 150 kW charger

    return RouteRecommendationResult(
      charger: const Charger(
        id: 5, businessId: 1,
        name: 'Bandra Hub DC Fast',
        address: 'Bandra Kurla Complex, Bandra East',
        latitude: 19.0596,
        longitude: 72.8684,
        powerKw: 150,
        accessType: 'public',
        basePrice: 22,
        status: 'active',
        reliabilityScore: 0.98,
        amenities: 'WiFi,Cafe,Parking,Restroom',
      ),
      reason: 'Fastest option — 150 kW ultra-rapid for your ${request.vehicleMake}.',
      estimatedCost: cost.roundToDouble(),
      estimatedTimeMinutes: chargeMin,
      confidenceScore: 0.87,
      detourMinutes: 11,
      predictedWaitMinutes: 3,
      reliabilityScore: 0.95,
      connectorCompatible: isCCS,
      factors: [
        RecommendationReason(
          icon: Icons.check_circle_rounded,
          label: 'Compatible',
          description: 'CCS2 and CHAdeMO — supports your vehicle',
          color: const Color(0xFF34D399),
        ),
        RecommendationReason(
          icon: Icons.bolt_rounded,
          label: 'Ultra-Rapid',
          description: '150 kW — fastest available in the area',
          color: const Color(0xFF3B82F6),
        ),
        RecommendationReason(
          icon: Icons.timer_rounded,
          label: '~3 min Wait',
          description: '1 slot occupied — brief queue expected',
          color: const Color(0xFFF59E0B),
        ),
        RecommendationReason(
          icon: Icons.verified_rounded,
          label: 'High Reliability',
          description: '95% uptime — premium maintained station',
          color: const Color(0xFF34D399),
        ),
        RecommendationReason(
          icon: Icons.navigation_rounded,
          label: '11 min Detour',
          description: 'Slightly further off-route than other options',
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  // ─── Recommendation 3: Marine Drive — Cheapest ───

  RouteRecommendationResult _buildRecommendation3(
    RouteRecommendationRequest request,
    double neededKwh,
    bool isCCS,
  ) {
    final cost = neededKwh * 10;
    final chargeMin = (neededKwh / 22 * 60).round(); // 22 kW charger

    return RouteRecommendationResult(
      charger: const Charger(
        id: 4, businessId: 1,
        name: 'Marine Drive AC Charger',
        address: 'Marine Drive, Churchgate',
        latitude: 18.9432,
        longitude: 72.8234,
        powerKw: 22,
        accessType: 'public',
        basePrice: 10,
        status: 'active',
        reliabilityScore: 0.90,
        amenities: 'Parking,AC Lounge',
      ),
      reason: 'Lowest cost option — saves ₹${((neededKwh * 22) - (neededKwh * 10)).round()} vs fastest.',
      estimatedCost: cost.roundToDouble(),
      estimatedTimeMinutes: chargeMin,
      confidenceScore: 0.91,
      detourMinutes: 8,
      predictedWaitMinutes: 0,
      reliabilityScore: 0.92,
      connectorCompatible: false, // Type 2, not CCS2
      factors: [
        RecommendationReason(
          icon: Icons.warning_amber_rounded,
          label: 'Connector Mismatch',
          description: 'Type 2 AC — requires adapter for your CCS2 vehicle',
          color: const Color(0xFFF59E0B),
        ),
        RecommendationReason(
          icon: Icons.currency_rupee,
          label: 'Lowest Cost',
          description: '₹10/kWh — cheapest within 15 km',
          color: const Color(0xFF34D399),
        ),
        RecommendationReason(
          icon: Icons.bolt_rounded,
          label: 'AC Charging',
          description: '22 kW AC — slower but gentler on battery',
          color: const Color(0xFF6366F1),
        ),
        RecommendationReason(
          icon: Icons.schedule_rounded,
          label: 'No Wait',
          description: 'All slots available right now',
          color: const Color(0xFF34D399),
        ),
        RecommendationReason(
          icon: Icons.verified_rounded,
          label: 'Good Reliability',
          description: '92% uptime — well maintained',
          color: const Color(0xFF34D399),
        ),
      ],
    );
  }
}
