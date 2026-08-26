import 'dart:async';
import 'api_service.dart';

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
  LiveBookingApi(this._api);

  final ApiService _api;

  @override
  Future<List<SlotInfo>> getAvailability(
    String chargerId,
    DateTime date,
  ) async {
    final chargerResponse = await _api.getChargerById(chargerId);
    final charger = chargerResponse.data as Map<String, dynamic>;
    final ports = charger['ports'] as List<dynamic>? ?? const [];
    final slots = <SlotInfo>[];

    for (final rawPort in ports) {
      final port = rawPort as Map<String, dynamic>;
      if (!(port['is_active'] as bool? ?? true)) continue;
      final portId = port['id'].toString();
      final windowResponse = await _api.getPortAvailability(portId);
      final windows = windowResponse.data as List<dynamic>? ?? const [];

      for (final rawWindow in windows) {
        final window = rawWindow as Map<String, dynamic>;
        if ((window['day_of_week'] as num).toInt() != date.weekday - 1 ||
            (window['is_unavailable'] as bool? ?? false)) {
          continue;
        }
        final start = _combineDateAndTime(
          date,
          window['start_local_time'].toString(),
        );
        final end = _combineDateAndTime(
          date,
          window['end_local_time'].toString(),
        );
        var cursor = start;
        while (cursor.isBefore(end)) {
          final slotEnd = cursor.add(const Duration(hours: 1));
          if (slotEnd.isAfter(end)) break;
          if (slotEnd.isAfter(DateTime.now())) {
            slots.add(SlotInfo(
              id: '$portId|${cursor.toUtc().toIso8601String()}|${slotEnd.toUtc().toIso8601String()}',
              chargerId: chargerId,
              portName: 'Port ${port['port_number']}',
              connectorType: _connectorName(
                (port['connector_type_id'] as num?)?.toInt() ?? 1,
              ),
              startTime: cursor,
              endTime: slotEnd,
              status: SlotStatus.available,
              pricePerKwh: 15,
              lastUpdated: DateTime.now(),
            ));
          }
          cursor = slotEnd;
        }
      }
    }
    slots.sort((a, b) => a.startTime.compareTo(b.startTime));
    return slots;
  }

  @override
  Future<HoldResult> holdSlot({
    required String chargerId,
    required String slotId,
    required String connectorType,
  }) async {
    final parts = slotId.split('|');
    if (parts.length != 3) {
      throw const BookingApiException('Invalid availability slot.');
    }
    try {
      final response = await _api.createBooking({
        'charger_port_id': parts[0],
        'start_at': parts[1],
        'end_at': parts[2],
      });
      final json = response.data as Map<String, dynamic>;
      final slot = SlotInfo(
        id: slotId,
        chargerId: chargerId,
        portName: 'Port',
        connectorType: connectorType,
        startTime: DateTime.parse(parts[1]).toLocal(),
        endTime: DateTime.parse(parts[2]).toLocal(),
        status: SlotStatus.occupied,
        pricePerKwh: 15,
        lastUpdated: DateTime.now(),
      );
      return HoldResult(
        bookingId: json['id'].toString(),
        holdExpiresAt: json['hold_expires_at'] != null
            ? DateTime.parse(json['hold_expires_at'] as String).toLocal()
            : DateTime.now().add(const Duration(minutes: 10)),
        slot: slot,
        estimatedCost: 450,
      );
    } catch (error) {
      if (error.toString().contains('SLOT_UNAVAILABLE')) {
        throw const SlotTakenException(
          'This slot was just taken by another driver.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<PaymentOrder> createPaymentOrder({
    required String bookingId,
    required double amount,
  }) async {
    final response = await _api.createPaymentOrder({
      'booking_id': bookingId,
      'amount': amount,
      'currency': 'INR',
      'status': 'pending',
    });
    final json = response.data as Map<String, dynamic>;
    return PaymentOrder(
      orderId: json['provider_order_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? amount,
      bookingId: json['booking_id']?.toString() ?? bookingId,
    );
  }

  @override
  Future<ConfirmedBooking> verifyPayment({
    required String orderId,
    required String bookingId,
  }) async {
    throw const PaymentFailedException(
      'Payment confirmation is completed by the signed Razorpay webhook; '
      'no client-side verification endpoint exists.',
    );
  }

  @override
  Future<List<ConfirmedBooking>> getBookingHistory() async {
    final response = await _api.getDriverBookings();
    return (response.data as List<dynamic>).map((item) {
      final json = item as Map<String, dynamic>;
      final start = DateTime.parse(json['start_at'] as String).toLocal();
      final end = DateTime.parse(json['end_at'] as String).toLocal();
      return ConfirmedBooking(
        bookingId: json['id'].toString(),
        chargerName: 'Charger booking',
        chargerAddress: 'Port ${json['charger_port_id']}',
        date: '${start.day}/${start.month}/${start.year}',
        startTime: _clock(start),
        endTime: _clock(end),
        connectorType: 'See charger details',
        powerKw: 0,
        estimatedCost: 0,
        status: json['status']?.toString() ?? 'held',
      );
    }).toList();
  }

  static DateTime _combineDateAndTime(DateTime date, String time) {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static String _connectorName(int id) {
    return const <int, String>{
          1: 'CCS2',
          2: 'Type2',
          3: 'CHAdeMO',
          4: 'Bharat AC',
          5: 'Bharat DC',
        }[id] ??
        'Unknown';
  }

  static String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
        id: 'slot_${chargerId}_$hour',
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
  const SlotTakenException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PaymentFailedException implements Exception {
  const PaymentFailedException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HoldExpiredException implements Exception {
  const HoldExpiredException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BookingApiException implements Exception {
  const BookingApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
