import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';

/// DESIGN 6.3, 6.9: a small count badge for a navigation item or a header
/// control.
///
/// The badge is decorative: its host owns the spoken name with the count. It
/// shows no amount, so it stays visible when amounts are hidden.
class CountBadge extends StatelessWidget {
  const CountBadge({
    required this.count,
    required this.color,
    super.key,
  });

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Center(
            child: Text(
              '$count',
              style: AppText.tabLabel.copyWith(
                color: tokens.textOnSection,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
