// P3-25 entry points (SCREENS X03 step 2, X80 Capture): Import is reachable
// from the product, not only from the debug gallery.
import 'package:contour/app/router.dart';
import 'package:contour/design/design.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ContourRouter router) => MaterialApp.router(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router.build(),
    );

void main() {
  testWidgets('Home step 2 opens the import hub', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(ContourRouter(initialLocation: '/x03')),
    );
    await tester.pumpAndSettle();

    final l = AppLocalizations.of(
      tester.element(find.byType(TabRootScreen)),
    );
    await tester.tap(find.text(l.x03Step2));
    await tester.pumpAndSettle();

    expect(find.text(l.importChoosePdf), findsOneWidget);
    expect(find.text(l.importKicker), findsOneWidget);
  });

  testWidgets('Settings Import layouts opens the import hub', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(ContourRouter(initialLocation: '/x80')),
    );
    await tester.pumpAndSettle();

    final l = AppLocalizations.of(
      tester.element(find.byType(DetailScreen)),
    );
    await tester.ensureVisible(find.text(l.x80ImportLayouts));
    await tester.tap(find.text(l.x80ImportLayouts));
    await tester.pumpAndSettle();

    expect(find.text(l.importChoosePdf), findsOneWidget);
  });
}
