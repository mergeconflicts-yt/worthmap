import 'package:contour/app/app.dart';
import 'package:contour/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// T01 smoke test, updated in T09: the app builds the Phase 1 router and the
// welcome route renders without error. The real X01 screen lands in T10.
void main() {
  testWidgets('ContourApp builds the Phase 1 router', (tester) async {
    await tester.pumpWidget(
      ContourApp(router: ContourRouter(gate: const AlwaysOpenGate())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Navigator), findsOneWidget);
  });
}
