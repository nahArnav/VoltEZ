import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/models/models.dart';
import '../network/booking_api.dart';
import '../network/api_service.dart';

/// Phase of the booking flow.
enum BookingPhase {
  /// Showing available slots.
  idle,

  /// Slot selected, hold request in flight.
  holding,

  /// Hold succeeded — countdown active, waiting for payment.
  held,

  /// Hold expired.
  expired,

  /// Payment order created, waiting for user action.
  paymentPending,

  /// Payment processing (verification in flight).
  paymentProcessing,

  /// Payment succeeded — confirmation screen.
  confirmed,

  /// Payment failed — can retry or cancel.
  paymentFailed,

  /// Payment cancelled by user.
  paymentCancelled,
}

/// Manages the full driver booking flow:
/// charger → slots → hold → countdown → payment → confirmation.
///
/// The production default is the live backend adapter. Tests can still inject
/// a purpose-built [BookingApi] implementation explicitly.
class BookingProvider extends ChangeNotifier {
  BookingProvider({BookingApi? bookingApi})
    : _api = bookingApi ?? LiveBookingApi(ApiService());

  final BookingApi _api;

  // ─── Current charger context ───
  Charger? _selectedCharger;
  Charger? get selectedCharger => _selectedCharger;

  // ─── Phase ───
  BookingPhase _phase = BookingPhase.idle;
  BookingPhase get phase => _phase;

  // ─── Slots ───
  List<SlotInfo> _slots = [];
  List<SlotInfo> get slots => _slots;
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;
  bool _slotsLoading = false;
  bool get slotsLoading => _slotsLoading;
  String? _slotsError;
  String? get slotsError => _slotsError;

  SlotInfo? _selectedSlot;
  SlotInfo? get selectedSlot => _selectedSlot;

  // ─── Hold ───
  HoldResult? _holdResult;
  HoldResult? get holdResult => _holdResult;
  int _countdownSeconds = 0;
  int get countdownSeconds => _countdownSeconds;
  Timer? _countdownTimer;

  // ─── Payment ───
  PaymentOrder? _paymentOrder;
  PaymentOrder? get paymentOrder => _paymentOrder;
  String? _paymentOrderMethod;
  String _paymentMethod = 'upi';
  String get paymentMethod => _paymentMethod;

  // ─── Confirmation ───
  ConfirmedBooking? _confirmedBooking;
  ConfirmedBooking? get confirmedBooking => _confirmedBooking;

  // ─── Error ───
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── History ───
  List<ConfirmedBooking> _bookingHistory = [];
  List<ConfirmedBooking> get bookingHistory => _bookingHistory;
  bool _historyLoading = false;
  bool get historyLoading => _historyLoading;

  // ═══════════════════════════════════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set the charger context for this booking flow.
  void setCharger(Charger charger) {
    _selectedCharger = charger;
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    notifyListeners();
  }

  /// Change the booking day and load server-computed slots for that date.
  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _selectedSlot = null;
    _errorMessage = null;
    await loadSlots();
  }

  /// Load available slots for the current charger.
  Future<void> loadSlots() async {
    if (_selectedCharger == null) return;

    _slotsLoading = true;
    _slotsError = null;
    _slots = [];
    notifyListeners();

    try {
      _slots = await _api.getAvailability(
        _selectedCharger!.id.toString(),
        _selectedDate,
      );
    } catch (e) {
      _slotsError = e.toString();
    }

    _slotsLoading = false;
    notifyListeners();
  }

  /// Select a slot and initiate the hold.
  Future<void> selectAndHoldSlot(SlotInfo slot) async {
    if (_selectedCharger == null) return;

    _selectedSlot = slot;
    _phase = BookingPhase.holding;
    _errorMessage = null;
    notifyListeners();

    try {
      _holdResult = await _api.holdSlot(
        chargerId: _selectedCharger!.id.toString(),
        slotId: slot.id,
        connectorType: slot.connectorType,
      );

      _countdownSeconds = _holdResult!.secondsRemaining;
      _phase = BookingPhase.held;
      _startCountdown();
    } on SlotTakenException catch (e) {
      _errorMessage = e.message;
      _phase = BookingPhase.idle;
      _selectedSlot = null;
      // Reload slots to reflect updated availability
      await loadSlots();
    } catch (e) {
      _errorMessage = 'Failed to hold slot. Please try again.';
      _phase = BookingPhase.idle;
      _selectedSlot = null;
    }

    notifyListeners();
  }

  /// Open the payment step after a hold is confirmed.
  ///
  /// The gateway order is intentionally created only when the user taps Pay.
  /// This lets the user choose UPI, card, or cash before an irreversible
  /// provider order is created (Razorpay orders cannot be changed from UPI to
  /// card after creation).
  void proceedToPayment({String method = 'upi'}) {
    if (_holdResult == null) return;

    _paymentMethod = method;
    _paymentOrder = null;
    _paymentOrderMethod = null;
    _phase = BookingPhase.paymentPending;
    _errorMessage = null;
    notifyListeners();
  }

  /// Create the server-side payment order for the selected method.
  /// Returns false when the backend/provider cannot prepare payment.
  Future<bool> preparePayment({String? method}) async {
    if (_holdResult == null) return false;
    final selectedMethod = method ?? _paymentMethod;
    _paymentMethod = selectedMethod;
    if (_paymentOrder != null && _paymentOrderMethod == selectedMethod) {
      return true;
    }

    _phase = BookingPhase.paymentPending;
    _errorMessage = null;
    notifyListeners();
    try {
      _paymentOrder = await _api.createPaymentOrder(
        bookingId: _holdResult!.bookingId,
        amount: _holdResult!.estimatedCost,
        method: selectedMethod,
      );
      _paymentOrderMethod = selectedMethod;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create payment order.';
      _phase = BookingPhase.held;
      notifyListeners();
      return false;
    }
  }

  /// Cash is confirmed as a reservation immediately and settled at the
  /// station. No client-side success is fabricated; the booking is re-read
  /// from the backend after the cash method is accepted.
  Future<void> processCashPayment() async {
    if (_holdResult == null) return;
    if (!await preparePayment(method: 'cash')) return;
    _phase = BookingPhase.paymentProcessing;
    _errorMessage = null;
    notifyListeners();
    try {
      _confirmedBooking = await _api.confirmCashPayment(_holdResult!.bookingId);
      _stopCountdown();
      _phase = BookingPhase.confirmed;
    } catch (_) {
      _errorMessage = 'Could not confirm the pay-at-charger reservation.';
      _phase = BookingPhase.paymentFailed;
    }
    notifyListeners();
  }

  // ─── Razorpay payment details ───
  String? _razorpayPaymentId;
  String? get razorpayPaymentId => _razorpayPaymentId;

  /// Process payment after Razorpay checkout succeeds.
  /// Sends the Razorpay payment_id, order_id, and signature to the
  /// backend for server-side verification.
  Future<void> processPayment({
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    if (_paymentOrder == null || _holdResult == null) return;

    _phase = BookingPhase.paymentProcessing;
    _errorMessage = null;
    _razorpayPaymentId = razorpayPaymentId;
    notifyListeners();

    try {
      _confirmedBooking = await _api.verifyPayment(
        orderId: razorpayOrderId ?? _paymentOrder!.orderId,
        bookingId: _holdResult!.bookingId,
        paymentId: razorpayPaymentId ?? '',
        signature: razorpaySignature ?? '',
      );

      _stopCountdown();
      _phase = BookingPhase.confirmed;
    } on PaymentFailedException catch (e) {
      _errorMessage = e.message;
      _phase = BookingPhase.paymentFailed;
    } catch (e) {
      _errorMessage = 'Payment verification failed. Please retry.';
      _phase = BookingPhase.paymentFailed;
    }

    notifyListeners();
  }

  /// Retry payment after failure.
  void retryPayment() {
    _errorMessage = null;
    _paymentOrder = null;
    _paymentOrderMethod = null;
    _paymentMethod = 'upi';
    _phase = BookingPhase.held;
    notifyListeners();
  }

  /// Cancel payment and release the hold.
  Future<void> cancelPayment() async {
    final bookingId = _holdResult?.bookingId;
    if (bookingId != null) {
      try {
        await _api.cancelBooking(bookingId);
      } catch (_) {
        _errorMessage = 'Could not cancel this booking. Please retry.';
        _phase = BookingPhase.paymentFailed;
        notifyListeners();
        return;
      }
    }
    _stopCountdown();
    _errorMessage = null;
    _paymentOrder = null;
    _paymentOrderMethod = null;
    _holdResult = null;
    _selectedSlot = null;
    _phase = BookingPhase.paymentCancelled;
    notifyListeners();
  }

  /// Set a payment error from an external source (e.g. Razorpay failure).
  void setPaymentError(String message) {
    _errorMessage = message;
    _phase = BookingPhase.paymentFailed;
    notifyListeners();
  }

  /// Go back to slot selection (from any terminal state).
  void resetToSlots() {
    _stopCountdown();
    _selectedSlot = null;
    _holdResult = null;
    _paymentOrder = null;
    _paymentOrderMethod = null;
    _confirmedBooking = null;
    _errorMessage = null;
    _phase = BookingPhase.idle;
    notifyListeners();
    loadSlots();
  }

  /// Load booking history.
  Future<void> loadHistory() async {
    _historyLoading = true;
    notifyListeners();

    try {
      _bookingHistory = await _api.getBookingHistory();
    } catch (_) {
      _bookingHistory = [];
    }

    _historyLoading = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Countdown
  // ═══════════════════════════════════════════════════════════════════════════

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        _phase = BookingPhase.expired;
        _selectedSlot = null;
        _holdResult = null;
        _paymentOrder = null;
        _paymentOrderMethod = null;
        _errorMessage = 'Your hold has expired. Please select another slot.';
        notifyListeners();
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  String get formattedCountdown {
    final m = _countdownSeconds ~/ 60;
    final s = _countdownSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get isCountdownUrgent => _countdownSeconds < 120; // < 2 min

  // ═══════════════════════════════════════════════════════════════════════════
  // Cleanup
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _stopCountdown();
    super.dispose();
  }
}
