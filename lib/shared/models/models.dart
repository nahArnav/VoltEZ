/// VoltEZ Data Models
///
/// Shared between Driver and Business sides.
library;

import 'package:flutter/material.dart';

// ─── User / Auth ───

enum AccountRole { driver, business }

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final AccountRole role;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        role: AccountRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => AccountRole.driver,
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'role': role.name,
      };
}

// ─── Charger ───

enum ChargerStatus { available, busy, offline, maintenance }

enum ConnectorType { ccs2, type2, chademo, gbT, type1 }

class Charger {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double powerKw;
  final double pricePerKwh;
  final ChargerStatus status;
  final List<ConnectorType> connectors;
  final List<String> amenities;
  final double rating;
  final int totalRatings;
  final String? imageUrl;
  final String? businessId;

  const Charger({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.powerKw,
    required this.pricePerKwh,
    required this.status,
    required this.connectors,
    this.amenities = const [],
    this.rating = 0.0,
    this.totalRatings = 0,
    this.imageUrl,
    this.businessId,
  });

  factory Charger.fromJson(Map<String, dynamic> json) => Charger(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        powerKw: (json['powerKw'] as num).toDouble(),
        pricePerKwh: (json['pricePerKwh'] as num).toDouble(),
        status: ChargerStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ChargerStatus.offline,
        ),
        connectors: (json['connectors'] as List<dynamic>?)
                ?.map((e) => ConnectorType.values.firstWhere(
                      (c) => c.name == e,
                      orElse: () => ConnectorType.ccs2,
                    ))
                .toList() ??
            [],
        amenities: (json['amenities'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        totalRatings: json['totalRatings'] as int? ?? 0,
        imageUrl: json['imageUrl'] as String?,
        businessId: json['businessId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'powerKw': powerKw,
        'pricePerKwh': pricePerKwh,
        'status': status.name,
        'connectors': connectors.map((e) => e.name).toList(),
        'amenities': amenities,
        'rating': rating,
        'totalRatings': totalRatings,
        'imageUrl': imageUrl,
        'businessId': businessId,
      };
}

// ─── Booking ───

enum BookingStatus { pending, confirmed, held, active, completed, cancelled }

class Booking {
  final String id;
  final String chargerId;
  final String chargerName;
  final String driverId;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;
  final double amount;
  final String? connectorType;

  const Booking({
    required this.id,
    required this.chargerId,
    required this.chargerName,
    required this.driverId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.amount,
    this.connectorType,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        chargerId: json['chargerId'] as String,
        chargerName: json['chargerName'] as String? ?? '',
        driverId: json['driverId'] as String? ?? '',
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        status: BookingStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => BookingStatus.pending,
        ),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        connectorType: json['connectorType'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chargerId': chargerId,
        'chargerName': chargerName,
        'driverId': driverId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'status': status.name,
        'amount': amount,
        'connectorType': connectorType,
      };
}

// ─── Slot ───

class Slot {
  final String id;
  final String chargerId;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAvailable;
  final double? priceOverride;

  const Slot({
    required this.id,
    required this.chargerId,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.priceOverride,
  });

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        id: json['id'] as String,
        chargerId: json['chargerId'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        isAvailable: json['isAvailable'] as bool? ?? true,
        priceOverride: (json['priceOverride'] as num?)?.toDouble(),
      );
}

// ─── Vehicle (Driver Onboarding) ───

class Vehicle {
  final String id;
  final String make;
  final String model;
  final int year;
  final double batteryCapacityKwh;
  final ConnectorType connectorType;

  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.batteryCapacityKwh,
    required this.connectorType,
  });

  String get displayName => '$year $make $model';
}

// ─── Business (Business Partner) ───

class Business {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final bool isVerified;
  final double rating;

  const Business({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.gstNumber,
    this.isVerified = false,
    this.rating = 0.0,
  });

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        gstNumber: json['gstNumber'] as String?,
        isVerified: json['isVerified'] as bool? ?? false,
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      );
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

// ─── AI Recommendation (Driver) ───

enum RecommendationPreference { fastest, cheapest, balanced, reliable }

/// A single explanation factor shown in the "Why this charger?" section.
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

  /// Extra fields for the detailed recommendation card.
  final int detourMinutes;
  final int predictedWaitMinutes;
  final double reliabilityScore; // 0.0 – 1.0
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
