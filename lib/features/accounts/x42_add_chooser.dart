// X42 (SPEC 6.6; flow C01; SCREENS X42): Add, choose a type.
//
// The screen lists the types the app can save today. It reads the account
// count per group and writes nothing. A type opens its form; the form holds
// the save.
library;

import 'package:flutter/widgets.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'account_models.dart';

/// One card of the chooser: a group and the types it holds.
final class _Group {
  const _Group(this.group, this.kinds);

  final AccountGroup group;
  final List<AccountKind> kinds;
}

/// SPEC 6.6: the groups the forms cover today.
///
/// Investments, retirement and deposits wait for their forms (P4-03).
const List<_Group> _groups = <_Group>[
  _Group(AccountGroup.cash, <AccountKind>[
    AccountKind.bank,
    AccountKind.cash,
  ]),
  _Group(AccountGroup.things, <AccountKind>[
    AccountKind.property,
    AccountKind.vehicle,
  ]),
  _Group(AccountGroup.owe, <AccountKind>[
    AccountKind.card,
    AccountKind.loan,
    AccountKind.moneyBorrowed,
  ]),
  _Group(AccountGroup.other, <AccountKind>[
    AccountKind.moneyLent,
    AccountKind.other,
  ]),
];

class X42AddChooser extends StatelessWidget {
  const X42AddChooser({
    required this.gateway,
    required this.onClose,
    required this.onPick,
    super.key,
  });

  final AccountsGateway gateway;

  /// Close (X): writes nothing.
  final VoidCallback onClose;

  /// Opens the form for the chosen type.
  final ValueChanged<AccountKind> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<AccountSummary>>(
      future: gateway.listAccounts(),
      builder:
          (BuildContext context, AsyncSnapshot<List<AccountSummary>> snap) {
        final accounts = snap.data ?? const <AccountSummary>[];
        return DetailScreen(
          header: ScreenHeader(
            leading: AppIconButton(
              icon: AppIcons.close,
              variant: AppIconButtonVariant.onPage,
              semanticLabel: l.accountClose,
              onPressed: onClose,
            ),
            kicker: l.x42Kicker,
            title: l.x42Title,
            dateLine: l.x42Subline,
          ),
          children: <Widget>[
            for (final group in _groups)
              GlassCard(
                title: _groupName(l, group.group),
                meta: l.x42GroupCount(
                  accounts.where((a) => a.kind.group == group.group).length,
                ),
                child: Column(
                  children: <Widget>[
                    for (final kind in group.kinds)
                      SelectRow(
                        name: _typeName(l, kind),
                        line: _typeHint(l, kind),
                        semanticLabel:
                            '${_typeName(l, kind)}. ${_typeHint(l, kind)}',
                        onTap: () => onPick(kind),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _groupName(AppLocalizations l, AccountGroup group) =>
      switch (group) {
        AccountGroup.cash => l.x42GroupCash,
        AccountGroup.investments => l.accountTypeOther,
        AccountGroup.retirement => l.accountTypeOther,
        AccountGroup.deposits => l.accountTypeOther,
        AccountGroup.things => l.x42GroupThings,
        AccountGroup.owe => l.x42GroupOwe,
        AccountGroup.other => l.x42GroupOther,
      };

  static String _typeName(AppLocalizations l, AccountKind kind) =>
      switch (kind) {
        AccountKind.bank => l.accountTypeBank,
        AccountKind.cash => l.accountTypeCash,
        AccountKind.card => l.accountTypeCard,
        AccountKind.property => l.accountTypeProperty,
        AccountKind.vehicle => l.accountTypeVehicle,
        AccountKind.loan => l.accountTypeLoan,
        AccountKind.moneyBorrowed => l.accountTypeMoneyBorrowed,
        AccountKind.moneyLent => l.accountTypeMoneyLent,
        AccountKind.other => l.accountTypeOther,
        _ => l.accountTypeOther,
      };

  static String _typeHint(AppLocalizations l, AccountKind kind) =>
      switch (kind) {
        AccountKind.bank => l.x42HintBank,
        AccountKind.cash => l.x42HintCash,
        AccountKind.card => l.x42HintCard,
        AccountKind.property => l.x42HintProperty,
        AccountKind.vehicle => l.x42HintVehicle,
        AccountKind.loan => l.x42HintLoan,
        AccountKind.moneyBorrowed => l.x42HintBorrowed,
        AccountKind.moneyLent => l.x42HintLent,
        _ => l.x42HintOther,
      };
}
