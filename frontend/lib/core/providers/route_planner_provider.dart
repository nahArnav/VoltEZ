import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/models/models.dart';
import '../network/api_service.dart';
import '../network/route_recommendation_api.dart';

/// Manages the full route-planner flow:
/// origin → destination → vehicle/SOC → find → top-3 recommendations.
///
/// Uses [RouteRecommendationApi] for all backend calls.
/// Inject [MockRouteRecommendationApi] for dev/testing,
/// swap to [LiveRouteRecommendationApi] when the backend is live.
class RoutePlannerProvider extends ChangeNotifier {
  RoutePlannerProvider({
    ApiService? api,
    RouteRecommendationApi? recommendationApi,
  })  : _apiService = api ?? ApiService(),
        _api = recommendationApi ??
            LiveRouteRecommendationApi(api ?? ApiService());

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

  bool get isRouteValid =>
      _originName.isNotEmpty &&
      _originLat != null &&
      _originLng != null &&
      _destinationName.isNotEmpty &&
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
          (response.data as List<dynamic>)
              .map((item) => Vehicle.fromJson(item as Map<String, dynamic>)),
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
    // Text geocoding is not yet backed by a configured Maps key. Keep manual
    // text entry inside the Pune pilot zone instead of sending null coordinates.
    _originLat = lat ?? 18.5204;
    _originLng = lng ?? 73.8567;
    _usingCurrentLocation = false;
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
        destLat: _destinationLat ?? 0,
        destLng: _destinationLng ?? 0,
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
          .map((r) => ChargerRecommendation(
                charger: r.charger,
                reason: r.reason,
                estimatedCost: r.estimatedCost,
                estimatedTimeMinutes: r.estimatedTimeMinutes,
                confidenceScore: r.confidenceScore,
                detourMinutes: r.detourMinutes,
                predictedWaitMinutes: r.predictedWaitMinutes,
                reliabilityScore: r.reliabilityScore,
                connectorCompatible: r.connectorCompatible,
                factors: r.factors,
              ))
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
    notifyListeners();
  }
}
