import 'package:flutter/widgets.dart';

import '../design/tokens/tokens.g.dart';

/// T01 stub. Routing, theme, lock land in T04/T08/T09.
/// This stub shows a blank start screen only. No amounts. No network.
class ContourApp extends StatelessWidget {
  const ContourApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(T10): replace with l10n string and router.
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: ColorTokensDark.palettePage,
        child: Center(
          child: Text('Contour'),
        ),
      ),
    );
  }
}
