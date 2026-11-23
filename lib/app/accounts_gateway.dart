// P21 (SPEC 6.6; flow C01): the app composition for account setup.
//
// This is the only adapter between the account feature port and the data
// layer. The app mounts it when the vault is open; tests mount it over an
// in-memory vault. It holds no state and logs nothing (AGENTS 2.6).
//
// PF-01 / T07-CIPHER-BUILD still block the release path that would open a
// user vault, so `main` does not mount this adapter yet. The seam is ready
// and tested; `P21-UNWIRED-GATEWAY` records the gate.
library;

import 'dart:math';

import '../core/dates.dart';
import '../core/ids.dart';
import '../data/db/command_repository.dart';
import '../data/repositories/accounts.dart';
import '../data/repositories/write_plan.dart';
import '../features/accounts/account_models.dart';

/// P14 + the single command writer behind the C01 port.
///
/// One [createAccount] call writes the account, the inclusive anchor, the
/// selected pointer and the ChangeLog entries in one command.
final class SqlAccountsGateway implements AccountsGateway {
  SqlAccountsGateway({
    required this.accounts,
    required this.commands,
    required this.today,
    required this.newId,
  });

  final AccountRepository accounts;
  final CommandRepository commands;

  /// The cut-off for a listed balance. The app passes the local today.
  final LocalDate Function() today;

  /// A UUID v7 source. The app boundary supplies the clock and randomness
  /// (AGENTS 6.3).
  final String Function() newId;

  @override
  Future<List<AccountSummary>> listAccounts() async {
    final rows = await accounts.list();
    final asOf = today().toString();
    return <AccountSummary>[
      for (final row in rows)
        AccountSummary(
          id: row.id,
          name: row.name,
          kind: _kind(row.type),
          currencyCode: row.currency,
          balanceMinor: await _balance(row.id, asOf),
        ),
    ];
  }

  @override
  Future<AccountSummary> createAccount(AccountSetup setup) async {
    final accountId = newId();
    final anchorId = newId();
    final operationId = newId();
    final create = accounts.planCreateAccount(
      id: accountId,
      name: setup.name,
      type: setup.kind.databaseType,
      currency: setup.currencyCode,
      isLiability: setup.kind.isLiability,
      isLiquid: setup.countsAsCash,
      includeInNetWorth: setup.includeInNetWorth,
    );
    final signed = setup.kind.isLiability
        ? -setup.openingBalanceMinor
        : setup.openingBalanceMinor;
    final opening = accounts.planSetOpeningBalance(
      accountId: accountId,
      anchorId: anchorId,
      date: setup.openingDate.toString(),
      balanceMinor: signed,
      currency: setup.currencyCode,
    );
    final combined = WritePlan(
      changes: <ChangeLogEntry>[...create.changes, ...opening.changes],
      apply: () async {
        await create.apply();
        await opening.apply();
      },
    );
    await commands.prepare(
      operationId: operationId,
      commandType: 'account.create',
      draftId: newId(),
      formType: 'account',
      payloadJson: '{"v":1}',
      payloadVersion: 1,
      codecVersion: 1,
      schemaVersion: 1,
    );
    await commands.execute(
      operationId: operationId,
      changes: combined.changes,
      effects: combined.apply,
      resultJson: '{}',
    );
    return AccountSummary(
      id: accountId,
      name: setup.name,
      kind: setup.kind,
      currencyCode: setup.currencyCode,
      balanceMinor: signed,
    );
  }

  Future<int?> _balance(String accountId, String asOf) async {
    final balance = await accounts.balanceAt(accountId: accountId, asOf: asOf);
    return switch (balance) {
      KnownBalance(:final amount) => amount.minor,
      MissingBalance() => null,
    };
  }

  static AccountKind _kind(String type) => switch (type) {
        'card' => AccountKind.card,
        'cash' => AccountKind.cash,
        _ => AccountKind.bank,
      };
}

/// A UUID v7 from the wall clock and secure randomness, for the app boundary.
String newAccountId() {
  final now = DateTime.now().toUtc();
  final random = Random.secure();
  return UuidV7.generate(
    unixMillis: now.millisecondsSinceEpoch,
    randomBytes: List<int>.generate(10, (_) => random.nextInt(256)),
  ).toString();
}

/// The production cut-off: the local calendar date.
LocalDate accountToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
