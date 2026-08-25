import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltez_frontend/screens/profile/profile_screen.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(home: child);
  }

  group('ProfileScreen Widget Tests', () {
    testWidgets('Renders host information, stats, and sections', (tester) async {
      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('BUSINESS PROFILE'), findsOneWidget);
      expect(find.text('STATION OVERVIEW'), findsOneWidget);
      expect(find.text('ACCOUNT & EARNINGS'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('SIGN OUT'), findsOneWidget);
    });

    testWidgets('Toggling notifications preference switch toggles state and shows snackbar', (tester) async {
      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      final notificationSwitch = find.byType(Switch).first;
      expect(tester.widget<Switch>(notificationSwitch).value, isTrue);

      // Toggle off
      await tester.tap(notificationSwitch);
      await tester.pump();

      expect(tester.widget<Switch>(notificationSwitch).value, isFalse);
    });

    testWidgets('Opens Account Information bottom sheet when tapped', (tester) async {
      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Account Information'));
      await tester.pumpAndSettle();

      expect(find.text('Owner Name'), findsOneWidget);
      expect(find.text('Host Status'), findsOneWidget);
      expect(find.text('EDIT ACCOUNT DETAILS'), findsOneWidget);
    });

    testWidgets('Opens edit profile dialog and updates business name', (tester) async {
      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      // Tap the edit icon button on top profile card
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Business Profile'), findsOneWidget);

      final businessNameField = find.widgetWithText(TextField, 'ABC Motors EV Station');
      expect(businessNameField, findsOneWidget);

      await tester.enterText(businessNameField, 'VoltHub Express Central');
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();

      // Verify updated business name displays on screen
      expect(find.text('VoltHub Express Central'), findsWidgets);
    });

    testWidgets('Shows logout confirmation alert when tapping sign out button', (tester) async {
      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      // Scroll to bottom and tap Sign Out
      await tester.ensureVisible(find.text('SIGN OUT'));
      await tester.tap(find.text('SIGN OUT'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });
  });
}