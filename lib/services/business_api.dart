import 'dart:async';

class BusinessApi {
  Future<BusinessSnapshot> loadDashboard() async {
    await Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    return const BusinessSnapshot(
      businessName: 'ABC Motors',
      verification: 'verified',
      revenue: 18420,
      utilization: 0.76,
      chargers: [
        Charger(
          id: 'c1',
          name: 'Charger 01',
          power: 60,
          status: 'active',
          reliability: 0.98,
          ports: [
            Port(
              name: 'CCS2',
              status: 'available',
            ),
            Port(
              name: 'Type 2',
              status: 'occupied',
            ),
          ],
        ),
        Charger(
          id: 'c2',
          name: 'Charger 02',
          power: 22,
          status: 'paused',
          reliability: 0.87,
          ports: [
            Port(
              name: 'Type 2',
              status: 'offline',
            ),
          ],
        ),
      ],
      bookings: [
        Booking(
          id: 'BK-1284',
          vehicle: 'Tata Nexon EV',
          slot: '10:00 – 11:00',
          status: 'CONFIRMED',
          amount: 420,
        ),
        Booking(
          id: 'BK-1285',
          vehicle: 'MG ZS EV',
          slot: '12:30 – 13:30',
          status: 'HELD',
          amount: 510,
        ),
      ],
      recommendations: [
        Recommendation(
          id: 'rec-123',
          type: 'availability_and_pricing',
          title: 'Open availability',
          recommendedStartAt: '14:00',
          recommendedEndAt: '17:00',
          suggestedPrice: 20,
          forecastDemand: 18,
          nearbySupply: 5,
          predictedUtilization: 0.82,
          confidence: 0.91,
          reason:
              'Demand is forecast to rise while nearby supply remains low.',
          status: 'pending',
        ),
      ],
    );
  }

  Future<void> recommendationAction(
    String id,
    String action,
  ) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 200),
    );
  }

  Future<void> cancelBooking(String id) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 200),
    );
  }
}

class BusinessSnapshot {
  const BusinessSnapshot({
    required this.businessName,
    required this.verification,
    required this.revenue,
    required this.utilization,
    required this.chargers,
    required this.bookings,
    required this.recommendations,
  });

  final String businessName;
  final String verification;
  final double revenue;
  final double utilization;

  final List<Charger> chargers;
  final List<Booking> bookings;
  final List<Recommendation> recommendations;
}

class Charger {
  const Charger({
    required this.id,
    required this.name,
    required this.power,
    required this.status,
    required this.reliability,
    required this.ports,
  });

  final String id;
  final String name;
  final int power;
  final String status;
  final double reliability;
  final List<Port> ports;
}

class Port {
  const Port({
    required this.name,
    required this.status,
  });

  final String name;
  final String status;
}

class Booking {
  const Booking({
    required this.id,
    required this.vehicle,
    required this.slot,
    required this.status,
    required this.amount,
  });

  final String id;
  final String vehicle;
  final String slot;
  final String status;
  final double amount;
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.type,
    required this.title,
    required this.recommendedStartAt,
    required this.recommendedEndAt,
    required this.suggestedPrice,
    required this.forecastDemand,
    required this.nearbySupply,
    required this.predictedUtilization,
    required this.confidence,
    required this.reason,
    required this.status,
  });

  final String id;
  final String type;

  final String title;
  final String recommendedStartAt;
  final String recommendedEndAt;

  final double suggestedPrice;
  final int forecastDemand;
  final int nearbySupply;

  final double predictedUtilization;
  final double confidence;

  final String reason;
  final String status;
}