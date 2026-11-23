import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/domain/importers/quick_add_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/voice_sentences.dart';

const QuickAddParser _parser = QuickAddParser(
  knownMerchants: <String>['Starbucks', 'Tesco', 'Subway'],
  keywordCategories: <String, String>{
    'taxi': 'Transport',
    'coffee': 'Coffee',
    'groceries': 'Groceries',
    'parking': 'Parking',
  },
);

PaymentDraft _parse(
  String sentence, {
  QuickAddParser parser = _parser,
  Currency mainCurrency = Currency.usd,
  LocalDate? today,
}) =>
    parser.parse(
      sentence,
      today: today ?? testDay,
      mainCurrency: mainCurrency,
    );

String _code(String? code) => code ?? 'USD';

Currency _currency(String? code) =>
    code == null ? Currency.usd : Currency.of(code);

LocalDate _shift(LocalDate date, int days) {
  final shifted =
      DateTime.utc(date.year, date.month, date.day).add(Duration(days: days));
  return LocalDate(shifted.year, shifted.month, shifted.day);
}

void main() {
  group('SPEC 8.10 voice sentences', () {
    for (final testCase in voiceCases) {
      test(testCase.sentence, () {
        final draft = _parse(testCase.sentence);
        final expected = testCase.expected;
        if (expected.amountMinor == null) {
          expect(draft.amount, isNull);
          expect(draft.hasAmount, isFalse);
        } else {
          expect(
            draft.amount,
            Money.fromMinor(
              expected.amountMinor!,
              _currency(expected.currencyCode),
            ),
          );
          expect(draft.currency.code, _code(expected.currencyCode));
          expect(draft.currencyExplicit, expected.currencyCode != null);
        }
        expect(draft.merchant, expected.merchant, reason: 'merchant');
        expect(draft.category, expected.category, reason: 'category');
        expect(draft.date, _shift(testDay, expected.dayOffset), reason: 'date');
        expect(draft.isIncome, expected.isIncome, reason: 'income');
        expect(draft.secondAmount?.minor, expected.secondAmountMinor);
      });
    }
  });

  group('SPEC 8.3 quick add sentences', () {
    for (final testCase in quickAddCases) {
      test(testCase.sentence, () {
        final draft = _parse(testCase.sentence);
        final expected = testCase.expected;
        expect(
          draft.amount,
          Money.fromMinor(
            expected.amountMinor!,
            _currency(expected.currencyCode),
          ),
        );
        expect(draft.merchant, expected.merchant, reason: 'merchant');
        expect(draft.category, expected.category, reason: 'category');
      });
    }
  });

  group('amounts', () {
    test('a thousands comma and a decimal point', () {
      expect(
        _parse('1,234.56 lunch').amount,
        Money.fromMinor(123456, Currency.usd),
      );
    });

    test('a thousands point and a decimal comma', () {
      expect(
        _parse('lunch 1.234,56').amount,
        Money.fromMinor(123456, Currency.usd),
      );
    });

    test('a decimal comma', () {
      expect(
        _parse('coffee 12,50').amount,
        Money.fromMinor(1250, Currency.usd),
      );
    });

    test('a k suffix multiplies by one thousand', () {
      expect(_parse('1.2k rent').amount, Money.fromMinor(120000, Currency.usd));
    });

    test('a symbol before or after the number', () {
      expect(_parse(r'$40 lunch').amount, Money.fromMinor(4000, Currency.usd));
      expect(_parse(r'lunch 40$').amount, Money.fromMinor(4000, Currency.usd));
    });

    test('currency words', () {
      expect(
        _parse('12 bucks lunch').currency,
        Currency.usd,
      );
      expect(
        _parse('12 rupees lunch').currency,
        Currency.inr,
      );
      expect(
        _parse('12 pounds lunch').currency,
        Currency.gbp,
      );
      expect(
        _parse('12 yen lunch').currency,
        Currency.jpy,
      );
    });

    test('spoken compound numbers', () {
      expect(
        _parse('forty two lunch').amount,
        Money.fromMinor(4200, Currency.usd),
      );
    });

    test('a sentence without an amount keeps the keypad active', () {
      final draft = _parse('Lunch at Subway');
      expect(draft.hasAmount, isFalse);
      expect(draft.confidenceOf(DraftField.amount), FieldConfidence.absent);
    });

    test('a number that belongs to a date is not an amount', () {
      expect(_parse('lunch 12 Oct').hasAmount, isFalse);
      expect(_parse('two days ago lunch').hasAmount, isFalse);
    });
  });

  group('dates', () {
    test('a thousands group without decimals', () {
      expect(
        _parse('lunch 1,234').amount,
        Money.fromMinor(123400, Currency.usd),
      );
      expect(
        _parse('lunch 1,234,567').amount,
        Money.fromMinor(123456700, Currency.usd),
      );
    });

    test('a spoken number before a time unit is not an amount', () {
      expect(_parse('lunch two weeks').hasAmount, isFalse);
    });

    test('today and yesterday', () {
      expect(_parse('lunch 5 today').date, testDay);
      expect(_parse('lunch 5 yesterday').date, LocalDate(2026, 10, 12));
    });

    test('a weekday means the most recent past', () {
      expect(_parse('lunch 5 friday').date, LocalDate(2026, 10, 9));
      expect(_parse('lunch 5 last friday').date, LocalDate(2026, 10, 9));
    });

    test('a relative day count', () {
      expect(_parse('lunch 5 two days ago').date, LocalDate(2026, 10, 11));
      expect(_parse('lunch 5 3 days ago').date, LocalDate(2026, 10, 10));
      expect(_parse('lunch 5 -2d').date, LocalDate(2026, 10, 11));
    });

    test('a day and month uses the most recent year not after today', () {
      expect(_parse('lunch 5 12 Oct').date, LocalDate(2026, 10, 12));
      expect(_parse('lunch 5 20 Dec').date, LocalDate(2025, 12, 20));
    });

    test('an explicit year is honoured', () {
      expect(_parse('lunch 5 12 Oct 2024').date, LocalDate(2024, 10, 12));
    });

    test('a numeric date follows the day-first setting', () {
      expect(_parse('lunch 5 12/10').date, LocalDate(2026, 10, 12));
      expect(
        _parse(
          'lunch 5 12/10',
          parser: const QuickAddParser(dayFirst: false),
        ).date,
        LocalDate(2025, 12, 10),
      );
    });

    test('an impossible date leaves today', () {
      expect(_parse('lunch 5 31 Feb').date, testDay);
    });
  });

  group('confidence and fields', () {
    test('a spoken account needs a check, an explicit one does not', () {
      final spoken = _parse('Coffee 4 euros 50 using my Visa');
      expect(spoken.account, 'Visa');
      expect(spoken.confidenceOf(DraftField.account), FieldConfidence.unsure);
      final explicit = _parse('rent 100 #housing @bank');
      expect(explicit.account, 'bank');
      expect(explicit.confidenceOf(DraftField.account), FieldConfidence.filled);
    });

    test('an account after "on my" needs a check', () {
      final draft = _parse('lunch 10 on my Visa');
      expect(draft.account, 'Visa');
      expect(draft.confidenceOf(DraftField.account), FieldConfidence.unsure);
    });

    test('the filled and unsure counts follow the filled fields', () {
      final draft = _parse('Coffee 4 euros 50 using my Visa');
      expect(draft.filledCount, 2);
      expect(draft.unsureCount, 1);
    });

    test('an explicit category wins over a keyword rule', () {
      expect(_parse('taxi 50 #coffee').category, 'Coffee');
    });

    test('a keyword rule fills the category', () {
      expect(_parse('taxi 50').category, 'Transport');
    });

    test('an unknown merchant keeps its typed text', () {
      expect(_parse('lunch 10 at Bowl').merchant, 'Bowl');
    });

    test('money in is detected from its words', () {
      expect(_parse('received 100').isIncome, isTrue);
      expect(_parse('salary 500').isIncome, isTrue);
      expect(_parse('spent 100').isIncome, isFalse);
    });

    test('no explicit date is reported as absent confidence', () {
      final draft = _parse('lunch 10');
      expect(draft.date, testDay);
      expect(draft.dateExplicit, isFalse);
      expect(draft.confidenceOf(DraftField.date), FieldConfidence.absent);
    });
  });
}
