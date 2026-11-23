import 'package:flutter/widgets.dart';

import 'hidden_amounts.dart';
import 'money_format.dart';
import 'value_presentation.dart';

/// DESIGN 6.6, 8, 9: shows one amount with its [ValueState] (a [ValueSpec]).
///
/// It never shows a bare zero for unknown data: [ValueSpec.noneRecorded] and
/// [ValueSpec.missing] carry their own phrase. When [hidden] is true the digits
/// are replaced by [hiddenMask] in the pixels, and the accessible name uses
/// [amountHiddenLabel] instead of the amount (hidden_mode_semantics).
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    this.hidden,
    this.showSymbol = true,
    this.mark,
    this.hiddenLabel,
    this.prefix,
    this.sign = SignStyle.negativeOnly,
    this.style,
    super.key,
  });

  /// The value and its state.
  final ValueSpec value;

  /// The component override; null follows [HiddenAmountsScope].
  final bool? hidden;
  final TextStyle? style;
  final String? mark;
  final bool showSymbol;

  /// How the amount shows its sign (DESIGN 4). Gains use [SignStyle.always].
  final SignStyle sign;

  /// The word for the accessible name in hidden mode, from l10n. Defaults to
  /// [amountHiddenLabel].
  final String? hiddenLabel;

  /// A word before the amount, for example "Owes " on a card balance. It is
  /// part of the pixels and of the spoken name, and it masks with the amount.
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);
    final presentation = formatValueState(
      value,
      hidden: hiddenNow,
      showSymbol: showSymbol,
      mark: mark,
      hiddenLabel: hiddenLabel,
      sign: sign,
    );
    final prefixText = prefix ?? '';
    return Text(
      '$prefixText${presentation.text}',
      style: style,
      textAlign: TextAlign.end,
      semanticsLabel: '$prefixText${presentation.semanticsLabel}',
    );
  }
}
