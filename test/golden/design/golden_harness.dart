import 'package:contour/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled Inter and Inter Display fonts so goldens use the real
/// type, not the test placeholder font.
Future<void> loadContourFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('lib/design/fonts/Inter-ExtraLight.ttf'))
    ..addFont(rootBundle.load('lib/design/fonts/Inter-Regular.ttf'))
    ..addFont(rootBundle.load('lib/design/fonts/Inter-Medium.ttf'))
    ..addFont(rootBundle.load('lib/design/fonts/Inter-SemiBold.ttf'));
  await inter.load();

  final display = FontLoader('Inter Display')
    ..addFont(rootBundle.load('lib/design/fonts/InterDisplay-ExtraLight.ttf'))
    ..addFont(rootBundle.load('lib/design/fonts/InterDisplay-Light.ttf'));
  await display.load();
}

/// Wraps [child] in the app theme, a section and a text scale, as a screen does.
Widget goldenApp({
  required ThemeData theme,
  required Section section,
  required double textScale,
  required Widget child,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: SectionScope(
      section: section,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    ),
  );
}

/// Text scales required by AGENTS 7 (1.0 and 2.0).
const List<double> goldenScales = <double>[1.0, 2.0];
