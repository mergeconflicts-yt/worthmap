import 'package:contour/data/speech/speech.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:contour/features/add/voice/x24_voice_capture.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_payments_gateway.dart';
import 'fake_speech_port.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(section: Section.spending, child: child),
    );

final class _Harness {
  _Harness({
    ScriptedSpeechPort? speech,
    FakePaymentsGateway? gateway,
  })  : speech = speech ?? ScriptedSpeechPort(),
        gateway = gateway ??
            FakePaymentsGateway(
              expenseCategories: const <CategorySummary>[
                CategorySummary(id: 'category-dining', name: 'Dining'),
                CategorySummary(id: 'category-coffee', name: 'Coffee'),
              ],
            );

  final ScriptedSpeechPort speech;
  final FakePaymentsGateway gateway;
  SavedPayment? saved;
  String? transcript;
  int closed = 0;

  Widget build() => _wrap(
        X24VoiceCapture(
          gateway: gateway,
          speech: speech,
          today: testToday(),
          showToast: false,
          onClose: () => closed += 1,
          onSaved: (value) => saved = value,
          onContinueWithForm: (value) => transcript = value,
        ),
      );
}

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  await tester.binding.setSurfaceSize(const Size(600, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness.build());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('X87 explains the microphone before the system prompt',
      (tester) async {
    final harness = _Harness(
      speech: ScriptedSpeechPort(
        availability: SpeechAvailability.needsPermission,
      ),
    );
    await _pump(tester, harness);

    expect(find.text('Use your voice to add payments'), findsOneWidget);
    expect(
      find.textContaining('Speech is turned into text on this phone.'),
      findsOneWidget,
    );
    expect(harness.speech.listenCalls, 0);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('The microphone is not allowed'), findsOneWidget);
    expect(find.text('Typed entry works as usual.'), findsOneWidget);
    expect(harness.speech.listenCalls, 0);
  });

  testWidgets('Allow opens X24 and Stop fills X25 with nothing saved',
      (tester) async {
    final harness = _Harness(
      speech: ScriptedSpeechPort(
        availability: SpeechAvailability.needsPermission,
        parts: <String>['Spent 40 dollars on coffee today at Starbucks'],
      ),
    );
    await _pump(tester, harness);
    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();

    expect(find.text('Listening, on this phone'), findsOneWidget);
    expect(
      find.text('Spent 40 dollars on coffee today at Starbucks'),
      findsOneWidget,
    );
    expect(harness.gateway.saved, isEmpty);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(find.text('VOICE · FORM FILLED'), findsOneWidget);
    expect(find.text('You said'), findsOneWidget);
    expect(find.text(r'$40.00'), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(harness.gateway.saved, isEmpty, reason: 'nothing saves before Save');
  });

  testWidgets('X25 Save writes one payment and returns it', (tester) async {
    final harness = _Harness(
      speech: ScriptedSpeechPort(
        parts: <String>[
          'Spent 40 dollars on coffee today at Starbucks with Checking',
        ],
      ),
    );
    await _pump(tester, harness);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, r'Save $40.00'));
    await tester.pumpAndSettle();

    expect(harness.gateway.saved, hasLength(1));
    expect(harness.saved, isNotNull);
    expect(harness.gateway.saved.single.amountMinor, -4000);
  });

  testWidgets('a missing account returns the transcript to the form',
      (tester) async {
    final harness = _Harness(
      speech: ScriptedSpeechPort(
        parts: <String>['Spent 40 dollars on coffee today at Starbucks'],
      ),
    );
    await _pump(tester, harness);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose an account before Save.'),
      findsOneWidget,
    );
    expect(find.text('Choose account'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Continue in the form'));
    await tester.pumpAndSettle();

    expect(harness.gateway.saved, isEmpty);
    expect(harness.transcript, 'Spent 40 dollars on coffee today at Starbucks');
  });

  testWidgets('an absent engine states it and starts no request',
      (tester) async {
    final harness = _Harness(
      speech: ScriptedSpeechPort(
        availability: SpeechAvailability.unavailable,
      ),
    );
    await _pump(tester, harness);

    expect(
      find.text('Voice is not available on this device'),
      findsOneWidget,
    );
    expect(harness.speech.listenCalls, 0);
    expect(find.text('Type it instead'), findsOneWidget);
  });
}
