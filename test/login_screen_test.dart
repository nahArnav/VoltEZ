import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltez_frontend/screens/auth/login_screen.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('Renders all input fields and sign-in button', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('COMMAND ACCESS'), findsOneWidget);
    });

    testWidgets('Triggers form validation error when submitting empty fields', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));

      // Tap Sign In without typing anything
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Shows error on invalid email format', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));

      final textFields = find.byType(TextFormField);

      // Enter invalid email
      await tester.enterText(textFields.first, 'invalid-email-string');
      await tester.enterText(textFields.last, 'password123');
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Please enter your password'), findsNothing);
    });

    testWidgets('Toggles password visibility on eye icon press', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));

      final passwordFieldFinder = find.byType(TextFormField).last;
      TextField passwordTextField = tester.widget<TextField>(
        find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)),
      );
      expect(passwordTextField.obscureText, isTrue);

      // Tap visibility toggle icon
      final visibilityIcon = find.byIcon(Icons.visibility_off);
      expect(visibilityIcon, findsOneWidget);
      await tester.tap(visibilityIcon);
      await tester.pumpAndSettle();

      passwordTextField = tester.widget<TextField>(
        find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)),
      );
      expect(passwordTextField.obscureText, isFalse);
    });
  });
}