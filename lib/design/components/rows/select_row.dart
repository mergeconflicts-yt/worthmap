import 'package:flutter/material.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';

/// DESIGN 6.3: `SelectRow` — name, optional grey line, value
/// (`text.secondary`) and chevron; minimum height `size.rowS`. A leading
/// slot holds an icon tile or a number when the reference shows one.
///
/// Rows keep to tokens only. A tappable row requires a semantic label
/// (AGENTS 6.9); an informational row needs none.
class SelectRow extends StatelessWidget {
  const SelectRow({
    required this.name,
    this.line,
    this.value,
    this.leading,
    this.trailing,
    this.chevron = true,
    this.onTap,
    this.semanticLabel,
    this.stackValue = false,
    super.key,
  }) : assert(onTap == null || semanticLabel != null);

  /// The row name (`bodyStrong`).
  final String name;

  /// The grey explanatory line (`caption`, `text.secondary`).
  final String? line;

  /// The value on the right (`text.secondary`).
  final String? value;

  /// An optional leading widget (icon tile, number).
  final Widget? leading;

  /// An optional trailing widget that replaces the value.
  final Widget? trailing;

  /// Draws the chevron. Rows without a chevron are informational.
  final bool chevron;

  final VoidCallback? onTap;

  /// The spoken description (AGENTS 6.9). Required when the row is tappable.
  final String? semanticLabel;

  /// Large text puts the value under the line instead of beside it, so the
  /// name and line keep the full width (X30 rows).
  final bool stackValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final largeText = MediaQuery.textScalerOf(context).scale(13) >= 13 * 1.3;
    final stack = stackValue && largeText;
    final valueText = value == null
        ? null
        : Text(
            value!,
            style: AppText.body.copyWith(color: tokens.textSecondary),
            textAlign: TextAlign.end,
          );
    final stackedValue = trailing ?? valueText;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SizeTokens.rowS),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: Space.m),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: AppText.bodyStrong),
                if (line != null) ...[
                  const SizedBox(height: Space.xxs),
                  Text(
                    line!,
                    style: AppText.caption.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
                if (stack && stackedValue != null) ...[
                  const SizedBox(height: Space.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: stackedValue,
                  ),
                ],
              ],
            ),
          ),
          if (!stack && trailing != null)
            trailing!
          else if (!stack && valueText != null)
            Flexible(child: valueText),
          if (chevron) ...[
            const SizedBox(width: Space.s),
            AppIcon(
              data: AppIcons.chevronRight,
              size: SizeTokens.iconM,
              color: tokens.iconSecondary,
            ),
          ],
        ],
      ),
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.m),
      child: content,
    );
    if (onTap == null) {
      return row;
    }
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
