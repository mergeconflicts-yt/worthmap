import 'package:contour/core/money.dart';
import 'package:flutter/widgets.dart';

import '../components/feedback/confirm_bar.dart';
import '../components/forms/amount_input.dart';
import '../components/forms/split_editor.dart';
import '../components/hero/ob_hero.dart';
import '../format/hidden_amounts.dart';
import '../format/money_format.dart';
import '../format/money_text.dart';
import '../format/value_presentation.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../typography/app_text.dart';

/// P20 (DESIGN 0.7, 6.6): every Phase 2 money component in the hidden state.
///
/// The state is the app scope, not a per-component flag, so this gallery shows
/// what a screen shows when the person hides amounts. Percentages, dates and
/// counts stay; amounts are the mask in text and in the spoken name.
class Phase2HiddenGallery extends StatelessWidget {
  const Phase2HiddenGallery({super.key});

  static Money _usd(int major) => Money.fromMinor(major * 100, Currency.usd);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return HiddenAmountsScope(
      hidden: true,
      child: ColoredBox(
        color: tokens.surfacePage,
        child: Padding(
          padding: const EdgeInsets.all(Space.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'AmountInput',
                style: AppText.titleSection.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const VSpace(Space.m),
              AmountInput(
                value: ValueSpec.real(_usd(24)),
                semanticLabel: 'Amount \$24.00',
                emptyText: '\$0.00',
                emptySemanticLabel: 'Amount, not filled yet',
              ),
              const VSpace(Space.xxl),
              Text(
                'MoneyText · hero and row',
                style: AppText.titleSection.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const VSpace(Space.m),
              ObHero(
                kicker: 'SPENT',
                value: ValueSpec.real(_usd(3940)),
                contextLine: '1–13 Oct 2026 · October: \$1,260 left of \$5,200',
                hiddenContextLine:
                    '1–13 Oct 2026 · October: \$$hiddenMask left of \$$hiddenMask',
              ),
              const VSpace(Space.m),
              MoneyText(
                ValueSpec.real(_usd(3940)),
                style: AppText.numberM.copyWith(color: tokens.textPrimary),
              ),
              const VSpace(Space.xxl),
              Text(
                'SplitEditor · ConfirmBar',
                style: AppText.titleSection.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const VSpace(Space.m),
              SplitEditor(
                parts: <SplitPart>[
                  SplitPart(
                    name: 'Groceries',
                    amountText: '\$$hiddenMask',
                    dotColor: tokens.dataNeutralFill,
                    removeLabel: 'Remove Groceries',
                    onAmountTap: () {},
                    onRemove: () {},
                  ),
                  SplitPart(
                    name: 'Household',
                    amountText: '\$$hiddenMask',
                    dotColor: tokens.dataNeutralFill,
                    removeLabel: 'Remove Household',
                    onAmountTap: () {},
                    onRemove: () {},
                  ),
                ],
                leftLabel: 'Left to split',
                leftValue: Text(
                  '\$$hiddenMask',
                  style: AppText.numberXS.copyWith(color: tokens.textPrimary),
                ),
                addLabel: 'Add a part',
                onAdd: () {},
              ),
              const VSpace(Space.l),
              ConfirmBar(
                label: 'Confirm 2 ticked, \$$hiddenMask',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
