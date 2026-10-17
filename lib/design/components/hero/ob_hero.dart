import 'package:contour/core/money.dart';
import 'package:flutter/widgets.dart';

import '../../format/money_text.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../typography/app_text.dart';
import '../buttons/info_button.dart';

/// DESIGN 6.7, 14.2: `0bHero` variants.
enum ObHeroVariant {
  /// One number and its context line.
  number,

  /// A number with period chips and a background chart.
  period,

  /// A number with side figures (DESIGN 14.2, detail).
  detail,
}

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
    required this.amount,
    required this.state,
    this.variant = ObHeroVariant.number,
    this.hidden = false,
    this.contextLine,
    this.onInfo,
    this.infoLabel,
    this.sideFigures = const <HeroSideFigure>[],
    this.noneRecordedLabel,
    super.key,
  });

  final String kicker;
  final Money? amount;
  final ValueState state;
  final ObHeroVariant variant;
  final bool hidden;
  final String? contextLine;
  final VoidCallback? onInfo;
  final String? infoLabel;
  final List<HeroSideFigure> sideFigures;

  /// The label for [ValueState.noneRecorded], from l10n.
  final String? noneRecordedLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final largeText = MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;

    final number = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) =>
          tokens.textHeroFill.toLinearGradient().createShader(bounds),
      child: Text(
        _numberText(),
        style: AppText.numberHeroLight,
        maxLines: 1,
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
        label: _numberSemantics(),
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
      children.add(largeText ? _sideColumn(tokens) : _sideRow(tokens));
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
            figure.period!.toUpperCase(),
            style: AppText.labelCaps.copyWith(color: tokens.textSecondary),
          ),
      ],
    );
  }

  String _numberText() {
    switch (state) {
      case ValueState.noneRecorded:
      case ValueState.missing:
        return noneRecordedLabel ?? '';
      case ValueState.real:
      case ValueState.estimated:
      case ValueState.expected:
        break;
    }
    final value = amount!;
    if (hidden) {
      return '${currencyMark(value.currency)}$hiddenMask';
    }
    return formatMoney(value);
  }

  String _numberSemantics() => _numberText();
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
