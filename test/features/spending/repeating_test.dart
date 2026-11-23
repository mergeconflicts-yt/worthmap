import 'package:contour/design/design.dart';
import 'package:contour/features/spending/c02_schedule_editor.dart';
import 'package:contour/features/spending/c03_rule_editor.dart';
import 'package:contour/features/spending/repeating_controller.dart';
import 'package:contour/features/spending/repeating_models.dart';
import 'package:contour/features/spending/x34_repeating.dart';
import 'package:contour/features/spending/x35_repeating_detail.dart';
import 'package:contour/features/spending/x84_rules.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_repeating_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.spending, child: child),
    );

Future<void> _size(WidgetTester tester, {double height = 3000}) async {
  await tester.binding.setSurfaceSize(Size(600, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  test('the repeating list totals the schedules', () async {
    final controller = RepeatingController(gateway: FakeRepeatingGateway());
    await controller.load();

    expect(controller.state, RepeatingState.ready);
    expect(controller.view!.items, hasLength(3));
    expect(controller.view!.monthlyTotalMinor, 188099);
    expect(controller.view!.yearlyTotalMinor, 188099 * 12);
    controller.dispose();
  });

  test('Stop calls the gateway once', () async {
    final gateway = FakeRepeatingGateway();
    final controller = RepeatingDetailController(
      gateway: gateway,
      scheduleId: 's2',
    );
    await controller.load();
    expect(controller.view, isNotNull);

    final stopped = await controller.stop();

    expect(stopped, isTrue);
    expect(gateway.stopped, <String>['s2']);
    controller.dispose();
  });

  test('the rules list loads', () async {
    final controller = RulesController(gateway: FakeRepeatingGateway());
    await controller.load();

    expect(controller.rules, hasLength(2));
    expect(controller.rules.first.pattern, 'Whole Foods');
    expect(controller.categories, hasLength(3));
    controller.dispose();
  });

  testWidgets('X34 shows the hero and one row per schedule', (tester) async {
    await _size(tester);
    await tester.pumpWidget(
      _wrap(
        X34Repeating(
          gateway: FakeRepeatingGateway(),
          onClose: () {},
          onOpenSchedule: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repeating'), findsWidgets);
    expect(find.textContaining('1,880.99'), findsWidgets);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Car insurance'), findsOneWidget);
    expect(find.textContaining('Paid'), findsWidgets);
  });

  testWidgets('X35 shows the history and Stop ends the schedule',
      (tester) async {
    await _size(tester);
    final gateway = FakeRepeatingGateway();
    var closed = 0;
    await tester.pumpWidget(
      _wrap(
        X35RepeatingDetail(
          gateway: gateway,
          scheduleId: 's2',
          onClose: () => closed += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsWidgets);
    expect(find.textContaining('17.99'), findsWidgets);
    expect(find.text('Last 6 payments'), findsOneWidget);
    expect(find.text('Visa card'), findsOneWidget);

    await tester.tap(find.text('Stop repeating'));
    await tester.pumpAndSettle();
    expect(find.text('Stop this repeating payment?'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Stop repeating').last);
    await tester.pumpAndSettle();

    expect(gateway.stopped, <String>['s2']);
    expect(closed, 1);
  });

  testWidgets('X84 lists the rules and opens C03', (tester) async {
    await _size(tester);
    var added = 0;
    await tester.pumpWidget(
      _wrap(
        X84Rules(
          gateway: FakeRepeatingGateway(),
          onClose: () {},
          onAddRule: () => added += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Whole Foods'), findsOneWidget);
    expect(find.textContaining('Groceries'), findsOneWidget);
    expect(find.text('12x'), findsOneWidget);

    await tester.tap(find.text('Add a rule'));
    await tester.pumpAndSettle();
    expect(added, 1);
  });

  testWidgets('C03 saves one rule', (tester) async {
    await _size(tester);
    final gateway = FakeRepeatingGateway();
    var saved = 0;
    await tester.pumpWidget(
      _wrap(
        C03RuleEditor(
          gateway: gateway,
          onClose: () {},
          onSaved: () => saved += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Whole Foods');
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save rule'));
    await tester.pumpAndSettle();

    expect(gateway.savedRules, hasLength(1));
    expect(gateway.savedRules.single.pattern, 'Whole Foods');
    expect(gateway.savedRules.single.categoryId, 'c1');
    expect(saved, 1);
  });

  testWidgets('C02 saves one schedule', (tester) async {
    await _size(tester);
    final gateway = FakeRepeatingGateway();
    var saved = 0;
    await tester.pumpWidget(
      _wrap(
        C02ScheduleEditor(
          gateway: gateway,
          onClose: () {},
          onSaved: () => saved += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Netflix');
    for (final digit in <String>['1', '7', '9', '9']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save schedule'));
    await tester.pumpAndSettle();

    expect(gateway.savedSchedules, hasLength(1));
    expect(gateway.savedSchedules.single.name, 'Netflix');
    expect(gateway.savedSchedules.single.amountMinor, 179900);
    expect(gateway.savedSchedules.single.frequency, RepeatFrequency.yearly);
    expect(saved, 1);
  });
}
