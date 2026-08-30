import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/network/booking_api.dart';
import '../../../core/network/razorpay_service.dart';
import '../../../shared/widgets/widgets.dart';

/// Razorpay API key — replace with your actual key from https://dashboard.razorpay.com/app/keys
/// In production, store this in a backend endpoint, not in client code.
const String kRazorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');

/// Payment screen — launches the configured gateway checkout, then verifies
/// with the backend. Stripe hosted Checkout is preferred when configured;
/// Razorpay remains supported for existing deployments.
///
/// States: pending (select method + pay), processing (spinner),
/// success (confirmation), failed (retry), cancelled, hold expired.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  String _selectedMethod = 'UPI';
  RazorpayService? _razorpay;
  bool _stripeCheckoutOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreDefaultPaymentMethod();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _stripeCheckoutOpened) {
      _stripeCheckoutOpened = false;
      final booking = context.read<BookingProvider>();
      booking.processStripePayment();
    }
  }

  Future<void> _restoreDefaultPaymentMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('voltez_default_payment_method');
    if (!mounted || value == null || !{'upi', 'card', 'cash'}.contains(value)) {
      return;
    }
    setState(
      () => _selectedMethod = value == 'upi'
          ? 'UPI'
          : value == 'card'
          ? 'Card'
          : 'Cash',
    );
    context.read<BookingProvider>().proceedToPayment(method: value);
  }

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
      'icon': Icons.payments_outlined,
      'label': 'Cash',
      'subtitle': 'Pay the host when you arrive',
    },
  ];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _razorpay?.dispose();
    super.dispose();
  }

  /// Open Razorpay checkout sheet and handle the result.
  Future<void> _launchRazorpay(BookingProvider booking) async {
    final hold = booking.holdResult;
    if (hold == null) return;

    // Create the gateway order only after the user has selected a method and
    // tapped Pay. This keeps UPI/card orders from being created prematurely
    // and lets the user switch methods safely.
    final prepared = await booking.preparePayment(
      method: booking.paymentMethod,
    );
    if (!prepared || !mounted) return;

    if (booking.paymentMethod == 'cash') {
      await booking.processCashPayment();
      return;
    }
    final order = booking.paymentOrder;
    if (order == null || order.orderId.isEmpty) return;
    if (order.provider == 'stripe') {
      final checkoutUrl = order.checkoutUrl;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        booking.setPaymentError(
          'Stripe did not return a checkout link. Please retry.',
        );
        return;
      }
      _stripeCheckoutOpened = true;
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _stripeCheckoutOpened = false;
        booking.setPaymentError(
          'Could not open Stripe Checkout on this device.',
        );
        return;
      }
      if (!mounted) return;
      // Hosted Checkout pauses this app. Verification is intentionally
      // deferred until Android/iOS resumes it, after the user has completed
      // (or cancelled) the payment in the browser.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete payment in the browser, then return to VoltEZ.',
          ),
        ),
      );
      return;
    }
    if (kRazorpayKeyId.isEmpty) {
      booking.setPaymentError(
        'Razorpay is not configured for this build. Add the RAZORPAY_KEY_ID build setting.',
      );
      return;
    }

    _razorpay?.dispose();
    _razorpay = RazorpayService();

    final auth = context.read<AuthProvider>();
    final result = await _razorpay!.openCheckout(
      razorpayKey: kRazorpayKeyId,
      amount: (order.amount * 100).round(), // ₹ → paise
      orderId: order.orderId,
      name: 'VoltEZ Charging',
      description:
          'Charging at ${hold.slot.connectorLabel} · '
          '${_formatTime(hold.slot.startTime)} – ${_formatTime(hold.slot.endTime)}',
      prefill: RazorpayPrefill(
        contact: auth.user?.phone ?? '',
        email: auth.user?.email ?? '',
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
                      onTap: () {
                        setState(() => _selectedMethod = m['label']);
                        final method = (m['label'] as String).toLowerCase();
                        booking.proceedToPayment(method: method);
                      },
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
                            Icon(
                              m['icon'],
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['label'],
                                    style: AppTypography.headlineSmall,
                                  ),
                                  Text(
                                    m['subtitle'],
                                    style: AppTypography.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Gateway powered-by notice
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Secured by Stripe / Razorpay',
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
            'BOOKING HOLD',
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
          if (slot != null) ...[
            const SizedBox(height: 6),
            Text(
              'Charging tariff: ₹${slot.pricePerKwh.toStringAsFixed(2)}/kWh · final bill uses delivered energy',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textOnPrimary.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
          ],
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
          Text('Verifying payment…', style: AppTypography.headlineMedium),
          SizedBox(height: 8),
          Text(
            'Confirming with backend',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
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
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              booking.paymentMethod == 'cash'
                  ? 'Reservation Confirmed'
                  : 'Payment Successful!',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${booking.holdResult?.estimatedCost.round() ?? 0} hold · ${booking.paymentMethod == 'cash' ? 'pay at charger' : booking.paymentMethod.toUpperCase()}',
              style: AppTypography.bodyMedium,
            ),
            if (booking.paymentMethod == 'cash' && booking.paymentOrder?.cashOtp != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text('Start Code (OTP)', style: AppTypography.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      booking.paymentOrder!.cashOtp!,
                      style: AppTypography.displaySmall.copyWith(
                        letterSpacing: 4.0,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Show this code to the host to start charging',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
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
            const SizedBox(height: 16),
            Text('Booking confirmed', style: AppTypography.bodySmall),
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
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Failed',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.error,
              ),
            ),
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
            Icon(
              Icons.cancel_rounded,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text('Payment Cancelled', style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Your slot hold has been released.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
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
              child: const Icon(
                Icons.timer_off_rounded,
                color: AppColors.warning,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Hold Expired',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.warning,
              ),
            ),
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
