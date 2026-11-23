// P3-25 (flow F06; SCREENS X63, X65, X66, X68, X88): the import flow state.
//
// The controller reads a local PDF through the domain importer, keeps the
// parsed rows, and sends them to the Inbox. It never writes a payment. The
// file bytes stay in memory until the send completes and are then dropped.
library;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../domain/importers/pdf/pdf_import.dart';
import '../../domain/importers/pdf/pdf_statement.dart';
import '../../domain/importers/pdf/pdf_template.dart';
import 'import_models.dart';

/// One step of the flow.
enum ImportStep {
  idle,
  reading,
  password,
  preview,
  sending,
  done,
  failed,
}

/// X63, X65, X66, X68 and X88 state.
final class ImportController extends ChangeNotifier {
  ImportController({
    required ImportGateway gateway,
    required ImportFileIntake intake,
    ImportPasswordVault? passwords,
    PdfImporter importer = const PdfImporter(),
    this.onUndone,
  })  : _gateway = gateway,
        _intake = intake,
        _passwords = passwords,
        _importer = importer;

  final ImportGateway _gateway;
  final ImportFileIntake _intake;
  final ImportPasswordVault? _passwords;
  final PdfImporter _importer;

  /// Called once after a successful undo (the caller shows the toast).
  final VoidCallback? onUndone;

  ImportStep _step = ImportStep.idle;
  ImportFailure? _failure;
  ImportedFile? _file;
  String? _fileName;
  PdfImportOutcome? _outcome;
  SavedLayout? _layout;
  String? _passwordError;
  String? _batchId;
  int _staged = 0;
  int _existing = 0;
  int _undone = 0;
  bool _busy = false;

  List<SavedLayout> _layouts = const <SavedLayout>[];
  List<ImportBatchView> _history = const <ImportBatchView>[];

  ImportStep get step => _step;
  ImportFailure? get failure => _failure;
  String? get fileName => _fileName;
  PdfImportOutcome? get outcome => _outcome;
  SavedLayout? get matchedLayout => _layout;
  String? get passwordError => _passwordError;
  String? get batchId => _batchId;
  int get staged => _staged;
  int get existing => _existing;
  int get undone => _undone;
  bool get busy => _busy;
  List<SavedLayout> get layouts => _layouts;
  List<ImportBatchView> get history => _history;

  /// Payments ready for the Inbox.
  int get readyCount {
    final payments = _outcome?.statement.payments ?? const <PdfStatementRow>[];
    return payments
        .where((row) => row.confidence == PdfRowConfidence.filled)
        .length;
  }

  /// Rows the reader marked for a check.
  int get decisionCount => _outcome?.unsureCount ?? 0;

  /// Rows without a category. The Inbox offers the category choice.
  int get noCategoryCount => 0;

  /// Loads the saved layouts and the history. A closed vault is not an error
  /// on the hub: the lists stay empty and the actions still state the reason.
  Future<void> load() async {
    try {
      final layouts = await _gateway.layouts();
      final history = await _gateway.history();
      _layouts = List<SavedLayout>.unmodifiable(layouts);
      _history = List<ImportBatchView>.unmodifiable(history);
      notifyListeners();
    } on ImportIntakeError {
      _layouts = const <SavedLayout>[];
      _history = const <ImportBatchView>[];
      notifyListeners();
    }
  }

  /// Opens the local picker and reads the chosen file.
  Future<void> chooseFile() async {
    if (_busy) return;
    _busy = true;
    _step = ImportStep.reading;
    _failure = null;
    _passwordError = null;
    notifyListeners();
    try {
      final picked = await _intake.pickPdf();
      if (picked == null) {
        _busy = false;
        _step = ImportStep.idle;
        notifyListeners();
        return;
      }
      _file = picked;
      _fileName = picked.name;
      await _read(password: null);
    } on ImportIntakeError catch (error) {
      _fail(error.failure);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Opens a locked file with a password. A wrong password keeps X64 open.
  ///
  /// [remember] stores the password in the vault for this file name. The
  /// dialog offers the choice; a saved password opens the next copy without a
  /// question.
  Future<void> submitPassword(String password, {bool remember = false}) async {
    if (_busy || password.isEmpty) return;
    _busy = true;
    notifyListeners();
    try {
      await _read(password: password, remember: remember);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _read({String? password, bool remember = false}) async {
    final file = _file;
    if (file == null) return;
    var attempt = password;
    var fromSaved = false;
    if (attempt == null || attempt.isEmpty) {
      final saved = await _passwords?.read(file.name);
      if (saved != null && saved.isNotEmpty) {
        attempt = saved;
        fromSaved = true;
      }
    }
    try {
      var outcome = _importer.read(file.bytes, password: attempt);
      SavedLayout? layout;
      for (final saved in _layouts) {
        if (saved.fingerprint == outcome.fingerprint) {
          layout = saved;
          break;
        }
      }
      if (layout != null && layout.bands != null) {
        final template = PdfTemplate(
          fingerprint: layout.fingerprint,
          name: layout.name,
          format: 'pdf',
          version: PdfTemplate.currentVersion,
          bands: layout.bands!,
        );
        outcome = _importer.read(
          file.bytes,
          password: attempt,
          template: template,
        );
      }
      if (attempt != null && attempt.isNotEmpty && !fromSaved && remember) {
        await _passwords?.save(file.name, attempt);
      }
      _layout = layout;
      _outcome = outcome;
      _passwordError = null;
      _step = ImportStep.preview;
    } on PdfImportError catch (error) {
      if (fromSaved &&
          (error.code == PdfImportErrorCode.wrongPassword ||
              error.code == PdfImportErrorCode.locked)) {
        await _passwords?.clear(file.name);
        _step = ImportStep.password;
        _passwordError = null;
        return;
      }
      switch (error.code) {
        case PdfImportErrorCode.locked:
          _step = ImportStep.password;
        case PdfImportErrorCode.wrongPassword:
          _step = ImportStep.password;
          _passwordError = 'wrong';
        default:
          _fail(_mapFailure(error.code));
      }
    }
  }

  /// Closes X64 without a password and returns to the hub.
  void cancelPassword() {
    _step = ImportStep.idle;
    _file = null;
    _passwordError = null;
    notifyListeners();
  }

  /// Sends the parsed payments to the Inbox (`StageImport`).
  Future<void> send({
    required String accountId,
    bool allowReimport = false,
  }) async {
    final outcome = _outcome;
    final file = _file;
    if (outcome == null || file == null || _busy) return;
    _busy = true;
    _step = ImportStep.sending;
    _failure = null;
    notifyListeners();
    try {
      final rows = <ImportDraftRow>[
        for (final row in outcome.statement.payments)
          ImportDraftRow(
            sourceKey: row.sourceKey,
            date: row.date.toString(),
            amountMinor: row.amountMinor,
            currencyCode: row.currencyCode,
            merchantName: row.description.isEmpty ? null : row.description,
          ),
      ];
      final result = await _gateway.send(
        label: file.name,
        fileDigest: sha256.convert(file.bytes).bytes,
        accountId: accountId,
        rows: rows,
        fingerprint: outcome.fingerprint,
        allowReimport: allowReimport,
      );
      _batchId = result.batchId;
      _staged = result.staged;
      _existing = result.existing;
      _file = null;
      _step = ImportStep.done;
    } on ImportIntakeError catch (error) {
      _fail(error.failure);
    }
  }

  /// Removes every staged item of this import.
  Future<void> undo() async {
    final id = _batchId;
    if (id == null || _busy) return;
    _busy = true;
    notifyListeners();
    try {
      _undone = await _gateway.undo(id);
      _step = ImportStep.idle;
      _batchId = null;
      onUndone?.call();
      await load();
    } on ImportIntakeError catch (error) {
      _fail(error.failure);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Saves the taught layout. Returns true when the layout was stored.
  Future<bool> teach({
    required int dateCell,
    required int amountCell,
  }) async {
    final outcome = _outcome;
    final sample = outcome?.sampleLine;
    if (outcome == null || sample == null || _busy) return false;
    _busy = true;
    notifyListeners();
    try {
      final template = teachPdfTemplate(
        name: fileName ?? 'Statement',
        statement: outcome.statement,
        sampleLine: sample,
        dateCell: dateCell,
        amountCell: amountCell,
      );
      if (template == null) {
        _busy = false;
        notifyListeners();
        return false;
      }
      final saved = await _gateway.saveLayout(template);
      _layouts = <SavedLayout>[..._layouts, saved];
      _layout = saved;
      _busy = false;
      notifyListeners();
      return true;
    } on ImportIntakeError {
      _busy = false;
      _failure = ImportFailure.templateFailed;
      notifyListeners();
      return false;
    }
  }

  /// Opens one row of the X63 history in X68.
  void openBatch(ImportBatchView batch) {
    _batchId = batch.id;
    _staged = batch.staged;
    _existing = batch.existing;
    _outcome = null;
    _step = ImportStep.done;
    notifyListeners();
  }

  /// Returns to the hub after a done or failed step.
  void reset() {
    _step = ImportStep.idle;
    _failure = null;
    _outcome = null;
    _file = null;
    _batchId = null;
    _passwordError = null;
    _layout = null;
    _fileName = null;
    _staged = 0;
    _existing = 0;
    _undone = 0;
    notifyListeners();
  }

  void _fail(ImportFailure failure) {
    _failure = failure;
    _step = ImportStep.failed;
  }

  static ImportFailure _mapFailure(PdfImportErrorCode code) => switch (code) {
        PdfImportErrorCode.notPdf => ImportFailure.notPdf,
        PdfImportErrorCode.damaged => ImportFailure.damaged,
        PdfImportErrorCode.tooLarge => ImportFailure.tooLarge,
        PdfImportErrorCode.unsupportedFilter => ImportFailure.unsupportedFilter,
        PdfImportErrorCode.locked => ImportFailure.locked,
        PdfImportErrorCode.wrongPassword => ImportFailure.wrongPassword,
        PdfImportErrorCode.unsupportedEncryption =>
          ImportFailure.unsupportedEncryption,
        PdfImportErrorCode.noPages => ImportFailure.damaged,
        PdfImportErrorCode.noText => ImportFailure.noText,
        PdfImportErrorCode.noRows => ImportFailure.noRows,
      };
}

/// True when [bytes] start with a PDF banner (the picker check).
bool isPdfFile(Uint8List bytes) => looksLikePdf(bytes);
