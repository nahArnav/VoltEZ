import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voltez_frontend/models/user_profile_model.dart';
import 'package:voltez_frontend/screens/profile/profile_screen.dart';
import 'package:voltez_frontend/services/profile_services.dart';
import 'package:voltez_frontend/models/user_profile_model.dart'; 

// Mock definition
class MockProfileService extends Mock implements ProfileService {}
// 1. Define the Fake class
class FakeUserPreferences extends Fake implements UserPreferences {}

void main() {
  // 2. Register the fallback before running the tests
  setUpAll(() {
    registerFallbackValue(FakeUserPreferences());
  });

  // Keep your existing setUp, group, and test definitions below...

  late MockProfileService mockService;

  final sampleProfile = UserProfile(
    id: 'usr-001',
    name: 'Sachi Pate',
    email: 'sachi@voltez.com',
    phone: '+91 9876543210',
    businessName: 'ABC Motors EV Station',
    isVerifiedHost: true,
    stationSpecs: StationSpecs(
      location: 'Shivajinagar, Pune',
      activeChargers: 4,
      totalPowerKw: 180,
    ),
    stats: StationStats(
      totalRevenue: 128640,
      kwhDispensed: 8040,
      reliabilityPercent: 99,
    ),
    preferences: UserPreferences(
      notifications: true,
      location: true,
      darkMode: true,
    ),
  );

  setUp(() {
    mockService = MockProfileService();

    when(() => mockService.fetchProfile())
        .thenAnswer((_) async => sampleProfile);

    when(() => mockService.updateProfile(
          name: any(named: 'name'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          businessName: any(named: 'businessName'),
        )).thenAnswer((_) async => true);

    when(() => mockService.updatePreferences(any()))
        .thenAnswer((_) async => true);

    when(() => mockService.logout()).thenAnswer((_) async => true);
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('ProfileScreen Widget Tests', () {
    testWidgets('Renders host information, stats, and sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(ProfileScreen(service: mockService)));
      await tester.pumpAndSettle();

      expect(find.text('BUSINESS PROFILE'), findsOneWidget);
      expect(find.text('Sachi Pate'), findsOneWidget);
      expect(find.text('ABC Motors EV Station'), findsWidgets);
      expect(find.text('VERIFIED HOST'), findsOneWidget);
      expect(find.text('STATION OVERVIEW'), findsOneWidget);
      expect(find.text('ACCOUNT & EARNINGS'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('SIGN OUT'), findsOneWidget);
    });

    testWidgets('Toggling preference switch triggers service update', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(ProfileScreen(service: mockService)));
      await tester.pumpAndSettle();

      final firstSwitch = find.byType(Switch).first;
      expect(tester.widget<Switch>(firstSwitch).value, isTrue);

      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();

      verify(() => mockService.updatePreferences(any())).called(1);
    });

    testWidgets('Opens Account Information bottom sheet when tapped', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(ProfileScreen(service: mockService)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Account Information'));
      await tester.pumpAndSettle();

      expect(find.text('Owner Name'), findsOneWidget);
      expect(find.text('Station Location'), findsOneWidget);
      expect(find.text('EDIT ACCOUNT DETAILS'), findsOneWidget);
    });

    testWidgets('Opens edit profile dialog and saves changes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(ProfileScreen(service: mockService)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit Business Profile'), findsOneWidget);

      final nameField = find.widgetWithText(TextField, 'Sachi Pate');
      await tester.enterText(nameField, 'Sachi Updated');

      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();

      verify(() => mockService.updateProfile(
            name: 'Sachi Updated',
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            businessName: any(named: 'businessName'),
          )).called(1);
    });

    testWidgets('Shows logout confirmation alert when tapping sign out button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(ProfileScreen(service: mockService)));
      await tester.pumpAndSettle();

      final signOutBtn = find.text('SIGN OUT');
      expect(signOutBtn, findsOneWidget);

      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Sign out?'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });
  });
}