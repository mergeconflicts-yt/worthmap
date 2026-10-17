import 'package:flutter/painting.dart';

import '../tokens/token_types.dart';
import '../tokens/tokens.g.dart';

/// DESIGN 2.5: the only text styles. Colour is not part of a style; the
/// component applies the role colour. `copyWith(fontSize:)` is forbidden
/// outside `lib/design/`.
abstract final class AppText {
  const AppText._();

  static TextStyle _style(
    TypeStyle token, {
    required String family,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: token.size,
      fontWeight: FontWeight.values.firstWhere(
        (weight) => weight.value == token.weight,
      ),
      letterSpacing: token.letterSpacing * token.size,
      height: token.lineHeight,
      fontFeatures:
          tabular ? const <FontFeature>[FontFeature.tabularFigures()] : null,
    );
  }

  static const String _inter = 'Inter';
  static const String _display = 'Inter Display';

  static final TextStyle numberHeroLight = _style(
    TypeTokens.numberHeroLight,
    family: _display,
    tabular: true,
  );
  static final TextStyle numberXL = _style(
    TypeTokens.numberXL,
    family: _inter,
    tabular: true,
  );
  static final TextStyle numberL = _style(
    TypeTokens.numberL,
    family: _inter,
    tabular: true,
  );
  static final TextStyle numberM = _style(
    TypeTokens.numberM,
    family: _inter,
    tabular: true,
  );
  static final TextStyle numberS = _style(
    TypeTokens.numberS,
    family: _inter,
    tabular: true,
  );
  static final TextStyle numberXS = _style(
    TypeTokens.numberXS,
    family: _inter,
    tabular: true,
  );
  static final TextStyle dateDay = _style(
    TypeTokens.dateDay,
    family: _inter,
    tabular: true,
  );
  static final TextStyle titleScreen = _style(
    TypeTokens.titleScreen,
    family: _inter,
  );
  static final TextStyle titleBar = _style(TypeTokens.titleBar, family: _inter);
  static final TextStyle titleCompact = _style(
    TypeTokens.titleCompact,
    family: _inter,
  );
  static final TextStyle titleGroup = _style(
    TypeTokens.titleGroup,
    family: _inter,
  );
  static final TextStyle titleSection = _style(
    TypeTokens.titleSection,
    family: _inter,
  );
  static final TextStyle titleDialog = _style(
    TypeTokens.titleDialog,
    family: _inter,
  );
  static final TextStyle body = _style(TypeTokens.body, family: _inter);
  static final TextStyle bodyStrong = _style(
    TypeTokens.bodyStrong,
    family: _inter,
  );
  static final TextStyle line = _style(TypeTokens.line, family: _inter);
  static final TextStyle bodyS = _style(TypeTokens.bodyS, family: _inter);
  static final TextStyle caption = _style(TypeTokens.caption, family: _inter);
  static final TextStyle captionStrong = _style(
    TypeTokens.captionStrong,
    family: _inter,
  );

  /// `label.caps` is uppercase; components apply `toUpperCase` to the text.
  static final TextStyle labelCaps = _style(
    TypeTokens.labelCaps,
    family: _inter,
  );
  static final TextStyle button = _style(TypeTokens.button, family: _inter);
  static final TextStyle buttonS = _style(TypeTokens.buttonS, family: _inter);
  static final TextStyle tabLabel = _style(TypeTokens.tabLabel, family: _inter);
  static final TextStyle weekday = _style(TypeTokens.weekday, family: _inter);
  static final TextStyle chartLabel = _style(
    TypeTokens.chartLabel,
    family: _inter,
    tabular: true,
  );
  static final TextStyle chartAxis = _style(
    TypeTokens.chartAxis,
    family: _inter,
    tabular: true,
  );
  static final TextStyle key = _style(
    TypeTokens.key,
    family: _inter,
    tabular: true,
  );

  /// Every style, for the gallery. Keyed by the DESIGN style name.
  static final Map<String, TextStyle> all = <String, TextStyle>{
    'numberHero.light': numberHeroLight,
    'numberXL': numberXL,
    'numberL': numberL,
    'numberM': numberM,
    'numberS': numberS,
    'numberXS': numberXS,
    'dateDay': dateDay,
    'titleScreen': titleScreen,
    'titleBar': titleBar,
    'titleCompact': titleCompact,
    'titleGroup': titleGroup,
    'titleSection': titleSection,
    'titleDialog': titleDialog,
    'body': body,
    'bodyStrong': bodyStrong,
    'line': line,
    'bodyS': bodyS,
    'caption': caption,
    'captionStrong': captionStrong,
    'label.caps': labelCaps,
    'button': button,
    'buttonS': buttonS,
    'tabLabel': tabLabel,
    'weekday': weekday,
    'chartLabel': chartLabel,
    'chartAxis': chartAxis,
    'key': key,
  };
}
