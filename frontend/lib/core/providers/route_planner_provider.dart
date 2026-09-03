import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../shared/models/models.dart';
import '../network/api_service.dart';
import '../network/route_recommendation_api.dart';
import '../utils/address_formatter.dart';

class LocationSuggestion {
  const LocationSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
  });
  final String label;
  final double latitude;
  final double longitude;
}

/// Manages the full route-planner flow:
/// origin → destination → vehicle/SOC → find → top-3 recommendations.
///
/// Uses [RouteRecommendationApi] for all backend calls.
/// The production default is the live route-recommendation adapter. Tests can
/// inject an explicit [RouteRecommendationApi] implementation.
class RoutePlannerProvider extends ChangeNotifier {
  RoutePlannerProvider({
    ApiService? api,
    RouteRecommendationApi? recommendationApi,
  }) : _apiService = api ?? ApiService(),
       _api =
           recommendationApi ?? LiveRouteRecommendationApi(api ?? ApiService());

  final RouteRecommendationApi _api;
  final ApiService _apiService;

  // ─── Route Inputs ───
  String _originName = '';
  double? _originLat;
  double? _originLng;
  bool _usingCurrentLocation = false;

  String _destinationName = '';
  double? _destinationLat;
  double? _destinationLng;

  // ─── Vehicle / SOC ───
  Vehicle? _selectedVehicle;
  double _currentSOC = 62;
  double _reserveSOC = 15;
  RecommendationPreference _preference = RecommendationPreference.balanced;

  // ─── Recommendations ───
  List<ChargerRecommendation> _recommendations = [];
  bool _isAnalyzing = false;
  bool _hasSearched = false;
  String? _analysisError;
  double? _routeDistanceKm;
  int? _routeDurationMinutes;
  bool _routeMetricsLoading = false;

  Timer? _originSearchTimer;
  Timer? _destinationSearchTimer;
  int _originSearchToken = 0;
  int _destinationSearchToken = 0;
  List<LocationSuggestion> _originSuggestions = const [];
  List<LocationSuggestion> _destinationSuggestions = const [];

  // ─── Getters ───
  String get originName => _originName;
  double? get originLat => _originLat;
  double? get originLng => _originLng;
  bool get usingCurrentLocation => _usingCurrentLocation;

  String get destinationName => _destinationName;
  double? get destinationLat => _destinationLat;
  double? get destinationLng => _destinationLng;

  Vehicle? get selectedVehicle => _selectedVehicle;
  double get currentSOC => _currentSOC;
  double get reserveSOC => _reserveSOC;
  RecommendationPreference get preference => _preference;

  List<ChargerRecommendation> get recommendations => _recommendations;
  bool get isAnalyzing => _isAnalyzing;
  bool get hasSearched => _hasSearched;
  String? get analysisError => _analysisError;
  double? get routeDistanceKm => _routeDistanceKm;
  int? get routeDurationMinutes => _routeDurationMinutes;
  bool get routeMetricsLoading => _routeMetricsLoading;
  List<LocationSuggestion> get originSuggestions => _originSuggestions;
  List<LocationSuggestion> get destinationSuggestions =>
      _destinationSuggestions;

  bool get isRouteValid =>
      _originName.isNotEmpty &&
      _originLat != null &&
      _originLng != null &&
      _destinationName.isNotEmpty &&
      _destinationLat != null &&
      _destinationLng != null &&
      _selectedVehicle != null;

  /// Whether the form has enough human-entered data to try on-device
  /// geocoding before making the recommendation request.
  bool get canAttemptSearch =>
      _originName.trim().isNotEmpty &&
      _destinationName.trim().isNotEmpty &&
      _selectedVehicle != null;

  // ─── Vehicles ───
  final List<Vehicle> availableVehicles = [];
  String? _vehiclesError;
  String? get vehiclesError => _vehiclesError;

  Future<void> loadVehicles({String? selectedVehicleId}) async {
    _vehiclesError = null;
    try {
      final response = await _apiService.getVehicles();
      availableVehicles
        ..clear()
        ..addAll(
          (response.data as List<dynamic>).map(
            (item) => Vehicle.fromJson(item as Map<String, dynamic>),
          ),
        );
      if (availableVehicles.isNotEmpty) {
        final requested = selectedVehicleId == null
            ? null
            : availableVehicles
                  .where((v) => v.id == selectedVehicleId)
                  .firstOrNull;
        if (requested != null || _selectedVehicle == null) {
          _selectedVehicle = requested ?? availableVehicles.first;
        } else {
          final refreshed = availableVehicles
              .where((v) => v.id == _selectedVehicle!.id)
              .firstOrNull;
          _selectedVehicle = refreshed ?? availableVehicles.first;
        }
      } else {
        // No saved vehicles (for example the last one was removed) — fall back
        // to the "Add your EV" state on the home screen.
        _selectedVehicle = null;
      }
    } catch (error) {
      availableVehicles.clear();
      _selectedVehicle = null;
      _vehiclesError = error.toString();
    }
    notifyListeners();
  }

  // ─── Location ───
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

  // ─── Setters ───

  void setOrigin(String name, {double? lat, double? lng}) {
    _originName = name;
    _originLat = lat;
    _originLng = lng;
    _usingCurrentLocation = false;
    _clearRouteMetrics();
    if (lat == null || lng == null) _originSuggestions = const [];
    notifyListeners();
  }

  Future<void> useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _originName = 'Current Location';
      _originLat = _currentPosition!.latitude;
      _originLng = _currentPosition!.longitude;
      _usingCurrentLocation = true;
      _clearRouteMetrics();
      notifyListeners();
    } catch (_) {
      // Location fetch failed silently
    }
  }

  void setDestination(String name, {double? lat, double? lng}) {
    _destinationName = name;
    _destinationLat = lat;
    _destinationLng = lng;
    _clearRouteMetrics();
    if (lat == null || lng == null) _destinationSuggestions = const [];
    notifyListeners();
  }

  /// Debounced platform address search used by the route form.  Suggestions
  /// carry the coordinates returned by the OS geocoder, so selecting one
  /// removes ambiguity before the backend receives a route request.
  void searchOrigin(String query) {
    _originSearchTimer?.cancel();
    final token = ++_originSearchToken;
    if (query.trim().length < 3 || _usingCurrentLocation) {
      _originSuggestions = const [];
      notifyListeners();
      return;
    }
    _originSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      final results = await _searchAddress(query.trim());
      if (token != _originSearchToken) return;
      _originSuggestions = results;
      notifyListeners();
    });
  }

  void searchDestination(String query) {
    _destinationSearchTimer?.cancel();
    final token = ++_destinationSearchToken;
    if (query.trim().length < 3) {
      _destinationSuggestions = const [];
      notifyListeners();
      return;
    }
    _destinationSearchTimer = Timer(
      const Duration(milliseconds: 350),
      () async {
        final results = await _searchAddress(query.trim());
        if (token != _destinationSearchToken) return;
        _destinationSuggestions = results;
        notifyListeners();
      },
    );
  }

  Future<List<LocationSuggestion>> _searchAddress(String query) async {
    // Prefer the backend geocoder so suggestions are ranked, labelled and
    // coordinate-backed consistently on Android, iOS and web. The platform
    // geocoder remains a local fallback for offline development.
    try {
      final response = await _apiService.searchLocations(query);
      final data = response.data;
      if (data is List && data.isNotEmpty) {
        return data
            .whereType<Map>()
            .map(
              (item) => LocationSuggestion(
                label: AddressFormatter.cleanAddressString(
                  item['display_name']?.toString() ?? query,
                ),
                latitude: (item['latitude'] as num).toDouble(),
                longitude: (item['longitude'] as num).toDouble(),
              ),
            )
            .toList();
      }
    } catch (_) {
      // Fall through to the OS geocoder when the API/provider is unavailable.
    }
    try {
      final locations = await locationFromAddress(query);
      final suggestions = <LocationSuggestion>[];
      for (final location in locations.take(5)) {
        var label = query;
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );
          if (placemarks.isNotEmpty) {
            label = AddressFormatter.formatPlacemark(placemarks.first, query);
          }
        } catch (_) {
          // Coordinate results are still valid even if reverse labelling fails.
        }
        suggestions.add(
          LocationSuggestion(
            label: label,
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      }
      return suggestions;
    } catch (_) {
      return const [];
    }
  }

  void selectOriginSuggestion(LocationSuggestion suggestion) {
    _originSuggestions = const [];
    setOrigin(
      suggestion.label,
      lat: suggestion.latitude,
      lng: suggestion.longitude,
    );
  }

  void selectDestinationSuggestion(LocationSuggestion suggestion) {
    _destinationSuggestions = const [];
    setDestination(
      suggestion.label,
      lat: suggestion.latitude,
      lng: suggestion.longitude,
    );
  }

  /// Resolve typed origin/destination names with the platform geocoder.
  /// Failure is surfaced to the UI; no synthetic coordinates are sent.
  Future<void> resolveTypedLocations() async {
    final failures = <String>[];

    if (!_usingCurrentLocation &&
        (_originLat == null || _originLng == null) &&
        _originName.trim().isNotEmpty) {
      try {
        final matches = await _searchAddress(_originName.trim());
        if (matches.isNotEmpty) {
          _originLat = matches.first.latitude;
          _originLng = matches.first.longitude;
        } else {
          failures.add('origin');
        }
      } catch (_) {
        failures.add('origin');
      }
    }

    if ((_destinationLat == null || _destinationLng == null) &&
        _destinationName.trim().isNotEmpty) {
      try {
        final matches = await _searchAddress(_destinationName.trim());
        if (matches.isNotEmpty) {
          _destinationLat = matches.first.latitude;
          _destinationLng = matches.first.longitude;
        } else {
          failures.add('destination');
        }
      } catch (_) {
        failures.add('destination');
      }
    }

    _analysisError = failures.isEmpty
        ? null
        : 'Could not locate your ${failures.join(' and ')}. Use a more specific place name or enable location services.';
    notifyListeners();
  }

  void selectVehicle(Vehicle vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  void setCurrentSOC(double value) {
    _currentSOC = value;
    notifyListeners();
  }

  void setReserveSOC(double value) {
    _reserveSOC = value;
    notifyListeners();
  }

  void setPreference(RecommendationPreference pref) {
    _preference = pref;
    notifyListeners();
  }

  // ─── Find Recommendations ───
  //
  // Builds a [RouteRecommendationRequest] from the current form state,
  // delegates to the injected [RouteRecommendationApi], and maps the
  // response into [ChargerRecommendation] objects for the UI layer.
  Future<void> findRecommendations() async {
    if (!isRouteValid) return;

    _isAnalyzing = true;
    _hasSearched = false;
    _analysisError = null;
    _recommendations = [];
    notifyListeners();

    try {
      await _loadRouteMetrics();
      final request = RouteRecommendationRequest(
        originLat: _originLat!,
        originLng: _originLng!,
        destLat: _destinationLat!,
        destLng: _destinationLng!,
        vehicleMake: _selectedVehicle!.make,
        vehicleModel: _selectedVehicle!.model,
        batteryCapacityKwh: _selectedVehicle!.batteryCapacityKwh,
        connectorType: _selectedVehicle!.primaryConnector,
        currentSOC: _currentSOC,
        reserveSOC: _reserveSOC,
        preference: _preference.name,
        originName: _originName,
        destinationName: _destinationName,
        vehicleId: _selectedVehicle!.id,
        routeDistanceKm: _routeDistanceKm,
        routeDurationMinutes: _routeDurationMinutes,
      );

      final results = await _api.getRecommendations(request);

      _recommendations = results
          .map(
            (r) => ChargerRecommendation(
              charger: r.charger,
              reason: r.reason,
              estimatedCost: r.estimatedCost,
              estimatedPricePerKwh: r.estimatedPricePerKwh,
              estimatedTimeMinutes: r.estimatedTimeMinutes,
              confidenceScore: r.confidenceScore,
              detourMinutes: r.detourMinutes,
              detourDistanceKm: r.detourDistanceKm,
              predictedWaitMinutes: r.predictedWaitMinutes,
              reliabilityScore: r.reliabilityScore,
              connectorCompatible: r.connectorCompatible,
              factors: r.factors,
            ),
          )
          .toList();
    } catch (e) {
      _analysisError = e.toString();
    }

    _isAnalyzing = false;
    _hasSearched = true;
    notifyListeners();
  }

  void _clearRouteMetrics() {
    _routeDistanceKm = null;
    _routeDurationMinutes = null;
  }

  /// Ask the backend for a driving route before ranking charging stops. The
  /// backend uses Google Routes when configured and returns a clearly-marked
  /// road-distance estimate otherwise; both are better than treating a city
  /// trip as a straight line.
  Future<void> _loadRouteMetrics() async {
    if (_originLat == null ||
        _originLng == null ||
        _destinationLat == null ||
        _destinationLng == null) {
      return;
    }
    _routeMetricsLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.computeRoute(
        originLat: _originLat!,
        originLng: _originLng!,
        destLat: _destinationLat!,
        destLng: _destinationLng!,
      );
      final data = response.data;
      if (data is Map) {
        final distance = data['distance_meters'];
        final duration = data['duration_seconds'];
        if (distance is num) _routeDistanceKm = distance.toDouble() / 1000;
        if (duration is num) {
          _routeDurationMinutes = (duration.toDouble() / 60).ceil();
        }
      }
    } catch (_) {
      // Recommendation ranking still works using the backend's documented
      // road-distance fallback when the route provider is temporarily down.
      _routeDistanceKm = null;
      _routeDurationMinutes = null;
    } finally {
      _routeMetricsLoading = false;
      notifyListeners();
    }
  }

  // ─── Reset ───
  void reset() {
    _originSearchTimer?.cancel();
    _destinationSearchTimer?.cancel();
    _originName = '';
    _originLat = null;
    _originLng = null;
    _usingCurrentLocation = false;
    _destinationName = '';
    _destinationLat = null;
    _destinationLng = null;
    _currentSOC = 62;
    _reserveSOC = 15;
    _preference = RecommendationPreference.balanced;
    _recommendations = [];
    _isAnalyzing = false;
    _hasSearched = false;
    _analysisError = null;
    _originSuggestions = const [];
    _destinationSuggestions = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _originSearchTimer?.cancel();
    _destinationSearchTimer?.cancel();
    super.dispose();
  }
}
