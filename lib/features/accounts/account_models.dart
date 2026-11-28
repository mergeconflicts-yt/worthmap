// P21 (SPEC 6.6; flows C01; DECISIONS CLOSED-G01): the account setup feature
// contract.
//
// The feature talks to one port. The app composition (T07/T09) supplies the
// implementation over the account repository; tests supply one over an
// in-memory vault. No widget reads the database (AGENTS 6.2).
library;

import 'package:decimal/decimal.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/values/value_projection.dart';

/// SPEC 6.6: the seven groups of the Add, choose type screen.
enum AccountGroup {
  cash,
  investments,
  retirement,
  deposits,
  things,
  owe,
  other
}

/// SPEC 6.6 and SPEC 9.2: one account type.
///
/// The authored `accounts.type` values are the database contract. A card, a
/// loan and money borrowed are liabilities; the screen shows their owed
/// amount as a positive value.
enum AccountKind {
  bank('bank'),
  cash('cash'),
  card('card'),
  brokerage('brokerage'),
  pension('pension'),
  deposit('deposit'),
  property('property'),
  vehicle('vehicle'),
  preciousMetal('preciousMetal'),
  loan('loan'),
  moneyLent('moneyLent'),
  moneyBorrowed('moneyBorrowed'),
  other('other');

  const AccountKind(this.databaseType);

  /// The authored `accounts.type` value.
  final String databaseType;

  /// Maps a stored type. An unknown stored type is Other, never a guess.
  static AccountKind fromDatabase(String type) {
    for (final kind in AccountKind.values) {
      if (kind.databaseType == type) {
        return kind;
      }
    }
    return AccountKind.other;
  }

  /// SPEC 6.6: a card, a loan and money borrowed are liabilities.
  bool get isLiability => switch (this) {
        AccountKind.card ||
        AccountKind.loan ||
        AccountKind.moneyBorrowed =>
          true,
        _ => false,
      };

  /// SPEC 6.6: the Add, choose type group.
  AccountGroup get group => switch (this) {
        AccountKind.bank || AccountKind.cash => AccountGroup.cash,
        AccountKind.brokerage ||
        AccountKind.preciousMetal =>
          AccountGroup.investments,
        AccountKind.pension => AccountGroup.retirement,
        AccountKind.deposit => AccountGroup.deposits,
        AccountKind.property || AccountKind.vehicle => AccountGroup.things,
        AccountKind.card ||
        AccountKind.loan ||
        AccountKind.moneyBorrowed =>
          AccountGroup.owe,
        AccountKind.moneyLent || AccountKind.other => AccountGroup.other,
      };

  /// SPEC 6.6: the balance counts as cash you can use by default.
  bool get isCashByDefault =>
      this == AccountKind.bank || this == AccountKind.cash;
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

/// SPEC 6.6, X42b: one term deposit and its interest rule.
///
/// The amount is the principal in minor units. The rate is a fraction (0.041
/// is 4.1%). The rule restarts from any later real value (P4-01).
final class DepositSetup {
  const DepositSetup({
    required this.name,
    required this.currencyCode,
    required this.amountMinor,
    required this.annualRate,
    required this.compounding,
    required this.start,
    required this.maturity,
    this.renewsAutomatically = false,
    this.countsAsCash = false,
    this.includeInNetWorth = true,
  });

  final String name;
  final String currencyCode;
  final int amountMinor;
  final Decimal annualRate;
  final Compounding compounding;
  final LocalDate start;
  final LocalDate maturity;
  final bool renewsAutomatically;

  /// SPEC 6.6: a term deposit is locked until maturity, so the default is off.
  final bool countsAsCash;
  final bool includeInNetWorth;
}

/// SPEC 6.6, X42b: the deposit save port.
///
/// One call writes the account, its inclusive anchor and its interest rule in
/// one commit. It changes no payment.
abstract interface class DepositGateway {
  Future<AccountSummary> createDeposit(DepositSetup setup);
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
