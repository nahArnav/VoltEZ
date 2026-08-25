import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/models/models.dart';

/// Charger discovery state + filtering logic.
/// Supplies nearby station data, GPS location, connector/power filters,
/// and selected-marker state for the map screen.
class ChargerDiscoveryProvider extends ChangeNotifier {
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

  List<Charger> get allChargers => _allChargers;
  bool get chargersLoading => _chargersLoading;

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
    _loadMockChargers();
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
  void _loadMockChargers() {
    _chargersLoading = true;
    notifyListeners();

    // In production: call ApiService.getNearbyChargers(latitude, longitude)
    // Mock chargers use backend-aligned field names.
    _allChargers = [
      const Charger(id: 1, businessId: 1, name: 'Phoenix Mall Charger', address: 'Phoenix Mall, Lower Parel, Mumbai', latitude: 19.0760, longitude: 72.8777, powerKw: 60, accessType: 'public', basePrice: 14, status: 'active', reliabilityScore: 0.92, amenities: 'WiFi,Food Court,Parking'),
      const Charger(id: 2, businessId: 1, name: 'Highway Fast Charge', address: 'Mumbai-Pune Expressway, Khalapur', latitude: 19.0896, longitude: 72.8656, powerKw: 120, accessType: 'public', basePrice: 18, status: 'active', reliabilityScore: 0.84, amenities: 'Restroom,Cafe'),
      const Charger(id: 3, businessId: 1, name: 'Tech Park Station', address: 'Infosys Campus, Airoli', latitude: 19.0596, longitude: 72.8295, powerKw: 30, accessType: 'public', basePrice: 11, status: 'active', reliabilityScore: 0.96, amenities: 'WiFi'),
      const Charger(id: 4, businessId: 1, name: 'Marine Drive AC Charger', address: 'Marine Drive, Churchgate', latitude: 18.9432, longitude: 72.8234, powerKw: 22, accessType: 'public', basePrice: 10, status: 'active', reliabilityScore: 0.90, amenities: 'Parking,AC Lounge'),
      const Charger(id: 5, businessId: 1, name: 'Bandra Hub DC Fast', address: 'Bandra Kurla Complex, Bandra East', latitude: 19.0596, longitude: 72.8684, powerKw: 150, accessType: 'public', basePrice: 22, status: 'active', reliabilityScore: 0.98, amenities: 'WiFi,Cafe,Parking,Restroom'),
      const Charger(id: 6, businessId: 1, name: 'Thane Station AC', address: 'Thane West, near Viviana Mall', latitude: 19.1896, longitude: 72.9596, powerKw: 7, accessType: 'public', basePrice: 8, status: 'active', reliabilityScore: 0.82, amenities: 'Parking'),
      const Charger(id: 7, businessId: 1, name: 'Navi Mumbai DC', address: 'Vashi, Sector 17', latitude: 19.0736, longitude: 72.9988, powerKw: 60, accessType: 'public', basePrice: 15, status: 'inactive', reliabilityScore: 0.78, amenities: ''),
      const Charger(id: 8, businessId: 1, name: 'Andheri Express Charger', address: 'Andheri-Kurla Road, Andheri East', latitude: 19.1136, longitude: 72.8697, powerKw: 45, accessType: 'public', basePrice: 13, status: 'active', reliabilityScore: 0.86, amenities: 'WiFi,Food Court'),
      const Charger(id: 9, businessId: 1, name: 'Powai Lake Charger', address: 'Powai, Hiranandani Gardens', latitude: 19.1187, longitude: 72.9066, powerKw: 22, accessType: 'public', basePrice: 12, status: 'active', reliabilityScore: 0.94, amenities: 'WiFi,Parking'),
      const Charger(id: 10, businessId: 1, name: 'Chembur Fast DC', address: 'Chembur, near Diamond Garden', latitude: 19.0520, longitude: 72.8904, powerKw: 90, accessType: 'public', basePrice: 16, status: 'active', reliabilityScore: 0.88, amenities: 'Cafe,Restroom'),
      const Charger(id: 11, businessId: 1, name: 'Dadar TT Circle', address: 'Dadar TT Circle, Dadar West', latitude: 19.0176, longitude: 72.8434, powerKw: 15, accessType: 'public', basePrice: 9, status: 'active', reliabilityScore: 0.76, amenities: ''),
      const Charger(id: 12, businessId: 1, name: 'Goregaon Film City', address: 'Film City Road, Goregaon East', latitude: 19.1664, longitude: 72.8526, powerKw: 60, accessType: 'public', basePrice: 14, status: 'active', reliabilityScore: 0.92, amenities: 'WiFi,Parking,AC Lounge'),
      const Charger(id: 13, businessId: 1, name: 'Mulund East Hub', address: 'Mulund East, near Market Garden', latitude: 19.1628, longitude: 72.9522, powerKw: 30, accessType: 'public', basePrice: 11, status: 'inactive', reliabilityScore: 0.80, amenities: 'Parking'),
      const Charger(id: 14, businessId: 1, name: 'Juhu Beach Charger', address: 'Juhu Tara Road, Juhu', latitude: 19.1330, longitude: 72.8260, powerKw: 22, accessType: 'public', basePrice: 12, status: 'active', reliabilityScore: 0.90, amenities: 'WiFi,Cafe'),
      const Charger(id: 15, businessId: 1, name: 'Colaba Express DC', address: 'Colaba Causeway, Colaba', latitude: 18.9154, longitude: 72.8264, powerKw: 45, accessType: 'public', basePrice: 14, status: 'active', reliabilityScore: 0.84, amenities: 'Restroom'),
    ];

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
