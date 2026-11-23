import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/add/payment_draft.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:contour/features/add/x23_split_screen.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<CategorySummary> _categories = <CategorySummary>[
  CategorySummary(id: 'c1', name: 'Groceries'),
  CategorySummary(id: 'c2', name: 'Household'),
  CategorySummary(id: 'c3', name: 'Gifts'),
];

const List<PaymentDraftSplit> _parts = <PaymentDraftSplit>[
  PaymentDraftSplit(
    categoryId: 'c1',
    name: 'Groceries',
    amountText: '84.12',
  ),
  PaymentDraftSplit(
    categoryId: 'c2',
    name: 'Household',
    amountText: '25.00',
  ),
  PaymentDraftSplit(categoryId: 'c3', name: 'Gifts', amountText: '12.18'),
];

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.spending, child: child),
    );

void main() {
  testWidgets('an exact split shows the total, the parts and an active Save',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X23SplitScreen(
          total: Money.fromMinor(12130, Currency.usd),
          merchantName: 'Whole Foods',
          date: LocalDate(2026, 10, 5),
          categories: _categories,
          initialParts: _parts,
          onSave: (_) {},
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Split payment'), findsWidgets);
    expect(find.text('Whole Foods, 5 Oct'), findsOneWidget);
    expect(find.text('Whole Foods · 5 Oct · 3 parts'), findsOneWidget);
    expect(find.textContaining('All of'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save split'))
          .onPressed,
      isNotNull,
    );
    expect(find.textContaining('Remove Groceries'), findsNothing);
    expect(find.bySemanticsLabel('Remove Groceries'), findsOneWidget);
  });

  testWidgets('a part with an amount left keeps Save inactive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X23SplitScreen(
          total: Money.fromMinor(12130, Currency.usd),
          merchantName: 'Whole Foods',
          date: LocalDate(2026, 10, 5),
          categories: _categories,
          initialParts: const <PaymentDraftSplit>[
            PaymentDraftSplit(
              categoryId: 'c1',
              name: 'Groceries',
              amountText: '84.12',
            ),
            PaymentDraftSplit(
              categoryId: 'c2',
              name: 'Household',
              amountText: '20.00',
            ),
          ],
          onSave: (_) {},
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save split'))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('17.18'), findsOneWidget);
  });

  testWidgets('Add a part takes the remainder and needs a category',
      (tester) async {
    List<PaymentDraftSplit>? saved;
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X23SplitScreen(
          total: Money.fromMinor(5000, Currency.usd),
          merchantName: 'Market',
          date: LocalDate(2026, 10, 5),
          categories: _categories,
          initialParts: const <PaymentDraftSplit>[
            PaymentDraftSplit(
              categoryId: 'c1',
              name: 'Groceries',
              amountText: '50',
            ),
          ],
          onSave: (parts) => saved = parts,
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a part'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gifts'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsWidgets);
    await tester.ensureVisible(find.widgetWithText(AppButton, 'Save split'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save split'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(2));
    expect(saved!.last.name, 'Gifts');
    expect(saved!.last.amountText, '0.00');
  });

  testWidgets('removing a part leaves its amount to split', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X23SplitScreen(
          total: Money.fromMinor(5000, Currency.usd),
          merchantName: 'Market',
          date: LocalDate(2026, 10, 5),
          categories: _categories,
          initialParts: const <PaymentDraftSplit>[
            PaymentDraftSplit(
              categoryId: 'c1',
              name: 'Groceries',
              amountText: '20',
            ),
            PaymentDraftSplit(
              categoryId: 'c2',
              name: 'Household',
              amountText: '30',
            ),
          ],
          onSave: (_) {},
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Remove Household'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('30.00'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save split'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a part amount is editable and the remainder follows',
      (tester) async {
    List<PaymentDraftSplit>? saved;
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X23SplitScreen(
          total: Money.fromMinor(5000, Currency.usd),
          merchantName: 'Market',
          date: LocalDate(2026, 10, 5),
          categories: _categories,
          initialParts: const <PaymentDraftSplit>[
            PaymentDraftSplit(
              categoryId: 'c1',
              name: 'Groceries',
              amountText: '20',
            ),
            PaymentDraftSplit(
              categoryId: 'c2',
              name: 'Household',
              amountText: '30',
            ),
          ],
          onSave: (parts) => saved = parts,
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the amount sheet of the second part (the parts card shows it).
    await tester.tap(
      find.descendant(
        of: find.byType(SplitEditor),
        matching: find.text(r'$30.00'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Done'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SplitEditor),
        matching: find.text(r'$25.00'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('5.00'), findsWidgets);
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save split'))
          .onPressed,
      isNull,
      reason: '20 + 25 leaves 5 to split',
    );
    expect(saved, isNull);
  });

  testWidgets('Close writes nothing', (tester) async {
    var closed = 0;
    var saved = 0;
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X23SplitScreen(
          total: Money.fromMinor(5000, Currency.usd),
          merchantName: 'Market',
          date: LocalDate(2026, 10, 5),
          categories: _categories,
          initialParts: _parts,
          onSave: (_) => saved += 1,
          onClose: () => closed += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppIconButton).first);
    await tester.pumpAndSettle();
    expect(closed, 1);
    expect(saved, 0);
  });
}
