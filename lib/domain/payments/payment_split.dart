import '../../core/money.dart';

/// SPEC 4.1 / 6.3: a split adds to exactly the whole amount.
///
/// X23 shows "Left to split" and enables Save only when nothing is left. The
/// validator returns that remainder; it never rounds or clamps a part.

/// One part of a split payment.
final class SplitPart {
  SplitPart({
    required this.amount,
    required this.categoryId,
    required this.isEssential,
  }) {
    if (amount.minor <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive');
    }
    if (categoryId.isEmpty) {
      throw ArgumentError.value(categoryId, 'categoryId', 'Must not be empty');
    }
  }

  /// The part amount, positive.
  final Money amount;

  /// The category this part belongs to.
  final String categoryId;

  /// The user's needs/wants tag for the category.
  final bool isEssential;
}

/// SPEC 6.3: the result of checking a split against its total.
sealed class SplitCheck {
  const SplitCheck();
}

/// The parts add to the total exactly; Save is active.
final class BalancedSplit extends SplitCheck {
  BalancedSplit({required this.total, required this.parts});

  /// The whole amount.
  final Money total;

  /// The parts, in input order.
  final List<SplitPart> parts;
}

/// The parts do not add to the total; Save stays inactive.
final class UnbalancedSplit extends SplitCheck {
  const UnbalancedSplit({required this.left});

  /// What is still unassigned: total minus the parts. Negative when the parts
  /// exceed the total.
  final Money left;
}

/// SPEC 4.1: checks that [parts] add to [total] exactly.
///
/// A zero or negative total is a caller error. Parts in another currency are
/// rejected, never converted.
SplitCheck checkSplit({
  required Money total,
  required List<SplitPart> parts,
}) {
  if (total.minor <= 0) {
    throw ArgumentError.value(total, 'total', 'Must be positive');
  }
  var sum = Money.zero(total.currency);
  for (final part in parts) {
    if (part.amount.currency != total.currency) {
      throw MoneyCurrencyMismatch(
        part.amount.currency.code,
        total.currency.code,
      );
    }
    sum = sum + part.amount;
  }
  if (sum == total) {
    return BalancedSplit(
      total: total,
      parts: List<SplitPart>.unmodifiable(parts),
    );
  }
  return UnbalancedSplit(left: total - sum);
}
