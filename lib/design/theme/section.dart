import 'package:flutter/widgets.dart';

/// DESIGN 3: the router sets the section for a route; components read it.
/// Section sets chrome only (DESIGN 2.3).
enum Section { home, spending, income, wealth, plan }

/// DESIGN 3: `SectionScope` sets the section for a subtree. Components read
/// `context.section`. Sheets and dialogs inherit the opener's section.
class SectionScope extends InheritedWidget {
  const SectionScope({required this.section, required super.child, super.key});

  final Section section;

  static Section of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SectionScope>()?.section ??
      Section.home;

  @override
  bool updateShouldNotify(SectionScope oldWidget) =>
      oldWidget.section != section;
}

extension SectionContext on BuildContext {
  /// The current section, defaulting to Home (DESIGN 3).
  Section get section => SectionScope.of(this);
}
