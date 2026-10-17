import 'dart:typed_data';

import 'package:contour/core/ids.dart';
import 'package:flutter_test/flutter_test.dart';

// T02 — UUID v7 codec. SPEC 9: authored ids are UUID v7 text.
// DATABASE_DESIGN 3: lowercase canonical form. Tests first (AGENTS 2.8).
void main() {
  test('generates a canonical version 7 UUID from supplied inputs', () {
    final id = UuidV7.generate(
      unixMillis: 0x0123456789AB,
      randomBytes: Uint8List.fromList(<int>[
        0x0f,
        0x11,
        0x22,
        0x33,
        0x44,
        0x55,
        0x66,
        0x77,
        0x88,
        0x99,
      ]),
    );
    expect(id.toString(), '01234567-89ab-7f11-a233-445566778899');
    expect(id.version, 7);
  });

  test('generation is deterministic for the same inputs', () {
    final bytes = Uint8List.fromList(List<int>.filled(10, 0x01));
    final a = UuidV7.generate(unixMillis: 1, randomBytes: bytes);
    final b = UuidV7.generate(unixMillis: 1, randomBytes: bytes);
    expect(a, b);
  });

  test('parse round-trips the canonical form', () {
    final id = UuidV7.parse('01234567-89ab-7f11-a233-445566778899');
    expect(id.toString(), '01234567-89ab-7f11-a233-445566778899');
  });

  test('rejects a wrong version nibble', () {
    expect(
      () => UuidV7.parse('01234567-89ab-4f11-a233-445566778899'),
      throwsFormatException,
    );
  });

  test('rejects a wrong variant', () {
    expect(
      () => UuidV7.parse('01234567-89ab-7f11-0233-445566778899'),
      throwsFormatException,
    );
  });

  test('rejects malformed text', () {
    expect(() => UuidV7.parse('not-a-uuid'), throwsFormatException);
    expect(
      () => UuidV7.parse('01234567-89ab-7f11-a233'),
      throwsFormatException,
    );
    expect(UuidV7.tryParse('not-a-uuid'), isNull);
  });

  test('requires at least 10 random bytes', () {
    expect(
      () => UuidV7.generate(
        unixMillis: 1,
        randomBytes: Uint8List(9),
      ),
      throwsArgumentError,
    );
  });

  test('rejects an out-of-range timestamp', () {
    expect(
      () => UuidV7.generate(
        unixMillis: 0x1000000000000,
        randomBytes: Uint8List(10),
      ),
      throwsArgumentError,
    );
  });

  test('fromBytes validates length, version and variant', () {
    final id = UuidV7.fromBytes(<int>[
      0x01,
      0x23,
      0x45,
      0x67,
      0x89,
      0xab,
      0x7f,
      0x11,
      0xa2,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x99,
    ]);
    expect(id.toString(), '01234567-89ab-7f11-a233-445566778899');
    expect(() => UuidV7.fromBytes(<int>[0, 1, 2]), throwsFormatException);
    expect(
      () => UuidV7.fromBytes(<int>[
        0,
        0,
        0,
        0,
        0,
        0,
        0x4f,
        0x11,
        0xa2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]),
      throwsFormatException,
    );
  });

  test('equality and hashCode use every byte', () {
    final a = UuidV7.parse('01234567-89ab-7f11-a233-445566778899');
    final b = UuidV7.parse('01234567-89ab-7f11-a233-445566778899');
    final c = UuidV7.parse('01234567-89ab-7f11-a233-44556677889a');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, false);
    expect(a == Object(), false);
  });
}
