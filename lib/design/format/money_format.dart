import '../../core/money.dart';

/// DESIGN 2.6, 8: currency marks. The mark is not the code; the code is the
/// fallback when no mark is known (DATABASE_DESIGN 3).
const Map<String, String> currencyMarks = <String, String>{
  'USD': r'$',
  'EUR': '\u20AC',
  'GBP': '\u00A3',
  'JPY': '\u00A5',
  'INR': '\u20B9',
  'TWD': r'NT$',
};

/// DESIGN 6.6, 9: the hidden-amount mask. The currency mark stays; the digits
/// become six middle dots (U+00B7).
const String hiddenMask = '\u00B7\u00B7\u00B7\u00B7\u00B7\u00B7';

/// The currency mark for [currency], or its code when no mark is known.
String currencyMark(Currency currency) =>
    currencyMarks[currency.code] ?? currency.code;

/// The true minus sign (U+2212). Not the ASCII hyphen (DESIGN 4; CR-06).
const String minusSign = '\u2212';

/// The gain sign (DESIGN 4: a change always has a sign; gains carry +).
const String plusSign = '+';

/// DESIGN 4: which sign a formatted amount shows.
enum SignStyle {
  /// Never a sign; the magnitude only.
  none,

  /// A sign only when the amount is negative (the default).
  negativeOnly,

  /// A sign always: "+" or the true minus sign.
  always,
}

/// DESIGN 8: formats [money] with a thousands separator and its exact minor
/// units. Never used for financial maths (SPEC 4.1); display only.
///
/// [sign] follows DESIGN 4: a change always has a sign, and the minus is the
/// true sign U+2212.
String formatMoney(
  Money money, {
  bool showSymbol = true,
  String? mark,
  SignStyle sign = SignStyle.negativeOnly,
}) {
  // The magnitude comes from BigInt, never `minor.abs()`: native abs() at the
  // minimum 64-bit value overflows and would leave the sign in place (R03).
  final digits = BigInt.from(money.minor).abs().toString().padLeft(
        money.currency.minorUnits + 1,
        '0',
      );
  final units = money.currency.minorUnits == 0
      ? digits
      : digits.substring(0, digits.length - money.currency.minorUnits);
  final fraction = money.currency.minorUnits == 0
      ? ''
      : '.${digits.substring(digits.length - money.currency.minorUnits)}';
  final grouped = _group(units);
  final signText = switch (sign) {
    SignStyle.none => '',
    SignStyle.negativeOnly => money.isNegative ? minusSign : '',
    SignStyle.always => money.isNegative ? minusSign : plusSign,
  };
  final symbol = showSymbol ? (mark ?? currencyMark(money.currency)) : '';
  return '$signText$symbol$grouped$fraction';
}

String _group(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
