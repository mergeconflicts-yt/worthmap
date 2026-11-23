import 'package:contour/design/design.dart';
import 'package:contour/features/spending/payments_models.dart';
import 'package:contour/features/spending/x36_category_detail.dart';
import 'package:contour/features/spending/x37_all_payments.dart';
import 'package:contour/features/spending/x38_filter_sheet.dart';
import 'package:contour/features/spending/x39_payment_detail.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_payments_read_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.spending, child: child),
    );

Future<void> _size(WidgetTester tester, {double height = 2600}) async {
  await tester.binding.setSurfaceSize(Size(600, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('X37 groups the rows by day and opens one payment',
      (tester) async {
    await _size(tester, height: 3000);
    final opened = <String>[];
    await tester.pumpWidget(
      _wrap(
        X37AllPayments(
          gateway: FakePaymentsReadGateway(),
          onClose: () {},
          onOpenPayment: (String id) async {
            opened.add(id);
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All payments'), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);
    expect(find.text('PX Market'), findsWidgets);
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.textContaining('Yesterday'), findsOneWidget);

    await tester.tap(find.text('Starbucks'));
    await tester.pumpAndSettle();
    expect(opened, <String>['p1']);
  });

  testWidgets('X37 keeps the list when the filter is dismissed (F08-A)',
      (tester) async {
    await _size(tester, height: 3200);
    final gateway = FakePaymentsReadGateway();
    await tester.pumpWidget(
      _wrap(
        X37AllPayments(
          gateway: gateway,
          onClose: () {},
          onOpenPayment: (String id) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppIconButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Starbucks'), findsOneWidget, reason: 'no filter applied');
  });

  testWidgets('X38 applies on Show and keeps the draft on Back',
      (tester) async {
    await _size(tester, height: 2600);
    final gateway = FakePaymentsReadGateway();
    PaymentFilter? result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) => AppButton(
            label: 'Open',
            onPressed: () async {
              result = await showPaymentFilterSheet(
                context,
                gateway: gateway,
                initial: const PaymentFilter(
                  period: PaymentPeriod.thisMonth,
                  show: PaymentShowFilter.moneyOut,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last month'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show 4 payments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 4 payments'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.period, PaymentPeriod.lastMonth);
  });

  testWidgets('X38 Back returns no filter (F08-A)', (tester) async {
    await _size(tester, height: 3400);
    PaymentFilter? result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) => AppButton(
            label: 'Open',
            onPressed: () async {
              result = await showPaymentFilterSheet(
                context,
                gateway: FakePaymentsReadGateway(),
                initial: const PaymentFilter(
                  period: PaymentPeriod.thisMonth,
                  show: PaymentShowFilter.moneyOut,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last month'));
    await tester.pumpAndSettle();

    // The scrim above the sheet dismisses it (Back keeps the applied filter).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('X39 shows the fields and Keep it leaves the payment',
      (tester) async {
    await _size(tester, height: 2800);
    final gateway = FakePaymentsReadGateway();
    DeletedPayment? deleted;
    await tester.pumpWidget(
      _wrap(
        X39PaymentDetail(
          gateway: gateway,
          paymentId: 'p3',
          onClose: () {},
          onDeleted: (DeletedPayment value) => deleted = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Whole Foods'), findsOneWidget);
    expect(find.text('Split into 3'), findsOneWidget);
    expect(find.text('Household'), findsWidgets);
    expect(find.text('Weekly shop'), findsOneWidget);

    await tester.tap(find.text('Delete payment'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this payment?'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(gateway.deleted, isEmpty);
    expect(deleted, isNull);
  });

  testWidgets('X39b deletes once and returns the committed result',
      (tester) async {
    await _size(tester, height: 2800);
    final gateway = FakePaymentsReadGateway();
    DeletedPayment? deleted;
    await tester.pumpWidget(
      _wrap(
        X39PaymentDetail(
          gateway: gateway,
          paymentId: 'p1',
          onClose: () {},
          onDeleted: (DeletedPayment value) => deleted = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Delete payment').last);
    await tester.pumpAndSettle();

    expect(gateway.deleted, <String>['p1']);
    expect(deleted?.paymentId, 'p1');
  });

  testWidgets('X36 shows the category numbers, merchants and payments',
      (tester) async {
    await _size(tester, height: 3400);
    await tester.pumpWidget(
      _wrap(
        X36CategoryDetail(
          gateway: FakePaymentsReadGateway(),
          categoryId: 'cat-groceries',
          onClose: () {},
          onOpenPayment: (String id) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsWidgets);
    expect(find.textContaining('620'), findsWidgets);
    expect(find.textContaining('580'), findsWidgets);
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Month gone'), findsOneWidget);
    expect(find.text('12-month average'), findsOneWidget);
    expect(find.text('Each month'), findsOneWidget);
    expect(find.text('Where'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
  });
}
