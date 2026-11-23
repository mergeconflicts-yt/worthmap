import 'package:contour_lints/contour_lints.dart';
import 'package:flutter_test/flutter_test.dart';

/// T12: the custom lint rules (DESIGN 9) are tested on parsed source, so a
/// broken rule fails `flutter test` and not only the CLI.
Set<String> codes(String source, {String path = 'lib/features/example.dart'}) =>
    scanSource(source, path: path)
        .map((LintFinding finding) => finding.code)
        .toSet();

void main() {
  group('design rules outside lib/design', () {
    test('raw colour, text style, spacing and containers are reported', () {
      final found = codes('''
class Example {
  Object build() {
    return Container(
      color: Colors.red,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Text('x', style: TextStyle(fontSize: 10)),
      ),
    );
  }
}
''');
      expect(
        found,
        containsAll(<String>[
          'no_raw_containers',
          'no_color_literals',
          'no_raw_spacing',
          'no_text_style',
          'min_text_size',
        ]),
      );
    });

    test('a token and a component produce no finding', () {
      final found = codes('''
class Example {
  Object build() => const Padding(
        padding: EdgeInsets.all(Space.s),
        child: Text('x', style: AppText.body),
      );
}
''');
      expect(found, isEmpty);
    });

    test('the add icon is reported outside lib/design', () {
      expect(
        codes('const icon = AppIcons.add;'),
        contains('no_add_icon'),
      );
    });

    test('a hex colour string is reported outside lib/design', () {
      expect(
        codes("const colour = '#FF0000';"),
        contains('no_color_literals'),
      );
    });

    test('a duration literal is reported outside lib/design/motion', () {
      expect(
        codes('const d = Duration(milliseconds: 300);'),
        contains('no_infinite_animation'),
      );
      expect(
        codes(
          'const d = Duration(milliseconds: 300);',
          path: 'lib/design/motion/durations.dart',
        ),
        isEmpty,
      );
    });

    test('a shader is reported outside lib/design', () {
      expect(
        codes('const w = ShaderMask(shaderCallback: null);'),
        contains('no_gradient_on_data'),
      );
    });

    test('a custom painter is reported outside the charts folder', () {
      expect(
        codes('class P extends CustomPainter {}'),
        contains('no_custom_paint'),
      );
      expect(
        codes(
          'class P extends CustomPainter {}',
          path: 'lib/design/charts/p.dart',
        ),
        isNot(contains('no_custom_paint')),
      );
    });
  });

  group('one control row', () {
    test('two controls in a screen build are reported', () {
      final found = codes('''
class HomeScreen {
  Object build() => Column(children: <Object>[
    SegmentedControl(),
    ChipRow(),
  ]);
}
''');
      expect(found, contains('one_control_row'));
    });

    test('one control is allowed', () {
      expect(
        codes('class HomeScreen { Object build() => SegmentedControl(); }'),
        isEmpty,
      );
    });

    test('forms are excluded', () {
      expect(
        codes('''
class PaymentForm {
  Object build() => Column(children: <Object>[
    SegmentedControl(),
    ChipRow(),
  ]);
}
'''),
        isEmpty,
      );
    });
  });

  group('scope', () {
    test('lib/design is exempt from the styling rules', () {
      expect(
        codes(
          'const c = Color(0xFF000000); '
          'const s = TextStyle(fontSize: 14);',
          path: 'lib/design/example.dart',
        ),
        isEmpty,
      );
    });

    test('tests, tools and generated files are not app code', () {
      for (final path in <String>[
        'test/example_test.dart',
        'tool/example.dart',
        'lib/design/tokens/tokens.g.dart',
        'lib/l10n/generated/app_localizations.dart',
      ]) {
        expect(codes('const c = Color(0xFFFF0000);', path: path), isEmpty);
      }
    });

    test('an absolute custom_lint path is normalized', () {
      expect(
        codes(
          'const c = Color(0xFFFF0000);',
          path: '/Users/me/repo/lib/features/example.dart',
        ),
        contains('no_color_literals'),
      );
    });

    test('a text size below 13 is reported in lib/design too', () {
      expect(
        codes(
          'const s = TextStyle(fontSize: 12);',
          path: 'lib/design/example.dart',
        ),
        contains('min_text_size'),
      );
    });
  });

  group('P19/P20 chart and hidden rules', () {
    test('a chart without a ChartFrame and a table is reported', () {
      expect(
        codes(
          '''
class SpendChart {
  Object build() => const CustomPaint(painter: null);
}
''',
          path: 'lib/design/charts/spend_chart.dart',
        ),
        contains('chart_requires_table'),
      );
    });

    test('a chart with a frame and a table passes', () {
      expect(
        codes(
          '''
class SpendChart {
  Object build() => ChartFrame(
        label: 'Spent',
        chart: const CustomPaint(painter: null),
        table: const ChartTable(columns: <String>[], rows: <List<String>>[]),
      );
}
''',
          path: 'lib/design/charts/spend_chart.dart',
        ),
        isNot(contains('chart_requires_table')),
      );
    });

    test('a preview chart needs the frame only', () {
      expect(
        codes(
          '''
class SpendChart {
  Object build() => ChartFrame(
        label: 'Spent',
        preview: true,
        chart: const CustomPaint(painter: null),
      );
}
''',
          path: 'lib/design/charts/spend_chart.dart',
        ),
        isNot(contains('chart_requires_table')),
      );
    });

    test('a money widget without a hidden state is reported', () {
      expect(
        codes(
          '''
class SpendText {
  const SpendText(this.value);
  final Money value;
  Object build() => formatMoney(value);
}
''',
          path: 'lib/design/components/spend_text.dart',
        ),
        contains('hidden_mode_semantics'),
      );
    });

    test('a money widget with a hidden state passes', () {
      expect(
        codes(
          '''
class SpendText {
  const SpendText(this.value, {this.hidden});
  final Money value;
  final bool? hidden;
  Object build() => formatMoney(value);
}
''',
          path: 'lib/design/components/spend_text.dart',
        ),
        isNot(contains('hidden_mode_semantics')),
      );
    });

    test('a scope read satisfies the hidden rule', () {
      expect(
        codes(
          '''
class SpendText {
  const SpendText(this.value);
  final Money value;
  Object build(BuildContext context) => formatMoney(value);
  bool get isHidden => HiddenAmountsScope.hiddenOf(context);
}
''',
          path: 'lib/design/components/spend_text.dart',
        ),
        isNot(contains('hidden_mode_semantics')),
      );
    });

    test('feature code is not a money component', () {
      expect(
        codes(
          '''
class SpendText {
  const SpendText(this.value);
  final Money value;
  Object build() => formatMoney(value);
}
''',
          path: 'lib/features/spending/spend_text.dart',
        ),
        isNot(contains('hidden_mode_semantics')),
      );
    });
  });
}
