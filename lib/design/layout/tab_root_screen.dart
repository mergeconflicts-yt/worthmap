import 'package:flutter/widgets.dart';

import '../tokens/space.dart';
import 'page_background.dart';

/// DESIGN 5, 14.2: `TabRootScreen`. A spotlight page, a [ScreenHeader], then a
/// hero and cards. Cards have 14 pt gaps. The template reserves the tab-bar
/// clearance at the bottom. Features pass a header and the blocks in order.
class TabRootScreen extends StatelessWidget {
  const TabRootScreen({
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
          bottom: Space.tabClearance,
        ),
        children: <Widget>[
          header,
          const VSpace(Space.xl),
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const VSpace(Space.card),
            children[i],
          ],
        ],
      ),
    );
  }
}
