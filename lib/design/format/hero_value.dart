import 'money_format.dart';
import 'value_presentation.dart';

/// DESIGN 2.5, 6.7: one hero value split into its typographic parts.
///
/// The hero is not one string. The currency mark is 0.45 em at weight 300 and
/// raised; the cents are 0.5 em in `text.secondary`; the rest uses the 14.1(c)
/// fill. A non-amount state (None recorded, Missing, Loading, Not available)
/// has no parts and keeps its phrase as one string.
final class HeroValueParts {
  const HeroValueParts.plain(this.plain)
      : isAmount = false,
        signMark = '',
        whole = '',
        fraction = '',
        marker = '';

  const HeroValueParts.amount({
    required this.signMark,
    required this.whole,
    required this.fraction,
    required this.marker,
  })  : isAmount = true,
        plain = '';

  /// True when the value has an amount and can use the split typography.
  final bool isAmount;

  /// The state phrase for [isAmount] false, for example "None recorded".
  final String plain;

  /// The sign (if any) and the currency mark, for example "−$" or "NT$".
  final String signMark;

  /// The grouped whole units, for example "4,123". For a hidden amount this is
  /// the six middle dots.
  final String whole;

  /// The decimal point and minor units, for example ".65". Empty when the
  /// currency has no minor units or the amount is hidden.
  final String fraction;

  /// The state word after the amount, for example "Est.". Empty for a real
  /// value. It is drawn in the caption style, not the hero style (N-15).
  final String marker;

  /// The one-line text, used when the split parts cannot fit even at the
  /// minimum size.
  String get text {
    if (!isAmount) {
      return plain;
    }
    final state = marker.isEmpty ? '' : ' $marker';
    return '$signMark$whole$fraction$state';
  }
}

/// DESIGN 2.5, 6.7; SPEC 4.9: the hero pixels and its one spoken label.
final class HeroValue {
  const HeroValue({required this.parts, required this.semanticsLabel});

  final HeroValueParts parts;

  /// The full amount and state word for the screen reader, or the masked
  /// wording. It never holds a hidden amount.
  final String semanticsLabel;
}

/// Splits [spec] for the hero typography. The split reads the one formatted
/// string, so every state rule stays in [formatValueState].
HeroValue formatHeroValue(
  ValueSpec spec, {
  bool hidden = false,
  String? hiddenLabel,
  String? mark,
}) {
  final presentation = formatValueState(
    spec,
    hidden: hidden,
    hiddenLabel: hiddenLabel,
    mark: mark,
  );
  final amount = spec.amount;
  final hasAmount = switch (spec.state) {
    ValueState.real ||
    ValueState.estimated ||
    ValueState.expected ||
    ValueState.oldPrice =>
      amount != null,
    ValueState.noneRecorded ||
    ValueState.missing ||
    ValueState.notAvailable ||
    ValueState.loading =>
      false,
  };
  if (!hasAmount) {
    return HeroValue(
      parts: HeroValueParts.plain(presentation.text),
      semanticsLabel: presentation.semanticsLabel,
    );
  }
  if (amount == null) {
    return _plain(presentation);
  }

  final markText = mark ?? currencyMark(amount.currency);
  final marker = spec.label ?? '';
  var body = presentation.text;

  // Remove the state word first: the split keeps it as its own part.
  if (marker.isNotEmpty) {
    final suffix = ' $marker';
    if (!body.endsWith(suffix)) {
      return _plain(presentation);
    }
    body = body.substring(0, body.length - suffix.length);
  }

  var sign = '';
  if (body.startsWith(minusSign)) {
    sign = minusSign;
    body = body.substring(minusSign.length);
  } else if (body.startsWith(plusSign)) {
    sign = plusSign;
    body = body.substring(plusSign.length);
  }

  if (!body.startsWith(markText)) {
    return _plain(presentation);
  }
  body = body.substring(markText.length);

  var whole = body;
  var fraction = '';
  if (!hidden && amount.currency.minorUnits > 0) {
    final dot = body.lastIndexOf('.');
    if (dot >= 0) {
      whole = body.substring(0, dot);
      fraction = body.substring(dot);
    }
  }

  return HeroValue(
    parts: HeroValueParts.amount(
      signMark: '$sign$markText',
      whole: whole,
      fraction: fraction,
      marker: marker,
    ),
    semanticsLabel: presentation.semanticsLabel,
  );
}

HeroValue _plain(ValuePresentation presentation) => HeroValue(
      parts: HeroValueParts.plain(presentation.text),
      semanticsLabel: presentation.semanticsLabel,
    );
