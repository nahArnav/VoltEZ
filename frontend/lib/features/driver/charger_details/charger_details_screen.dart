import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../core/providers/charger_discovery_provider.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/widgets.dart';

/// Charger Details — shown when driver taps a recommended charger
/// or charger card from the map.
///
/// Looks up the charger from [RoutePlannerProvider] recommendations first,
/// then falls back to [ChargerDiscoveryProvider] for map-originated taps.
/// Sets the charger context on [BookingProvider] before navigation.
class ChargerDetailsScreen extends StatefulWidget {
  const ChargerDetailsScreen({super.key, required this.chargerId});

  final String chargerId;

  @override
  State<ChargerDetailsScreen> createState() => _ChargerDetailsScreenState();
}

class _ChargerDetailsScreenState extends State<ChargerDetailsScreen> {
  Charger? _charger;
  int _detourMinutes = 0;
  double _reliabilityScore = 0.0;
  bool _connectorCompatible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveCharger();
  }

  void _resolveCharger() {
    if (_charger != null) return;

    // Try recommendation data first
    try {
      final planner = context.read<RoutePlannerProvider>();
      for (final rec in planner.recommendations) {
        if (rec.charger.id.toString() == widget.chargerId) {
          setState(() {
            _charger = rec.charger;
            _detourMinutes = rec.detourMinutes;
            _reliabilityScore = rec.reliabilityScore;
            _connectorCompatible = rec.connectorCompatible;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback — try ChargerDiscoveryProvider for map-originated taps
    try {
      final discovery = context.read<ChargerDiscoveryProvider>();
      for (final c in discovery.allChargers) {
        if (c.id.toString() == widget.chargerId) {
          setState(() {
            _charger = c;
            _detourMinutes = 0;
            _reliabilityScore = c.rating / 5.0;
            _connectorCompatible = true;
          });
          return;
        }
      }
    } catch (_) {}

    // Final fallback — use default charger
    setState(() {
      _charger = const Charger(
        id: '1', businessId: '1',
        name: 'Phoenix Mall Charger',
        address: 'Phoenix Mall, Lower Parel, Mumbai',
        latitude: 19.0760,
        longitude: 72.8777,
        powerKw: 60,
        accessType: 'public',
        basePrice: 14,
        status: 'active',
        reliabilityScore: 0.92,
        amenities: 'WiFi,Food Court,Parking,Restroom,AC Waiting Lounge',
      );
      _detourMinutes = 6;
      _reliabilityScore = 0.94;
      _connectorCompatible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final charger = _charger;
    if (charger == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final statusColor = _statusColor(charger.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VoltAppBar(
        title: charger.name,
        subtitle: charger.address,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share_rounded,
                color: AppColors.textPrimary, size: 22),
            tooltip: 'Share',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Status + Key Info ───
                  _buildStatusHeader(charger, statusColor),
                  const SizedBox(height: 20),

                  // ─── Quick Stats ───
                  _buildQuickStats(charger),
                  const SizedBox(height: 20),

                  // ─── Connector Info ───
                  _buildConnectorInfo(charger),
                  const SizedBox(height: 20),

                  // ─── Amenities ───
                  _buildAmenities(charger),
                  const SizedBox(height: 20),

                  // ─── Ratings & Trust ───
                  _buildRatingCard(charger),
                  const SizedBox(height: 20),

                  // ─── Business/Host ───
                  _buildHostInfo(charger),
                  const SizedBox(height: 20),

                  // ─── Trust Section ───
                  _buildTrustSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // ─── Bottom CTA ───
          _buildBottomCTA(context, charger),
        ],
      ),
    );
  }

  // ─── Status Header ───
  Widget _buildStatusHeader(Charger charger, Color statusColor) {
    return GlassCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _statusLabel(charger.status),
                style: AppTypography.headlineSmall
                    .copyWith(color: AppColors.onPrimary),
              ),
              const Spacer(),
              _infoChip(
                Icons.star_rounded,
                '${charger.rating} (${charger.totalRatings})',
                AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(
                Icons.power_rounded,
                charger.connectorTypes.isNotEmpty
                    ? charger.connectorTypes.first
                    : 'CCS2',
                AppColors.primary,
              ),
              _infoChip(
                Icons.bolt_rounded,
                '${charger.powerKw.round()} kW',
                AppColors.secondary,
              ),
              _infoChip(
                Icons.currency_rupee,
                '₹${charger.pricePerKwh.round()}/kWh',
                AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick Stats (Detour, Reliability, Compatibility) ───
  Widget _buildQuickStats(Charger charger) {
    return Row(
      children: [
        _statCard(
          Icons.navigation_rounded,              '$_detourMinutes min',
          'Detour',
          AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _statCard(
          Icons.verified_rounded,
          '${(_reliabilityScore * 100).round()}%',
          'Reliability',
          _reliabilityScore >= 0.9
              ? AppColors.success
              : AppColors.warning,
        ),
        const SizedBox(width: 10),
        _statCard(
          _connectorCompatible
              ? Icons.check_circle_rounded
              : Icons.warning_amber_rounded,
          _connectorCompatible ? 'Yes' : 'No',
          'Compatible',
          _connectorCompatible
              ? AppColors.success
              : AppColors.warning,
        ),
      ],
    );
  }

  Widget _statCard(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }

  // ─── Connector Info ───
  Widget _buildConnectorInfo(Charger charger) {
    final connectorNames = charger.connectors
        .map((ct) => ct == ConnectorType.ccs2
            ? 'CCS2 (DC)'
            : ct == ConnectorType.type2
                ? 'Type 2 (AC)'
                : ct.name)
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connector', style: AppTypography.headlineMedium),
        const SizedBox(height: 12),
        GlassCard(
          accentColor: AppColors.primary,
          padding: const EdgeInsets.all(16),
          borderRadius: 14,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.power_rounded,
                    color: AppColors.onPrimary.withValues(alpha: 0.9)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(connectorNames,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.onPrimary,
                        )),
                    Text(
                      '${charger.powerKw.round()} kW · ${charger.powerKw >= 50 ? "DC Fast Charging" : "AC Charging"}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _connectorCompatible
                      ? 'COMPATIBLE'
                      : 'CHECK ADAPTER',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Amenities ───
  Widget _buildAmenities(Charger charger) {
    final amenities = charger.amenitiesList;
    if (amenities.isEmpty) return const SizedBox.shrink();

    final icons = {
      'WiFi': Icons.wifi_rounded,
      'Food Court': Icons.restaurant_rounded,
      'Parking': Icons.local_parking_rounded,
      'Restroom': Icons.wc_rounded,
      'AC Waiting Lounge': Icons.ac_unit_rounded,
      'Cafe': Icons.coffee_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amenities', style: AppTypography.headlineMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: amenities.map((a) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icons[a] ?? Icons.check_circle_rounded,
                    color: AppColors.onPrimary.withValues(alpha: 0.8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    a,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Rating Card ───
  Widget _buildRatingCard(Charger charger) {
    return GlassCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ratings', style: AppTypography.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                children: [
                  Text(
                    charger.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < charger.rating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppColors.warning,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${charger.totalRatings} reviews',
                      style: AppTypography.bodySmall),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _ratingBar('Reliability',
                        _reliabilityScore, AppColors.success),
                    const SizedBox(height: 8),
                    _ratingBar('Cleanliness', 0.88, AppColors.primary),
                    const SizedBox(height: 8),
                    _ratingBar('Speed', 0.91, AppColors.secondary),
                    const SizedBox(height: 8),
                    _ratingBar(
                        'Location', 0.85, AppColors.warning),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: AppTypography.labelSmall.copyWith(
            color: AppColors.onPrimary.withValues(alpha: 0.7),
          )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              color: AppColors.onPrimary,
              backgroundColor: AppColors.onPrimary.withValues(alpha: 0.15),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${(value * 100).round()}%',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ─── Host Info ───
  Widget _buildHostInfo(Charger charger) {
    if (charger.businessId.isEmpty || charger.businessId == '0') return const SizedBox.shrink();

    return GlassCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.business_rounded,
                color: AppColors.onPrimary.withValues(alpha: 0.9), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hosted by', style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.6),
                )),
                Text(
                  'VoltEZ Partner',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded,
              color: AppColors.onPrimary, size: 20),
        ],
      ),
    );
  }

  // ─── Trust Section ───
  Widget _buildTrustSection() {
    return GlassCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Row(
        children: [
          Icon(Icons.verified_rounded,
              color: AppColors.onPrimary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verified Charger',
                    style: AppTypography.headlineSmall
                        .copyWith(color: AppColors.onPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Verified by VoltEZ. Regularly inspected for safety and performance.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom CTA ───
  Widget _buildBottomCTA(BuildContext context, Charger charger) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${charger.pricePerKwh.round()}/kWh',
                style: AppTypography.headlineMedium
                    .copyWith(color: AppColors.primary),
              ),
              Text(
                '$_detourMinutes min detour · ${_reliabilityScore > 0 ? '${(_reliabilityScore * 100).round()}% reliable' : ''}',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              text: 'SELECT SLOT',
              onPressed: () {
                // Set charger on booking provider
                context.read<BookingProvider>().setCharger(charger);
                context.go('/driver/booking');
              },
              isExpanded: true,
              icon: Icons.schedule_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───
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

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Available';
      case 'paused':
        return 'Paused';
      case 'inactive':
        return 'Offline';
      default:
        return status;
    }
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.onPrimary.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
