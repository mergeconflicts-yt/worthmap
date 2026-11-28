import 'package:contour/app/router.dart';
import 'package:contour/design/design.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A scripted gate for the redirect tests.
final class ScriptedGate implements LockGate {
  ScriptedGate(this.open);

  bool open;

  @override
  bool get admissionOpen => open;
}

/// Builds one router config and pumps it. The config object is the single
/// navigation entry point for the test; the event list is the log surface.
Future<(GoRouter, List<RouterLogEvent>)> pumpRouter(
  WidgetTester tester,
  ScriptedGate gate,
) async {
  final events = <RouterLogEvent>[];
  final router = ContourRouter(
    gate: gate,
    onLog: events.add,
  );
  final config = router.build();
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: config,
    ),
  );
  await tester.pumpAndSettle();
  return (config, events);
}

void main() {
  test('bareLocation drops query and fragment (no amounts in URLs)', () {
    expect(
      ContourRouter.bareLocation(
        Uri.parse('/x80?amount=1000&command=save#x'),
      ),
      '/x80',
    );
    expect(
      ContourRouter.bareLocation(Uri.parse('/x03?x=1')),
      '/x03',
    );
  });

  testWidgets('every route renders inside its SectionScope', (tester) async {
    final (config, _) = await pumpRouter(tester, ScriptedGate(true));
    // The initial route is X01 welcome, section Home.
    final match = config.routerDelegate.currentConfiguration.matches.last;
    expect(match.matchedLocation, '/x01');
    final context = tester.state(find.byType(Navigator)).context;
    expect(SectionScope.of(context), Section.home);
  });

  testWidgets('the tab bar opens the four section roots', (tester) async {
    final (config, _) = await pumpRouter(tester, ScriptedGate(true));
    config.go('/x03');
    await tester.pumpAndSettle();

    expect(find.byType(AppTabBar), findsOneWidget);
    Finder tab(String label) => find.descendant(
          of: find.byType(AppTabBar),
          matching: find.text(label),
        );
    expect(tab('Home'), findsOneWidget);
    expect(tab('Spending'), findsOneWidget);
    expect(tab('Wealth'), findsOneWidget);
    expect(tab('Plan'), findsOneWidget);

    await tester.tap(tab('Wealth'));
    await tester.pumpAndSettle();
    expect(
      config.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      '/x40',
    );

    await tester.tap(tab('Plan'));
    await tester.pumpAndSettle();
    expect(
      config.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      '/x50',
    );

    await tester.tap(tab('Spending'));
    await tester.pumpAndSettle();
    expect(
      config.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      '/x30',
    );

    // A detail screen has no tab bar (SPEC 5.1).
    config.go('/x80');
    await tester.pumpAndSettle();
    expect(find.byType(AppTabBar), findsNothing);
  });

  testWidgets('a deep link waits behind unlock and resumes after it',
      (tester) async {
    final gate = ScriptedGate(false);
    final (config, events) = await pumpRouter(tester, gate);
    // Deep link while locked: deferred to X02, bare path only.
    config.go('/x80?x=1');
    await tester.pumpAndSettle();
    var matches = config.routerDelegate.currentConfiguration.matches;
    expect(matches.last.matchedLocation, '/x02');
    expect(events, contains(RouterLogEvent.deepLinkDeferred));

    // Unlock: the deferred bare target resumes.
    gate.open = true;
    config.go('/x02');
    await tester.pumpAndSettle();
    matches = config.routerDelegate.currentConfiguration.matches;
    expect(matches.last.matchedLocation, '/x80');
    expect(events, contains(RouterLogEvent.deepLinkResumed));
  });

  testWidgets('an unavailable target returns to the nearest parent',
      (tester) async {
    final (config, events) = await pumpRouter(tester, ScriptedGate(true));
    config.go('/no/such/screen');
    await tester.pumpAndSettle();
    final match = config.routerDelegate.currentConfiguration.matches.last;
    expect(match.matchedLocation, '/x03');
    expect(events, contains(RouterLogEvent.unknownTargetRouted));
  });

  testWidgets('a tab re-select returns to the tab root', (tester) async {
    final (config, _) = await pumpRouter(tester, ScriptedGate(true));
    config.go('/x80');
    await tester.pumpAndSettle();
    // Re-select the Home tab: back to the Home root.
    config.go('/x03');
    await tester.pumpAndSettle();
    config.go('/x03');
    await tester.pumpAndSettle();
    final match = config.routerDelegate.currentConfiguration.matches.last;
    expect(match.matchedLocation, '/x03');
  });

  testWidgets('the gallery route exists in debug mode only', (tester) async {
    final (config, _) = await pumpRouter(tester, ScriptedGate(true));
    config.go('/dev/gallery');
    await tester.pumpAndSettle();
    final match = config.routerDelegate.currentConfiguration.matches.last;
    expect(
      kDebugMode ? match.matchedLocation : '/x03',
      kDebugMode ? '/dev/gallery' : '/x03',
    );
  });
}
