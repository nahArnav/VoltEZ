import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/network/booking_api.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/widgets.dart';

/// Slot selection + hold countdown + booking history.
///
/// Reads charger context from [BookingProvider.selectedCharger].
/// Loads slots via [BookingProvider.loadSlots()].
/// Hold countdown is managed by [BookingProvider].
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _selectedTab = 0; // 0 = slots, 1 = history

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = context.read<BookingProvider>();
      if (booking.selectedCharger != null && booking.slots.isEmpty) {
        booking.loadSlots();
      }
      booking.loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VoltAppBar(title: 'Book a Slot'),
      body: SafeArea(
        child: Consumer<BookingProvider>(
          builder: (context, booking, _) {
            return Column(
              children: [
                // ─── Tabs ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      _tabButton('Select Slot', 0),
                      const SizedBox(width: 8),
                      _tabButton('Booking History', 1),
                    ],
                  ),
                ),

                // ─── Error Banner ───
                if (booking.errorMessage != null &&
                    booking.phase != BookingPhase.held)
                  _buildErrorBanner(booking),

                // ─── Countdown Banner ───
                if (booking.phase == BookingPhase.held ||
                    booking.phase == BookingPhase.holding)
                  _buildCountdownBanner(booking),

                // ─── Content ───
                Expanded(
                  child: _selectedTab == 0
                      ? _buildSlotContent(booking)
                      : _buildBookingHistory(booking),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.primary
                    : AppColors.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Error Banner ───
  Widget _buildErrorBanner(BookingProvider booking) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              booking.errorMessage!,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () {
              booking.resetToSlots();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            child: Text(
              'RETRY',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Countdown Banner ───
  Widget _buildCountdownBanner(BookingProvider booking) {
    final isHolding = booking.phase == BookingPhase.holding;
    final color = booking.isCountdownUrgent
        ? AppColors.error
        : AppColors.warning;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isHolding ? Icons.hourglass_top_rounded : Icons.timer_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHolding ? 'Holding slot…' : 'Slot held — confirm within:',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
                if (!isHolding)
                  Text(
                    booking.formattedCountdown,
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          if (!isHolding)
            PrimaryButton(
              text: 'CONTINUE',
              onPressed: () => booking.proceedToPayment(),
              height: 44,
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SLOT CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSlotContent(BookingProvider booking) {
    final charger = booking.selectedCharger;

    if (charger == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ev_station_rounded,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No charger selected',
                style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Select a charger from the map or recommendations',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'FIND CHARGER',
              onPressed: () => context.go('/driver/map'),
              icon: Icons.map_rounded,
            ),
          ],
        ),
      );
    }

    if (booking.slotsLoading) {
      return _buildSlotsSkeleton();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Charger Info ───
          _buildChargerInfoBar(charger),
          const SizedBox(height: 12),

          _buildDatePicker(booking),
          const SizedBox(height: 14),

          Text('Available Slots — ${_dateHeading(booking.selectedDate)}',
              style: AppTypography.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Select a slot to hold it for 10 minutes',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),

          // ─── Slots Grid ───
          Expanded(
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.0,
              ),
              itemCount: booking.slots.length,
              itemBuilder: (context, index) {
                final slot = booking.slots[index];
                final selected =
                    booking.selectedSlot?.id == slot.id;
                final isHolding =
                    booking.phase == BookingPhase.holding;

                return _buildSlotCard(
                  slot: slot,
                  selected: selected,
                  disabled: isHolding || !slot.isAvailable,
                  onTap: slot.isAvailable && !isHolding
                      ? () => booking.selectAndHoldSlot(slot)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(BookingProvider booking) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      7,
      (index) => today.add(Duration(days: index)),
    );

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = _sameDate(day, booking.selectedDate);
          return Semantics(
            button: true,
            selected: selected,
            label: 'Book for ${_dateHeading(day)}',
            child: InkWell(
              onTap: booking.phase == BookingPhase.idle
                  ? () => booking.selectDate(day)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekday(day),
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekday(DateTime date) => const [
        'MON',
        'TUE',
        'WED',
        'THU',
        'FRI',
        'SAT',
        'SUN',
      ][date.weekday - 1];

  String _dateHeading(DateTime date) {
    if (_sameDate(date, DateTime.now())) return 'Today';
    return '${_weekday(date)} ${date.day}/${date.month}';
  }

  Widget _buildChargerInfoBar(Charger charger) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(charger.name, style: AppTypography.headlineSmall),
                Text(
                  '${charger.powerKw.round()} kW · '
                  '${charger.connectors.first == ConnectorType.ccs2 ? "CCS2" : "Type 2"} · '
                  '₹${charger.pricePerKwh.round()}/kWh',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard({
    required SlotInfo slot,
    required bool selected,
    required bool disabled,
    VoidCallback? onTap,
  }) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    String statusText;

    if (disabled && !selected) {
      bgColor = AppColors.surface.withValues(alpha: 0.5);
      borderColor = AppColors.border;
      textColor = AppColors.textMuted;
      statusText = _slotStatusLabel(slot.status);
    } else if (selected) {
      bgColor = AppColors.primary.withValues(alpha: 0.15);
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
      statusText = 'HELD';
    } else {
      bgColor = AppColors.card;
      borderColor = AppColors.border;
      textColor = AppColors.textPrimary;
      statusText = '₹${slot.pricePerKwh.round()}/kWh';
    }

    final timeStr =
        '${_formatTime(slot.startTime)} – ${_formatTime(slot.endTime)}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timeStr,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: !disabled || selected
                        ? AppColors.success
                        : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (slot.isStale) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline_rounded,
                      size: 12, color: AppColors.warning),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _slotStatusLabel(SlotStatus status) {
    switch (status) {
      case SlotStatus.available:
        return 'Available';
      case SlotStatus.occupied:
        return 'Occupied';
      case SlotStatus.offline:
        return 'Offline';
      case SlotStatus.unknown:
        return 'Unknown';
    }
  }

  Widget _buildSlotsSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(200, 18, 8),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.0,
              ),
              itemCount: 8,
              itemBuilder: (_, _) => Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BOOKING HISTORY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBookingHistory(BookingProvider booking) {
    if (booking.historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (booking.bookingHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No bookings yet',
                style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Your booking history will appear here',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: booking.bookingHistory.length,
      itemBuilder: (context, index) {
        final b = booking.bookingHistory[index];
        final (statusLabel, statusColor) =
            _historyStatus(b.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          AppColors.primary.withValues(alpha: 0.12),
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
                        Text(b.chargerName,
                            style: AppTypography.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${b.date} · ${b.startTime} – ${b.endTime}',
                          style: AppTypography.bodySmall,
                        ),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${b.estimatedCost.round()} · ${b.connectorType} · ${b.powerKw.round()} kW',
                    style: AppTypography.bodySmall,
                  ),
                  if (b.status == 'completed')
                    TextButton(
                      onPressed: () {},
                      child: Text('Rate',
                          style: TextStyle(
                              color: AppColors.warning, fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  (String, Color) _historyStatus(String status) {
    switch (status) {
      case 'completed':
        return ('COMPLETED', AppColors.success);
      case 'confirmed':
        return ('CONFIRMED', AppColors.primary);
      case 'cancelled':
        return ('CANCELLED', AppColors.error);
      default:
        return ('PENDING', AppColors.warning);
    }
  }

  // ─── Helpers ───
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
