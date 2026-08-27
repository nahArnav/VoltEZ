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
    required String paymentId,
    required String signature,
  });

  /// POST /bookings/{id}/cancel — release a held/confirmed booking.
  Future<void> cancelBooking(String bookingId);

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
      final slotResponse = await _api.getPortSlots(portId, date);
      final openSlots = slotResponse.data as List<dynamic>? ?? const [];

      for (final rawSlot in openSlots) {
        final openSlot = rawSlot as Map<String, dynamic>;
        final start = DateTime.parse(openSlot['start_at'] as String).toLocal();
        final end = DateTime.parse(openSlot['end_at'] as String).toLocal();
        slots.add(SlotInfo(
          id: '$portId|${start.toUtc().toIso8601String()}|${end.toUtc().toIso8601String()}',
          chargerId: chargerId,
          portName: 'Port ${port['port_number']}',
          connectorType: _connectorName(
            (port['connector_type_id'] as num?)?.toInt() ?? 1,
          ),
          startTime: start,
          endTime: end,
          status: SlotStatus.available,
          pricePerKwh:
              (openSlot['price_per_kwh'] as num?)?.toDouble() ?? 15,
          lastUpdated: DateTime.now(),
        ));
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
        estimatedCost: (json['estimated_amount'] as num?)?.toDouble() ?? 0,
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
    required String paymentId,
    required String signature,
  }) async {
    await _api.verifyPayment({
      'booking_id': bookingId,
      'provider_order_id': orderId,
      'provider_payment_id': paymentId,
      'provider_signature': signature,
    });
    final response = await _api.getBooking(bookingId);
    final json = response.data as Map<String, dynamic>;
    final start = DateTime.parse(json['start_at'] as String).toLocal();
    final end = DateTime.parse(json['end_at'] as String).toLocal();
    return ConfirmedBooking(
      bookingId: json['id'].toString(),
      chargerName: 'VoltEZ charger',
      chargerAddress: 'Port ${json['charger_port_id']}',
      date: '${start.day}/${start.month}/${start.year}',
      startTime: _clock(start),
      endTime: _clock(end),
      connectorType: 'Connected port',
      powerKw: 0,
      estimatedCost: (json['estimated_amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'confirmed',
    );
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _api.cancelBooking(bookingId);
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
        estimatedCost: (json['estimated_amount'] as num?)?.toDouble() ?? 0,
        status: json['status']?.toString() ?? 'held',
      );
    }).toList();
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
