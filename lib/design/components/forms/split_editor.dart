import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../buttons/icon_button.dart';
import '../interaction/app_interaction.dart';

/// One part in a [SplitEditor].
final class SplitPart {
  const SplitPart({
    required this.name,
    required this.amountText,
    required this.removeLabel,
    this.dotColor,
    this.onAmountTap,
    this.onRemove,
  });

  final String name;

  /// The formatted amount. The caller formats it through `lib/design/format/`.
  final String amountText;
  final String removeLabel;
  final Color? dotColor;
  final VoidCallback? onAmountTap;
  final VoidCallback? onRemove;
}

/// DESIGN 6.4: `SplitEditor`. Category and amount rows, "Add a part", and the
/// exact amount left to split. The screen owns the card and the values.
class SplitEditor extends StatelessWidget {
  const SplitEditor({
    required this.parts,
    required this.addLabel,
    required this.onAdd,
    required this.leftLabel,
    required this.leftValue,
    super.key,
  });

  final List<SplitPart> parts;
  final String addLabel;
  final VoidCallback? onAdd;
  final String leftLabel;

  /// A `MoneyText` or a value-state widget from the caller.
  final Widget leftValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final part in parts) ...<Widget>[
          Row(
            children: <Widget>[
              if (part.dotColor != null) ...<Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: part.dotColor,
                    borderRadius: BorderRadius.circular(RadiusTokens.xs),
                  ),
                  child: const SizedBox(width: Space.m, height: Space.m),
                ),
                const HSpace(Space.s),
              ],
              Expanded(
                child: Text(
                  part.name,
                  style: AppText.bodyStrong.copyWith(color: tokens.textPrimary),
                ),
              ),
              _AmountBox(
                amountText: part.amountText,
                onPressed: part.onAmountTap,
              ),
              AppIconButton(
                icon: AppIcons.close,
                semanticLabel: part.removeLabel,
                variant: AppIconButtonVariant.plain,
                onPressed: part.onRemove,
              ),
            ],
          ),
          const VSpace(Space.s),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: _TextAction(
            label: addLabel,
            color: role.text,
            onPressed: onAdd,
          ),
        ),
        const VSpace(Space.m),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                leftLabel,
                style: AppText.caption.copyWith(color: tokens.textSecondary),
              ),
            ),
            leftValue,
          ],
        ),
      ],
    );
  }
}

class _AmountBox extends StatelessWidget {
  const _AmountBox({required this.amountText, required this.onPressed});

  final String amountText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: amountText,
      button: onPressed != null,
      excludeSemantics: true,
      child: AppInteraction(
        onActivated: onPressed,
        enabled: onPressed != null,
        borderRadius: BorderRadius.circular(RadiusTokens.s),
        child: Container(
          constraints: const BoxConstraints(minHeight: SizeTokens.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          decoration: BoxDecoration(
            color: tokens.surfaceTile,
            borderRadius: BorderRadius.circular(RadiusTokens.s),
            border: Border.all(color: tokens.borderChip),
          ),
          child: Center(
            child: Text(
              amountText,
              style: AppText.numberXS.copyWith(color: tokens.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: AppInteraction(
        onActivated: onPressed,
        enabled: enabled,
        borderRadius: BorderRadius.circular(RadiusTokens.s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SizeTokens.touchMin),
          child: Center(
            child: Text(
              label,
              style: AppText.buttonS.copyWith(
                color: enabled ? color : context.tokens.disabled,
                decoration: TextDecoration.underline,
                decorationColor: enabled ? color : context.tokens.disabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
