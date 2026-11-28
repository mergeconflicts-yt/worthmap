// P21 (SPEC 6.6; flow C01): the account picker used by the payment forms.
//
// The picker reads the supplied list and returns one account. A Missing
// balance is "Missing", never zero; a card shows the owed amount as a positive
// number with the word "Owes" (SPEC 6.6, G01-E).
library;

import 'package:flutter/widgets.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'account_models.dart';

/// The picker content. It sits in one `AppSheet`; the caller supplies the
/// selection path and an optional "Add an account" action.
class AccountPickerSheet extends StatelessWidget {
  const AccountPickerSheet({
    required this.accounts,
    required this.onSelected,
    this.onAdd,
    super.key,
  });

  final List<AccountSummary> accounts;
  final ValueChanged<AccountSummary> onSelected;

  /// Opens C01 when set. The picker does not add a second add control.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (accounts.isEmpty)
          Text(
            l.accountPickerEmpty,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          )
        else
          for (final account in accounts)
            SelectRow(
              name: account.name,
              line: _typeLine(l, account.kind),
              trailing: _balance(context, l, account),
              semanticLabel: '${account.name}, ${_typeLine(l, account.kind)}',
              onTap: () => onSelected(account),
            ),
        if (onAdd != null) ...<Widget>[
          const VSpace(Space.m),
          AppButton(
            label: l.accountPickerAdd,
            variant: AppButtonVariant.ghost,
            onPressed: onAdd,
          ),
        ],
      ],
    );
  }

  Widget _balance(
    BuildContext context,
    AppLocalizations l,
    AccountSummary account,
  ) {
    final money = account.balance;
    if (money == null) {
      return MoneyText(
        ValueSpec.missing(l.accountBalanceMissing),
        style: AppText.numberXS.copyWith(
          color: context.tokens.textSecondary,
        ),
      );
    }
    if (account.owes) {
      return MoneyText(
        ValueSpec.real(-money),
        prefix: '${l.accountOwes} ',
        style: AppText.numberXS.copyWith(
          color: context.tokens.textPrimary,
        ),
      );
    }
    return MoneyText(
      ValueSpec.real(money),
      style: AppText.numberXS.copyWith(color: context.tokens.textPrimary),
    );
  }

  static String _typeLine(AppLocalizations l, AccountKind kind) =>
      switch (kind) {
        AccountKind.bank => l.accountLineBank,
        AccountKind.cash => l.accountLineCash,
        AccountKind.card => l.accountLineCard,
        _ => l.accountLineOther,
      };
}

/// Opens the picker and returns the chosen account, or null when dismissed.
Future<AccountSummary?> showAccountPicker(
  BuildContext context, {
  required List<AccountSummary> accounts,
  VoidCallback? onAdd,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<AccountSummary>(
    context,
    title: l.accountPickerTitle,
    semanticLabel: l.accountPickerSpoken,
    children: <Widget>[
      AccountPickerSheet(
        accounts: accounts,
        onSelected: (account) => Navigator.of(context).pop(account),
        onAdd: onAdd == null
            ? null
            : () {
                Navigator.of(context).pop();
                onAdd();
              },
      ),
    ],
  );
}
