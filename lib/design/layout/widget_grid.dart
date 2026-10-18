import 'package:flutter/widgets.dart';

import '../tokens/space.dart';

/// N-09: the pair grid for half-size placements. It lives in `lib/design/`
/// so no layout math sits in `lib/app/` (AGENTS 2.4).
///
/// Pairing follows the resolved visible order: the host passes one or two
/// cells. A lone half keeps its row with an empty second cell, so a later
/// partner cannot shift it.
class WidgetGrid extends StatelessWidget {
  WidgetGrid({required List<Widget> cells, super.key})
      : assert(
          cells.isNotEmpty && cells.length <= 2,
          'One or two cells',
        ),
        cells = List<Widget>.of(cells);

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    final second = cells.length == 2 ? cells[1] : const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: cells[0]),
        const HSpace(Space.card),
        Expanded(child: second),
      ],
    );
  }
}
