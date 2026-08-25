import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/models/models.dart';
import '../network/route_recommendation_api.dart';

/// Manages the full route-planner flow:
/// origin → destination → vehicle/SOC → find → top-3 recommendations.
///
/// Uses [RouteRecommendationApi] for all backend calls.
/// Inject [MockRouteRecommendationApi] for dev/testing,
/// swap to [LiveRouteRecommendationApi] when the backend is live.
class RoutePlannerProvider extends ChangeNotifier {
  RoutePlannerProvider({RouteRecommendationApi? recommendationApi})
      : _api = recommendationApi ?? MockRouteRecommendationApi();

  final RouteRecommendationApi _api;

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
      _destinationName.isNotEmpty &&
      _selectedVehicle != null;

  // ─── Mock Vehicles (match backend Vehicle schema) ───
  final List<Vehicle> availableVehicles = const [
    Vehicle(
      id: 1, userId: 1, make: 'Tata', model: 'Nexon EV',
      batteryKwh: 40.5, connectorTypes: ['CCS2'],
    ),
    Vehicle(
      id: 2, userId: 1, make: 'MG', model: 'ZS EV',
      batteryKwh: 50.3, connectorTypes: ['CCS2'],
    ),
    Vehicle(
      id: 3, userId: 1, make: 'Hyundai', model: 'Ioniq 5',
      batteryKwh: 58.0, connectorTypes: ['CCS2'],
    ),
    Vehicle(
      id: 4, userId: 1, make: 'BYD', model: 'Atto 3',
      batteryKwh: 60.5, connectorTypes: ['CCS2'],
    ),
  ];

  // ─── Location ───
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

  // ─── Setters ───

  void setOrigin(String name, {double? lat, double? lng}) {
    _originName = name;
    _originLat = lat;
    _originLng = lng;
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
