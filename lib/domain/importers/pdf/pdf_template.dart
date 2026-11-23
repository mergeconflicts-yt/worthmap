// P3-01 (SPEC 8.6): a saved statement layout ("Teach once", X66).
//
// A template stores the layout fingerprint, the column bands and the date
// order. It holds no row values and no file content. Matching is exact on the
// fingerprint; a changed layout asks the user to teach it again.
library;

import 'pdf_statement.dart';
import 'pdf_text.dart';

/// One saved PDF layout.
final class PdfTemplate {
  const PdfTemplate({
    required this.fingerprint,
    required this.name,
    required this.format,
    required this.bands,
    required this.version,
  });

  /// SHA-256 of the normalised header and its column positions.
  final String fingerprint;

  /// The user-visible layout name ("First Bank, checking").
  final String name;

  /// The source format. PDF only in this release.
  final String format;

  final PdfColumnBands bands;

  /// The template schema version. A parser change retires older templates.
  final int version;

  static const int currentVersion = 1;

  bool matches(String candidate) => candidate == fingerprint;

  Map<String, Object?> toJson() => <String, Object?>{
        'v': version,
        'fingerprint': fingerprint,
        'name': name,
        'format': format,
        'bands': bands.toJson(),
      };

  /// Parses a stored template. A newer version returns null, so the caller
  /// asks the user to teach the layout again instead of applying it wrongly.
  static PdfTemplate? fromJson(Map<String, Object?> json) {
    final version = json['v'];
    if (version is! int || version != currentVersion) return null;
    final fingerprint = json['fingerprint'];
    final name = json['name'];
    final format = json['format'];
    final bands = json['bands'];
    if (fingerprint is! String ||
        fingerprint.isEmpty ||
        name is! String ||
        format is! String ||
        bands is! Map) {
      return null;
    }
    return PdfTemplate(
      fingerprint: fingerprint,
      name: name,
      format: format,
      bands: PdfColumnBands.fromJson(Map<String, Object?>.from(bands)),
      version: version,
    );
  }
}

/// Builds a template from the header line and one taught row.
///
/// [dateCell] and [amountCell] index the cells of [sampleLine] that the user
/// tapped on X66. A missing cell returns null.
PdfTemplate? teachPdfTemplate({
  required String name,
  required PdfStatement statement,
  required PdfTextLine sampleLine,
  required int dateCell,
  required int amountCell,
}) {
  final cells = pdfLineCells(sampleLine);
  if (dateCell < 0 ||
      amountCell < 0 ||
      dateCell >= cells.length ||
      amountCell >= cells.length ||
      dateCell == amountCell) {
    return null;
  }
  final date = cells[dateCell];
  final amount = cells[amountCell];
  if (amount.x <= date.x) return null;
  final details = _detailsBetween(cells, dateCell, amountCell);
  return PdfTemplate(
    fingerprint: statement.fingerprint,
    name: name.trim().isEmpty ? 'Statement' : name.trim(),
    format: 'pdf',
    version: PdfTemplate.currentVersion,
    bands: PdfColumnBands(
      dateX: date.x,
      detailsX: details?.x ?? date.x + 40,
      amountX: amount.x,
    ),
  );
}

PdfLineCell? _detailsBetween(
  List<PdfLineCell> cells,
  int dateCell,
  int amountCell,
) {
  for (var i = dateCell + 1; i < amountCell; i++) {
    if (cells[i].text.trim().isNotEmpty) return cells[i];
  }
  return null;
}
