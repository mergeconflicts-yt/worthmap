// P3-07 (SPEC 8.6): the PDF document layer for statement import.
//
// Open a PDF, find its pages and decode their content streams. The reader is
// deliberately narrow: statements, not arbitrary documents. It never resolves
// a URL or runs a script action.
library;

import 'dart:typed_data';

import 'pdf_crypto.dart';
import 'pdf_objects.dart';

/// One page of a PDF document.
final class PdfPage {
  PdfPage({
    required this.number,
    required this.dict,
    required this.resources,
    required List<int> content,
  }) : content = List<int>.unmodifiable(content);

  /// 1-based page number.
  final int number;
  final PdfDict dict;
  final PdfDict resources;

  /// The decoded content stream(s), joined with a newline.
  final List<int> content;

  double get width {
    final box = dict['MediaBox'];
    if (box is PdfArray && box.items.length >= 4) {
      final x0 = _num(box.items[0]);
      final x1 = _num(box.items[2]);
      if (x0 != null && x1 != null && x1 > x0) return x1 - x0;
    }
    return 612;
  }
}

double? _num(PdfObject? value) => value is PdfNumber ? value.asDouble : null;

/// An open, read-only PDF.
final class PdfDocument {
  PdfDocument._({
    required Map<int, PdfObject> objects,
    required PdfDict trailer,
    required this.pages,
    required this.encrypted,
    required this.hasTextOperators,
  })  : _objects = objects,
        _trailer = trailer;

  final Map<int, PdfObject> _objects;
  final PdfDict _trailer;
  final List<PdfPage> pages;
  final bool encrypted;
  final bool hasTextOperators;

  /// Opens a PDF from local bytes.
  ///
  /// Throws [PdfError] with a safe code. A locked file needs a password; a
  /// wrong password is [PdfErrorCode.wrongPassword].
  static PdfDocument open(List<int> bytes, {String? password}) {
    if (bytes.isEmpty) throw const PdfError(PdfErrorCode.notPdf);
    if (bytes.length > kPdfMaxBytes) {
      throw const PdfError(PdfErrorCode.tooLarge);
    }
    final data = asPdfBytes(bytes);
    if (!_looksLikePdf(data)) {
      throw const PdfError(PdfErrorCode.notPdf);
    }

    final scan = _scan(data);
    if (scan.objects.isEmpty) throw const PdfError(PdfErrorCode.damaged);

    var objects = scan.objects;
    var trailer = scan.trailer ?? const PdfDict(<String, PdfObject>{});
    final encryptValue = _resolveRaw(trailer['Encrypt'], objects);
    PdfDecryptor? decryptor;
    var encryptObject = -1;
    if (encryptValue is PdfDict) {
      final encryptRef = trailer['Encrypt'];
      if (encryptRef is PdfRef) encryptObject = encryptRef.number;
      final id = pdfFileId(trailer);
      decryptor = PdfDecryptor.create(
        encrypt: encryptValue,
        fileId: id,
        password: password,
      );
    }

    if (decryptor != null) {
      final decrypted = <int, PdfObject>{};
      for (final entry in objects.entries) {
        decrypted[entry.key] = entry.key == encryptObject
            ? entry.value
            : _decryptObject(entry.key, entry.value, decryptor);
      }
      objects = decrypted;
    }

    // Objects inside object streams are new after decryption.
    _expandObjectStreams(objects);

    final document = PdfDocument._(
      objects: objects,
      trailer: trailer,
      pages: const <PdfPage>[],
      encrypted: decryptor != null,
      hasTextOperators: false,
    );
    return document._withPages();
  }

  PdfDocument _withPages() {
    var rootValue = _trailer['Root'];
    var root = resolveDict(rootValue);
    if (root == null) {
      for (final object in _objects.values) {
        final dict = object is PdfStream ? object.dict : object;
        if (dict is PdfDict && _isCatalog(dict)) {
          root = dict;
          break;
        }
      }
    }
    if (root == null) throw const PdfError(PdfErrorCode.damaged);

    final pages = <PdfPage>[];
    final seen = <int>{};
    void visit(PdfObject? node, PdfDict? inherited, int depth) {
      if (depth > 32 || pages.length >= 200) return;
      final dict = resolveDict(node);
      if (dict == null) return;
      final ref = node is PdfRef ? node.number : null;
      if (ref != null && !seen.add(ref)) return;
      final resources = resolveDict(dict['Resources']) ?? inherited;
      final kids = resolve(dict['Kids']);
      final isPages = dict['Type'] is PdfName &&
          (dict['Type']! as PdfName).value == 'Pages';
      if (kids is PdfArray && (isPages || dict['Kids'] != null)) {
        for (final kid in kids.items) {
          visit(kid, resources, depth + 1);
        }
        return;
      }
      pages.add(
        PdfPage(
          number: pages.length + 1,
          dict: dict,
          resources: resources ?? const PdfDict(<String, PdfObject>{}),
          content: _pageContent(dict),
        ),
      );
    }

    final pagesNode = root['Pages'];
    visit(pagesNode, null, 0);
    if (pages.isEmpty) {
      // Some damaged files point straight at one page.
      for (final object in _objects.values) {
        final dict = object is PdfStream ? object.dict : object;
        if (dict is PdfDict &&
            dict['Type'] is PdfName &&
            (dict['Type']! as PdfName).value == 'Page') {
          visit(dict, null, 0);
          break;
        }
      }
    }
    if (pages.isEmpty) throw const PdfError(PdfErrorCode.noPages);

    return PdfDocument._(
      objects: _objects,
      trailer: _trailer,
      pages: List<PdfPage>.unmodifiable(pages),
      encrypted: encrypted,
      hasTextOperators: pages.any((page) => page.content.isNotEmpty),
    );
  }

  bool _isCatalog(PdfDict dict) {
    final type = dict['Type'];
    return type is PdfName && type.value == 'Catalog';
  }

  /// Follows references until an object or a missing reference is found.
  PdfObject? resolve(PdfObject? value) {
    var current = value;
    var guard = 0;
    while (current is PdfRef) {
      if (++guard > 32) return null;
      current = _objects[current.number];
    }
    return current;
  }

  PdfDict? resolveDict(PdfObject? value) {
    final resolved = resolve(value);
    return resolved is PdfDict ? resolved : null;
  }

  PdfStream? resolveStream(PdfObject? value) {
    final resolved = resolve(value);
    return resolved is PdfStream ? resolved : null;
  }

  /// Stream bytes after decryption and filters.
  List<int> streamData(PdfStream stream) => decodePdfStream(stream);

  List<int> _pageContent(PdfDict page) {
    final contents = page['Contents'];
    final buffer = <int>[];
    void addOne(PdfObject? value) {
      final stream = resolveStream(value);
      if (stream == null) return;
      try {
        if (buffer.isNotEmpty) buffer.add(0x0A);
        buffer.addAll(decodePdfStream(stream));
      } on PdfError {
        // A broken content stream leaves the page empty; the caller reports it.
      }
    }

    if (contents is PdfArray) {
      for (final item in contents.items) {
        addOne(item);
      }
    } else {
      addOne(contents);
    }
    return buffer;
  }

  static bool _looksLikePdf(Uint8List data) {
    final limit = data.length < 1024 ? data.length : 1024;
    for (var i = 0; i + 5 <= limit; i++) {
      if (data[i] == 0x25 &&
          data[i + 1] == 0x50 &&
          data[i + 2] == 0x44 &&
          data[i + 3] == 0x46) {
        return true;
      }
    }
    return false;
  }

  static PdfObject? _resolveRaw(
    PdfObject? value,
    Map<int, PdfObject> objects,
  ) {
    var current = value;
    var guard = 0;
    while (current is PdfRef) {
      if (++guard > 32) return null;
      current = objects[current.number];
    }
    return current;
  }

  static PdfObject _decryptObject(
    int number,
    PdfObject object,
    PdfDecryptor decryptor,
  ) {
    switch (object) {
      case PdfString():
        return PdfString(
          decryptor.decryptString(number, 0, object.bytes),
        );
      case PdfStream():
        return PdfStream(
          _decryptObject(number, object.dict, decryptor) as PdfDict,
          decryptor.decryptStream(number, 0, object.bytes),
        );
      case PdfArray():
        return PdfArray(<PdfObject>[
          for (final item in object.items)
            _decryptObject(number, item, decryptor),
        ]);
      case PdfDict():
        return PdfDict(<String, PdfObject>{
          for (final entry in object.entries.entries)
            entry.key: _decryptObject(number, entry.value, decryptor),
        });
      default:
        return object;
    }
  }

  static void _expandObjectStreams(Map<int, PdfObject> objects) {
    final streamNumbers = <int>[];
    for (final entry in objects.entries) {
      final object = entry.value;
      if (object is PdfStream &&
          object.dict['Type'] is PdfName &&
          (object.dict['Type']! as PdfName).value == 'ObjStm') {
        streamNumbers.add(entry.key);
      }
    }
    for (final number in streamNumbers) {
      final stream = objects[number];
      if (stream is! PdfStream) continue;
      try {
        final data = decodePdfStream(stream);
        final count = _intOf(stream.dict['N']) ?? 0;
        final first = _intOf(stream.dict['First']) ?? 0;
        if (count <= 0 || first < 0 || first > data.length) continue;
        final header = PdfLexer(data);
        final parser = PdfObjectParser(header);
        final pairs = <int, int>{};
        for (var i = 0; i < count; i++) {
          final objectNumber = parser.take();
          final offset = parser.take();
          if (objectNumber.kind != PdfTokenKind.number ||
              offset.kind != PdfTokenKind.number) {
            break;
          }
          pairs[objectNumber.number!.toInt()] = offset.number!.toInt();
        }
        for (final pair in pairs.entries) {
          if (objects.containsKey(pair.key)) continue;
          final position = first + pair.value;
          if (position < 0 || position >= data.length) continue;
          final body = PdfLexer(data);
          body.position = position;
          final object = PdfObjectParser(body).parseObject();
          objects[pair.key] = object;
        }
      } on PdfError {
        continue;
      }
    }
  }

  static int? _intOf(PdfObject? value) {
    if (value is PdfNumber) return value.asInt;
    if (value is PdfRef) return null;
    return null;
  }
}

final class _ScanResult {
  const _ScanResult(this.objects, this.trailer);

  final Map<int, PdfObject> objects;
  final PdfDict? trailer;
}

/// Scans every `n g obj` body. Later definitions win, as incremental updates
/// append them.
_ScanResult _scan(Uint8List data) {
  final objects = <int, PdfObject>{};
  final lexer = PdfLexer(data);
  final parser = PdfObjectParser(lexer);
  PdfDict? trailer;
  var trailerOffset = -1;

  while (true) {
    final token = parser.peek();
    if (token.kind == PdfTokenKind.eof) break;

    if (token.isKeyword('trailer')) {
      parser.take();
      final dict = parser.parseObject();
      if (dict is PdfDict && lexer.position > trailerOffset) {
        trailer = dict;
        trailerOffset = lexer.position;
      }
      continue;
    }

    if (token.kind == PdfTokenKind.number &&
        token.number is int &&
        parser.peek(1).kind == PdfTokenKind.number &&
        parser.peek(1).number is int &&
        parser.peek(2).isKeyword('obj')) {
      final number = token.number!.toInt();
      parser.take();
      parser.take();
      parser.take();
      final object = parser.parseObject();

      final next = parser.peek();
      if (next.isKeyword('stream')) {
        parser.take();
        final start = _streamStart(lexer);
        final length = _directLength(object);
        final end = _streamEnd(
          data,
          start,
          length,
        );
        final bytes = data.sublist(start, end.dataEnd);
        final dict =
            object is PdfDict ? object : const PdfDict(<String, PdfObject>{});
        objects[number] = PdfStream(dict, bytes);
        lexer.position = end.after;
        parser.clearBuffer();
        continue;
      }
      if (object is! PdfNull) {
        objects[number] = object;
      } else {
        objects[number] = object;
      }
      continue;
    }
    parser.take();
  }

  // A cross-reference stream carries the trailer keys in modern files.
  if (trailer == null) {
    for (final object in objects.values) {
      if (object is PdfStream &&
          object.dict['Type'] is PdfName &&
          (object.dict['Type']! as PdfName).value == 'XRef') {
        trailer = object.dict;
      }
    }
  }

  return _ScanResult(objects, trailer);
}

int _streamStart(PdfLexer lexer) {
  var position = lexer.position;
  // A stream keyword is followed by CRLF or LF (or CR).
  if (position < lexer.bytes.length && lexer.bytes[position] == 0x0D) {
    position++;
    if (position < lexer.bytes.length && lexer.bytes[position] == 0x0A) {
      position++;
    }
  } else if (position < lexer.bytes.length && lexer.bytes[position] == 0x0A) {
    position++;
  }
  return position;
}

int? _directLength(PdfObject? object) {
  if (object is PdfDict) {
    final length = object['Length'];
    if (length is PdfNumber) return length.asInt;
  }
  return null;
}

({int dataEnd, int after}) _streamEnd(
  Uint8List data,
  int start,
  int? length,
) {
  if (length != null && length >= 0 && start + length <= data.length) {
    var after = start + length;
    // Skip the EOL before `endstream`.
    while (after < data.length &&
        (data[after] == 0x0D || data[after] == 0x0A || data[after] == 0x20)) {
      after++;
    }
    if (_startsWith(data, after, 'endstream')) {
      return (dataEnd: start + length, after: after + 9);
    }
  }
  // Indirect or wrong length: search for the marker.
  final index = _indexOf(data, 'endstream', start);
  if (index < 0) {
    return (dataEnd: data.length, after: data.length);
  }
  var end = index;
  if (end > start && data[end - 1] == 0x0A) end--;
  if (end > start && data[end - 1] == 0x0D) end--;
  return (dataEnd: end, after: index + 9);
}

bool _startsWith(Uint8List data, int offset, String text) {
  if (offset < 0 || offset + text.length > data.length) return false;
  for (var i = 0; i < text.length; i++) {
    if (data[offset + i] != text.codeUnitAt(i)) return false;
  }
  return true;
}

int _indexOf(Uint8List data, String text, int from) {
  final first = text.codeUnitAt(0);
  final last = data.length - text.length;
  for (var i = from < 0 ? 0 : from; i <= last; i++) {
    if (data[i] != first) continue;
    if (_startsWith(data, i, text)) return i;
  }
  return -1;
}
