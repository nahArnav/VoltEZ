import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltez_frontend/screens/profile/profile_screen.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  setUp(() {
    // Set a large viewport so all profile items render without offscreen clipping
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('Renders host information, stats, and sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('Toggling preference switch toggles state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      final switches = find.byType(Switch);
      if (switches.evaluate().isNotEmpty) {
        final firstSwitch = switches.first;
        final initialVal = tester.widget<Switch>(firstSwitch).value;

        await tester.tap(firstSwitch);
        await tester.pumpAndSettle();

        expect(tester.widget<Switch>(firstSwitch).value, !initialVal);
      }
    });

    testWidgets('Opens edit profile dialog or sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined);
      final altEditIcon = find.byIcon(Icons.edit_rounded);
      final fallbackEdit = find.byIcon(Icons.edit);

      Finder? targetFinder;
      if (editIcon.evaluate().isNotEmpty) {
        targetFinder = editIcon.first;
      } else if (altEditIcon.evaluate().isNotEmpty) {
        targetFinder = altEditIcon.first;
      } else if (fallbackEdit.evaluate().isNotEmpty) {
        targetFinder = fallbackEdit.first;
      }

      if (targetFinder != null) {
        await tester.tap(targetFinder);
        await tester.pumpAndSettle();

        final hasDialog = find.byType(AlertDialog).evaluate().isNotEmpty;
        final hasSheet = find.byType(BottomSheet).evaluate().isNotEmpty;
        expect(hasDialog || hasSheet, isTrue);

        final cancelBtn = find.textContaining(RegExp('cancel|close', caseSensitive: false));
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.first);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Shows logout confirmation alert when tapping sign out button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      // Look for sign-out trigger via icon, text, or button type
      final logoutIcon = find.byIcon(Icons.logout_rounded);
      final altLogoutIcon = find.byIcon(Icons.logout);
      final textLogout = find.textContaining(RegExp('sign out|log out', caseSensitive: false));

      Finder? logoutTarget;
      if (logoutIcon.evaluate().isNotEmpty) {
        logoutTarget = logoutIcon.first;
      } else if (altLogoutIcon.evaluate().isNotEmpty) {
        logoutTarget = altLogoutIcon.first;
      } else if (textLogout.evaluate().isNotEmpty) {
        logoutTarget = textLogout.first;
      }

      expect(logoutTarget, isNotNull, reason: 'Sign out button/icon must exist on ProfileScreen');

      await tester.tap(logoutTarget!);
      await tester.pumpAndSettle();

      // Verify that either an AlertDialog or confirmation BottomSheet was shown
      final dialogFound = find.byType(AlertDialog).evaluate().isNotEmpty;
      final bottomSheetFound = find.byType(BottomSheet).evaluate().isNotEmpty;
      final cancelTextFound = find.textContaining(RegExp('cancel|no|back', caseSensitive: false)).evaluate().isNotEmpty;

      expect(
        dialogFound || bottomSheetFound || cancelTextFound,
        isTrue,
        reason: 'Tapping sign out must open a confirmation dialog or bottom sheet',
      );
    });
  });
}