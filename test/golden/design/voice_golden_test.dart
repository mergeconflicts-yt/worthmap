@Tags(<String>['golden'])
library;

import 'package:contour/data/speech/speech.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:contour/features/add/voice/x24_voice_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/add/fake_payments_gateway.dart';
import '../../features/add/fake_speech_port.dart';
import 'golden_harness.dart';

FakePaymentsGateway _gateway() => FakePaymentsGateway(
      expenseCategories: const <CategorySummary>[
        CategorySummary(id: 'category-dining', name: 'Dining'),
        CategorySummary(id: 'category-coffee', name: 'Coffee'),
      ],
    );

Widget _voice(ScriptedSpeechPort speech, {bool toast = false}) =>
    X24VoiceCapture(
      gateway: _gateway(),
      speech: speech,
      today: testToday(),
      showToast: toast,
      onClose: () {},
      onSaved: (_) {},
      onContinueWithForm: (_) {},
    );

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('voice listening ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1500 : 2300),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final speech = ScriptedSpeechPort(
          parts: <String>[
            'Spent 40 dollars on coffee today at Starbucks with Checking',
          ],
        );

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: _voice(speech),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x24_listening_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('voice filled ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(
          Size(420, scale == 1.0 ? 1800 : 2600),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final speech = ScriptedSpeechPort(
          parts: <String>[
            'Spent 40 dollars on coffee today at Starbucks with Checking',
          ],
        );

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: _voice(speech),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stop'));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x25_filled_${theme.$1}_${scale}x.png',
          ),
        );
      });

      testWidgets('microphone permission ${theme.$1} ${scale}x',
          (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final speech = ScriptedSpeechPort(
          availability: SpeechAvailability.needsPermission,
        );

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.spending,
            textScale: scale,
            child: _voice(speech),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'screens_x87_permission_${theme.$1}_${scale}x.png',
          ),
        );
      });
    }
  }
}
