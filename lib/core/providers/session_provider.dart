import 'dart:async';
import 'package:flutter/material.dart';
import '../network/session_api.dart';

/// Phase of the session flow.
enum SessionPhase {
  /// No active session — waiting for check-in.
  idle,

  /// Check-in request in flight.
  checkingIn,

  /// Checked in but not yet charging.
  checkedIn,

  /// Actively charging — polling for live data.
  charging,

  /// Session ending (end request in flight).
  ending,

  /// Session complete — show summary.
  complete,

  /// Rating submitted — thank you.
  rated,

  /// Error state.
  error,
}

/// Manages the full driver session flow:
/// check-in → live charging → end session → rating → history.
///
/// Inject [MockSessionApi] for dev/testing, swap to [LiveSessionApi]
/// when the backend is ready.
class SessionProvider extends ChangeNotifier {
  SessionProvider({SessionApi? sessionApi})
      : _api = sessionApi ?? MockSessionApi();

  final SessionApi _api;

  // ─── Phase ───
  SessionPhase _phase = SessionPhase.idle;
  SessionPhase get phase => _phase;

  // ─── Session Data ───
  SessionData? _sessionData;
  SessionData? get sessionData => _sessionData;

  // ─── Session Summary ───
  SessionSummary? _sessionSummary;
  SessionSummary? get sessionSummary => _sessionSummary;

  // ─── Connection State ───
  String _connectionState = 'Live';
  String get connectionState => _connectionState;

  // ─── Error ───
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── History ───
  List<DriverHistoryItem> _history = [];
  List<DriverHistoryItem> get history => _history;
  bool _historyLoading = false;
  bool get historyLoading => _historyLoading;

  // ─── Rating ───
  bool _ratingSubmitted = false;
  bool get ratingSubmitted => _ratingSubmitted;

  // ─── Polling ───
  Timer? _pollTimer;


  // ─── Active booking context ───
  String? _bookingId;
  String? get bookingId => _bookingId;

  // ═══════════════════════════════════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set the booking context for session initiation.
  void setBookingId(String bookingId) {
    _bookingId = bookingId;
    notifyListeners();
  }

  /// Check in at the charger.
  Future<void> checkIn() async {
    if (_bookingId == null) return;

    _phase = SessionPhase.checkingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      _sessionData = await _api.checkIn(_bookingId!);
      _phase = SessionPhase.checkedIn;
      _startPolling();
    } on SessionApiException catch (e) {
      _errorMessage = e.message;
      _phase = SessionPhase.error;
    } catch (e) {
      _errorMessage = 'Check-in failed. Please try again.';
      _phase = SessionPhase.error;
    }

    notifyListeners();
  }

  /// Start the charging session (transition from checkedIn to charging).
  void startCharging() {
    if (_phase != SessionPhase.checkedIn) return;
    _phase = SessionPhase.charging;
    notifyListeners();
  }

  /// End the charging session.
  Future<void> endSession() async {
    if (_sessionData == null) return;

    _stopPolling();
    _phase = SessionPhase.ending;
    _errorMessage = null;
    notifyListeners();

    try {
      _sessionSummary = await _api.endSession(_sessionData!.sessionId);
      _phase = SessionPhase.complete;
    } on SessionApiException catch (e) {
      _errorMessage = e.message;
      _phase = SessionPhase.charging;
      _startPolling(); // Resume polling
    } catch (e) {
      _errorMessage = 'Failed to end session. Please try again.';
      _phase = SessionPhase.charging;
      _startPolling();
    }

    notifyListeners();
  }

  /// Submit rating and optional issue report.
  Future<void> submitRating({
    required int rating,
    String? issueCategory,
    String? feedback,
  }) async {
    if (_sessionSummary == null) return;

    try {
      await _api.submitRating(RatingPayload(
        sessionId: _sessionSummary!.sessionId,
        rating: rating,
        issueCategory: issueCategory,
        feedback: feedback,
      ));
      _ratingSubmitted = true;
      _phase = SessionPhase.rated;
    } catch (_) {
      // Rating failure is non-critical — still show thank you
      _phase = SessionPhase.rated;
    }

    notifyListeners();
  }

  /// Skip rating and go to thank you.
  void skipRating() {
    _phase = SessionPhase.rated;
    notifyListeners();
  }

  /// Load session history.
  Future<void> loadHistory() async {
    _historyLoading = true;
    notifyListeners();

    try {
      _history = await _api.getHistory();
    } catch (_) {
      _history = [];
    }

    _historyLoading = false;
    notifyListeners();
  }

  /// Reset to idle (e.g., after returning from session).
  void reset() {
    _stopPolling();
    _phase = SessionPhase.idle;
    _sessionData = null;
    _sessionSummary = null;
    _errorMessage = null;
    _bookingId = null;
    _ratingSubmitted = false;
    _connectionState = 'Live';
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Polling
  // ═══════════════════════════════════════════════════════════════════════════

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _pollSessionStatus();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollSessionStatus() async {
    if (_sessionData == null) return;
    if (_phase != SessionPhase.checkedIn && _phase != SessionPhase.charging) {
      return;
    }

    try {
      final updated = await _api.getSessionStatus(_sessionData!.sessionId);
      _sessionData = updated;
      _connectionState = 'Live';

      if (updated.status == SessionStatus.completed) {
        _stopPolling();
        // Auto-end: create summary from session data
        _sessionSummary = SessionSummary(
          sessionId: updated.sessionId,
          chargerName: updated.chargerName,
          connectorType: updated.connectorType,
          durationMinutes: (updated.elapsedSeconds / 60).ceil(),
          energyKwh: updated.energyKwh,
          totalCost: updated.runningCost,
          date: _formatDate(DateTime.now()),
          startTime: updated.slotStart,
          endTime: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        );
        _phase = SessionPhase.complete;
      } else if (updated.status == SessionStatus.charging &&
          _phase == SessionPhase.checkedIn) {
        _phase = SessionPhase.charging;
      }

      _errorMessage = null;
    } catch (_) {
      _connectionState = 'Connection lost — showing last known data';
      // Don't crash polling on transient errors
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Formatted Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  String get formattedElapsed {
    if (_sessionData == null) return '00:00';
    final s = _sessionData!.elapsedSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Cleanup
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
