import 'package:flutter/widgets.dart';

/// DESIGN 4, 6.6; SPEC 4.9: the app-level hidden-amount state for the
/// presentation layer.
///
/// The state itself lives in `lib/app/` (the provider and its persistence).
/// Design components read this one scope, so a component never needs the app
/// layer and a feature never passes `hidden` through every widget.
///
/// A component may still pass `hidden:` for one local case (a screenshot, a
/// preview, a golden). The local value wins; null follows the scope.
class HiddenAmountsScope extends InheritedWidget {
  const HiddenAmountsScope({
    required this.hidden,
    required super.child,
    super.key,
  });

  /// Whether amounts show as the mask.
  final bool hidden;

  /// The nearest state, or false when no provider is mounted.
  static bool hiddenOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HiddenAmountsScope>()
          ?.hidden ??
      false;

  /// The nearest state, or null when no provider is mounted. A component can
  /// then keep its own default.
  static bool? maybeHiddenOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HiddenAmountsScope>()?.hidden;

  /// Resolves an optional component override against the app state.
  static bool resolve(BuildContext context, bool? override) =>
      override ?? hiddenOf(context);

  @override
  bool updateShouldNotify(HiddenAmountsScope oldWidget) =>
      oldWidget.hidden != hidden;
}
