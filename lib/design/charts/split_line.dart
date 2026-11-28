// DESIGN 7.2: `SplitLine` — a thin whole-and-parts line for a card header.
//
// The shares come from `Percent.split` (largest remainder). The line is a
// shape that repeats the values in the tiles below, so it carries one spoken
// label and no table (PREVIEW-CHART).
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../../core/percent.dart';
import 'chart_tone.dart';

/// One part of the line.
class SplitLinePart {
  const SplitLinePart({
    required this.name,
    required this.amount,
    required this.mark,
  });

  final String name;
  final Money amount;
  final ChartMark mark;
}

/// A thin pill line of coloured segments, one per part.
class SplitLine extends StatelessWidget {
  const SplitLine({
    required this.parts,
    required this.label,
    this.height = 10,
    super.key,
  });

  final List<SplitLinePart> parts;

  /// The spoken label, built by the caller with the exact values.
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    final colours = ChartColours.of(context, ChartTone.onCard);
    final shares = Percent.split(
      <Decimal>[for (final part in parts) Decimal.fromInt(part.amount.minor)],
    );
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < parts.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: _flex(shares[i]),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colours.mark(parts[i].mark),
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A layout weight from the share. One decimal is enough for the pixels.
  static int _flex(Percent share) {
    final weight = share.value.toDouble();
    final rounded = (weight * 10).round();
    return rounded < 1 ? 1 : rounded;
  }
}
