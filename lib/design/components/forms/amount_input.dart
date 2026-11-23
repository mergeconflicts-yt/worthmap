import 'package:flutter/widgets.dart';

import '../../format/fit_number.dart';
import '../../format/hero_value.dart';
import '../../format/hidden_amounts.dart';
import '../../format/value_presentation.dart';
import '../../theme/app_theme.dart';
import '../../typography/app_text.dart';
import '../hero/hero_amount.dart';

/// DESIGN 6.4: `AmountInput`. A large `numberHero` amount with grey cents,
/// used with [Keypad]. A null [value] is the empty field: [emptyText] shows in
/// `text.secondary` and the spoken name is [emptySemanticLabel].
class AmountInput extends StatelessWidget {
  const AmountInput({
    required this.value,
    this.semanticLabel,
    required this.emptyText,
    required this.emptySemanticLabel,
    this.minFontSize = 40,
    this.hidden,
    super.key,
  });

  final ValueSpec? value;

  /// The spoken name. When null, the formatted amount is the name.
  final String? semanticLabel;
  final String emptyText;
  final String emptySemanticLabel;
  final double minFontSize;

  /// The component override; null follows [HiddenAmountsScope].
  final bool? hidden;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);
    final current = value;
    if (current == null) {
      return Semantics(
        label: emptySemanticLabel,
        excludeSemantics: true,
        child: FitNumber(
          text: emptyText,
          style: AppText.numberHeroLight.copyWith(
            color: tokens.textSecondary,
          ),
          minFontSize: minFontSize,
          semanticsLabel: emptySemanticLabel,
        ),
      );
    }
    final spoken = hiddenNow
        ? amountHiddenLabel
        : (semanticLabel ?? formatHeroValue(current).semanticsLabel);
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: HeroAmount(
        value: formatHeroValue(current, hidden: hiddenNow),
        minFontSize: minFontSize,
      ),
    );
  }
}
