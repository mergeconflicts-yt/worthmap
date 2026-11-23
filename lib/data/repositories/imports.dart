// P3-16 (SPEC 8.6, 8.8; SYSTEM_DESIGN 10; EXECUTION_SAFETY 2): staging an
// imported statement.
//
// The repository writes source identities, a parse configuration, one import
// batch, staged rows, source claims and Inbox items. It publishes the batch
// marker and the Inbox count in one transaction, so a viewer never sees half
// an import. It never writes a payment: only `ConfirmInboxBatch` does that.
//
// The file name and the row text stay inside the vault. Logs and errors carry
// codes and counts only (AGENTS 2.6).
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../domain/importers/pdf/pdf_statement.dart';
import '../../domain/importers/pdf/pdf_template.dart';
import '../db/app_database.dart';

/// Safe import staging failure codes.
enum ImportStageErrorCode {
  duplicateFile,
  noRows,
  tooManyRows,
  accountMissing,
  notFound,
  alreadyConfirmed,
  notPublished,
  withdrawn,
}

final class ImportStageError implements Exception {
  const ImportStageError(this.code, {this.batchId});

  final ImportStageErrorCode code;
  final String? batchId;

  @override
  String toString() => 'ImportStageError(${code.name})';
}

/// One parsed payment to stage.
final class ImportRowDraft {
  const ImportRowDraft({
    required this.sourceKey,
    required this.date,
    required this.amountMinor,
    required this.currencyCode,
    this.merchantName,
    this.categoryId,
    this.unsure = false,
  });

  /// A stable key inside the file, such as `pdf:1:12:3`.
  final String sourceKey;

  /// ISO `YYYY-MM-DD`.
  final String date;
  final int amountMinor;
  final String currencyCode;
  final String? merchantName;
  final String? categoryId;
  final bool unsure;
}

/// One import request. The caller holds the bytes; the vault holds no copy.
final class ImportStageRequest {
  const ImportStageRequest({
    required this.label,
    required this.fileDigest,
    required this.accountId,
    required this.rows,
    required this.templateFingerprint,
    this.parserId = 'pdf',
    this.parserVersion = 1,
    this.allowReimport = false,
  });

  /// The display name ("First Bank statement, October"). Local only.
  final String label;

  /// SHA-256 of the file bytes.
  final List<int> fileDigest;
  final String accountId;
  final List<ImportRowDraft> rows;
  final String templateFingerprint;
  final String parserId;
  final int parserVersion;

  /// A second import of the same file asks first (SPEC 8.9).
  final bool allowReimport;
}

final class ImportStageResult {
  const ImportStageResult({
    required this.batchId,
    required this.staged,
    required this.existing,
  });

  final String batchId;

  /// Rows published to the Inbox.
  final int staged;

  /// Rows already in the app by source identity.
  final int existing;
}

/// One row of X63 *History*.
final class ImportBatchRow {
  const ImportBatchRow({
    required this.id,
    required this.label,
    required this.createdAtMs,
    required this.staged,
    required this.existing,
    required this.accepted,
    required this.status,
  });

  final String id;
  final String label;
  final int createdAtMs;
  final int staged;
  final int existing;

  /// How many staged rows were later confirmed.
  final int accepted;

  /// `review`, `done` or `discarded`.
  final String status;
}

/// Q13 / SYSTEM_DESIGN 10: staging and withdrawal of a file import.
final class SavedTemplate {
  const SavedTemplate({
    required this.fingerprint,
    required this.name,
    required this.bands,
    required this.usedCount,
  });

  final String fingerprint;
  final String name;
  final PdfColumnBands bands;
  final int usedCount;
}

/// Q13 / SYSTEM_DESIGN 10: staging and withdrawal of a file import.
final class ImportStagingRepository {
  ImportStagingRepository({
    required AppDatabase db,
    required DateTime Function() clockUtc,
    String Function()? newEntityId,
  })  : _db = db,
        _clockUtc = clockUtc,
        _newEntityId = newEntityId;

  final AppDatabase _db;
  final DateTime Function() _clockUtc;
  final String Function()? _newEntityId;

  /// Stages and publishes one import. One transaction or none.
  Future<ImportStageResult> stage(ImportStageRequest request) async {
    if (request.rows.isEmpty) {
      throw const ImportStageError(ImportStageErrorCode.noRows);
    }
    if (request.rows.length > 5000) {
      throw const ImportStageError(ImportStageErrorCode.tooManyRows);
    }
    if (request.accountId.isEmpty) {
      throw const ImportStageError(ImportStageErrorCode.accountMissing);
    }
    final now = _clockUtc().millisecondsSinceEpoch;
    final label = request.label.trim().isEmpty ? 'Statement' : request.label;

    final existing = await _db.customSelect(
      'SELECT id FROM import_batches WHERE file_digest = ? '
      "AND status != 'discarded' LIMIT 1",
      variables: <Variable<Object>>[
        Variable<Uint8List>(Uint8List.fromList(request.fileDigest)),
      ],
    ).get();
    if (existing.isNotEmpty && !request.allowReimport) {
      throw ImportStageError(
        ImportStageErrorCode.duplicateFile,
        batchId: existing.first.data['id'] as String,
      );
    }

    final batchId = _nextId();
    final parseConfigId = _nextId();
    var staged = 0;
    var repeated = 0;

    await _db.transaction(() async {
      final known = await _db.customSelect(
        'SELECT source_record_id FROM source_identities '
        'WHERE namespace = ? AND account_scope = ?',
        variables: <Variable<Object>>[
          const Variable<String>('localFile'),
          Variable<String>(request.accountId),
        ],
      ).get();
      final seen = <String>{
        for (final row in known) row.data['source_record_id'] as String,
      };
      for (final row in request.rows) {
        if (seen.contains(row.sourceKey)) repeated++;
      }

      final config = jsonEncode(<String, Object?>{
        'label': label,
        'template': request.templateFingerprint,
        'existing': repeated,
      });
      await _db.customStatement(
        'INSERT INTO import_parse_configs (id, parser_id, parser_version, '
        'identity_version, config_version, config_json, content_digest) '
        'VALUES (?, ?, ?, 1, 1, ?, ?)',
        <Object?>[
          parseConfigId,
          request.parserId,
          request.parserVersion,
          config,
          Uint8List.fromList(sha256.convert(utf8.encode(config)).bytes),
        ],
      );
      await _db.customStatement(
        'INSERT INTO import_batches (id, parse_config_id, source, file_digest, '
        'parser_id, parser_version, template_version, created_at, status, '
        'row_count, parsed_cursor, safe_error_code, payload_schema_version, '
        'inbox_published) '
        "VALUES (?, ?, 'localFile', ?, ?, ?, 1, ?, 'review', 0, NULL, NULL, 1, 0)",
        <Object?>[
          batchId,
          parseConfigId,
          Uint8List.fromList(request.fileDigest),
          request.parserId,
          request.parserVersion,
          now,
        ],
      );

      for (final row in request.rows) {
        if (seen.contains(row.sourceKey)) {
          continue;
        }
        final sourceId = await _identityFor(
          accountId: request.accountId,
          sourceKey: row.sourceKey,
          now: now,
        );
        final proposal = _proposalJson(row, request.accountId);
        await _db.customStatement(
          'INSERT INTO staged_rows (batch_id, row_ordinal, '
          'source_identity_id, payload_json, payload_schema_version) '
          'VALUES (?, ?, ?, ?, 1)',
          <Object?>[batchId, staged, sourceId, proposal],
        );
        final stagedRow = await _db
            .customSelect(
              'SELECT last_insert_rowid() AS id',
            )
            .getSingle();
        final stagedRowId = stagedRow.data['id'] as int;
        await _db.customStatement(
          'INSERT INTO source_claims (source_identity_id, batch_id, draft_id, '
          "status) VALUES (?, ?, NULL, 'staged')",
          <Object?>[sourceId, batchId],
        );
        await _db.customStatement(
          'INSERT INTO inbox_items (source_identity_id, staged_row_id, '
          'received_at, suggestion_type, payload_schema_version, '
          'proposed_json, decision, edit_revision) '
          "VALUES (?, ?, ?, 'new', 1, ?, 'pending', 1)",
          <Object?>[sourceId, stagedRowId, now, proposal],
        );
        staged++;
      }

      await _db.customStatement(
        'UPDATE import_batches SET row_count = ?, inbox_published = 1 '
        'WHERE id = ?',
        <Object?>[staged, batchId],
      );
      await _bumpInboxRevision();
    });

    return ImportStageResult(
      batchId: batchId,
      staged: staged,
      existing: repeated,
    );
  }

  /// The X63 history list, newest first.
  Future<List<ImportBatchRow>> history({int limit = 20}) async {
    final rows = await _db.customSelect(
      'SELECT b.id, b.created_at, b.row_count, b.status, c.config_json, '
      '(SELECT COUNT(*) FROM source_claims s WHERE s.batch_id = b.id '
      "AND s.status = 'accepted') AS accepted "
      'FROM import_batches b '
      'JOIN import_parse_configs c ON c.id = b.parse_config_id '
      "WHERE b.status != 'discarded' "
      'ORDER BY b.created_at DESC, b.id DESC LIMIT ?',
      variables: <Variable<Object>>[Variable<int>(limit)],
    ).get();
    return <ImportBatchRow>[
      for (final row in rows)
        ImportBatchRow(
          id: row.data['id'] as String,
          label: _labelOf(row.data['config_json']),
          createdAtMs: row.data['created_at'] as int,
          staged: row.data['row_count'] as int,
          existing: _existingOf(row.data['config_json']),
          accepted: row.data['accepted'] as int,
          status: row.data['status'] as String,
        ),
    ];
  }

  /// Removes every staged item of a batch. Returns the number withdrawn.
  ///
  /// After one confirmed item the batch is no longer withdrawable: the items
  /// are real payments and their own Undo applies (SPEC 8.18).
  Future<int> withdraw(String batchId) async {
    final rows = await _db.customSelect(
      'SELECT id, status, inbox_published FROM import_batches WHERE id = ?',
      variables: <Variable<Object>>[Variable<String>(batchId)],
    ).get();
    if (rows.isEmpty) {
      throw const ImportStageError(ImportStageErrorCode.notFound);
    }
    final status = rows.single.data['status'] as String;
    if (status == 'discarded') {
      throw const ImportStageError(ImportStageErrorCode.withdrawn);
    }
    if (status != 'review') {
      throw const ImportStageError(ImportStageErrorCode.alreadyConfirmed);
    }
    final accepted = await _db.customSelect(
      'SELECT COUNT(*) AS n FROM source_claims WHERE batch_id = ? '
      "AND status != 'staged'",
      variables: <Variable<Object>>[Variable<String>(batchId)],
    ).getSingle();
    if ((accepted.data['n'] as int) > 0) {
      throw const ImportStageError(ImportStageErrorCode.alreadyConfirmed);
    }
    final count = await _db.customSelect(
      'SELECT COUNT(*) AS n FROM staged_rows WHERE batch_id = ?',
      variables: <Variable<Object>>[Variable<String>(batchId)],
    ).getSingle();
    final withdrawn = count.data['n'] as int;
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM inbox_items WHERE staged_row_id IN '
        '(SELECT id FROM staged_rows WHERE batch_id = ?)',
        <Object?>[batchId],
      );
      await _db.customStatement(
        'DELETE FROM staged_rows WHERE batch_id = ?',
        <Object?>[batchId],
      );
      await _db.customStatement(
        'UPDATE source_claims SET status = ? '
        "WHERE batch_id = ? AND status = 'staged'",
        <Object?>['discarded', batchId],
      );
      await _db.customStatement(
        'UPDATE import_batches SET status = ?, row_count = 0 WHERE id = ?',
        <Object?>['discarded', batchId],
      );
      await _bumpInboxRevision();
    });
    return withdrawn;
  }

  // -------------------------------------------------------------------------

  /// Stores a taught layout. The config is append-only, so a re-teach of the
  /// same layout creates a newer row and the newest one wins on read.
  Future<void> saveTemplate(PdfTemplate template) async {
    final id = _nextId();
    final json = jsonEncode(template.toJson());
    await _db.customStatement(
      'INSERT INTO import_parse_configs (id, parser_id, parser_version, '
      'identity_version, config_version, config_json, content_digest) '
      'VALUES (?, ?, ?, 1, ?, ?, ?)',
      <Object?>[
        id,
        'pdf-template',
        template.version,
        template.version,
        json,
        Uint8List.fromList(sha256.convert(utf8.encode(json)).bytes),
      ],
    );
  }

  /// The saved layouts, newest first and one row per fingerprint.
  Future<List<SavedTemplate>> templates() async {
    final rows = await _db
        .customSelect(
          'SELECT config_json FROM import_parse_configs '
          "WHERE parser_id = 'pdf-template' ORDER BY rowid DESC",
        )
        .get();
    final seen = <String>{};
    final out = <SavedTemplate>[];
    for (final row in rows) {
      final raw = row.data['config_json'];
      if (raw is! String) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final template = PdfTemplate.fromJson(
        Map<String, Object?>.from(decoded),
      );
      if (template == null || !seen.add(template.fingerprint)) continue;
      out.add(
        SavedTemplate(
          fingerprint: template.fingerprint,
          name: template.name,
          bands: template.bands,
          usedCount: await _templateUses(template.fingerprint),
        ),
      );
    }
    return out;
  }

  Future<int> _templateUses(String fingerprint) async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS n FROM import_batches b '
      'JOIN import_parse_configs c ON c.id = b.parse_config_id '
      "WHERE json_extract(c.config_json, '\$.template') = ?",
      variables: <Variable<Object>>[Variable<String>(fingerprint)],
    ).getSingle();
    return row.data['n'] as int;
  }

  /// Reserves a source identity for one row. The caller checks known keys
  /// first, so the insert always creates exactly one row.
  Future<int> _identityFor({
    required String accountId,
    required String sourceKey,
    required int now,
  }) async {
    await _db.customStatement(
      'INSERT INTO source_identities (namespace, account_scope, '
      'source_record_id, identity_version, first_seen_at) '
      'VALUES (?, ?, ?, 1, ?)',
      <Object?>['localFile', accountId, sourceKey, now],
    );
    final row = await _db
        .customSelect(
          'SELECT last_insert_rowid() AS id',
        )
        .getSingle();
    return row.data['id'] as int;
  }

  String _proposalJson(ImportRowDraft row, String accountId) => jsonEncode(
        <String, Object?>{
          'v': 1,
          'amountMinor': row.amountMinor,
          'currency': row.currencyCode,
          'date': row.date,
          'accountId': accountId,
          'kind': row.amountMinor < 0 ? 'expense' : 'income',
          if (row.merchantName != null && row.merchantName!.isNotEmpty)
            'merchantName': row.merchantName,
          if (row.categoryId != null) 'categoryId': row.categoryId,
          'splits': const <Object?>[],
          'tagIds': const <String>[],
          'decision': 'accept',
        },
      );

  String _labelOf(Object? raw) {
    if (raw is! String) return 'Statement';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['label'] is String) {
        return decoded['label'] as String;
      }
    } on FormatException {
      return 'Statement';
    }
    return 'Statement';
  }

  int _existingOf(Object? raw) {
    if (raw is! String) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['existing'] is int) {
        return decoded['existing'] as int;
      }
    } on FormatException {
      return 0;
    }
    return 0;
  }

  Future<void> _bumpInboxRevision() async {
    await _db.customStatement(
      'UPDATE db_state SET inbox_revision = inbox_revision + 1 '
      'WHERE singleton = 1',
    );
  }

  String _nextId() {
    final injected = _newEntityId;
    if (injected != null) return injected();
    final random = Random.secure();
    final bytes = List<int>.generate(10, (_) => random.nextInt(256));
    return UuidV7.generate(
      unixMillis: _clockUtc().millisecondsSinceEpoch,
      randomBytes: bytes,
    ).toString();
  }
}
