// P3-25 demo only (PF-01: synthetic data, debug builds). Builds a small
// statement PDF in memory so the import flow can be used without a real file.
// It is never part of a release path.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../features/import/import_models.dart';

/// One synthetic statement, read from memory.
final class SyntheticFileIntake implements ImportFileIntake {
  const SyntheticFileIntake();

  @override
  Future<ImportedFile?> pickPdf() async => ImportedFile(
        name: 'First Bank statement, October.pdf',
        bytes: buildSyntheticStatement(),
      );
}

/// A one-page statement with a header and five rows.
Uint8List buildSyntheticStatement() {
  const rows = <List<String>>[
    <String>['01 Oct 2026', 'Opening balance', '1,240.00'],
    <String>['13 Oct 2026', 'Coffee shop', '-12.50'],
    <String>['14 Oct 2026', 'Salary', '2,400.00 CR'],
    <String>['15 Oct 2026', 'Grocery store', '-84.20'],
    <String>['16 Oct 2026', 'Book shop', '-23.40'],
  ];
  final content = StringBuffer('BT /F1 9 Tf\n');
  var y = 730;
  void cell(int x, String text) {
    content.write('1 0 0 1 $x $y Tm\n');
    content.write('(${_escape(text)}) Tj\n');
  }

  cell(40, 'Date');
  cell(120, 'Description');
  cell(480, 'Amount');
  for (final row in rows) {
    y -= 20;
    cell(40, row[0]);
    cell(120, row[1]);
    cell(480, row[2]);
  }
  content.write('ET\n');
  final stream = utf8.encode(content.toString());

  final buffer = BytesBuilder();
  buffer.add(utf8.encode('%PDF-1.4\n'));
  buffer.add(utf8.encode('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n'));
  buffer.add(
    utf8.encode('2 0 obj\n<</Type/Pages/Kids[3 0 R]/Count 1>>\nendobj\n'),
  );
  buffer.add(
    utf8.encode(
      '3 0 obj\n<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]'
      '/Resources<</Font<</F1 4 0 R>>>>/Contents 5 0 R>>\nendobj\n',
    ),
  );
  buffer.add(
    utf8.encode(
      '4 0 obj\n<</Type/Font/Subtype/Type1/BaseFont/Helvetica'
      '/Encoding/WinAnsiEncoding>>\nendobj\n',
    ),
  );
  buffer.add(
    utf8.encode('5 0 obj\n<</Length ${stream.length}>>\nstream\n'),
  );
  buffer.add(stream);
  buffer.add(utf8.encode('\nendstream\nendobj\n'));
  buffer.add(
    utf8.encode('trailer\n<</Root 1 0 R/Size 6>>\nstartxref\n0\n%%EOF\n'),
  );
  return buffer.takeBytes();
}

String _escape(String text) =>
    text.replaceAll('\\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
