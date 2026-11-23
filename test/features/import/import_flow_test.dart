// P3-25 (flow F06): the PDF import flow.
//
// A synthetic statement goes from the picker to the preview, then to the
// Inbox. The tests assert that no payment is written before Send and that the
// teach step stores a layout.
import 'dart:convert';
import 'dart:typed_data';

import 'package:contour/app/demo/sample_statement.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/import/x63_import.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_import.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(
        section: Section.home,
        child: child,
      ),
    );

void main() {
  testWidgets('a PDF goes from the picker to the Inbox', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeImportGateway();
    await tester.pumpWidget(
      _app(
        X63Import(
          gateway: gateway,
          intake: FakeIntake(buildSyntheticStatement()),
          accounts: FakeAccountsGateway(
            accounts: const <AccountSummary>[checkingAccount],
          ),
          onClose: () {},
          onOpenInbox: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a PDF statement'), findsOneWidget);
    await tester.tap(find.text('Choose a PDF statement'));
    await tester.pumpAndSettle();

    expect(find.text('DATE · DETAILS · AMOUNT'), findsOneWidget);
    expect(find.text('Send 4 to the Inbox'), findsOneWidget);
    expect(gateway.sendCount, 0);

    await tester.ensureVisible(find.text('Send 4 to the Inbox'));
    await tester.tap(find.text('Send 4 to the Inbox'));
    await tester.pumpAndSettle();

    expect(gateway.sendCount, 1);
    expect(gateway.lastAccount, checkingAccount.id);
    await tester.ensureVisible(find.text('Open the Inbox'));
    expect(find.text('Open the Inbox'), findsOneWidget);
  });

  testWidgets('Teach once stores the layout and returns to the preview',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeImportGateway();
    await tester.pumpWidget(
      _app(
        X63Import(
          gateway: gateway,
          intake: FakeIntake(buildSyntheticStatement()),
          accounts: FakeAccountsGateway(
            accounts: const <AccountSummary>[checkingAccount],
          ),
          onClose: () {},
          onOpenInbox: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a PDF statement'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Wrong layout? Teach again'));
    await tester.tap(find.text('Wrong layout? Teach again'));
    await tester.pumpAndSettle();
    expect(find.text('Steps'), findsOneWidget);

    await tester.tap(find.text('13 Oct 2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('-12.50').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save layout'));
    await tester.pumpAndSettle();

    expect(gateway.layoutsList.length, 1);
    expect(find.text('DATE · DETAILS · AMOUNT'), findsOneWidget);
  });

  testWidgets('a file that is not a PDF shows X88', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        X63Import(
          gateway: FakeImportGateway(),
          intake: FakeIntake(
            Uint8List.fromList(utf8.encode('hello')),
            name: 'notes.txt',
          ),
          accounts: FakeAccountsGateway(
            accounts: const <AccountSummary>[checkingAccount],
          ),
          onClose: () {},
          onOpenInbox: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a PDF statement'));
    await tester.pumpAndSettle();

    expect(find.text('This file is not a PDF'), findsOneWidget);
    expect(
      find.text(
        'notes.txt may be a photo of a page, or a layout this version cannot read.',
      ),
      findsOneWidget,
    );
    expect(find.text('Nothing from this file was added.'), findsOneWidget);
  });
}
