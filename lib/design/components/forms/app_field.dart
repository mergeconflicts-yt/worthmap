import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';

/// DESIGN 6.4: `AppField`. A label above (`captionStrong`, `text.secondary`),
/// a 52 pt field (`surface.tile`, 1 px `border.chip`, `radius.m`), a helper
/// caption, and an optional trailing control.
class AppField extends StatelessWidget {
  const AppField({
    required this.label,
    required this.semanticLabel,
    this.controller,
    this.hint,
    this.helper,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    super.key,
  });

  final String label;

  /// The spoken name. The visible label is not read twice.
  final String semanticLabel;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool enabled;
  final bool autofocus;

  /// Masks the typed text (X64 password).
  final bool obscureText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.m),
      borderSide: BorderSide(
        color: enabled ? tokens.borderChip : tokens.disabled,
      ),
    );
    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.m),
      borderSide: BorderSide(
        color: enabled ? tokens.focusRing : tokens.disabled,
        width: BorderTokens.focusRing,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppText.captionStrong.copyWith(color: tokens.textSecondary),
        ),
        const VSpace(Space.xs),
        Semantics(
          label: semanticLabel,
          textField: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SizeTokens.field),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: autofocus,
              obscureText: obscureText,
              maxLines: maxLines,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: role.text,
              style: AppText.body.copyWith(color: tokens.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.body.copyWith(color: tokens.textSecondary),
                filled: true,
                fillColor: tokens.surfaceTile,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Space.card,
                  vertical: Space.m,
                ),
                border: border,
                enabledBorder: border,
                disabledBorder: border,
                focusedBorder: focused,
                suffixIcon: trailing,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: SizeTokens.touchMin,
                  minHeight: SizeTokens.touchMin,
                ),
              ),
            ),
          ),
        ),
        if (helper != null) ...<Widget>[
          const VSpace(Space.xs),
          Text(
            helper!,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
        ],
      ],
    );
  }
}
