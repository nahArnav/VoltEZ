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
  @override
  Future<SessionData> checkIn(String bookingId) async {
    throw UnimplementedError('LiveSessionApi not connected yet.');
  }

  @override
  Future<SessionData> getSessionStatus(String sessionId) async {
    throw UnimplementedError('LiveSessionApi not connected yet.');
  }

  @override
  Future<SessionSummary> endSession(String sessionId) async {
    throw UnimplementedError('LiveSessionApi not connected yet.');
  }

  @override
  Future<void> submitRating(RatingPayload payload) async {
    throw UnimplementedError('LiveSessionApi not connected yet.');
  }

  @override
  Future<List<DriverHistoryItem>> getHistory() async {
    throw UnimplementedError('LiveSessionApi not connected yet.');
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Mock Implementation
// ═════════════════════════════════════════════════════════════════════════════

class MockSessionApi implements SessionApi {
  SessionData? _activeSession;

  @override
  Future<SessionData> checkIn(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    // Simulate 5% chance of error
    if (DateTime.now().millisecond % 20 == 0) {
      throw SessionApiException(
        'Charger unavailable. The charger may be offline or under maintenance.',
      );
    }

    final now = DateTime.now();
    _activeSession = SessionData(
      sessionId: 'SES-${now.millisecondsSinceEpoch % 100000}',
      bookingId: bookingId,
      chargerName: 'Phoenix Mall Charger',
      chargerAddress: 'Phoenix Mall, Lower Parel, Mumbai',
      connectorType: 'CCS2',
      powerKw: 60,
      slotStart: '14:00',
      slotEnd: '15:00',
      status: SessionStatus.checkedIn,
      batteryPercent: 68,
      energyKwh: 0,
      currentPowerKw: 0,
      runningCost: 0,
      costPerKwh: 14,
      elapsedSeconds: 0,
      estimatedRemainingMinutes: 45,
      sessionStartedAt: now,
      lastUpdated: now,
    );

    return _activeSession!;
  }

  @override
  Future<SessionData> getSessionStatus(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (_activeSession == null || _activeSession!.sessionId != sessionId) {
      throw SessionApiException('Session not found.');
    }

    // Simulate charging progress
    final elapsed = _activeSession!.elapsedSeconds + 3;
    final energy = elapsed * 0.025; // ~60kW → ~0.025 kWh per second
    final soc = (68 + energy * 2.5).clamp(0, 100).toDouble();
    final power = 45.0 + (DateTime.now().millisecond % 15);
    final cost = energy * _activeSession!.costPerKwh;

    // After ~30 minutes, auto-complete
    if (elapsed > 1800) {
      _activeSession = SessionData(
        sessionId: sessionId,
        bookingId: _activeSession!.bookingId,
        chargerName: _activeSession!.chargerName,
        chargerAddress: _activeSession!.chargerAddress,
        connectorType: _activeSession!.connectorType,
        powerKw: _activeSession!.powerKw,
        slotStart: _activeSession!.slotStart,
        slotEnd: _activeSession!.slotEnd,
        status: SessionStatus.completed,
        batteryPercent: 100,
        energyKwh: energy,
        currentPowerKw: 0,
        runningCost: cost,
        costPerKwh: _activeSession!.costPerKwh,
        elapsedSeconds: elapsed,
        estimatedRemainingMinutes: 0,
        sessionStartedAt: _activeSession!.sessionStartedAt,
        lastUpdated: DateTime.now(),
      );
      return _activeSession!;
    }

    _activeSession = SessionData(
      sessionId: sessionId,
      bookingId: _activeSession!.bookingId,
      chargerName: _activeSession!.chargerName,
      chargerAddress: _activeSession!.chargerAddress,
      connectorType: _activeSession!.connectorType,
      powerKw: _activeSession!.powerKw,
      slotStart: _activeSession!.slotStart,
      slotEnd: _activeSession!.slotEnd,
      status: SessionStatus.charging,
      batteryPercent: soc,
      energyKwh: energy,
      currentPowerKw: power,
      runningCost: cost,
      costPerKwh: _activeSession!.costPerKwh,
      elapsedSeconds: elapsed,
      estimatedRemainingMinutes: ((1800 - elapsed) / 60).ceil(),
      sessionStartedAt: _activeSession!.sessionStartedAt,
      lastUpdated: DateTime.now(),
    );

    return _activeSession!;
  }

  @override
  Future<SessionSummary> endSession(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (_activeSession == null || _activeSession!.sessionId != sessionId) {
      throw SessionApiException('Session not found.');
    }

    final s = _activeSession!;
    final durationMinutes = (s.elapsedSeconds / 60).ceil();

    return SessionSummary(
      sessionId: sessionId,
      chargerName: s.chargerName,
      connectorType: s.connectorType,
      durationMinutes: durationMinutes,
      energyKwh: s.energyKwh,
      totalCost: s.runningCost,
      date: _formatDate(DateTime.now()),
      startTime: s.slotStart,
      endTime: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  Future<void> submitRating(RatingPayload payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // In production, this POSTs to backend. Success is implicit.
  }

  @override
  Future<List<DriverHistoryItem>> getHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final now = DateTime.now();
    return [
      DriverHistoryItem(
        id: 'SES-98712',
        chargerName: 'Phoenix Mall Charger',
        chargerAddress: 'Phoenix Mall, Lower Parel',
        date: _formatDate(now.subtract(const Duration(days: 1))),
        startTime: '14:00',
        endTime: '14:38',
        connectorType: 'CCS2',
        powerKw: 60,
        durationMinutes: 38,
        energyKwh: 15.2,
        amountPaid: 213,
        status: 'completed',
        rating: 5,
      ),
      DriverHistoryItem(
        id: 'SES-98654',
        chargerName: 'Highway Fast Charge',
        chargerAddress: 'Mumbai-Pune Expressway',
        date: _formatDate(now.subtract(const Duration(days: 3))),
        startTime: '10:00',
        endTime: '10:25',
        connectorType: 'CCS2',
        powerKw: 150,
        durationMinutes: 25,
        energyKwh: 28.4,
        amountPaid: 426,
        status: 'completed',
        rating: 4,
      ),
      DriverHistoryItem(
        id: 'BK-1290',
        chargerName: 'Tech Park Station',
        chargerAddress: 'Infosys Campus, Hinjewadi',
        date: _formatDate(now.add(const Duration(days: 1))),
        startTime: '09:00',
        endTime: '10:00',
        connectorType: 'Type 2',
        powerKw: 30,
        durationMinutes: 0,
        energyKwh: 0,
        amountPaid: 88,
        status: 'confirmed',
        rating: null,
      ),
      DriverHistoryItem(
        id: 'SES-98510',
        chargerName: 'Phoenix Mall Charger',
        chargerAddress: 'Phoenix Mall, Lower Parel',
        date: _formatDate(now.subtract(const Duration(days: 5))),
        startTime: '16:00',
        endTime: '16:45',
        connectorType: 'CCS2',
        powerKw: 60,
        durationMinutes: 45,
        energyKwh: 10.0,
        amountPaid: 140,
        status: 'completed',
        rating: null,
      ),
      DriverHistoryItem(
        id: 'BK-1280',
        chargerName: 'Bandra Hub DC Fast',
        chargerAddress: 'Bandra Kurla Complex',
        date: _formatDate(now.subtract(const Duration(days: 7))),
        startTime: '11:00',
        endTime: '12:00',
        connectorType: 'CCS2',
        powerKw: 150,
        durationMinutes: 0,
        energyKwh: 0,
        amountPaid: 0,
        status: 'cancelled',
        rating: null,
      ),
    ];
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
// Exceptions
// ═════════════════════════════════════════════════════════════════════════════

class SessionApiException implements Exception {
  SessionApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
