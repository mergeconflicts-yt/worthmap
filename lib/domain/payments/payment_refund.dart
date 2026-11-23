import '../../core/money.dart';

/// SPEC 4.2 / 4.11: a refund never returns more than the original payment.
///
/// A refund reduces spending in the original category under the refund
/// recognition period; partial refunds are allowed. The check returns the
/// remaining refundable amount so the caller writes one linked posting and
/// never a second copy of the original.

/// SPEC 4.2: the result of checking a refund against its original.
sealed class RefundCheck {
  const RefundCheck();
}

/// The refund fits; [remaining] stays refundable.
final class AllowedRefund extends RefundCheck {
  const AllowedRefund({required this.remaining});

  /// The amount of the original payment that is still refundable.
  final Money remaining;
}

/// The refund is larger than what is left of the original.
final class RefundExceeds extends RefundCheck {
  const RefundExceeds({required this.over});

  /// The amount above the remaining refundable amount.
  final Money over;
}

/// SPEC 4.2: checks a refund against the original and earlier refunds.
///
/// [alreadyRefunded] is the sum of confirmed refunds linked to the original.
/// A refund of the whole original leaves a known zero (F08-D), which is not
/// the same as no refund at all.
RefundCheck checkRefund({
  required Money original,
  required Money alreadyRefunded,
  required Money refund,
}) {
  if (original.minor <= 0) {
    throw ArgumentError.value(original, 'original', 'Must be positive');
  }
  if (refund.minor <= 0) {
    throw ArgumentError.value(refund, 'refund', 'Must be positive');
  }
  if (alreadyRefunded.isNegative) {
    throw ArgumentError.value(
      alreadyRefunded,
      'alreadyRefunded',
      'Must be zero or positive',
    );
  }
  if (alreadyRefunded.currency != original.currency ||
      refund.currency != original.currency) {
    throw MoneyCurrencyMismatch(
      refund.currency.code,
      original.currency.code,
    );
  }
  final available = original - alreadyRefunded;
  if (refund.compareTo(available) <= 0) {
    return AllowedRefund(remaining: available - refund);
  }
  return RefundExceeds(over: refund - available);
}
