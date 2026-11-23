@Tags(<String>['golden'])
library;

import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/add/payment_draft.dart';
import 'package:contour/features/add/payment_form_controller.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:contour/features/add/x20_add_payment.dart';
import 'package:contour/features/add/x21_category_sheet.dart';
import 'package:contour/features/add/x22_details_sheet.dart';
import 'package:contour/features/add/x23_split_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/add/fake_payments_gateway.dart';
import 'golden_harness.dart';

const AccountSummary _checking = AccountSummary(
  id: 'account-1',
  name: 'Checking',
  kind: AccountKind.bank,
  currencyCode: 'USD',
  balanceMinor: 645000,
);

const List<CategorySummary> _categories = <CategorySummary>[
  CategorySummary(id: 'c1', name: 'Rent'),
  CategorySummary(id: 'c2', name: 'Groceries'),
  CategorySummary(id: 'c3', name: 'Dining'),
  CategorySummary(id: 'c4', name: 'Coffee'),
  CategorySummary(id: 'c5', name: 'Transport'),
  CategorySummary(id: 'c6', name: 'Shopping'),
  CategorySummary(id: 'c7', name: 'Utilities'),
  CategorySummary(id: 'c8', name: 'Subscriptions'),
];

PaymentFormController _draft({
  required String amount,
  required List<CategorySummary> categories,
  PaymentKind kind = PaymentKind.expense,
  List<PaymentDraftSplit> splits = const <PaymentDraftSplit>[],
}) {
  final gateway = FakePaymentsGateway(
    accounts: const <AccountSummary>[_checking],
    expenseCategories: categories,
    incomeCategories: categories,
  );
  final controller = PaymentFormController(
    gateway: gateway,
    today: LocalDate(2026, 10, 13),
    kind: kind,
  );
  for (final key in amount.split('')) {
    controller.pressKey(key);
  }
  controller
    ..selectAccount(_checking)
    ..setMerchant('Starbucks')
    ..setSplitParts(splits);
  if (categories.isNotEmpty) {
    controller.selectCategory(
      categories.length > 2 ? categories[2] : categories.first,
    );
  }
  return controller;
}

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('add expense ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1600 : 2400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _draft(amount: '24', categories: _categories);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: X20AddPayment(
              gateway: FakePaymentsGateway(),
              today: LocalDate(2026, 10, 13),
              controller: controller,
              showToast: false,
              onClose: () {},
              onSaved: (_) {},
              onSpeak: () async => null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x20_add_expense_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('add income ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1600 : 2400),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _draft(
          amount: '5000',
          categories: const <CategorySummary>[
            CategorySummary(id: 'i1', name: 'Salary'),
          ],
          kind: PaymentKind.income,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: X20AddPayment(
              gateway: FakePaymentsGateway(),
              today: LocalDate(2026, 10, 13),
              controller: controller,
              showToast: false,
              onClose: () {},
              onSaved: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x20_add_income_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('category sheet ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: Material(
              color: theme.$2.extension<ContourTokens>()!.surfacePage,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AppSheet(
                  title: 'Category',
                  semanticLabel: 'Choose a category',
                  children: <Widget>[
                    X21CategorySheet(
                      categories: _categories,
                      selectedId: 'c3',
                      onSelected: (_) {},
                      onNewCategory: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x21_category_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('details sheet ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: Material(
              color: theme.$2.extension<ContourTokens>()!.surfacePage,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AppSheet(
                  title: 'Details',
                  semanticLabel: 'Date, account, currency',
                  children: <Widget>[
                    X22DetailsSheet(
                      initial: PaymentDetails(
                        date: LocalDate(2026, 10, 13),
                        currencyCode: 'USD',
                        account: _checking,
                        tagIds: const <String>[],
                      ),
                      today: LocalDate(2026, 10, 13),
                      accounts: const <AccountSummary>[_checking],
                      tags: const <TagSummary>[
                        TagSummary(id: 't1', name: 'Household'),
                      ],
                      onDone: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x22_details_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('split payment ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1800 : 2600),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: X23SplitScreen(
              total: Money.fromMinor(12130, Currency.usd),
              merchantName: 'Whole Foods',
              date: LocalDate(2026, 10, 5),
              categories: _categories,
              initialParts: const <PaymentDraftSplit>[
                PaymentDraftSplit(
                  categoryId: 'c2',
                  name: 'Groceries',
                  amountText: '84.12',
                ),
                PaymentDraftSplit(
                  categoryId: 'c7',
                  name: 'Household',
                  amountText: '25.00',
                ),
                PaymentDraftSplit(
                  categoryId: 'c1',
                  name: 'Gifts',
                  amountText: '12.18',
                ),
              ],
              onSave: (_) {},
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x23_split_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}
