import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/domain/numbers/spending_averages.dart';
import 'package:contour/domain/numbers/spending_totals.dart';

/// SPEC Appendix A: the sample data set, as synthetic rows.
///
/// Values are printed in `docs/spec/spec-calculation.md` (Appendix A) and
/// `docs/screens/SCREENS.md`. The current month is October 2026 (today
/// 13 Oct); the 12 complete months for averages are Oct 2025 to Sep 2026.
///
/// Only the October category rows are printed in detail. The other months
/// carry their printed totals as one row each; per-category history beyond
/// October is not printed and is not claimed here.

/// The sample currency.
const Currency sampleCurrency = Currency.usd;

/// Builds an amount from minor units (cents) of the sample currency.
Money cents(int minor) => Money.fromMinor(minor, sampleCurrency);

SpendingEntry _row(
  String date,
  SpendingKind kind,
  int minor, {
  String? category,
  bool? essential,
}) =>
    SpendingEntry(
      date: LocalDate.parse(date),
      kind: kind,
      amount: cents(minor),
      categoryId: category,
      isEssential: essential,
    );

/// All sample rows: spending from Oct 2025 to 13 Oct 2026, plus income.
List<SpendingEntry> appendixAPayments() => <SpendingEntry>[
      // October 2026 (1-13 Oct). The split by day answers the 1W and 1M chips.
      _row(
        '2026-10-01',
        SpendingKind.expense,
        180000,
        category: 'rent',
        essential: true,
      ),
      _row('2026-10-01', SpendingKind.income, 820000),
      _row(
        '2026-10-02',
        SpendingKind.expense,
        32000,
        category: 'groceries',
        essential: true,
      ),
      _row(
        '2026-10-03',
        SpendingKind.expense,
        6000,
        category: 'transport',
        essential: true,
      ),
      _row(
        '2026-10-04',
        SpendingKind.expense,
        9000,
        category: 'utilities',
        essential: true,
      ),
      _row(
        '2026-10-05',
        SpendingKind.expense,
        7000,
        category: 'dining',
        essential: false,
      ),
      _row(
        '2026-10-06',
        SpendingKind.expense,
        4000,
        category: 'shopping',
        essential: false,
      ),
      _row(
        '2026-10-07',
        SpendingKind.expense,
        30000,
        category: 'groceries',
        essential: true,
      ),
      _row(
        '2026-10-08',
        SpendingKind.expense,
        34000,
        category: 'dining',
        essential: false,
      ),
      _row(
        '2026-10-09',
        SpendingKind.expense,
        34000,
        category: 'shopping',
        essential: false,
      ),
      _row(
        '2026-10-10',
        SpendingKind.expense,
        20000,
        category: 'transport',
        essential: true,
      ),
      _row(
        '2026-10-11',
        SpendingKind.expense,
        12000,
        category: 'utilities',
        essential: true,
      ),
      _row(
        '2026-10-12',
        SpendingKind.expense,
        17000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-10-13',
        SpendingKind.expense,
        9000,
        category: 'subscriptions',
        essential: false,
      ),

      // September 2026: 4,320 in the month, 4,005 of it in 1-13 Sep.
      _row(
        '2026-09-01',
        SpendingKind.expense,
        180000,
        category: 'rent',
        essential: true,
      ),
      _row(
        '2026-09-02',
        SpendingKind.expense,
        90000,
        category: 'groceries',
        essential: true,
      ),
      _row(
        '2026-09-03',
        SpendingKind.expense,
        60500,
        category: 'dining',
        essential: false,
      ),
      _row(
        '2026-09-04',
        SpendingKind.expense,
        70000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-09-20',
        SpendingKind.expense,
        31500,
        category: 'other',
        essential: false,
      ),

      // The other complete months: printed totals only.
      _row(
        '2025-10-05',
        SpendingKind.expense,
        390000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2025-11-05',
        SpendingKind.expense,
        390000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2025-12-05',
        SpendingKind.expense,
        410000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-01-05',
        SpendingKind.expense,
        380000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-02-05',
        SpendingKind.expense,
        370000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-03-05',
        SpendingKind.expense,
        418000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-04-05',
        SpendingKind.expense,
        340000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-05-05',
        SpendingKind.expense,
        400000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-06-05',
        SpendingKind.expense,
        400000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-07-05',
        SpendingKind.expense,
        420000,
        category: 'other',
        essential: false,
      ),
      _row(
        '2026-08-05',
        SpendingKind.expense,
        456000,
        category: 'other',
        essential: false,
      ),

      // Salary on the first of each month, Oct 2025 to Oct 2026.
      _row('2025-10-01', SpendingKind.income, 820000),
      _row('2025-11-01', SpendingKind.income, 820000),
      _row('2025-12-01', SpendingKind.income, 820000),
      _row('2026-01-01', SpendingKind.income, 820000),
      _row('2026-02-01', SpendingKind.income, 820000),
      _row('2026-03-01', SpendingKind.income, 820000),
      _row('2026-04-01', SpendingKind.income, 820000),
      _row('2026-05-01', SpendingKind.income, 820000),
      _row('2026-06-01', SpendingKind.income, 820000),
      _row('2026-07-01', SpendingKind.income, 820000),
      _row('2026-08-01', SpendingKind.income, 820000),
      _row('2026-09-01', SpendingKind.income, 820000),

      // Rent received Jan-Mar, bonus in March, interest in Dec and Mar.
      _row('2026-01-03', SpendingKind.income, 180000),
      _row('2026-02-03', SpendingKind.income, 200000),
      _row('2026-03-03', SpendingKind.income, 200000),
      _row('2026-03-15', SpendingKind.income, 600000),
      _row('2025-12-31', SpendingKind.income, 50000),
      _row('2026-03-31', SpendingKind.income, 50000),
    ];

/// The 12 complete months before October 2026, with their printed totals.
List<MonthlyTotal> appendixAMonthlyTotals() => <MonthlyTotal>[
      MonthlyTotal(year: 2025, month: 10, amount: cents(390000)),
      MonthlyTotal(year: 2025, month: 11, amount: cents(390000)),
      MonthlyTotal(year: 2025, month: 12, amount: cents(410000)),
      MonthlyTotal(year: 2026, month: 1, amount: cents(380000)),
      MonthlyTotal(year: 2026, month: 2, amount: cents(370000)),
      MonthlyTotal(year: 2026, month: 3, amount: cents(418000)),
      MonthlyTotal(year: 2026, month: 4, amount: cents(340000)),
      MonthlyTotal(year: 2026, month: 5, amount: cents(400000)),
      MonthlyTotal(year: 2026, month: 6, amount: cents(400000)),
      MonthlyTotal(year: 2026, month: 7, amount: cents(420000)),
      MonthlyTotal(year: 2026, month: 8, amount: cents(456000)),
      MonthlyTotal(year: 2026, month: 9, amount: cents(432000)),
    ];

/// SPEC Appendix A: the cash you can use on 13 Oct 2026.
Money appendixACashYouCanUse() => cents(2145000);

/// SPEC Appendix A: the October 2026 limit total.
Money appendixAOctoberLimit() => cents(520000);

/// SPEC Appendix A: money out on the same days of September (1-13 Sep).
Money appendixASameDaysSeptember() => cents(400500);
