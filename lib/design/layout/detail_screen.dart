import 'package:flutter/widgets.dart';

import '../tokens/space.dart';
import 'page_background.dart';

/// DESIGN 5, 14.2: `DetailScreen`. A [DetailHeader], a detail hero, then cards.
/// It keeps the parent's tab bar, so it needs no tab clearance of its own.
class DetailScreen extends StatelessWidget {
  const DetailScreen({
    required this.header,
    required this.children,
    super.key,
  });

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PageBackground(
      child: ListView(
        padding: const EdgeInsets.only(
          top: Space.l,
          left: Space.page,
          right: Space.page,
          bottom: Space.xxl,
        ),
        children: <Widget>[
          header,
          const VSpace(Space.l),
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const VSpace(Space.card),
            children[i],
          ],
        ],
      ),
    );
  }
}
