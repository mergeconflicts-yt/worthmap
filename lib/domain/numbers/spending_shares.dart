import 'package:decimal/decimal.dart';

import '../../core/money.dart';
import '../../core/percent.dart';
import 'spending_ratio.dart';
import 'spending_totals.dart';

/// SPEC 6.5 / 4.4: shares of spending and money in, by category and by tag.
///
/// Category shares are plain ratios: they are not parts of one split, so they
/// are not forced to add to 100% (SPEC 4.1 applies largest-remainder rounding
/// to one split only). The needs/wants split is one split, so it adds to
/// exactly 100% when the total is positive.

/// One category and its money out in the period.
final class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.spent,
    required this.isEssential,
  });

  /// The category identifier.
  final String categoryId;

  /// Money out in this category (expenses plus fees minus refunds).
  final Money spent;

  /// The user's needs/wants tag, or null when the category has none.
  final bool? isEssential;
}

/// SPEC 6.5: money out per category, largest first.
///
/// Amounts without a category are not listed; they stay in the totals as
/// unclassified (see [spendingTotals]).
List<CategorySpend> categorySpending(
  Iterable<SpendingEntry> entries, {
  required Currency currency,
}) {
  final spent = <String, Money>{};
  final essential = <String, bool?>{};
  for (final entry in entries) {
    final categoryId = entry.categoryId;
    if (categoryId == null) {
      continue;
    }
    if (entry.amount.currency != currency) {
      throw MoneyCurrencyMismatch(
        entry.amount.currency.code,
        currency.code,
      );
    }
    final current = spent[categoryId] ?? Money.zero(currency);
    switch (entry.kind) {
      case SpendingKind.expense:
      case SpendingKind.fee:
        spent[categoryId] = current + entry.amount;
        if (entry.isEssential != null) {
          essential[categoryId] = entry.isEssential;
        }
      case SpendingKind.refund:
        spent[categoryId] = current - entry.amount;
        if (entry.isEssential != null) {
          essential[categoryId] ??= entry.isEssential;
        }
      case SpendingKind.income:
      case SpendingKind.reimbursable:
      case SpendingKind.transfer:
      case SpendingKind.loanIn:
      case SpendingKind.saleProceeds:
        break;
    }
  }
  final rows = <CategorySpend>[
    for (final entry in spent.entries)
      CategorySpend(
        categoryId: entry.key,
        spent: entry.value,
        isEssential: essential[entry.key],
      ),
  ]..sort((a, b) => b.spent.compareTo(a.spent));
  return rows;
}

/// SPEC 6.5: one category as a share of a whole (spending or money in).
///
/// Returns null when the denominator is zero or negative: "Not available",
/// never 0% (SPEC 4.3).
Percent? shareOfWhole(Money part, Money whole, {int scale = 1}) =>
    percentOfMoney(part, whole, scale: scale);

/// SPEC 4.4 / Appendix B: needs, wants and unclassified as one split.
///
/// Returns an empty list when spending is not known or is zero or negative:
/// there is no split to show. Otherwise the three shares add to exactly 100%
/// (SPEC 4.1).
List<Percent> needsWantsShares(SpendingTotals totals, {int scale = 1}) {
  final needs = totals.needs;
  final wants = totals.wants;
  final unclassified = totals.unclassified;
  if (needs is! KnownTotal ||
      wants is! KnownTotal ||
      unclassified is! KnownTotal) {
    return const <Percent>[];
  }
  final parts = <Money>[needs.amount, wants.amount, unclassified.amount];
  var total = BigInt.zero;
  for (final part in parts) {
    if (part.isNegative) {
      return const <Percent>[];
    }
    total += BigInt.from(part.minor);
  }
  if (total == BigInt.zero) {
    return const <Percent>[];
  }
  return Percent.split(
    <Decimal>[for (final part in parts) part.toDecimal()],
    scale: scale,
  );
}
