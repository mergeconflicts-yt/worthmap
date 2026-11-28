// SPEC 9.2, SPEC 4.9, DECISIONS P4-VALUE-METHOD-BASIS: the value methods.
//
// The basis is actual days, one year is 365 days, the user's compounding,
// pro-rata growth from each date, and one half-even round to minor units.

import 'package:contour/core/dates.dart';
import 'package:contour/core/money.dart';
import 'package:contour/domain/values/value_projection.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

Money usd(int minor) => Money.fromMinor(minor, Currency.usd);

int amountOf(ProjectedValue value) => switch (value) {
      KnownValue(:final amount) => amount.minor,
      EstimatedValue(:final amount) => amount.minor,
      UnavailableValue() => fail('Expected a value, got $value'),
    };

void main() {
  group('interest', () {
    test('a monthly deposit is 10,278 on 13 October', () {
      final value = projectInterest(
        principal: usd(1000000),
        annualRate: Decimal.parse('0.041'),
        compounding: Compounding.monthly,
        start: LocalDate(2026, 2, 12),
        asOf: LocalDate(2026, 10, 13),
        maturity: LocalDate(2026, 11, 12),
      );
      expect(value, isA<EstimatedValue>());
      expect(amountOf(value), 1027778);
      expect((value as EstimatedValue).basis, ValueBasis.interest);
      expect(value.date, LocalDate(2026, 10, 13));
    });

    test('the maturity value is 10,312 and does not grow after it', () {
      ProjectedValue at(LocalDate date) => projectInterest(
            principal: usd(1000000),
            annualRate: Decimal.parse('0.041'),
            compounding: Compounding.monthly,
            start: LocalDate(2026, 2, 12),
            asOf: date,
            maturity: LocalDate(2026, 11, 12),
          );
      expect(amountOf(at(LocalDate(2026, 11, 12))), 1031174);
      expect(amountOf(at(LocalDate(2027, 6, 1))), 1031174);
      expect(
        (at(LocalDate(2027, 6, 1)) as EstimatedValue).date,
        LocalDate(2026, 11, 12),
      );
    });

    test('a simple deposit is 10,273 on 13 October', () {
      final value = projectInterest(
        principal: usd(1000000),
        annualRate: Decimal.parse('0.041'),
        compounding: Compounding.simple,
        start: LocalDate(2026, 2, 12),
        asOf: LocalDate(2026, 10, 13),
      );
      expect(amountOf(value), 1027296);
    });

    test('quarterly and yearly compounding add whole periods only', () {
      Decimal rate(String value) => Decimal.parse(value);
      final quarterly = projectInterest(
        principal: usd(100000),
        annualRate: rate('0.04'),
        compounding: Compounding.quarterly,
        start: LocalDate(2026, 1, 15),
        asOf: LocalDate(2026, 7, 15),
        maturity: LocalDate(2027, 1, 15),
      );
      // Two complete quarters, no remaining days.
      expect(amountOf(quarterly), 102010);
      final yearly = projectInterest(
        principal: usd(100000),
        annualRate: rate('0.04'),
        compounding: Compounding.yearly,
        start: LocalDate(2026, 1, 15),
        asOf: LocalDate(2027, 1, 15),
        maturity: LocalDate(2028, 1, 15),
      );
      expect(amountOf(yearly), 104000);
    });

    test('a leap day counts as one day', () {
      final value = projectInterest(
        principal: usd(100000),
        annualRate: Decimal.parse('0.05'),
        compounding: Compounding.simple,
        start: LocalDate(2024, 2, 28),
        asOf: LocalDate(2024, 3, 1),
      );
      // Two days, not three and not a 366-day year.
      expect(amountOf(value), 100027);
    });

    test('a date before the start is unavailable, never zero', () {
      final value = projectInterest(
        principal: usd(100000),
        annualRate: Decimal.parse('0.04'),
        compounding: Compounding.simple,
        start: LocalDate(2026, 2, 12),
        asOf: LocalDate(2026, 2, 11),
      );
      expect(value, isA<UnavailableValue>());
      expect((value as UnavailableValue).reason, ValueUnavailable.beforeStart);
    });

    test('a zero rate returns the principal', () {
      expect(
        amountOf(
          projectInterest(
            principal: usd(50000),
            annualRate: Decimal.zero,
            compounding: Compounding.monthly,
            start: LocalDate(2026, 1, 1),
            asOf: LocalDate(2026, 9, 1),
          ),
        ),
        50000,
      );
    });

    test('a maturity before the start is a programmer error', () {
      expect(
        () => projectInterest(
          principal: usd(100),
          annualRate: Decimal.zero,
          compounding: Compounding.simple,
          start: LocalDate(2026, 2, 12),
          asOf: LocalDate(2026, 3, 1),
          maturity: LocalDate(2026, 2, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('contribution', () {
    test('a pension is 23,934 on 13 October', () {
      final value = projectContribution(
        lastValue: usd(2270000),
        lastValueDate: LocalDate(2026, 7, 31),
        monthlyContribution: usd(50000),
        annualRate: Decimal.parse('0.05'),
        contributionDay: 31,
        asOf: LocalDate(2026, 10, 13),
      );
      expect(amountOf(value), 2393395);
      expect((value as EstimatedValue).basis, ValueBasis.contribution);
    });

    test('the contribution day clamps to the month end', () {
      // 31 August and 30 September count; 31 October is after the read date.
      final toOctober = projectContribution(
        lastValue: usd(100000),
        lastValueDate: LocalDate(2026, 7, 31),
        monthlyContribution: usd(10000),
        annualRate: Decimal.zero,
        contributionDay: 31,
        asOf: LocalDate(2026, 10, 13),
      );
      expect(amountOf(toOctober), 120000);
    });

    test('employer contributions add to the personal part', () {
      final value = projectContribution(
        lastValue: usd(100000),
        lastValueDate: LocalDate(2026, 1, 1),
        monthlyContribution: usd(10000),
        employerContribution: usd(5000),
        annualRate: Decimal.zero,
        contributionDay: 1,
        asOf: LocalDate(2026, 3, 1),
      );
      expect(amountOf(value), 130000);
    });

    test('a date before the last value is unavailable', () {
      final value = projectContribution(
        lastValue: usd(100000),
        lastValueDate: LocalDate(2026, 7, 31),
        monthlyContribution: usd(10000),
        annualRate: Decimal.parse('0.05'),
        contributionDay: 31,
        asOf: LocalDate(2026, 7, 30),
      );
      expect(value, isA<UnavailableValue>());
    });

    test('a zero rate and no contribution return the last value', () {
      expect(
        amountOf(
          projectContribution(
            lastValue: usd(100000),
            lastValueDate: LocalDate(2026, 7, 31),
            monthlyContribution: Money.zero(Currency.usd),
            annualRate: Decimal.zero,
            contributionDay: 31,
            asOf: LocalDate(2026, 10, 13),
          ),
        ),
        100000,
      );
    });

    test('an invalid contribution day is a programmer error', () {
      expect(
        () => projectContribution(
          lastValue: usd(100),
          lastValueDate: LocalDate(2026, 1, 1),
          monthlyContribution: usd(100),
          annualRate: Decimal.zero,
          contributionDay: 32,
          asOf: LocalDate(2026, 2, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('depreciation', () {
    test('a car loses 10% in one year', () {
      final value = projectDepreciation(
        purchaseValue: usd(1200000),
        purchaseDate: LocalDate(2025, 10, 13),
        yearlyRate: Decimal.parse('0.10'),
        asOf: LocalDate(2026, 10, 13),
      );
      expect(amountOf(value), 1080000);
      expect((value as EstimatedValue).basis, ValueBasis.depreciation);
    });

    test('a value stops at zero', () {
      expect(
        amountOf(
          projectDepreciation(
            purchaseValue: usd(1200000),
            purchaseDate: LocalDate(2000, 1, 1),
            yearlyRate: Decimal.parse('0.10'),
            asOf: LocalDate(2026, 1, 1),
          ),
        ),
        0,
      );
    });

    test('a negative rate is a programmer error', () {
      expect(
        () => projectDepreciation(
          purchaseValue: usd(100),
          purchaseDate: LocalDate(2026, 1, 1),
          yearlyRate: Decimal.parse('-0.1'),
          asOf: LocalDate(2026, 2, 1),
        ),
        throwsArgumentError,
      );
    });

    test('a date before the purchase is unavailable', () {
      expect(
        projectDepreciation(
          purchaseValue: usd(100),
          purchaseDate: LocalDate(2026, 1, 1),
          yearlyRate: Decimal.zero,
          asOf: LocalDate(2025, 12, 31),
        ),
        isA<UnavailableValue>(),
      );
    });
  });

  group('market price and weight', () {
    test(r'158 shares at $197.47 are $31,200.26', () {
      expect(
        amountOf(
          projectMarketPrice(
            quantity: Decimal.fromInt(158),
            pricePerUnit: usd(19747),
            asOf: LocalDate(2026, 10, 13),
          ),
        ),
        3120026,
      );
    });

    test('a missing price is unavailable, never zero', () {
      final value = projectMarketPrice(
        quantity: Decimal.fromInt(10),
        pricePerUnit: null,
        asOf: LocalDate(2026, 10, 13),
      );
      expect((value as UnavailableValue).reason, ValueUnavailable.noPrice);
    });

    test('the exchange rate multiplies the value', () {
      expect(
        amountOf(
          projectMarketPrice(
            quantity: Decimal.fromInt(10),
            pricePerUnit: usd(1000),
            fxRate: Decimal.parse('1.25'),
            asOf: LocalDate(2026, 10, 13),
          ),
        ),
        12500,
      );
    });

    test(r'10 g of 99.9% gold at $60 a gram is $599.40', () {
      expect(
        amountOf(
          projectWeightAndPrice(
            weight: Decimal.fromInt(10),
            purity: Decimal.parse('0.999'),
            pricePerUnit: usd(6000),
            asOf: LocalDate(2026, 10, 13),
          ),
        ),
        59940,
      );
    });

    test('missing gold price is unavailable', () {
      expect(
        projectWeightAndPrice(
          weight: Decimal.fromInt(10),
          purity: Decimal.one,
          pricePerUnit: null,
          asOf: LocalDate(2026, 10, 13),
        ),
        isA<UnavailableValue>(),
      );
    });

    test('rounding is half to even', () {
      Money priceOne = usd(1);
      expect(
        amountOf(
          projectMarketPrice(
            quantity: Decimal.parse('0.5'),
            pricePerUnit: priceOne,
            asOf: LocalDate(2026, 10, 13),
          ),
        ),
        0,
      );
      expect(
        amountOf(
          projectMarketPrice(
            quantity: Decimal.parse('1.5'),
            pricePerUnit: priceOne,
            asOf: LocalDate(2026, 10, 13),
          ),
        ),
        2,
      );
    });
  });

  group('manual and capital account', () {
    test('a manual value is real and keeps its date', () {
      final value = projectManual(
        value: usd(123456),
        date: LocalDate(2026, 9, 30),
      );
      expect(value, isA<KnownValue>());
      expect((value as KnownValue).amount.minor, 123456);
      expect(value.date, LocalDate(2026, 9, 30));
    });

    test('a capital account with no report is unavailable', () {
      expect(
        projectCapitalAccount(reportedValue: null, reportedDate: null),
        isA<UnavailableValue>(),
      );
      expect(
        projectCapitalAccount(
          reportedValue: usd(500000),
          reportedDate: LocalDate(2026, 6, 30),
        ),
        isA<KnownValue>(),
      );
    });
  });
}
