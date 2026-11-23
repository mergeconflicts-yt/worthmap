// P3-07 (SPEC 8.6): text and line extraction from a statement PDF.
//
// The extractor reads the page content stream operators that place text
// (`BT`, `Tf`, `Tm`, `Td`, `TG`, `Tj`, `TJ`, `'`, `"`) and returns spans with
// their approximate position. Lines group spans by their vertical position.
// It does not lay out glyphs and does not use a font metrics table; a wide
// kerning gap inside `TJ` becomes a column gap.
library;

import 'dart:convert';

import 'pdf_document.dart';
import 'pdf_objects.dart';

/// One run of text at one position.
final class PdfSpan {
  const PdfSpan({
    required this.x,
    required this.y,
    required this.text,
    required this.fontSize,
  });

  final double x;
  final double y;
  final String text;
  final double fontSize;
}

/// Spans that share one baseline.
final class PdfTextLine {
  PdfTextLine(this.y, this.spans);

  final double y;
  final List<PdfSpan> spans;

  /// The line text. Two or more spaces mark a layout gap; the statement parser
  /// reads them as a column break.
  String get text {
    final buffer = StringBuffer();
    PdfSpan? previous;
    for (final span in spans) {
      if (previous != null) {
        final gap = span.x - (previous.x + _estimateWidth(previous));
        if (gap > previous.fontSize * 1.6) {
          buffer.write('  ');
        } else if (buffer.isNotEmpty && !buffer.toString().endsWith(' ')) {
          buffer.write(' ');
        }
      }
      buffer.write(span.text);
      previous = span;
    }
    return buffer.toString().trim();
  }

  static double _estimateWidth(PdfSpan span) =>
      span.text.length * span.fontSize * 0.5;
}

/// All lines of one page.
final class PdfPageText {
  const PdfPageText({
    required this.pageNumber,
    required this.width,
    required this.lines,
  });

  final int pageNumber;
  final double width;
  final List<PdfTextLine> lines;

  bool get isEmpty => lines.every((line) => line.text.trim().isEmpty);
}

/// Reads every page of an open document.
List<PdfPageText> extractPdfText(PdfDocument document) {
  final pages = <PdfPageText>[];
  for (final page in document.pages) {
    final spans = _readSpans(document, page);
    pages.add(
      PdfPageText(
        pageNumber: page.number,
        width: page.width,
        lines: _groupLines(spans),
      ),
    );
  }
  return pages;
}

List<PdfSpan> _readSpans(PdfDocument document, PdfPage page) {
  final spans = <PdfSpan>[];
  final fonts = <String, PdfFontDecoder>{};
  final resources = page.resources;
  final fontDict = document.resolveDict(resources['Font']);

  PdfFontDecoder fontFor(String name) => fonts.putIfAbsent(name, () {
        final font = document.resolveDict(fontDict?[name]);
        return PdfFontDecoder.build(document, font);
      });

  final parser = PdfObjectParser(PdfLexer(page.content));
  final operands = <PdfObject>[];
  final state = _TextState();

  void draw(List<int> bytes, PdfFontDecoder decoder) {
    final text = decoder.decode(bytes);
    if (text.isEmpty) return;
    spans.add(
      PdfSpan(x: state.x, y: state.y, text: text, fontSize: state.fontSize),
    );
  }

  while (true) {
    final token = parser.peek();
    if (token.kind == PdfTokenKind.eof) break;
    if (token.kind == PdfTokenKind.keyword) {
      parser.take();
      final operator = token.text;
      switch (operator) {
        case 'BT':
          state.reset();
        case 'Tf':
          if (operands.length >= 2) {
            final name = operands[operands.length - 2];
            final size = operands.last;
            state.fontName = name is PdfName ? name.value : state.fontName;
            state.fontSize = size is PdfNumber ? size.asDouble : state.fontSize;
          }
        case 'Tm':
          if (operands.length >= 6) {
            final e = operands[operands.length - 2];
            final f = operands.last;
            if (e is PdfNumber) state.x = e.asDouble;
            if (f is PdfNumber) state.y = f.asDouble;
          }
        case 'Td':
        case 'TD':
          if (operands.length >= 2) {
            final tx = operands[operands.length - 2];
            final ty = operands.last;
            if (tx is PdfNumber) state.x += tx.asDouble;
            if (ty is PdfNumber) {
              state.y += ty.asDouble;
              if (operator == 'TD') state.leading = -ty.asDouble;
            }
          }
        case 'T*':
          state.y -= state.leading;
        case 'TL':
          if (operands.isNotEmpty && operands.last is PdfNumber) {
            state.leading = (operands.last as PdfNumber).asDouble;
          }
        case 'Tj':
          if (operands.isNotEmpty && operands.last is PdfString) {
            draw((operands.last as PdfString).bytes, fontFor(state.fontName));
          }
        case 'TJ':
          if (operands.isNotEmpty && operands.last is PdfArray) {
            final decoder = fontFor(state.fontName);
            final buffer = <int>[];
            for (final item in (operands.last as PdfArray).items) {
              if (item is PdfString) {
                buffer.addAll(item.bytes);
              } else if (item is PdfNumber && item.value <= -120) {
                buffer.addAll(const <int>[0x20, 0x20]);
              }
            }
            if (buffer.isNotEmpty) draw(buffer, decoder);
          }
        case "'":
          state.y -= state.leading;
          if (operands.isNotEmpty && operands.last is PdfString) {
            draw((operands.last as PdfString).bytes, fontFor(state.fontName));
          }
        case '"':
          state.y -= state.leading;
          if (operands.isNotEmpty && operands.last is PdfString) {
            draw((operands.last as PdfString).bytes, fontFor(state.fontName));
          }
        default:
          break;
      }
      operands.clear();
      continue;
    }
    operands.add(parser.parseObject());
  }
  return spans;
}

final class _TextState {
  double x = 0;
  double y = 0;
  double leading = 0;
  double fontSize = 10;
  String fontName = '';

  void reset() {
    x = 0;
    y = 0;
    leading = 0;
  }
}

List<PdfTextLine> _groupLines(List<PdfSpan> spans) {
  if (spans.isEmpty) return const <PdfTextLine>[];
  final sorted = List<PdfSpan>.from(spans)
    ..sort((a, b) {
      final byY = b.y.compareTo(a.y);
      if (byY != 0) return byY;
      return a.x.compareTo(b.x);
    });
  final lines = <PdfTextLine>[];
  var current = <PdfSpan>[sorted.first];
  var currentY = sorted.first.y;
  for (var i = 1; i < sorted.length; i++) {
    final span = sorted[i];
    final tolerance = span.fontSize > 0 ? span.fontSize * 0.45 : 4.0;
    if ((currentY - span.y).abs() <= tolerance) {
      current.add(span);
    } else {
      current.sort((a, b) => a.x.compareTo(b.x));
      lines.add(PdfTextLine(currentY, List<PdfSpan>.unmodifiable(current)));
      current = <PdfSpan>[span];
      currentY = span.y;
    }
  }
  current.sort((a, b) => a.x.compareTo(b.x));
  lines.add(PdfTextLine(currentY, List<PdfSpan>.unmodifiable(current)));
  return lines;
}

// ---------------------------------------------------------------------------
// Font decoding
// ---------------------------------------------------------------------------

/// Decodes a font's byte codes to Unicode text.
final class PdfFontDecoder {
  PdfFontDecoder._(this._map, this._twoByte);

  final Map<int, String> _map;
  final bool _twoByte;

  static PdfFontDecoder build(PdfDocument document, PdfDict? font) {
    final map = <int, String>{};
    var twoByte = false;
    if (font != null) {
      final subtype = font['Subtype'];
      twoByte = subtype is PdfName && subtype.value == 'Type0';

      final toUnicode = document.resolveStream(font['ToUnicode']);
      if (toUnicode != null) {
        try {
          _readCMap(document.streamData(toUnicode), map);
        } on PdfError {
          // A broken CMap falls back to the encoding table.
        }
      }

      final encoding = font['Encoding'];
      if (encoding is PdfName && encoding.value == 'WinAnsiEncoding') {
        _applyWinAnsi(map, overwrite: false);
      } else if (encoding is PdfDict) {
        final base = encoding['BaseEncoding'];
        if (base is PdfName && base.value == 'WinAnsiEncoding') {
          _applyWinAnsi(map, overwrite: false);
        }
        final differences = encoding['Differences'];
        if (differences is PdfArray) {
          var code = 0;
          for (final item in differences.items) {
            if (item is PdfNumber) {
              code = item.asInt;
            } else if (item is PdfName) {
              final char = glyphToText(item.value);
              if (char != null) map[code] = char;
              code++;
            }
          }
        }
      }
    }
    return PdfFontDecoder._(map, twoByte);
  }

  String decode(List<int> bytes) {
    final buffer = StringBuffer();
    if (_twoByte) {
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        final code = (bytes[i] << 8) | bytes[i + 1];
        final mapped = _map[code];
        buffer.write(mapped ?? '');
      }
      return buffer.toString();
    }
    for (final byte in bytes) {
      final mapped = _map[byte];
      buffer.write(mapped ?? winAnsiChar(byte));
    }
    return buffer.toString();
  }
}

void _applyWinAnsi(Map<int, String> map, {required bool overwrite}) {
  for (var code = 32; code < 256; code++) {
    if (!overwrite && map.containsKey(code)) continue;
    map[code] = winAnsiChar(code);
  }
}

const Map<int, String> _winAnsiSpecials = <int, String>{
  0x80: '\u20AC',
  0x82: '\u201A',
  0x83: '\u0192',
  0x84: '\u201E',
  0x85: '\u2026',
  0x86: '\u2020',
  0x87: '\u2021',
  0x88: '\u02C6',
  0x89: '\u2030',
  0x8A: '\u0160',
  0x8B: '\u2039',
  0x8C: '\u0152',
  0x8E: '\u017D',
  0x91: '\u2018',
  0x92: '\u2019',
  0x93: '\u201C',
  0x94: '\u201D',
  0x95: '\u2022',
  0x96: '\u2013',
  0x97: '\u2014',
  0x98: '\u02DC',
  0x99: '\u2122',
  0x9A: '\u0161',
  0x9B: '\u203A',
  0x9C: '\u0153',
  0x9E: '\u017E',
  0x9F: '\u0178',
};

String winAnsiChar(int code) {
  if (code < 0x20) return '';
  if (code < 0x7F) return String.fromCharCode(code);
  final special = _winAnsiSpecials[code];
  if (special != null) return special;
  if (code >= 0xA0) return String.fromCharCode(code);
  return '';
}

const Map<String, String> _glyphNames = <String, String>{
  'space': ' ',
  'exclam': '!',
  'quotedbl': '"',
  'numbersign': '#',
  'dollar': r'$',
  'percent': '%',
  'ampersand': '&',
  'quotesingle': "'",
  'quoteright': '\u2019',
  'quoteleft': '\u2018',
  'parenleft': '(',
  'parenright': ')',
  'asterisk': '*',
  'plus': '+',
  'comma': ',',
  'hyphen': '-',
  'minus': '-',
  'period': '.',
  'slash': '/',
  'zero': '0',
  'one': '1',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'nine': '9',
  'colon': ':',
  'semicolon': ';',
  'less': '<',
  'equal': '=',
  'greater': '>',
  'question': '?',
  'at': '@',
  'bracketleft': '[',
  'backslash': r'\',
  'bracketright': ']',
  'asciicircum': '^',
  'underscore': '_',
  'grave': '`',
  'braceleft': '{',
  'bar': '|',
  'braceright': '}',
  'asciitilde': '~',
  'Euro': '\u20AC',
  'sterling': '\u00A3',
  'yen': '\u00A5',
  'cent': '\u00A2',
  'endash': '\u2013',
  'emdash': '\u2014',
  'bullet': '\u2022',
  'ellipsis': '\u2026',
};

String? glyphToText(String name) {
  final direct = _glyphNames[name];
  if (direct != null) return direct;
  if (name.startsWith('uni') && name.length >= 7) {
    final code = int.tryParse(name.substring(3, 7), radix: 16);
    if (code != null) return String.fromCharCode(code);
  }
  if (name.startsWith('u') && name.length >= 5) {
    final code = int.tryParse(name.substring(1, 5), radix: 16);
    if (code != null) return String.fromCharCode(code);
  }
  if (name.length == 1) return name;
  return null;
}

// ---------------------------------------------------------------------------
// CMap parsing
// ---------------------------------------------------------------------------

void _readCMap(List<int> data, Map<int, String> out) {
  final text = latin1.decode(data, allowInvalid: true);
  _readCMapSection(text, 'beginbfchar', 'endbfchar', out);
  _readCMapSection(text, 'beginbfrange', 'endbfrange', out);
}

void _readCMapSection(
  String text,
  String open,
  String close,
  Map<int, String> out,
) {
  var index = 0;
  while (true) {
    final start = text.indexOf(open, index);
    if (start < 0) break;
    final end = text.indexOf(close, start + open.length);
    if (end < 0) break;
    final body = text.substring(start + open.length, end);
    if (open == 'beginbfchar') {
      _readBfChar(body, out);
    } else {
      _readBfRange(body, out);
    }
    index = end + close.length;
  }
}

final RegExp _hexPair = RegExp(r'<([0-9A-Fa-f\s]*)>');

void _readBfChar(String body, Map<int, String> out) {
  final matches = _hexPair.allMatches(body).toList();
  for (var i = 0; i + 1 < matches.length; i += 2) {
    final source = _hexToBytes(matches[i].group(1)!);
    final target = _hexToBytes(matches[i + 1].group(1)!);
    if (source.isEmpty) continue;
    out[_codeValue(source)] = _utf16(target);
  }
}

void _readBfRange(String body, Map<int, String> out) {
  // `<lo> <hi> <target>` or `<lo> <hi> [<t1> <t2> ...]`.
  final head = RegExp(
    r'<([0-9A-Fa-f\s]*)>\s*<([0-9A-Fa-f\s]*)>\s*(\[[^\]]*\]|<[0-9A-Fa-f\s]*>)',
  );
  for (final match in head.allMatches(body)) {
    final low = _codeValue(_hexToBytes(match.group(1)!));
    final high = _codeValue(_hexToBytes(match.group(2)!));
    if (high < low || high - low > 65535) continue;
    final target = match.group(3)!;
    if (target.startsWith('[')) {
      final items = _hexPair
          .allMatches(target)
          .map((m) => _utf16(_hexToBytes(m.group(1)!)))
          .toList();
      for (var code = low; code <= high; code++) {
        final offset = code - low;
        if (offset < items.length) out[code] = items[offset];
      }
    } else {
      final bytes = _hexToBytes(target.substring(1, target.length - 1));
      final base = _codeValue(bytes);
      for (var code = low; code <= high; code++) {
        final value = base + (code - low);
        out[code] = bytes.length <= 1
            ? String.fromCharCode(value)
            : _utf16(_intToBytes(value, bytes.length));
      }
    }
  }
}

int _codeValue(List<int> bytes) {
  var value = 0;
  for (final byte in bytes) {
    value = (value << 8) | byte;
  }
  return value;
}

String _utf16(List<int> bytes) {
  if (bytes.isEmpty) return '';
  final buffer = StringBuffer();
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    buffer.writeCharCode((bytes[i] << 8) | bytes[i + 1]);
  }
  if (bytes.length.isOdd) buffer.writeCharCode(bytes.last);
  return buffer.toString();
}

List<int> _hexToBytes(String text) {
  final digits = <int>[];
  for (final unit in text.codeUnits) {
    final value = _hexDigit(unit);
    if (value >= 0) digits.add(value);
  }
  final out = <int>[];
  for (var i = 0; i + 1 < digits.length; i += 2) {
    out.add(digits[i] * 16 + digits[i + 1]);
  }
  if (digits.length.isOdd) out.add(digits.last * 16);
  return out;
}

int _hexDigit(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  return -1;
}

List<int> _intToBytes(int value, int length) {
  final out = List<int>.filled(length, 0);
  for (var i = length - 1; i >= 0; i--) {
    out[i] = value & 0xFF;
    value >>= 8;
  }
  return out;
}
