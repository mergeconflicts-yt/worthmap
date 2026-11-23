// P3-25 (SCREEN X65; flow F06 step 4): the import preview.
//
// The facts are the exact parsed counts: rows in the file, rows already in the
// app and new rows. The preview is a draft list; nothing is written until
// "Send to the Inbox".
library;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../features/accounts/account_models.dart';
import '../../l10n/generated/app_localizations.dart';
import 'import_controller.dart';

/// X65: facts, layout, preview and Send.
class X65ImportPreview extends StatelessWidget {
  const X65ImportPreview({
    required this.controller,
    required this.account,
    required this.accounts,
    required this.onAccount,
    required this.onClose,
    required this.onTeach,
    super.key,
  });

  final ImportController controller;
  final AccountSummary? account;
  final List<AccountSummary> accounts;
  final VoidCallback onAccount;
  final VoidCallback onClose;
  final VoidCallback onTeach;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final outcome = controller.outcome;
    final payments = outcome?.statement.payments ?? const [];
    final rows = outcome?.statement.rows.length ?? 0;
    final staged = payments.length;
    return DetailScreen(
      header: ScreenHeader(
        title: l.importTitle,
        dateLine: controller.fileName,
        leading: AppIconButton(
          icon: AppIcons.close,
          semanticLabel: l.importCancel,
          onPressed: onClose,
        ),
      ),
      children: <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.importPreviewKicker(controller.fileName ?? ''),
                style: AppText.labelCaps,
              ),
              const VSpace(Space.s),
              Text('$staged', style: AppText.numberXL),
              const VSpace(Space.xxs),
              Text(l.importPreviewLine(staged), style: AppText.body),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            children: <Widget>[
              SelectRow(
                name: l.importFactsRows,
                line: l.importFactsRowsMeta,
                value: '$rows',
                chevron: false,
              ),
              SelectRow(
                name: l.importFactsAlready,
                line: l.importFactsAlreadyMeta,
                value: '${controller.existing}',
                chevron: false,
              ),
              SelectRow(
                name: l.importFactsNew,
                line: l.importFactsNewMeta,
                value: '$staged',
                chevron: false,
              ),
            ],
          ),
        ),
        Text(
          controller.matchedLayout == null
              ? l.importNoLayout
              : l.importMatchedLayout(controller.matchedLayout!.name),
          style: AppText.caption.copyWith(color: context.tokens.textSecondary),
        ),
        GlassCard(
          title: l.importPreviewCard,
          meta: l.importPreviewMeta,
          child: Column(
            children: <Widget>[
              for (final row in payments.take(5))
                SelectRow(
                  name: '${_date(row.date.toString())} · ${row.description}',
                  value: _amount(row.amountMinor, row.currencyCode),
                  chevron: false,
                  semanticLabel: l.importSemanticAmount(
                    _amount(row.amountMinor, row.currencyCode),
                    row.description,
                  ),
                ),
              if (payments.length > 5)
                SelectRow(
                  name: l.importPreviewMore(payments.length - 5),
                  chevron: false,
                ),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            children: <Widget>[
              SelectRow(
                name: l.importSourceAccount,
                value: account?.name ?? l.importChooseAccount,
                onTap: onAccount,
                semanticLabel: l.importChooseAccount,
              ),
            ],
          ),
        ),
        AppButton(
          label: l.importSend(staged),
          onPressed: account == null
              ? null
              : () => controller.send(accountId: account!.id),
        ),
        if (account == null)
          Text(
            l.importNoAccount,
            style:
                AppText.caption.copyWith(color: context.tokens.textSecondary),
          ),
        AppButton(
          label: l.importWrongLayout,
          variant: AppButtonVariant.ghost,
          onPressed: onTeach,
        ),
        Text(
          l.importFileDeleted,
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: context.tokens.textSecondary),
        ),
      ],
    );
  }

  String _date(String iso) {
    final date = LocalDate.tryParse(iso);
    return date == null ? iso : formatDate(date, DateStyle.short);
  }

  String _amount(int minor, String currency) => formatMoney(
        Money.fromMinor(minor, Currency.of(currency)),
        sign: SignStyle.always,
      );
}
