// P3-07 (SPEC 8.6; flow F06): the PDF import entry point.
//
// Bytes in, statement rows out. The importer never writes, never fetches and
// never keeps the file. A failure returns a typed code that X88 maps to one
// sentence.
library;

import 'pdf_document.dart';
import 'pdf_objects.dart';
import 'pdf_statement.dart';
import 'pdf_template.dart';
import 'pdf_text.dart';

/// Safe import failure codes (no file name, amount or row text).
enum PdfImportErrorCode {
  notPdf,
  damaged,
  tooLarge,
  unsupportedFilter,
  locked,
  wrongPassword,
  unsupportedEncryption,
  noPages,
  noText,
  noRows,
}

final class PdfImportError implements Exception {
  const PdfImportError(this.code);

  final PdfImportErrorCode code;

  @override
  String toString() => 'PdfImportError(${code.name})';
}

/// The result of reading one statement.
final class PdfImportOutcome {
  const PdfImportOutcome({
    required this.statement,
    required this.fingerprint,
    required this.templateMatched,
    required this.pageCount,
    this.sampleLine,
    this.sampleCells = const <PdfLineCell>[],
  });

  final PdfStatement statement;
  final String fingerprint;
  final bool templateMatched;
  final int pageCount;

  /// The first payment line, for the Teach once editor (X66).
  final PdfTextLine? sampleLine;

  /// The cells of [sampleLine], in reading order.
  final List<PdfLineCell> sampleCells;

  int get paymentCount => statement.payments.length;
  int get balanceCount =>
      statement.rows.where((row) => row.kind == PdfRowKind.balance).length;
  int get unsureCount => statement.unsureCount;
}

/// Reads a statement PDF. PDF only in this release (DECISIONS
/// `P3-PDF-SUBSET`).
final class PdfImporter {
  const PdfImporter({this.defaultCurrency = 'USD'});

  final String defaultCurrency;

  /// Reads [bytes]. A saved [template] must match the layout fingerprint.
  PdfImportOutcome read(
    List<int> bytes, {
    String? password,
    PdfTemplate? template,
  }) {
    final PdfDocument document;
    try {
      document = PdfDocument.open(bytes, password: password);
    } on PdfError catch (error) {
      throw PdfImportError(_mapError(error.code));
    }

    final pages = extractPdfText(document);
    final hasText = pages.any((page) => !page.isEmpty);
    if (!hasText) {
      throw const PdfImportError(PdfImportErrorCode.noText);
    }

    final parser = PdfStatementParser(defaultCurrency: defaultCurrency);
    final statement = parser.parse(pages);
    if (statement.payments.isEmpty && statement.rows.isEmpty) {
      throw const PdfImportError(PdfImportErrorCode.noRows);
    }

    PdfTextLine? sampleLine;
    var sampleCells = const <PdfLineCell>[];
    final firstPayment =
        statement.payments.isEmpty ? null : statement.payments.first;
    if (firstPayment != null &&
        firstPayment.page >= 1 &&
        firstPayment.page <= pages.length) {
      final page = pages[firstPayment.page - 1];
      if (firstPayment.line >= 0 && firstPayment.line < page.lines.length) {
        sampleLine = page.lines[firstPayment.line];
        sampleCells = pdfLineCells(sampleLine);
      }
    }

    final matched = template == null || template.matches(statement.fingerprint);
    if (template != null && !matched) {
      return PdfImportOutcome(
        statement: statement,
        fingerprint: statement.fingerprint,
        templateMatched: false,
        pageCount: document.pages.length,
        sampleLine: sampleLine,
        sampleCells: sampleCells,
      );
    }
    if (template != null) {
      final applied = parser.parse(pages, bands: template.bands);
      return PdfImportOutcome(
        statement: applied,
        fingerprint: applied.fingerprint,
        templateMatched: true,
        pageCount: document.pages.length,
        sampleLine: sampleLine,
        sampleCells: sampleCells,
      );
    }
    return PdfImportOutcome(
      statement: statement,
      fingerprint: statement.fingerprint,
      templateMatched: template == null,
      pageCount: document.pages.length,
      sampleLine: sampleLine,
      sampleCells: sampleCells,
    );
  }

  static PdfImportErrorCode _mapError(PdfErrorCode code) => switch (code) {
        PdfErrorCode.notPdf => PdfImportErrorCode.notPdf,
        PdfErrorCode.damaged => PdfImportErrorCode.damaged,
        PdfErrorCode.tooLarge => PdfImportErrorCode.tooLarge,
        PdfErrorCode.unsupportedFilter => PdfImportErrorCode.unsupportedFilter,
        PdfErrorCode.locked => PdfImportErrorCode.locked,
        PdfErrorCode.wrongPassword => PdfImportErrorCode.wrongPassword,
        PdfErrorCode.unsupportedEncryption =>
          PdfImportErrorCode.unsupportedEncryption,
        PdfErrorCode.noPages => PdfImportErrorCode.noPages,
      };
}

/// A quick test: does this file look like a PDF?
bool looksLikePdf(List<int> bytes) {
  final limit = bytes.length < 1024 ? bytes.length : 1024;
  for (var i = 0; i + 5 <= limit; i++) {
    if (bytes[i] == 0x25 &&
        bytes[i + 1] == 0x50 &&
        bytes[i + 2] == 0x44 &&
        bytes[i + 3] == 0x46) {
      return true;
    }
  }
  return false;
}
