// P12 (SPEC 9.3; DATABASE_DESIGN 4.1, 5): categories, rules and tags.
//
// Writes are prepared plans for the single command writer. Reads are typed
// lists for the editors (X21, X84) and the parsers.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/command_repository.dart';
import 'write_plan.dart';

/// One category (SPEC 9.3).
final class CategoryRow {
  const CategoryRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.parentId,
    required this.archived,
    required this.revision,
    this.isEssential,
  });

  final String id;
  final String name;
  final String kind;
  final String? parentId;
  final bool archived;
  final int revision;

  /// SPEC 4.4: the user's tag. Null is not tagged yet.
  final bool? isEssential;
}

/// One category rule (SPEC 9.3).
final class CategoryRuleRow {
  const CategoryRuleRow({
    required this.id,
    required this.matchType,
    required this.pattern,
    required this.categoryId,
    required this.priority,
    required this.createdFrom,
    required this.hitCount,
  });

  final String id;
  final String matchType;
  final String pattern;
  final String categoryId;
  final int priority;
  final String createdFrom;
  final int hitCount;
}

/// One tag.
final class TagRow {
  const TagRow({required this.id, required this.name});

  final String id;
  final String name;
}

/// SPEC 9.3 / X84: categories, rules and tags.
final class CategoryRepository {
  CategoryRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
  })  : _db = db,
        _clockUtc = clockUtc;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  /// Categories of one kind, by sort order then name.
  Future<List<CategoryRow>> list({
    required String kind,
    bool includeArchived = false,
  }) async {
    final rows = await _db.customSelect(
      'SELECT id, name, kind, parent_id, archived, revision, is_essential '
      'FROM categories '
      'WHERE kind = ? '
      '${includeArchived ? '' : 'AND archived = 0 '}'
      'ORDER BY sort_order, name',
      variables: [Variable(kind)],
    ).get();
    return <CategoryRow>[
      for (final row in rows)
        CategoryRow(
          id: row.data['id'] as String,
          name: row.data['name'] as String,
          kind: row.data['kind'] as String,
          parentId: row.data['parent_id'] as String?,
          archived: (row.data['archived'] as int) == 1,
          revision: row.data['revision'] as int,
          isEssential: switch (row.data['is_essential']) {
            1 => true,
            0 => false,
            _ => null,
          },
        ),
    ];
  }

  /// Rules by priority, highest first (SPEC 8.9).
  Future<List<CategoryRuleRow>> rules() async {
    final rows = await _db
        .customSelect(
          'SELECT id, match_type, pattern, category_id, priority, created_from, '
          'hit_count FROM category_rules WHERE deleted_at IS NULL '
          'ORDER BY priority DESC, id',
        )
        .get();
    return <CategoryRuleRow>[
      for (final row in rows)
        CategoryRuleRow(
          id: row.data['id'] as String,
          matchType: row.data['match_type'] as String,
          pattern: row.data['pattern'] as String,
          categoryId: row.data['category_id'] as String,
          priority: row.data['priority'] as int,
          createdFrom: row.data['created_from'] as String,
          hitCount: row.data['hit_count'] as int,
        ),
    ];
  }

  /// Tags by name.
  Future<List<TagRow>> tags() async {
    final rows = await _db
        .customSelect(
          'SELECT id, name FROM tags WHERE deleted_at IS NULL ORDER BY name',
        )
        .get();
    return <TagRow>[
      for (final row in rows)
        TagRow(id: row.data['id'] as String, name: row.data['name'] as String),
    ];
  }

  /// Creates a category (X21 "New category").
  WritePlan planCreateCategory({
    required String id,
    required String name,
    required String kind,
    String? parentId,
    int sortOrder = 0,
    bool? isEssential,
  }) {
    if (kind != 'expense' && kind != 'income') {
      throw ArgumentError.value(kind, 'kind', 'Must be expense or income');
    }
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{'name': name, 'kind': kind}),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'INSERT INTO categories (id, created_at, updated_at, deleted_at, '
          'revision, name, parent_id, kind, sort_order, archived, '
          'is_essential) '
          'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, 0, ?)',
          [
            id,
            now,
            now,
            name,
            parentId,
            kind,
            sortOrder,
            switch (isEssential) {
              true => 1,
              false => 0,
              null => null,
            },
          ],
        );
      },
    );
  }

  /// Renames a category (C03): one edit, one revision.
  WritePlan planRenameCategory({
    required String id,
    required String name,
    required int expectedRevision,
  }) {
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          fromRevision: expectedRevision,
          toRevision: expectedRevision + 1,
          changeKind: 'edit',
          beforeJson: '{"name":null}',
          afterJson: jsonEncode(<String, Object?>{'name': name}),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        final updated = await _db.customUpdate(
          'UPDATE categories SET name = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ? AND revision = ? '
          'AND deleted_at IS NULL',
          variables: [
            Variable(name),
            Variable(now),
            Variable(id),
            Variable(expectedRevision),
          ],
        );
        if (updated == 0) {
          throw StateError('Stale category revision');
        }
      },
    );
  }

  /// Tags a category as a need (true), a want (false), or not tagged (null).
  ///
  /// SPEC 4.4: the tag is the user's own label; the app adds no judgement.
  WritePlan planSetEssential({
    required String id,
    required bool? isEssential,
    required int expectedRevision,
  }) {
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          fromRevision: expectedRevision,
          toRevision: expectedRevision + 1,
          changeKind: 'edit',
          beforeJson: '{"isEssential":null}',
          afterJson: jsonEncode(<String, Object?>{
            'isEssential': isEssential,
          }),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'UPDATE categories SET is_essential = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ? AND revision = ?',
          [
            switch (isEssential) {
              true => 1,
              false => 0,
              null => null,
            },
            now,
            id,
            expectedRevision,
          ],
        );
      },
    );
  }

  /// Archives a category; history and payments keep the row (soft delete).
  WritePlan planArchiveCategory({
    required String id,
    required int expectedRevision,
  }) {
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          fromRevision: expectedRevision,
          toRevision: expectedRevision + 1,
          changeKind: 'softDelete',
          beforeJson: '{"archived":false}',
          afterJson: '{"archived":true}',
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'UPDATE categories SET archived = 1, deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ? AND revision = ?',
          [now, now, id, expectedRevision],
        );
      },
    );
  }

  /// Creates a rule (C03). A rule proposes; it never reclassifies by itself.
  WritePlan planCreateRule({
    required String id,
    required String matchType,
    required String pattern,
    required String categoryId,
    required String createdFrom,
    int priority = 0,
  }) {
    const matchTypes = <String>{
      'merchantEquals',
      'merchantContains',
      'regex',
      'amountRange',
    };
    if (!matchTypes.contains(matchType)) {
      throw ArgumentError.value(matchType, 'matchType', 'Unknown match type');
    }
    if (createdFrom != 'user' &&
        createdFrom != 'learned' &&
        createdFrom != 'default') {
      throw ArgumentError.value(createdFrom, 'createdFrom', 'Unknown origin');
    }
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{
            'matchType': matchType,
            'categoryId': categoryId,
          }),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'INSERT INTO category_rules (id, created_at, updated_at, '
          'deleted_at, revision, match_type, pattern, category_id, priority, '
          'created_from, hit_count) '
          'VALUES (?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, 0)',
          [
            id,
            now,
            now,
            matchType,
            pattern,
            categoryId,
            priority,
            createdFrom,
          ],
        );
      },
    );
  }

  /// Creates a tag. A live tag name is unique.
  WritePlan planCreateTag({required String id, required String name}) {
    final now = _nowMs();
    return WritePlan(
      changes: <ChangeLogEntry>[
        ChangeLogEntry(
          entityId: id,
          toRevision: 1,
          changeKind: 'create',
          afterJson: jsonEncode(<String, Object?>{'name': name}),
          schemaVersion: 1,
        ),
      ],
      apply: () async {
        await _db.customStatement(
          'INSERT INTO tags (id, created_at, updated_at, deleted_at, '
          'revision, name) VALUES (?, ?, ?, NULL, 1, ?)',
          [id, now, now, name],
        );
      },
    );
  }
}
