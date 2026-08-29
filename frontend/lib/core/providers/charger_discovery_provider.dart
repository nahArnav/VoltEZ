import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../network/api_service.dart';
import '../../shared/models/models.dart';

/// Charger discovery state + filtering logic.
/// Supplies nearby station data, GPS location, connector/power filters,
/// and selected-marker state for the map screen.
class ChargerDiscoveryProvider extends ChangeNotifier {
  ChargerDiscoveryProvider({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  // ─── Location ───
  Position? _currentPosition;
  bool _locationLoading = false;
  String? _locationError;

  Position? get currentPosition => _currentPosition;
  bool get locationLoading => _locationLoading;
  String? get locationError => _locationError;

  // ─── Chargers ───
  List<Charger> _allChargers = [];
  bool _chargersLoading = false;
  String? _chargersError;

  List<Charger> get allChargers => _allChargers;
  bool get chargersLoading => _chargersLoading;
  String? get chargersError => _chargersError;

  // ─── Filters ───
  final Set<String> _selectedConnectorStrings = {};
  RangeValues _powerRange = const RangeValues(7, 150);
  String _searchQuery = '';

  Set<String> get selectedConnectors => _selectedConnectorStrings;
  RangeValues get powerRange => _powerRange;
  String get searchQuery => _searchQuery;

  // ─── Selected Marker ───
  Charger? _selectedCharger;
  Charger? get selectedCharger => _selectedCharger;

  // ─── Filtered Chargers ───
  List<Charger> get filteredChargers {
    return _allChargers.where((c) {
      // Connector filter
      if (_selectedConnectorStrings.isNotEmpty) {
        final hasMatchingConnector = c.connectorTypes
            .any(_selectedConnectorStrings.contains);
        if (!hasMatchingConnector) return false;
      }

      // Power range filter
      if (c.powerKw < _powerRange.start || c.powerKw > _powerRange.end) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!c.name.toLowerCase().contains(q) &&
            !(c.address ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ─── Init ───
  Future<void> init() async {
    await _fetchLocation();
    await fetchNearbyChargers();
  }

  // ─── Location ───
  Future<void> _fetchLocation() async {
    _locationLoading = true;
    _locationError = null;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationError = 'Location services are disabled';
        _locationLoading = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationError = 'Location permission denied';
          _locationLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _locationError = 'Location permission permanently denied';
        _locationLoading = false;
        notifyListeners();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      _locationError = e.toString();
    }

    _locationLoading = false;
    notifyListeners();
  }

  Future<void> refreshLocation() async => _fetchLocation();

  // ─── Chargers ───
  Future<void> fetchNearbyChargers() async {
    if (_currentPosition == null) {
      _chargersError = 'Location not available';
      notifyListeners();
      return;
    }

    _chargersLoading = true;
    _chargersError = null;
    notifyListeners();

    try {
      final response = await _api.getNearbyChargers(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusMeters: 10000,
      );

      final data = response.data;
      if (data is List) {
        _allChargers = data
            .map((json) => Charger.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _allChargers = [];
      }

      _chargersLoading = false;
      _chargersError = null;
    } catch (e) {
      // If the backend is unreachable, fall back to demo chargers
      // so the UI is not blank during development.
      _chargersError = e.toString();
      _allChargers = _demoChargers();
      _chargersLoading = false;
    }
    notifyListeners();
  }

  /// Refresh nearby chargers (pull-to-refresh support).
  Future<void> refreshChargers() async {
    await _fetchLocation();
    await fetchNearbyChargers();
  }

  /// Calculate distance from user to a charger in km.
  double distanceTo(Charger charger) {
    if (_currentPosition == null) return 0;
    // Haversine approximation for short distances
    const earthRadius = 6371.0;
    final dLat = _degreesToRad(charger.latitude - _currentPosition!.latitude);
    final dLon = _degreesToRad(charger.longitude - _currentPosition!.longitude);
    final a = dLat * dLat +
        math.cos(_degreesToRad(_currentPosition!.latitude)) *
            math.cos(_degreesToRad(charger.latitude)) *
            dLon * dLon;
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRad(double degrees) => degrees * math.pi / 180;

  /// Demo chargers shown when backend is unreachable.
  List<Charger> _demoChargers() {
    return [
      const Charger(id: 1, businessId: 1, name: 'Phoenix Mall Charger', address: 'Phoenix Mall, Lower Parel, Mumbai', latitude: 19.0760, longitude: 72.8777, powerKw: 60, accessType: 'public', basePrice: 14, status: 'active', reliabilityScore: 0.92, amenities: 'WiFi,Food Court,Parking'),
      const Charger(id: 2, businessId: 1, name: 'Highway Fast Charge', address: 'Mumbai-Pune Expressway, Khalapur', latitude: 19.0896, longitude: 72.8656, powerKw: 120, accessType: 'public', basePrice: 18, status: 'active', reliabilityScore: 0.84, amenities: 'Restroom,Cafe'),
      const Charger(id: 3, businessId: 1, name: 'Tech Park Station', address: 'Infosys Campus, Airoli', latitude: 19.0596, longitude: 72.8295, powerKw: 30, accessType: 'public', basePrice: 11, status: 'active', reliabilityScore: 0.96, amenities: 'WiFi'),
    ];
  }

  // ─── Filter Mutators ───
  void toggleConnector(String connectorType) {
    if (_selectedConnectorStrings.contains(connectorType)) {
      _selectedConnectorStrings.remove(connectorType);
    } else {
      _selectedConnectorStrings.add(connectorType);
    }
    notifyListeners();
  }

  void clearConnectorFilter() {
    _selectedConnectorStrings.clear();
    notifyListeners();
  }

  void setPowerRange(RangeValues range) {
    _powerRange = range;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ─── Marker Selection ───
  void selectCharger(Charger? charger) {
    _selectedCharger = charger;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCharger = null;
    notifyListeners();
  }
}
