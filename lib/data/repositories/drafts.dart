// P01 / SPEC 8.16: the editable draft store.
//
// A draft keeps the structured fields of one form between visits. It is
// written at field commit, resumed without overwriting another draft, and
// removed by Discard or by the confirmed Save. The payload is bounded by the
// database (256 KiB) and stays in the encrypted vault.
//
// Log privacy (AGENTS 2.6): this file never logs or prints a payload value;
// errors carry a safe code only.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// SPEC 8.16 / SCHEMA.sql: the status of a draft header.
enum DraftStatus { editing, submitted, committed, discarded, unsupported }

/// SPEC 8.16: a record the draft refers to, with its expected revision.
final class DraftReference {
  const DraftReference({
    required this.entityId,
    required this.expectedRevision,
  });

  /// The referenced authored record.
  final String entityId;

  /// Its revision when the draft was written.
  final int expectedRevision;
}

/// SPEC 8.16: one stored draft.
final class DraftRecord {
  const DraftRecord({
    required this.id,
    required this.formType,
    required this.schemaVersion,
    required this.dbEpoch,
    required this.editRevision,
    required this.status,
    required this.payloadJson,
    required this.committedOperationId,
    required this.updatedAtMs,
  });

  /// The draft identity.
  final String id;

  /// The editor that owns the draft (for example `payment`).
  final String formType;

  /// The payload schema version of the form.
  final int schemaVersion;

  /// The database epoch the draft was written in.
  final String dbEpoch;

  /// Increments on every save of the same draft.
  final int editRevision;

  /// The lifecycle state.
  final DraftStatus status;

  /// The structured fields, or null after commit or discard.
  final String? payloadJson;

  /// The operation that committed this draft, when committed.
  final String? committedOperationId;

  /// The last save time, in milliseconds since the epoch.
  final int updatedAtMs;
}

/// Safe draft failure codes (no draft value in an error).
enum DraftErrorCode { notFound, invalidState, payloadTooLarge, epochMismatch }

/// A typed draft failure. It holds a code only (AGENTS 2.6, P01).
class DraftError implements Exception {
  const DraftError(this.code);

  final DraftErrorCode code;

  @override
  String toString() => 'DraftError(${code.name})';
}

/// SPEC 8.16: saves, resumes, discards and retires editable drafts.
final class DraftRepository {
  DraftRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
  })  : _db = db,
        _clockUtc = clockUtc;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;

  /// SPEC 8.16: the schema bound of one payload (SCHEMA.sql).
  static const int maxPayloadBytes = 262144;

  int _nowMs() => _clockUtc().millisecondsSinceEpoch;

  /// Writes a draft at field commit and returns the stored record.
  ///
  /// A new draft starts at revision 1. Saving the same draft increments its
  /// revision. A submitted, committed, discarded, unsupported or
  /// old-generation draft cannot be edited.
  Future<DraftRecord> save({
    required String id,
    required String formType,
    required int schemaVersion,
    required String payloadJson,
    List<DraftReference> references = const <DraftReference>[],
  }) async {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion', 'Must be 1+');
    }
    if (utf8.encode(payloadJson).length > maxPayloadBytes) {
      throw const DraftError(DraftErrorCode.payloadTooLarge);
    }
    final epoch = await _currentEpoch();
    final now = _nowMs();
    await _db.transaction(() async {
      final existing = await _row(id);
      if (existing == null) {
        await _db.customStatement(
          'INSERT INTO draft_headers (id, form_type, schema_version, db_epoch, '
          'created_at, updated_at, edit_revision, status) '
          'VALUES (?, ?, ?, ?, ?, ?, 1, ?)',
          [id, formType, schemaVersion, epoch, now, now, 'editing'],
        );
      } else {
        if (existing.status != DraftStatus.editing) {
          throw const DraftError(DraftErrorCode.invalidState);
        }
        if (existing.dbEpoch != epoch) {
          throw const DraftError(DraftErrorCode.epochMismatch);
        }
        await _db.customStatement(
          'UPDATE draft_headers SET schema_version = ?, updated_at = ?, '
          'edit_revision = edit_revision + 1 WHERE id = ?',
          [schemaVersion, now, id],
        );
      }
      await _db.customStatement(
        'DELETE FROM draft_payloads WHERE draft_id = ?',
        [id],
      );
      await _db.customStatement(
        'INSERT INTO draft_payloads (draft_id, payload_json) VALUES (?, ?)',
        [id, payloadJson],
      );
      await _db.customStatement(
        'DELETE FROM draft_references WHERE draft_id = ?',
        [id],
      );
      for (final reference in references) {
        await _db.customStatement(
          'INSERT INTO draft_references (draft_id, entity_id, '
          'expected_revision) VALUES (?, ?, ?)',
          [id, reference.entityId, reference.expectedRevision],
        );
      }
    });
    final stored = await byId(id);
    if (stored == null) {
      throw const DraftError(DraftErrorCode.notFound);
    }
    return stored;
  }

  /// The stored draft, or null when no such id exists.
  Future<DraftRecord?> byId(String id) async {
    final row = await _row(id);
    if (row == null) {
      return null;
    }
    final payload = await _db.customSelect(
      'SELECT payload_json FROM draft_payloads WHERE draft_id = ?',
      variables: [Variable(id)],
    ).getSingleOrNull();
    return DraftRecord(
      id: row.id,
      formType: row.formType,
      schemaVersion: row.schemaVersion,
      dbEpoch: row.dbEpoch,
      editRevision: row.editRevision,
      status: row.status,
      payloadJson: payload?.data['payload_json'] as String?,
      committedOperationId: row.committedOperationId,
      updatedAtMs: row.updatedAtMs,
    );
  }

  /// Editing drafts of [formType] in the current database generation, newest
  /// first. Drafts of an older generation are not offered (SPEC 8.16).
  Future<List<DraftRecord>> list({required String formType}) async {
    final epoch = await _currentEpoch();
    final rows = await _db.customSelect(
      'SELECT id, form_type, schema_version, db_epoch, edit_revision, status, '
      'committed_operation_id, updated_at FROM draft_headers '
      'WHERE form_type = ? AND status = ? AND db_epoch = ? '
      'ORDER BY updated_at DESC, id DESC',
      variables: [
        Variable(formType),
        const Variable('editing'),
        Variable(epoch),
      ],
    ).get();
    return <DraftRecord>[
      for (final row in rows) await _recordFromRow(row),
    ];
  }

  /// The most recent editing draft of [formType], or null.
  Future<DraftRecord?> find({required String formType}) async {
    final drafts = await list(formType: formType);
    return drafts.isEmpty ? null : drafts.first;
  }

  /// Deletes the payload and references and marks the draft discarded.
  ///
  /// An editing or unsupported draft can be discarded (SPEC 8.16). A
  /// submitted draft must resolve its operation first; a committed draft is
  /// history and is never discarded here.
  Future<void> discard(String id) async {
    final row = await _row(id);
    if (row == null) {
      throw const DraftError(DraftErrorCode.notFound);
    }
    if (row.status != DraftStatus.editing &&
        row.status != DraftStatus.unsupported) {
      throw const DraftError(DraftErrorCode.invalidState);
    }
    final now = _nowMs();
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM draft_payloads WHERE draft_id = ?',
        [id],
      );
      await _db.customStatement(
        'DELETE FROM draft_references WHERE draft_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE draft_headers SET status = ?, updated_at = ? WHERE id = ?',
        ['discarded', now, id],
      );
    });
  }

  /// Keeps the payload and shows the unsupported state (SPEC 8.16,
  /// DATABASE_DESIGN 10). Used when the form cannot read an old payload.
  Future<DraftRecord> markUnsupported(String id) async {
    final row = await _row(id);
    if (row == null) {
      throw const DraftError(DraftErrorCode.notFound);
    }
    if (row.status != DraftStatus.editing) {
      throw const DraftError(DraftErrorCode.invalidState);
    }
    await _db.customStatement(
      'UPDATE draft_headers SET status = ?, updated_at = ? WHERE id = ?',
      ['unsupported', _nowMs(), id],
    );
    final stored = await byId(id);
    if (stored == null) {
      throw const DraftError(DraftErrorCode.notFound);
    }
    return stored;
  }

  Future<String> _currentEpoch() async {
    final row = await _db
        .customSelect('SELECT db_epoch FROM db_state WHERE singleton = 1')
        .getSingle();
    return row.data['db_epoch'] as String;
  }

  Future<_DraftRow?> _row(String id) async {
    final row = await _db.customSelect(
      'SELECT id, form_type, schema_version, db_epoch, edit_revision, status, '
      'committed_operation_id, updated_at FROM draft_headers WHERE id = ?',
      variables: [Variable(id)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _DraftRow(
      id: row.data['id'] as String,
      formType: row.data['form_type'] as String,
      schemaVersion: row.data['schema_version'] as int,
      dbEpoch: row.data['db_epoch'] as String,
      editRevision: row.data['edit_revision'] as int,
      status: _statusOf(row.data['status'] as String),
      committedOperationId: row.data['committed_operation_id'] as String?,
      updatedAtMs: row.data['updated_at'] as int,
    );
  }

  Future<DraftRecord> _recordFromRow(QueryRow row) async {
    final id = row.data['id'] as String;
    final payload = await _db.customSelect(
      'SELECT payload_json FROM draft_payloads WHERE draft_id = ?',
      variables: [Variable(id)],
    ).getSingleOrNull();
    return DraftRecord(
      id: id,
      formType: row.data['form_type'] as String,
      schemaVersion: row.data['schema_version'] as int,
      dbEpoch: row.data['db_epoch'] as String,
      editRevision: row.data['edit_revision'] as int,
      status: _statusOf(row.data['status'] as String),
      payloadJson: payload?.data['payload_json'] as String?,
      committedOperationId: row.data['committed_operation_id'] as String?,
      updatedAtMs: row.data['updated_at'] as int,
    );
  }

  DraftStatus _statusOf(String value) => DraftStatus.values.byName(value);
}

final class _DraftRow {
  const _DraftRow({
    required this.id,
    required this.formType,
    required this.schemaVersion,
    required this.dbEpoch,
    required this.editRevision,
    required this.status,
    required this.committedOperationId,
    required this.updatedAtMs,
  });

  final String id;
  final String formType;
  final int schemaVersion;
  final String dbEpoch;
  final int editRevision;
  final DraftStatus status;
  final String? committedOperationId;
  final int updatedAtMs;
}
