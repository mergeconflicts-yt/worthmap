// P3-07 (SPEC 8.6): the Standard security handler for statement PDFs.
//
// Supported: RC4 revisions 2, 3 and 4 (V 1, 2 and 4 with `/CFM /V2`).
// Unsupported and reported as `unsupportedEncryption`: AES-128 (AESV2) and
// AES-256 (AESV3, revisions 5 and 6). The subset is recorded in DECISIONS
// `P3-PDF-SUBSET`.
//
// The password never reaches a log, an error text or a screen message. A wrong
// password returns [PdfErrorCode.wrongPassword] with no characters in it.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'pdf_objects.dart';

const List<int> _kPadding = <int>[
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

/// RC4 (ARC4). Symmetric: the same call encrypts and decrypts.
List<int> rc4(List<int> key, List<int> data) {
  final s = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i < 256; i++) {
    j = (j + s[i] + key[i % key.length]) & 0xFF;
    final tmp = s[i];
    s[i] = s[j];
    s[j] = tmp;
  }
  final out = List<int>.filled(data.length, 0);
  var a = 0;
  var b = 0;
  for (var k = 0; k < data.length; k++) {
    a = (a + 1) & 0xFF;
    b = (b + s[a]) & 0xFF;
    final tmp = s[a];
    s[a] = s[b];
    s[b] = tmp;
    out[k] = data[k] ^ s[(s[a] + s[b]) & 0xFF];
  }
  return out;
}

List<int> _padPassword(String password) {
  final bytes = utf8.encode(password);
  final out = <int>[];
  for (var i = 0; i < 32; i++) {
    out.add(i < bytes.length ? bytes[i] : _kPadding[i]);
  }
  return out;
}

/// The Standard security handler for one open document.
final class PdfDecryptor {
  PdfDecryptor._({
    required List<int> key,
    required this.revision,
    required this.version,
    required this.keyLength,
  }) : _key = List<int>.unmodifiable(key);

  final List<int> _key;
  final int revision;
  final int version;
  final int keyLength;

  /// Builds the handler. Throws [PdfError] when the file is locked or uses an
  /// unsupported method.
  static PdfDecryptor create({
    required PdfDict encrypt,
    required List<int> fileId,
    required String? password,
  }) {
    final filter = encrypt['Filter'];
    if (filter is! PdfName || filter.value != 'Standard') {
      throw const PdfError(PdfErrorCode.unsupportedEncryption);
    }
    final version =
        (encrypt['V'] is PdfNumber) ? (encrypt['V']! as PdfNumber).asInt : 1;
    final revision =
        (encrypt['R'] is PdfNumber) ? (encrypt['R']! as PdfNumber).asInt : 2;
    if (version >= 5 || revision >= 5) {
      throw const PdfError(PdfErrorCode.unsupportedEncryption);
    }
    if (version == 4) {
      final cf = encrypt['CF'];
      final std = cf is PdfDict ? cf['StdCF'] : null;
      final cfm = std is PdfDict ? std['CFM'] : null;
      if (cfm is PdfName && cfm.value == 'AESV2') {
        throw const PdfError(PdfErrorCode.unsupportedEncryption);
      }
      if (cfm is PdfName && cfm.value != 'V2' && cfm.value != 'None') {
        throw const PdfError(PdfErrorCode.unsupportedEncryption);
      }
    }
    final lengthBits = (encrypt['Length'] is PdfNumber)
        ? (encrypt['Length']! as PdfNumber).asInt
        : (version == 1 ? 40 : 128);
    final keyLength = (lengthBits ~/ 8).clamp(5, 16);

    final oValue = encrypt['O'];
    final uValue = encrypt['U'];
    final pValue = encrypt['P'];
    if (oValue is! PdfString || uValue is! PdfString || pValue is! PdfNumber) {
      throw const PdfError(PdfErrorCode.damaged);
    }
    final owner = oValue.bytes;
    final user = uValue.bytes;
    final permission = pValue.asInt;

    List<int>? keyFor(List<int> padded) {
      final key = _computeKey(
        padded: padded,
        owner: owner,
        permission: permission,
        fileId: fileId,
        revision: revision,
        keyLength: keyLength,
      );
      return _matchesUser(
        key: key,
        user: user,
        fileId: fileId,
        revision: revision,
        keyLength: keyLength,
      )
          ? key
          : null;
    }

    final candidates = <String>[
      if (password != null) password,
      '',
    ];
    for (final candidate in candidates) {
      final key = keyFor(_padPassword(candidate));
      if (key != null) {
        return PdfDecryptor._(
          key: key,
          revision: revision,
          version: version,
          keyLength: keyLength,
        );
      }
    }

    // An owner password can open the file too: it recovers the user padding.
    if (password != null && password.isNotEmpty) {
      final recovered = _recoverUserPadding(
        ownerPadding: _padPassword(password),
        owner: owner,
        revision: revision,
        keyLength: keyLength,
      );
      if (recovered != null) {
        final key = keyFor(recovered);
        if (key != null) {
          return PdfDecryptor._(
            key: key,
            revision: revision,
            version: version,
            keyLength: keyLength,
          );
        }
      }
    }

    throw PdfError(
      password == null || password.isEmpty
          ? PdfErrorCode.locked
          : PdfErrorCode.wrongPassword,
    );
  }

  static List<int> _computeKey({
    required List<int> padded,
    required List<int> owner,
    required int permission,
    required List<int> fileId,
    required int revision,
    required int keyLength,
  }) {
    final input = <int>[
      ...padded,
      ...owner.take(32),
      permission & 0xFF,
      (permission >> 8) & 0xFF,
      (permission >> 16) & 0xFF,
      (permission >> 24) & 0xFF,
      ...fileId,
    ];
    var hash = md5.convert(input).bytes;
    if (revision >= 3) {
      for (var i = 0; i < 50; i++) {
        hash = md5.convert(hash.take(keyLength).toList()).bytes;
      }
    }
    return hash.take(keyLength).toList();
  }

  static bool _matchesUser({
    required List<int> key,
    required List<int> user,
    required List<int> fileId,
    required int revision,
    required int keyLength,
  }) {
    if (user.length < 16) return false;
    if (revision == 2) {
      final computed = rc4(key, _kPadding);
      for (var i = 0; i < 32 && i < user.length; i++) {
        if (computed[i] != user[i]) return false;
      }
      return true;
    }
    final hash = md5.convert(<int>[..._kPadding, ...fileId]).bytes;
    var value = rc4(key, hash);
    for (var i = 1; i <= 19; i++) {
      value = rc4(_xorKey(key, i), value);
    }
    for (var i = 0; i < 16; i++) {
      if (value[i] != user[i]) return false;
    }
    return true;
  }

  static List<int>? _recoverUserPadding({
    required List<int> ownerPadding,
    required List<int> owner,
    required int revision,
    required int keyLength,
  }) {
    if (owner.length < 32) return null;
    var hash = md5.convert(ownerPadding).bytes;
    if (revision >= 3) {
      for (var i = 0; i < 50; i++) {
        hash = md5.convert(hash).bytes;
      }
    }
    final key = hash.take(keyLength).toList();
    var value = owner.take(32).toList();
    if (revision == 2) {
      return rc4(key, value);
    }
    for (var i = 19; i >= 0; i--) {
      value = rc4(_xorKey(key, i), value);
    }
    return value;
  }

  static List<int> _xorKey(List<int> key, int value) =>
      <int>[for (final byte in key) byte ^ value];

  List<int> _objectKey(int number, int generation) => md5
      .convert(<int>[
        ..._key,
        number & 0xFF,
        (number >> 8) & 0xFF,
        (number >> 16) & 0xFF,
        generation & 0xFF,
        (generation >> 8) & 0xFF,
      ])
      .bytes
      .take((keyLength + 5).clamp(0, 16))
      .toList();

  /// Decrypts one string value (not a stream).
  List<int> decryptString(int number, int generation, List<int> bytes) {
    if (bytes.isEmpty) return bytes;
    return rc4(_objectKey(number, generation), bytes);
  }

  /// Decrypts stream bytes.
  List<int> decryptStream(int number, int generation, List<int> bytes) =>
      decryptString(number, generation, bytes);
}

/// True when the dictionary uses an encryption this reader cannot open.
bool isUnsupportedEncryption(PdfDict encrypt) {
  final version = encrypt['V'];
  final revision = encrypt['R'];
  final v = version is PdfNumber ? version.asInt : 1;
  final r = revision is PdfNumber ? revision.asInt : 2;
  if (v >= 5 || r >= 5) return true;
  if (v == 4) {
    final cf = encrypt['CF'];
    final std = cf is PdfDict ? cf['StdCF'] : null;
    final cfm = std is PdfDict ? std['CFM'] : null;
    return cfm is PdfName && cfm.value == 'AESV2';
  }
  return false;
}

/// Reads `/ID[0]` as bytes. A missing ID is an empty value.
List<int> pdfFileId(PdfDict? trailer) {
  final id = trailer?['ID'];
  if (id is PdfArray && id.items.isNotEmpty && id.items.first is PdfString) {
    return (id.items.first as PdfString).bytes;
  }
  return const <int>[];
}

Uint8List asPdfBytes(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
