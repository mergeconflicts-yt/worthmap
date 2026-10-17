import 'package:contour/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SectionScope defaults to Home', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext inner) {
            context = inner;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(context.section, equals(Section.home));
  });

  testWidgets('SectionScope reads the nearest section', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: SectionScope(
          section: Section.wealth,
          child: Builder(
            builder: (BuildContext inner) {
              context = inner;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(context.section, equals(Section.wealth));
  });

  test('the dark and light themes register ContourTokens', () {
    final dark = AppTheme.dark().extension<ContourTokens>();
    final light = AppTheme.light().extension<ContourTokens>();
    expect(dark, isNotNull);
    expect(light, isNotNull);
    expect(dark!.isDark, isTrue);
    expect(light!.isDark, isFalse);
  });

  test('every section has a role in both themes', () {
    for (final tokens in <ContourTokens>[
      ContourTokens.dark(),
      ContourTokens.light(),
    ]) {
      for (final section in Section.values) {
        final role = tokens.role(section);
        expect(role.gradientStart, isA<Color>());
        expect(role.selectedFill.colors, hasLength(2));
      }
    }
  });

  test('text sizes follow the DESIGN 2.5 minimum', () {
    const allowed = <String, double>{
      'chartAxis': 11,
      'tabLabel': 12,
      'weekday': 12,
      'chartLabel': 12,
    };
    AppText.all.forEach((name, style) {
      final size = style.fontSize!;
      if (allowed.containsKey(name)) {
        expect(size, equals(allowed[name]), reason: name);
      } else {
        expect(size, greaterThanOrEqualTo(13), reason: name);
      }
    });
  });

  test('number styles use tabular figures', () {
    for (final name in <String>[
      'numberHero.light',
      'numberXL',
      'numberL',
      'numberM',
      'numberS',
      'numberXS',
    ]) {
      final features = AppText.all[name]!.fontFeatures;
      expect(features, isNotNull, reason: name);
      expect(
        features!.any((feature) => feature.feature == 'tnum'),
        isTrue,
        reason: name,
      );
    }
  });

  test('icons are unique svg assets', () {
    final assets = AppIcons.all.values.map((icon) => icon.asset).toList();
    expect(assets.toSet().length, equals(assets.length));
    for (final asset in assets) {
      expect(asset, endsWith('.svg'));
      expect(asset, startsWith('lib/design/icons/'));
    }
  });
}
