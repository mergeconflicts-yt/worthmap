// X40 (SCREENS; SPEC 6.5): the net-worth change for the selected period.
//
// The change is the difference between two readings. The share divides by
// the earlier reading, so a flow into the accounts counts as change, as the
// X40 side figures show. Missing is never zero (SPEC 4.3).
library;

import 'package:decimal/decimal.dart';

import '../../core/percent.dart';

/// The signed change in minor units, or null when a reading is Missing.
///
/// X40: "$16,900 · 12 months" is `end − start`.
int? wealthChangeMinor({int? startMinor, int? endMinor}) {
  if (startMinor == null || endMinor == null) {
    return null;
  }
  return endMinor - startMinor;
}

/// The change as a share of [startMinor], in percentage points.
///
/// Null when a reading is Missing or the start is zero: a share of zero has
/// no meaning and must not read as 0% (SPEC 4.3, DESIGN 4).
Percent? wealthChangeShare({int? startMinor, int? endMinor}) {
  final change = wealthChangeMinor(
    startMinor: startMinor,
    endMinor: endMinor,
  );
  final start = startMinor;
  if (change == null || start == null || start == 0) {
    return null;
  }
  return Percent.fromFraction(
    (Decimal.fromInt(change) / Decimal.fromInt(start))
        .toDecimal(scaleOnInfinitePrecision: 6),
  );
}
