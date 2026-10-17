import 'package:flutter/widgets.dart';

import '../tokens/space.dart';
import 'page_background.dart';

/// DESIGN 5, 14.2: `FormScreen`. A Close (X) and an optional "Save" at the top,
/// the fields with labels above, and one full-width 52 pt primary button at the
/// bottom, in the scroll flow.
class FormScreen extends StatelessWidget {
  const FormScreen({
    required this.close,
    required this.primaryAction,
    required this.children,
    this.save,
    super.key,
  });

  /// The Close control (an `IconButton.onPage` with `AppIcons.close`).
  final Widget close;

  /// The one full-width primary button.
  final Widget primaryAction;

  /// An optional "Save" text action on the top line.
  final Widget? save;
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
          Row(
            children: <Widget>[
              close,
              const Spacer(),
              if (save != null) save!,
            ],
          ),
          const VSpace(Space.l),
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const VSpace(Space.xl),
            children[i],
          ],
          const VSpace(Space.xxl),
          primaryAction,
        ],
      ),
    );
  }
}
