import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/tokens.g.dart';

/// DESIGN 7.2: where a chart sits. It changes the neutral chrome only; a data
/// mark keeps its own colour.
enum ChartTone {
  /// Inside a GlassCard.
  onCard,

  /// Inside a GlassCard stage.
  onStage,

  /// Behind the `0bHero.period` number (DESIGN 6.7). The chart is a shape, not
  /// the screen's focus.
  heroBackground,
}

/// DESIGN 2.4: the data role of a chart mark. A chart takes a role, never a
/// colour, so the Light mark map stays in one place.
enum ChartMark {
  neutral,
  spending,
  investing,
  moneyIn,
  gain,
  loss,
  rent,
  groceries,
  dining,
  shopping,
  transport,
  utilities,
  subscriptions,
  fun,
  other,
  needs,
  wants,
  invested,
  inCash,
}

/// DESIGN 7.1: the neutral chart chrome for one [ChartTone].
///
/// `grid` and `base` are the axis grammar values (white 7% and 16% in dark,
/// ink 8% and 20% in Light). `pastBar` is the neutral past bar (white 24% in
/// dark, ink equivalent in Light). They are chart geometry values, so they
/// live in `lib/design/charts/` and never in feature code.
final class ChartChrome {
  const ChartChrome({
    required this.axis,
    required this.grid,
    required this.base,
    required this.pastBar,
    required this.reference,
    required this.track,
    required this.hatch,
  });

  /// Axis and direct-label text (`text.secondary`).
  final Color axis;

  /// A grid line.
  final Color grid;

  /// The baseline under the marks.
  final Color base;

  /// A period bar that is not the current period.
  final Color pastBar;

  /// An average, limit or cost-basis reference line.
  final Color reference;

  /// The track behind a coloured mark.
  final Color track;

  /// The incomplete-period hatch.
  final Color hatch;
}

/// DESIGN 7.1, 2.4: resolves the chart chrome and the data marks for the
/// current theme. A chart never reads the section colour.
final class ChartColours {
  const ChartColours._(this.chrome, this._isDark);

  factory ChartColours.of(BuildContext context, ChartTone tone) {
    final isDark = context.tokens.isDark;
    return ChartColours._(_chrome(isDark, tone), isDark);
  }

  final ChartChrome chrome;
  final bool _isDark;

  static ChartChrome _chrome(bool isDark, ChartTone tone) {
    if (isDark) {
      return const ChartChrome(
        axis: ColorTokensDark.roleTextSecondary,
        grid: Color(0x12FFFFFF),
        base: Color(0x29FFFFFF),
        pastBar: Color(0x3DFFFFFF),
        reference: ColorTokensDark.roleTextControl,
        track: ColorTokensDark.roleSurfaceTrack,
        hatch: Color(0x59A3A6AF),
      );
    }
    return const ChartChrome(
      axis: ColorTokensLight.roleTextSecondary,
      grid: Color(0x1416171B),
      base: Color(0x3316171B),
      pastBar: Color(0x3D16171B),
      reference: ColorTokensLight.roleTextControl,
      track: ColorTokensLight.roleSurfaceTrack,
      hatch: Color(0x8C5A5D67),
    );
  }

  /// The mark colour for [mark] in this theme. Light uses the mark value from
  /// the DATA-LIGHT map (3:1 or more), not the text tint.
  Color mark(ChartMark mark) {
    if (_isDark) {
      return switch (mark) {
        ChartMark.neutral => ColorTokensDark.roleDataNeutralFill,
        ChartMark.spending => ColorTokensDark.dataFlowSpending,
        ChartMark.investing => ColorTokensDark.dataFlowInvesting,
        ChartMark.moneyIn => ColorTokensDark.dataFlowMoneyIn,
        ChartMark.gain => ColorTokensDark.dataSignedGain,
        ChartMark.loss => ColorTokensDark.dataSignedLoss,
        ChartMark.rent => ColorTokensDark.dataCategoryRent,
        ChartMark.groceries => ColorTokensDark.dataCategoryGroceries,
        ChartMark.dining => ColorTokensDark.dataCategoryDining,
        ChartMark.shopping => ColorTokensDark.dataCategoryShopping,
        ChartMark.transport => ColorTokensDark.dataCategoryTransport,
        ChartMark.utilities => ColorTokensDark.dataCategoryUtilities,
        ChartMark.subscriptions => ColorTokensDark.dataCategorySubscriptions,
        ChartMark.fun => ColorTokensDark.dataCategoryFun,
        ChartMark.other => ColorTokensDark.dataCategoryOther,
        ChartMark.needs => ColorTokensDark.dataCategoryNeeds,
        ChartMark.wants => ColorTokensDark.dataCategoryWants,
        ChartMark.invested => ColorTokensDark.dataCategoryInvested,
        ChartMark.inCash => ColorTokensDark.dataCategoryInCash,
      };
    }
    return switch (mark) {
      ChartMark.neutral => ColorTokensLight.roleDataNeutralFill,
      ChartMark.spending => ColorTokensLight.dataFlowSpending,
      ChartMark.investing => ColorTokensLight.dataFlowInvesting,
      ChartMark.moneyIn => ColorTokensLight.dataFlowMoneyIn,
      ChartMark.gain => ColorTokensLight.dataSignedGain,
      ChartMark.loss => ColorTokensLight.dataSignedLoss,
      ChartMark.rent => ColorTokensLight.dataCategoryRentMark,
      ChartMark.groceries => ColorTokensLight.dataCategoryGroceriesMark,
      ChartMark.dining => ColorTokensLight.dataCategoryDiningMark,
      ChartMark.shopping => ColorTokensLight.dataCategoryShoppingMark,
      ChartMark.transport => ColorTokensLight.dataCategoryTransportMark,
      ChartMark.utilities => ColorTokensLight.dataCategoryUtilitiesMark,
      ChartMark.subscriptions => ColorTokensLight.dataCategorySubscriptionsMark,
      ChartMark.fun => ColorTokensLight.dataCategoryFunMark,
      ChartMark.other => ColorTokensLight.dataCategoryOtherMark,
      ChartMark.needs => ColorTokensLight.dataCategoryNeedsMark,
      ChartMark.wants => ColorTokensLight.dataCategoryWantsMark,
      ChartMark.invested => ColorTokensLight.dataCategoryInvestedMark,
      ChartMark.inCash => ColorTokensLight.dataCategoryInCashMark,
    };
  }
}
