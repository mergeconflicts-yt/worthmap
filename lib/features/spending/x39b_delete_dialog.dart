// P27 (SCREEN X39b; flow F08 step 4): the delete confirmation.
//
// One destructive action and one ghost action. The dialog dismisses without a
// delete (F08-B). The caller writes nothing until the primary action returns
// true.
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// Shows X39b and returns true when the person confirms the delete.
Future<bool> showDeletePaymentDialog(
  BuildContext context, {
  required String name,
  required String amount,
  required String date,
}) async {
  final l = AppLocalizations.of(context);
  final result = await showAppDialog<bool>(
    context,
    leading: const IconTile(icon: AppIcons.trash),
    title: l.paymentsDeleteTitle,
    body: l.paymentsDeleteBody(name, amount, date),
    primaryLabel: l.paymentsDelete,
    primaryVariant: AppButtonVariant.destructive,
    secondaryLabel: l.paymentsDeleteKeep,
    semanticLabel: l.paymentsDeleteTitle,
    onPrimary: () => Navigator.of(context).pop(true),
    onSecondary: () => Navigator.of(context).pop(false),
  );
  return result ?? false;
}
