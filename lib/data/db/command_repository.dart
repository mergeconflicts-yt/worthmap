// T07 (DATABASE_DESIGN 6, SYSTEM_DESIGN 6): the command protocol machinery.
//
// An intent is a durable request; a receipt proves a committed result. The
// protocol implemented here:
//   prepare — persist the draft, the canonical payload with digest and the
//     `submitted` intent BEFORE the writer runs (one transaction).
//   execute — receipt first (an identical retry returns the recorded result;
//     a reused id with different input fails), then one write transaction:
//     recheck intent state, run the caller's effects, write ChangeLog rows,
//     advance the commit sequence and the read revision once, write the
//     receipt, seal the draft. The read store is notified only after commit.
//
// Concrete financial commands stay gated (G01, FIN-3); this is the storage
// protocol they will call. Effects receive no connection and cannot commit
// anything outside the caller's transaction.
//
// Log privacy (AGENTS 2.6): errors carry safe codes only.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/ids.dart';
import 'app_database.dart';
import 'read_revision.dart';

/// One ChangeLog row (DATABASE_DESIGN: `change_log` columns). [ordinal] is
/// assigned by the writer per operation.
final class ChangeLogEntry {
  const ChangeLogEntry({
    required this.entityId,
    required this.toRevision,
    required this.changeKind,
    required this.afterJson,
    required this.schemaVersion,
    this.fromRevision,
    this.beforeJson,
  });

  final String entityId;
  final int? fromRevision;
  final int toRevision;

  /// create | edit | softDelete | restore | compensate (database CHECK).
  final String changeKind;
  final String? beforeJson;
  final String afterJson;
  final int schemaVersion;
}

/// Safe command failure codes.
enum CommandErrorCode {
  unknownOperation,
  draftNotFound,
  invalidState,
  digestMismatch,
  executionFailed,
}

class CommandError implements Exception {
  const CommandError(this.code);

  final CommandErrorCode code;

  @override
  String toString() => 'CommandError(${code.name})';
}

/// The outcome of a committed command.
final class CommandOutcome {
  const CommandOutcome({
    required this.operationId,
    required this.commitSequence,
    required this.readRevision,
    required this.resultJson,
  });

  final String operationId;
  final int commitSequence;
  final int readRevision;
  final String resultJson;
}

/// The command protocol repository. One instance per vault; all confirmed
/// mutations go through it (AGENTS 11: the single command writer).
final class CommandRepository {
  CommandRepository({
    required AppDatabase db,
    required this.clockUtc,
    String Function()? newOperationId,
  })  : _db = db,
        _newOperationId = newOperationId;

  final AppDatabase _db;

  /// Allocates an operation id for a Save that has no active attempt.
  /// Tests inject a deterministic sequence (DATABASE_DESIGN 6).
  final String Function()? _newOperationId;

  /// Injected clock for `submitted_at` / `committed_at` / timestamps
  /// (AGENTS 6.3: no DateTime.now() in functions).
  final DateTime Function() clockUtc;

  final StreamController<int> _published = StreamController<int>.broadcast();

  /// Fires after each commit with the new read revision (SYSTEM_DESIGN 8.3:
  /// notify the central read store once, after commit).
  Stream<int> get published => _published.stream;

  int _nowMs() => clockUtc().millisecondsSinceEpoch;

  /// SHA-256 of the canonical payload bytes (DATABASE_DESIGN 6: the digest is
  /// frozen before submission; the payload is JSON text, no raw source bytes).
  static List<int> digestOf(String payloadJson) {
    return sha256.convert(utf8.encode(payloadJson)).bytes;
  }

  /// Persists the draft, the canonical payload and the submitted intent.
  /// `payloadJson` must already be the canonical encoding (versioned codec);
  /// its SHA-256 becomes the intent digest.
  Future<void> prepare({
    required String operationId,
    required String commandType,
    required String draftId,
    required String formType,
    required String payloadJson,
    required int payloadVersion,
    required int codecVersion,
    required int schemaVersion,
  }) async {
    final digest = digestOf(payloadJson);
    final now = _nowMs();
    final dbEpoch = await _currentEpoch();
    await _db.transaction(() async {
      // One unresolved attempt per draft (DATABASE_DESIGN 6): a retry with
      // the same identity and payload is a no-op; a different identity or
      // payload fails instead of creating a second intent.
      final active = await _activeIntent(draftId);
      if (active != null) {
        if (active.operationId != operationId) {
          throw const CommandError(CommandErrorCode.invalidState);
        }
        if (!_digestEquals(active.digest, digest)) {
          throw const CommandError(CommandErrorCode.digestMismatch);
        }
        return;
      }

      final draft = await _db.customSelect(
        'SELECT status, db_epoch FROM draft_headers WHERE id = ?',
        variables: [Variable(draftId)],
      ).getSingleOrNull();
      if (draft == null) {
        await _db.customStatement(
          'INSERT INTO draft_headers (id, form_type, schema_version, db_epoch, '
          'created_at, updated_at, edit_revision, status) '
          'VALUES (?, ?, ?, ?, ?, ?, 1, ?)',
          [draftId, formType, schemaVersion, dbEpoch, now, now, 'editing'],
        );
      } else {
        if (draft.data['status'] != 'editing' ||
            draft.data['db_epoch'] != dbEpoch) {
          throw const CommandError(CommandErrorCode.invalidState);
        }
        await _db.customStatement(
          'UPDATE draft_headers SET status = ?, schema_version = ?, '
          'updated_at = ? WHERE id = ?',
          ['submitted', schemaVersion, now, draftId],
        );
      }

      await _db.customStatement(
        'INSERT INTO operation_intents (operation_id, command_type, '
        'payload_digest, payload_version, draft_id, submitted_at, state, '
        'state_version) VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
        [
          operationId,
          commandType,
          digest,
          payloadVersion,
          draftId,
          now,
          'submitted',
        ],
      );
      await _db.customStatement(
        'INSERT INTO operation_payloads (operation_id, codec_version, '
        'chunk_count, total_bytes, manifest_digest) VALUES (?, ?, 1, ?, ?)',
        [
          operationId,
          codecVersion,
          utf8.encode(payloadJson).length,
          digest,
        ],
      );
      await _db.customStatement(
        'INSERT INTO operation_payload_chunks (operation_id, chunk_index, '
        'payload_json, content_digest) VALUES (?, 0, ?, ?)',
        [operationId, payloadJson, digest],
      );
    });
  }

  /// Executes a prepared command. Receipt-first: a committed id returns its
  /// recorded outcome; an unknown id fails; a cancelled/rejected id fails.
  /// [effects] runs inside the single write transaction and must use the
  /// caller's [AppDatabase] (drift keeps the transaction on the connection).
  Future<CommandOutcome> execute({
    required String operationId,
    required List<ChangeLogEntry> changes,
    required FutureOr<void> Function() effects,
    required String resultJson,
  }) async {
    // Receipt first (DATABASE_DESIGN 6 step 2), outside the write
    // transaction.
    final existing = await _readReceipt(operationId);
    if (existing != null) {
      return existing;
    }
    await _checkIntentIsSubmitted(operationId);

    final committed = await _db.transaction(() async {
      // Recheck under the writer: still submitted?
      final state = await _db.customSelect(
        'SELECT state, payload_digest FROM operation_intents '
        'WHERE operation_id = ?',
        variables: [Variable(operationId)],
      ).getSingle();
      if (state.data['state'] != 'submitted') {
        throw const CommandError(CommandErrorCode.invalidState);
      }

      // Verify the stored payload against the frozen digest before running
      // effects (integrity of durable input).
      final chunk = await _db.customSelect(
        'SELECT payload_json, content_digest FROM operation_payload_chunks '
        'WHERE operation_id = ? AND chunk_index = 0',
        variables: [Variable(operationId)],
      ).getSingle();
      final payload = chunk.data['payload_json'] as String;
      final digest = chunk.data['content_digest'] as List<int>;
      final actual = digestOf(payload);
      if (!_digestEquals(digest, actual)) {
        throw const CommandError(CommandErrorCode.digestMismatch);
      }

      await _db.customStatement(
        'UPDATE operation_intents SET state = ?, state_version = '
        'state_version + 1 WHERE operation_id = ?',
        ['running', operationId],
      );

      // Caller effects write their authored rows now.
      await effects();

      // ChangeLog rows. `from_revision`/`to_revision` must be contiguous
      // (database CHECK); the entity registry FK proves existence.
      const ordinalBase = 0;
      for (final (index, entry) in changes.indexed) {
        await _db.customStatement(
          'INSERT INTO change_log (operation_id, ordinal, entity_id, '
          'from_revision, to_revision, change_kind, before_json, after_json, '
          'schema_version, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            operationId,
            ordinalBase + index,
            entry.entityId,
            entry.fromRevision,
            entry.toRevision,
            entry.changeKind,
            entry.beforeJson,
            entry.afterJson,
            entry.schemaVersion,
            _nowMs(),
          ],
        );
      }

      // One commit sequence and one read revision per confirmed command
      // (SHARED_STATE 3).
      final commitSequence = await advanceCommitSequence(_db);
      final readRevision = await advanceReadRevision(_db);

      await _db.customStatement(
        'INSERT INTO operation_receipts (operation_id, commit_sequence, '
        'committed_at, result_version, result_json) VALUES (?, ?, ?, 1, ?)',
        [operationId, commitSequence, _nowMs(), resultJson],
      );

      await _db.customStatement(
        'UPDATE operation_intents SET state = ?, state_version = '
        'state_version + 1 WHERE operation_id = ?',
        ['committed', operationId],
      );
      // SPEC 8.16: the confirmed Save clears the draft payload and its
      // references in the same transaction.
      final draftRow = await _db.customSelect(
        'SELECT draft_id FROM operation_intents WHERE operation_id = ?',
        variables: [Variable(operationId)],
      ).getSingle();
      final draftId = draftRow.data['draft_id'] as String?;
      if (draftId != null) {
        await _db.customStatement(
          'DELETE FROM draft_payloads WHERE draft_id = ?',
          [draftId],
        );
        await _db.customStatement(
          'DELETE FROM draft_references WHERE draft_id = ?',
          [draftId],
        );
      }

      await _db.customStatement(
        'UPDATE draft_headers SET status = ?, committed_operation_id = ?, '
        'updated_at = ? WHERE id = (SELECT draft_id FROM operation_intents '
        'WHERE operation_id = ?)',
        ['committed', operationId, _nowMs(), operationId],
      );

      return CommandOutcome(
        operationId: operationId,
        commitSequence: commitSequence,
        readRevision: readRevision,
        resultJson: resultJson,
      );
    });

    // Notify the read store once, after commit (SYSTEM_DESIGN 8.3).
    _published.add(committed.readRevision);
    return committed;
  }

  /// Marks a submitted intent cancelled before the writer admits it. An
  /// already-committed command cannot be cancelled.
  Future<void> cancel(String operationId) async {
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE operation_intents SET state = ?, state_version = '
        'state_version + 1 WHERE operation_id = ? AND state = ? AND '
        '(SELECT count(*) FROM operation_intents WHERE operation_id = ?) = 1',
        ['cancelled', operationId, 'submitted', operationId],
      );
      final updated = await _db.customSelect(
        'SELECT state FROM operation_intents WHERE operation_id = ?',
        variables: [Variable(operationId)],
      ).getSingle();
      if (updated.data['state'] != 'cancelled') {
        throw const CommandError(CommandErrorCode.invalidState);
      }
    });
  }

  /// SPEC 8.16 / DATABASE_DESIGN 6: the manual Save of an existing draft.
  ///
  /// One attempt per draft. A committed draft returns its recorded receipt
  /// (a repeated tap); a crash after prepare resumes the same intent; a
  /// changed payload with an active intent fails with `digestMismatch`.
  Future<CommandOutcome> saveDraft({
    required String draftId,
    required String commandType,
    required String payloadJson,
    required int payloadVersion,
    required int codecVersion,
    required List<ChangeLogEntry> changes,
    required FutureOr<void> Function() effects,
    required String resultJson,
  }) async {
    final draft = await _db.customSelect(
      'SELECT form_type, schema_version, status, committed_operation_id '
      'FROM draft_headers WHERE id = ?',
      variables: [Variable(draftId)],
    ).getSingleOrNull();
    if (draft == null) {
      throw const CommandError(CommandErrorCode.draftNotFound);
    }
    final status = draft.data['status'] as String;
    final committed = draft.data['committed_operation_id'] as String?;
    if (committed != null) {
      final receipt = await _readReceipt(committed);
      if (receipt == null) {
        throw const CommandError(CommandErrorCode.invalidState);
      }
      return receipt;
    }
    if (status != 'editing' && status != 'submitted') {
      throw const CommandError(CommandErrorCode.invalidState);
    }

    final active = await _activeIntent(draftId);
    if (active == null) {
      await prepare(
        operationId: _nextOperationId(),
        commandType: commandType,
        draftId: draftId,
        formType: draft.data['form_type'] as String,
        payloadJson: payloadJson,
        payloadVersion: payloadVersion,
        codecVersion: codecVersion,
        schemaVersion: draft.data['schema_version'] as int,
      );
    } else if (!_digestEquals(active.digest, digestOf(payloadJson))) {
      throw const CommandError(CommandErrorCode.digestMismatch);
    }

    final operation = await _activeIntent(draftId);
    if (operation == null) {
      throw const CommandError(CommandErrorCode.invalidState);
    }
    return execute(
      operationId: operation.operationId,
      changes: changes,
      effects: effects,
      resultJson: resultJson,
    );
  }

  /// DATABASE_DESIGN 6 / SPEC 8.16: after a proven uncommitted failure, the
  /// attempt becomes rejected and the draft returns to editing, so the next
  /// Save allocates a new operation id. A committed attempt is never released.
  Future<void> releaseUncommitted(String operationId) async {
    await _db.transaction(() async {
      final receipt = await _readReceipt(operationId);
      if (receipt != null) {
        throw const CommandError(CommandErrorCode.invalidState);
      }
      final intent = await _db.customSelect(
        'SELECT draft_id, state FROM operation_intents WHERE operation_id = ?',
        variables: [Variable(operationId)],
      ).getSingleOrNull();
      if (intent == null) {
        throw const CommandError(CommandErrorCode.unknownOperation);
      }
      if (intent.data['state'] == 'committed') {
        throw const CommandError(CommandErrorCode.invalidState);
      }
      await _db.customStatement(
        'UPDATE operation_intents SET state = ?, state_version = '
        'state_version + 1 WHERE operation_id = ?',
        ['rejected', operationId],
      );
      final draftId = intent.data['draft_id'] as String?;
      if (draftId != null) {
        await _db.customStatement(
          'UPDATE draft_headers SET status = ?, updated_at = ? '
          'WHERE id = ? AND status = ?',
          ['editing', _nowMs(), draftId, 'submitted'],
        );
      }
    });
  }

  /// The recorded receipt for an operation, or null when none exists.
  /// Receipt-first retry and lost-response recovery both resolve through
  /// this query (DATABASE_DESIGN 6).
  Future<CommandOutcome?> receiptOf(String operationId) =>
      _readReceipt(operationId);

  /// The unresolved operation of [draftId], or null when the draft has none.
  ///
  /// A typed failure uses this to resolve a lost response through its receipt
  /// and, only when no receipt exists, to release the attempt
  /// (SPEC 8.16; DECISIONS P13-DRAFTS).
  Future<String?> activeOperationId(String draftId) async {
    final active = await _activeIntent(draftId);
    return active?.operationId;
  }

  /// The recorded outcome of a draft that already committed, or null.
  ///
  /// A repeated Save returns this receipt before its effects are prepared, so
  /// a second tap writes nothing (F03-B; DATABASE_DESIGN 6).
  Future<CommandOutcome?> committedOutcomeOf(String draftId) async {
    final row = await _db.customSelect(
      'SELECT committed_operation_id FROM draft_headers WHERE id = ?',
      variables: [Variable(draftId)],
    ).getSingleOrNull();
    final operationId = row?.data['committed_operation_id'] as String?;
    if (operationId == null) {
      return null;
    }
    return _readReceipt(operationId);
  }

  Future<({String operationId, List<int> digest})?> _activeIntent(
    String draftId,
  ) async {
    final rows = await _db.customSelect(
      'SELECT operation_id, payload_digest FROM operation_intents '
      'WHERE draft_id = ? AND state IN (?, ?)',
      variables: [
        Variable(draftId),
        const Variable('submitted'),
        const Variable('running'),
      ],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return (
      operationId: row.data['operation_id'] as String,
      digest: row.data['payload_digest'] as List<int>,
    );
  }

  Future<String> _currentEpoch() async {
    final row = await _db
        .customSelect('SELECT db_epoch FROM db_state WHERE singleton = 1')
        .getSingle();
    return row.data['db_epoch'] as String;
  }

  String _nextOperationId() {
    final injected = _newOperationId;
    if (injected != null) {
      return injected();
    }
    final random = Random.secure();
    final bytes = List<int>.generate(10, (_) => random.nextInt(256));
    return UuidV7.generate(
      unixMillis: _nowMs(),
      randomBytes: bytes,
    ).toString();
  }

  Future<CommandOutcome?> _readReceipt(String operationId) async {
    final rows = await _db.customSelect(
      'SELECT r.commit_sequence, r.result_json, s.read_revision '
      'FROM operation_receipts r, db_state s '
      'WHERE r.operation_id = ? AND s.singleton = 1',
      variables: [Variable(operationId)],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return CommandOutcome(
      operationId: operationId,
      commitSequence: row.data['commit_sequence'] as int,
      readRevision: row.data['read_revision'] as int,
      resultJson: row.data['result_json'] as String,
    );
  }

  Future<void> _checkIntentIsSubmitted(String operationId) async {
    final rows = await _db.customSelect(
      'SELECT state FROM operation_intents WHERE operation_id = ?',
      variables: [Variable(operationId)],
    ).get();
    if (rows.isEmpty) {
      throw const CommandError(CommandErrorCode.unknownOperation);
    }
    final state = rows.first.data['state'] as String?;
    switch (state) {
      case 'submitted':
        return;
      case 'committed':
        // Receipt appeared between the read and now; the caller retries and
        // gets the recorded outcome. Treat as unknown here.
        throw const CommandError(CommandErrorCode.invalidState);
      default:
        throw const CommandError(CommandErrorCode.invalidState);
    }
  }

  bool _digestEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// Closes notifications. The vault stays owned elsewhere.
  Future<void> dispose() => _published.close();
}
