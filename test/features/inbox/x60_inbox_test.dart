import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/inbox/inbox_models.dart';
import 'package:contour/features/inbox/x60_inbox.dart';
import 'package:contour/features/inbox/x61_item_sheet.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_inbox_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.home, child: child),
    );

Future<void> _pump(WidgetTester tester, FakeInboxGateway gateway) async {
  await tester.binding.setSurfaceSize(const Size(600, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _wrap(
      X60Inbox(
        gateway: gateway,
        showToast: false,
        onClose: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('X60 shows the hero, the decision card and the ready rows',
      (tester) async {
    await _pump(tester, FakeInboxGateway());

    expect(find.text('INBOX · READY TO CONFIRM'), findsOneWidget);
    expect(find.textContaining('ticked of 4'), findsOneWidget);
    expect(find.text('Needs a decision'), findsOneWidget);
    expect(
      find.text('Is this a transfer between your own accounts?'),
      findsOneWidget,
    );
    expect(find.text('Yes, a transfer'), findsOneWidget);
    expect(find.text('No, two payments'), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);
    expect(find.text('PX Market'), findsOneWidget);
    expect(find.text('Confirm 2 ticked, \$48.58'), findsOneWidget);
    expect(find.textContaining('Coffee'), findsWidgets);
    expect(find.text('Coffee ?'), findsNothing);
    expect(find.textContaining('No category'), findsWidgets);
  });

  testWidgets('the open decision blocks Confirm until it is answered',
      (tester) async {
    final gateway = FakeInboxGateway();
    await _pump(tester, gateway);

    final before = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Confirm 2 ticked, \$48.58'),
    );
    expect(before.onPressed, isNull);
    expect(before.variant, AppButtonVariant.ghost);

    await tester.tap(find.text('Yes, a transfer'));
    await tester.pumpAndSettle();

    expect(gateway.decisions, <bool>[true]);
    expect(find.text('Needs a decision'), findsNothing);
    expect(find.text('Confirm 3 ticked, \$1,288.58'), findsOneWidget);
    expect(find.byType(ConfirmBar), findsOneWidget);
  });

  testWidgets('Confirm sends the ticked ids and shows no second write',
      (tester) async {
    final gateway = FakeInboxGateway();
    await _pump(tester, gateway);
    await tester.tap(find.text('Yes, a transfer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm 3 ticked, \$1,288.58'));
    await tester.pumpAndSettle();

    expect(gateway.confirmed, hasLength(1));
    expect(gateway.confirmed.single, <int>{1, 3, 4});
    expect(gateway.confirmed.single.length, 3);
  });

  testWidgets('X62 empty state is a known zero with no ConfirmBar',
      (tester) async {
    await _pump(
      tester,
      FakeInboxGateway(rows: const <InboxRow>[], pendingCount: 0),
    );

    expect(find.text('All clear'), findsOneWidget);
    expect(find.text('Nothing to check · on this phone'), findsOneWidget);
    expect(find.byType(ConfirmBar), findsNothing);
  });

  testWidgets('X61 shows the read fields and confirms a reviewed row',
      (tester) async {
    final unsure = InboxRow(
      id: 2,
      title: 'PX Market',
      source: 'statement',
      date: LocalDate(2026, 10, 10),
      amountMinor: -3175,
      currencyCode: 'USD',
      editRevision: 1,
      suggestion: 'new',
      categoryName: null,
      accountName: 'Checking',
      isUnsure: true,
    );
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var confirmed = 0;
    await tester.pumpWidget(
      _wrap(
        Material(
          color: AppTheme.dark().extension<ContourTokens>()!.surfaceSheet,
          child: X61InboxItemSheet(
            row: unsure,
            onConfirm: () => confirmed += 1,
            onDelete: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PX Market'), findsWidgets);
    expect(find.text(r'$31.75'), findsOneWidget);
    expect(find.text('No category'), findsOneWidget);
    expect(find.text('Checking'), findsOneWidget);
    expect(find.text('From Statement'), findsOneWidget);
    final confirm = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Confirm'),
    );
    expect(confirm.onPressed, isNotNull);
  });
}
