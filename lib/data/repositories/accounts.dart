// P14 (DECISIONS CLOSED-G01; DATABASE_DESIGN 4.1): accounts, anchors and
// balances.
//
// G01-A: an anchor is the balance at the end of its local date, inclusive.
// G01-B: balance = anchor + accepted postings strictly after the anchor date.
// G01-E: no selected anchor is Missing, never zero; an entered zero is real.
// The stored balance is signed (a liability is negative); the screen shows an
// owed amount as its positive value.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/money.dart';
import '../db/app_database.dart';
import '../db/command_repository.dart';
import 'write_plan.dart';

/// One account row.
final class AccountRow {
  const AccountRow({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.isLiability,
    required this.isLiquid,
    required this.includeInNetWorth,
    required this.revision,
    this.institution,
  });

  final String id;
  final String name;
  final String type;
  final String currency;
  final bool isLiability;
  final bool isLiquid;
  final bool includeInNetWorth;
  final int revision;

  /// SPEC 9.2: the bank or broker name. Null when the user entered none.
  final String? institution;
}

/// SPEC 6.6, X41: one account and its value at the read date.
final class AccountDetail {
  const AccountDetail({required this.account, required this.balance});

  final AccountRow account;

  /// Known from the selected anchor, or Missing (G01-E).
  final AccountBalance balance;
}

/// SPEC 9.2, schema version 10: one value method per account.
///
/// The rule holds the method and its bounded parameters. The real value stays
/// the selected balance anchor, so this row holds no balance.
final class ValuationRuleRow {
  const ValuationRuleRow({
    required this.id,
    required this.accountId,
    required this.method,
    required this.parametersJson,
    required this.revision,
  });

  final String id;
  final String accountId;
  final String method;
  final String parametersJson;
  final int revision;
}

/// SPEC 9.2: the value methods. The database check holds the same list.
const Set<String> kValueMethods = <String>{
  'marketPrice',
  'interest',
  'contribution',
  'weightPrice',
  'manual',
  'depreciation',
  'capitalAccount',
};

/// G01-E: a balance is known from a selected anchor, or Missing.
sealed class AccountBalance {
  const AccountBalance();
}

/// The balance at the cut-off, from the selected anchor plus later postings.
final class KnownBalance extends AccountBalance {
  const KnownBalance({required this.amount, required this.anchorDate});

  final Money amount;
  final String anchorDate;
}

/// No selected anchor: Missing (never zero).
final class MissingBalance extends AccountBalance {
  const MissingBalance();
}

/// Account reads and prepared writes.
final class AccountRepository {
  AccountRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
  })  : _db = db,
        _clockUtc = clockUtc;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  /// Accounts by name.
  Future<List<AccountRow>> list() async {
    final rows = await _db
        .customSelect(
          'SELECT id, name, type, currency, institution, is_liability, '
          'is_liquid, include_in_net_worth, revision FROM accounts '
          'WHERE deleted_at IS NULL ORDER BY name',
        )
        .get();
    return <AccountRow>[
      for (final row in rows)
        AccountRow(
          id: row.data['id'] as String,
          name: row.data['name'] as String,
          type: row.data['type'] as String,
          currency: row.data['currency'] as String,
          isLiability: (row.data['is_liability'] as int) == 1,
          isLiquid: (row.data['is_liquid'] as int) == 1,
          includeInNetWorth: (row.data['include_in_net_worth'] as int) == 1,
          revision: row.data['revision'] as int,
          institution: row.data['institution'] as String?,
        ),
    ];
  }

  /// X41: one live account and its value at [asOf]. Null when it is absent.
  Future<AccountDetail?> findById({
    required String id,
    required String asOf,
  }) async {
    final row = await _db.customSelect(
      'SELECT id, name, type, currency, institution, is_liability, '
      'is_liquid, include_in_net_worth, revision FROM accounts '
      'WHERE id = ? AND deleted_at IS NULL',
      variables: [Variable(id)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    final account = AccountRow(
      id: row.data['id'] as String,
      name: row.data['name'] as String,
      type: row.data['type'] as String,
      currency: row.data['currency'] as String,
      isLiability: (row.data['is_liability'] as int) == 1,
      isLiquid: (row.data['is_liquid'] as int) == 1,
      includeInNetWorth: (row.data['include_in_net_worth'] as int) == 1,
      revision: row.data['revision'] as int,
      institution: row.data['institution'] as String?,
    );
    return AccountDetail(
      account: account,
      balance: await balanceAt(accountId: id, asOf: asOf),
    );
  }

  /// G01-A to G01-E: the balance as at [asOf], or Missing.
  Future<AccountBalance> balanceAt({
    required String accountId,
    required String asOf,
  }) async {
    final pointer = await _db.customSelect(
      'SELECT a.date AS anchor_date, a.balance_minor, a.currency '
      'FROM current_balance_anchors c '
      'JOIN balance_anchors a ON a.id = c.anchor_id '
      'WHERE c.account_id = ?',
      variables: [Variable(accountId)],
    ).getSingleOrNull();
    if (pointer == null) {
      return const MissingBalance();
    }
    final anchorDate = pointer.data['anchor_date'] as String;
    if (asOf.compareTo(anchorDate) < 0) {
      // The anchor says nothing about the account before its own date.
      // A historical read before the anchor is Missing, never the anchor
      // balance (SPEC 4.3).
      return const MissingBalance();
    }
    final currency = Currency.of(pointer.data['currency'] as String);
    final sum = await _db.customSelect(
      'SELECT COALESCE(SUM(amount_minor), 0) AS delta FROM transactions '
      'WHERE account_id = ? AND deleted_at IS NULL '
      'AND date > ? AND date <= ?',
      variables: [Variable(accountId), Variable(anchorDate), Variable(asOf)],
    ).getSingle();
    final minor =
        (pointer.data['balance_minor'] as int) + (sum.data['delta'] as int);
    return KnownBalance(
      amount: Money.fromMinor(minor, currency),
      anchorDate: anchorDate,
    );
  }

  /// The number of live holdings. Home uses it to tell "no holdings" (Invested
  /// is zero) from "holdings exist, cost basis not read here" (Missing).
  Future<int> holdingCount() async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM holdings WHERE deleted_at IS NULL',
        )
        .getSingle();
    return row.data['n'] as int;
  }

  /// The earliest live balance anchor date, for the MAX period.
  Future<String?> firstAnchorDate() async {
    final row = await _db
        .customSelect(
          'SELECT MIN(date) AS d FROM balance_anchors WHERE deleted_at IS NULL',
        )
        .getSingle();
    return row.data['d'] as String?;
  }

  /// The live value rule of [accountId], or null when none is stored.
  Future<ValuationRuleRow?> ruleFor(String accountId) async {
    final row = await _db.customSelect(
      'SELECT id, account_id, method, parameters_json, revision '
      'FROM valuation_rules WHERE account_id = ? AND deleted_at IS NULL',
      variables: [Variable(accountId)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return ValuationRuleRow(
      id: row.data['id'] as String,
      accountId: row.data['account_id'] as String,
      method: row.data['method'] as String,
      parametersJson: row.data['parameters_json'] as String,
      revision: row.data['revision'] as int,
    );
  }

  /// Saves one value rule. Pass [current] to edit; null inserts a new row.
  ///
  /// The parameters are bounded JSON. The method comes from [kValueMethods];
  /// an unknown method is a programmer error, not a user state.
  WritePlan planSaveRule({
    required String id,
    required String accountId,
    required String method,
    required String parametersJson,
    ValuationRuleRow? current,
  }) {
    if (!kValueMethods.contains(method)) {
      throw ArgumentError.value(method, 'method', 'Unknown value method');
    }
    final decoded = jsonDecode(parametersJson);
    if (decoded is! Map<String, Object?>) {
      throw ArgumentError.value(
        parametersJson,
        'parametersJson',
        'Must be a JSON object',
      );
    }
    final now = _nowMs();
    if (current == null) {
      return WritePlan(
        changes: <ChangeLogEntry>[
          ChangeLogEntry(
            entityId: id,
            toRevision: 1,
            changeKind: 'create',
            afterJson: jsonEncode(<String, Object?>{
              'accountId': accountId,
              'method': method,
            }),
            schemaVersion: 1,
          ),
        ],
        apply: () async {
          await _db.customStatement(
            'INSERT INTO valuation_rules (id, created_at, updated_at, '
            'deleted_at, revision, account_id, method, parameters_json) '
            'VALUES (?, ?, ?, NULL, 1, ?, ?, ?)',
            [id, now, now, accountId, method, parametersJson],
          );
        },
      );
    }
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: current.id,
          fromRevision: current.revision,
          toRevision: current.revision + 1,
          changeKind: 'edit',
          beforeJson: jsonEncode(<String, Object?>{'method': current.method}),
          afterJson: jsonEncode(<String, Object?>{'method': method}),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'UPDATE valuation_rules SET method = ?, parameters_json = ?, '
          'updated_at = ?, revision = revision + 1 WHERE id = ?',
          [method, parametersJson, now, current.id],
        );
      },
    );
  }

  /// C01: creates an account (one authored row).
  WritePlan planCreateAccount({
    required String id,
    required String name,
    required String type,
    required String currency,
    String? institution,
    String ownershipPercent = '100',
    int? minimumBalanceMinor,
    int? overdraftLimitMinor,
    bool isLiability = false,
    bool isLiquid = false,
    bool includeInNetWorth = true,
  }) {
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'name': name,
            'type': type,
            'institution': institution,
          }),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'INSERT INTO accounts (id, created_at, updated_at, deleted_at, '
          'revision, name, type, currency, institution, '
          'ownership_percent_decimal, minimum_balance_minor, '
          'overdraft_limit_minor, is_liability, is_liquid, '
          'include_in_net_worth, archived) '
          'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
          [
            id,
            now,
            now,
            name,
            type,
            currency,
            institution,
            ownershipPercent,
            minimumBalanceMinor,
            overdraftLimitMinor,
            isLiability ? 1 : 0,
            isLiquid ? 1 : 0,
            includeInNetWorth ? 1 : 0,
          ],
        );
      },
    );
  }

  /// C01 opening balance: an immutable inclusive anchor, selected at once.
  ///
  /// G01-E: a zero is a real anchor. A correction passes [supersedesAnchorId]
  /// and becomes the new selected pointer (DATABASE_DESIGN 4.1).
  WritePlan planSetOpeningBalance({
    required String accountId,
    required String anchorId,
    required String date,
    required int balanceMinor,
    required String currency,
    String? supersedesAnchorId,
  }) {
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: anchorId,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'date': date,
            'balanceMinor': balanceMinor,
          }),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        final running = await _db.customSelect(
          'SELECT operation_id FROM operation_intents WHERE state = ? LIMIT 1',
          variables: [const Variable('running')],
        ).getSingleOrNull();
        if (running == null) {
          throw StateError('No running operation for the balance');
        }
        await _db.customStatement(
          'INSERT INTO balance_anchors (id, created_at, updated_at, '
          'deleted_at, revision, account_id, date, balance_minor, currency, '
          'source, source_identity_id, inclusive, supersedes_anchor_id) '
          'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, NULL, 1, ?)',
          [
            anchorId,
            now,
            now,
            accountId,
            date,
            balanceMinor,
            currency,
            'manual',
            supersedesAnchorId,
          ],
        );
        await _db.customStatement(
          'DELETE FROM current_balance_anchors WHERE account_id = ?',
          [accountId],
        );
        await _db.customStatement(
          'INSERT INTO current_balance_anchors (account_id, anchor_id, '
          'selected_operation_id) VALUES (?, ?, ?)',
          [
            accountId,
            anchorId,
            running.data['operation_id'] as String,
          ],
        );
        await _db.customStatement(
          'INSERT INTO dependency_scopes (kind, scope_key) '
          'SELECT ?, ? WHERE NOT EXISTS (SELECT 1 FROM dependency_scopes '
          'WHERE kind = ? AND scope_key = ?)',
          ['account', accountId, 'account', accountId],
        );
        await _db.customStatement(
          'UPDATE dependency_revisions SET revision = revision + 1 '
          'WHERE scope_id = (SELECT id FROM dependency_scopes '
          'WHERE kind = ? AND scope_key = ?)',
          ['account', accountId],
        );
        await _db.customStatement(
          'INSERT INTO dependency_revisions (scope_id, revision) '
          'SELECT id, 1 FROM dependency_scopes WHERE kind = ? AND scope_key = ? '
          'AND NOT EXISTS (SELECT 1 FROM dependency_revisions '
          'WHERE scope_id = dependency_scopes.id)',
          ['account', accountId],
        );
      },
    );
  }
}
