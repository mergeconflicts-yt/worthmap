import 'package:contour/core/money.dart';
import 'package:contour/domain/numbers/spending_totals.dart';
import 'package:contour/domain/payments/payment_expectation.dart';
import 'package:flutter_test/flutter_test.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

Expectation _expectation({
  int minor = 64000,
  ExpectationKind kind = ExpectationKind.reimbursement,
  String? paymentId = 'payment-1',
}) =>
    Expectation(
      expected: _usd(minor),
      kind: kind,
      paymentId: paymentId,
    );

void main() {
  group('Expectation', () {
    test('a reimbursement needs its payment', () {
      expect(
        () => _expectation(paymentId: null),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a refund needs its payment', () {
      expect(
        () => _expectation(kind: ExpectationKind.refund, paymentId: null),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a deposit or other money owed needs no payment', () {
      expect(
        _expectation(kind: ExpectationKind.deposit, paymentId: null).kind,
        ExpectationKind.deposit,
      );
      expect(
        _expectation(kind: ExpectationKind.other, paymentId: null).kind,
        ExpectationKind.other,
      );
    });

    test('an empty payment id is rejected', () {
      expect(() => _expectation(paymentId: ''), throwsA(isA<ArgumentError>()));
    });

    test('the expected amount must be positive', () {
      expect(() => _expectation(minor: 0), throwsA(isA<ArgumentError>()));
      expect(() => _expectation(minor: -1), throwsA(isA<ArgumentError>()));
    });
  });

  group('applyReceipt', () {
    test('a partial receipt reduces the remainder once', () {
      final update = applyReceipt(
        _expectation(),
        receivedSoFar: _usd(0),
        receipt: _usd(20000),
      );
      expect(update.applied, _usd(20000));
      expect(update.unallocated, _usd(0));
      expect(update.remaining, _usd(44000));
    });

    test('the final receipt closes the remainder', () {
      final update = applyReceipt(
        _expectation(),
        receivedSoFar: _usd(44000),
        receipt: _usd(20000),
      );
      expect(update.applied, _usd(20000));
      expect(update.remaining, _usd(0));
    });

    test('a larger receipt keeps its unallocated part', () {
      final update = applyReceipt(
        _expectation(),
        receivedSoFar: _usd(0),
        receipt: _usd(70000),
      );
      expect(update.applied, _usd(64000));
      expect(update.unallocated, _usd(6000));
      expect(update.remaining, _usd(0));
    });

    test('a receipt after the remainder is fully unallocated', () {
      final update = applyReceipt(
        _expectation(),
        receivedSoFar: _usd(64000),
        receipt: _usd(100),
      );
      expect(update.applied, _usd(0));
      expect(update.unallocated, _usd(100));
      expect(update.remaining, _usd(0));
    });

    test('rejects a zero or negative receipt', () {
      expect(
        () => applyReceipt(
          _expectation(),
          receivedSoFar: _usd(0),
          receipt: _usd(0),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => applyReceipt(
          _expectation(),
          receivedSoFar: _usd(0),
          receipt: _usd(-1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a received total above the expectation', () {
      expect(
        () => applyReceipt(
          _expectation(),
          receivedSoFar: _usd(70000),
          receipt: _usd(100),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a negative received total', () {
      expect(
        () => applyReceipt(
          _expectation(),
          receivedSoFar: _usd(-1),
          receipt: _usd(100),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects another currency', () {
      expect(
        () => applyReceipt(
          _expectation(),
          receivedSoFar: Money.fromMinor(0, Currency.eur),
          receipt: _usd(100),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
      expect(
        () => applyReceipt(
          _expectation(),
          receivedSoFar: _usd(0),
          receipt: Money.fromMinor(100, Currency.eur),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('reverseReceipt', () {
    test('reopens the remainder with the applied amount', () {
      final remaining = reverseReceipt(
        expectation: _expectation(),
        receivedSoFar: _usd(20000),
        applied: _usd(20000),
      );
      expect(remaining, _usd(64000));
    });

    test('a later receipt stays accounted for', () {
      final remaining = reverseReceipt(
        expectation: _expectation(),
        receivedSoFar: _usd(44000),
        applied: _usd(20000),
      );
      expect(remaining, _usd(40000));
    });

    test('rejects a zero applied amount or one above the receipts', () {
      expect(
        () => reverseReceipt(
          expectation: _expectation(),
          receivedSoFar: _usd(20000),
          applied: _usd(0),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => reverseReceipt(
          expectation: _expectation(),
          receivedSoFar: _usd(20000),
          applied: _usd(30000),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects another currency', () {
      expect(
        () => reverseReceipt(
          expectation: _expectation(),
          receivedSoFar: _usd(20000),
          applied: Money.fromMinor(100, Currency.eur),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('cancelExpectation', () {
    test('a reimbursement makes the payment spending again', () {
      expect(
        cancelExpectation(_expectation()),
        CancellationEffect.paymentCountsAsSpending,
      );
    });

    test('a refund closes with spending unchanged', () {
      expect(
        cancelExpectation(_expectation(kind: ExpectationKind.refund)),
        CancellationEffect.spendingUnchanged,
      );
    });

    test('a deposit or other money owed closes with spending unchanged', () {
      expect(
        cancelExpectation(
          _expectation(kind: ExpectationKind.deposit, paymentId: null),
        ),
        CancellationEffect.spendingUnchanged,
      );
      expect(
        cancelExpectation(
          _expectation(kind: ExpectationKind.other, paymentId: null),
        ),
        CancellationEffect.spendingUnchanged,
      );
    });
  });

  group('validatePaymentFlags', () {
    test('accepts one flag on an expense', () {
      validatePaymentFlags(
        kind: SpendingKind.expense,
        reimbursable: true,
        refundExpected: false,
      );
      validatePaymentFlags(
        kind: SpendingKind.expense,
        reimbursable: false,
        refundExpected: true,
      );
      validatePaymentFlags(
        kind: SpendingKind.expense,
        reimbursable: false,
        refundExpected: false,
      );
    });

    test('rejects both flags at once', () {
      expect(
        () => validatePaymentFlags(
          kind: SpendingKind.expense,
          reimbursable: true,
          refundExpected: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a flag on a non-expense', () {
      expect(
        () => validatePaymentFlags(
          kind: SpendingKind.income,
          reimbursable: true,
          refundExpected: false,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => validatePaymentFlags(
          kind: SpendingKind.transfer,
          reimbursable: false,
          refundExpected: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
