// P3-25 (SCREENS X63, X65, X66, X68, X88; flow F06): the PDF import feature
// contract.
//
// The feature reads a local PDF, shows the parsed rows and sends drafts to the
// Inbox. It never writes a payment; `ConfirmInboxBatch` stays the only write
// that creates one. The file bytes stay in memory and are dropped after the
// send.
library;

import 'dart:typed_data';

import '../../domain/importers/pdf/pdf_statement.dart';
import '../../domain/importers/pdf/pdf_template.dart';

/// Safe failure codes (no file name, amount or row text).
enum ImportFailure {
  notWired,
  notPdf,
  damaged,
  tooLarge,
  unsupportedFilter,
  unsupportedEncryption,
  locked,
  wrongPassword,
  noText,
  noRows,
  duplicateFile,
  sendFailed,
  undoFailed,
  templateFailed,
}

/// A local file the user picked. The bytes never leave the device.
final class ImportedFile {
  const ImportedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// The local file intake. One implementation per platform; the demo uses a
/// synthetic file and the release path stays unavailable until the native
/// share/file binding lands (P3-21, P3-22).
abstract interface class ImportFileIntake {
  /// Returns null when the user cancels. Throws [ImportFailure] codes through
  /// [ImportIntakeError].
  Future<ImportedFile?> pickPdf();
}

final class ImportIntakeError implements Exception {
  const ImportIntakeError(this.failure);

  final ImportFailure failure;
}

/// One saved layout for the X63 list.
final class SavedLayout {
  const SavedLayout({
    required this.fingerprint,
    required this.name,
    required this.usedCount,
    this.bands,
  });

  final String fingerprint;
  final String name;
  final int usedCount;

  /// The column bands stored with the layout, when the caller read them.
  final PdfColumnBands? bands;
}

/// One row of the X63 history.
final class ImportBatchView {
  const ImportBatchView({
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
  final int accepted;
  final String status;
}

/// One parsed payment on its way to the Inbox.
final class ImportDraftRow {
  const ImportDraftRow({
    required this.sourceKey,
    required this.date,
    required this.amountMinor,
    required this.currencyCode,
    this.merchantName,
  });

  final String sourceKey;

  /// ISO `YYYY-MM-DD`.
  final String date;
  final int amountMinor;
  final String currencyCode;
  final String? merchantName;
}

final class ImportSendResult {
  const ImportSendResult({
    required this.batchId,
    required this.staged,
    required this.existing,
  });

  final String batchId;
  final int staged;
  final int existing;
}

/// The import data port. One call is one read or one commit boundary group.
abstract interface class ImportGateway {
  Future<List<SavedLayout>> layouts();

  /// Saves a taught layout. It holds no row values.
  Future<SavedLayout> saveLayout(PdfTemplate template);

  Future<List<ImportBatchView>> history();

  /// `StageImport`: writes staging rows and publishes them. No payment.
  Future<ImportSendResult> send({
    required String label,
    required List<int> fileDigest,
    required String accountId,
    required List<ImportDraftRow> rows,
    required String fingerprint,
    required bool allowReimport,
  });

  /// Removes every staged item of one import. Returns the count.
  Future<int> undo(String batchId);
}

/// The placeholder port before the composition mounts the vault.
final class UnavailableImportGateway implements ImportGateway {
  const UnavailableImportGateway();

  @override
  Future<List<SavedLayout>> layouts() async =>
      throw const ImportIntakeError(ImportFailure.notWired);

  @override
  Future<SavedLayout> saveLayout(PdfTemplate template) async =>
      throw const ImportIntakeError(ImportFailure.notWired);

  @override
  Future<List<ImportBatchView>> history() async =>
      throw const ImportIntakeError(ImportFailure.notWired);

  @override
  Future<ImportSendResult> send({
    required String label,
    required List<int> fileDigest,
    required String accountId,
    required List<ImportDraftRow> rows,
    required String fingerprint,
    required bool allowReimport,
  }) async =>
      throw const ImportIntakeError(ImportFailure.notWired);

  @override
  Future<int> undo(String batchId) async =>
      throw const ImportIntakeError(ImportFailure.notWired);
}

/// The placeholder intake. The release composition mounts it until a verified
/// local file binding exists.
final class UnavailableFileIntake implements ImportFileIntake {
  const UnavailableFileIntake();

  @override
  Future<ImportedFile?> pickPdf() async =>
      throw const ImportIntakeError(ImportFailure.notWired);
}

/// The PDF password vault port (X64 "Remember for this layout").
abstract interface class ImportPasswordVault {
  Future<String?> read(String scope);

  Future<void> save(String scope, String password);

  Future<void> clear(String scope);
}

/// A session-only vault for the demo composition and widget tests.
final class MemoryImportPasswordVault implements ImportPasswordVault {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String scope) async => _values[scope];

  @override
  Future<void> save(String scope, String password) async {
    if (scope.isEmpty || password.isEmpty) return;
    _values[scope] = password;
  }

  @override
  Future<void> clear(String scope) async {
    _values.remove(scope);
  }
}
