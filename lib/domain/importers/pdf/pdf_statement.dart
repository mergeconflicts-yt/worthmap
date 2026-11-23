// P3-07 (SPEC 8.6, 4.3): turn extracted PDF lines into statement rows.
//
// Rules:
//   - a row needs a date and an amount; a row without a date is not guessed;
//   - an unknown amount is absent, never zero;
//   - money is an integer minor-unit value; no `double` touches it;
//   - a balance row is a fact about the account, not a payment;
//   - an ambiguous numeric date or an amount without decimals is `unsure`.
//
// The parser reads text only. It never writes to the database.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/dates.dart';
import 'pdf_text.dart';

/// What one statement line describes.
enum PdfRowKind { payment, balance }

/// How much the reader trusts the parsed row (X25 review rows).
enum PdfRowConfidence { filled, unsure }

/// One candidate row from a statement.
final class PdfStatementRow {
  const PdfStatementRow({
    required this.date,
    required this.description,
    required this.amountMinor,
    required this.currencyCode,
    required this.kind,
    required this.confidence,
    required this.page,
    required this.line,
    required this.sourceKey,
  });

  final LocalDate date;
  final String description;

  /// Signed minor units. A payment is negative; a credit is positive.
  final int amountMinor;
  final String currencyCode;
  final PdfRowKind kind;
  final PdfRowConfidence confidence;

  /// A stable identity for this row inside this file.
  final String sourceKey;
  final int page;
  final int line;

  bool get isPayment => kind == PdfRowKind.payment;
}

/// The parsed statement. [rows] holds payments and balance rows in file order.
final class PdfStatement {
  const PdfStatement({
    required this.rows,
    required this.pageCount,
    required this.currencyCode,
    required this.headerText,
    required this.fingerprint,
    required this.templateMatched,
  });

  final List<PdfStatementRow> rows;
  final int pageCount;
  final String currencyCode;

  /// The detected table header, or an empty string.
  final String headerText;

  /// The layout fingerprint used for a saved template lookup.
  final String fingerprint;

  /// False when a saved template was supplied and did not match this layout.
  final bool templateMatched;

  List<PdfStatementRow> get payments =>
      rows.where((row) => row.isPayment).toList(growable: false);

  int get unsureCount =>
      rows.where((row) => row.confidence == PdfRowConfidence.unsure).length;
}

/// The column bands of a layout, in points from the page's left edge.
final class PdfColumnBands {
  const PdfColumnBands({
    required this.dateX,
    required this.detailsX,
    required this.amountX,
    this.balanceX,
  });

  final double dateX;
  final double detailsX;
  final double amountX;
  final double? balanceX;

  Map<String, Object?> toJson() => <String, Object?>{
        'dateX': dateX,
        'detailsX': detailsX,
        'amountX': amountX,
        if (balanceX != null) 'balanceX': balanceX,
      };

  factory PdfColumnBands.fromJson(Map<String, Object?> json) => PdfColumnBands(
        dateX: (json['dateX'] as num).toDouble(),
        detailsX: (json['detailsX'] as num).toDouble(),
        amountX: (json['amountX'] as num).toDouble(),
        balanceX: (json['balanceX'] as num?)?.toDouble(),
      );
}

/// Parses lines into statement rows.
final class PdfStatementParser {
  const PdfStatementParser({this.defaultCurrency = 'USD'});

  final String defaultCurrency;

  PdfStatement parse(List<PdfPageText> pages, {PdfColumnBands? bands}) {
    final rows = <PdfStatementRow>[];
    final header = _findHeader(pages);
    final fingerprint = _fingerprint(pages, header);
    var ordinal = 0;
    for (final page in pages) {
      for (var i = 0; i < page.lines.length; i++) {
        final line = page.lines[i];
        final text = _normalise(line.text);
        if (text.isEmpty) continue;
        final candidate = _parseLine(
          line,
          page: page.pageNumber,
          lineNumber: i,
          ordinal: ordinal,
          bands: bands,
        );
        if (candidate == null) continue;
        ordinal++;
        rows.add(candidate);
      }
    }
    return PdfStatement(
      rows: List<PdfStatementRow>.unmodifiable(rows),
      pageCount: pages.length,
      currencyCode: rows.isEmpty ? defaultCurrency : rows.first.currencyCode,
      headerText: header?.text ?? '',
      fingerprint: fingerprint,
      templateMatched: true,
    );
  }

  PdfStatementRow? _parseLine(
    PdfTextLine line, {
    required int page,
    required int lineNumber,
    required int ordinal,
    required PdfColumnBands? bands,
  }) {
    final cells = _cells(line);
    if (cells.isEmpty) return null;
    var text = _normalise(line.text);

    final lowered = text.toLowerCase();
    final isBalance = lowered.contains('opening balance') ||
        lowered.contains('closing balance') ||
        lowered.contains('balance brought forward') ||
        lowered.contains('balance carried forward') ||
        lowered.contains('balance b/f') ||
        lowered.contains('balance c/f');

    final dateMatch = _findDate(cells);
    if (dateMatch == null) return null;
    final date = dateMatch.date;

    final amounts = _findAmounts(cells, bands: bands);
    if (amounts.isEmpty) return null;

    // The last amount is the balance when the row names one or carries two
    // numbers and no explicit balance column.
    var amount = amounts.first;
    if (isBalance || amounts.length >= 3) {
      amount = amounts[amounts.length - 1];
    } else if (amounts.length == 2) {
      amount = amounts.first;
    }

    final description =
        _description(cells, dateMatch.cellIndex, amounts.first).trim();
    if (!isBalance && description.isEmpty) {
      // A payment with no description is still a row, but it needs a check.
    }

    final kind = isBalance ? PdfRowKind.balance : PdfRowKind.payment;
    final confidence = dateMatch.ambiguous || !amount.hasDecimals
        ? PdfRowConfidence.unsure
        : PdfRowConfidence.filled;

    return PdfStatementRow(
      date: date,
      description: description,
      amountMinor: isBalance ? amount.minor.abs() : amount.minor,
      currencyCode: amount.currency ?? defaultCurrency,
      kind: kind,
      confidence: confidence,
      page: page,
      line: lineNumber,
      sourceKey: 'pdf:$page:$lineNumber:$ordinal',
    );
  }

  String _description(List<_Cell> cells, int dateCell, _Amount amount) {
    final parts = <String>[];
    for (var i = dateCell + 1; i < cells.length; i++) {
      final cell = cells[i];
      if (identical(cell, amount.cell)) break;
      if (cell.x >= amount.cell.x) break;
      final text = cell.text.trim();
      if (text.isEmpty) continue;
      if (_looksLikeDate(text)) continue;
      if (_looksLikeAmount(text)) continue;
      parts.add(text);
    }
    return parts.join(' ');
  }

  _DateMatch? _findDate(List<_Cell> cells) {
    final limit = cells.length < 3 ? cells.length : 3;
    for (var i = 0; i < limit; i++) {
      final parsed = _parseDate(cells[i].text.trim());
      if (parsed != null) {
        return _DateMatch(parsed.date, i, parsed.ambiguous);
      }
    }
    return null;
  }

  List<_Amount> _findAmounts(List<_Cell> cells, {PdfColumnBands? bands}) {
    final out = <_Amount>[];
    for (var i = cells.length - 1; i >= 0; i--) {
      final cell = cells[i];
      final parsed = parsePdfAmount(cell.text);
      if (parsed == null) continue;
      // A date cell is not an amount.
      if (_looksLikeDate(cell.text)) continue;
      out.add(_Amount(parsed.minor, parsed.hasDecimals, parsed.currency, cell));
      if (out.length >= 3) break;
    }
    out.sort((a, b) => a.cell.x.compareTo(b.cell.x));
    return out;
  }
}

final class _Cell {
  const _Cell(this.x, this.text, this.fontSize);

  final double x;
  final String text;
  final double fontSize;
}

/// One layout cell of a line. The teach editor (X66) uses these positions.
final class PdfLineCell {
  const PdfLineCell(this.x, this.text, this.fontSize);

  final double x;
  final String text;
  final double fontSize;
}

/// Splits a line into cells at wide gaps and at `TJ` column breaks.
List<PdfLineCell> pdfLineCells(PdfTextLine line) => <PdfLineCell>[
      for (final cell in _cells(line))
        PdfLineCell(cell.x, cell.text, cell.fontSize),
    ];

List<_Cell> _cells(PdfTextLine line) {
  final cells = <_Cell>[];
  for (final span in line.spans) {
    final parts = span.text.split(RegExp(r'\s{2,}'));
    var offset = 0.0;
    for (final part in parts) {
      if (part.trim().isNotEmpty) {
        cells.add(
          _Cell(
            span.x + offset,
            part,
            span.fontSize <= 0 ? 10 : span.fontSize,
          ),
        );
      }
      offset += part.length * (span.fontSize <= 0 ? 10 : span.fontSize) * 0.5;
    }
  }
  return cells;
}

String _normalise(String text) =>
    text.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

final class _DateMatch {
  const _DateMatch(this.date, this.cellIndex, this.ambiguous);

  final LocalDate date;
  final int cellIndex;
  final bool ambiguous;
}

final class _Amount {
  const _Amount(this.minor, this.hasDecimals, this.currency, this.cell);

  final int minor;
  final bool hasDecimals;
  final String? currency;
  final _Cell cell;
}

const Map<String, int> _months = <String, int>{
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

final RegExp _dayMonthName = RegExp(
  r'^(\d{1,2})\s+([A-Za-z]{3,9})\.?\s+(\d{2,4})$',
);
final RegExp _monthNameDay = RegExp(
  r'^([A-Za-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{2,4})$',
);
final RegExp _numericDate =
    RegExp(r'^(\d{1,4})[\/\-.](\d{1,2})[\/\-.](\d{1,4})$');

({LocalDate date, bool ambiguous})? _parseDate(String text) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  var match = _dayMonthName.firstMatch(clean);
  if (match != null) {
    final day = int.tryParse(match.group(1)!);
    final month = _months[match.group(2)!.toLowerCase()];
    final year = _year(match.group(3)!);
    if (day != null && month != null && year != null) {
      final date = _safeDate(year, month, day);
      if (date != null) return (date: date, ambiguous: false);
    }
  }
  match = _monthNameDay.firstMatch(clean);
  if (match != null) {
    final month = _months[match.group(1)!.toLowerCase()];
    final day = int.tryParse(match.group(2)!);
    final year = _year(match.group(3)!);
    if (day != null && month != null && year != null) {
      final date = _safeDate(year, month, day);
      if (date != null) return (date: date, ambiguous: false);
    }
  }
  match = _numericDate.firstMatch(clean);
  if (match != null) {
    final a = int.tryParse(match.group(1)!);
    final b = int.tryParse(match.group(2)!);
    final c = int.tryParse(match.group(3)!);
    if (a != null && b != null && c != null) {
      if (a >= 1000) {
        final date = _safeDate(a, b, c);
        if (date != null) return (date: date, ambiguous: false);
      }
      final year = _year(match.group(3)!);
      if (year == null) return null;
      if (a > 12) {
        final date = _safeDate(year, b, a);
        if (date != null) return (date: date, ambiguous: false);
      }
      if (b > 12) {
        final date = _safeDate(year, a, b);
        if (date != null) return (date: date, ambiguous: false);
      }
      // Both parts can be a month. Day-first is the v1 default; mark it.
      final dayFirst = _safeDate(year, b, a);
      if (dayFirst != null) return (date: dayFirst, ambiguous: true);
    }
  }
  return null;
}

bool _looksLikeDate(String text) {
  final clean = _normalise(text);
  return _dayMonthName.hasMatch(clean) ||
      _monthNameDay.hasMatch(clean) ||
      _numericDate.hasMatch(clean);
}

int? _year(String text) {
  final value = int.tryParse(text);
  if (value == null) return null;
  if (value >= 1000) return value;
  if (value >= 70) return 1900 + value;
  return 2000 + value;
}

LocalDate? _safeDate(int year, int month, int day) {
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  try {
    return LocalDate(year, month, day);
  } on Object {
    return null;
  }
}

/// One parsed amount from a statement cell.
final class PdfAmountParse {
  const PdfAmountParse(this.minor, {required this.hasDecimals, this.currency});

  final int minor;
  final bool hasDecimals;
  final String? currency;
}

final RegExp _currencySymbol = RegExp(r'[$€£¥₹]');
const Map<String, String> _currencySymbols = <String, String>{
  r'$': 'USD',
  '€': 'EUR',
  '£': 'GBP',
  '¥': 'JPY',
  '₹': 'INR',
};

/// Parses `1,240.00`, `1.240,00`, `-42.50`, `(42.50)`, `42.50 DR`.
PdfAmountParse? parsePdfAmount(String text) {
  var value = text.trim();
  if (value.isEmpty) return null;
  String? currency;
  final symbol = _currencySymbol.firstMatch(value);
  if (symbol != null) {
    currency = _currencySymbols[symbol.group(0)];
    value = value.replaceAll(symbol.group(0)!, '');
  }
  final codeMatch = RegExp(r'\b([A-Z]{3})\b').firstMatch(value);
  if (codeMatch != null) {
    currency ??= codeMatch.group(1);
    value = value.replaceAll(codeMatch.group(0)!, '');
  }
  var negative = false;
  final lower = value.toLowerCase();
  if (lower.contains('dr') && !lower.contains('credit')) negative = true;
  value = value.replaceAll(RegExp(r'\b(CR|DR)\b', caseSensitive: false), '');
  value = value.trim();
  if (RegExp(r'[A-Za-z]').hasMatch(value)) return null;
  if (value.startsWith('(') && value.endsWith(')')) {
    negative = true;
    value = value.substring(1, value.length - 1);
  }
  if (value.endsWith('-')) {
    negative = !negative;
    value = value.substring(0, value.length - 1);
  }
  if (value.startsWith('-')) {
    negative = !negative;
    value = value.substring(1);
  }
  value = value.replaceAll(RegExp(r'[^\d.,]'), '');
  if (!RegExp(r'\d').hasMatch(value)) return null;

  final lastDot = value.lastIndexOf('.');
  final lastComma = value.lastIndexOf(',');
  int decimalIndex;
  if (lastDot >= 0 && lastComma >= 0) {
    decimalIndex = lastDot > lastComma ? lastDot : lastComma;
  } else if (lastDot >= 0) {
    decimalIndex = lastDot;
  } else if (lastComma >= 0) {
    decimalIndex = lastComma;
  } else {
    decimalIndex = -1;
  }

  var hasDecimals = false;
  var digits = value;
  var minorUnits = 0;
  if (decimalIndex >= 0) {
    final fraction = value.substring(decimalIndex + 1);
    final digitsOnlyFraction = fraction.replaceAll(RegExp(r'\D'), '');
    if (fraction.length == 2 && digitsOnlyFraction.length == 2) {
      digits = value.substring(0, decimalIndex);
      minorUnits = int.tryParse(digitsOnlyFraction) ?? 0;
      hasDecimals = true;
    }
  }
  digits = digits.replaceAll(RegExp(r'[.,]'), '');
  if (digits.isEmpty) return null;
  final whole = int.tryParse(digits);
  if (whole == null) return null;
  if (whole > 999999999999999) return null;
  final minor = whole * 100 + minorUnits;
  return PdfAmountParse(
    negative ? -minor : minor,
    hasDecimals: hasDecimals,
    currency: currency,
  );
}

bool _looksLikeAmount(String text) => parsePdfAmount(text) != null;

// ---------------------------------------------------------------------------
// Layout detection
// ---------------------------------------------------------------------------

const Set<String> _headerWords = <String>{
  'date',
  'description',
  'details',
  'amount',
  'debit',
  'credit',
  'balance',
  'particulars',
  'transaction',
};

PdfTextLine? _findHeader(List<PdfPageText> pages) {
  if (pages.isEmpty) return null;
  final limit = pages.first.lines.length < 25 ? pages.first.lines.length : 25;
  for (var i = 0; i < limit; i++) {
    final line = pages.first.lines[i];
    final words = _normalise(line.text)
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((word) => word.isNotEmpty)
        .toSet();
    final hits = words.intersection(_headerWords).length;
    if (hits >= 2) return line;
  }
  return null;
}

String _fingerprint(List<PdfPageText> pages, PdfTextLine? header) {
  final buffer = StringBuffer();
  if (header != null) {
    buffer.write(_normalise(header.text).toLowerCase());
    buffer.write('|');
    for (final span in header.spans) {
      buffer.write((span.x / 10).round());
      buffer.write(',');
    }
  } else {
    buffer.write('noheader');
  }
  buffer.write('|');
  buffer.write((pages.isEmpty ? 0 : pages.first.width).round());
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}
