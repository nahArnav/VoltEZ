import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'session_api.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Connection state
// ═════════════════════════════════════════════════════════════════════════════

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

// ═════════════════════════════════════════════════════════════════════════════
// Stream event types from the server
// ═════════════════════════════════════════════════════════════════════════════

/// A single event received from the session WebSocket.
class SessionStreamEvent {
  const SessionStreamEvent({
    required this.type,
    this.sessionData,
    this.summary,
    this.errorMessage,
  });

  /// Event type: 'status_update', 'session_completed', 'error', 'pong'.
  final String type;

  /// Present when type == 'status_update'.
  final SessionData? sessionData;

  /// Present when type == 'session_completed'.
  final SessionSummary? summary;

  /// Present when type == 'error'.
  final String? errorMessage;

  /// Parse a raw JSON message from the WebSocket.
  factory SessionStreamEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';

    SessionData? sessionData;
    if (json['data'] != null && type == 'status_update') {
      sessionData = _parseSessionData(json['data']);
    }

    SessionSummary? summary;
    if (json['data'] != null && type == 'session_completed') {
      summary = _parseSessionSummary(json['data']);
    }

    return SessionStreamEvent(
      type: type,
      sessionData: sessionData,
      summary: summary,
      errorMessage: json['message'] as String?,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Abstract WebSocket interface
// ═════════════════════════════════════════════════════════════════════════════

/// Abstraction for a session-scoped WebSocket connection.
///
/// The real implementation connects to `wss://backend/sessions/{id}/stream`.
/// The mock implementation simulates the same event stream with timers.
abstract class SessionWebSocket {
  /// Stream of events from the server.
  Stream<SessionStreamEvent> get events;

  /// Current connection state.
  WebSocketConnectionState get connectionState;

  /// Stream of connection state changes.
  Stream<WebSocketConnectionState> get connectionStateChanges;

  /// Connect to the session stream.
  Future<void> connect(String sessionId);

  /// Disconnect from the stream.
  Future<void> disconnect();

  /// Send a ping / keepalive.
  void sendPing();

  /// Clean up resources.
  void dispose();
}

// ═════════════════════════════════════════════════════════════════════════════
// Live WebSocket implementation
// ═════════════════════════════════════════════════════════════════════════════

/// Connects to the real backend WebSocket endpoint.
///
/// Expected server protocol:
/// - URL: `wss://{host}/api/v1/ws/{userId}?token={jwt}`
/// - Client → Server: `{"type": "ping"}`
/// - Server → Client: `{"type": "status_update", "data": {...SessionData...}}`
/// - Server → Client: `{"type": "session_completed", "data": {...SessionSummary...}}`
/// - Server → Client: `{"type": "pong"}`
/// - Server → Client: `{"type": "error", "message": "..."}`
class LiveSessionWebSocket implements SessionWebSocket {
  LiveSessionWebSocket({
    this.baseUrl = 'ws://127.0.0.1:8001/api/v1',
    this.baseUrlGetter,
    required this.userIdGetter,
    required this.tokenGetter,
  });

  final String baseUrl;
  final String Function()? baseUrlGetter;
  final String? Function() userIdGetter;
  final String? Function() tokenGetter;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final _eventController = StreamController<SessionStreamEvent>.broadcast();
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();

  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  String? _sessionId;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 10;

  @override
  Stream<SessionStreamEvent> get events => _eventController.stream;

  @override
  WebSocketConnectionState get connectionState => _state;

  @override
  Stream<WebSocketConnectionState> get connectionStateChanges =>
      _stateController.stream;

  @override
  Future<void> connect(String sessionId) async {
    _sessionId = sessionId;
    _reconnectAttempt = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_sessionId == null) return;

    _setState(WebSocketConnectionState.connecting);

    try {
      final userId = userIdGetter();
      final token = tokenGetter();
      if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
        throw StateError('Authenticated WebSocket identity is unavailable.');
      }
      final effectiveBaseUrl = baseUrlGetter?.call() ?? baseUrl;
      final uri = Uri.parse('$effectiveBaseUrl/ws/$userId').replace(
        queryParameters: {'token': token},
      );
      _channel = WebSocketChannel.connect(uri);

      // Wait for the connection to be ready
      await _channel!.ready;

      _setState(WebSocketConnectionState.connected);
      _reconnectAttempt = 0;

      // Listen for messages
      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final json = jsonDecode(message as String) as Map<String, dynamic>;
            final event = SessionStreamEvent.fromJson(json);
            _eventController.add(event);
          } catch (_) {
            // Ignore malformed messages
          }
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      // Start keepalive ping every 30s
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        sendPing();
      });
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;

    if (_sessionId != null && _reconnectAttempt < _maxReconnectAttempts) {
      _setState(WebSocketConnectionState.reconnecting);
      _scheduleReconnect();
    } else {
      _setState(WebSocketConnectionState.disconnected);
    }
  }

  void _scheduleReconnect() {
    _reconnectAttempt++;
    // Exponential backoff: 1s, 2s, 4s, 8s, ... capped at 30s
    final delay = Duration(
      seconds: (1 << (_reconnectAttempt - 1)).clamp(1, 30),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _doConnect();
    });
  }

  @override
  Future<void> disconnect() async {
    _reconnectAttempt = _maxReconnectAttempts; // Prevent reconnect
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _sessionId = null;
    _setState(WebSocketConnectionState.disconnected);
  }

  @override
  void sendPing() {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'ping'}));
    } catch (_) {
      // Connection may be dead — reconnect logic will handle it
    }
  }

  void _setState(WebSocketConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    _stateController.close();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Mock WebSocket implementation
// ═════════════════════════════════════════════════════════════════════════════

/// Simulates a WebSocket stream for development/testing.
/// Produces the same charging-progress simulation as MockSessionApi
/// but delivers data via a stream (no polling).
class MockSessionWebSocket implements SessionWebSocket {
  Timer? _tickTimer;
  String? _sessionId;
  int _elapsedSeconds = 0;
  double _soc = 68;
  double _energy = 0;
  bool _connected = false;

  final _eventController = StreamController<SessionStreamEvent>.broadcast();
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();

  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;

  @override
  Stream<SessionStreamEvent> get events => _eventController.stream;

  @override
  WebSocketConnectionState get connectionState => _state;

  @override
  Stream<WebSocketConnectionState> get connectionStateChanges =>
      _stateController.stream;

  @override
  Future<void> connect(String sessionId) async {
    _sessionId = sessionId;
    _setState(WebSocketConnectionState.connecting);

    // Simulate connection delay
    await Future<void>.delayed(const Duration(milliseconds: 300));

    _connected = true;
    _setState(WebSocketConnectionState.connected);

    // Start emitting updates every 3 seconds (same cadence as old polling)
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _emitUpdate();
    });
  }

  void _emitUpdate() {
    if (!_connected || _sessionId == null) return;

    _elapsedSeconds += 3;
    _energy = _elapsedSeconds * 0.025; // ~60kW → ~0.025 kWh/s
    _soc = (68 + _energy * 2.5).clamp(0.0, 100.0);
    final power = 45.0 + (_elapsedSeconds % 15);
    final cost = _energy * 14;

    // After ~30 minutes, emit completion
    if (_elapsedSeconds > 1800) {
      _tickTimer?.cancel();
      final summary = SessionSummary(
        sessionId: _sessionId!,
        chargerName: 'Phoenix Mall Charger',
        connectorType: 'CCS2',
        durationMinutes: (_elapsedSeconds / 60).ceil(),
        energyKwh: _energy,
        totalCost: cost,
        date: _formatDate(DateTime.now()),
        startTime: '14:00',
        endTime:
            '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      );
      _eventController.add(SessionStreamEvent(
        type: 'session_completed',
        summary: summary,
      ));
      return;
    }

    final data = SessionData(
      sessionId: _sessionId!,
      bookingId: 'BK-mock',
      chargerName: 'Phoenix Mall Charger',
      chargerAddress: 'Phoenix Mall, Lower Parel, Mumbai',
      connectorType: 'CCS2',
      powerKw: 60,
      slotStart: '14:00',
      slotEnd: '15:00',
      status: _elapsedSeconds > 0 ? SessionStatus.charging : SessionStatus.checkedIn,
      batteryPercent: _soc,
      energyKwh: _energy,
      currentPowerKw: power,
      runningCost: cost,
      costPerKwh: 14,
      elapsedSeconds: _elapsedSeconds,
      estimatedRemainingMinutes: ((1800 - _elapsedSeconds) / 60).ceil(),
      sessionStartedAt: DateTime.now().subtract(Duration(seconds: _elapsedSeconds)),
      lastUpdated: DateTime.now(),
    );

    _eventController.add(SessionStreamEvent(
      type: 'status_update',
      sessionData: data,
    ));
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _tickTimer?.cancel();
    _tickTimer = null;
    _sessionId = null;
    _elapsedSeconds = 0;
    _soc = 68;
    _energy = 0;
    _setState(WebSocketConnectionState.disconnected);
  }

  @override
  void sendPing() {
    if (!_connected) return;
    // Mock pong — no-op
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    _stateController.close();
  }

  void _setState(WebSocketConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// JSON Parsing Helpers
// ═════════════════════════════════════════════════════════════════════════════

SessionData _parseSessionData(Map<String, dynamic> json) {
  return SessionData(
    sessionId: json['sessionId'] as String? ?? '',
    bookingId: json['bookingId'] as String? ?? '',
    chargerName: json['chargerName'] as String? ?? '',
    chargerAddress: json['chargerAddress'] as String? ?? '',
    connectorType: json['connectorType'] as String? ?? '',
    powerKw: (json['powerKw'] as num?)?.toDouble() ?? 0,
    slotStart: json['slotStart'] as String? ?? '',
    slotEnd: json['slotEnd'] as String? ?? '',
    status: _parseSessionStatus(json['status'] as String?),
    batteryPercent: (json['batteryPercent'] as num?)?.toDouble() ?? 0,
    energyKwh: (json['energyKwh'] as num?)?.toDouble() ?? 0,
    currentPowerKw: (json['currentPowerKw'] as num?)?.toDouble() ?? 0,
    runningCost: (json['runningCost'] as num?)?.toDouble() ?? 0,
    costPerKwh: (json['costPerKwh'] as num?)?.toDouble() ?? 14,
    elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
    estimatedRemainingMinutes: json['estimatedRemainingMinutes'] as int? ?? 0,
    sessionStartedAt: json['sessionStartedAt'] != null
        ? DateTime.tryParse(json['sessionStartedAt'] as String)
        : null,
    lastUpdated: json['lastUpdated'] != null
        ? DateTime.tryParse(json['lastUpdated'] as String)
        : DateTime.now(),
  );
}

SessionSummary _parseSessionSummary(Map<String, dynamic> json) {
  return SessionSummary(
    sessionId: json['sessionId'] as String? ?? '',
    chargerName: json['chargerName'] as String? ?? '',
    connectorType: json['connectorType'] as String? ?? '',
    durationMinutes: json['durationMinutes'] as int? ?? 0,
    energyKwh: (json['energyKwh'] as num?)?.toDouble() ?? 0,
    totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
    date: json['date'] as String? ?? '',
    startTime: json['startTime'] as String? ?? '',
    endTime: json['endTime'] as String? ?? '',
    rating: json['rating'] as int?,
  );
}

SessionStatus _parseSessionStatus(String? status) {
  switch (status) {
    case 'checked_in':
      return SessionStatus.checkedIn;
    case 'charging':
      return SessionStatus.charging;
    case 'completed':
      return SessionStatus.completed;
    case 'failed':
      return SessionStatus.failed;
    case 'cancelled':
      return SessionStatus.cancelled;
    default:
      return SessionStatus.checkedIn;
  }
}
