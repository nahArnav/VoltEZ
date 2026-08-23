import 'package:flutter_test/flutter_test.dart';
import 'package:voltez_frontend/services/business_api.dart';

void main() {
  group('Business Owner Models & API Unit Tests', () {
    final api = BusinessApi();

    test('loadDashboard returns valid business snapshot', () async {
      final snapshot = await api.loadDashboard();

      expect(snapshot.businessName, equals('ABC Motors'));
      expect(snapshot.verification, equals('verified'));
      expect(snapshot.revenue, greaterThan(0));
      expect(snapshot.chargers, isNotEmpty);
      expect(snapshot.recommendations, isNotEmpty);
    });

    test('Charger port configuration validation', () async {
      const charger = Charger(
        id: 'c101',
        name: 'VoltHub Fast Charger',
        power: 120,
        status: 'active',
        reliability: 0.98,
        ports: [
          Port(name: 'CCS2', status: 'available'),
          Port(name: 'Type 2', status: 'occupied'),
        ],
      );

      expect(charger.power, equals(120));
      expect(charger.status, equals('active'));
      expect(charger.ports.length, equals(2));
      expect(charger.ports.first.name, equals('CCS2'));
    });

    test('Recommendation model calculates utilization bounds correctly', () async {
      const rec = Recommendation(
        id: 'rec-1',
        type: 'availability_and_pricing',
        title: 'Open availability 2-5 PM',
        recommendedStartAt: '14:00',
        recommendedEndAt: '17:00',
        suggestedPrice: 20.0,
        forecastDemand: 18,
        nearbySupply: 5,
        predictedUtilization: 0.82,
        confidence: 0.91,
        reason: 'High demand, low supply',
        status: 'pending',
      );

      expect(rec.confidence, greaterThanOrEqualTo(0.0));
      expect(rec.confidence, lessThanOrEqualTo(1.0));
      expect(rec.predictedUtilization, equals(0.82));
      expect(rec.suggestedPrice, equals(20.0));
    });
  });
}
