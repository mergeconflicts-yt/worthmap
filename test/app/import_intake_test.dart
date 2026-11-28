// P3-21/P3-22 (SPEC 8.8): the PDF-only file intake adapter.
//
// The native picker is replaced by a scripted method-channel handler. The
// tests cover the byte bound, the PDF signature, cancel, the typed failures
// and a platform without the binding. No test writes a file.
import 'package:contour/app/import_intake.dart';
import 'package:contour/features/import/import_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('contour/import_intake_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const pdf = <int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37];
  const notPdf = <int>[0x50, 0x4B, 0x03, 0x04, 0x00];

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('a cancel returns null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    const intake = PlatformImportFileIntake(channel: channel);

    expect(await intake.pickPdf(), isNull);
  });

  test('a picked PDF returns its name and bytes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pickPdf');
      expect(call.arguments, <String, Object?>{'maxBytes': maxImportBytes});
      return <String, Object?>{
        'name': 'statement.pdf',
        'bytes': Uint8List.fromList(pdf),
      };
    });

    const intake = PlatformImportFileIntake(channel: channel);
    final file = await intake.pickPdf();

    expect(file, isNotNull);
    expect(file!.name, 'statement.pdf');
    expect(file.bytes, pdf);
  });

  test('a non-PDF file is refused before parsing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object?>{
        'name': 'statement.pdf',
        'bytes': Uint8List.fromList(notPdf),
      };
    });

    const intake = PlatformImportFileIntake(channel: channel);

    await expectLater(
      intake.pickPdf(),
      throwsA(
        isA<ImportIntakeError>().having(
          (error) => error.failure,
          'failure',
          ImportFailure.notPdf,
        ),
      ),
    );
  });

  test('a file over the bound is refused', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object?>{
        'name': 'statement.pdf',
        'bytes': Uint8List.fromList(<int>[...pdf, 0x00]),
      };
    });

    const intake = PlatformImportFileIntake(channel: channel, maxBytes: 8);

    await expectLater(
      intake.pickPdf(),
      throwsA(
        isA<ImportIntakeError>().having(
          (error) => error.failure,
          'failure',
          ImportFailure.tooLarge,
        ),
      ),
    );
  });

  test('a native refusal keeps its typed failure', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'tooLarge');
    });

    const intake = PlatformImportFileIntake(channel: channel);

    await expectLater(
      intake.pickPdf(),
      throwsA(
        isA<ImportIntakeError>().having(
          (error) => error.failure,
          'failure',
          ImportFailure.tooLarge,
        ),
      ),
    );
  });

  test('a platform without the binding is unavailable', () async {
    const intake = PlatformImportFileIntake(channel: channel);

    await expectLater(
      intake.pickPdf(),
      throwsA(
        isA<ImportIntakeError>().having(
          (error) => error.failure,
          'failure',
          ImportFailure.notWired,
        ),
      ),
    );
  });

  test('a malformed reply is damaged, not accepted', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object?>{'name': 'statement.pdf', 'bytes': 'not bytes'};
    });

    const intake = PlatformImportFileIntake(channel: channel);

    await expectLater(
      intake.pickPdf(),
      throwsA(
        isA<ImportIntakeError>().having(
          (error) => error.failure,
          'failure',
          ImportFailure.damaged,
        ),
      ),
    );
  });
}
