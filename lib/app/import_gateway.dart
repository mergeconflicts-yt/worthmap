// P3-25 (flow F06): the app composition for the PDF import.
//
// The adapter maps the P3-16 repository to the feature port. It formats no
// money and logs nothing (AGENTS 2.6). `send` publishes staged rows only; the
// Inbox confirm stays the one write that creates a payment.
library;

import '../data/repositories/imports.dart';
import '../domain/importers/pdf/pdf_template.dart';
import '../features/import/import_models.dart';

/// P3-16 behind the import feature port.
final class SqlImportGateway implements ImportGateway {
  SqlImportGateway({required this.imports});

  final ImportStagingRepository imports;

  @override
  Future<List<SavedLayout>> layouts() async {
    final rows = await imports.templates();
    return <SavedLayout>[
      for (final row in rows)
        SavedLayout(
          fingerprint: row.fingerprint,
          name: row.name,
          usedCount: row.usedCount,
          bands: row.bands,
        ),
    ];
  }

  @override
  Future<SavedLayout> saveLayout(PdfTemplate template) async {
    await imports.saveTemplate(template);
    return SavedLayout(
      fingerprint: template.fingerprint,
      name: template.name,
      usedCount: 0,
      bands: template.bands,
    );
  }

  @override
  Future<List<ImportBatchView>> history() async {
    final rows = await imports.history();
    return <ImportBatchView>[
      for (final row in rows)
        ImportBatchView(
          id: row.id,
          label: row.label,
          createdAtMs: row.createdAtMs,
          staged: row.staged,
          existing: row.existing,
          accepted: row.accepted,
          status: row.status,
        ),
    ];
  }

  @override
  Future<ImportSendResult> send({
    required String label,
    required List<int> fileDigest,
    required String accountId,
    required List<ImportDraftRow> rows,
    required String fingerprint,
    required bool allowReimport,
  }) async {
    try {
      final result = await imports.stage(
        ImportStageRequest(
          label: label,
          fileDigest: fileDigest,
          accountId: accountId,
          templateFingerprint: fingerprint,
          allowReimport: allowReimport,
          rows: <ImportRowDraft>[
            for (final row in rows)
              ImportRowDraft(
                sourceKey: row.sourceKey,
                date: row.date,
                amountMinor: row.amountMinor,
                currencyCode: row.currencyCode,
                merchantName: row.merchantName,
              ),
          ],
        ),
      );
      return ImportSendResult(
        batchId: result.batchId,
        staged: result.staged,
        existing: result.existing,
      );
    } on ImportStageError catch (error) {
      throw ImportIntakeError(_map(error.code));
    }
  }

  @override
  Future<int> undo(String batchId) async {
    try {
      return await imports.withdraw(batchId);
    } on ImportStageError {
      throw const ImportIntakeError(ImportFailure.undoFailed);
    }
  }

  static ImportFailure _map(ImportStageErrorCode code) => switch (code) {
        ImportStageErrorCode.duplicateFile => ImportFailure.duplicateFile,
        ImportStageErrorCode.noRows => ImportFailure.noRows,
        ImportStageErrorCode.tooManyRows => ImportFailure.sendFailed,
        ImportStageErrorCode.accountMissing => ImportFailure.sendFailed,
        ImportStageErrorCode.notFound => ImportFailure.undoFailed,
        ImportStageErrorCode.alreadyConfirmed => ImportFailure.undoFailed,
        ImportStageErrorCode.notPublished => ImportFailure.undoFailed,
        ImportStageErrorCode.withdrawn => ImportFailure.undoFailed,
      };
}
