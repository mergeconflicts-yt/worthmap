import 'package:contour/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

// T01 smoke test. Proves the test runner works. No financial logic.
void main() {
  testWidgets('ContourApp builds start stub', (WidgetTester tester) async {
    await tester.pumpWidget(const ContourApp());
    expect(find.text('Contour'), findsOneWidget);
  });
}
