// P3-07 (SPEC 8.6): the PDF object layer for statement import.
//
// This is a small, read-only PDF reader for statements. It handles the object
// model, the common stream filters and the text operators that a statement
// uses. It never writes a file, never calls the network and never resolves a
// remote resource.
//
// Scope notes, recorded in DECISIONS `P3-PDF-SUBSET`:
//   - Standard security handler, RC4 revisions 2, 3 and 4 only. AES-encrypted
//     files return a typed `unsupportedEncryption` error.
//   - Classic and stream cross-reference tables. A damaged table falls back to
//     a validated object scan.
//   - Flate, ASCIIHex, ASCII85 and RunLength filters. LZW is unsupported.
//
// The parser holds no user text in an error. Callers map [PdfErrorCode] to a
// screen message (X88).
library;

import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

/// A safe PDF failure. It carries a code only (AGENTS 2.6).
enum PdfErrorCode {
  notPdf,
  damaged,
  unsupportedFilter,
  unsupportedEncryption,
  wrongPassword,
  locked,
  noPages,
  tooLarge,
}

final class PdfError implements Exception {
  const PdfError(this.code);

  final PdfErrorCode code;

  @override
  String toString() => 'PdfError(${code.name})';
}

/// The largest file this reader accepts. A statement is far smaller.
const int kPdfMaxBytes = 32 * 1024 * 1024;

/// The largest decompressed stream this reader accepts (bomb guard).
const int kPdfMaxStreamBytes = 64 * 1024 * 1024;

sealed class PdfObject {
  const PdfObject();
}

final class PdfNull extends PdfObject {
  const PdfNull();
}

final class PdfBool extends PdfObject {
  const PdfBool(this.value);

  final bool value;
}

final class PdfNumber extends PdfObject {
  const PdfNumber(this.value);

  final num value;

  int get asInt => value.toInt();
  double get asDouble => value.toDouble();
}

final class PdfName extends PdfObject {
  const PdfName(this.value);

  final String value;
}

final class PdfString extends PdfObject {
  const PdfString(this.bytes);

  final List<int> bytes;
}

final class PdfArray extends PdfObject {
  const PdfArray(this.items);

  final List<PdfObject> items;
}

final class PdfDict extends PdfObject {
  const PdfDict(this.entries);

  final Map<String, PdfObject> entries;

  PdfObject? operator [](String key) => entries[key];

  bool get isEmpty => entries.isEmpty;
}

final class PdfStream extends PdfObject {
  const PdfStream(this.dict, this.bytes);

  final PdfDict dict;
  final List<int> bytes;
}

final class PdfRef extends PdfObject {
  const PdfRef(this.number, this.generation);

  final int number;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is PdfRef &&
      other.number == number &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(number, generation);
}

// ---------------------------------------------------------------------------
// Lexer
// ---------------------------------------------------------------------------

enum PdfTokenKind {
  eof,
  number,
  name,
  string,
  keyword,
  arrayOpen,
  arrayClose,
  dictOpen,
  dictClose,
}

final class PdfToken {
  const PdfToken(
    this.kind, {
    this.text = '',
    this.bytes = const <int>[],
    this.number,
  });

  final PdfTokenKind kind;
  final String text;
  final List<int> bytes;
  final num? number;

  bool isKeyword(String value) => kind == PdfTokenKind.keyword && text == value;
}

bool _isWhitespace(int c) =>
    c == 0x00 || c == 0x09 || c == 0x0A || c == 0x0C || c == 0x0D || c == 0x20;

bool _isDelimiter(int c) =>
    c == 0x28 ||
    c == 0x29 ||
    c == 0x3C ||
    c == 0x3E ||
    c == 0x5B ||
    c == 0x5D ||
    c == 0x7B ||
    c == 0x7D ||
    c == 0x2F ||
    c == 0x25;

int _hexValue(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  return -1;
}

/// A byte lexer for PDF syntax and content streams.
final class PdfLexer {
  PdfLexer(List<int> bytes)
      : bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        position = 0;

  final Uint8List bytes;

  /// The current read position.
  int position;

  bool get isAtEnd => position >= bytes.length;

  void _skipWhitespace() {
    while (position < bytes.length) {
      final c = bytes[position];
      if (_isWhitespace(c)) {
        position++;
        continue;
      }
      if (c == 0x25) {
        // Comment to end of line.
        while (position < bytes.length &&
            bytes[position] != 0x0A &&
            bytes[position] != 0x0D) {
          position++;
        }
        continue;
      }
      break;
    }
  }

  PdfToken next() {
    _skipWhitespace();
    if (position >= bytes.length) {
      return const PdfToken(PdfTokenKind.eof);
    }
    final c = bytes[position];
    if (c == 0x5B) {
      position++;
      return const PdfToken(PdfTokenKind.arrayOpen);
    }
    if (c == 0x5D) {
      position++;
      return const PdfToken(PdfTokenKind.arrayClose);
    }
    if (c == 0x3C) {
      if (position + 1 < bytes.length && bytes[position + 1] == 0x3C) {
        position += 2;
        return const PdfToken(PdfTokenKind.dictOpen);
      }
      return PdfToken(PdfTokenKind.string, bytes: _readHexString());
    }
    if (c == 0x3E) {
      if (position + 1 < bytes.length && bytes[position + 1] == 0x3E) {
        position += 2;
        return const PdfToken(PdfTokenKind.dictClose);
      }
      // A stray '>' is damage; skip it so a scan can continue.
      position++;
      return next();
    }
    if (c == 0x2F) {
      position++;
      return PdfToken(PdfTokenKind.name, text: _readName());
    }
    if (c == 0x28) {
      position++;
      return PdfToken(PdfTokenKind.string, bytes: _readLiteralString());
    }
    if (c == 0x2B || c == 0x2D || c == 0x2E || (c >= 0x30 && c <= 0x39)) {
      final token = _tryReadNumber();
      if (token != null) return token;
    }
    return PdfToken(PdfTokenKind.keyword, text: _readKeyword());
  }

  PdfToken? _tryReadNumber() {
    final start = position;
    if (bytes[position] == 0x2B || bytes[position] == 0x2D) position++;
    var digits = 0;
    var dot = false;
    while (position < bytes.length) {
      final c = bytes[position];
      if (c >= 0x30 && c <= 0x39) {
        digits++;
        position++;
      } else if (c == 0x2E && !dot) {
        dot = true;
        position++;
      } else {
        break;
      }
    }
    if (digits == 0) {
      position = start;
      return null;
    }
    final text = latin1.decode(bytes.sublist(start, position));
    final value = dot ? double.tryParse(text) : int.tryParse(text);
    if (value == null) {
      position = start;
      return null;
    }
    return PdfToken(PdfTokenKind.number, text: text, number: value);
  }

  String _readName() {
    final out = <int>[];
    while (position < bytes.length) {
      final c = bytes[position];
      if (_isWhitespace(c) || _isDelimiter(c)) break;
      if (c == 0x23 && position + 2 < bytes.length) {
        final hi = _hexValue(bytes[position + 1]);
        final lo = _hexValue(bytes[position + 2]);
        if (hi >= 0 && lo >= 0) {
          out.add(hi * 16 + lo);
          position += 3;
          continue;
        }
      }
      out.add(c);
      position++;
    }
    return latin1.decode(out);
  }

  String _readKeyword() {
    final start = position;
    while (position < bytes.length) {
      final c = bytes[position];
      if (_isWhitespace(c) || _isDelimiter(c)) break;
      position++;
    }
    if (start == position) {
      // Unknown delimiter; consume one byte and continue.
      position++;
      return latin1.decode(bytes.sublist(start, position));
    }
    return latin1.decode(bytes.sublist(start, position));
  }

  List<int> _readHexString() {
    position++; // '<'
    final out = <int>[];
    var hi = -1;
    while (position < bytes.length) {
      final c = bytes[position];
      position++;
      if (c == 0x3E) break;
      final value = _hexValue(c);
      if (value < 0) continue;
      if (hi < 0) {
        hi = value;
      } else {
        out.add(hi * 16 + value);
        hi = -1;
      }
    }
    if (hi >= 0) out.add(hi * 16);
    return out;
  }

  List<int> _readLiteralString() {
    final out = <int>[];
    var depth = 1;
    while (position < bytes.length && depth > 0) {
      final c = bytes[position];
      position++;
      if (c == 0x5C) {
        if (position >= bytes.length) break;
        final escaped = bytes[position];
        position++;
        switch (escaped) {
          case 0x6E:
            out.add(0x0A);
          case 0x72:
            out.add(0x0D);
          case 0x74:
            out.add(0x09);
          case 0x62:
            out.add(0x08);
          case 0x66:
            out.add(0x0C);
          case 0x28:
          case 0x29:
          case 0x5C:
            out.add(escaped);
          case 0x0D:
            if (position < bytes.length && bytes[position] == 0x0A) position++;
          case 0x0A:
            break;
          default:
            if (escaped >= 0x30 && escaped <= 0x37) {
              var value = escaped - 0x30;
              for (var i = 0; i < 2 && position < bytes.length; i++) {
                final next = bytes[position];
                if (next < 0x30 || next > 0x37) break;
                value = value * 8 + (next - 0x30);
                position++;
              }
              out.add(value & 0xFF);
            } else {
              out.add(escaped);
            }
        }
        continue;
      }
      if (c == 0x28) {
        depth++;
        out.add(c);
        continue;
      }
      if (c == 0x29) {
        depth--;
        if (depth == 0) break;
        out.add(c);
        continue;
      }
      out.add(c);
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Object parser
// ---------------------------------------------------------------------------

/// Builds [PdfObject] values from a lexer.
final class PdfObjectParser {
  PdfObjectParser(this._lexer);

  final PdfLexer _lexer;
  final List<PdfToken> _buffer = <PdfToken>[];

  PdfLexer get lexer => _lexer;

  PdfToken peek([int index = 0]) {
    while (_buffer.length <= index) {
      _buffer.add(_lexer.next());
    }
    return _buffer[index];
  }

  PdfToken take() {
    if (_buffer.isNotEmpty) return _buffer.removeAt(0);
    return _lexer.next();
  }

  /// Drops buffered look-ahead tokens after a manual [PdfLexer.position] jump.
  void clearBuffer() => _buffer.clear();

  PdfObject parseObject() {
    final token = peek();
    switch (token.kind) {
      case PdfTokenKind.eof:
        return const PdfNull();
      case PdfTokenKind.number:
        // A reference is `int int R`.
        if (token.number is int) {
          final second = peek(1);
          final third = peek(2);
          if (second.kind == PdfTokenKind.number &&
              second.number is int &&
              third.isKeyword('R')) {
            take();
            take();
            take();
            return PdfRef(token.number!.toInt(), second.number!.toInt());
          }
        }
        take();
        return PdfNumber(token.number!);
      case PdfTokenKind.name:
        take();
        return PdfName(token.text);
      case PdfTokenKind.string:
        take();
        return PdfString(token.bytes);
      case PdfTokenKind.arrayOpen:
        take();
        final items = <PdfObject>[];
        while (true) {
          final next = peek();
          if (next.kind == PdfTokenKind.arrayClose) {
            take();
            break;
          }
          if (next.kind == PdfTokenKind.eof) break;
          items.add(parseObject());
        }
        return PdfArray(items);
      case PdfTokenKind.dictOpen:
        take();
        return parseDictBody();
      case PdfTokenKind.dictClose:
      case PdfTokenKind.arrayClose:
        take();
        return const PdfNull();
      case PdfTokenKind.keyword:
        take();
        return switch (token.text) {
          'true' => const PdfBool(true),
          'false' => const PdfBool(false),
          'null' => const PdfNull(),
          _ => const PdfNull(),
        };
    }
  }

  PdfDict parseDictBody() {
    final entries = <String, PdfObject>{};
    while (true) {
      final token = peek();
      if (token.kind == PdfTokenKind.dictClose) {
        take();
        break;
      }
      if (token.kind == PdfTokenKind.eof) break;
      if (token.kind != PdfTokenKind.name) {
        // Skip damaged content inside a dictionary.
        take();
        continue;
      }
      take();
      entries[token.text] = parseObject();
    }
    return PdfDict(entries);
  }
}

// ---------------------------------------------------------------------------
// Stream filters
// ---------------------------------------------------------------------------

List<String> _filterNames(PdfObject? value) {
  if (value is PdfName) return <String>[value.value];
  if (value is PdfArray) {
    return <String>[
      for (final item in value.items)
        if (item is PdfName) item.value,
    ];
  }
  return const <String>[];
}

PdfDict? _asDict(PdfObject? value) => value is PdfDict ? value : null;

/// Decodes stream bytes through every filter in `/Filter`.
List<int> decodePdfStream(PdfStream stream) {
  var data = stream.bytes;
  final filters = _filterNames(stream.dict['Filter']);
  final parmsValue = stream.dict['DecodeParms'];
  final parms = <PdfDict?>[];
  if (parmsValue is PdfDict) {
    parms.add(parmsValue);
  } else if (parmsValue is PdfArray) {
    for (final item in parmsValue.items) {
      parms.add(_asDict(item));
    }
  }
  for (var i = 0; i < filters.length; i++) {
    final filter = filters[i];
    final parm = i < parms.length ? parms[i] : null;
    data = switch (filter) {
      'FlateDecode' || 'Fl' => _inflate(data),
      'ASCIIHexDecode' || 'AHx' => _asciiHex(data),
      'ASCII85Decode' || 'A85' => _ascii85(data),
      'RunLengthDecode' || 'RL' => _runLength(data),
      _ => throw const PdfError(PdfErrorCode.unsupportedFilter),
    };
    if (parm != null) {
      data = _applyPredictor(data, parm);
    }
    if (data.length > kPdfMaxStreamBytes) {
      throw const PdfError(PdfErrorCode.tooLarge);
    }
  }
  return data;
}

List<int> _inflate(List<int> data) {
  try {
    return ZLibDecoder().convert(data);
  } on Object {
    try {
      return ZLibDecoder(raw: true).convert(data);
    } on Object {
      throw const PdfError(PdfErrorCode.damaged);
    }
  }
}

List<int> _asciiHex(List<int> data) {
  final out = <int>[];
  var high = -1;
  for (final c in data) {
    if (c == 0x3E) break; // '>'
    final value = _hexValue(c);
    if (value < 0) continue;
    if (high < 0) {
      high = value;
    } else {
      out.add(high * 16 + value);
      high = -1;
    }
  }
  if (high >= 0) out.add(high * 16);
  return out;
}

List<int> _ascii85(List<int> data) {
  final out = <int>[];
  var tuple = 0;
  var count = 0;
  var started = false;
  for (var i = 0; i < data.length; i++) {
    final c = data[i];
    if (c == 0x7E) break; // '~'
    if (_isWhitespace(c)) continue;
    if (c == 0x3C && i + 1 < data.length && data[i + 1] == 0x7E) {
      started = true;
      i++;
      continue;
    }
    if (!started) continue;
    if (c == 0x7A && count == 0) {
      out.addAll(const <int>[0, 0, 0, 0]);
      continue;
    }
    if (c < 0x21 || c > 0x75) continue;
    tuple = tuple * 85 + (c - 0x21);
    count++;
    if (count == 5) {
      out.add((tuple >> 24) & 0xFF);
      out.add((tuple >> 16) & 0xFF);
      out.add((tuple >> 8) & 0xFF);
      out.add(tuple & 0xFF);
      tuple = 0;
      count = 0;
    }
  }
  if (count > 1) {
    for (var i = count; i < 5; i++) {
      tuple = tuple * 85 + 84;
    }
    final bytes = <int>[
      (tuple >> 24) & 0xFF,
      (tuple >> 16) & 0xFF,
      (tuple >> 8) & 0xFF,
      tuple & 0xFF,
    ];
    out.addAll(bytes.sublist(0, count - 1));
  }
  return out;
}

List<int> _runLength(List<int> data) {
  final out = <int>[];
  var i = 0;
  while (i < data.length) {
    final length = data[i++];
    if (length == 128) break;
    if (length < 128) {
      final count = length + 1;
      for (var j = 0; j < count && i < data.length; j++) {
        out.add(data[i++]);
      }
    } else {
      if (i >= data.length) break;
      final value = data[i++];
      for (var j = 0; j < 257 - length; j++) {
        out.add(value);
      }
    }
  }
  return out;
}

List<int> _applyPredictor(List<int> data, PdfDict parms) {
  final predictor = _intOf(parms['Predictor']) ?? 1;
  if (predictor <= 1) return data;
  final colors = _intOf(parms['Colors']) ?? 1;
  final bits = _intOf(parms['BitsPerComponent']) ?? 8;
  final columns = _intOf(parms['Columns']) ?? 1;
  final bytesPerPixel = ((colors * bits) + 7) ~/ 8;
  final rowLength = ((colors * bits * columns) + 7) ~/ 8;
  if (rowLength <= 0) return data;

  if (predictor == 2) {
    // TIFF predictor, 8-bit components only.
    if (bits != 8) return data;
    final out = List<int>.from(data);
    for (var row = 0; row * rowLength < out.length; row++) {
      final start = row * rowLength;
      for (var i = bytesPerPixel; i < rowLength; i++) {
        final index = start + i;
        if (index < out.length) {
          out[index] = (out[index] + out[index - bytesPerPixel]) & 0xFF;
        }
      }
    }
    return out;
  }

  final out = <int>[];
  var previous = List<int>.filled(rowLength, 0);
  var offset = 0;
  while (offset < data.length) {
    final filter = data[offset++];
    final row = List<int>.filled(rowLength, 0);
    for (var i = 0; i < rowLength && offset < data.length; i++) {
      row[i] = data[offset++];
    }
    for (var i = 0; i < rowLength; i++) {
      final left = i >= bytesPerPixel ? row[i - bytesPerPixel] : 0;
      final up = previous[i];
      final upLeft = i >= bytesPerPixel ? previous[i - bytesPerPixel] : 0;
      row[i] = switch (filter) {
        0 => row[i],
        1 => (row[i] + left) & 0xFF,
        2 => (row[i] + up) & 0xFF,
        3 => (row[i] + ((left + up) ~/ 2)) & 0xFF,
        4 => (row[i] + _paeth(left, up, upLeft)) & 0xFF,
        _ => row[i],
      };
    }
    out.addAll(row);
    previous = row;
  }
  return out;
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

int? _intOf(PdfObject? value) {
  if (value is PdfNumber) return value.asInt;
  return null;
}
