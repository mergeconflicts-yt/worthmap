import 'package:flutter/widgets.dart';

import '../../format/fit_number.dart';
import '../../format/value_presentation.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../typography/app_text.dart';
import '../buttons/info_button.dart';

/// DESIGN 6.7, 14.2: `0bHero` variants.
enum ObHeroVariant {
  /// One number and its context line. Side figures sit in a row.
  number,

  /// A number with stacked side figures (DESIGN 14.2, detail).
  detail,
}

// HERO-PERIOD and HERO-SPLIT-NUMBER are pending: the period variant needs the
// T11 charts, and the split-number typography (currency mark 0.45 em weight
// 300, raised; cents 0.5 em in text.secondary; DESIGN 2.5) is not built yet.
// DECISION-PENDING: HERO-SPLIT-NUMBER.

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
    this.hidden = false,
    this.contextLine,
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
  final bool hidden;
  final String? contextLine;
  final VoidCallback? onInfo;
  final String? infoLabel;
  final List<HeroSideFigure> sideFigures;

  /// The accessible word in hidden mode, from l10n.
  final String? hiddenLabel;

  ValuePresentation get _presentation => formatValueState(
        value,
        hidden: hidden,
        hiddenLabel: hiddenLabel,
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final largeText = MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;

    final presentation = _presentation;

    final number = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) =>
          tokens.textHeroFill.toLinearGradient().createShader(bounds),
      child: FitNumber(
        text: presentation.text,
        style: AppText.numberHeroLight,
        minFontSize: 40,
        semanticsLabel: presentation.semanticsLabel,
      ),
    );

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
        label: presentation.semanticsLabel,
        child: number,
      ),
    ];

    if (contextLine != null) {
      children.addAll(<Widget>[
        const VSpace(Space.xs),
        Text(
          contextLine!,
          style: AppText.line.copyWith(color: tokens.textSecondary),
        ),
      ]);
    }

    if (sideFigures.isNotEmpty) {
      children.add(const VSpace(Space.m));
      final stack = variant == ObHeroVariant.detail || largeText;
      children.add(stack ? _sideColumn(tokens) : _sideRow(tokens));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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
