// P3-20 (flow F06 step 2): the saved PDF password.
//
// The tests build a small RC4-encrypted statement, seed the vault and assert
// that the flow opens the file without the dialog. A wrong saved password is
// cleared and the dialog returns.
import 'dart:convert';
import 'dart:typed_data';

import 'package:contour/data/keys/secure_key_store.dart';
import 'package:contour/data/repositories/import_secrets.dart';
import 'package:contour/domain/importers/pdf/pdf_crypto.dart';
import 'package:contour/features/import/import_controller.dart';
import 'package:contour/features/import/import_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_import.dart';

const String _password = 'secret';

void main() {
  group('the secure store', () {
    late _MemoryStorage api;
    late SecureImportPasswordStore store;

    setUp(() {
      api = _MemoryStorage();
      store = SecureImportPasswordStore(api);
    });

    test('saves, reads and clears one password', () async {
      await store.save('statement.pdf', 'secret');
      expect(await store.read('statement.pdf'), 'secret');
      expect(await store.read('other.pdf'), isNull);
      await store.clear('statement.pdf');
      expect(await store.read('statement.pdf'), isNull);
    });

    test('the key holds no file name', () async {
      await store.save('First Bank October.pdf', 'secret');
      expect(api.values.keys.single.contains('First Bank'), isFalse);
      expect(api.values.values.single, 'secret');
    });

    test('an empty password is refused', () {
      expect(
        () => store.save('statement.pdf', ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('clearing a missing entry is not an error', () async {
      await store.clear('statement.pdf');
      expect(await store.read('statement.pdf'), isNull);
    });
  });

  group('the import flow', () {
    const fileName = 'locked-statement.pdf';
    const password = _password;

    test('a saved password opens the file without the dialog', () async {
      final vault = MemoryImportPasswordVault();
      await vault.save(fileName, password);
      final controller = ImportController(
        gateway: FakeImportGateway(),
        intake: FakeIntake(_lockedStatement(), name: fileName),
        passwords: vault,
      );
      await controller.load();
      await controller.chooseFile();
      expect(controller.step, ImportStep.preview);
      expect(controller.outcome?.paymentCount, 1);
    });

    test('a locked file without a saved password asks for one', () async {
      final controller = ImportController(
        gateway: FakeImportGateway(),
        intake: FakeIntake(_lockedStatement(), name: fileName),
      );
      await controller.load();
      await controller.chooseFile();
      expect(controller.step, ImportStep.password);
    });

    test('a wrong saved password is cleared and the dialog returns', () async {
      final vault = MemoryImportPasswordVault();
      await vault.save(fileName, 'wrong');
      final controller = ImportController(
        gateway: FakeImportGateway(),
        intake: FakeIntake(_lockedStatement(), name: fileName),
        passwords: vault,
      );
      await controller.load();
      await controller.chooseFile();
      expect(controller.step, ImportStep.password);
      expect(await vault.read(fileName), isNull);
    });

    test('the given password can be stored', () async {
      final vault = MemoryImportPasswordVault();
      final controller = ImportController(
        gateway: FakeImportGateway(),
        intake: FakeIntake(_lockedStatement(), name: fileName),
        passwords: vault,
      );
      await controller.load();
      await controller.chooseFile();
      await controller.submitPassword(password, remember: true);
      expect(controller.step, ImportStep.preview);
      expect(await vault.read(fileName), password);
    });
  });
}

final class _MemoryStorage implements SecureStorageApi {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

// ---------------------------------------------------------------------------
// An RC4-encrypted statement
// ---------------------------------------------------------------------------

Uint8List _lockedStatement() {
  final content = StringBuffer()
    ..writeln('BT /F1 9 Tf')
    ..writeln('1 0 0 1 40 730 Tm (Date) Tj')
    ..writeln('1 0 0 1 480 730 Tm (Amount) Tj')
    ..writeln('1 0 0 1 40 700 Tm (13 Oct 2026) Tj')
    ..writeln('1 0 0 1 120 700 Tm (Coffee shop) Tj')
    ..writeln('1 0 0 1 480 700 Tm (-12.50) Tj')
    ..writeln('ET');
  final plain = utf8.encode(content.toString());

  const fileId = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
  ];
  final encrypt = _encryptDict(_password, fileId);
  final key = _keyFor(_password, encrypt, fileId);
  final objectKey = _objectKey(key, 5);
  final stream = rc4(objectKey, plain);

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
  buffer.add(utf8.encode('6 0 obj\n${_encryptText(encrypt)}\nendobj\n'));
  buffer.add(
    utf8.encode(
      'trailer\n<</Root 1 0 R/Size 7/Encrypt 6 0 R'
      '/ID[<0102030405060708090A0B0C0D0E0F10>'
      '<0102030405060708090A0B0C0D0E0F10>]>>\n%%EOF\n',
    ),
  );
  return buffer.takeBytes();
}

String _encryptText(Map<String, Object?> encrypt) {
  final o = encrypt['O']! as List<int>;
  final u = encrypt['U']! as List<int>;
  return '<</Filter/Standard/V 2/R 3/Length 128'
      '/O<${_hex(o)}>/U<${_hex(u)}>/P -4>>';
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

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

Map<String, Object?> _encryptDict(String userPassword, List<int> fileId) {
  const ownerPassword = 'owner';
  final ownerPadded = _pad(ownerPassword);
  var ownerHash = md5.convert(ownerPadded).bytes;
  for (var i = 0; i < 50; i++) {
    ownerHash = md5.convert(ownerHash).bytes;
  }
  final ownerKey = ownerHash.take(16).toList();
  var ownerValue = rc4(ownerKey, _pad(userPassword));
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

  var userValue = rc4(key, md5.convert(<int>[..._pad(''), ...fileId]).bytes);
  for (var i = 1; i <= 19; i++) {
    userValue = rc4(<int>[for (final byte in key) byte ^ i], userValue);
  }
  return <String, Object?>{
    'O': ownerValue,
    'U': <int>[...userValue, ...List<int>.filled(16, 0)],
  };
}

List<int> _keyFor(
  String userPassword,
  Map<String, Object?> encrypt,
  List<int> fileId,
) {
  const permission = -4;
  final owner = encrypt['O']! as List<int>;
  final keyInput = <int>[
    ..._pad(userPassword),
    ...owner,
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
  return hash.take(16).toList();
}

List<int> _objectKey(List<int> key, int number) => md5
    .convert(<int>[
      ...key,
      number & 0xFF,
      (number >> 8) & 0xFF,
      (number >> 16) & 0xFF,
      0,
      0,
    ])
    .bytes
    .take((key.length + 5).clamp(0, 16))
    .toList();
