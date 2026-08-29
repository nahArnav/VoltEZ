import 'dart:async';
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
        final hasMatchingConnector = c.connectorTypes.any(
          _selectedConnectorStrings.contains,
        );
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

  Future<void> refreshLocation() async {
    await _fetchLocation();
    await fetchNearbyChargers();
  }

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
        _allChargers =
            data
                .map((json) => Charger.fromJson(json as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => distanceTo(a).compareTo(distanceTo(b)));
      } else {
        _allChargers = [];
      }

      _chargersLoading = false;
      _chargersError = null;
    } catch (e) {
      // Never fabricate stations when the API is unavailable. Showing a
      // fixture here can cause a driver to navigate to a charger that does
      // not exist and is especially dangerous when booking is enabled.
      _chargersError = e.toString();
      _allChargers = [];
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
    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          charger.latitude,
          charger.longitude,
        ) /
        1000;
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
