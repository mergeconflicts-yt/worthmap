import 'package:decimal/decimal.dart';

import 'decimal.dart';

/// SPEC 4.1: an ISO 4217 currency code with its minor unit count.
///
/// DATABASE_DESIGN 3: the code is validated and metadata is pinned; the minor
/// unit count is never inferred from a locale or a symbol.
final class Currency {
  const Currency._(this.code, this.minorUnits);

  /// Validates [code] (three uppercase letters) and [minorUnits] (0 to 4).
  factory Currency(String code, {required int minorUnits}) {
    if (!_codePattern.hasMatch(code)) {
      throw ArgumentError.value(
        code,
        'code',
        'Must be three uppercase letters',
      );
    }
    if (minorUnits < 0 || minorUnits > 4) {
      throw ArgumentError.value(
        minorUnits,
        'minorUnits',
        'Must be between 0 and 4',
      );
    }
    return Currency._(code, minorUnits);
  }

  static final RegExp _codePattern = RegExp(r'^[A-Z]{3}$');

  /// The ISO 4217 alphabetic code.
  final String code;

  /// The number of decimal digits in one major unit (JPY 0, USD 2, KWD 3).
  final int minorUnits;

  static const Currency usd = Currency._('USD', 2);
  static const Currency eur = Currency._('EUR', 2);
  static const Currency gbp = Currency._('GBP', 2);
  static const Currency jpy = Currency._('JPY', 0);
  static const Currency kwd = Currency._('KWD', 3);
  static const Currency inr = Currency._('INR', 2);
  static const Currency twd = Currency._('TWD', 2);

  @override
  bool operator ==(Object other) =>
      other is Currency && other.code == code && other.minorUnits == minorUnits;

  @override
  int get hashCode => Object.hash(code, minorUnits);

  @override
  String toString() => code;
}

/// Raised when two amounts of different currencies are combined.
///
/// It holds only the two currency codes; never an amount (AGENTS 2.6).
final class MoneyCurrencyMismatch implements Exception {
  const MoneyCurrencyMismatch(this.left, this.right);

  final String left;
  final String right;

  @override
  String toString() => 'MoneyCurrencyMismatch($left, $right)';
}

/// Raised when an amount does not fit the signed 64-bit minor-unit range.
final class MoneyOutOfRange implements Exception {
  const MoneyOutOfRange();

  @override
  String toString() => 'MoneyOutOfRange';
}

/// SPEC 4.1: money is an integer of minor units plus an ISO 4217 currency.
///
/// Never use `double`. Convert and round only through this type and
/// `core/decimal.dart` (AGENTS 6.4).
final class Money implements Comparable<Money> {
  const Money._(this.minor, this.currency);

  /// Creates an amount from an integer number of minor units.
  factory Money.fromMinor(int minor, Currency currency) {
    _checkRange(BigInt.from(minor));
    return Money._(minor, currency);
  }

  /// The signed 64-bit minor-unit range (SYSTEM_DESIGN 7).
  static final BigInt maxMinor = BigInt.parse('9223372036854775807');
  static final BigInt minMinor = BigInt.parse('-9223372036854775808');

  /// Signed integer minor units (for example USD cents).
  final int minor;

  /// The currency of [minor].
  final Currency currency;

  /// The zero amount in [currency].
  static Money zero(Currency currency) => Money._(0, currency);

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return _of(BigInt.from(minor) + BigInt.from(other.minor), currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return _of(BigInt.from(minor) - BigInt.from(other.minor), currency);
  }

  Money operator -() => Money._(-minor, currency);

  /// SPEC 4.1: multiplies by an exact factor and rounds to minor units.
  ///
  /// Conversions use half to even by default. Pass [RoundingMode.halfUp] for
  /// display rounding.
  Money times(Decimal factor, {RoundingMode mode = RoundingMode.halfEven}) {
    final product = Decimal.fromInt(minor) * factor;
    return _of(roundToBigInt(product, mode), currency);
  }

  /// The exact value as a [Decimal] of major units.
  Decimal toDecimal() {
    final value = Decimal.fromInt(minor).shift(-currency.minorUnits);
    return value;
  }

  /// SPEC 4.1: builds an amount from a [value] in major units.
  ///
  /// Conversions use half to even by default. Display uses half up.
  static Money fromDecimal(
    Decimal value,
    Currency currency, {
    RoundingMode mode = RoundingMode.halfEven,
  }) {
    final scaled = value * BigInt.from(10).pow(currency.minorUnits).toDecimal();
    return _of(roundToBigInt(scaled, mode), currency);
  }

  static Money _of(BigInt minor, Currency currency) {
    _checkRange(minor);
    return Money._(minor.toInt(), currency);
  }

  static void _checkRange(BigInt minor) {
    if (minor < minMinor || minor > maxMinor) {
      throw const MoneyOutOfRange();
    }
  }

  void _requireSameCurrency(Money other) {
    if (other.currency != currency) {
      throw MoneyCurrencyMismatch(currency.code, other.currency.code);
    }
  }

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor ${currency.code})';
}
