// P27 (SCREEN X36; flow F08 step 2; SPEC 4.4): category reads.
//
// Monthly totals and merchant totals for one category. A split payment counts
// through its split rows; an unsplit payment counts once through its own row
// (DATABASE_DESIGN 7). Refunds reduce the category net because their posting is
// positive on the account (SPEC 4.11).

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// One month of a category (X36 "Each month").
final class CategoryMonthRow {
  const CategoryMonthRow({required this.month, required this.amountMinor});

  /// `YYYY-MM`.
  final String month;

  /// The net money out; negative means refunds exceed spending.
  final int amountMinor;
}

/// One merchant inside a category (X36 "Where").
final class MerchantTotalRow {
  const MerchantTotalRow({
    required this.merchantName,
    required this.amountMinor,
  });

  final String? merchantName;
  final int amountMinor;
}

/// Category monthly and merchant reads.
final class CategoryReadRepository {
  CategoryReadRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// One category name, or an empty string when the row is absent.
  Future<String> name(String id) async {
    final row = await _db.customSelect(
      'SELECT name FROM categories WHERE id = ? AND deleted_at IS NULL',
      variables: <Variable<Object>>[Variable(id)],
    ).getSingleOrNull();
    return (row?.data['name'] as String?) ?? '';
  }

  /// The monthly net of one category between [from] and [to], oldest first.
  Future<List<CategoryMonthRow>> months({
    required String categoryId,
    required String from,
    required String to,
  }) async {
    final rows = await _db.customSelect(
      'SELECT month, SUM(amount_minor) AS total FROM ('
      'SELECT substr(t.date, 1, 7) AS month, s.amount_minor AS amount_minor '
      'FROM transaction_splits s JOIN transactions t ON t.id = s.transaction_id '
      'WHERE s.deleted_at IS NULL AND t.deleted_at IS NULL '
      'AND s.category_id = ? AND t.date >= ? AND t.date <= ? '
      'UNION ALL '
      'SELECT substr(t.date, 1, 7), t.amount_minor FROM transactions t '
      'WHERE t.deleted_at IS NULL AND t.category_id = ? '
      'AND t.date >= ? AND t.date <= ? '
      'AND NOT EXISTS (SELECT 1 FROM transaction_splits s2 '
      'WHERE s2.transaction_id = t.id AND s2.deleted_at IS NULL)'
      ') GROUP BY month ORDER BY month',
      variables: <Variable<Object>>[
        Variable(categoryId),
        Variable(from),
        Variable(to),
        Variable(categoryId),
        Variable(from),
        Variable(to),
      ],
    ).get();
    return <CategoryMonthRow>[
      for (final row in rows)
        CategoryMonthRow(
          month: row.data['month'] as String,
          amountMinor: row.data['total'] as int,
        ),
    ];
  }

  /// The merchants of one category, largest first.
  Future<List<MerchantTotalRow>> merchants({
    required String categoryId,
    required String from,
    required String to,
  }) async {
    final rows = await _db.customSelect(
      'SELECT merchant_name, SUM(amount_minor) AS total FROM ('
      'SELECT t.merchant_name AS merchant_name, s.amount_minor AS amount_minor '
      'FROM transaction_splits s JOIN transactions t ON t.id = s.transaction_id '
      'WHERE s.deleted_at IS NULL AND t.deleted_at IS NULL '
      'AND s.category_id = ? AND t.date >= ? AND t.date <= ? '
      'UNION ALL '
      'SELECT t.merchant_name, t.amount_minor FROM transactions t '
      'WHERE t.deleted_at IS NULL AND t.category_id = ? '
      'AND t.date >= ? AND t.date <= ? '
      'AND NOT EXISTS (SELECT 1 FROM transaction_splits s2 '
      'WHERE s2.transaction_id = t.id AND s2.deleted_at IS NULL)'
      ') GROUP BY merchant_name ORDER BY total ASC',
      variables: <Variable<Object>>[
        Variable(categoryId),
        Variable(from),
        Variable(to),
        Variable(categoryId),
        Variable(from),
        Variable(to),
      ],
    ).get();
    return <MerchantTotalRow>[
      for (final row in rows)
        MerchantTotalRow(
          merchantName: row.data['merchant_name'] as String?,
          amountMinor: row.data['total'] as int,
        ),
    ];
  }
}
