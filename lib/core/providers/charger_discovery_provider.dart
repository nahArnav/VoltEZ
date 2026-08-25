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
  Set<ConnectorType> _selectedConnectors = {};
  RangeValues _powerRange = const RangeValues(7, 150);
  String _searchQuery = '';

  Set<ConnectorType> get selectedConnectors => _selectedConnectors;
  RangeValues get powerRange => _powerRange;
  String get searchQuery => _searchQuery;

  // ─── Selected Marker ───
  Charger? _selectedCharger;
  Charger? get selectedCharger => _selectedCharger;

  // ─── Filtered Chargers ───
  List<Charger> get filteredChargers {
    return _allChargers.where((c) {
      // Connector filter
      if (_selectedConnectors.isNotEmpty) {
        final hasMatchingConnector =
            c.connectors.any(_selectedConnectors.contains);
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
            !c.address.toLowerCase().contains(q)) {
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

    // In production: call ApiService.getNearbyChargers(lat, lng)
    _allChargers = [
      Charger(
        id: 'c1',
        name: 'Phoenix Mall Charger',
        address: 'Phoenix Mall, Lower Parel, Mumbai',
        latitude: 19.0760,
        longitude: 72.8777,
        powerKw: 60,
        pricePerKwh: 14,
        status: ChargerStatus.available,
        connectors: [ConnectorType.ccs2],
        amenities: ['WiFi', 'Food Court', 'Parking'],
        rating: 4.6,
        totalRatings: 234,
      ),
      Charger(
        id: 'c2',
        name: 'Highway Fast Charge',
        address: 'Mumbai-Pune Expressway, Khalapur',
        latitude: 19.0896,
        longitude: 72.8656,
        powerKw: 120,
        pricePerKwh: 18,
        status: ChargerStatus.available,
        connectors: [ConnectorType.ccs2, ConnectorType.chademo],
        amenities: ['Restroom', 'Cafe'],
        rating: 4.2,
        totalRatings: 156,
      ),
      Charger(
        id: 'c3',
        name: 'Tech Park Station',
        address: 'Infosys Campus, Airoli',
        latitude: 19.0596,
        longitude: 72.8295,
        powerKw: 30,
        pricePerKwh: 11,
        status: ChargerStatus.busy,
        connectors: [ConnectorType.type2],
        amenities: ['WiFi'],
        rating: 4.8,
        totalRatings: 89,
      ),
      Charger(
        id: 'c4',
        name: 'Marine Drive AC Charger',
        address: 'Marine Drive, Churchgate',
        latitude: 18.9432,
        longitude: 72.8234,
        powerKw: 22,
        pricePerKwh: 10,
        status: ChargerStatus.available,
        connectors: [ConnectorType.type2],
        amenities: ['Parking', 'AC Lounge'],
        rating: 4.5,
        totalRatings: 312,
      ),
      Charger(
        id: 'c5',
        name: 'Bandra Hub DC Fast',
        address: 'Bandra Kurla Complex, Bandra East',
        latitude: 19.0596,
        longitude: 72.8684,
        powerKw: 150,
        pricePerKwh: 22,
        status: ChargerStatus.available,
        connectors: [ConnectorType.ccs2, ConnectorType.chademo],
        amenities: ['WiFi', 'Cafe', 'Parking', 'Restroom'],
        rating: 4.9,
        totalRatings: 501,
      ),
      Charger(
        id: 'c6',
        name: 'Thane Station AC',
        address: 'Thane West, near Viviana Mall',
        latitude: 19.1896,
        longitude: 72.9596,
        powerKw: 7,
        pricePerKwh: 8,
        status: ChargerStatus.busy,
        connectors: [ConnectorType.type2],
        amenities: ['Parking'],
        rating: 4.1,
        totalRatings: 67,
      ),
      Charger(
        id: 'c7',
        name: 'Navi Mumbai DC',
        address: 'Vashi, Sector 17',
        latitude: 19.0736,
        longitude: 72.9988,
        powerKw: 60,
        pricePerKwh: 15,
        status: ChargerStatus.offline,
        connectors: [ConnectorType.ccs2],
        amenities: [],
        rating: 3.9,
        totalRatings: 42,
      ),
      Charger(
        id: 'c8',
        name: 'Andheri Express Charger',
        address: 'Andheri-Kurla Road, Andheri East',
        latitude: 19.1136,
        longitude: 72.8697,
        powerKw: 45,
        pricePerKwh: 13,
        status: ChargerStatus.available,
        connectors: [ConnectorType.ccs2, ConnectorType.type2],
        amenities: ['WiFi', 'Food Court'],
        rating: 4.3,
        totalRatings: 198,
      ),
      Charger(
        id: 'c9',
        name: 'Powai Lake Charger',
        address: 'Powai, Hiranandani Gardens',
        latitude: 19.1187,
        longitude: 72.9066,
        powerKw: 22,
        pricePerKwh: 12,
        status: ChargerStatus.available,
        connectors: [ConnectorType.type2],
        amenities: ['WiFi', 'Parking'],
        rating: 4.7,
        totalRatings: 145,
      ),
      Charger(
        id: 'c10',
        name: 'Chembur Fast DC',
        address: 'Chembur, near Diamond Garden',
        latitude: 19.0520,
        longitude: 72.8904,
        powerKw: 90,
        pricePerKwh: 16,
        status: ChargerStatus.available,
        connectors: [ConnectorType.ccs2],
        amenities: ['Cafe', 'Restroom'],
        rating: 4.4,
        totalRatings: 210,
      ),
      Charger(
        id: 'c11',
        name: 'Dadar TT Circle',
        address: 'Dadar TT Circle, Dadar West',
        latitude: 19.0176,
        longitude: 72.8434,
        powerKw: 15,
        pricePerKwh: 9,
        status: ChargerStatus.busy,
        connectors: [ConnectorType.type2],
        amenities: [],
        rating: 3.8,
        totalRatings: 55,
      ),
      Charger(
        id: 'c12',
        name: 'Goregaon Film City',
        address: 'Film City Road, Goregaon East',
        latitude: 19.1664,
        longitude: 72.8526,
        powerKw: 60,
        pricePerKwh: 14,
        status: ChargerStatus.available,
        connectors: [ConnectorType.ccs2, ConnectorType.type2],
        amenities: ['WiFi', 'Parking', 'AC Lounge'],
        rating: 4.6,
        totalRatings: 278,
      ),
      Charger(
        id: 'c13',
        name: 'Mulund East Hub',
        address: 'Mulund East, nearMarket Garden',
        latitude: 19.1628,
        longitude: 72.9522,
        powerKw: 30,
        pricePerKwh: 11,
        status: ChargerStatus.offline,
        connectors: [ConnectorType.type2],
        amenities: ['Parking'],
        rating: 4.0,
        totalRatings: 88,
      ),
      Charger(
        id: 'c14',
        name: 'Juhu Beach Charger',
        address: 'Juhu Tara Road, Juhu',
        latitude: 19.1330,
        longitude: 72.8260,
        powerKw: 22,
        pricePerKwh: 12,
        status: ChargerStatus.available,
        connectors: [ConnectorType.type2],
        amenities: ['WiFi', 'Cafe'],
        rating: 4.5,
        totalRatings: 189,
      ),
      Charger(
        id: 'c15',
        name: 'Colaba Express DC',
        address: 'Colaba Causeway, Colaba',
        latitude: 18.9154,
        longitude: 72.8264,
        powerKw: 45,
        pricePerKwh: 14,
        status: ChargerStatus.available,
        connectors: [ConnectorType.ccs2],
        amenities: ['Restroom'],
        rating: 4.2,
        totalRatings: 134,
      ),
    ];

    _chargersLoading = false;
    notifyListeners();
  }

  // ─── Filter Mutators ───
  void toggleConnector(ConnectorType type) {
    if (_selectedConnectors.contains(type)) {
      _selectedConnectors.remove(type);
    } else {
      _selectedConnectors.add(type);
    }
    notifyListeners();
  }

  void clearConnectorFilter() {
    _selectedConnectors.clear();
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
