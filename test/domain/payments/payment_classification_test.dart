import 'package:contour/core/money.dart';
import 'package:contour/domain/numbers/spending_totals.dart';
import 'package:contour/domain/payments/payment_classification.dart';
import 'package:flutter_test/flutter_test.dart';

Money _usd(int minor) => Money.fromMinor(minor, Currency.usd);

AccountRef _checking() =>
    const AccountRef(id: 'checking', currency: Currency.usd);

AccountRef _savings() =>
    const AccountRef(id: 'savings', currency: Currency.usd);

AccountRef _visa({bool includeInNetWorth = true}) => AccountRef(
      id: 'visa',
      currency: Currency.usd,
      isLiability: true,
      includeInNetWorth: includeInNetWorth,
    );

void main() {
  group('expense and income', () {
    test('an expense posts one negative posting on its account', () {
      final event = classifyPayment(
        ExpenseRequest(amount: _usd(12130), account: _checking()),
      );
      expect(event.postings.length, 1);
      final posting = event.postings.single;
      expect(posting.kind, SpendingKind.expense);
      expect(posting.amount, _usd(-12130));
      expect(posting.account.id, 'checking');
      expect(posting.isPrincipal, isFalse);
      expect(event.feePosting, isNull);
      expect(event.netWorthChange, _usd(-12130));
    });

    test('a card expense is negative on the card account', () {
      final event = classifyPayment(
        ExpenseRequest(amount: _usd(640), account: _visa()),
      );
      expect(event.postings.single.amount, _usd(-640));
      expect(event.netWorthChange, _usd(-640));
    });

    test('income posts one positive posting', () {
      final event = classifyPayment(
        IncomeRequest(amount: _usd(820000), account: _checking()),
      );
      expect(event.postings.single.kind, SpendingKind.income);
      expect(event.postings.single.amount, _usd(820000));
      expect(event.netWorthChange, _usd(820000));
    });

    test('a zero or negative amount is rejected', () {
      expect(
        () => ExpenseRequest(amount: _usd(0), account: _checking()),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => IncomeRequest(amount: _usd(-1), account: _checking()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('an amount in another currency is rejected', () {
      expect(
        () => ExpenseRequest(
          amount: Money.fromMinor(100, Currency.eur),
          account: _checking(),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('transfer', () {
    test('writes a debit and a credit and no net worth change', () {
      final request = TransferRequest(
        from: _checking(),
        to: _savings(),
        amount: _usd(124000),
      );
      final event = classifyPayment(request);
      expect(event.postings.length, 2);
      expect(event.postings[0].amount, _usd(-124000));
      expect(event.postings[0].kind, SpendingKind.transfer);
      expect(event.postings[1].amount, _usd(124000));
      expect(event.postings[1].kind, SpendingKind.transfer);
      expect(event.netWorthChange, _usd(0));
      expect(request.paysLiability, isFalse);
    });

    test('a card repayment is a transfer to a liability account', () {
      final request = TransferRequest(
        from: _checking(),
        to: _visa(),
        amount: _usd(124000),
      );
      final event = classifyPayment(request);
      expect(request.paysLiability, isTrue);
      expect(event.postings[1].amount, _usd(124000));
      expect(event.netWorthChange, _usd(0));
    });

    test('one charged fee posts once, negative on the paying account', () {
      final event = classifyPayment(
        TransferRequest(
          from: _checking(),
          to: _savings(),
          amount: _usd(200000),
          fee: _usd(1200),
        ),
      );
      expect(event.postings.length, 3);
      final fee = event.feePosting;
      expect(fee, isNotNull);
      expect(fee!.kind, SpendingKind.fee);
      expect(fee.amount, _usd(-1200));
      expect(fee.account.id, 'checking');
      expect(event.netWorthChange, _usd(-1200));
    });

    test('the same account is rejected', () {
      expect(
        () => TransferRequest(
          from: _checking(),
          to: _checking(),
          amount: _usd(100),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a cross-currency transfer is rejected in this phase', () {
      expect(
        () => TransferRequest(
          from: _checking(),
          to: const AccountRef(id: 'inr', currency: Currency.inr),
          amount: _usd(100),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a zero amount is rejected', () {
      expect(
        () => TransferRequest(
          from: _checking(),
          to: _savings(),
          amount: _usd(0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a zero, negative or foreign fee is rejected', () {
      expect(
        () => TransferRequest(
          from: _checking(),
          to: _savings(),
          amount: _usd(100),
          fee: _usd(0),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TransferRequest(
          from: _checking(),
          to: _savings(),
          amount: _usd(100),
          fee: _usd(-5),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TransferRequest(
          from: _checking(),
          to: _savings(),
          amount: _usd(100),
          fee: Money.fromMinor(5, Currency.eur),
        ),
        throwsA(isA<MoneyCurrencyMismatch>()),
      );
    });
  });

  group('net worth boundary (F05-E)', () {
    test('leaving an included account for an excluded one falls', () {
      final event = classifyPayment(
        TransferRequest(
          from: _checking(),
          to: _visa(includeInNetWorth: false),
          amount: _usd(50000),
        ),
      );
      expect(event.netWorthChange, _usd(-50000));
    });

    test('entering an included account from an excluded one rises', () {
      final event = classifyPayment(
        TransferRequest(
          from: _visa(includeInNetWorth: false),
          to: _checking(),
          amount: _usd(50000),
        ),
      );
      expect(event.netWorthChange, _usd(50000));
    });

    test('two excluded accounts change nothing', () {
      final event = classifyPayment(
        TransferRequest(
          from: _visa(includeInNetWorth: false),
          to: const AccountRef(
            id: 'loan',
            currency: Currency.usd,
            isLiability: true,
            includeInNetWorth: false,
          ),
          amount: _usd(50000),
        ),
      );
      expect(event.netWorthChange, _usd(0));
    });
  });

  group('PaymentEvent', () {
    test('rejects an empty posting set', () {
      expect(
        () => PaymentEvent(postings: const <Posting>[]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
