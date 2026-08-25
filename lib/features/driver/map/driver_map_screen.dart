import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/charger_discovery_provider.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../shared/models/models.dart';

/// Station discovery screen with Google Maps.
///
/// Features:
/// - GoogleMap centered on driver's GPS (fallback: Mumbai).
/// - Custom colored markers: green = available, amber = busy, red = offline.
/// - Marker tap → bottom sheet with station name, distance, ports, wait
///   time prediction, and "View Details" button.
/// - Connector-type filter chips (CCS2, Type 2, CHAdeMO).
/// - Power range slider (7 kW – 150 kW).
/// - ClusterManager-ready marker set for 50+ pins.
class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  bool _sheetExpanded = false;

  // Default center: Mumbai
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);

  // Connector type display labels (backend uses plain strings)
  static const Map<String, String> _connectorLabels = {
    'CCS2': 'CCS2',
    'Type2': 'Type 2',
    'Type 2': 'Type 2',
    'CHAdeMO': 'CHAdeMO',
    'GB_T': 'GB/T',
    'Type1': 'Type 1',
  };

  // Connector types available for filter chips
  static const List<String> _filterConnectorTypes = ['CCS2', 'Type2', 'CHAdeMO'];

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
    _sheetController.dispose();
    super.dispose();
  }

  // ─── Marker hue mapping (backend status strings) ───
  double _markerHue(String status) {
    switch (status) {
      case 'active':
        return BitmapDescriptor.hueGreen;
      case 'paused':
        return BitmapDescriptor.hueOrange;
      case 'inactive':
        return BitmapDescriptor.hueRed;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'paused':
        return AppColors.warning;
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }



  String _waitTimeEstimate(String status) {
    switch (status) {
      case 'active':
        return '< 5 min';
      case 'paused':
        return '~15 min';
      case 'inactive':
        return 'N/A';
      default:
        return 'N/A';
    }
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<ChargerDiscoveryProvider>(
        builder: (context, discovery, _) {
          final center = discovery.currentPosition != null
              ? LatLng(
                  discovery.currentPosition!.latitude,
                  discovery.currentPosition!.longitude,
                )
              : _defaultCenter;

          return Stack(
            children: [
              // ─── Google Map ───
              _buildGoogleMap(discovery, center),

              // ─── Search Bar ───
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: _buildSearchBar(discovery),
              ),

              // ─── Filter Chips Row ───
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                left: 0,
                right: 0,
                child: _buildFilterRow(discovery),
              ),

              // ─── Location FAB ───
              Positioned(
                bottom: _sheetExpanded ? 300 : 140,
                right: 16,
                child: _buildLocationFab(discovery),
              ),

              // ─── Station Bottom Sheet ───
              _buildStationSheet(discovery),

              // ─── Charger Count Badge ───
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                right: 16,
                child: _buildCountBadge(discovery),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Google Map ───
  Widget _buildGoogleMap(
      ChargerDiscoveryProvider discovery, LatLng center) {
    // google_maps_flutter does not support Flutter Web.
    // Show a charger list fallback on web.
    if (kIsWeb) {
      return _buildWebMapFallback(discovery);
    }

    final markers = <Marker>{};

    // Collect recommended charger IDs so we can visually distinguish them
    final recIds = <int>{};
    try {
      final planner = context.read<RoutePlannerProvider>();
      for (final r in planner.recommendations) {
        recIds.add(r.charger.id);
      }
    } catch (_) {
      // Provider not available — skip recommended markers
    }

    for (final charger in discovery.filteredChargers) {
      final isRecommended = recIds.contains(charger.id);
      markers.add(
        Marker(
          markerId: MarkerId('discovery_${charger.id}'),
          position: LatLng(charger.latitude, charger.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isRecommended
                ? BitmapDescriptor.hueAzure
                : _markerHue(charger.status),
          ),
          infoWindow: InfoWindow(
            title: '${isRecommended ? '★ ' : ''}${charger.name}',
            snippet: '${charger.powerKw.round()} kW · ₹${charger.pricePerKwh.round()}/kWh',
          ),
          onTap: () {
            discovery.selectCharger(charger);
            _animateSheet(true);
          },
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: 13,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      markers: markers,
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
      onCameraMove: (position) {
        // Future: load chargers for visible bounds
      },
      onTap: (_) {
        discovery.clearSelection();
        _animateSheet(false);
      },
      style: _mapStyle,
    );
  }

  // ─── Web fallback: styled charger list instead of Google Map ───
  Widget _buildWebMapFallback(ChargerDiscoveryProvider discovery) {
    return Container(
      color: AppColors.background,
      child: discovery.filteredChargers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded,
                      size: 64,
                      color: AppColors.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No chargers found',
                      style: AppTypography.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Map view is available on mobile.\nShowing charger list on web.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 120, 16, 200),
              itemCount: discovery.filteredChargers.length,
              itemBuilder: (context, index) {
                final charger = discovery.filteredChargers[index];
                final statusCol = _statusColor(charger.status);

                return GestureDetector(
                  onTap: () => context
                      .go('/driver/charger/${charger.id}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: statusCol.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.ev_station_rounded,
                              color: statusCol, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(charger.name,
                                  style: AppTypography.headlineSmall),
                              const SizedBox(height: 2),
                              Text(charger.address ?? '',
                                  style: AppTypography.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${charger.powerKw.round()} kW',
                              style: AppTypography.labelMedium
                                  .copyWith(color: AppColors.primary),
                            ),
                            Text(
                              '₹${charger.pricePerKwh.round()}/kWh',
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ─── Search Bar ───
  Widget _buildSearchBar(ChargerDiscoveryProvider discovery) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
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
              onChanged: (value) => discovery.setSearchQuery(value),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                discovery.setSearchQuery('');
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 16),
              ),
            ),
        ],
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
            final selected =
                discovery.selectedConnectors.contains(type);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => discovery.toggleConnector(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  Icon(Icons.speed_rounded,
                      size: 14,
                      color: _isPowerRangeActive(discovery)
                          ? AppColors.secondary
                          : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${discovery.powerRange.start.round()}–${discovery.powerRange.end.round()} kW',
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
                  discovery.setPowerRange(
                      const RangeValues(7, 150));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
                      Icon(Icons.filter_alt_off_rounded,
                          size: 14, color: AppColors.error),
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
    return discovery.powerRange.start > 7 ||
        discovery.powerRange.end < 150;
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
      onTap: () async {
        if (kIsWeb) return;
        if (discovery.currentPosition != null) {
          final controller = await _mapController.future;
          controller.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(
                discovery.currentPosition!.latitude,
                discovery.currentPosition!.longitude,
              ),
            ),
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
      height: 260,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _sheetMetric(
                        Icons.bolt_rounded,
                        '${charger.powerKw.round()} kW',
                        'Power',
                        AppColors.primary,
                      ),
                      _sheetMetric(
                        Icons.currency_rupee,
                        '₹${charger.pricePerKwh.round()}/kWh',
                        'Price',
                        AppColors.success,
                      ),
                      _sheetMetric(
                        Icons.schedule_rounded,
                        _waitTimeEstimate(charger.status),
                        'Wait',
                        _statusColor(charger.status),
                      ),
                      _sheetMetric(
                        Icons.star_rounded,
                        '${charger.rating}',
                        'Rating',
                        AppColors.warning,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Connectors + View Details
                  Row(
                    children: [
                      // Connector badges
                      ...charger.connectors.map((ct) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                connectorTypeLabel(ct.name),
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          )),

                      const Spacer(),

                      // View Details button
                      GestureDetector(
                        onTap: () {
                          context
                              .go('/driver/charger/${charger.id}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Details',
                                style: AppTypography.buttonTextSmall
                                    .copyWith(
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

  Widget _sheetMetric(
      IconData icon, String value, String label, Color color) {
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
    return Container(
      height: 180,
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
                        Icon(Icons.search_off_rounded,
                            color: AppColors.textMuted, size: 32),
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
                        horizontal: 20, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: discovery.filteredChargers.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final charger =
                          discovery.filteredChargers[index];
                      final statusCol =
                          _statusColor(charger.status);

                      return GestureDetector(
                        onTap: () {
                          discovery.selectCharger(charger);
                          _animateSheet(true);

                          // Pan map to marker (native only)
                          if (!kIsWeb) {
                            _mapController.future.then((ctrl) {
                              ctrl.animateCamera(
                                CameraUpdate.newLatLng(
                                  LatLng(charger.latitude,
                                      charger.longitude),
                                ),
                              );
                            });
                          }
                        },
                        child: Container(
                          width: 210,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      charger.name,
                                      style: AppTypography
                                          .headlineSmall,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
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
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  Text(
                                    '${charger.powerKw.round()} kW · ₹${charger.pricePerKwh.round()}/kWh',
                                    style: AppTypography
                                        .labelMedium
                                        .copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Icon(
                                    Icons
                                        .arrow_forward_ios_rounded,
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
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
                  Text(
                    'Power Range',
                    style: AppTypography.headlineMedium,
                  ),
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
                      Text('${discovery.powerRange.start.round()} kW',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.secondary,
                          )),
                      Text('${discovery.powerRange.end.round()} kW',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.secondary,
                          )),
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

  // ─── Dark Map Style (matches VoltEZ dark theme) ───
  static const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#1a1f2e"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#8a8f9c"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#1a1f2e"}]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#2a3040"}]
  },
  {
    "featureType": "landscape",
    "elementType": "geometry",
    "stylers": [{"color": "#111827"}]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{"color": "#151c2c"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#1e2738"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#6b7280"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#243044"}]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#6b7280"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#0e1525"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#3e4a5a"}]
  }
]
''';
}
