import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/domain/importers/quick_add_parser.dart' show DraftField;
import 'package:contour/features/add/payment_draft.dart';
import 'package:contour/features/add/payment_form_controller.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:contour/features/add/x20_add_payment.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_payments_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.spending, child: child),
    );

final class _Harness {
  _Harness({
    this.controller,
    this.drafts,
    this.editing,
    this.showToast = false,
    FakePaymentsGateway? gateway,
  }) : gateway = gateway ?? FakePaymentsGateway();

  final FakePaymentsGateway gateway;
  final PaymentFormController? controller;
  final PaymentDraftStore? drafts;
  final PaymentEdit? editing;
  final bool showToast;
  SavedPayment? saved;
  int closed = 0;

  Widget build() => _wrap(
        X20AddPayment(
          gateway: gateway,
          today: testToday(),
          controller: controller,
          drafts: drafts,
          editing: editing,
          showToast: showToast,
          onClose: () => closed += 1,
          onSaved: (value) => saved = value,
        ),
      );
}

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  await tester.binding.setSurfaceSize(const Size(600, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness.build());
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.text(digit).last);
    await tester.pump();
  }
}

PaymentFormController _prepared(
  FakePaymentsGateway gateway, {
  required String amount,
  bool exactSplit = false,
  PaymentEdit? editing,
}) {
  final controller = PaymentFormController(
    gateway: gateway,
    today: testToday(),
    editing: editing,
  );
  for (final key in amount.split('')) {
    controller.pressKey(key);
  }
  controller.selectAccount(gateway.accounts.first);
  if (exactSplit) {
    controller.setSplitParts(const <PaymentDraftSplit>[
      PaymentDraftSplit(categoryId: 'a', name: 'Groceries', amountText: '12'),
      PaymentDraftSplit(categoryId: 'b', name: 'Household', amountText: '12'),
    ]);
  }
  return controller;
}

void main() {
  testWidgets('the fresh form opens on the amount with Save inactive',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsNothing, reason: 'X26 is P23');
    expect(find.text(r'$0.00'), findsOneWidget);
    expect(find.text('Where or what?'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a typical expense saves in four activations, one of them Save',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    // The account is chosen first: the app has no last-used account yet.
    await _type(tester, '24');
    await tester.tap(find.widgetWithText(PillPicker, 'Choose account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Paid with'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid with'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(harness.gateway.saved, isEmpty, reason: 'nothing before Save');

    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, r'Save $24.00'));
    await tester.pumpAndSettle();

    expect(harness.gateway.saved, hasLength(1));
    final setup = harness.gateway.saved.single;
    expect(setup.amountMinor, -2400);
    expect(setup.categoryId, 'category-dining');
    expect(setup.date, testToday());
    expect(setup.accountId, 'account-1');
    expect(harness.saved, isNotNull);
  });

  testWidgets('an uncategorised payment saves (F03-A)', (tester) async {
    final gateway = FakePaymentsGateway();
    final controller = _prepared(gateway, amount: '24');
    final harness = _Harness(controller: controller, gateway: gateway);
    addTearDown(controller.dispose);
    await _pump(tester, harness);

    await tester.tap(find.widgetWithText(AppButton, r'Save $24.00'));
    await tester.pumpAndSettle();

    expect(harness.gateway.saved.single.categoryId, isNull);
    expect(harness.gateway.saved.single.amountMinor, -2400);
  });

  testWidgets('a split saves once after repeated taps (F03-B)', (tester) async {
    final gateway = FakePaymentsGateway();
    final controller = _prepared(
      gateway,
      amount: '24',
      exactSplit: true,
    );
    final harness = _Harness(controller: controller, gateway: gateway);
    addTearDown(controller.dispose);
    await _pump(tester, harness);

    final save = find.widgetWithText(AppButton, r'Save $24.00');
    await tester.tap(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(harness.gateway.saved, hasLength(1));
    expect(harness.gateway.saved.single.splits, hasLength(2));
    expect(harness.gateway.saved.single.splits.first.amountMinor, -1200);
  });

  testWidgets('a split with an amount left does not save (F03-B)',
      (tester) async {
    final gateway = FakePaymentsGateway();
    final controller = _prepared(gateway, amount: '24')
      ..setSplitParts(const <PaymentDraftSplit>[
        PaymentDraftSplit(categoryId: 'a', name: 'Groceries', amountText: '10'),
        PaymentDraftSplit(categoryId: 'b', name: 'Household', amountText: '4'),
      ]);
    final harness = _Harness(controller: controller, gateway: gateway);
    addTearDown(controller.dispose);
    await _pump(tester, harness);

    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, r'Save $24.00'))
          .onPressed,
      isNull,
    );
    expect(find.text(r'2 parts, $10.00 left to split'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, r'Save $24.00'));
    await tester.pumpAndSettle();
    expect(gateway.saved, isEmpty);
  });

  testWidgets('a failed save keeps every entry and names the reason',
      (tester) async {
    final gateway = FakePaymentsGateway()
      ..saveFailure = const PaymentsError(PaymentsErrorCode.notWired);
    final controller = _prepared(gateway, amount: '24');
    final harness = _Harness(controller: controller, gateway: gateway);
    addTearDown(controller.dispose);
    await _pump(tester, harness);

    await tester.tap(find.widgetWithText(AppButton, r'Save $24.00'));
    await tester.pumpAndSettle();

    expect(
      find.text('Payments are not connected in this build.'),
      findsOneWidget,
    );
    expect(find.text(r'Save $24.00'), findsOneWidget);
    expect(find.text('Checking'), findsOneWidget);
    expect(harness.saved, isNull);
  });

  testWidgets('Close writes nothing', (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);
    await _type(tester, '24');
    await tester.tap(find.byType(AppIconButton).first);
    await tester.pumpAndSettle();
    expect(harness.closed, 1);
    expect(harness.gateway.saved, isEmpty);
  });

  testWidgets('an edit changes the record and does not add one (F03-C)',
      (tester) async {
    const edit = PaymentEdit(
      paymentId: 'p-1',
      eventId: 'e-1',
      expectedRevision: 2,
    );
    final gateway = FakePaymentsGateway();
    final controller = _prepared(gateway, amount: '40', editing: edit);
    final harness = _Harness(
      controller: controller,
      gateway: gateway,
      editing: edit,
    );
    addTearDown(controller.dispose);
    await _pump(tester, harness);

    await tester.tap(find.widgetWithText(AppButton, r'Save $40.00'));
    await tester.pumpAndSettle();

    expect(gateway.saved, hasLength(1));
    expect(gateway.saved.single.edit!.paymentId, 'p-1');
    expect(harness.saved!.edit, isTrue);
  });

  testWidgets('a confirmed save shows one toast whose Undo compensates',
      (tester) async {
    final gateway = FakePaymentsGateway();
    final controller = _prepared(gateway, amount: '24');
    final harness = _Harness(
      controller: controller,
      gateway: gateway,
      showToast: true,
    );
    addTearDown(controller.dispose);
    await _pump(tester, harness);

    await tester.tap(find.widgetWithText(AppButton, r'Save $24.00'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Payment saved'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(harness.gateway.undoCalls, 1);

    // The toast timer closes itself after 5 s (DESIGN 6.6).
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a typed sentence fills the amount and the merchant',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    await tester.enterText(
      find.byType(TextField).first,
      'coffee 4.50 at #Dining',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text(r'Save $4.50'), findsOneWidget);
    expect(find.text('Dining'), findsOneWidget);
    expect(harness.gateway.saved, isEmpty);
  });

  testWidgets('the Save label masks the amount in the hidden state',
      (tester) async {
    final gateway = FakePaymentsGateway();
    final controller = _prepared(gateway, amount: '24');
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(600, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        HiddenAmountsScope(
          hidden: true,
          child: X20AddPayment(
            gateway: gateway,
            today: testToday(),
            controller: controller,
            showToast: false,
            onClose: () {},
            onSaved: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save ······'), findsOneWidget);
    expect(find.textContaining(r'$24'), findsNothing);
  });

  testWidgets('a stored draft resumes and Discard removes it', (tester) async {
    final store = MemoryPaymentDraftStore()
      ..draft = PaymentFormDraft(
        kind: PaymentKind.expense,
        amountText: '18.50',
        currencyCode: 'USD',
        date: LocalDate(2026, 11, 20),
        accountId: 'account-1',
        categoryId: null,
        tagIds: const <String>[],
        merchantText: 'Subway',
        splits: const <PaymentDraftSplit>[],
        unsureFields: const <DraftField>{},
      );
    final harness = _Harness(drafts: store);
    await _pump(tester, harness);

    expect(find.text(r'Save $18.50'), findsOneWidget);
    expect(find.text('Subway'), findsOneWidget);
    expect(find.text('Checking'), findsOneWidget);

    await tester.ensureVisible(find.text('Discard draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(store.draft, isNull);
    expect(harness.closed, 1);
  });

  testWidgets('a direct close keeps the draft and writes no payment',
      (tester) async {
    final store = MemoryPaymentDraftStore();
    final harness = _Harness(drafts: store);
    await _pump(tester, harness);
    await _type(tester, '9');
    await tester.tap(find.widgetWithText(PillPicker, 'Choose account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Paid with'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid with'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppIconButton).first);
    await tester.pumpAndSettle();

    expect(harness.closed, 1);
    expect(harness.gateway.saved, isEmpty);
    expect(store.draft, isNotNull);
  });
}
