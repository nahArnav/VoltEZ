import 'dart:async';
import 'package:flutter/material.dart';
import '../network/session_api.dart';
import '../network/session_websocket.dart';
import '../network/api_service.dart';

/// Phase of the session flow.
enum SessionPhase {
  /// No active session — waiting for check-in.
  idle,

  /// Check-in request in flight.
  checkingIn,

  /// Checked in but not yet charging.
  checkedIn,

  /// Actively charging — receiving live updates.
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
/// Uses a [SessionWebSocket] for real-time updates during charging,
/// falling back to the REST [SessionApi] for check-in, end, rating, and history.
class SessionProvider extends ChangeNotifier {
  SessionProvider({
    SessionApi? sessionApi,
    SessionWebSocket? webSocket,
  })  : _api = sessionApi ?? LiveSessionApi(ApiService()),
        _webSocket = webSocket ??
            LiveSessionWebSocket(
              userIdGetter: () => null,
              tokenGetter: () => null,
            );

  final SessionApi _api;
  final SessionWebSocket _webSocket;

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
  WebSocketConnectionState _wsState = WebSocketConnectionState.disconnected;
  WebSocketConnectionState get wsState => _wsState;

  /// Human-readable connection label for the UI.
  String get connectionStateLabel {
    switch (_wsState) {
      case WebSocketConnectionState.connected:
        return 'Live';
      case WebSocketConnectionState.connecting:
      case WebSocketConnectionState.reconnecting:
        return 'Connecting…';
      case WebSocketConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  bool get isConnected => _wsState == WebSocketConnectionState.connected;

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

  // ─── WebSocket subscriptions ───
  StreamSubscription<SessionStreamEvent>? _eventSubscription;
  StreamSubscription<WebSocketConnectionState>? _wsStateSubscription;

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

  /// Check in at the charger, then connect the WebSocket for live updates.
  Future<void> checkIn() async {
    if (_bookingId == null) return;

    _phase = SessionPhase.checkingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      _sessionData = await _api.checkIn(_bookingId!);
      // A host may have verified the cash OTP and started the session before
      // the driver taps CHECK IN. Reflect the server status immediately so the
      // driver is taken to the live charging view instead of seeing a second
      // "START CHARGING" action that would fail.
      _phase = _sessionData!.status == SessionStatus.charging
          ? SessionPhase.charging
          : _sessionData!.status == SessionStatus.completed
          ? SessionPhase.complete
          : SessionPhase.checkedIn;
      // Connect WebSocket for live updates
      await _connectWebSocket(_sessionData!.sessionId);
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
  Future<void> startCharging() async {
    if (_phase == SessionPhase.charging) return;
    if (_phase != SessionPhase.checkedIn) return;
    if (_sessionData == null) return;
    _errorMessage = null;
    try {
      _sessionData = await _api.startSession(_sessionData!.sessionId);
      _phase = SessionPhase.charging;
    } on SessionApiException catch (error) {
      _errorMessage = error.message;
      _phase = SessionPhase.error;
    } catch (_) {
      _errorMessage = 'Unable to start charging. Please try again.';
      _phase = SessionPhase.error;
    }
    notifyListeners();
  }

  /// End the charging session.
  Future<void> endSession() async {
    if (_sessionData == null) return;

    await _disconnectWebSocket();
    _phase = SessionPhase.ending;
    _errorMessage = null;
    notifyListeners();

    try {
      _sessionSummary = await _api.endSession(_sessionData!.sessionId);
      _phase = SessionPhase.complete;
    } on SessionApiException catch (e) {
      _errorMessage = e.message;
      _phase = SessionPhase.charging;
      // Reconnect WebSocket
      await _connectWebSocket(_sessionData!.sessionId);
    } catch (e) {
      _errorMessage = 'Failed to end session. Please try again.';
      _phase = SessionPhase.charging;
      await _connectWebSocket(_sessionData!.sessionId);
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
    _disconnectWebSocket();
    _phase = SessionPhase.idle;
    _sessionData = null;
    _sessionSummary = null;
    _errorMessage = null;
    _bookingId = null;
    _ratingSubmitted = false;
    _wsState = WebSocketConnectionState.disconnected;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WebSocket
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _connectWebSocket(String sessionId) async {
    await _disconnectWebSocket();

    // Listen to connection state changes
    _wsStateSubscription = _webSocket.connectionStateChanges.listen((state) {
      final changed = _wsState != state;
      _wsState = state;
      if (changed) notifyListeners();
    });

    // Listen to session events
    _eventSubscription = _webSocket.events.listen(
      _handleWebSocketEvent,
      onError: (_) {
        _wsState = WebSocketConnectionState.disconnected;
        notifyListeners();
      },
    );

    // Start the connection
    await _webSocket.connect(sessionId);
    _wsState = _webSocket.connectionState;
    notifyListeners();
  }

  Future<void> _disconnectWebSocket() async {
    await _eventSubscription?.cancel();
    await _wsStateSubscription?.cancel();
    _eventSubscription = null;
    _wsStateSubscription = null;
    await _webSocket.disconnect();
    _wsState = WebSocketConnectionState.disconnected;
  }

  void _handleWebSocketEvent(SessionStreamEvent event) {
    switch (event.type) {
      case 'status_update':
        if (event.sessionData != null) {
          _sessionData = event.sessionData;
          _errorMessage = null;

          // Auto-transition phase based on status
          if (event.sessionData!.status == SessionStatus.charging &&
              _phase == SessionPhase.checkedIn) {
            _phase = SessionPhase.charging;
          }
        }
        break;

      case 'session_completed':
        if (event.summary != null) {
          _sessionSummary = event.summary;
          _phase = SessionPhase.complete;
          _disconnectWebSocket();
        }
        break;

      case 'error':
        _errorMessage = event.errorMessage ?? 'Connection error';
        break;

      case 'pong':
        // Keepalive acknowledged — no action needed
        break;
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Cleanup
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _disconnectWebSocket();
    _webSocket.dispose();
    super.dispose();
  }
}
