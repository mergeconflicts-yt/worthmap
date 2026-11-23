import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/domain/numbers/spending_totals.dart';
import 'package:contour/domain/payments/payment_refund.dart';
import 'package:flutter_test/flutter_test.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

SpendingEntry _entry({
  SpendingKind kind = SpendingKind.expense,
  int minor = 1000,
  bool? essential = false,
}) =>
    SpendingEntry(
      date: LocalDate.parse('2026-10-05'),
      kind: kind,
      amount: _usd(minor),
      categoryId: 'dining',
      isEssential: essential,
    );

void main() {
  group('checkRefund', () {
    test('a partial refund leaves the rest refundable', () {
      final result = checkRefund(
        original: _usd(12130),
        alreadyRefunded: _usd(0),
        refund: _usd(3000),
      );
      expect(result, isA<AllowedRefund>());
      expect((result as AllowedRefund).remaining, _usd(9130));
    });

    test('a full refund leaves a known zero', () {
      final result = checkRefund(
        original: _usd(12130),
        alreadyRefunded: _usd(0),
        refund: _usd(12130),
      );
      expect((result as AllowedRefund).remaining, _usd(0));
    });

    test('earlier refunds reduce what is available', () {
      final result = checkRefund(
        original: _usd(1000),
        alreadyRefunded: _usd(400),
        refund: _usd(600),
      );
      expect((result as AllowedRefund).remaining, _usd(0));
    });

    test('a refund above the remainder reports the excess', () {
      final result = checkRefund(
        original: _usd(1000),
        alreadyRefunded: _usd(400),
        refund: _usd(700),
      );
      expect(result, isA<RefundExceeds>());
      expect((result as RefundExceeds).over, _usd(100));
    });

    test('rejects a zero original or refund', () {
      expect(
        () => checkRefund(
          original: _usd(0),
          alreadyRefunded: _usd(0),
          refund: _usd(100),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => checkRefund(
          original: _usd(100),
          alreadyRefunded: _usd(0),
          refund: _usd(0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a negative already-refunded amount', () {
      expect(
        () => checkRefund(
          original: _usd(100),
          alreadyRefunded: _usd(-1),
          refund: _usd(50),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects another currency', () {
      expect(
        () => checkRefund(
          original: _usd(100),
          alreadyRefunded: _usd(0),
          refund: Money.fromMinor(50, Currency.eur),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('refund against spending (F08-D)', () {
    test('a full refund is a known zero, unlike no rows', () {
      final refunded = spendingTotals(
        <SpendingEntry>[
          _entry(minor: 1000),
          _entry(kind: SpendingKind.refund, minor: 1000),
        ],
        currency: Currency.usd,
      );
      expect(refunded.moneyOut, isA<KnownTotal>());
      expect((refunded.moneyOut as KnownTotal).amount, _usd(0));

      final none =
          spendingTotals(const <SpendingEntry>[], currency: Currency.usd);
      expect(none.moneyOut, isA<NoneRecordedTotal>());
    });
  });
}
