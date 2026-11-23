import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/section.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../buttons/app_button.dart';

/// DESIGN 5, 6.6: `AppDialog`. A centred `surface.sheet` card 28 pt from the
/// sides: title, body, primary (or destructive) button, ghost button stacked.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.semanticLabel,
    this.primaryVariant = AppButtonVariant.primary,
    this.leading,
    this.child,
    super.key,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final String semanticLabel;
  final AppButtonVariant primaryVariant;

  /// An optional badge above the title (X87 microphone). It is decorative and
  /// excluded from semantics; the title carries the meaning.
  final Widget? leading;

  /// Optional form content between the body and the actions (X64 password).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: semanticLabel,
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.all(Space.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              Align(child: leading!),
              const VSpace(Space.l),
            ],
            Text(
              title,
              style: AppText.titleDialog.copyWith(color: tokens.textPrimary),
            ),
            if (body.isNotEmpty) ...<Widget>[
              const VSpace(Space.s),
              Text(
                body,
                style: AppText.line.copyWith(color: tokens.textSecondary),
              ),
            ],
            if (child != null) ...<Widget>[
              const VSpace(Space.l),
              child!,
            ],
            const VSpace(Space.l),
            AppButton(
              label: primaryLabel,
              variant: primaryVariant,
              onPressed: onPrimary,
            ),
            const VSpace(Space.s),
            AppButton(
              label: secondaryLabel,
              variant: AppButtonVariant.ghost,
              onPressed: onSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows one [AppDialog] behind the app scrim. The barrier dismisses unless
/// [barrierDismissible] is false.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  required String body,
  required String primaryLabel,
  required VoidCallback onPrimary,
  required String secondaryLabel,
  required VoidCallback onSecondary,
  required String semanticLabel,
  AppButtonVariant primaryVariant = AppButtonVariant.primary,
  bool barrierDismissible = true,
  Widget? leading,
  Widget? child,
}) {
  final tokens = context.tokens;
  // DESIGN 3: a dialog inherits the opener's section. The dialog route builds
  // under the root navigator, so the scope is passed explicitly.
  final section = context.section;
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: tokens.scrim,
    builder: (context) => SectionScope(
      section: section,
      child: Dialog(
        backgroundColor: tokens.surfaceSheet,
        insetPadding: const EdgeInsets.symmetric(horizontal: Space.xxl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.sheet),
        ),
        child: AppDialog(
          title: title,
          body: body,
          primaryLabel: primaryLabel,
          onPrimary: onPrimary,
          secondaryLabel: secondaryLabel,
          onSecondary: onSecondary,
          semanticLabel: semanticLabel,
          primaryVariant: primaryVariant,
          leading: leading,
          child: child,
        ),
      ),
    ),
  );
}
