import 'api_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// DTOs
// ═════════════════════════════════════════════════════════════════════════════

/// Session status — mirrors backend truth.
enum SessionStatus {
  checkedIn,
  charging,
  completed,
  failed,
  cancelled,
}

/// Live session data from the backend.
class SessionData {
  const SessionData({
    required this.sessionId,
    required this.bookingId,
    required this.chargerName,
    required this.chargerAddress,
    required this.connectorType,
    required this.powerKw,
    required this.slotStart,
    required this.slotEnd,
    required this.status,
    this.batteryPercent = 0,
    this.energyKwh = 0,
    this.currentPowerKw = 0,
    this.runningCost = 0,
    this.costPerKwh = 14,
    this.elapsedSeconds = 0,
    this.estimatedRemainingMinutes = 0,
    this.sessionStartedAt,
    this.lastUpdated,
  });

  final String sessionId;
  final String bookingId;
  final String chargerName;
  final String chargerAddress;
  final String connectorType;
  final double powerKw;
  final String slotStart;
  final String slotEnd;
  final SessionStatus status;
  final double batteryPercent;
  final double energyKwh;
  final double currentPowerKw;
  final double runningCost;
  final double costPerKwh;
  final int elapsedSeconds;
  final int estimatedRemainingMinutes;
  final DateTime? sessionStartedAt;
  final DateTime? lastUpdated;

  bool get isStale =>
      lastUpdated != null &&
      DateTime.now().difference(lastUpdated!).inSeconds > 30;
}

/// Session summary after completion.
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.chargerName,
    required this.connectorType,
    required this.durationMinutes,
    required this.energyKwh,
    required this.totalCost,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.rating,
  });

  final String sessionId;
  final String chargerName;
  final String connectorType;
  final int durationMinutes;
  final double energyKwh;
  final double totalCost;
  final String date;
  final String startTime;
  final String endTime;
  final int? rating;
}

/// History item — combines booking and session data.
class DriverHistoryItem {
  const DriverHistoryItem({
    required this.id,
    required this.chargerName,
    required this.chargerAddress,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.connectorType,
    required this.powerKw,
    required this.durationMinutes,
    required this.energyKwh,
    required this.amountPaid,
    required this.status,
    this.rating,
  });

  final String id;
  final String chargerName;
  final String chargerAddress;
  final String date;
  final String startTime;
  final String endTime;
  final String connectorType;
  final double powerKw;
  final int durationMinutes;
  final double energyKwh;
  final double amountPaid;
  final String status; // completed, confirmed, cancelled, active
  final int? rating;
}

/// Rating submission payload.
class RatingPayload {
  const RatingPayload({
    required this.sessionId,
    required this.rating,
    this.issueCategory,
    this.feedback,
  });

  final String sessionId;
  final int rating;
  final String? issueCategory;
  final String? feedback;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'rating': rating,
        if (issueCategory != null) 'issueCategory': issueCategory,
        if (feedback != null) 'feedback': feedback,
      };
}

// ═════════════════════════════════════════════════════════════════════════════
// Abstract API
// ═════════════════════════════════════════════════════════════════════════════

abstract class SessionApi {
  /// POST /sessions/check-in — check in at the charger.
  /// Returns live session data.
  /// Throws if: too early, too late, booking not found, charger unavailable.
  Future<SessionData> checkIn(String bookingId);

  /// POST /sessions/:id/start — transition the backend session to charging.
  Future<SessionData> startSession(String sessionId);

  /// GET /sessions/:id/status — fetch live session status.
  Future<SessionData> getSessionStatus(String sessionId);

  /// POST /sessions/:id/end — end the charging session.
  Future<SessionSummary> endSession(String sessionId);

  /// POST /sessions/:id/rating — submit rating and optional issue report.
  Future<void> submitRating(RatingPayload payload);

  /// GET /sessions/history — fetch driver's full history (bookings + sessions).
  Future<List<DriverHistoryItem>> getHistory();
}

// ═════════════════════════════════════════════════════════════════════════════
// Live Implementation
// ═════════════════════════════════════════════════════════════════════════════

class LiveSessionApi implements SessionApi {
  LiveSessionApi(this._api);

  final ApiService _api;
  SessionData? _activeSession;

  @override
  Future<SessionData> checkIn(String bookingId) async {
    final response = await _api.checkIn(bookingId);
    _activeSession = _fromJson(response.data as Map<String, dynamic>);
    return _activeSession!;
  }

  @override
  Future<SessionData> startSession(String sessionId) async {
    final response = await _api.startCharging(sessionId);
    _activeSession = _fromJson(response.data as Map<String, dynamic>);
    return _activeSession!;
  }

  @override
  Future<SessionData> getSessionStatus(String sessionId) async {
    final response = await _api.getSession(sessionId);
    _activeSession = _fromJson(response.data as Map<String, dynamic>);
    return _activeSession!;
  }

  @override
  Future<SessionSummary> endSession(String sessionId) async {
    final response = await _api.completeSession(
      sessionId,
      _activeSession?.energyKwh ?? 0,
    );
    final json = response.data as Map<String, dynamic>;
    final completed = _fromJson(json);
    _activeSession = completed;
    final started = completed.sessionStartedAt;
    final ended = json['ended_at'] != null
        ? DateTime.parse(json['ended_at'] as String).toLocal()
        : DateTime.now();
    return SessionSummary(
      sessionId: completed.sessionId,
      chargerName: completed.chargerName,
      connectorType: completed.connectorType,
      durationMinutes: started == null ? 0 : ended.difference(started).inMinutes,
      energyKwh: completed.energyKwh,
      totalCost: completed.runningCost,
      date: '${ended.day}/${ended.month}/${ended.year}',
      startTime: completed.slotStart,
      endTime: _clock(ended),
    );
  }

  @override
  Future<void> submitRating(RatingPayload payload) async {
    await _api.submitSessionRating(payload.sessionId, {
      'session_id': payload.sessionId,
      'rating': payload.rating,
      if (payload.feedback != null) 'comment': payload.feedback,
      if (payload.issueCategory != null)
        'issue_flags': [payload.issueCategory],
    });
  }

  @override
  Future<List<DriverHistoryItem>> getHistory() async {
    final response = await _api.getSessions();
    return (response.data as List<dynamic>).map((item) {
      final json = item as Map<String, dynamic>;
      final start = DateTime.parse(json['reserved_at'] as String).toLocal();
      final end = json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String).toLocal()
          : start;
      return DriverHistoryItem(
        id: json['id'].toString(),
        chargerName: json['charger_name']?.toString() ?? 'Unknown charger',
        chargerAddress: json['charger_address']?.toString() ?? 'Unknown location',
        date: '${start.day}/${start.month}/${start.year}',
        startTime: _clock(start),
        endTime: _clock(end),
        connectorType: json['connector_type']?.toString() ?? 'Unknown connector',
        powerKw: (json['power_kw'] as num?)?.toDouble() ?? 0,
        durationMinutes: end.difference(start).inMinutes,
        energyKwh: (json['energy_kwh'] as num?)?.toDouble() ?? 0,
        amountPaid: (json['amount'] as num?)?.toDouble() ?? 0,
        status: json['status']?.toString() ?? 'reserved',
      );
    }).toList();
  }

  SessionData _fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    final started = json['started_at'] != null
        ? DateTime.parse(json['started_at'] as String).toLocal()
        : null;
    return SessionData(
      sessionId: json['id'].toString(),
      bookingId: json['booking_id']?.toString() ?? '',
      chargerName: json['charger_name']?.toString() ?? 'Unknown charger',
      chargerAddress: json['charger_address']?.toString() ?? 'Unknown location',
      connectorType: json['connector_type']?.toString() ?? 'Unknown connector',
      powerKw: (json['power_kw'] as num?)?.toDouble() ?? 0,
      slotStart: started == null ? '' : _clock(started),
      slotEnd: '',
      status: status == 'charging'
          ? SessionStatus.charging
          : status == 'completed'
              ? SessionStatus.completed
              : status == 'failed'
                  ? SessionStatus.failed
                  : SessionStatus.checkedIn,
      energyKwh: (json['energy_kwh'] as num?)?.toDouble() ?? 0,
      runningCost: (json['amount'] as num?)?.toDouble() ?? 0,
      costPerKwh: (json['price_per_kwh'] as num?)?.toDouble() ?? 0,
      currentPowerKw: status == 'charging' ? 1 : 0,
      sessionStartedAt: started,
      lastUpdated: DateTime.now(),
    );
  }

  static String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
class SessionApiException implements Exception {
  SessionApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
