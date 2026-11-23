import '../../core/percent.dart';

/// DESIGN 4: one percentage in the visible text.
///
/// The value comes from `Percent` (exact decimal points); this is the only
/// place that turns it into a string. [decimals] defaults to one place.
String formatPercent(Percent percent, {int decimals = 1}) =>
    '${percent.value.toStringAsFixed(decimals)}%';
