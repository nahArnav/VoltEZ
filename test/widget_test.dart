import 'package:flutter_test/flutter_test.dart';
import 'package:voltez_frontend/app.dart';

void main() {
  testWidgets('VoltezApp renders splash screen initially', (WidgetTester tester) async {
    await tester.pumpWidget(const VoltezApp());
    expect(find.byType(VoltezApp), findsOneWidget);
  });
}
