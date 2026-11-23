// P27 (SCREENS X36–X39; flow F08 steps 3–4): payment list and detail reads.
//
// Reads only. The list is filtered by the applied X38 filter; the detail joins
// the account, category, splits and tags for X39. Money stays integer minor
// units (SPEC 4.1). No formatting and no logs (AGENTS 2.6).

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// The X38 "Show" choice.
enum PaymentShow { moneyOut, moneyIn, transfers, noCategory }

/// One applied payment filter (X38). The list reads this, never a draft.
final class PaymentQuery {
  const PaymentQuery({
    required this.from,
    required this.to,
    this.show = PaymentShow.moneyOut,
    this.accountId,
    this.categoryId,
    this.limit = 200,
  });

  /// Inclusive local dates.
  final String from;
  final String to;
  final PaymentShow show;
  final String? accountId;
  final String? categoryId;
  final int limit;
}

/// One row of the X37 list.
final class PaymentListRow {
  const PaymentListRow({
    required this.id,
    required this.date,
    required this.amountMinor,
    required this.currency,
    required this.kind,
    required this.revision,
    required this.merchantName,
    required this.categoryId,
    required this.categoryName,
    required this.accountName,
  });

  final String id;
  final String date;
  final int amountMinor;
  final String currency;
  final String kind;
  final int revision;
  final String? merchantName;
  final String? categoryId;
  final String? categoryName;
  final String accountName;
}

/// One split of a payment (X39).
final class PaymentSplitRow {
  const PaymentSplitRow({
    required this.categoryId,
    required this.categoryName,
    required this.amountMinor,
  });

  final String categoryId;
  final String? categoryName;
  final int amountMinor;
}

/// The full X39 payment.
final class PaymentDetailRow {
  const PaymentDetailRow({
    required this.id,
    required this.date,
    required this.amountMinor,
    required this.currency,
    required this.kind,
    required this.revision,
    required this.merchantName,
    required this.note,
    required this.accountId,
    required this.accountName,
    required this.categoryId,
    required this.categoryName,
    required this.splits,
    required this.tags,
  });

  final String id;
  final String date;
  final int amountMinor;
  final String currency;
  final String kind;
  final int revision;
  final String? merchantName;
  final String? note;
  final String accountId;
  final String accountName;
  final String? categoryId;
  final String? categoryName;
  final List<PaymentSplitRow> splits;
  final List<String> tags;
}

/// Payment list and detail reads.
final class PaymentReadRepository {
  PaymentReadRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// The list of X37, newest first, with the applied filter.
  Future<List<PaymentListRow>> list(PaymentQuery query) async {
    final where = _where(query);
    final rows = await _db.customSelect(
      'SELECT t.id, t.date, t.amount_minor, t.currency, t.kind, '
      't.merchant_name, t.category_id, t.revision, '
      'a.name AS account_name, c.name AS category_name '
      'FROM transactions t '
      'JOIN accounts a ON a.id = t.account_id '
      'LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE t.deleted_at IS NULL AND $where '
      'ORDER BY t.date DESC, t.id DESC LIMIT ?',
      variables: <Variable<Object>>[
        ..._variables(query),
        Variable(query.limit),
      ],
    ).get();
    return <PaymentListRow>[
      for (final row in rows)
        PaymentListRow(
          id: row.data['id'] as String,
          date: row.data['date'] as String,
          amountMinor: row.data['amount_minor'] as int,
          currency: row.data['currency'] as String,
          kind: row.data['kind'] as String,
          revision: row.data['revision'] as int,
          merchantName: row.data['merchant_name'] as String?,
          categoryId: row.data['category_id'] as String?,
          categoryName: row.data['category_name'] as String?,
          accountName: row.data['account_name'] as String,
        ),
    ];
  }

  /// The exact row count of the applied filter (X38 "Show N payments").
  Future<int> count(PaymentQuery query) async {
    final row = await _db
        .customSelect(
          'SELECT count(*) AS n FROM transactions t '
          'WHERE t.deleted_at IS NULL AND ${_where(query)}',
          variables: _variables(query),
        )
        .getSingle();
    return row.data['n'] as int;
  }

  /// The full payment for X39, or null when it is absent or deleted.
  Future<PaymentDetailRow?> detail(String id) async {
    final row = await _db.customSelect(
      'SELECT t.id, t.date, t.amount_minor, t.currency, t.kind, t.revision, '
      't.merchant_name, t.note, t.account_id, t.category_id, '
      'a.name AS account_name, c.name AS category_name '
      'FROM transactions t '
      'JOIN accounts a ON a.id = t.account_id '
      'LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE t.id = ? AND t.deleted_at IS NULL',
      variables: <Variable<Object>>[Variable(id)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    final splits = await _db.customSelect(
      'SELECT s.category_id, s.amount_minor, c.name AS category_name '
      'FROM transaction_splits s '
      'LEFT JOIN categories c ON c.id = s.category_id '
      'WHERE s.transaction_id = ? AND s.deleted_at IS NULL '
      'ORDER BY s.amount_minor DESC',
      variables: <Variable<Object>>[Variable(id)],
    ).get();
    final tags = await _db.customSelect(
      'SELECT g.name FROM transaction_tags tt '
      'JOIN tags g ON g.id = tt.tag_id '
      'WHERE tt.transaction_id = ? AND g.deleted_at IS NULL ORDER BY g.name',
      variables: <Variable<Object>>[Variable(id)],
    ).get();
    return PaymentDetailRow(
      id: row.data['id'] as String,
      date: row.data['date'] as String,
      amountMinor: row.data['amount_minor'] as int,
      currency: row.data['currency'] as String,
      kind: row.data['kind'] as String,
      revision: row.data['revision'] as int,
      merchantName: row.data['merchant_name'] as String?,
      note: row.data['note'] as String?,
      accountId: row.data['account_id'] as String,
      accountName: row.data['account_name'] as String,
      categoryId: row.data['category_id'] as String?,
      categoryName: row.data['category_name'] as String?,
      splits: <PaymentSplitRow>[
        for (final split in splits)
          PaymentSplitRow(
            categoryId: split.data['category_id'] as String,
            categoryName: split.data['category_name'] as String?,
            amountMinor: split.data['amount_minor'] as int,
          ),
      ],
      tags: <String>[for (final tag in tags) tag.data['name'] as String],
    );
  }

  String _where(PaymentQuery query) {
    final conditions = <String>['t.date >= ?', 't.date <= ?'];
    switch (query.show) {
      case PaymentShow.moneyOut:
        conditions.add("t.kind IN ('expense', 'fee')");
      case PaymentShow.moneyIn:
        conditions.add("t.kind = 'income'");
      case PaymentShow.transfers:
        conditions.add("t.kind = 'transfer'");
      case PaymentShow.noCategory:
        conditions.add('t.category_id IS NULL');
    }
    if (query.accountId != null) {
      conditions.add('t.account_id = ?');
    }
    if (query.categoryId != null) {
      conditions.add('t.category_id = ?');
    }
    return conditions.join(' AND ');
  }

  List<Variable<Object>> _variables(PaymentQuery query) => <Variable<Object>>[
        Variable(query.from),
        Variable(query.to),
        if (query.accountId != null) Variable(query.accountId!),
        if (query.categoryId != null) Variable(query.categoryId!),
      ];
}
