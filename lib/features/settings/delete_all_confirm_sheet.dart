import 'package:contour/design/design.dart';
import 'package:contour/features/settings/delete_all_controller.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// T11 (SPEC 11; flows F21): the Delete-all destructive confirm sheet, UI
/// only. It never runs the executor itself; the controller on X86 owns the
/// confirm chain.
///
/// The strings below are Phase 1 l10n additions owned by this task
/// (DECISIONS T11-L10N). No advice wording; the verbs are exact.
class DeleteAllConfirmSheet extends StatelessWidget {
  const DeleteAllConfirmSheet({
    required this.controller,
    super.key,
  });

  final DeleteAllController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return Semantics(
      label: l.deleteAllSheetSpoken,
      child: Padding(
        padding: const EdgeInsets.all(Space.cardPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.deleteAllSheetTitle, style: AppText.titleScreen),
            const VSpace(Space.s),
            Text(
              l.deleteAllSheetLine,
              style: AppText.line.copyWith(color: tokens.textSecondary),
            ),
            const VSpace(Space.l),
            AppButton(
              label: l.deleteAllSheetConfirm,
              variant: AppButtonVariant.destructive,
              onPressed: () async {
                await controller.confirmSecond();
              },
            ),
            const VSpace(Space.s),
            AppButton(
              label: l.deleteAllSheetCancel,
              variant: AppButtonVariant.ghost,
              onPressed: controller.cancel,
            ),
          ],
        ),
      ),
    );
  }
}
