// ignore_for_file: constant_identifier_names
// UPPER_CASE enum values intentionally match backend JSON strings.

/// VoltEZ Data Models
///
/// Shared between Driver and Business sides.
/// Backend-aligned models with backward-compatible aliases for existing screens.
library;

import 'package:flutter/material.dart';

// ─── User / Auth ───
// Backend: UserRole enum = "DRIVER" | "OWNER" | "ADMIN"

enum AccountRole { driver, owner, admin }

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final AccountRole role;
  final String verificationStatus;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.verificationStatus = 'unverified',
    this.createdAt,
  });

  // ─── Backward-compat ───
  String get idString => id;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        role: _parseUserRole(json['role'] as String?),
        verificationStatus: json['verification_status'] as String? ?? 'unverified',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'verification_status': verificationStatus,
      };
}

AccountRole _parseUserRole(String? role) {
  switch (role) {
    case 'DRIVER':
    case 'driver':
      return AccountRole.driver;
    case 'OWNER':
    case 'owner':
      return AccountRole.owner;
    case 'ADMIN':
    case 'admin':
      return AccountRole.admin;
    default:
      return AccountRole.driver;
  }
}

// ─── Vehicle ───
// Backend: { id: int, user_id, make, model, battery_kwh, connector_types: List[str], ... }

class Vehicle {
  final String id;
  final String userId;
  final String make;
  final String model;
  final double batteryKwh;
  final List<String> connectorTypes;
  final double? maxAcKw;
  final double? maxDcKw;
  final double? estimatedRangeKm;
  final DateTime? createdAt;

  const Vehicle({
    required this.id,
    required this.userId,
    required this.make,
    required this.model,
    required this.batteryKwh,
    required this.connectorTypes,
    this.maxAcKw,
    this.maxDcKw,
    this.estimatedRangeKm,
    this.createdAt,
  });

  String get displayName => '$make $model';
  String get primaryConnector => connectorTypes.isNotEmpty ? connectorTypes.first : 'Unknown';

  // ─── Backward-compat for old screens ───
  double get batteryCapacityKwh => batteryKwh;
  String get connectorType => primaryConnector;
  int get year => createdAt?.year ?? 2024;

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        make: json['make'] as String,
        model: json['model'] as String,
        batteryKwh: (json['battery_kwh'] as num).toDouble(),
        connectorTypes: (json['connector_types'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            (json['connector_type_ids'] as List<dynamic>?)
                ?.map((e) => _connectorNameFromId((e as num).toInt()))
                .toList() ?? [],
        maxAcKw: (json['max_ac_kw'] as num?)?.toDouble(),
        maxDcKw: (json['max_dc_kw'] as num?)?.toDouble(),
        estimatedRangeKm: (json['estimated_range_km'] as num?)?.toDouble(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'battery_kwh': batteryKwh,
        'connector_type_ids': connectorTypes.map(_connectorIdFromName).toList(),
        if (maxAcKw != null) 'max_ac_kw': maxAcKw,
        if (maxDcKw != null) 'max_dc_kw': maxDcKw,
        if (estimatedRangeKm != null) 'estimated_range_km': estimatedRangeKm,
      };
}

// ─── Charger ───
// Backend: { id: int, business_id, name, power_kw, access_type, base_price,
//   status: "active"|"paused"|"inactive", reliability_score, latitude, longitude,
//   ports: List[ChargerPortResponse], amenities? (comma-separated str) }

enum ChargerOperationalStatus { active, paused, inactive }
enum PortStatus { available, occupied, offline, unknown }

/// Backward-compatible connector type enum (legacy screens reference this).
/// Backend uses plain strings: "CCS2", "Type2", "CHAdeMO", etc.
enum ConnectorType { ccs2, type2, chademo, gbT, type1 }

/// Backward-compatible charger status enum (legacy screens reference this).
/// Backend uses: "active"/"paused"/"inactive" for charger status,
/// and "available"/"occupied"/"offline"/"unknown" for port status.
enum ChargerStatus { available, busy, offline, maintenance }

String connectorTypeLabel(String type) {
  switch (type) {
    case 'CCS2': return 'CCS2';
    case 'Type2': return 'Type 2';
    case 'Type 2': return 'Type 2';
    case 'CHAdeMO': return 'CHAdeMO';
    case 'GB_T': return 'GB/T';
    case 'Type1': return 'Type 1';
    default: return type;
  }
}

class ChargerPort {
  final String id;
  final String chargerId;
  final String connectorType;
  final double maxPowerKw;
  final String status;
  final DateTime? createdAt;

  const ChargerPort({
    required this.id,
    required this.chargerId,
    required this.connectorType,
    required this.maxPowerKw,
    required this.status,
    this.createdAt,
  });

  bool get isAvailable => status == 'available';

  factory ChargerPort.fromJson(Map<String, dynamic> json) => ChargerPort(
        id: json['id']?.toString() ?? '',
        chargerId: json['charger_id']?.toString() ?? '',
        connectorType: json['connector_type'] as String? ??
            _connectorNameFromId((json['connector_type_id'] as num?)?.toInt() ?? 1),
        maxPowerKw: (json['max_power_kw'] as num).toDouble(),
        status: json['status'] as String? ??
            ((json['is_active'] as bool? ?? true) ? 'available' : 'offline'),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class Charger {
  final String id;
  final String businessId;
  final String name;
  final String? address; // Not in backend — may be computed from lat/lng or omitted
  final double latitude;
  final double longitude;
  final double powerKw;
  final String accessType;
  final double basePrice; // INR per kWh
  final String status; // "active", "paused", "inactive"
  final double reliabilityScore; // 0.0 – 1.0
  final String? parkingInfo;
  final String? amenities; // comma-separated string
  final List<ChargerPort> ports;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ─── Backward-compat fields for legacy screens ───
  final List<ConnectorType> _legacyConnectors;
  final ChargerStatus _legacyStatus;

  const Charger({
    required this.id,
    this.businessId = '',
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.powerKw,
    this.accessType = 'public',
    this.basePrice = 0,
    this.status = 'active',
    this.reliabilityScore = 0.5,
    this.parkingInfo,
    this.amenities,
    this.ports = const [],
    this.createdAt,
    this.updatedAt,
    List<ConnectorType> connectors = const [],
    ChargerStatus chargerStatus = ChargerStatus.available,
  }) : _legacyConnectors = connectors,
       _legacyStatus = chargerStatus;

  /// Backward-compat: display status for UI.
  String get displayStatus {
    switch (status) {
      case 'available':
      case 'active': return 'Available';
      case 'unavailable':
      case 'paused': return 'Paused';
      case 'offline':
      case 'inactive': return 'Offline';
      case 'maintenance': return 'Maintenance';
      default: return status;
    }
  }

  /// Connector types derived from ports.
  List<String> get connectorTypes =>
      ports.map((p) => p.connectorType).toSet().toList();

  /// Highest power port.
  double get maxPortPower =>
      ports.isEmpty ? powerKw : ports.map((p) => p.maxPowerKw).reduce((a, b) => a > b ? a : b);

  /// Parsed amenities list from comma-separated string.
  List<String> get amenitiesList =>
      amenities?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [];

  /// Backward-compat: rating (use reliabilityScore * 5 as proxy).
  double get rating =>
      ((reliabilityScore > 1 ? reliabilityScore / 100 : reliabilityScore) * 5)
          .clamp(0.0, 5.0);

  /// Backward-compat: totalRatings (not in backend — return 0).
  int get totalRatings => 0;

  /// Backward-compat: pricePerKwh (backend uses basePrice).
  double get pricePerKwh => basePrice;

  /// Backward-compat: connectors list (derived from ports or legacy).
  List<ConnectorType> get connectors =>
      ports.isNotEmpty
          ? ports.map((p) => _connectorTypeFromString(p.connectorType)).toList()
          : _legacyConnectors;

  /// Backward-compat: ChargerStatus (derived from backend status string).
  ChargerStatus get chargerStatus => _legacyStatus;

  ConnectorType _connectorTypeFromString(String s) {
    switch (s) {
      case 'CCS2': return ConnectorType.ccs2;
      case 'Type2': case 'Type 2': return ConnectorType.type2;
      case 'CHAdeMO': return ConnectorType.chademo;
      case 'GB_T': return ConnectorType.gbT;
      case 'Type1': return ConnectorType.type1;
      default: return ConnectorType.ccs2;
    }
  }

  factory Charger.fromJson(Map<String, dynamic> json) {
    // Handle legacy connectors list (old frontend format)
    final legacyConnectors = (json['connectors'] as List<dynamic>?)
            ?.map((e) {
              final s = e as String;
              switch (s) {
                case 'ccs2': return ConnectorType.ccs2;
                case 'type2': return ConnectorType.type2;
                case 'chademo': return ConnectorType.chademo;
                case 'gbT': return ConnectorType.gbT;
                case 'type1': return ConnectorType.type1;
                default: return ConnectorType.ccs2;
              }
            }).toList() ?? [];

    // Handle legacy status enum (old frontend format)
    final statusStr = json['status'] as String? ?? 'active';
    ChargerStatus legacyStatus;
    switch (statusStr) {
      case 'available': legacyStatus = ChargerStatus.available; break;
      case 'unavailable': legacyStatus = ChargerStatus.busy; break;
      case 'busy': legacyStatus = ChargerStatus.busy; break;
      case 'offline': legacyStatus = ChargerStatus.offline; break;
      case 'maintenance': legacyStatus = ChargerStatus.maintenance; break;
      case 'active': legacyStatus = ChargerStatus.available; break;
      case 'paused': legacyStatus = ChargerStatus.busy; break;
      case 'inactive': legacyStatus = ChargerStatus.offline; break;
      default: legacyStatus = ChargerStatus.offline;
    }

    // Handle amenities as list or string
    String? amenitiesStr;
    if (json['amenities'] is String) {
      amenitiesStr = json['amenities'] as String;
    } else if (json['amenities'] is List) {
      amenitiesStr = (json['amenities'] as List).join(', ');
    }

    return Charger(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      powerKw: (json['power_kw'] as num?)?.toDouble() ?? (json['powerKw'] as num?)?.toDouble() ?? 0,
      accessType: json['access_type'] as String? ??
          json['charger_type'] as String? ?? 'public',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? (json['pricePerKwh'] as num?)?.toDouble() ?? 0,
      status: statusStr,
      reliabilityScore: (json['reliability_score'] as num?)?.toDouble() ?? 0.5,
      parkingInfo: json['parking_info'] as String?,
      amenities: amenitiesStr,
      ports: (json['ports'] as List<dynamic>?)
              ?.map((e) => ChargerPort.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      connectors: legacyConnectors,
      chargerStatus: legacyStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_id': businessId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'power_kw': powerKw,
        'access_type': accessType,
        'base_price': basePrice,
        'status': status,
        'reliability_score': reliabilityScore,
        'amenities': amenities,
        'ports': ports.map((p) => {
          'id': p.id, 'charger_id': p.chargerId,
          'connector_type': p.connectorType, 'max_power_kw': p.maxPowerKw, 'status': p.status,
        }).toList(),
      };
}

// ─── Booking ───
// Backend: BookingStatus = PENDING | HELD | PAYMENT_PENDING | CONFIRMED |
//   CANCELLED | EXPIRED | FAILED | NO_SHOW | CHECKED_IN | CHARGING | COMPLETED

enum BookingStatus {
  PENDING, HELD, PAYMENT_PENDING, CONFIRMED, CANCELLED,
  EXPIRED, FAILED, NO_SHOW, CHECKED_IN, CHARGING, COMPLETED,
}

BookingStatus parseBookingStatus(String? status) {
  if (status == null) return BookingStatus.PENDING;
  return BookingStatus.values.firstWhere(
    (e) => e.name == status.toUpperCase(),
    orElse: () => BookingStatus.PENDING,
  );
}

class Booking {
  final String id;
  final String userId;
  final String? vehicleId;
  final String portId;
  final DateTime startAt;
  final DateTime endAt;
  final BookingStatus status;
  final DateTime? holdExpiresAt;
  final Map<String, dynamic>? quoteSnapshot;
  final String? idempotencyKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Booking({
    required this.id,
    required this.userId,
    this.vehicleId,
    required this.portId,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.holdExpiresAt,
    this.quoteSnapshot,
    this.idempotencyKey,
    this.createdAt,
    this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        vehicleId: json['vehicle_id']?.toString(),
        portId: (json['charger_port_id'] ?? json['port_id'])?.toString() ?? '',
        startAt: DateTime.parse(json['start_at'] as String),
        endAt: DateTime.parse(json['end_at'] as String),
        status: parseBookingStatus(json['status'] as String?),
        holdExpiresAt: json['hold_expires_at'] != null ? DateTime.tryParse(json['hold_expires_at'] as String) : null,
        quoteSnapshot: json['quote_snapshot'] as Map<String, dynamic>?,
        idempotencyKey: json['idempotency_key'] as String?,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      );
}

// ─── ChargingSession ───
// Backend: status = "checked_in" | "charging" | "completed" | "failed"

enum SessionStatus { checkedIn, charging, completed, failed }

SessionStatus parseSessionStatus(String? status) {
  switch (status) {
    case 'checked_in': return SessionStatus.checkedIn;
    case 'charging': return SessionStatus.charging;
    case 'completed': return SessionStatus.completed;
    case 'failed': return SessionStatus.failed;
    default: return SessionStatus.checkedIn;
  }
}

class ChargingSession {
  final String id;
  final String bookingId;
  final DateTime? checkInAt;
  final DateTime? startAt;
  final DateTime? endAt;
  final double? energyKwh;
  final double? finalAmount;
  final SessionStatus status;
  final DateTime? createdAt;

  const ChargingSession({
    required this.id,
    required this.bookingId,
    this.checkInAt,
    this.startAt,
    this.endAt,
    this.energyKwh,
    this.finalAmount,
    required this.status,
    this.createdAt,
  });

  int get elapsedSeconds {
    if (startAt == null) return 0;
    final end = endAt ?? DateTime.now();
    return end.difference(startAt!).inSeconds;
  }

  factory ChargingSession.fromJson(Map<String, dynamic> json) => ChargingSession(
        id: json['id']?.toString() ?? '',
        bookingId: json['booking_id']?.toString() ?? '',
        checkInAt: json['reserved_at'] != null ? DateTime.tryParse(json['reserved_at'] as String) : null,
        startAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'] as String) : null,
        endAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at'] as String) : null,
        energyKwh: (json['energy_kwh'] as num?)?.toDouble(),
        finalAmount: (json['amount'] as num?)?.toDouble(),
        status: parseSessionStatus(json['status'] as String?),
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}

String _connectorNameFromId(int id) {
  const names = <int, String>{
    1: 'CCS2',
    2: 'Type2',
    3: 'CHAdeMO',
    4: 'Bharat AC',
    5: 'Bharat DC',
  };
  return names[id] ?? 'Unknown';
}

int _connectorIdFromName(String name) {
  switch (name.toLowerCase().replaceAll(' ', '')) {
    case 'type2':
      return 2;
    case 'chademo':
      return 3;
    case 'bharatac':
      return 4;
    case 'bharatdc':
      return 5;
    case 'ccs2':
    default:
      return 1;
  }
}

// ─── Payment ───
// Backend: status = "pending" | "completed" | "failed" | "refunded"

enum PaymentStatus { pending, completed, failed, refunded }

class Payment {
  final int id;
  final int bookingId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? providerOrderId;
  final String? providerPaymentId;
  final DateTime? verifiedAt;
  final DateTime? createdAt;

  const Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.providerOrderId,
    this.providerPaymentId,
    this.verifiedAt,
    this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        bookingId: json['booking_id'] is int ? json['booking_id'] as int : 0,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'INR',
        status: PaymentStatus.values.firstWhere(
          (e) => e.name == json['status'], orElse: () => PaymentStatus.pending,
        ),
        providerOrderId: json['provider_order_id'] as String?,
        providerPaymentId: json['provider_payment_id'] as String?,
        verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'] as String) : null,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}

// ─── AvailabilityWindow ───
// Backend: { id: int, port_id, start_at, end_at, source?, price_override?, status?, ... }

class AvailabilityWindow {
  final int id;
  final int portId;
  final DateTime startAt;
  final DateTime endAt;
  final String? source;
  final double? priceOverride;
  final String? status;
  final bool isRecurring;
  final DateTime? createdAt;

  const AvailabilityWindow({
    required this.id,
    required this.portId,
    required this.startAt,
    required this.endAt,
    this.source,
    this.priceOverride,
    this.status,
    this.isRecurring = false,
    this.createdAt,
  });

  factory AvailabilityWindow.fromJson(Map<String, dynamic> json) => AvailabilityWindow(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        portId: json['port_id'] is int ? json['port_id'] as int : 0,
        startAt: DateTime.parse(json['start_at'] as String),
        endAt: DateTime.parse(json['end_at'] as String),
        source: json['source'] as String?,
        priceOverride: (json['price_override'] as num?)?.toDouble(),
        status: json['status'] as String?,
        isRecurring: json['is_recurring'] as bool? ?? false,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}

// ─── Review ───

class Review {
  final int id;
  final int sessionId;
  final int userId;
  final double rating;
  final String? comment;
  final List<String>? issueFlags;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.rating,
    this.comment,
    this.issueFlags,
    this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        sessionId: json['session_id'] is int ? json['session_id'] as int : 0,
        userId: json['user_id'] is int ? json['user_id'] as int : 0,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String?,
        issueFlags: (json['issue_flags'] as List<dynamic>?)?.map((e) => e as String).toList(),
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}

// ─── Business ───

class Business {
  final int id;
  final String name;
  final String email;
  final String? phone;

  const Business({required this.id, required this.name, required this.email, this.phone});

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
      );
}

// ─── Notification ───

class Notification {
  final int id;
  final int userId;
  final String type;
  final Map<String, dynamic>? payload;
  final String status;
  final DateTime? createdAt;

  const Notification({required this.id, required this.userId, required this.type, this.payload, this.status = 'pending', this.createdAt});

  factory Notification.fromJson(Map<String, dynamic> json) => Notification(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        userId: json['user_id'] is int ? json['user_id'] as int : 0,
        type: json['type'] as String,
        payload: json['payload'] as Map<String, dynamic>?,
        status: json['status'] as String? ?? 'pending',
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}

// ─── Recommendation ───

enum RecommendationPreference { fastest, cheapest, balanced, reliable }

class RecommendationReason {
  const RecommendationReason({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String description;
  final Color color;
}

class ChargerRecommendation {
  final Charger charger;
  final String reason;
  final double estimatedCost;
  final int estimatedTimeMinutes;
  final double confidenceScore;
  final int detourMinutes;
  final int predictedWaitMinutes;
  final double reliabilityScore;
  final bool connectorCompatible;
  final List<RecommendationReason> factors;

  const ChargerRecommendation({
    required this.charger,
    required this.reason,
    required this.estimatedCost,
    required this.estimatedTimeMinutes,
    required this.confidenceScore,
    this.detourMinutes = 0,
    this.predictedWaitMinutes = 0,
    this.reliabilityScore = 0.0,
    this.connectorCompatible = true,
    this.factors = const [],
  });
}

// ─── Analytics Summary (Business) ───

class AnalyticsSummary {
  final double revenueToday;
  final double revenueWeek;
  final double revenueMonth;
  final int sessionsToday;
  final int activeChargers;
  final double utilization;
  final List<HourlyData> peakHours;

  const AnalyticsSummary({
    required this.revenueToday,
    required this.revenueWeek,
    required this.revenueMonth,
    required this.sessionsToday,
    required this.activeChargers,
    required this.utilization,
    this.peakHours = const [],
  });
}

class HourlyData {
  final int hour;
  final double value;
  const HourlyData({required this.hour, required this.value});
}
