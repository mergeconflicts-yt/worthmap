import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/token_types.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';

/// DESIGN 6.7: `GlassCard` variants.
enum GlassCardVariant {
  /// A metal card of content.
  normal,

  /// Holds a chart (DESIGN 6.7, stage).
  stage,

  /// A wider card for side-by-side layouts.
  wide,
}

/// DESIGN 6.7: a metal surface: `surface.glass`, `elevation.glass`,
/// `radius.card`, padding 18 top and sides, 10 bottom.
///
/// CARD-TITLE-OUT: the title and meta sit above the card, 4 pt in from its
/// edge and 10 pt above it. The card and title are one reader group.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.variant = GlassCardVariant.normal,
    this.title,
    this.meta,
    this.titleOpens = false,
    this.onTap,
    this.padding,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final GlassCardVariant variant;

  /// The title above the card (`titleGroup`, `text.primary`).
  final String? title;

  /// The meta above the card, right-aligned (`label.caps`, `text.secondary`).
  final String? meta;

  /// Adds a small chevron to the title (a title that opens a screen).
  final bool titleOpens;

  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final effectivePadding = padding ??
        const EdgeInsets.only(
          top: Space.cardPad,
          left: Space.cardPad,
          right: Space.cardPad,
          bottom: Space.cardTitleGap,
        );
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        gradient: tokens.surfaceRim.toLinearGradient(),
        boxShadow: tokens.elevationGlass.shadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(BorderTokens.rimLight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              RadiusTokens.card - BorderTokens.rimLight,
            ),
            gradient: tokens.surfaceGlass.toLinearGradient(),
          ),
          child: Padding(padding: effectivePadding, child: child),
        ),
      ),
    );

    final body = onTap == null
        ? card
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: card,
            ),
          );

    final header = title == null
        ? null
        : _Header(title: title!, meta: meta, opens: titleOpens);
    if (header == null) {
      return _labelled(context, body, label: semanticLabel);
    }
    return _labelled(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: Space.xs,
              right: Space.xs,
              bottom: Space.cardTitleGap,
            ),
            child: header,
          ),
          body,
        ],
      ),
      label: semanticLabel,
    );
  }

  Widget _labelled(BuildContext context, Widget child, {String? label}) {
    if (onTap == null && label == null) {
      return child;
    }
    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.meta, required this.opens});

  final String title;
  final String? meta;
  final bool opens;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            title,
            style: AppText.titleGroup.copyWith(color: tokens.textPrimary),
          ),
        ),
        if (opens) ...<Widget>[
          const SizedBox(width: Space.xs),
          AppIcon(
            data: AppIcons.chevronRight,
            size: SizeTokens.iconS,
            color: tokens.textSecondary,
          ),
        ],
      ],
    );
    if (meta == null) {
      return titleRow;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: titleRow),
        const SizedBox(width: Space.s),
        Text(
          meta!.toUpperCase(),
          style: AppText.labelCaps.copyWith(color: tokens.textSecondary),
        ),
      ],
    );
  }
}
