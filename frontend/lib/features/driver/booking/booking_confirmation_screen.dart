import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../shared/widgets/widgets.dart';


/// Booking Confirmation — shown after successful payment verification.
///
/// Displays:
/// - Booking confirmed badge
/// - Full booking details (charger, location, date, times, connector, power, cost, ID)
/// - "Navigate to Charger" CTA (with navigation/open maps)
/// - "Check In" CTA (goes to charging session)
/// - "View Booking" CTA
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ─── Back Button ───
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => context.go('/driver/home'),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 24),
              tooltip: 'Back',
            ),
          ),

          Consumer<BookingProvider>(
        builder: (context, booking, _) {
          final confirmed = booking.confirmedBooking;

          if (confirmed == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 56,
                      color: AppColors.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No booking found',
                      style: AppTypography.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Check your bookings or find a charger',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: 'GO HOME',
                    onPressed: () => context.go('/driver/home'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
            child: Column(
              children: [
                // ─── Confirmed Badge ───
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 52),
                ),
                const SizedBox(height: 24),
                Text('Booking Confirmed',
                    style: AppTypography.displaySmall
                        .copyWith(color: AppColors.success)),
                const SizedBox(height: 8),
                Text(
                  'Your slot is reserved. Arrive 5 minutes early.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 32),

                // ─── Booking Details Card ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Charger name
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.ev_station_rounded,
                                color: AppColors.primary,
                                size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(confirmed.chargerName,
                                    style: AppTypography
                                        .headlineLarge),
                                Text(
                                  confirmed.chargerAddress,
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Container(
                        height: 1,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 20),

                      // Detail rows
                      _detailRow('Date', confirmed.date),
                      _detailRow('Start Time', confirmed.startTime),
                      _detailRow('End Time', confirmed.endTime),
                      _detailRow('Connector', confirmed.connectorType),
                      _detailRow(
                          'Power', '${confirmed.powerKw.round()} kW'),
                      _detailRow(
                        'Estimated Cost',
                        '₹${confirmed.estimatedCost.round()}',
                        highlight: true,
                      ),
                      if (confirmed.startCode != null || booking.paymentOrder?.cashOtp != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.key_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CHECK-IN START CODE / OTP',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      confirmed.startCode ??
                                          booking.paymentOrder?.cashOtp ??
                                          '------',
                                      style: AppTypography.displaySmall.copyWith(
                                        color: Colors.white,
                                        letterSpacing: 3,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  final code = confirmed.startCode ??
                                      booking.paymentOrder?.cashOtp;
                                  if (code != null) {
                                    NavigationUtils.copyCode(
                                      context,
                                      code,
                                      label: 'Check-in Code',
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Booking ID',
                              style: AppTypography.bodySmall),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Text(
                              confirmed.bookingId,
                              style: AppTypography.headlineSmall
                                  .copyWith(
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Tip ───
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Show the 6-digit Start Code to the host or enter it on the charger screen to activate power.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ─── Navigate to Charger CTA ───
                PrimaryButton(
                  text: 'NAVIGATE TO CHARGER',
                  onPressed: () {
                    final lat = confirmed.latitude ??
                        booking.selectedCharger?.latitude ??
                        18.5204;
                    final lng = confirmed.longitude ??
                        booking.selectedCharger?.longitude ??
                        73.8567;
                    NavigationUtils.openMapsNavigation(
                      latitude: lat,
                      longitude: lng,
                      title: confirmed.chargerName,
                      context: context,
                    );
                  },
                  isExpanded: true,
                  icon: Icons.navigation_rounded,
                ),
                const SizedBox(height: 12),

                // ─── Check In CTA ───
                PrimaryButton(
                  text: 'CHECK IN',
                  onPressed: () {
                    // Wire booking ID to session provider
                    context.read<SessionProvider>().setBookingId(
                        confirmed.bookingId);
                    context.go('/driver/session');
                  },
                  isExpanded: true,
                  icon: Icons.check_circle_rounded,
                  height: 52,
                ),
                const SizedBox(height: 12),

                // ─── View Booking CTA ───
                SecondaryButton(
                  text: 'VIEW ALL BOOKINGS',
                  onPressed: () {
                    booking.resetToSlots();
                    context.go('/driver/history');
                  },
                  isExpanded: true,
                  icon: Icons.receipt_long_rounded,
                ),

                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.go('/driver/home'),
                  child: Text(
                    'Back to Home',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall),
          Text(
            value,
            style: highlight
                ? AppTypography.headlineSmall
                    .copyWith(color: AppColors.primary)
                : AppTypography.headlineSmall.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
