import 'package:flutter/widgets.dart';

import '../components/navigation/app_tab_bar.dart';
import '../tokens/space.dart';

/// SPEC 5.1 / DESIGN 14.2: the floating tab bar over a tab screen. The bar
/// sits 14 pt above the bottom and 16 pt from the sides, and hides while the
/// keyboard is open. The page reserves `space.tabClearance` at its end.
class TabShell extends StatelessWidget {
  const TabShell({
    required this.child,
    required this.tabBar,
    this.hideWithKeyboard = true,
    super.key,
  });

  final Widget child;
  final AppTabBar tabBar;
  final bool hideWithKeyboard;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        if (!(hideWithKeyboard && keyboard))
          Positioned(
            left: Space.s,
            right: Space.s,
            bottom: MediaQuery.paddingOf(context).bottom + AppTabBar.lift,
            child: tabBar,
          ),
      ],
    );
  }
}
