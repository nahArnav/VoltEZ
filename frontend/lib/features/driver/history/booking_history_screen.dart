import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/network/booking_api.dart';
import '../../../core/network/session_api.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../shared/widgets/widgets.dart';

/// Driver History & Active Bookings — shows all active bookings, OTP codes, and past sessions.
class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  String _filter = 'active'; // active, completed, all

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<BookingProvider>().loadHistory(),
      context.read<SessionProvider>().loadHistory(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VoltAppBar(
        title: 'My Bookings & History',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer2<BookingProvider, SessionProvider>(
          builder: (context, bookingProvider, sessionProvider, _) {
            final isLoading =
                bookingProvider.historyLoading || sessionProvider.historyLoading;
            final bookings = bookingProvider.bookingHistory;
            final sessions = sessionProvider.history;

            final activeBookings = bookings.where((b) {
              final s = b.status.toLowerCase();
              return s == 'confirmed' ||
                  s == 'held' ||
                  s == 'pending' ||
                  s == 'payment_pending' ||
                  s == 'checked_in' ||
                  s == 'charging';
            }).toList();

            final completedItems = sessions.where((s) => s.status == 'completed').toList();

            if (isLoading && bookings.isEmpty && sessions.isEmpty) {
              return _buildSkeleton();
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── Stats Bar ───
                          _buildStatsBar(
                            activeCount: activeBookings.length,
                            completedCount: completedItems.length,
                            totalSpent: completedItems.fold<double>(
                              0,
                              (sum, i) => sum + i.amountPaid,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ─── Segment Filter Chips ───
                          _buildFilterChips(
                            activeCount: activeBookings.length,
                            completedCount: completedItems.length,
                            totalCount: bookings.length + sessions.length,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // ─── Content List ───
                  if (_filter == 'active') ...[
                    if (activeBookings.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(
                          title: 'No active reservations',
                          subtitle:
                              'Book a fast charging slot from the map to view your Start Code here.',
                          actionText: 'FIND A CHARGER',
                          onAction: () => context.go('/driver/map'),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildBookingCard(
                              activeBookings[index],
                              bookingProvider,
                            ),
                            childCount: activeBookings.length,
                          ),
                        ),
                      ),
                  ] else if (_filter == 'completed') ...[
                    if (completedItems.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(
                          title: 'No completed sessions yet',
                          subtitle:
                              'Completed charging receipts with cryptographic proof will appear here.',
                          actionText: 'EXPLORE STATIONS',
                          onAction: () => context.go('/driver/home'),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildSessionCard(completedItems[index]),
                            childCount: completedItems.length,
                          ),
                        ),
                      ),
                  ] else ...[
                    // ALL tab
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < bookings.length) {
                              return _buildBookingCard(
                                bookings[index],
                                bookingProvider,
                              );
                            }
                            final sessionIndex = index - bookings.length;
                            return _buildSessionCard(sessions[sessionIndex]);
                          },
                          childCount: bookings.length + sessions.length,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Stats Bar ───
  Widget _buildStatsBar({
    required int activeCount,
    required int completedCount,
    required double totalSpent,
  }) {
    return Row(
      children: [
        _statItem('$activeCount', 'Active Slots', AppColors.primary, Icons.schedule_rounded),
        const SizedBox(width: 10),
        _statItem('$completedCount', 'Completed', AppColors.success, Icons.check_circle_rounded),
        const SizedBox(width: 10),
        _statItem('₹${totalSpent.round()}', 'Total Spent', AppColors.warning, Icons.currency_rupee_rounded),
      ],
    );
  }

  Widget _statItem(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter Chips ───
  Widget _buildFilterChips({
    required int activeCount,
    required int completedCount,
    required int totalCount,
  }) {
    final filters = [
      ('active', 'Active & Upcoming ($activeCount)'),
      ('completed', 'Completed ($completedCount)'),
      ('all', 'All ($totalCount)'),
    ];

    return Row(
      children: filters.map((f) {
        final (key, label) = f;
        final selected = _filter == key;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _filter = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.textOnPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Active Booking Card (With Start Code & Navigation) ───
  Widget _buildBookingCard(
    ConfirmedBooking booking,
    BookingProvider provider,
  ) {
    final status = booking.status.toLowerCase();
    final isCancelled = status == 'cancelled';
    final isConfirmed = status == 'confirmed' || status == 'held';

    final (statusLabel, statusColor) = _bookingStatusMeta(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCancelled
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station header + Status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.chargerName,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      booking.chargerAddress,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Time slot & Power specs
          Row(
            children: [
              _infoBadge(
                Icons.calendar_month_rounded,
                '${booking.date} · ${booking.startTime} - ${booking.endTime}',
                AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoBadge(
                Icons.bolt_rounded,
                '${booking.powerKw.round()} kW',
                AppColors.primary,
              ),
              const SizedBox(width: 8),
              _infoBadge(
                Icons.power_rounded,
                booking.connectorType,
                AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _infoBadge(
                Icons.currency_rupee_rounded,
                'Est. ₹${booking.estimatedCost.round()}',
                AppColors.success,
              ),
            ],
          ),

          // ─── START CODE / CHECK-IN OTP BANNER ───
          if (booking.startCode != null && !isCancelled) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.secondary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.key_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'START CODE / CHECK-IN OTP',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking.startCode!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => NavigationUtils.copyCode(
                      context,
                      booking.startCode!,
                      label: 'Check-in Code',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.copy_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'COPY',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ─── ACTION BUTTONS: NAVIGATE & CHECK IN ───
          if (isConfirmed && !isCancelled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // Turn-by-Turn Navigation
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final lat = booking.latitude ?? 18.5204;
                      final lng = booking.longitude ?? 73.8567;
                      NavigationUtils.openMapsNavigation(
                        latitude: lat,
                        longitude: lng,
                        title: booking.chargerName,
                        context: context,
                      );
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('NAVIGATE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Check In CTA
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context
                          .read<SessionProvider>()
                          .setBookingId(booking.bookingId);
                      context.go('/driver/session');
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('CHECK IN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  // ─── Completed Session Card ───
  Widget _buildSessionCard(DriverHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.chargerName,
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.date} · ${item.startTime} - ${item.endTime}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricChip(
                Icons.bolt_rounded,
                '${item.energyKwh.toStringAsFixed(1)} kWh',
                AppColors.primary,
              ),
              const SizedBox(width: 8),
              _metricChip(
                Icons.speed_rounded,
                '${item.durationMinutes} min',
                AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _metricChip(
                Icons.currency_rupee_rounded,
                '₹${item.amountPaid.round()}',
                AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppColors.secondary,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Swytchcode verified audit proof',
                style: TextStyle(
                  color: AppColors.secondary.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.ev_station_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: actionText,
              onPressed: onAction,
              icon: Icons.search_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (_, _) => Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  (String, Color) _bookingStatusMeta(String status) {
    switch (status) {
      case 'confirmed':
        return ('CONFIRMED', AppColors.success);
      case 'held':
        return ('HELD (WAITING)', AppColors.warning);
      case 'payment_pending':
        return ('PAYMENT PENDING', AppColors.warning);
      case 'checked_in':
        return ('CHECKED IN', AppColors.primary);
      case 'charging':
        return ('CHARGING', AppColors.secondary);
      case 'completed':
        return ('COMPLETED', AppColors.success);
      case 'cancelled':
        return ('CANCELLED', AppColors.error);
      default:
        return (status.toUpperCase(), AppColors.textMuted);
    }
  }
}
