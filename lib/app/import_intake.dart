// P3-21/P3-22 (SPEC 8.8): the PDF-only local file intake.
//
// One method channel for both platforms. The native picker returns one local
// PDF of at most 100 MiB; this adapter keeps no copy, resolves a cancel to
// null and reports a typed failure for everything else. A platform without the
// binding reports the factual unavailable state (ImportFailure.notWired).
//
// The in-app picker reads the bytes while the app is open. The share staging
// object and its key belong to the separate share path (P3-21); this adapter
// never writes a file and never logs a name, path or content (AGENTS 2.6).
library;

import 'package:flutter/services.dart';

import '../features/import/import_models.dart';

/// SPEC 8.8: one file of at most 100 MiB encoded.
const int maxImportBytes = 100 * 1024 * 1024;

/// The channel the native builder implements on iOS and Android.
const String importIntakeChannelName = 'contour/import_intake';

const List<int> _pdfHeader = <int>[0x25, 0x50, 0x44, 0x46, 0x2D];

/// The production intake over the native PDF picker.
final class PlatformImportFileIntake implements ImportFileIntake {
  const PlatformImportFileIntake({
    MethodChannel channel = const MethodChannel(importIntakeChannelName),
    int maxBytes = maxImportBytes,
  })  : _channel = channel,
        _maxBytes = maxBytes;

  final MethodChannel _channel;
  final int _maxBytes;

  @override
  Future<ImportedFile?> pickPdf() async {
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>(
        'pickPdf',
        <String, Object?>{'maxBytes': _maxBytes},
      );
      if (reply == null) return null;
      final name = reply['name'];
      final bytes = reply['bytes'];
      if (name is! String || name.isEmpty || bytes is! Uint8List) {
        throw const ImportIntakeError(ImportFailure.damaged);
      }
      if (bytes.length > _maxBytes) {
        throw const ImportIntakeError(ImportFailure.tooLarge);
      }
      if (!_isPdf(bytes)) {
        throw const ImportIntakeError(ImportFailure.notPdf);
      }
      return ImportedFile(name: name, bytes: bytes);
    } on MissingPluginException {
      throw const ImportIntakeError(ImportFailure.notWired);
    } on PlatformException catch (error) {
      throw ImportIntakeError(_failureFor(error.code));
    }
  }
}

bool _isPdf(Uint8List bytes) {
  if (bytes.length < _pdfHeader.length) return false;
  for (var i = 0; i < _pdfHeader.length; i++) {
    if (bytes[i] != _pdfHeader[i]) return false;
  }
  return true;
}

ImportFailure _failureFor(String code) => switch (code) {
      'notPdf' => ImportFailure.notPdf,
      'tooLarge' => ImportFailure.tooLarge,
      'damaged' => ImportFailure.damaged,
      'unavailable' => ImportFailure.notWired,
      _ => ImportFailure.damaged,
    };
