import 'package:contour/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// T12: the Phase 1 device smoke test. It proves that the app starts on a real
/// engine, shows the product name from l10n, and does not need a network.
///
/// Run on a device or emulator:
/// `flutter test integration_test -d <device-id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app starts and shows the localized product name',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ContourApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Contour'), findsOneWidget);
  });
}
