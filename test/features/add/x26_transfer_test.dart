import 'package:contour/design/design.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:contour/features/add/transfer_models.dart';
import 'package:contour/features/add/x26_transfer.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transfer_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.spending, child: child),
    );

final class _Harness {
  _Harness({FakeTransferGateway? gateway})
      : gateway = gateway ?? FakeTransferGateway();

  final FakeTransferGateway gateway;
  SavedTransfer? saved;
  PaymentKind? switched;
  int closed = 0;

  Widget build() => _wrap(
        X26Transfer(
          gateway: gateway,
          today: transferTestToday(),
          showToast: false,
          onClose: () => closed += 1,
          onSaved: (value) => saved = value,
          onSwitchType: (kind) => switched = kind,
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

void main() {
  testWidgets('X26 opens on Transfer with the two accounts and the caption',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Checking'), findsOneWidget);
    expect(find.text('Visa card'), findsOneWidget);
    expect(find.text(r'$6,450.00'), findsOneWidget);
    expect(find.text(r'Owes $1,240.00'), findsOneWidget);
    expect(
      find.text(
        'A transfer moves money between your own accounts. '
        'It is not counted as spending.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save transfer'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Save needs an amount and returns the confirmed transfer',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    await _type(tester, '1240');
    final button = tester
        .widget<AppButton>(find.widgetWithText(AppButton, r'Save $1,240.00'));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(AppButton, r'Save $1,240.00'));
    await tester.pumpAndSettle();

    expect(harness.saved, isNotNull);
    expect(harness.gateway.saved.single.amountMinor, 124000);
    expect(harness.saved!.eventId, 'event-1');
    expect(harness.closed, 0);
  });

  testWidgets('the same account on both sides blocks Save and states why',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);
    await _type(tester, '20');

    await tester.tap(find.text('To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking').last);
    await tester.pumpAndSettle();

    expect(find.text('Choose two different accounts.'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, r'Save $20.00'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a failed Save keeps the amount and shows a safe message',
      (tester) async {
    final gateway = FakeTransferGateway()
      ..saveFailure = const TransferFormError(TransferErrorCode.saveFailed);
    final harness = _Harness(gateway: gateway);
    await _pump(tester, harness);

    await _type(tester, '30');
    await tester.tap(find.widgetWithText(AppButton, r'Save $30.00'));
    await tester.pumpAndSettle();

    expect(harness.saved, isNull);
    expect(
      find.text('The transfer was not saved. Your entries stay here.'),
      findsOneWidget,
    );
    expect(find.text(r'Save $30.00'), findsOneWidget);
  });

  testWidgets('the type switch returns to the expense or income form',
      (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);

    await tester.tap(find.text('Income'));
    await tester.pump();

    expect(harness.switched, PaymentKind.income);
  });

  testWidgets('Close keeps the draft and writes nothing', (tester) async {
    final harness = _Harness();
    await _pump(tester, harness);
    await _type(tester, '5');

    await tester.tap(find.byType(AppIconButton).first);
    await tester.pump();

    expect(harness.closed, 1);
    expect(harness.gateway.saved, isEmpty);
  });
}
