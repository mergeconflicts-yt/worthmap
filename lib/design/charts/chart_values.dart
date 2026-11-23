import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../../core/decimal.dart';
import '../../core/money.dart';
import '../format/money_format.dart';
import '../format/value_presentation.dart';
import '../motion/motion.dart';

/// DESIGN 4, 7.1: the amount text for a chart, masked in the hidden state.
///
/// The currency mark stays and the digits become the mask, as in MoneyText.
/// Cents show only when the amount has cents (DESIGN 4), so a whole amount
/// reads "$20", not "$20.00".
String chartAmountText(Money amount, {required bool hidden}) {
  final presentation = formatValueState(ValueSpec.real(amount), hidden: hidden);
  if (hidden) {
    return presentation.text;
  }
  return _trimWholeFraction(presentation.text, amount.currency);
}

String _trimWholeFraction(String text, Currency currency) {
  if (currency.minorUnits == 0) {
    return text;
  }
  final zeros = '0' * currency.minorUnits;
  final suffix = '.$zeros';
  return text.endsWith(suffix)
      ? text.substring(0, text.length - suffix.length)
      : text;
}

/// DESIGN 7.1: the axis short form: "$150K", "$1.2M", "$303".
///
/// Exact rounding goes through Decimal. A chart may use `double` for drawing
/// coordinates only; this text never does.
String chartShortAmount(Money amount) {
  final mark = currencyMark(amount.currency);
  final sign = amount.isNegative ? minusSign : '';
  final major = amount.toDecimal().abs();
  final thousand = Decimal.fromInt(1000);
  final million = thousand * thousand;
  if (major >= million) {
    return '$sign$mark${_compact((major / million).toDecimal())}M';
  }
  if (major >= thousand) {
    return '$sign$mark${_compact((major / thousand).toDecimal())}K';
  }
  return '$sign$mark${major.round().toString()}';
}

String _compact(Decimal value) {
  if (value >= Decimal.fromInt(10)) {
    return roundToScale(value, 0, RoundingMode.halfUp).toString();
  }
  final tenths = roundToScale(value, 1, RoundingMode.halfUp);
  if (tenths == tenths.truncate()) {
    return tenths.truncate().toString();
  }
  return tenths.toString();
}

/// DESIGN 2.10, 7.1: one draw-in per chart per session, at most 900 ms.
///
/// Reduce motion shows the final state at once. The builder gets the progress
/// from 0 to 1; a data mark never overshoots.
class ChartMotion extends StatefulWidget {
  const ChartMotion({
    required this.duration,
    required this.builder,
    super.key,
  });

  final Duration duration;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<ChartMotion> createState() => _ChartMotionState();
}

class _ChartMotionState extends State<ChartMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isCompleted) {
      return widget.builder(context, 1);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) =>
          widget.builder(context, _controller.value),
    );
  }
}

/// DESIGN 7.1: the shared draw duration for a bar chart.
Duration get chartBarDuration => Motion.drawBar;

/// DESIGN 7.1: the shared draw duration for a line-like chart.
Duration get chartLineDuration => Motion.drawLine;
