// DESIGN 6.3: `AmountTabs` — two totals side by side, one selected.
//
// Each tab carries a label and its value, with a 2 pt mark under the selected
// one (X40 You own / You owe). The caller formats the value.
library;

import 'package:flutter/widgets.dart';

import '../../charts/chart_tone.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// One tab: a label, its value and its underline mark.
class AmountTab {
  const AmountTab({
    required this.label,
    required this.value,
    required this.mark,
  });

  final String label;
  final String value;
  final ChartMark mark;
}

/// A row of amount tabs.
class AmountTabs extends StatelessWidget {
  const AmountTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final List<AmountTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colours = ChartColours.of(context, ChartTone.onCard);
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < tabs.length; i++) ...<Widget>[
            if (i > 0) const HSpace(Space.m),
            Expanded(
              child: AppInteraction(
                onActivated: () => onChanged(i),
                borderRadius: BorderRadius.circular(RadiusTokens.s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tabs[i].label.toUpperCase(),
                        style: AppText.labelCaps.copyWith(
                          color: i == selectedIndex
                              ? tokens.textPrimary
                              : tokens.textSecondary,
                        ),
                      ),
                      const VSpace(Space.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tabs[i].value,
                          style: AppText.numberS.copyWith(
                            color: tokens.textPrimary,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: i == selectedIndex
                              ? colours.mark(tabs[i].mark)
                              : tokens.surfaceTrack,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
