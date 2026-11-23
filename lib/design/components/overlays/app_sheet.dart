import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/token_types.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';

/// DESIGN 5, 14.2: `AppSheet`. A `surface.sheet` panel with a 28 pt top
/// radius, a grabber, a `titleDialog` title, scrollable content and an
/// optional sticky footer. The height fits the content up to 90% of the
/// screen. A 1 pt divider appears under the title only after the content
/// scrolls.
class AppSheet extends StatefulWidget {
  const AppSheet({
    required this.title,
    required this.semanticLabel,
    required this.children,
    this.footer,
    this.scrollable = true,
    this.showGrabber = true,
    super.key,
  });

  final String title;
  final String semanticLabel;
  final List<Widget> children;
  final Widget? footer;
  final bool scrollable;
  final bool showGrabber;

  @override
  State<AppSheet> createState() => _AppSheetState();
}

class _AppSheetState extends State<AppSheet> {
  bool _scrolled = false;

  void _onScroll(ScrollNotification notification) {
    final scrolled = notification.metrics.pixels > 0;
    if (scrolled != _scrolled) {
      setState(() => _scrolled = scrolled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < widget.children.length; index++) ...[
          if (index > 0) const VSpace(Space.m),
          widget.children[index],
        ],
      ],
    );

    return Semantics(
      label: widget.semanticLabel,
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surfaceSheet,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RadiusTokens.sheet),
            ),
            border: Border.all(color: tokens.surfaceGlassEdge),
            boxShadow: tokens.elevationSheet.shadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.showGrabber)
                Padding(
                  padding: const EdgeInsets.only(top: Space.s),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.borderChip,
                        borderRadius: BorderRadius.circular(RadiusTokens.pill),
                      ),
                      child: const SizedBox(width: 36, height: 4),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.page,
                  Space.m,
                  Space.page,
                  Space.s,
                ),
                child: Text(
                  widget.title,
                  style:
                      AppText.titleDialog.copyWith(color: tokens.textPrimary),
                ),
              ),
              if (_scrolled)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: tokens.borderDivider),
                    ),
                  ),
                  child: const SizedBox(height: BorderTokens.hairline),
                ),
              Flexible(
                fit: FlexFit.loose,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    Space.s,
                    Space.page,
                    Space.page,
                  ),
                  child: widget.scrollable
                      ? NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            _onScroll(notification);
                            return false;
                          },
                          child: SingleChildScrollView(child: content),
                        )
                      : content,
                ),
              ),
              if (widget.footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    0,
                    Space.page,
                    Space.page,
                  ),
                  child: widget.footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows one [AppSheet] from the bottom. The scrim and the panel rise as one
/// piece; the panel is at most 90% of the screen height.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required String semanticLabel,
  required List<Widget> children,
  Widget? footer,
  bool scrollable = true,
  bool barrierDismissible = true,
}) {
  final tokens = context.tokens;
  // DESIGN 3: a sheet inherits the opener's section. The modal route builds
  // under the root navigator, so the scope is passed explicitly.
  final section = context.section;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: tokens.scrim,
    isDismissible: barrierDismissible,
    useSafeArea: true,
    builder: (context) => SectionScope(
      section: section,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: AppSheet(
          title: title,
          semanticLabel: semanticLabel,
          footer: footer,
          scrollable: scrollable,
          children: children,
        ),
      ),
    ),
  );
}
