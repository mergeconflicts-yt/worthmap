import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/accounts/account_models.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:contour/features/add/x22_details_sheet.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const AccountSummary _checking = AccountSummary(
  id: 'account-1',
  name: 'Checking',
  kind: AccountKind.bank,
  currencyCode: 'USD',
  balanceMinor: 645000,
);

const List<TagSummary> _tags = <TagSummary>[
  TagSummary(id: 'tag-1', name: 'Household'),
];

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(
        section: Section.spending,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.page),
            child: child,
          ),
        ),
      ),
    );

PaymentDetails _initial() => PaymentDetails(
      date: LocalDate(2026, 11, 22),
      currencyCode: 'USD',
      account: _checking,
      tagIds: <String>[],
    );

void main() {
  testWidgets('the sheet shows the month, the chosen date and the fields',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X22DetailsSheet(
          initial: _initial(),
          today: LocalDate(2026, 11, 22),
          accounts: const <AccountSummary>[_checking],
          tags: _tags,
          onDone: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('TODAY 22 NOV'), findsOneWidget);
    expect(find.text('Paid with'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a date chip sets the date and Done returns it', (tester) async {
    PaymentDetails? result;
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X22DetailsSheet(
          initial: _initial(),
          today: LocalDate(2026, 11, 22),
          accounts: const <AccountSummary>[_checking],
          tags: _tags,
          onDone: (details) => result = details,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result!.date, LocalDate(2026, 11, 21));
    expect(result!.account!.id, 'account-1');
    expect(result!.currencyCode, 'USD');
  });

  testWidgets('a future day is not selectable', (tester) async {
    PaymentDetails? result;
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X22DetailsSheet(
          initial: PaymentDetails(
            date: LocalDate(2026, 11, 22),
            currencyCode: 'USD',
            account: _checking,
            tagIds: <String>[],
          ),
          today: LocalDate(2026, 11, 13),
          accounts: const <AccountSummary>[_checking],
          tags: _tags,
          onDone: (details) => result = details,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 20 November is after 13 November.
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result!.date, LocalDate(2026, 11, 22));
  });

  testWidgets('a past month is reachable; the next month stops at today',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X22DetailsSheet(
          initial: _initial(),
          today: LocalDate(2026, 11, 22),
          accounts: const <AccountSummary>[_checking],
          tags: _tags,
          onDone: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    final next = tester.widget<AppIconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppIconButton && widget.icon == AppIcons.chevronRight,
      ),
    );
    expect(next.onPressed, isNull, reason: 'the current month is the last');
  });

  testWidgets('the tags sheet ticks a tag and Done keeps it', (tester) async {
    PaymentDetails? result;
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X22DetailsSheet(
          initial: _initial(),
          today: LocalDate(2026, 11, 22),
          accounts: const <AccountSummary>[_checking],
          tags: _tags,
          onDone: (details) => result = details,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(find.text('Household'), findsOneWidget);
    await tester.tap(find.byType(AppCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    expect(result!.tagIds, <String>['tag-1']);
  });
}
