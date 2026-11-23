import 'dart:async';

import 'package:contour/app/router.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/inbox/x60_inbox.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_inbox_gateway.dart';

void main() {
  testWidgets('the X60 route opens the Inbox in the Home section',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ContourRouter(
      gate: const AlwaysOpenGate(),
      inbox: FakeInboxGateway(),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.build(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator))).go('/x03');
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator))).push('/x60'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(X60Inbox), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    final context = tester.element(find.byType(X60Inbox));
    expect(SectionScope.of(context), Section.home);
  });
}
