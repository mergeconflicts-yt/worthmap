import 'dart:typed_data';

/// SPEC 9 / DATABASE_DESIGN 3: authored identities are canonical lowercase
/// UUID version 7 text. UUID order is not financial chronology.
///
/// Generation takes the timestamp and random bytes as arguments, so domain code
/// stays free of a wall clock and unseeded randomness (AGENTS 6.3).
final class UuidV7 {
  UuidV7._(this._bytes) : assert(_bytes.length == length);

  final Uint8List _bytes;

  /// The number of bytes in a UUID.
  static const int length = 16;

  static final RegExp _text = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// The UUID version. Always 7 for this type.
  int get version => 7;

  /// Builds a version 7 UUID from a millisecond timestamp and random bytes.
  ///
  /// [randomBytes] must supply at least 10 bytes.
  static UuidV7 generate({
    required int unixMillis,
    required List<int> randomBytes,
  }) {
    if (unixMillis < 0 || unixMillis > 0xFFFFFFFFFFFF) {
      throw ArgumentError.value(unixMillis, 'unixMillis', 'Must fit 48 bits');
    }
    if (randomBytes.length < 10) {
      throw ArgumentError.value(
        randomBytes.length,
        'randomBytes',
        'Must supply at least 10 bytes',
      );
    }
    final bytes = Uint8List(length);
    for (var i = 0; i < 6; i++) {
      bytes[5 - i] = (unixMillis >> (8 * i)) & 0xff;
    }
    bytes[6] = 0x70 | (randomBytes[0] & 0x0f);
    bytes[7] = randomBytes[1] & 0xff;
    bytes[8] = 0x80 | (randomBytes[2] & 0x3f);
    for (var i = 3; i < 10; i++) {
      bytes[i + 6] = randomBytes[i] & 0xff;
    }
    return UuidV7._(bytes);
  }

  /// Wraps [bytes] and validates the version and variant.
  static UuidV7 fromBytes(List<int> bytes) {
    if (bytes.length != length) {
      throw const FormatException('A UUID needs exactly 16 bytes');
    }
    final copy = Uint8List.fromList(bytes);
    final id = UuidV7._(copy);
    if (!id._hasVersion7 || !id._hasRfcVariant) {
      throw const FormatException('Not a version 7 UUID');
    }
    return id;
  }

  /// Parses canonical text, or returns null.
  static UuidV7? tryParse(String source) {
    if (!_text.hasMatch(source)) {
      return null;
    }
    final hex = source.replaceAll('-', '');
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    if ((bytes[6] & 0xf0) != 0x70 || (bytes[8] & 0xc0) != 0x80) {
      return null;
    }
    return UuidV7._(bytes);
  }

  /// Parses canonical text, or throws [FormatException].
  static UuidV7 parse(String source) {
    final value = tryParse(source);
    if (value == null) {
      throw const FormatException('Not a canonical version 7 UUID');
    }
    return value;
  }

  bool get _hasVersion7 => (_bytes[6] & 0xf0) == 0x70;
  bool get _hasRfcVariant => (_bytes[8] & 0xc0) == 0x80;

  @override
  bool operator ==(Object other) {
    if (other is! UuidV7) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      if (_bytes[i] != other._bytes[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() {
    final hex = StringBuffer();
    for (final byte in _bytes) {
      hex.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    final text = hex.toString();
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-'
        '${text.substring(12, 16)}-${text.substring(16, 20)}-'
        '${text.substring(20)}';
  }
}
