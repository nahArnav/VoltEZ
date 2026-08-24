import 'charger.dart';
import 'booking.dart';
import 'recommendation.dart';

/// Business profile snapshot returned by `GET /businesses/me`.
class BusinessSnapshot {
  const BusinessSnapshot({
    required this.businessName,
    required this.verification,
    required this.revenue,
    required this.utilization,
    required this.chargers,
    required this.bookings,
    required this.recommendations,
    this.id,
    this.address,
    this.latitude,
    this.longitude,
    this.category,
  });

  final String? id;
  final String businessName;
  final String verification;
  final double revenue;
  final double utilization;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? category;
  final List<Charger> chargers;
  final List<Booking> bookings;
  final List<Recommendation> recommendations;

  factory BusinessSnapshot.fromJson(Map<String, dynamic> json) =>
      BusinessSnapshot(
        id: json['id'] as String?,
        businessName: (json['business_name'] ?? json['businessName'] ?? '') as String,
        verification: (json['verification'] ?? 'pending') as String,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
        utilization: (json['utilization'] as num?)?.toDouble() ?? 0.0,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        category: json['category'] as String?,
        chargers: (json['chargers'] as List<dynamic>?)
                ?.map((c) => Charger.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        bookings: (json['bookings'] as List<dynamic>?)
                ?.map((b) => Booking.fromJson(b as Map<String, dynamic>))
                .toList() ??
            [],
        recommendations: (json['recommendations'] as List<dynamic>?)
                ?.map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'business_name': businessName,
        'verification': verification,
        'revenue': revenue,
        'utilization': utilization,
        if (address != null) 'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (category != null) 'category': category,
        'chargers': chargers.map((c) => c.toJson()).toList(),
        'bookings': bookings.map((b) => b.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
      };
}

/// Availability window for a charger port schedule.
class AvailabilityWindow {
  const AvailabilityWindow({
    this.id,
    required this.chargerPortId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.priceOverride,
    required this.isActive,
    this.repeatWeekly = false,
  });

  final String? id;
  final String chargerPortId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final double priceOverride;
  final bool isActive;
  final bool repeatWeekly;

  factory AvailabilityWindow.fromJson(Map<String, dynamic> json) =>
      AvailabilityWindow(
        id: json['id'] as String?,
        chargerPortId: (json['charger_port_id'] ?? '') as String,
        dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
        startTime: (json['start_time'] ?? '') as String,
        endTime: (json['end_time'] ?? '') as String,
        priceOverride: (json['price_override'] as num?)?.toDouble() ?? 0.0,
        isActive: (json['is_active'] as bool?) ?? true,
        repeatWeekly: (json['repeat_weekly'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'charger_port_id': chargerPortId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'price_override': priceOverride,
        'is_active': isActive,
        'repeat_weekly': repeatWeekly,
      };
}
