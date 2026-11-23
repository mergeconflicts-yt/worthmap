// P25 (SCREEN X61; flow F07 step 3): the Inbox item sheet.
//
// One staged item with its read fields and two actions: Delete (removes the
// staged item; no payment exists) and Confirm (one-item `ConfirmInboxBatch`).
// The sheet writes nothing itself.
library;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'inbox_models.dart';

/// Opens X61 and returns when the sheet closes.
Future<void> showInboxItemSheet(
  BuildContext context, {
  required InboxRow row,
  required VoidCallback onConfirm,
  required VoidCallback onDelete,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<void>(
    context,
    title: l.inboxItemTitle,
    semanticLabel: l.inboxItemTitle,
    children: <Widget>[
      X61InboxItemSheet(
        row: row,
        onConfirm: () {
          Navigator.of(context).pop();
          onConfirm();
        },
        onDelete: () {
          Navigator.of(context).pop();
          onDelete();
        },
      ),
    ],
  );
}

/// The sheet content. It is public so a golden can render it directly.
class X61InboxItemSheet extends StatelessWidget {
  const X61InboxItemSheet({
    required this.row,
    required this.onConfirm,
    required this.onDelete,
    super.key,
  });

  final InboxRow row;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final money = Money.fromMinor(
      row.amountMinor.abs(),
      Currency.of(row.currencyCode),
    );
    final category = row.categoryName == null
        ? l.inboxCategoryMissing
        : row.isUnsure
            ? l.inboxCategoryUnsure(row.categoryName!)
            : row.categoryName!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const IconTile(icon: AppIcons.inbox),
            const HSpace(Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    row.title.isEmpty ? l.inboxPaymentFallback : row.title,
                    style: AppText.bodyStrong,
                  ),
                  const VSpace(Space.xxs),
                  Text(
                    l.inboxItemSource(_sourceLabel(l, row.source)),
                    style: AppText.caption.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const VSpace(Space.l),
        GlassCard(
          child: Column(
            children: <Widget>[
              SelectRow(
                name: l.inboxFieldName,
                value: row.title.isEmpty ? l.inboxPaymentFallback : row.title,
                chevron: false,
              ),
              SelectRow(
                name: l.inboxFieldAmount,
                value: formatMoney(money),
                chevron: false,
              ),
              SelectRow(
                name: l.inboxFieldDate,
                value: formatDate(row.date, DateStyle.short),
                chevron: false,
              ),
              SelectRow(
                name: l.inboxFieldCategory,
                value: category,
                chevron: false,
              ),
              SelectRow(
                name: l.inboxFieldAccount,
                value: row.accountName ?? l.inboxNoneRecorded,
                chevron: false,
              ),
            ],
          ),
        ),
        const VSpace(Space.l),
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton(
                label: l.inboxDelete,
                variant: AppButtonVariant.ghost,
                icon: AppIcons.trash,
                fullWidth: false,
                onPressed: onDelete,
              ),
            ),
            const HSpace(Space.s),
            Expanded(
              child: AppButton(
                label: l.inboxConfirmOne,
                fullWidth: false,
                onPressed: row.needsDecision ? null : onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _sourceLabel(AppLocalizations l, String source) {
    final token = source.toLowerCase();
    if (token.contains('notification')) {
      return l.inboxSourceNotifications;
    }
    if (token.contains('mail')) {
      return l.inboxSourceMail;
    }
    if (token.contains('statement') || token.contains('bank')) {
      return l.inboxSourceStatement;
    }
    if (token.contains('receipt') || token.contains('qr')) {
      return l.inboxSourceReceipt;
    }
    return l.inboxSourceOther;
  }
}
