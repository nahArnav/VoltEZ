import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../shared/models/models.dart';
import '../network/api_service.dart';
import '../network/route_recommendation_api.dart';

class LocationSuggestion {
  const LocationSuggestion({required this.label, required this.latitude, required this.longitude});
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
  List<LocationSuggestion> get originSuggestions => _originSuggestions;
  List<LocationSuggestion> get destinationSuggestions => _destinationSuggestions;

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

  Future<void> loadVehicles() async {
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
      if (_selectedVehicle == null && availableVehicles.isNotEmpty) {
        _selectedVehicle = availableVehicles.first;
      }
    } catch (error) {
      availableVehicles.clear();
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
      notifyListeners();
    } catch (_) {
      // Location fetch failed silently
    }
  }

  void setDestination(String name, {double? lat, double? lng}) {
    _destinationName = name;
    _destinationLat = lat;
    _destinationLng = lng;
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
    _destinationSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      final results = await _searchAddress(query.trim());
      if (token != _destinationSearchToken) return;
      _destinationSuggestions = results;
      notifyListeners();
    });
  }

  Future<List<LocationSuggestion>> _searchAddress(String query) async {
    try {
      final locations = await locationFromAddress(query);
      final suggestions = <LocationSuggestion>[];
      for (final location in locations.take(5)) {
        var label = query;
        try {
          final placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            label = [p.name, p.street, p.locality, p.administrativeArea]
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .join(', ');
          }
        } catch (_) {
          // Coordinate results are still valid even if reverse labelling fails.
        }
        suggestions.add(LocationSuggestion(label: label, latitude: location.latitude, longitude: location.longitude));
      }
      return suggestions;
    } catch (_) {
      return const [];
    }
  }

  void selectOriginSuggestion(LocationSuggestion suggestion) {
    _originSuggestions = const [];
    setOrigin(suggestion.label, lat: suggestion.latitude, lng: suggestion.longitude);
  }

  void selectDestinationSuggestion(LocationSuggestion suggestion) {
    _destinationSuggestions = const [];
    setDestination(suggestion.label, lat: suggestion.latitude, lng: suggestion.longitude);
  }

  /// Resolve typed origin/destination names with the platform geocoder.
  /// Failure is surfaced to the UI; no synthetic coordinates are sent.
  Future<void> resolveTypedLocations() async {
    final failures = <String>[];

    if (!_usingCurrentLocation &&
        (_originLat == null || _originLng == null) &&
        _originName.trim().isNotEmpty) {
      try {
        final matches = await locationFromAddress(_originName.trim());
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
        final matches = await locationFromAddress(_destinationName.trim());
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
      );

      final results = await _api.getRecommendations(request);

      _recommendations = results
          .map(
            (r) => ChargerRecommendation(
              charger: r.charger,
              reason: r.reason,
              estimatedCost: r.estimatedCost,
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
