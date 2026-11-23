import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/percent.dart';
import 'spending_ratio.dart';

/// SPEC 4.4: money in, money out (spent) and kept for one period.
///
/// Pure Dart. The caller supplies rows that are already classified: the
/// presence of a refund or a reimbursable flag is a domain fact (SPEC 4.2,
/// 4.11), not a guess made here. No database, no clock and no formatting.

/// The class of one row for the spending numbers (SPEC 4.4, 4.10, 4.11).
enum SpendingKind {
  /// An expense transaction. Counts in money out.
  expense,

  /// An income transaction. Counts in money in; excludes transfers, loan
  /// money, sale proceeds, refunds and reimbursements (SPEC 4.4).
  income,

  /// A merchant refund. Reduces money out and the category it names.
  refund,

  /// A payment a third party pays back. Never personal spending (SPEC 4.11).
  reimbursable,

  /// A transfer principal. Never income and never spending (SPEC 4.2).
  transfer,

  /// A charged fee. Counts in money out (SPEC 4.10).
  fee,

  /// Loan money received. Not income (SPEC 4.3).
  loanIn,

  /// Sale proceeds. Not income (SPEC 4.3).
  saleProceeds,
}

/// One dated amount in a spending period.
///
/// [amount] is zero or positive; [kind] gives the direction. A negative
/// amount is a caller error and throws. [isEssential] is the user's category
/// tag; null means the amount has no category, so it is never guessed
/// (SPEC 4.8, Appendix B "Needs and wants").
final class SpendingEntry {
  SpendingEntry({
    required this.date,
    required this.kind,
    required this.amount,
    this.categoryId,
    this.isEssential,
  }) {
    if (amount.isNegative) {
      throw ArgumentError.value(amount, 'amount', 'Must be zero or positive');
    }
  }

  /// The local calendar date of the payment.
  final LocalDate date;

  /// The class of the amount.
  final SpendingKind kind;

  /// The amount in its own currency.
  final Money amount;

  /// The category, when the amount has one.
  final String? categoryId;

  /// The user's needs/wants tag, when the amount has a category.
  final bool? isEssential;
}

/// SPEC 4.9: a total is known, nothing is recorded, or it is not available.
///
/// Unknown is never zero (SPEC 4.3). A caller renders [NoneRecordedTotal] as
/// "None recorded" and [NotAvailableTotal] as "Not available", never "$0".
sealed class Total {
  const Total();
}

/// A real total from the recorded rows.
final class KnownTotal extends Total {
  const KnownTotal(this.amount);

  /// The exact total.
  final Money amount;
}

/// No row exists for this number in the period.
final class NoneRecordedTotal extends Total {
  const NoneRecordedTotal();
}

/// A total cannot be computed from the recorded rows.
final class NotAvailableTotal extends Total {
  const NotAvailableTotal(this.reason);

  /// The factual reason for the state.
  final NotAvailableReason reason;
}

/// SPEC 4.4: why a derived total is not available.
enum NotAvailableReason {
  /// Money in has no recorded row.
  moneyInNotRecorded,

  /// Money out has no recorded row.
  moneyOutNotRecorded,
}

/// SPEC 4.4: the totals of one period.
final class SpendingTotals {
  const SpendingTotals({
    required this.currency,
    required this.moneyIn,
    required this.moneyOut,
    required this.kept,
    required this.keptPercent,
    required this.needs,
    required this.wants,
    required this.unclassified,
  });

  /// The currency every total uses.
  final Currency currency;

  /// Income in the period.
  final Total moneyIn;

  /// Expenses and fees minus refunds; transfers and reimbursables excluded.
  final Total moneyOut;

  /// Money in minus money out; not available when either side is not known.
  final Total kept;

  /// Kept as a share of money in, or null when not available.
  final Percent? keptPercent;

  /// The essential part of money out (SPEC Appendix B).
  final Total needs;

  /// The non-essential part of money out.
  final Total wants;

  /// The part of money out with no category, never guessed into a part.
  final Total unclassified;
}

/// SPEC 4.4: computes the period totals from classified rows.
///
/// Rules:
/// - money in = income only;
/// - money out = expense + fee - refund;
/// - reimbursable, transfer, loan money and sale proceeds are excluded;
/// - needs, wants and unclassified partition money out by the user's
///   `isEssential` tag; an amount without a category is unclassified and is
///   never labelled (SPEC 4.3, Appendix B).
SpendingTotals spendingTotals(
  Iterable<SpendingEntry> entries, {
  required Currency currency,
}) {
  var income = Money.zero(currency);
  var expense = Money.zero(currency);
  var fee = Money.zero(currency);
  var refund = Money.zero(currency);
  var needs = Money.zero(currency);
  var wants = Money.zero(currency);
  var unclassified = Money.zero(currency);
  var sawIncome = false;
  var sawMoneyOut = false;

  void classify(SpendingEntry entry, {required bool subtract}) {
    final bucket = entry.isEssential;
    if (bucket == null) {
      unclassified =
          subtract ? unclassified - entry.amount : unclassified + entry.amount;
    } else if (bucket) {
      needs = subtract ? needs - entry.amount : needs + entry.amount;
    } else {
      wants = subtract ? wants - entry.amount : wants + entry.amount;
    }
  }

  for (final entry in entries) {
    if (entry.amount.currency != currency) {
      throw MoneyCurrencyMismatch(
        entry.amount.currency.code,
        currency.code,
      );
    }
    switch (entry.kind) {
      case SpendingKind.income:
        income = income + entry.amount;
        sawIncome = true;
      case SpendingKind.expense:
        expense = expense + entry.amount;
        sawMoneyOut = true;
        classify(entry, subtract: false);
      case SpendingKind.fee:
        fee = fee + entry.amount;
        sawMoneyOut = true;
        classify(entry, subtract: false);
      case SpendingKind.refund:
        refund = refund + entry.amount;
        sawMoneyOut = true;
        classify(entry, subtract: true);
      case SpendingKind.reimbursable:
      case SpendingKind.transfer:
      case SpendingKind.loanIn:
      case SpendingKind.saleProceeds:
        break;
    }
  }

  final moneyIn = sawIncome ? KnownTotal(income) : const NoneRecordedTotal();
  final moneyOut = sawMoneyOut
      ? KnownTotal(expense + fee - refund)
      : const NoneRecordedTotal();

  final Total kept;
  Percent? keptPercent;
  if (moneyIn is KnownTotal && moneyOut is KnownTotal) {
    final keptAmount = moneyIn.amount - moneyOut.amount;
    kept = KnownTotal(keptAmount);
    keptPercent = moneyIn.amount.minor > 0
        ? percentOfMoney(keptAmount, moneyIn.amount)
        : null;
  } else if (moneyIn is NoneRecordedTotal) {
    kept = const NotAvailableTotal(NotAvailableReason.moneyInNotRecorded);
  } else {
    kept = const NotAvailableTotal(NotAvailableReason.moneyOutNotRecorded);
  }

  return SpendingTotals(
    currency: currency,
    moneyIn: moneyIn,
    moneyOut: moneyOut,
    kept: kept,
    keptPercent: keptPercent,
    needs: sawMoneyOut ? KnownTotal(needs) : const NoneRecordedTotal(),
    wants: sawMoneyOut ? KnownTotal(wants) : const NoneRecordedTotal(),
    unclassified:
        sawMoneyOut ? KnownTotal(unclassified) : const NoneRecordedTotal(),
  );
}
