import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Adjust imports based on your project paths
import 'package:voltez_frontend/models/user_profile_model.dart';
import 'package:voltez_frontend/models/recommendation.dart';

// 1. Define Mocks
class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
  });

  group('Business Models API Unit Tests (Network Mocking)', () {
    // ------------------------------------------------------------------------
    // TEST 1: User Profile / Business Host Mapping
    // ------------------------------------------------------------------------
    test('UserProfile.fromJson correctly parses mocked network response', () async {
      final mockApiResponse = {
        "id": "usr-8921",
        "name": "Sachi Pate",
        "email": "sachi.pate@email.com",
        "phone": "+91 98765 43210",
        "businessName": "ABC Motors EV Station",
        "isVerifiedHost": true,
        "stationSpecs": {
          "location": "Shivajinagar, Pune",
          "activeChargers": 3,
          "totalPowerKw": 180
        },
        "stats": {
          "totalRevenue": 128640.0,
          "kwhDispensed": 1247.0,
          "reliabilityPercent": 98
        },
        "preferences": {
          "notifications": true,
          "location": true,
          "darkMode": true
        }
      };

      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          data: mockApiResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/businesses/me/profile'),
        ),
      );

      // Perform network call simulation
      final response = await mockDio.get('/businesses/me/profile');
      final profile = UserProfile.fromJson(response.data);

      // Assertions
      expect(response.statusCode, 200);
      expect(profile.id, 'usr-8921');
      expect(profile.name, 'Sachi Pate');
      expect(profile.businessName, 'ABC Motors EV Station');
      expect(profile.isVerifiedHost, isTrue);
      expect(profile.stationSpecs.location, 'Shivajinagar, Pune');
      expect(profile.stationSpecs.activeChargers, 3);
      expect(profile.stationSpecs.totalPowerKw, 180);
      expect(profile.stats.totalRevenue, 128640.0);
      expect(profile.stats.reliabilityPercent, 98);
      expect(profile.preferences.darkMode, isTrue);
    });

    // ------------------------------------------------------------------------
    // TEST 2: AI Recommendations List Parsing
    // ------------------------------------------------------------------------
    test('Recommendation model list correctly parses from mocked endpoint', () async {
      final mockApiResponse = [
        {
          "id": "rec-123",
          "type": "availability_and_pricing",
          "date": "Tuesday • 25 Aug",
          "start": "14:00",
          "end": "17:00",
          "price": 20.0,
          "forecast": 18,
          "nearby": 5,
          "utilization": 0.82,
          "confidence": 0.91,
          "reason": "Demand is forecast to rise while nearby charging supply remains low.",
          "status": "pending"
        },
        {
          "id": "rec-124",
          "type": "availability_and_pricing",
          "date": "Thursday • 27 Aug",
          "start": "18:00",
          "end": "21:00",
          "price": 22.5,
          "forecast": 24,
          "nearby": 7,
          "utilization": 0.88,
          "confidence": 0.87,
          "reason": "Evening demand peak expected.",
          "status": "pending"
        }
      ];

      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          data: mockApiResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/businesses/me/recommendations'),
        ),
      );

      // Perform network call simulation
      final response = await mockDio.get('/businesses/me/recommendations');
      final List<dynamic> rawList = response.data;
      final recommendations = rawList.map((e) => Recommendation.fromJson(e)).toList();

      // Assertions
      expect(recommendations.length, 2);
      expect(recommendations.first.id, 'rec-123');
      expect(recommendations.first.price, 20.0);
      expect(recommendations.first.confidence, 0.91);
      expect(recommendations.first.status, 'pending');
      expect(recommendations.last.price, 22.5);
    });

    // ------------------------------------------------------------------------
    // TEST 3: AI Copilot Query Mutation / Parsing
    // ------------------------------------------------------------------------
    test('AI Copilot Query POST returns structured answer and deserializes correctly', () async {
      final mockApiResponse = {
        "response": "Based on current utilization patterns, raising daytime rates to ₹24/kWh could increase revenue by 14%.",
        "sessionId": "ses-99201",
        "tokensUsed": 142
      };

      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          data: mockApiResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/businesses/me/copilot-query'),
        ),
      );

      // Perform network mutation simulation
      final response = await mockDio.post(
        '/businesses/me/copilot-query',
        data: {'query': 'How to optimize pricing?'},
      );

      final reply = response.data['response'] as String;
      final tokens = response.data['tokensUsed'] as int;

      // Assertions
      expect(response.statusCode, 200);
      expect(reply, contains('₹24/kWh'));
      expect(tokens, 142);
      verify(() => mockDio.post(
            '/businesses/me/copilot-query',
            data: {'query': 'How to optimize pricing?'},
          )).called(1);
    });
  });
}