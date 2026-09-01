import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/route_planner_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/widgets.dart';

/// Smart Charger Recommendations — Top 3 results.
///
/// States: loading (skeleton), success (top-3 cards), empty (no search yet),
/// error (retry CTA), stale (low-confidence warning).
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _analysisController;
  late Animation<double> _analysisFade;

  @override
  void initState() {
    super.initState();
    _analysisController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _analysisFade = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _analysisController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _analysisController.dispose();
    super.dispose();
  }

  // ─── Tag info (rank → label + color) ───
  static const Map<int, (String, Color)> _rankMeta = {
    0: ('Best Overall', AppColors.primary),
    1: ('Fastest', AppColors.secondary),
    2: ('Cheapest', AppColors.success),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<RoutePlannerProvider>(
        builder: (context, planner, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(planner)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: planner.isAnalyzing
                    ? SliverToBoxAdapter(child: _buildLoadingState())
                    : planner.analysisError != null
                    ? SliverToBoxAdapter(child: _buildErrorState(planner))
                    : planner.hasSearched && planner.recommendations.isEmpty
                    ? SliverToBoxAdapter(child: _buildNoResultsState(planner))
                    : planner.hasSearched
                    ? _buildResults(planner)
                    : SliverToBoxAdapter(child: _buildEmptyState()),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader(RoutePlannerProvider planner) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/driver/home');
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommendations',
                      style: AppTypography.headlineLarge.copyWith(fontSize: 18),
                    ),
                    Text(
                      'Top picks for your route',
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (planner.hasSearched)
                GestureDetector(
                  onTap: () {
                    planner.reset();
                    context.go('/driver/route-planner');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'New Search',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOADING STATE — skeleton cards
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          // Pulsing icon
          AnimatedBuilder(
            animation: _analysisFade,
            builder: (context, _) {
              return Opacity(
                opacity: _analysisFade.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Finding best chargers...', style: AppTypography.displaySmall),
          const SizedBox(height: 6),
          Text(
            'Scanning compatible stations along your route',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 32),

          // Skeleton cards
          ...List.generate(3, (i) => _buildSkeletonCard(i)),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmerBox(36, 36, 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(140, 14, 6),
                    const SizedBox(height: 6),
                    _shimmerBox(200, 10, 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _shimmerBox(double.infinity, 48, 14),
          const SizedBox(height: 14),
          _shimmerBox(double.infinity, 36, 10),
        ],
      ),
    );
  }

  Widget _shimmerBox(double w, double h, double r) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ERROR STATE
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildErrorState(RoutePlannerProvider planner) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text('Something went wrong', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text(
            planner.analysisError ?? 'Unable to fetch recommendations.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            text: 'RETRY',
            onPressed: () {
              planner.reset();
              context.go('/driver/route-planner');
            },
            icon: Icons.refresh_rounded,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // NO RESULTS STATE
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildNoResultsState(RoutePlannerProvider planner) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text('No chargers found', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'No compatible chargers were found along your route. '
            'Try adjusting your destination, lowering the reserve, '
            'or changing your vehicle.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            text: 'EDIT ROUTE',
            onPressed: () => context.go('/driver/route-planner'),
            icon: Icons.edit_rounded,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EMPTY STATE (no search yet)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(
            Icons.map_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text('No recommendations yet', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Enter your route details to get\ncharger recommendations',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            text: 'PLAN ROUTE',
            onPressed: () => context.go('/driver/route-planner'),
            icon: Icons.arrow_back_rounded,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RESULTS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildResults(RoutePlannerProvider planner) {
    final hasLowConfidence = planner.recommendations.any(
      (r) => r.confidenceScore < 0.7,
    );

    return SliverList(
      delegate: SliverChildListDelegate([
        // Summary header
        _buildSummaryHeader(planner),
        const SizedBox(height: 20),

        // Stale / low-confidence warning
        if (hasLowConfidence) ...[
          _buildStaleWarning(),
          const SizedBox(height: 16),
        ],

        // Top 3 label
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Top Recommendations', style: AppTypography.headlineMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'TOP 3',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Recommendation cards
        ...List.generate(
          planner.recommendations.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _RecommendationCard(
              rec: planner.recommendations[i],
              index: i,
              rankMeta: _rankMeta,
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Summary Header ───
  Widget _buildSummaryHeader(RoutePlannerProvider planner) {
    final vehicle = planner.selectedVehicle;
    final neededKwh = vehicle != null
        ? vehicle.batteryCapacityKwh *
              (planner.currentSOC - planner.reserveSOC) /
              100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Route Analysis Complete',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                Icons.directions_car_rounded,
                vehicle != null ? '${vehicle.make} ${vehicle.model}' : 'N/A',
                AppColors.primary,
              ),
              _summaryChip(
                Icons.bolt_rounded,
                '${neededKwh.round()} kWh needed',
                AppColors.warning,
              ),
              _summaryChip(
                Icons.ev_station_rounded,
                '${planner.recommendations.length} options',
                AppColors.secondary,
              ),
              if (planner.routeDistanceKm != null)
                _summaryChip(
                  Icons.route_rounded,
                  '${planner.routeDistanceKm!.toStringAsFixed(1)} km drive',
                  AppColors.primary,
                ),
              if (planner.routeDurationMinutes != null)
                _summaryChip(
                  Icons.schedule_rounded,
                  '${planner.routeDurationMinutes} min ETA',
                  AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${planner.originName} → ${planner.destinationName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String text, Color color) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 76,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stale / low-confidence warning ───
  Widget _buildStaleWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Some results have low confidence. Data may be outdated — '
              'availability and pricing are based on last-known status.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RECOMMENDATION CARD — stateful to support expandable "Why this charger?"
// ═════════════════════════════════════════════════════════════════════════════

class _RecommendationCard extends StatefulWidget {
  const _RecommendationCard({
    required this.rec,
    required this.index,
    required this.rankMeta,
  });

  final ChargerRecommendation rec;
  final int index;
  final Map<int, (String, Color)> rankMeta;

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rec = widget.rec;
    final index = widget.index;
    final (tag, tagColor) = widget.rankMeta[index] ?? ('', AppColors.textMuted);

    return GestureDetector(
      onTap: () => context.go('/driver/charger/${rec.charger.id}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: index == 0
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
          ),
          boxShadow: index == 0
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header: rank badge + name + tag ───
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: tagColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.charger.name,
                        style: AppTypography.headlineSmall,
                      ),
                      Text(
                        rec.charger.address ?? '',
                        style: AppTypography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: tagColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── Key Metrics Grid ───
            _buildMetricsGrid(rec),

            const SizedBox(height: 14),

            // ─── Connector + Power Badge ───
            _buildConnectorBadge(rec),

            const SizedBox(height: 14),

            // ─── "Why this charger?" expandable ───
            _buildWhySection(rec),

            const SizedBox(height: 14),

            // ─── Confidence + Action Buttons ───
            Row(
              children: [
                // Confidence chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(rec.confidenceScore * 100).round()}% match',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                // View Details
                GestureDetector(
                  onTap: () => context.go('/driver/charger/${rec.charger.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'DETAILS',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Book Now
                GestureDetector(
                  onTap: () {
                    context.read<BookingProvider>().setCharger(rec.charger);
                    context.go('/driver/booking');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'BOOK NOW',
                      style: TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Metrics Grid (6 cells) ───
  Widget _buildMetricsGrid(ChargerRecommendation rec) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metricCell(
                  Icons.navigation_rounded,
                  '${rec.detourMinutes} min',
                  'Detour',
                  AppColors.secondary,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(
                child: _metricCell(
                  Icons.schedule_rounded,
                  '${rec.predictedWaitMinutes} min',
                  'Wait',
                  rec.predictedWaitMinutes == 0
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(
                child: _metricCell(
                  Icons.bolt_rounded,
                  '${rec.estimatedTimeMinutes} min',
                  'Charging',
                  AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCell(
                  Icons.currency_rupee,
                  '₹${rec.estimatedCost.round()}',
                  rec.estimatedPricePerKwh == null
                      ? 'Est. Cost'
                      : 'Dynamic cost',
                  AppColors.success,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(
                child: _metricCell(
                  Icons.verified_rounded,
                  '${(rec.reliabilityScore * 100).round()}%',
                  'Reliability',
                  rec.reliabilityScore >= 0.9
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(
                child: _metricCell(
                  Icons.power_rounded,
                  '${rec.charger.powerKw.round()} kW',
                  'Power',
                  AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCell(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
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

  // ─── Connector + Power Inline Badge ───
  Widget _buildConnectorBadge(ChargerRecommendation rec) {
    final connectorNames = rec.charger.connectors
        .map((ct) => connectorTypeLabel(ct.name))
        .join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: rec.connectorCompatible
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: rec.connectorCompatible
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            rec.connectorCompatible
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: rec.connectorCompatible
                ? AppColors.success
                : AppColors.warning,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '$connectorNames • ${rec.charger.powerKw.round()} kW',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: rec.connectorCompatible
                    ? AppColors.success
                    : AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── "Why this charger?" Expandable Section ───
  Widget _buildWhySection(ChargerRecommendation rec) {
    if (rec.factors.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'WHY THIS CHARGER',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),

            // Expanded factors
            if (_expanded) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rec.factors.map((f) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: f.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: f.color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.icon, color: f.color, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                f.label,
                                style: TextStyle(
                                  color: f.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                f.description,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              // Collapsed: show first 2 factor labels
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: rec.factors
                    .take(2)
                    .map(
                      (f) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(f.icon, color: f.color, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            f.label,
                            style: TextStyle(
                              color: f.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
