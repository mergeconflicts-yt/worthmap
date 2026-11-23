import '../../core/money.dart';
import '../numbers/spending_totals.dart';

/// SPEC 4.11: money owed to you, its receipts, cancellation and reversal.
///
/// An expectation is Expected: never cash, never income and never in net
/// worth. A receipt reduces the remainder once; a larger receipt keeps its
/// unallocated part (SPEC 4.11, 8.17). Nothing here writes or formats.

/// SPEC 4.11: why money is expected back.
enum ExpectationKind {
  /// A third party pays back a payment the user made.
  reimbursement,

  /// A merchant returns money for an earlier purchase.
  refund,

  /// A deposit held by another party.
  deposit,

  /// Any other money owed.
  other,
}

/// SPEC 4.11: one expected incoming amount.
final class Expectation {
  Expectation({
    required this.expected,
    required this.kind,
    this.paymentId,
  }) {
    if (expected.minor <= 0) {
      throw ArgumentError.value(expected, 'expected', 'Must be positive');
    }
    final needsPayment =
        kind == ExpectationKind.reimbursement || kind == ExpectationKind.refund;
    if (needsPayment && (paymentId == null || paymentId!.isEmpty)) {
      throw ArgumentError.value(
        paymentId,
        'paymentId',
        'A reimbursement or refund needs its payment',
      );
    }
  }

  /// The amount expected, positive.
  final Money expected;

  /// The reason for the expectation.
  final ExpectationKind kind;

  /// The linked payment, for a reimbursement or a refund.
  final String? paymentId;
}

/// SPEC 4.11: the outcome of a receipt or a reversal.
final class ExpectationUpdate {
  const ExpectationUpdate({
    required this.applied,
    required this.unallocated,
    required this.remaining,
  });

  /// The part of the receipt that reduces the expectation.
  final Money applied;

  /// The part above the remainder; it stays unallocated (8.17).
  final Money unallocated;

  /// What is still expected after the receipt.
  final Money remaining;
}

/// SPEC 4.11: applies a confirmed receipt to an expectation.
///
/// The allocation never exceeds the remainder; a larger receipt keeps its
/// unallocated part and no remainder becomes zero silently.
ExpectationUpdate applyReceipt(
  Expectation expectation, {
  required Money receivedSoFar,
  required Money receipt,
}) {
  final currency = expectation.expected.currency;
  if (receivedSoFar.currency != currency || receipt.currency != currency) {
    throw MoneyCurrencyMismatch(receipt.currency.code, currency.code);
  }
  if (receivedSoFar.isNegative) {
    throw ArgumentError.value(
      receivedSoFar,
      'receivedSoFar',
      'Must be zero or positive',
    );
  }
  if (receipt.minor <= 0) {
    throw ArgumentError.value(receipt, 'receipt', 'Must be positive');
  }
  final remainingBefore = expectation.expected - receivedSoFar;
  if (remainingBefore.isNegative) {
    throw ArgumentError.value(
      receivedSoFar,
      'receivedSoFar',
      'Must not exceed the expected amount',
    );
  }
  final applied =
      receipt.compareTo(remainingBefore) <= 0 ? receipt : remainingBefore;
  return ExpectationUpdate(
    applied: applied,
    unallocated: receipt - applied,
    remaining: remainingBefore - applied,
  );
}

/// SPEC 4.11: the remainder after a confirmed receipt is reversed.
///
/// A reversal is a compensating posting dated when it happens; it reopens the
/// remainder and never rewrites a past period (8.18).
Money reverseReceipt({
  required Expectation expectation,
  required Money receivedSoFar,
  required Money applied,
}) {
  final currency = expectation.expected.currency;
  if (receivedSoFar.currency != currency || applied.currency != currency) {
    throw MoneyCurrencyMismatch(applied.currency.code, currency.code);
  }
  if (applied.minor <= 0) {
    throw ArgumentError.value(applied, 'applied', 'Must be positive');
  }
  if (applied.compareTo(receivedSoFar) > 0) {
    throw ArgumentError.value(
      applied,
      'applied',
      'Must not exceed what was received',
    );
  }
  final remaining = expectation.expected - receivedSoFar;
  return remaining + applied;
}

/// SPEC 4.11: what cancelling an expectation does to the linked payment.
enum CancellationEffect {
  /// A reimbursable payment counts as personal spending again.
  paymentCountsAsSpending,

  /// Spending does not change (a refund expectation closes).
  spendingUnchanged,
}

/// SPEC 4.11: cancelling is allowed while no money is confirmed.
CancellationEffect cancelExpectation(Expectation expectation) =>
    switch (expectation.kind) {
      ExpectationKind.reimbursement =>
        CancellationEffect.paymentCountsAsSpending,
      ExpectationKind.refund ||
      ExpectationKind.deposit ||
      ExpectationKind.other =>
        CancellationEffect.spendingUnchanged,
    };

/// SPEC 4.11: a payment has one reason for money coming back.
///
/// Reimbursable and Refund expected are exclusive, and both apply only to an
/// expense. Both at once would count one amount twice.
void validatePaymentFlags({
  required SpendingKind kind,
  required bool reimbursable,
  required bool refundExpected,
}) {
  if (reimbursable && refundExpected) {
    throw ArgumentError(
      'A payment has one reason for money coming back (SPEC 4.11)',
    );
  }
  if ((reimbursable || refundExpected) && kind != SpendingKind.expense) {
    throw ArgumentError(
      'Only an expense can be reimbursable or refund expected (SPEC 4.11)',
    );
  }
}
