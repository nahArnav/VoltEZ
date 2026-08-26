import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/models/models.dart';
import '../network/api_service.dart';

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
    await loadNearbyChargers();
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

  Future<void> refreshLocation() async {
    await _fetchLocation();
    await loadNearbyChargers();
  }

  // ─── Chargers ───
  Future<void> loadNearbyChargers() async {
    _chargersLoading = true;
    _chargersError = null;
    notifyListeners();

    // Pune is the project pilot and also provides a deterministic fallback when
    // browser location permission is unavailable.
    final latitude = _currentPosition?.latitude ?? 18.5204;
    final longitude = _currentPosition?.longitude ?? 73.8567;

    try {
      final response = await _api.getNearbyChargers(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: 25000,
      );
      _allChargers = (response.data as List<dynamic>)
          .map((item) => Charger.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (error) {
      _allChargers = [];
      _chargersError = error.toString();
    }

    _chargersLoading = false;
    notifyListeners();
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
