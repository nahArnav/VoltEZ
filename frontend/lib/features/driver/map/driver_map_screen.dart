import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:provider/provider.dart';


import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/charger_discovery_provider.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../shared/models/models.dart';

/// Station discovery screen with OpenStreetMap (flutter_map).
///
/// Features:
/// - OpenStreetMap tiles centered on driver's GPS (Pune pilot center until GPS is granted).
/// - Custom colored markers: green = available, amber = busy, red = offline.
/// - Marker tap → bottom sheet with station name, distance, ports, wait
///   time prediction, and "View Details" button.
/// - Connector-type filter chips (CCS2, Type 2, CHAdeMO).
/// - Power range slider (7 kW – 150 kW).
/// - No API key required — uses free OpenStreetMap tile servers.
class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _sheetExpanded = false;
  String? _lastCenteredPosition;

  // Base-map center only; no charger data is fabricated when GPS/API access
  // is unavailable.
  static const latlong.LatLng _defaultCenter = latlong.LatLng(18.5204, 73.8567);


  // Connector type display labels (backend uses plain strings)
  static const Map<String, String> _connectorLabels = {
    'CCS2': 'CCS2',
    'Type2': 'Type 2',
    'Type 2': 'Type 2',
    'CHAdeMO': 'CHAdeMO',
    'GB_T': 'GB/T',
    'GB/T': 'GB/T',
    'Type1': 'Type 1',
    'Type 1': 'Type 1',
    'Bharat AC': 'Bharat AC-001',
    'Bharat AC-001': 'Bharat AC-001',
    'Bharat DC': 'Bharat DC-001',
    'Bharat DC-001': 'Bharat DC-001',
  };

  // Connector types available for filter chips
  static const List<String> _filterConnectorTypes = [
    'CCS2',
    'Type2',
    'CHAdeMO',
    'Bharat AC',
    'Bharat DC',
    'Type1',
    'GB_T',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChargerDiscoveryProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Marker color mapping (backend status strings) ───
  Color _statusColor(String status) {
    switch (status) {
      case 'available':
      case 'active':
        return AppColors.success;
      case 'unavailable':
      case 'paused':
        return AppColors.warning;
      case 'maintenance':
      case 'offline':
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  String _waitTimeEstimate(String status) {
    switch (status) {
      case 'available':
      case 'active':
        return 'Available now';
      case 'unavailable':
      case 'paused':
        return 'Currently unavailable';
      case 'maintenance':
        return 'Maintenance';
      case 'offline':
      case 'inactive':
        return 'Offline';
      default:
        return 'N/A';
    }
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/driver/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Consumer<ChargerDiscoveryProvider>(
          builder: (context, discovery, _) {
            final center = discovery.currentPosition != null
                ? latlong.LatLng(
                    discovery.currentPosition!.latitude,
                    discovery.currentPosition!.longitude,
                  )
                : _defaultCenter;
            if (discovery.currentPosition != null) {
              _centerOnPosition(discovery.currentPosition!);
            }


            return Stack(
              children: [
                // ─── OpenStreetMap ───
                _buildMap(discovery, center),

                // ─── Search Bar ───
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 64,
                  right: 16,
                  child: _buildSearchBar(discovery),
                ),

                // A map is a nested destination in the driver flow. Provide an
                // explicit back affordance so Android's system back does not
                // leave the app when this is the root tab.
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: Material(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    child: IconButton(
                      tooltip: 'Back to home',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/driver/home');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                // ─── Filter Chips Row ───
                Positioned(
                  top: MediaQuery.of(context).padding.top + 112,
                  left: 0,
                  right: 0,
                  child: _buildFilterRow(discovery),
                ),

                // Paint suggestions after the filter row so the dropdown is
                // never hidden underneath the horizontal chip list.
                if (discovery.locationSuggestions.isNotEmpty)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 62,
                    left: 64,
                    right: 16,
                    child: _buildLocationSuggestions(discovery),
                  ),

                // ─── Location FAB ───
                Positioned(
                  bottom: _sheetExpanded ? 320 : 140,
                  right: 16,
                  child: _buildLocationFab(discovery),
                ),

                // ─── Station Bottom Sheet ───
                _buildStationSheet(discovery),

                // ─── Charger Count Badge ───
                if (discovery.locationSuggestions.isEmpty)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 160,
                    right: 16,
                    child: _buildCountBadge(discovery),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _centerOnPosition(Position position) {
    final key =
        '${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}';
    if (key == _lastCenteredPosition) return;
    _lastCenteredPosition = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(
          latlong.LatLng(position.latitude, position.longitude),
          13,
        );
      } catch (_) {
        _lastCenteredPosition = null;
      }
    });
  }

  // ─── OpenStreetMap ───
  Widget _buildMap(ChargerDiscoveryProvider discovery, latlong.LatLng center) {
    // Collect recommended charger IDs
    final recIds = <String>{};
    try {
      final planner = context.read<RoutePlannerProvider>();
      for (final r in planner.recommendations) {
        recIds.add(r.charger.id);
      }
    } catch (_) {}

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        onTap: (tapPosition, point) {
          discovery.clearSelection();
          _animateSheet(false);
        },
      ),
      children: [
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.voltez.app',
        ),

        // Marker layer with high-visibility station pins
        MarkerLayer(
          markers: discovery.filteredChargers.map((charger) {
            final isRecommended = recIds.contains(charger.id);
            final statusCol = _statusColor(charger.status);

            return Marker(
              point: latlong.LatLng(charger.latitude, charger.longitude),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  discovery.selectCharger(charger);
                  _animateSheet(true);
                  _mapController.move(
                    latlong.LatLng(charger.latitude, charger.longitude),
                    _mapController.camera.zoom,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isRecommended ? AppColors.secondary : statusCol,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.ev_station_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // OpenStreetMap attribution
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
          ],
        ),
      ],
    );
  }


  // ─── Search Bar ───
  Widget _buildSearchBar(ChargerDiscoveryProvider discovery) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search station or location...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (value) {
                discovery.setSearchQuery(value);
                discovery.searchLocationSuggestions(value);
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                discovery.setSearchQuery('');
                discovery.clearLocationSuggestions();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSuggestions(ChargerDiscoveryProvider discovery) {
    return Material(
      color: AppColors.card,
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: discovery.locationSuggestions.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
          itemBuilder: (context, index) {
            final suggestion = discovery.locationSuggestions[index];
            return ListTile(
              dense: true,
              leading: Icon(
                suggestion.chargerId != null
                    ? Icons.ev_station_outlined
                    : Icons.location_on_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                suggestion.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () async {
                _searchController.text = suggestion.label;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _searchController.text.length),
                );
                discovery.clearLocationSuggestions();
                discovery.setSearchQuery('');

                // A station result is already in the live charger payload;
                // select it directly instead of issuing a second spatial
                // query. Place results continue through the normal nearby
                // charger lookup below.
                if (suggestion.chargerId != null) {
                  final charger = discovery.allChargers.where(
                    (item) => item.id == suggestion.chargerId,
                  );
                  if (charger.isNotEmpty) {
                    final selected = charger.first;
                    discovery.selectCharger(selected);
                    _mapController.move(
                      latlong.LatLng(selected.latitude, selected.longitude),
                      15,
                    );
                    _animateSheet(true);
                    return;
                  }
                }
                await discovery.fetchChargersAt(
                  suggestion.latitude,
                  suggestion.longitude,
                );
                if (!mounted) return;
                _mapController.move(
                  latlong.LatLng(suggestion.latitude, suggestion.longitude),
                  14,
                );
              },

            );
          },
        ),
      ),
    );
  }

  // ─── Filter Row (Connector chips + Power slider) ───
  Widget _buildFilterRow(ChargerDiscoveryProvider discovery) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Connector type chips
          ..._filterConnectorTypes.map((type) {
            final selected = discovery.selectedConnectors.contains(type);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => discovery.toggleConnector(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.card,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.power_rounded,
                        size: 14,
                        color: selected
                            ? AppColors.textOnPrimary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _connectorLabels[type] ?? type,
                        style: TextStyle(
                          color: selected
                              ? AppColors.textOnPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Divider
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: AppColors.border,
          ),

          // Power range chip (opens slider sheet)
          GestureDetector(
            onTap: () => _showPowerRangeSheet(discovery),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isPowerRangeActive(discovery)
                    ? AppColors.secondary.withValues(alpha: 0.2)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: _isPowerRangeActive(discovery)
                      ? AppColors.secondary
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.speed_rounded,
                    size: 14,
                    color: _isPowerRangeActive(discovery)
                        ? AppColors.secondary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${discovery.powerRange.start.round()}\u2013${discovery.powerRange.end.round()} kW',
                    style: TextStyle(
                      color: _isPowerRangeActive(discovery)
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Clear filters button
          if (_hasActiveFilters(discovery))
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  discovery.clearConnectorFilter();
                  discovery.setPowerRange(const RangeValues(7, 150));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_alt_off_rounded,
                        size: 14,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isPowerRangeActive(ChargerDiscoveryProvider discovery) {
    return discovery.powerRange.start > 7 || discovery.powerRange.end < 150;
  }

  bool _hasActiveFilters(ChargerDiscoveryProvider discovery) {
    return discovery.selectedConnectors.isNotEmpty ||
        _isPowerRangeActive(discovery);
  }

  // ─── Count Badge ───
  Widget _buildCountBadge(ChargerDiscoveryProvider discovery) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${discovery.filteredChargers.length} stations',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Location FAB ───
  Widget _buildLocationFab(ChargerDiscoveryProvider discovery) {
    return GestureDetector(
      onTap: () {
        if (discovery.currentPosition != null) {
          _mapController.move(
            latlong.LatLng(
              discovery.currentPosition!.latitude,
              discovery.currentPosition!.longitude,
            ),
            14,
          );
        } else {
          discovery.refreshLocation();
        }
      },

      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.my_location_rounded,
          color: discovery.currentPosition != null
              ? AppColors.primary
              : AppColors.textMuted,
          size: 22,
        ),
      ),
    );
  }

  // ─── Station Bottom Sheet ───
  Widget _buildStationSheet(ChargerDiscoveryProvider discovery) {
    final selected = discovery.selectedCharger;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: selected != null
            ? _buildSelectedStationSheet(selected)
            : _buildNearbyListSheet(discovery),
      ),
    );
  }

  // ─── Selected Station Detail Sheet ───
  Widget _buildSelectedStationSheet(Charger charger) {
    final statusCol = _statusColor(charger.status);

    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Station info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusCol,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          charger.name,
                          style: AppTypography.headlineLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    charger.address ?? '',
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 14),

                  // Metrics row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 86,
                          child: _sheetMetric(
                            Icons.bolt_rounded,
                            '${charger.powerKw.round()} kW',
                            'Power',
                            AppColors.primary,
                          ),
                        ),
                        SizedBox(
                          width: 86,
                          child: _sheetMetric(
                            Icons.currency_rupee,
                            '\u20B9${charger.pricePerKwh.round()}/kWh',
                            'Price',
                            AppColors.success,
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: _sheetMetric(
                            Icons.schedule_rounded,
                            _waitTimeEstimate(charger.status),
                            'Wait',
                            _statusColor(charger.status),
                          ),
                        ),
                        SizedBox(
                          width: 86,
                          child: _sheetMetric(
                            Icons.star_rounded,
                            '${charger.rating}',
                            'Rating',
                            AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Connectors + View Details
                  Row(
                    children: [
                      // Connector badges
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: charger.connectorTypes
                                .map(
                                  (ct) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _connectorLabels[ct] ?? ct,
                                        style: AppTypography.labelMedium
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // View Details button
                      GestureDetector(
                        onTap: () {
                          context.go('/driver/charger/${charger.id}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Details',
                                style: AppTypography.buttonTextSmall.copyWith(
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.textOnPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetMetric(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
        Text(label, style: AppTypography.labelSmall),
      ],
    );
  }

  // ─── Nearby Chargers List Sheet ───
  Widget _buildNearbyListSheet(ChargerDiscoveryProvider discovery) {
    return SafeArea(
      top: false,
      child: Container(
        height: 224,
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Text('Nearby Chargers', style: AppTypography.headlineMedium),
                  const Spacer(),
                  Text(
                    '${discovery.filteredChargers.length} found',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: discovery.filteredChargers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            color: AppColors.textMuted,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No chargers match filters',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: discovery.filteredChargers.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final charger = discovery.filteredChargers[index];
                        final statusCol = _statusColor(charger.status);

                        return GestureDetector(
                          onTap: () {
                            discovery.selectCharger(charger);
                            _animateSheet(true);
                            _mapController.move(
                              latlong.LatLng(
                                charger.latitude,
                                charger.longitude,
                              ),
                              _mapController.camera.zoom,
                            );
                          },

                          child: SizedBox(
                            width: 210,
                            height: 156,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          charger.name,
                                          style: AppTypography.headlineSmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: statusCol,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    charger.address ?? '',
                                    style: AppTypography.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${charger.powerKw.round()} kW \u00B7 \u20B9${charger.pricePerKwh.round()}/kWh',
                                        style: AppTypography.labelMedium
                                            .copyWith(color: AppColors.primary),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Power Range Bottom Sheet ───
  void _showPowerRangeSheet(ChargerDiscoveryProvider discovery) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Power Range', style: AppTypography.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Filter chargers by power output',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  RangeSlider(
                    values: discovery.powerRange,
                    min: 7,
                    max: 150,
                    divisions: 143,
                    activeColor: AppColors.secondary,
                    inactiveColor: AppColors.surface,
                    labels: RangeLabels(
                      '${discovery.powerRange.start.round()} kW',
                      '${discovery.powerRange.end.round()} kW',
                    ),
                    onChanged: (values) {
                      setModalState(() {
                        discovery.setPowerRange(values);
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('7 kW', style: AppTypography.labelSmall),
                      Text(
                        '${discovery.powerRange.start.round()} kW',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        '${discovery.powerRange.end.round()} kW',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                      Text('150 kW', style: AppTypography.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Apply',
                            style: AppTypography.buttonText.copyWith(
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Sheet Animation ───
  void _animateSheet(bool expand) {
    setState(() => _sheetExpanded = expand);
  }
}
