@Tags(<String>['golden'])
library;

import 'package:contour/design/design.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Goldens for the T10 design additions (DESIGN 6.3/6.7): BrandMark,
/// SelectRow, ToggleRow and CapsuleMeter. Dark and Light, 1.0 and 2.0.
class _NewComponentsGallery extends StatelessWidget {
  const _NewComponentsGallery();

  @override
  Widget build(BuildContext context) {
    final l = lookupAppLocalizations(const Locale('en'));
    final tokens = context.tokens;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: BrandMark(point: 64)),
          const VSpace(Space.l),
          GlassCard(
            title: l.x80CardCapture,
            child: Column(
              children: [
                SelectRow(
                  name: l.x80CaptureSources,
                  value: l.x80CaptureSourcesValue,
                ),
                SelectRow(
                  name: l.x01ShieldRowName,
                  line: l.x01ShieldRowLine,
                  chevron: false,
                ),
              ],
            ),
          ),
          const VSpace(Space.card),
          GlassCard(
            title: l.x86NetworkTitle,
            child: ToggleRow(
              name: l.x86TurnOff,
              description: l.x86TurnOffLine,
              value: false,
              onChanged: (_) {},
              semanticLabel: l.x86TurnOffSpoken,
            ),
          ),
          const VSpace(Space.card),
          GlassCard(
            title: l.x03GetStartedTitle,
            meta: l.x03GetStartedMeta,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CapsuleMeter(
                  value: 0,
                  limit: 5,
                  spokenLabel: l.x03GetStartedSpoken,
                ),
                const VSpace(Space.m),
                CapsuleMeter(
                  value: 3,
                  limit: 5,
                  spokenLabel: l.x03GetStartedSpoken,
                ),
                const VSpace(Space.m),
                CapsuleMeter(
                  value: 5,
                  limit: 5,
                  spokenLabel: l.x03GetStartedSpoken,
                ),
              ],
            ),
          ),
          const VSpace(Space.card),
          Text(
            l.x01Caption,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

void main() {
  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      testWidgets('new components ${theme.$1} ${scale}x', (tester) async {
        await loadContourFonts();
        await tester.binding.setSurfaceSize(const Size(420, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          goldenApp(
            theme: theme.$2,
            section: Section.home,
            textScale: scale,
            child: const _NewComponentsGallery(),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('extra_components_${theme.$1}_${scale}x.png'),
        );
      });
    }
  }
}
