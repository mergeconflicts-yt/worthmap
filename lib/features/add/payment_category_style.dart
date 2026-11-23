// P22 (DESIGN 2.4; DECISIONS P22-CATEGORY-DOT): the category dot colour.
//
// DESIGN 2.4 defines the `data.category` hues and says "never invent a
// colour". A category whose name matches one of those roles shows its dot; a
// name with no role shows no dot. The role, not a colour value, is chosen
// here; the colour comes from `ChartColours` in lib/design.
library;

import 'package:flutter/widgets.dart';

import '../../design/design.dart';

/// The palette role for a category name, or null when the name has none.
ChartMark? categoryMarkFor(String name) => switch (name.trim().toLowerCase()) {
      'rent' => ChartMark.rent,
      'groceries' => ChartMark.groceries,
      'dining' => ChartMark.dining,
      'shopping' => ChartMark.shopping,
      'transport' => ChartMark.transport,
      'utilities' => ChartMark.utilities,
      'subscriptions' => ChartMark.subscriptions,
      'fun' => ChartMark.fun,
      'other' => ChartMark.other,
      'needs' => ChartMark.needs,
      'wants' => ChartMark.wants,
      'invested' => ChartMark.invested,
      'in cash' => ChartMark.inCash,
      _ => null,
    };

/// The role a part or dot uses. A name with no DESIGN 2.4 role takes the
/// Other role, so the name still carries a mark and no colour is invented.
ChartMark categoryMarkOrOther(String name) =>
    categoryMarkFor(name) ?? ChartMark.other;

/// The dot colour for [name]. Every category shows a dot; a name with no role
/// uses the Other colour.
Color categoryDotTint(BuildContext context, String name) =>
    ChartColours.of(context, ChartTone.onCard).mark(categoryMarkOrOther(name));
