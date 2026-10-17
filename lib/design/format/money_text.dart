import 'package:flutter/widgets.dart';

import '../../core/money.dart';

/// DESIGN 8: money components key on a [ValueState]. A bare zero for unknown
/// data is impossible (SPEC 4.3).
enum ValueState {
  real,
  estimated,
  expected,
  noneRecorded,
  missing,
}

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

/// DESIGN 8: formats [money] with a thousands separator and its exact minor
/// units. Never used for financial maths (SPEC 4.1); display only.
String formatMoney(Money money, {bool showSymbol = true, String? mark}) {
  final digits = money.minor.abs().toString().padLeft(
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
  final sign = money.isNegative ? '-' : '';
  final symbol = showSymbol ? (mark ?? currencyMark(money.currency)) : '';
  return '$sign$symbol$grouped$fraction';
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

/// DESIGN 6.6, 8, 9: shows one amount. It requires a [ValueState]. When
/// [hidden] is true it shows the currency mark and [hiddenMask] instead of the
/// digits, for both the pixels and the accessible name (hidden_mode_semantics).
class MoneyText extends StatelessWidget {
  const MoneyText({
    required this.amount,
    required this.state,
    this.hidden = false,
    this.style,
    this.mark,
    this.showSymbol = true,
    this.noneRecordedLabel,
    this.unavailableLabel,
    super.key,
  });

  /// The amount, or null for [ValueState.noneRecorded] and
  /// [ValueState.missing].
  final Money? amount;
  final ValueState state;
  final bool hidden;
  final TextStyle? style;
  final String? mark;
  final bool showSymbol;

  /// The word shown for [ValueState.noneRecorded] ("None recorded"). Comes from
  /// l10n (DESIGN 8); never hard-coded here.
  final String? noneRecordedLabel;

  /// The word shown for [ValueState.missing]. Comes from l10n.
  final String? unavailableLabel;

  @override
  Widget build(BuildContext context) {
    final text = _displayText();
    return Text(
      text,
      style: style,
      textAlign: TextAlign.right,
      semanticsLabel: text,
    );
  }

  String _displayText() {
    switch (state) {
      case ValueState.noneRecorded:
        return noneRecordedLabel ?? '';
      case ValueState.missing:
        return unavailableLabel ?? '';
      case ValueState.real:
      case ValueState.estimated:
      case ValueState.expected:
        break;
    }
    final value = amount!;
    if (hidden) {
      final symbol = showSymbol ? (mark ?? currencyMark(value.currency)) : '';
      return '$symbol$hiddenMask';
    }
    return formatMoney(value, showSymbol: showSymbol, mark: mark);
  }
}
