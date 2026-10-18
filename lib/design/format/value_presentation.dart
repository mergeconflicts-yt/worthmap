import '../../core/money.dart';
import 'money_format.dart';

/// DESIGN 4, 8; SPEC 4.9: the states every value can have.
enum ValueState {
  real,
  estimated,
  expected,
  noneRecorded,
  missing,
  oldPrice,
}

/// DESIGN 4, 8; SPEC 4.9: one value and its state.
///
/// Build it only through the named constructors. Then an amount can never be
/// paired with [ValueState.noneRecorded] or [ValueState.missing], and those two
/// states always carry a label. An unknown value can therefore never render
/// blank or as a numeric zero (SPEC 4.3).
final class ValueSpec {
  const ValueSpec._(this.state, this.amount, this.label);

  /// A real amount, from a statement, import, capture or dated manual entry.
  const ValueSpec.real(Money amount) : this._(ValueState.real, amount, null);

  /// An amount calculated by a rule since the last real value. [label] is
  /// "Est." from l10n (SPEC 4.9).
  const ValueSpec.estimated(Money amount, String label)
      : this._(ValueState.estimated, amount, label);

  /// An amount not owned yet. [label] is "Expected" from l10n (SPEC 4.9).
  const ValueSpec.expected(Money amount, String label)
      : this._(ValueState.expected, amount, label);

  /// Nothing entered for this type. [label] is "None recorded" (SPEC 4.9).
  const ValueSpec.noneRecorded(String label)
      : this._(ValueState.noneRecorded, null, label);

  /// A value that is due but not entered. [label] is "Missing since [date]"
  /// with the date already formatted (SPEC 4.9).
  const ValueSpec.missing(String label)
      : this._(ValueState.missing, null, label);

  /// A price older than the last market close (offline). It shows "Est." on
  /// totals (SPEC 4.9); [label] is that "Est." word from l10n.
  const ValueSpec.oldPrice(Money amount, String label)
      : this._(ValueState.oldPrice, amount, label);

  final ValueState state;

  /// The amount, or null for [ValueState.noneRecorded] and
  /// [ValueState.missing].
  final Money? amount;

  /// The state label: "Est." / "Expected" after an amount, or the whole phrase
  /// for [ValueState.noneRecorded] and [ValueState.missing]. Null for
  /// [ValueState.real].
  final String? label;
}

/// DESIGN 4, 8; SPEC 4.9: the pixels and the spoken words for one value.
final class ValuePresentation {
  const ValuePresentation({required this.text, required this.semanticsLabel});

  /// The pixels: an amount, a masked amount, or a state phrase.
  final String text;

  /// What a screen reader says. It includes the state label, and never a hidden
  /// amount (hidden_mode_semantics).
  final String semanticsLabel;
}

/// The interim wording for a hidden amount. AGENTS 6.9 wants this from l10n;
/// T10 replaces it. DECISION-PENDING: T06-L10N-CONSTANTS.
const String amountHiddenLabel = 'Amount hidden';

/// DESIGN 4, 8; SPEC 4.9: the one place that turns a [ValueSpec] into text.
///
/// MoneyText, ObHero and every other money component call this, so the state
/// rules live in one place. A hidden amount never shows in [text] or
/// [ValuePresentation.semanticsLabel] (hidden_mode_semantics).
ValuePresentation formatValueState(
  ValueSpec spec, {
  bool hidden = false,
  bool showSymbol = true,
  String? mark,
  String? hiddenLabel,
  SignStyle sign = SignStyle.negativeOnly,
}) {
  final amount = spec.amount;
  switch (spec.state) {
    case ValueState.noneRecorded:
    case ValueState.missing:
      final label = spec.label;
      if (label == null || label.isEmpty) {
        throw ArgumentError(
          '${spec.state.name} needs a non-empty label',
        );
      }
      return ValuePresentation(text: label, semanticsLabel: label);
    case ValueState.real:
    case ValueState.estimated:
    case ValueState.expected:
    case ValueState.oldPrice:
      if (amount == null) {
        throw ArgumentError('${spec.state.name} needs an amount');
      }
      return _presentAmount(
        amount,
        spec.label,
        hidden: hidden,
        showSymbol: showSymbol,
        mark: mark,
        hiddenLabel: hiddenLabel,
        sign: sign,
      );
  }
}

ValuePresentation _presentAmount(
  Money amount,
  String? marker, {
  required bool hidden,
  required bool showSymbol,
  required SignStyle sign,
  String? mark,
  String? hiddenLabel,
}) {
  final String visible;
  if (hidden) {
    final symbol = showSymbol ? (mark ?? currencyMark(amount.currency)) : '';
    visible = '$symbol$hiddenMask';
  } else {
    visible =
        formatMoney(amount, showSymbol: showSymbol, mark: mark, sign: sign);
  }
  final text = marker == null ? visible : '$visible $marker';
  final String semanticsLabel;
  if (hidden) {
    final hiddenWord = (hiddenLabel ?? amountHiddenLabel);
    semanticsLabel = marker == null ? hiddenWord : '$hiddenWord $marker';
  } else {
    semanticsLabel = text;
  }
  return ValuePresentation(text: text, semanticsLabel: semanticsLabel);
}
