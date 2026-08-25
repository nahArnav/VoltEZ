import 'dart:async';

// ═════════════════════════════════════════════════════════════════════════════
// DTOs
// ═════════════════════════════════════════════════════════════════════════════

/// Slot status from the backend — distinguishes real-time from stale data.
enum SlotStatus { available, occupied, offline, unknown }

/// A single slot with its real-time status.
class SlotInfo {
  const SlotInfo({
    required this.id,
    required this.chargerId,
    required this.portName,
    required this.connectorType,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.pricePerKwh,
    this.lastUpdated,
  });

  final String id;
  final String chargerId;
  final String portName;
  final String connectorType;
  final DateTime startTime;
  final DateTime endTime;
  final SlotStatus status;
  final double pricePerKwh;
  final DateTime? lastUpdated;

  int get durationMinutes =>
      endTime.difference(startTime).inMinutes;

  bool get isAvailable => status == SlotStatus.available;

  /// Whether the data may be stale (> 60s old).
  bool get isStale =>
      lastUpdated != null &&
      DateTime.now().difference(lastUpdated!).inSeconds > 60;

  String get connectorLabel {
    switch (connectorType) {
      case 'ccs2':
        return 'CCS2';
      case 'type2':
        return 'Type 2';
      case 'chademo':
        return 'CHAdeMO';
      default:
        return connectorType;
    }
  }
}

/// Result from POST /bookings/hold.
class HoldResult {
  const HoldResult({
    required this.bookingId,
    required this.holdExpiresAt,
    required this.slot,
    required this.estimatedCost,
  });

  final String bookingId;
  final DateTime holdExpiresAt;
  final SlotInfo slot;
  final double estimatedCost;

  /// Seconds remaining until hold expires.
  int get secondsRemaining =>
      holdExpiresAt.difference(DateTime.now()).inSeconds.clamp(0, 600);
}

/// Result from POST /payments/create-order.
class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amount,
    required this.bookingId,
  });

  final String orderId;
  final double amount;
  final String bookingId;
}

/// Final confirmed booking data from the backend.
class ConfirmedBooking {
  const ConfirmedBooking({
    required this.bookingId,
    required this.chargerName,
    required this.chargerAddress,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.connectorType,
    required this.powerKw,
    required this.estimatedCost,
    required this.status,
  });

  final String bookingId;
  final String chargerName;
  final String chargerAddress;
  final String date;
  final String startTime;
  final String endTime;
  final String connectorType;
  final double powerKw;
  final double estimatedCost;
  final String status;
}

// ═════════════════════════════════════════════════════════════════════════════
// Abstract API
// ═════════════════════════════════════════════════════════════════════════════

abstract class BookingApi {
  /// GET /availability — fetch slots for a charger on a given date.
  Future<List<SlotInfo>> getAvailability(
    String chargerId,
    DateTime date,
  );

  /// POST /bookings/hold — hold a slot for the driver.
  /// Returns [HoldResult] with hold_expires_at from the backend.
  /// Throws if slot is already taken.
  Future<HoldResult> holdSlot({
    required String chargerId,
    required String slotId,
    required String connectorType,
  });

  /// POST /payments/create-order — create a payment order.
  Future<PaymentOrder> createPaymentOrder({
    required String bookingId,
    required double amount,
  });

  /// POST /payments/verify — verify payment completion.
  /// Returns confirmed booking data from backend.
  Future<ConfirmedBooking> verifyPayment({
    required String orderId,
    required String bookingId,
  });

  /// GET /bookings — fetch driver's booking history.
  Future<List<ConfirmedBooking>> getBookingHistory();
}

// ═════════════════════════════════════════════════════════════════════════════
// Live Implementation
// ═════════════════════════════════════════════════════════════════════════════

class LiveBookingApi implements BookingApi {
  LiveBookingApi();

  @override
  Future<List<SlotInfo>> getAvailability(
    String chargerId,
    DateTime date,
  ) async {
    // TODO: Wire to real backend
    throw UnimplementedError('LiveBookingApi not connected yet.');
  }

  @override
  Future<HoldResult> holdSlot({
    required String chargerId,
    required String slotId,
    required String connectorType,
  }) async {
    throw UnimplementedError('LiveBookingApi not connected yet.');
  }

  @override
  Future<PaymentOrder> createPaymentOrder({
    required String bookingId,
    required double amount,
  }) async {
    throw UnimplementedError('LiveBookingApi not connected yet.');
  }

  @override
  Future<ConfirmedBooking> verifyPayment({
    required String orderId,
    required String bookingId,
  }) async {
    throw UnimplementedError('LiveBookingApi not connected yet.');
  }

  @override
  Future<List<ConfirmedBooking>> getBookingHistory() async {
    throw UnimplementedError('LiveBookingApi not connected yet.');
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Mock Implementation
// ═════════════════════════════════════════════════════════════════════════════

class MockBookingApi implements BookingApi {
  @override
  Future<List<SlotInfo>> getAvailability(
    String chargerId,
    DateTime date,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate slots from 6 AM to 10 PM
    final slots = <SlotInfo>[];
    for (int hour = 6; hour <= 22; hour++) {
      final start = today.add(Duration(hours: hour));
      final end = start.add(const Duration(hours: 1));

      // Simulate some occupied/offline slots based on charger + time
      SlotStatus status;
      if (hour == 12 || hour == 15) {
        status = SlotStatus.occupied;
      } else if (hour == 20 || hour == 21) {
        status = SlotStatus.offline;
      } else if (hour < now.hour && today.isAtSameMomentAs(date)) {
        status = SlotStatus.unknown; // Past slots
      } else {
        status = SlotStatus.available;
      }

      // Price varies by time of day
      double price;
      if (hour >= 6 && hour < 10) {
        price = 12; // off-peak
      } else if (hour >= 10 && hour < 18) {
        price = 14; // standard
      } else {
        price = 16; // peak
      }

      slots.add(SlotInfo(
        id: 'slot_${chargerId}_${hour}',
        chargerId: chargerId,
        portName: 'Port ${hour - 5}',
        connectorType: hour % 2 == 0 ? 'ccs2' : 'type2',
        startTime: start,
        endTime: end,
        status: status,
        pricePerKwh: price,
        lastUpdated: DateTime.now().subtract(
          Duration(minutes: hour % 3 == 0 ? 90 : 5),
        ),
      ));
    }

    return slots;
  }

  @override
  Future<HoldResult> holdSlot({
    required String chargerId,
    required String slotId,
    required String connectorType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // 10% chance of slot already taken (simulates race condition)
    if (DateTime.now().millisecond % 10 == 0) {
      throw SlotTakenException(
        'This slot was just taken by another driver.',
      );
    }

    final now = DateTime.now();
    final holdExpiry = now.add(const Duration(minutes: 5));
    final parts = slotId.split('_');
    final hour = parts.length >= 3 ? int.tryParse(parts.last) ?? 14 : 14;

    final today = DateTime(now.year, now.month, now.day);
    final start = today.add(Duration(hours: hour));
    final end = start.add(const Duration(hours: 1));

    return HoldResult(
      bookingId: 'BK-${now.millisecondsSinceEpoch % 100000}',
      holdExpiresAt: holdExpiry,
      slot: SlotInfo(
        id: slotId,
        chargerId: chargerId,
        portName: 'Port ${hour - 5}',
        connectorType: connectorType,
        startTime: start,
        endTime: end,
        status: SlotStatus.available,
        pricePerKwh: hour >= 10 && hour < 18 ? 14 : 16,
        lastUpdated: now,
      ),
      estimatedCost: (hour >= 10 && hour < 18 ? 14.0 : 16.0) * 15, // ~15 kWh
    );
  }

  @override
  Future<PaymentOrder> createPaymentOrder({
    required String bookingId,
    required double amount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    return PaymentOrder(
      orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch % 100000}',
      amount: amount,
      bookingId: bookingId,
    );
  }

  @override
  Future<ConfirmedBooking> verifyPayment({
    required String orderId,
    required String bookingId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    // Simulate occasional payment failure (5%)
    if (DateTime.now().millisecond % 20 == 0) {
      throw PaymentFailedException(
        'Payment verification failed. Please retry.',
      );
    }

    final now = DateTime.now();
    return ConfirmedBooking(
      bookingId: bookingId,
      chargerName: 'Phoenix Mall Charger',
      chargerAddress: 'Phoenix Mall, Lower Parel, Mumbai',
      date: '${now.day} ${_monthName(now.month)} ${now.year}',
      startTime: '14:00',
      endTime: '15:00',
      connectorType: 'CCS2',
      powerKw: 60,
      estimatedCost: 210,
      status: 'confirmed',
    );
  }

  @override
  Future<List<ConfirmedBooking>> getBookingHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();
    return [
      ConfirmedBooking(
        bookingId: 'BK-1284',
        chargerName: 'Phoenix Mall Charger',
        chargerAddress: 'Phoenix Mall, Lower Parel',
        date: '${now.day - 2} ${_monthName(now.month - 1)} ${now.year}',
        startTime: '10:00',
        endTime: '11:00',
        connectorType: 'CCS2',
        powerKw: 60,
        estimatedCost: 168,
        status: 'completed',
      ),
      ConfirmedBooking(
        bookingId: 'BK-1285',
        chargerName: 'Bandra Hub DC Fast',
        chargerAddress: 'Bandra Kurla Complex',
        date: '${now.day - 5} ${_monthName(now.month - 1)} ${now.year}',
        startTime: '14:00',
        endTime: '15:00',
        connectorType: 'CCS2',
        powerKw: 150,
        estimatedCost: 216,
        status: 'completed',
      ),
      ConfirmedBooking(
        bookingId: 'BK-1290',
        chargerName: 'Tech Park Station',
        chargerAddress: 'Infosys Campus, Hinjewadi',
        date: '${now.day + 1} ${_monthName(now.month)} ${now.year}',
        startTime: '09:00',
        endTime: '10:00',
        connectorType: 'Type 2',
        powerKw: 30,
        estimatedCost: 88,
        status: 'confirmed',
      ),
    ];
  }

  String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Exceptions
// ═════════════════════════════════════════════════════════════════════════════

class SlotTakenException implements Exception {
  SlotTakenException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PaymentFailedException implements Exception {
  PaymentFailedException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HoldExpiredException implements Exception {
  HoldExpiredException(this.message);
  final String message;
  @override
  String toString() => message;
}
