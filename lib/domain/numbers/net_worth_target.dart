// SPEC 13.2: the net worth target share.
//
// The target measures net worth. It assigns no money. The share reached is
// current ÷ target, rounded once to one decimal place (half up). A missing
// current value or a target of zero is not available, never 0% (SPEC 4.3).
library;

import '../../core/money.dart';
import '../../core/percent.dart';
import 'spending_ratio.dart';

/// SPEC 13.2: the share of [target] reached by [current].
///
/// Returns null when [current] is null or [target] is zero or negative. Both
/// amounts must use the same currency.
Percent? netWorthTargetShare({
  required Money? current,
  required Money? target,
}) {
  if (current == null || target == null) {
    return null;
  }
  return percentOfMoney(current, target);
}
