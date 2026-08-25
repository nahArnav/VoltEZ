import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voltez_frontend/screens/dashboard/availability_scheduler_screen.dart';
import 'package:voltez_frontend/services/business_api.dart';

class MockBusinessApi extends Mock implements BusinessApi {}

void main() {
  late MockBusinessApi mockApi;

  final sampleChargers = [
    Charger(
      id: 'ch-01',
      name: 'Bay 01 • DC Fast',
      power: 60,
      status: 'active',
      reliability: 0.98,
      ports: [Port(id: 'p1', name: 'CCS2', status: 'available')],
    ),
    Charger(
      id: 'ch-02',
      name: 'Bay 02 • AC',
      power: 22,
      status: 'active',
      reliability: 0.95,
      ports: [Port(id: 'p2', name: 'Type 2', status: 'available')],
    ),
  ];

  final sampleSlots = [
    AvailabilitySlot(
      id: 'slot_06',
      startTime: '06:00',
      endTime: '07:00',
      pricePerKwh: 16.0,
      isAvailable: true,
      isPeak: false,
    ),
    AvailabilitySlot(
      id: 'slot_17',
      startTime: '17:00',
      endTime: '18:00',
      pricePerKwh: 22.0,
      isAvailable: true,
      isPeak: true,
    ),
  ];

  setUp(() {
    mockApi = MockBusinessApi();

    when(() => mockApi.loadDashboard()).thenAnswer(
      (_) async => DashboardSnapshot(
        businessName: 'VoltHub Prime',
        totalRevenue: 100000,
        energyDispensed: 1200,
        activeChargersCount: 2,
        chargers: sampleChargers,
      ),
    );

    when(() => mockApi.getAvailabilitySlots(
          chargerId: any(named: 'chargerId'),
          date: any(named: 'date'),
        )).thenAnswer((_) async => sampleSlots);

    when(() => mockApi.updateAvailabilitySlots(
          chargerId: any(named: 'chargerId'),
          date: any(named: 'date'),
          slots: any(named: 'slots'),
        )).thenAnswer((_) async => true);
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(home: child);
  }

  group('AvailabilitySchedulerScreen Widget Tests', () {
    testWidgets('Renders chargers, date selector, and initial slots list', (tester) async {
      await tester.pumpWidget(
        createTestWidget(AvailabilitySchedulerScreen(api: mockApi)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Availability & Pricing'), findsOneWidget);
      expect(find.text('Bay 01 • DC Fast'), findsOneWidget);
      expect(find.text('06:00 – 07:00'), findsOneWidget);
      expect(find.text('17:00 – 18:00'), findsOneWidget);
      expect(find.text('PEAK SURGE'), findsOneWidget);
    });

    testWidgets('Selecting a date triggers slot refetching for that date', (tester) async {
      await tester.pumpWidget(
        createTestWidget(AvailabilitySchedulerScreen(api: mockApi)),
      );
      await tester.pumpAndSettle();

      // Tap on second day in the horizontal date picker
      final dateItems = find.byType(GestureDetector);
      await tester.tap(dateItems.at(3));
      await tester.pumpAndSettle();

      verify(() => mockApi.getAvailabilitySlots(
            chargerId: any(named: 'chargerId'),
            date: any(named: 'date'),
          )).called(greaterThanOrEqualTo(1));
    });

    testWidgets('Toggling slot availability switch updates slot state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(AvailabilitySchedulerScreen(api: mockApi)),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch).first;
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isFalse);
    });

    testWidgets('Opens price edit dialog and applies new price rate to the slot', (tester) async {
      await tester.pumpWidget(
        createTestWidget(AvailabilitySchedulerScreen(api: mockApi)),
      );
      await tester.pumpAndSettle();

      // Tap edit price button for 06:00-07:00 slot (₹16.0)
      await tester.tap(find.text('₹16.0'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Slot Rate (06:00 - 07:00)'), findsOneWidget);

      // Enter new price in the dialog
      final dialogInput = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogInput, '19.5');
      await tester.tap(find.text('APPLY'));
      await tester.pumpAndSettle();

      expect(find.text('₹19.5'), findsOneWidget);
    });
  });
}