// P21 (SPEC 6.6; flows C01; DECISIONS CLOSED-G01): the account setup feature
// contract.
//
// The feature talks to one port. The app composition (T07/T09) supplies the
// implementation over the account repository; tests supply one over an
// in-memory vault. No widget reads the database (AGENTS 6.2).
library;

import '../../core/dates.dart';
import '../../core/money.dart';

/// SPEC 6.6: the three account kinds of the minimal C01 form.
enum AccountKind {
  bank,
  cash,
  card;

  /// The authored `accounts.type` value.
  String get databaseType => switch (this) {
        AccountKind.bank => 'bank',
        AccountKind.cash => 'cash',
        AccountKind.card => 'card',
      };

  /// DESIGN 2.4, SPEC 6.6: a card is a liability.
  bool get isLiability => this == AccountKind.card;
}

/// SPEC 6.6, flow C01: one validated account and its inclusive opening
/// balance. The amount is in minor units of [currencyCode].
final class AccountSetup {
  const AccountSetup({
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.openingBalanceMinor,
    required this.openingDate,
    required this.countsAsCash,
    required this.includeInNetWorth,
  });

  final String name;
  final AccountKind kind;
  final String currencyCode;

  /// The entered balance. A zero is real (G01-E). A card balance is the owed
  /// amount, always zero or more.
  final int openingBalanceMinor;

  /// The inclusive anchor date (G01-A).
  final LocalDate openingDate;
  final bool countsAsCash;
  final bool includeInNetWorth;
}

/// One account row for the picker and the form result.
final class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.balanceMinor,
  });

  final String id;
  final String name;
  final AccountKind kind;
  final String currencyCode;

  /// The signed balance at the cut-off; null is Missing (never zero, G01-E).
  final int? balanceMinor;

  bool get isLiability => kind.isLiability;

  Money? get balance {
    final minor = balanceMinor;
    if (minor == null) {
      return null;
    }
    return Money.fromMinor(minor, Currency.of(currencyCode));
  }

  bool get owes => isLiability && (balanceMinor ?? 0) < 0;
}

/// The account data port. One call is one commit boundary group.
abstract interface class AccountsGateway {
  /// Accounts by name. A closed or unreadable store returns an
  /// [AccountsError].
  Future<List<AccountSummary>> listAccounts();

  /// `CreateAccount` + `SetOpeningBalance` for one setup. The written records
  /// are the account, the inclusive anchor, the selected anchor pointer and
  /// the ChangeLog entries.
  Future<AccountSummary> createAccount(AccountSetup setup);
}

/// Typed, safe failure codes (no amount, name or id in the text).
enum AccountsErrorCode {
  /// The app composition has not mounted a gateway (vault closed or unwired).
  notWired,
  invalidSetup,
  saveFailed,
}

class AccountsError implements Exception {
  const AccountsError(this.code);

  final AccountsErrorCode code;

  @override
  String toString() => 'AccountsError(${code.name})';
}

/// The placeholder gateway before the app composition mounts the vault.
final class UnavailableAccountsGateway implements AccountsGateway {
  const UnavailableAccountsGateway();

  @override
  Future<List<AccountSummary>> listAccounts() async =>
      throw const AccountsError(AccountsErrorCode.notWired);

  @override
  Future<AccountSummary> createAccount(AccountSetup setup) async =>
      throw const AccountsError(AccountsErrorCode.notWired);
}
