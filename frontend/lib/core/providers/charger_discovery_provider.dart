import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../network/api_service.dart';
import '../../shared/models/models.dart';

class MapLocationSuggestion {
  const MapLocationSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.placeType,
    this.chargerId,
  });

  final String label;
  final double latitude;
  final double longitude;
  final String? placeType;
  final String? chargerId;
}

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
  bool _locationQueryActive = false;
  Timer? _locationSearchTimer;
  int _locationSearchToken = 0;
  List<MapLocationSuggestion> _locationSuggestions = const [];
  Future<void>? _initializationFuture;

  Set<String> get selectedConnectors => _selectedConnectorStrings;
  RangeValues get powerRange => _powerRange;
  String get searchQuery => _searchQuery;
  List<MapLocationSuggestion> get locationSuggestions => _locationSuggestions;

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
      if (_searchQuery.isNotEmpty && !_locationQueryActive) {
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
    // Home and Map can both request discovery during the same frame. Reuse
    // one in-flight initialization so the user receives a single permission
    // prompt and we do not race two nearby-charger requests.
    _initializationFuture ??= _initialize();
    await _initializationFuture;
  }

  Future<void> _initialize() async {
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
    _initializationFuture = null;
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

  /// Fetch stations around an explicitly selected place. This is separate
  /// from the device GPS position: the driver can explore a destination
  /// without pretending that their current location changed.
  Future<void> fetchChargersAt(double latitude, double longitude) async {
    _chargersLoading = true;
    _chargersError = null;
    notifyListeners();
    try {
      final response = await _api.getNearbyChargers(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: 10000,
      );
      final data = response.data;
      _allChargers = data is List
          ? data
                .map((json) => Charger.fromJson(json as Map<String, dynamic>))
                .toList()
          : [];
      _allChargers.sort(
        (a, b) =>
            Geolocator.distanceBetween(
              latitude,
              longitude,
              a.latitude,
              a.longitude,
            ).compareTo(
              Geolocator.distanceBetween(
                latitude,
                longitude,
                b.latitude,
                b.longitude,
              ),
            ),
      );
      _chargersLoading = false;
    } catch (e) {
      _chargersError = e.toString();
      _allChargers = [];
      _chargersLoading = false;
    }
    notifyListeners();
  }

  /// Refresh nearby chargers (pull-to-refresh support).
  Future<void> refreshChargers() async {
    _initializationFuture = null;
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
    if (query.trim().isEmpty) _locationQueryActive = false;
    notifyListeners();
  }

  /// Debounced server-side place suggestions. The server constrains results
  /// to India and returns coordinates + a full display label, unlike the
  /// platform geocoder which often returns a single vague match.
  void searchLocationSuggestions(String query) {
    _locationSearchTimer?.cancel();
    final token = ++_locationSearchToken;
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      _locationSuggestions = const [];
      _locationQueryActive = false;
      notifyListeners();
      return;
    }
    // Show local station matches immediately, even if the geocoder request is
    // still in flight or unavailable. This makes the same search field useful
    // for both “find a place” and “find my charger”, without inventing data.
    final localMatches = _allChargers
        .where((charger) {
          final haystack = [
            charger.name,
            charger.address ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(trimmed.toLowerCase());
        })
        .take(3)
        .map(
          (charger) => MapLocationSuggestion(
            label:
                '${charger.name}${charger.address == null ? '' : ' · ${charger.address}'}',
            latitude: charger.latitude,
            longitude: charger.longitude,
            placeType: 'charger',
            chargerId: charger.id,
          ),
        )
        .toList();
    _locationSuggestions = localMatches;
    _locationQueryActive = true;
    notifyListeners();
    _locationSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final response = await _api.searchLocations(trimmed);
        if (token != _locationSearchToken) return;
        final data = response.data;
        final placeMatches = data is List
            ? data
                  .whereType<Map>()
                  .map(
                    (item) => MapLocationSuggestion(
                      label: item['display_name']?.toString() ?? trimmed,
                      latitude: (item['latitude'] as num).toDouble(),
                      longitude: (item['longitude'] as num).toDouble(),
                      placeType: item['place_type']?.toString(),
                    ),
                  )
                  .toList()
            : const <MapLocationSuggestion>[];

        // Keep a station match ahead of geocoder results and de-duplicate by
        // coordinate. A query like “Ather” should therefore work offline,
        // while “Ather Baner Pune” still gets real place suggestions.
        final merged = <MapLocationSuggestion>[...localMatches];
        for (final place in placeMatches) {
          final duplicate = merged.any(
            (existing) =>
                (existing.latitude - place.latitude).abs() < 0.00001 &&
                (existing.longitude - place.longitude).abs() < 0.00001,
          );
          if (!duplicate) merged.add(place);
        }
        _locationSuggestions = merged.take(5).toList();
        _locationQueryActive = _locationSuggestions.isNotEmpty;
      } catch (_) {
        if (token != _locationSearchToken) return;
        _locationSuggestions = localMatches;
        // Keep station-name filtering available when the geocoder is offline.
        _locationQueryActive = localMatches.isNotEmpty;
      }
      notifyListeners();
    });
  }

  void clearLocationSuggestions() {
    _locationSearchTimer?.cancel();
    _locationSuggestions = const [];
    _locationQueryActive = false;
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

  @override
  void dispose() {
    _locationSearchTimer?.cancel();
    super.dispose();
  }
}
