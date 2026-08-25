import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/network/session_api.dart';
import '../../../shared/widgets/widgets.dart';

/// Driver History — shows all past charging sessions and bookings.
/// Data comes from [SessionProvider.history].
class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  String _filter = 'all'; // all, completed, confirmed, cancelled

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VoltAppBar(title: 'History'),
      body: SafeArea(
        child: Consumer<SessionProvider>(
          builder: (context, session, _) {
            if (session.historyLoading) {
              return _buildSkeleton();
            }

            if (session.history.isEmpty) {
              return _buildEmpty();
            }

            final filtered = session.history.where((item) {
              if (_filter == 'all') return true;
              return item.status == _filter;
            }).toList();

            return Column(
              children: [
                const SizedBox(height: 8),

                // Stats bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStatsBar(session.history),
                ),
                const SizedBox(height: 12),

                // Filter chips
                _buildFilterChips(),
                const SizedBox(height: 12),

                // History list
                Expanded(
                  child: filtered.isEmpty
                      ? _buildFilterEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildHistoryCard(filtered[index]);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Stats Bar ───
  Widget _buildStatsBar(List<DriverHistoryItem> items) {
    final completed =
        items.where((i) => i.status == 'completed').toList();
    final totalSpent =
        completed.fold<double>(0, (sum, i) => sum + i.amountPaid);
    final totalKwh =
        completed.fold<double>(0, (sum, i) => sum + i.energyKwh);


    return Row(
      children: [
        _stat('${items.length}', 'Total', AppColors.primary),
        const SizedBox(width: 12),
        _stat('${completed.length}', 'Completed', AppColors.success),
        const SizedBox(width: 12),
        _stat(
          '₹${totalSpent.round()}',
          'Spent',
          AppColors.warning,
        ),
        const SizedBox(width: 12),
        _stat(
          '${totalKwh.toStringAsFixed(1)}\nkWh',
          'Charged',
          AppColors.secondary,
        ),
      ],
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }

  // ─── Filter Chips ───
  Widget _buildFilterChips() {
    final filters = [
      ('all', 'All'),
      ('completed', 'Completed'),
      ('confirmed', 'Upcoming'),
      ('cancelled', 'Cancelled'),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (key, label) = filters[index];
          final selected = _filter == key;
          return GestureDetector(
            onTap: () => setState(() => _filter = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.textOnPrimary
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── History Card ───
  Widget _buildHistoryCard(DriverHistoryItem item) {
    final (statusLabel, statusColor) = _statusInfo(item.status);
    final isCompleted = item.status == 'completed';
    final isCancelled = item.status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.ev_station_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.chargerName,
                        style: AppTypography.headlineSmall),
                    const SizedBox(height: 2),
                    Text(item.chargerAddress,
                        style: AppTypography.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Details row
          Row(
            children: [
              _detailChip(
                Icons.calendar_today_rounded,
                '${item.date} · ${item.startTime} – ${item.endTime}',
              ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _metricChip(Icons.bolt_rounded,
                    '${item.energyKwh.toStringAsFixed(1)} kWh', AppColors.primary),
                const SizedBox(width: 8),
                _metricChip(Icons.speed_rounded,
                    '${item.durationMinutes} min', AppColors.secondary),
                const SizedBox(width: 8),
                _metricChip(Icons.power_rounded,
                    '${item.connectorType} · ${item.powerKw.round()} kW', AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metricChip(Icons.currency_rupee,
                    '₹${item.amountPaid.round()}', AppColors.success),
                const Spacer(),
                if (item.rating != null)
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < item.rating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: i < item.rating!
                            ? AppColors.warning
                            : AppColors.textMuted,
                      );
                    }),
                  ),
              ],
            ),
          ],
          if (!isCompleted && !isCancelled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _metricChip(Icons.currency_rupee,
                    '₹${item.amountPaid.round()}', AppColors.success),
                const SizedBox(width: 8),
                _metricChip(Icons.power_rounded,
                    '${item.connectorType} · ${item.powerKw.round()} kW', AppColors.textMuted),
                const Spacer(),
                if (item.status == 'confirmed')
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Booking details coming soon'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'VIEW',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 4),
        Text(text,
            style: AppTypography.bodySmall
                .copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _metricChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(String status) => switch (status) {
        'completed' => ('COMPLETED', AppColors.success),
        'confirmed' => ('CONFIRMED', AppColors.primary),
        'active' => ('ACTIVE', AppColors.primary),
        'cancelled' => ('CANCELLED', AppColors.error),
        _ => ('PENDING', AppColors.warning),
      };

  // ─── Empty State ───
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 56,
              color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 20),
          Text('No charging sessions yet', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Your bookings and sessions will appear here',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'FIND A CHARGER',
            onPressed: () => context.go('/driver/map'),
            icon: Icons.map_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list_off_rounded,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No $_filter sessions',
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _filter = 'all'),
            child: Text(
              'Show all',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Skeleton ───
  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats skeleton
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 12 : 0),
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // List skeleton
          ...List.generate(4, (i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              )),
        ],
      ),
    );
  }
}
