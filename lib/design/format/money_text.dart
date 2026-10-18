import 'package:flutter/widgets.dart';

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
    this.hidden = false,
    this.showSymbol = true,
    this.mark,
    this.hiddenLabel,
    this.sign = SignStyle.negativeOnly,
    this.style,
    super.key,
  });

  /// The value and its state.
  final ValueSpec value;
  final bool hidden;
  final TextStyle? style;
  final String? mark;
  final bool showSymbol;

  /// How the amount shows its sign (DESIGN 4). Gains use [SignStyle.always].
  final SignStyle sign;

  /// The word for the accessible name in hidden mode, from l10n. Defaults to
  /// [amountHiddenLabel].
  final String? hiddenLabel;

  @override
  Widget build(BuildContext context) {
    final presentation = formatValueState(
      value,
      hidden: hidden,
      showSymbol: showSymbol,
      mark: mark,
      hiddenLabel: hiddenLabel,
      sign: sign,
    );
    return Text(
      presentation.text,
      style: style,
      textAlign: TextAlign.end,
      semanticsLabel: presentation.semanticsLabel,
    );
  }
}
