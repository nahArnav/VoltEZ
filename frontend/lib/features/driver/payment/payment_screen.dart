import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/network/booking_api.dart';
import '../../../core/network/razorpay_service.dart';
import '../../../shared/widgets/widgets.dart';

/// Razorpay API key — replace with your actual key from https://dashboard.razorpay.com/app/keys
/// In production, store this in a backend endpoint, not in client code.
const String kRazorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');

/// Payment screen — launches Razorpay checkout sheet, then verifies with backend.
///
/// States: pending (select method + pay), processing (spinner),
/// success (confirmation), failed (retry), cancelled, hold expired.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'UPI';
  RazorpayService? _razorpay;

  final List<Map<String, dynamic>> _methods = [
    {
      'icon': Icons.account_balance_rounded,
      'label': 'UPI',
      'subtitle': 'Google Pay, PhonePe, Paytm',
    },
    {
      'icon': Icons.credit_card_rounded,
      'label': 'Card',
      'subtitle': 'Debit / Credit card',
    },
    {
      'icon': Icons.wallet_rounded,
      'label': 'VoltEZ Wallet',
      'subtitle': 'Balance: ₹500',
    },
  ];

  @override
  void dispose() {
    _razorpay?.dispose();
    super.dispose();
  }

  /// Open Razorpay checkout sheet and handle the result.
  Future<void> _launchRazorpay(BookingProvider booking) async {
    final hold = booking.holdResult;
    final order = booking.paymentOrder;
    if (hold == null || order == null) return;
    if (kRazorpayKeyId.isEmpty) {
      booking.setPaymentError(
        'Razorpay is not configured for this build. Add the RAZORPAY_KEY_ID build setting.',
      );
      return;
    }

    _razorpay?.dispose();
    _razorpay = RazorpayService();

    final result = await _razorpay!.openCheckout(
      razorpayKey: kRazorpayKeyId,
      amount: (order.amount * 100).round(), // ₹ → paise
      orderId: order.orderId,
      name: 'VoltEZ Charging',
      description: 'Charging at ${hold.slot.connectorLabel} · '
          '${_formatTime(hold.slot.startTime)} – ${_formatTime(hold.slot.endTime)}',
      prefill: RazorpayPrefill(
        contact: '+919999999999',
      ),
    );

    if (!mounted) return;

    if (result.isSuccess) {
      // Razorpay payment succeeded → verify with backend
      await booking.processPayment(
        razorpayPaymentId: result.paymentId,
        razorpayOrderId: result.orderId,
        razorpaySignature: result.signature,
      );
    } else if (result.status == RazorpayPaymentStatus.failure) {
      // Payment failed on Razorpay side
      setState(() {});
      booking.setPaymentError(result.errorMessage ?? 'Payment failed.');
    } else {
      // Dismissed or cancelled
      setState(() {});
      await booking.cancelPayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VoltAppBar(title: 'Payment'),
      body: Consumer<BookingProvider>(
        builder: (context, booking, _) {
          return switch (booking.phase) {
            BookingPhase.paymentPending => _buildPending(booking),
            BookingPhase.paymentProcessing => _buildProcessing(),
            BookingPhase.confirmed => _buildConfirmed(booking),
            BookingPhase.paymentFailed => _buildFailed(booking),
            BookingPhase.paymentCancelled => _buildCancelled(),
            BookingPhase.expired => _buildExpired(booking),
            _ => _buildPending(booking),
          };
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYMENT PENDING — select method + pay via Razorpay
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPending(BookingProvider booking) {
    final hold = booking.holdResult;
    final amount = hold?.estimatedCost ?? 0;
    final slot = hold?.slot;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount card
                _buildAmountCard(amount, slot),
                const SizedBox(height: 28),

                // Payment methods
                Text('Pay with', style: AppTypography.headlineMedium),
                const SizedBox(height: 14),
                ..._methods.map((m) {
                  final selected = _selectedMethod == m['label'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedMethod = m['label']),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(m['icon'],
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['label'],
                                      style:
                                          AppTypography.headlineSmall),
                                  Text(m['subtitle'],
                                      style: AppTypography.bodySmall),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 22),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Razorpay powered-by notice
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Secured by Razorpay',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Pay button + cancel
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              PrimaryButton(
                text: 'PAY ₹${amount.round()}',
                onPressed: () => _launchRazorpay(booking),
                isExpanded: true,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  await booking.cancelPayment();
                  if (!mounted ||
                      booking.phase != BookingPhase.paymentCancelled) {
                    return;
                  }
                  context.go('/driver/booking');
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountCard(double amount, SlotInfo? slot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'TOTAL AMOUNT',
            style: TextStyle(
              color: AppColors.textOnPrimary.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.round()}',
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (slot != null)
            Text(
              '${slot.connectorLabel} · ${slot.durationMinutes} min · '
              '${_formatTime(slot.startTime)} – ${_formatTime(slot.endTime)}',
              style: TextStyle(
                color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROCESSING — waiting for backend verification
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 24),
          Text('Verifying payment…',
              style: AppTypography.headlineMedium),
          SizedBox(height: 8),
          Text(
            'Confirming with backend',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUCCESS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildConfirmed(BookingProvider booking) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Payment Successful!',
                style: AppTypography.displaySmall
                    .copyWith(color: AppColors.success)),
            const SizedBox(height: 8),
            Text(
              '₹${booking.holdResult?.estimatedCost.round() ?? 0} charged via Razorpay',
              style: AppTypography.bodyMedium,
            ),
            if (booking.razorpayPaymentId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Payment ID: ${booking.razorpayPaymentId}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Booking confirmed',
                style: AppTypography.bodySmall),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'VIEW BOOKING',
              onPressed: () => context.go('/driver/booking-confirmation'),
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FAILED
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFailed(BookingProvider booking) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Payment Failed',
                style: AppTypography.displaySmall
                    .copyWith(color: AppColors.error)),
            const SizedBox(height: 8),
            Text(
              booking.errorMessage ?? 'Payment could not be processed.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'RETRY PAYMENT',
              onPressed: () => booking.retryPayment(),
              isExpanded: true,
              icon: Icons.refresh_rounded,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                await booking.cancelPayment();
                if (!mounted ||
                    booking.phase != BookingPhase.paymentCancelled) {
                  return;
                }
                context.go('/driver/booking');
              },
              child: Text(
                'Choose another slot',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CANCELLED
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCancelled() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_rounded,
                size: 64,
                color: AppColors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text('Payment Cancelled',
                style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Your slot hold has been released.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'BACK TO SLOTS',
              onPressed: () {
                context.read<BookingProvider>().resetToSlots();
                context.go('/driver/booking');
              },
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOLD EXPIRED
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildExpired(BookingProvider booking) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_rounded,
                  color: AppColors.warning, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Hold Expired',
                style: AppTypography.displaySmall
                    .copyWith(color: AppColors.warning)),
            const SizedBox(height: 8),
            Text(
              'Your 5-minute hold has expired.\nPlease select another slot.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'CHOOSE ANOTHER SLOT',
              onPressed: () {
                booking.resetToSlots();
                context.go('/driver/booking');
              },
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
