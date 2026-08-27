import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Payment result types
// ═════════════════════════════════════════════════════════════════════════════

/// Outcome of a Razorpay checkout attempt.
enum RazorpayPaymentStatus {
  success,
  failure,
  cancelled,
  dismissed,
}

/// Result returned from [RazorpayService.openCheckout].
class RazorpayPaymentResult {
  const RazorpayPaymentResult({
    required this.status,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorMessage,
  });

  final RazorpayPaymentStatus status;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;

  bool get isSuccess => status == RazorpayPaymentStatus.success;
}

// ═════════════════════════════════════════════════════════════════════════════
// Razorpay Service
// ═════════════════════════════════════════════════════════════════════════════

/// Wraps the Razorpay Flutter SDK into a clean async interface.
///
/// Usage:
/// ```dart
/// final service = RazorpayService();
/// final result = await service.openCheckout(
///   key: 'rzp_test_...',
///   amount: 20500, // in paise
///   orderId: 'order_xxx', // from backend
///   name: 'VoltEZ Charging',
///   description: 'Charging session at the selected charger',
///   prefill: RazorpayPrefill(email: 'user@example.com', contact: '+919999999999'),
/// );
/// service.dispose();
/// ```
class RazorpayService {
  final Razorpay _razorpay;
  final Completer<RazorpayPaymentResult> _completer = Completer();

  RazorpayService() : _razorpay = Razorpay() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // ─── Event handlers ───

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (_completer.isCompleted) return;
    _completer.complete(RazorpayPaymentResult(
      status: RazorpayPaymentStatus.success,
      paymentId: response.paymentId,
      orderId: response.orderId,
      signature: response.signature,
    ));
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (_completer.isCompleted) return;

    // Razorpay code 2 = PAYMENT_CANCELLED (user dismissed the sheet)
    final isDismissed = response.code == Razorpay.PAYMENT_CANCELLED;

    _completer.complete(RazorpayPaymentResult(
      status: isDismissed
          ? RazorpayPaymentStatus.dismissed
          : RazorpayPaymentStatus.failure,
      errorMessage: response.message ?? 'Payment failed. Please try again.',
    ));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Selecting a wallet is not proof of payment and provides no signature.
    if (_completer.isCompleted) return;
    _completer.complete(RazorpayPaymentResult(
      status: RazorpayPaymentStatus.failure,
      errorMessage:
          'Complete the payment in ${response.walletName ?? 'the wallet'} and retry.',
    ));
  }

  // ─── Open checkout ───

  /// Opens the Razorpay checkout sheet.
  ///
  /// [amount] must be in **paise** (e.g., ₹205 = 20500).
  /// [razorpayKey] is your Razorpay API key (test or live).
  /// [orderId] is the order ID created by your backend via POST /payments/create-order.
  /// Returns a [RazorpayPaymentResult] when the user completes or dismisses the checkout.
  Future<RazorpayPaymentResult> openCheckout({
    required String razorpayKey,
    required int amount,
    required String orderId,
    required String name,
    required String description,
    RazorpayPrefill? prefill,
    List<String>? methods,
  }) async {
    // razorpay_flutter has no web checkout. Never fabricate a successful
    // payment; production web must use Razorpay Checkout.js.
    if (kIsWeb) {
      return const RazorpayPaymentResult(
        status: RazorpayPaymentStatus.failure,
        errorMessage:
            'Payments are currently available in the VoltEZ Android/iOS app.',
      );
    }

    final options = {
      'key': razorpayKey,
      'amount': amount,
      'name': name,
      'description': description,
      'order_id': orderId,
      'prefill': {
        'contact': prefill?.contact ?? '',
        'email': prefill?.email ?? '',
      },
      'theme': {
        'color': '#6C5CE7', // VoltEZ primary
      },
      'modal': {
        'confirm_close': true,
        'escape': false,
      },
      if (methods != null && methods.isNotEmpty) 'method': methods,
    };

    try {
      _razorpay.open(options);
      return await _completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => const RazorpayPaymentResult(
          status: RazorpayPaymentStatus.dismissed,
          errorMessage: 'Payment timed out.',
        ),
      );
    } catch (e) {
      return RazorpayPaymentResult(
        status: RazorpayPaymentStatus.failure,
        errorMessage: 'Failed to open payment: $e',
      );
    }
  }

  /// Dispose of Razorpay listeners.
  void dispose() {
    _razorpay.clear();
  }
}

/// Prefill data for the Razorpay checkout sheet.
class RazorpayPrefill {
  const RazorpayPrefill({this.email, this.contact});
  final String? email;
  final String? contact;
}
