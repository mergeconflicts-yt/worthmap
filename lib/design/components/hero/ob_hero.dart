import 'package:flutter/widgets.dart';

import '../../format/hero_value.dart';
import '../../format/hidden_amounts.dart';
import '../../format/value_presentation.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../typography/app_text.dart';
import '../buttons/info_button.dart';
import 'hero_amount.dart';

/// DESIGN 6.7, 14.2: `0bHero` variants.
enum ObHeroVariant {
  /// One number and its context line. Side figures sit in a row.
  number,

  /// A number with stacked side figures (DESIGN 14.2, detail).
  detail,

  /// A number with its period line and a background chart (DESIGN 6.7).
  period,
}

// HERO-PERIOD is built (P20): the period chart sits behind the number, masked
// from 45% at its left end, with no table and no reader stop of its own.
// HERO-SPLIT-NUMBER is built here: currency mark 0.45 em weight 300, raised;
// cents 0.5 em in text.secondary; the rest with the 14.1(c) fill (DESIGN 2.5).
// HERO-MARKER-STYLE closed 2026-11-22 (DECISIONS "Decided"): the state word
// is the caption style after the number (the review's preferred option).

/// DESIGN 6.7: one side figure beside a detail hero number: a signed value and
/// a small `label.caps` period under it.
class HeroSideFigure {
  const HeroSideFigure({required this.value, this.period});

  final Widget value;
  final String? period;
}

/// DESIGN 6.7, 14.2: the one luminous hero per screen. A kicker in
/// `section.text`, one `numberHero.light` number with the 14.1(c) fill, an
/// optional context line and up to two side figures.
class ObHero extends StatelessWidget {
  const ObHero({
    required this.kicker,
    required this.value,
    this.variant = ObHeroVariant.number,
    this.hidden,
    this.contextLine,
    this.hiddenContextLine,
    this.backgroundChart,
    this.onInfo,
    this.infoLabel,
    this.sideFigures = const <HeroSideFigure>[],
    this.hiddenLabel,
    super.key,
  });

  final String kicker;

  /// The hero number and its state.
  final ValueSpec value;
  final ObHeroVariant variant;

  /// The component override; null follows [HiddenAmountsScope].
  final bool? hidden;
  final String? contextLine;

  /// The context line with every amount masked, built by the screen. When the
  /// state is hidden and this is null, the context line is not shown: a word
  /// that may hold an amount never survives a switch to hidden.
  final String? hiddenContextLine;

  /// DESIGN 6.7: the period line that sits behind the number, masked to 45%.
  /// Pass a chart in [ChartTone.heroBackground]. The hero adds no table and
  /// excludes the chart from semantics; the hero number is the one value.
  final Widget? backgroundChart;
  final VoidCallback? onInfo;
  final String? infoLabel;
  final List<HeroSideFigure> sideFigures;

  /// The accessible word in hidden mode, from l10n.
  final String? hiddenLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final largeText = MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;
    final hiddenNow = HiddenAmountsScope.resolve(context, hidden);

    final heroValue = formatHeroValue(
      value,
      hidden: hiddenNow,
      hiddenLabel: hiddenLabel,
    );

    final number = HeroAmount(value: heroValue);

    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              kicker.toUpperCase(),
              style: AppText.labelCaps.copyWith(color: role.text),
              // CR-14: keep the spoken name in the original case; a screen
              // reader can spell out all-caps words letter by letter.
              semanticsLabel: kicker,
            ),
          ),
          if (onInfo != null)
            InfoButton(
              semanticLabel: infoLabel ?? kicker,
              onPressed: onInfo,
            ),
        ],
      ),
      const VSpace(Space.m),
      SemanticAmount(
        label: heroValue.semanticsLabel,
        child: number,
      ),
    ];

    final shownLine = hiddenNow ? hiddenContextLine : contextLine;
    if (shownLine != null) {
      children.addAll(<Widget>[
        const VSpace(Space.xs),
        Text(
          shownLine,
          style: AppText.line.copyWith(color: tokens.textSecondary),
        ),
      ]);
    }

    if (sideFigures.isNotEmpty) {
      children.add(const VSpace(Space.m));
      final stack = variant == ObHeroVariant.detail || largeText;
      children.add(stack ? _sideColumn(tokens) : _sideRow(tokens));
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );

    if (variant != ObHeroVariant.period || backgroundChart == null) {
      return column;
    }
    return _periodStack(column, hiddenNow);
  }

  /// DESIGN 6.7: the period line sits behind the number, masked to 45% at its
  /// left end. It is a shape, so it takes no taps and adds no reader stop.
  Widget _periodStack(Widget column, bool hiddenNow) {
    final chart = IgnorePointer(
      child: ExcludeSemantics(
        child: hidden == null
            ? backgroundChart!
            : HiddenAmountsScope(
                hidden: hiddenNow,
                child: backgroundChart!,
              ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: -Space.page,
          right: Space.xl,
          bottom: 0,
          height: 136,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[Color(0x73FFFFFF), Color(0x00FFFFFF)],
            ).createShader(bounds),
            child: chart,
          ),
        ),
        column,
      ],
    );
  }

  Widget _sideRow(ContourTokens tokens) {
    final widgets = <Widget>[];
    for (var i = 0; i < sideFigures.length; i++) {
      if (i > 0) {
        widgets.add(const HSpace(Space.xxl));
      }
      widgets.add(_figure(sideFigures[i], tokens));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  Widget _sideColumn(ContourTokens tokens) {
    final widgets = <Widget>[];
    for (var i = 0; i < sideFigures.length; i++) {
      if (i > 0) {
        widgets.add(const VSpace(Space.m));
      }
      widgets.add(_figure(sideFigures[i], tokens));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _figure(HeroSideFigure figure, ContourTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        figure.value,
        if (figure.period != null)
          Text(
            // N-16: one rule everywhere. Uppercase is visual in the component;
            // the semantics keep the original case (CR-14).
            figure.period!.toUpperCase(),
            style: AppText.labelCaps.copyWith(color: tokens.textSecondary),
            semanticsLabel: figure.period,
          ),
      ],
    );
  }
}

/// DESIGN 6.6: replaces the pixels' accessible name so the amount can be masked
/// while the digits stay on screen (hidden_mode_semantics).
class SemanticAmount extends StatelessWidget {
  const SemanticAmount({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        excludeSemantics: true,
        child: child,
      );
}
