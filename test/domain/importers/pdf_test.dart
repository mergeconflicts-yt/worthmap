// P3-07 (SPEC 8.6): the PDF reader, the statement parser and the layout
// template. The fixtures are synthetic PDFs built in this file; no real
// statement data is used.
import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import 'package:contour/core/dates.dart';
import 'package:contour/domain/importers/pdf/pdf_crypto.dart';
import 'package:contour/domain/importers/pdf/pdf_import.dart';
import 'package:contour/domain/importers/pdf/pdf_objects.dart';
import 'package:contour/domain/importers/pdf/pdf_statement.dart';
import 'package:contour/domain/importers/pdf/pdf_template.dart';
import 'package:contour/domain/importers/pdf/pdf_text.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('objects and streams', () {
    test('a PDF banner is detected', () {
      expect(looksLikePdf(utf8.encode('%PDF-1.4\n')), isTrue);
      expect(looksLikePdf(utf8.encode('hello')), isFalse);
    });

    test('a broken object does not hang the scan', () {
      final bytes = utf8.encode('%PDF-1.4\n1 0 obj << /Type /Catalog \n');
      expect(
        () => const PdfImporter().read(bytes),
        throwsA(
          isA<PdfImportError>().having(
            (error) => error.code,
            'code',
            PdfImportErrorCode.noPages,
          ),
        ),
      );
    });

    test('a flate stream decodes', () {
      final payload = utf8.encode('BT (hello) Tj ET');
      final encoded = ZLibCodec().encode(payload);
      final stream = PdfStream(
        const PdfDict(<String, PdfObject>{
          'Filter': PdfName('FlateDecode'),
        }),
        encoded,
      );
      expect(utf8.decode(decodePdfStream(stream)), 'BT (hello) Tj ET');
    });

    test('an escaped literal string decodes', () {
      final lexer = PdfLexer(utf8.encode(r'(\050hi\051 \n)'));
      final token = lexer.next();
      expect(utf8.decode(token.bytes), '(hi) \n');
    });
  });

  group('amounts', () {
    test('plain and separated values', () {
      expect(parsePdfAmount('12.50')!.minor, 1250);
      expect(parsePdfAmount('1,240.00')!.minor, 124000);
      expect(parsePdfAmount('1.240,00')!.minor, 124000);
      expect(parsePdfAmount('1 240,50')!.minor, 124050);
    });

    test('signs', () {
      expect(parsePdfAmount('-42.50')!.minor, -4250);
      expect(parsePdfAmount('(42.50)')!.minor, -4250);
      expect(parsePdfAmount('42.50 DR')!.minor, -4250);
      expect(parsePdfAmount(r'$1,000.00')!.minor, 100000);
      expect(parsePdfAmount('2400.00 CR')!.minor, 240000);
    });

    test('an integer amount has no decimals', () {
      final value = parsePdfAmount('12')!;
      expect(value.minor, 1200);
      expect(value.hasDecimals, isFalse);
    });

    test('text is not an amount', () {
      expect(parsePdfAmount('Coffee shop'), isNull);
      expect(parsePdfAmount('13 Oct 2026'), isNull);
    });
  });

  group('dates', () {
    test('month names and numeric orders', () {
      final statement = const PdfStatementParser().parse(<PdfPageText>[
        _page(<String>['13 Oct 2026 | Coffee | -12.50']),
      ]);
      expect(statement.rows.single.date, LocalDate(2026, 10, 13));
    });

    test('day-first and month-first numeric dates', () {
      final statement = const PdfStatementParser().parse(<PdfPageText>[
        _page(<String>[
          '05/10/2026 | Coffee | -12.50',
          '12/13/2026 | Coffee | -12.50',
        ]),
      ]);
      expect(statement.rows[0].date, LocalDate(2026, 10, 5));
      expect(statement.rows[1].date, LocalDate(2026, 12, 13));
    });

    test('an ambiguous numeric date is unsure', () {
      final statement = const PdfStatementParser().parse(<PdfPageText>[
        _page(<String>['05/10/2026 | Coffee | -12.50']),
      ]);
      expect(statement.rows.single.confidence, PdfRowConfidence.unsure);
      expect(statement.rows.single.date, LocalDate(2026, 10, 5));
    });
  });

  group('statement rows', () {
    late PdfImportOutcome outcome;

    setUpAll(() {
      outcome = const PdfImporter().read(
        _statementPdf(
          rows: const <_RowFixture>[
            _RowFixture('01 Oct 2026', 'Opening balance', '1,240.00'),
            _RowFixture('13 Oct 2026', 'Coffee shop', '-12.50'),
            _RowFixture('14 Oct 2026', 'Salary', '2,400.00 CR'),
            _RowFixture('15 Oct 2026', 'Grocery store', '-84.20'),
          ],
        ),
      );
    });

    test('payments and the balance row are separated', () {
      expect(outcome.paymentCount, 3);
      expect(outcome.balanceCount, 1);
      expect(
        outcome.statement.rows.first.kind,
        PdfRowKind.balance,
      );
    });

    test('signed minor units and text', () {
      final rows = outcome.statement.payments;
      expect(rows[0].amountMinor, -1250);
      expect(rows[0].description, 'Coffee shop');
      expect(rows[0].date, LocalDate(2026, 10, 13));
      expect(rows[1].amountMinor, 240000);
      expect(rows[2].amountMinor, -8420);
    });

    test('the source key is stable for one file', () {
      final first = outcome.statement.payments.first.sourceKey;
      final again = const PdfImporter().read(
        _statementPdf(
          rows: const <_RowFixture>[
            _RowFixture('01 Oct 2026', 'Opening balance', '1,240.00'),
            _RowFixture('13 Oct 2026', 'Coffee shop', '-12.50'),
          ],
        ),
      );
      expect(again.statement.payments.single.sourceKey, first);
    });

    test('a saved template with another layout does not match', () {
      const template = PdfTemplate(
        fingerprint: 'other',
        name: 'First Bank',
        format: 'pdf',
        version: PdfTemplate.currentVersion,
        bands: PdfColumnBands(dateX: 40, detailsX: 120, amountX: 480),
      );
      final result = const PdfImporter().read(
        _statementPdf(
          rows: const <_RowFixture>[
            _RowFixture('13 Oct 2026', 'Coffee shop', '-12.50'),
          ],
        ),
        template: template,
      );
      expect(result.templateMatched, isFalse);
    });

    test('a taught layout imports the next month with no questions', () {
      final first = const PdfImporter().read(
        _statementPdf(
          rows: const <_RowFixture>[
            _RowFixture('13 Oct 2026', 'Coffee shop', '-12.50'),
          ],
        ),
      );
      final template = PdfTemplate(
        fingerprint: first.fingerprint,
        name: 'First Bank, checking',
        format: 'pdf',
        version: PdfTemplate.currentVersion,
        bands: const PdfColumnBands(dateX: 40, detailsX: 120, amountX: 480),
      );
      final next = const PdfImporter().read(
        _statementPdf(
          rows: const <_RowFixture>[
            _RowFixture('13 Nov 2026', 'Coffee shop', '-14.00'),
            _RowFixture('14 Nov 2026', 'Grocery store', '-60.10'),
          ],
        ),
        template: template,
      );
      expect(next.templateMatched, isTrue);
      expect(next.paymentCount, 2);
      expect(next.statement.payments.first.amountMinor, -1400);
    });

    test('a page with no rows is a typed failure', () {
      expect(
        () => const PdfImporter()
            .read(_statementPdf(rows: const <_RowFixture>[])),
        throwsA(
          isA<PdfImportError>().having(
            (error) => error.code,
            'code',
            PdfImportErrorCode.noRows,
          ),
        ),
      );
    });
  });

  group('layout template', () {
    test('teach stores bands and round-trips', () {
      final pages = <PdfPageText>[
        _page(<String>[
          'Date|Description|Amount',
          '13 Oct 2026|Coffee shop|-12.50',
        ]),
      ];
      final statement = const PdfStatementParser().parse(pages);
      final template = teachPdfTemplate(
        name: 'First Bank, checking',
        statement: statement,
        sampleLine: pages.single.lines.last,
        dateCell: 0,
        amountCell: 2,
      );
      expect(template, isNotNull);
      final restored = PdfTemplate.fromJson(template!.toJson());
      expect(restored!.name, 'First Bank, checking');
      expect(restored.fingerprint, template.fingerprint);
      expect(restored.matches(template.fingerprint), isTrue);
    });

    test('a newer template version is not applied', () {
      final json = <String, Object?>{
        'v': 99,
        'fingerprint': 'abc',
        'name': 'Old',
        'format': 'pdf',
        'bands': <String, Object?>{'dateX': 1, 'detailsX': 2, 'amountX': 3},
      };
      expect(PdfTemplate.fromJson(json), isNull);
    });

    test('a bad cell choice teaches nothing', () {
      final pages = <PdfPageText>[
        _page(<String>['Date Description Amount']),
      ];
      final statement = const PdfStatementParser().parse(pages);
      expect(
        teachPdfTemplate(
          name: 'x',
          statement: statement,
          sampleLine: pages.single.lines.single,
          dateCell: 0,
          amountCell: 5,
        ),
        isNull,
      );
    });
  });

  group('security handler', () {
    const password = 'secret';
    const ownerPassword = 'owner';

    late PdfDict encrypt;
    late List<int> fileId;

    setUp(() {
      fileId = List<int>.generate(16, (i) => i + 1);
      encrypt = _encryptDict(
        userPassword: password,
        ownerPassword: ownerPassword,
        fileId: fileId,
      );
    });

    test('the user password opens the file', () {
      final decryptor = PdfDecryptor.create(
        encrypt: encrypt,
        fileId: fileId,
        password: password,
      );
      final plain = utf8.encode('hello statement');
      final encrypted = decryptor.decryptString(7, 0, plain);
      expect(decryptor.decryptString(7, 0, encrypted), plain);
      expect(encrypted, isNot(plain));
    });

    test('the owner password opens the file', () {
      final decryptor = PdfDecryptor.create(
        encrypt: encrypt,
        fileId: fileId,
        password: ownerPassword,
      );
      expect(decryptor.revision, 3);
    });

    test('no password on a locked file', () {
      expect(
        () => PdfDecryptor.create(
          encrypt: encrypt,
          fileId: fileId,
          password: null,
        ),
        throwsA(
          isA<PdfError>().having(
            (error) => error.code,
            'code',
            PdfErrorCode.locked,
          ),
        ),
      );
    });

    test('a wrong password is typed and holds no text', () {
      expect(
        () => PdfDecryptor.create(
          encrypt: encrypt,
          fileId: fileId,
          password: 'wrong',
        ),
        throwsA(
          isA<PdfError>().having(
            (error) => error.code,
            'code',
            PdfErrorCode.wrongPassword,
          ),
        ),
      );
    });

    test('AES-256 is refused, not guessed', () {
      final aes = PdfDict(<String, PdfObject>{
        'Filter': const PdfName('Standard'),
        'V': const PdfNumber(5),
        'R': const PdfNumber(6),
        'O': PdfString(List<int>.filled(48, 1)),
        'U': PdfString(List<int>.filled(48, 2)),
        'P': const PdfNumber(-4),
      });
      expect(
        () => PdfDecryptor.create(
          encrypt: aes,
          fileId: fileId,
          password: 'secret',
        ),
        throwsA(
          isA<PdfError>().having(
            (error) => error.code,
            'code',
            PdfErrorCode.unsupportedEncryption,
          ),
        ),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

PdfPageText _page(List<String> lines) => PdfPageText(
      pageNumber: 1,
      width: 612,
      lines: <PdfTextLine>[
        for (var i = 0; i < lines.length; i++) _lineFor(lines[i], 700 - i * 20),
      ],
    );

PdfTextLine _lineFor(String line, double y) {
  // The test fixture uses `|` as the cell separator and turns it into a wide
  // gap, which is what the extractor reports for a table column.
  final parts = line.split('|');
  final spans = <PdfSpan>[];
  var x = 40.0;
  for (final part in parts) {
    final text = part.trimLeft();
    if (text.isNotEmpty) {
      spans.add(PdfSpan(x: x, y: y, text: text, fontSize: 9));
    }
    x += text.length * 5.0 + 30;
  }
  return PdfTextLine(y, spans);
}

final class _RowFixture {
  const _RowFixture(this.date, this.description, this.amount);

  final String date;
  final String description;
  final String amount;
}

List<int> _statementPdf({
  required List<_RowFixture> rows,
  bool compress = false,
}) {
  final content = StringBuffer();
  content.writeln('BT /F1 9 Tf');
  var y = 730.0;
  void cell(double x, String text) {
    content
        .writeln('1 0 0 1 ${x.toStringAsFixed(0)} ${y.toStringAsFixed(0)} Tm');
    content.writeln('(${_escape(text)}) Tj');
  }

  cell(40, 'Date');
  cell(120, 'Description');
  cell(480, 'Amount');
  for (final row in rows) {
    y -= 20;
    cell(40, row.date);
    cell(120, row.description);
    cell(480, row.amount);
  }
  content.writeln('ET');
  final contentBytes = utf8.encode(content.toString());
  final streamBytes =
      compress ? ZLibCodec().encode(contentBytes) : contentBytes;

  final objects = <String>[
    '1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n',
    '2 0 obj\n<</Type/Pages/Kids[3 0 R]/Count 1>>\nendobj\n',
    '3 0 obj\n<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]'
        '/Resources<</Font<</F1 4 0 R>>>>/Contents 5 0 R>>\nendobj\n',
    '4 0 obj\n<</Type/Font/Subtype/Type1/BaseFont/Helvetica'
        '/Encoding/WinAnsiEncoding>>\nendobj\n',
    '5 0 obj\n<</Length ${streamBytes.length}'
        '${compress ? '/Filter/FlateDecode' : ''}>>\nstream\n',
  ];
  final buffer = BytesBuilder();
  buffer.add(utf8.encode('%PDF-1.4\n'));
  for (final object in objects) {
    buffer.add(utf8.encode(object));
  }
  buffer.add(streamBytes);
  buffer.add(utf8.encode('\nendstream\nendobj\n'));
  buffer.add(
    utf8.encode(
      'trailer\n<</Root 1 0 R/Size 6/ID[<0102030405060708090A0B0C0D0E0F10>'
      '<0102030405060708090A0B0C0D0E0F10>]>>\nstartxref\n0\n%%EOF\n',
    ),
  );
  return buffer.takeBytes();
}

String _escape(String text) =>
    text.replaceAll('\\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

// A standards-shaped RC4 encryption dictionary for revisions 3.
PdfDict _encryptDict({
  required String userPassword,
  required String ownerPassword,
  required List<int> fileId,
}) {
  final ownerPadded = _pad(ownerPassword);
  var ownerHash = md5.convert(ownerPadded).bytes;
  for (var i = 0; i < 50; i++) {
    ownerHash = md5.convert(ownerHash).bytes;
  }
  final ownerKey = ownerHash.take(16).toList();
  var ownerValue = _pad(userPassword);
  ownerValue = rc4(ownerKey, ownerValue);
  for (var i = 1; i <= 19; i++) {
    ownerValue = rc4(
      <int>[for (final byte in ownerKey) byte ^ i],
      ownerValue,
    );
  }

  const permission = -4;
  final keyInput = <int>[
    ..._pad(userPassword),
    ...ownerValue,
    permission & 0xFF,
    (permission >> 8) & 0xFF,
    (permission >> 16) & 0xFF,
    (permission >> 24) & 0xFF,
    ...fileId,
  ];
  var hash = md5.convert(keyInput).bytes;
  for (var i = 0; i < 50; i++) {
    hash = md5.convert(hash.take(16).toList()).bytes;
  }
  final key = hash.take(16).toList();

  final value = md5.convert(<int>[..._pad(''), ...fileId]).bytes;
  var userValue = rc4(key, value);
  for (var i = 1; i <= 19; i++) {
    userValue = rc4(<int>[for (final byte in key) byte ^ i], userValue);
  }

  return PdfDict(<String, PdfObject>{
    'Filter': const PdfName('Standard'),
    'V': const PdfNumber(2),
    'R': const PdfNumber(3),
    'Length': const PdfNumber(128),
    'O': PdfString(ownerValue),
    'U': PdfString(<int>[...userValue, ...List<int>.filled(16, 0)]),
    'P': const PdfNumber(permission),
  });
}

const List<int> _padding = <int>[
  0x28,
  0xBF,
  0x4E,
  0x5E,
  0x4E,
  0x75,
  0x8A,
  0x41,
  0x64,
  0x00,
  0x4E,
  0x56,
  0xFF,
  0xFA,
  0x01,
  0x08,
  0x2E,
  0x2E,
  0x00,
  0xB6,
  0xD0,
  0x68,
  0x3E,
  0x80,
  0x2F,
  0x0C,
  0xA9,
  0xFE,
  0x64,
  0x53,
  0x69,
  0x7A,
];

List<int> _pad(String password) {
  final bytes = utf8.encode(password);
  return <int>[
    for (var i = 0; i < 32; i++) i < bytes.length ? bytes[i] : _padding[i],
  ];
}
