import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/scan.dart';

export 'src/scan.dart';

/// The custom_lint entry point. It returns the Contour design and privacy
/// rules (DESIGN 9). The scan itself is in `src/scan.dart` so the rules can be
/// tested with parsed source, not only through the CLI.
PluginBase createPlugin() => _ContourLints();

final class _ContourLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => kLintCodes.entries
      .map((MapEntry<String, LintCode> entry) =>
          _ScanRule(entry.key, entry.value))
      .toList(growable: false);
}

/// Every rule name and its reported code. A rule reports only findings with
/// its own name, so one scan feeds all rules.
const Map<String, LintCode> kLintCodes = <String, LintCode>{
  'no_color_literals': LintCode(
    name: 'no_color_literals',
    problemMessage: 'Use a design token: no Color(...), Colors.* or hex colour '
        'outside lib/design/ (DESIGN 2, 9).',
  ),
  'no_text_style': LintCode(
    name: 'no_text_style',
    problemMessage: 'Use AppText: no TextStyle(...), font copyWith or '
        'GoogleFonts outside lib/design/ (DESIGN 2.5, 9).',
  ),
  'no_raw_spacing': LintCode(
    name: 'no_raw_spacing',
    problemMessage: 'Use Space.* or VSpace/HSpace: no number literal in '
        'EdgeInsets, SizedBox or Padding outside lib/design/ (DESIGN 2.7, 9).',
  ),
  'no_raw_decoration': LintCode(
    name: 'no_raw_decoration',
    problemMessage: 'Use a component: no BoxDecoration, BorderRadius, Border '
        'or ShapeDecoration outside lib/design/ (DESIGN 9).',
  ),
  'no_raw_containers': LintCode(
    name: 'no_raw_containers',
    problemMessage: 'Use a layout template or component: no styled Container, '
        'DecoratedBox or Material outside lib/design/ (DESIGN 9).',
  ),
  'no_material_buttons': LintCode(
    name: 'no_material_buttons',
    problemMessage: 'Use AppButton or AppIconButton: no Material button or '
        'Chip outside lib/design/ (DESIGN 9).',
  ),
  'no_raw_icons': LintCode(
    name: 'no_raw_icons',
    problemMessage: 'Use AppIcons: no Icon(Icons.*) outside lib/design/ '
        '(DESIGN 2.11, 9).',
  ),
  'no_add_icon': LintCode(
    name: 'no_add_icon',
    problemMessage: 'AppIcons.add is only for the tab bar or one header '
        'button (DESIGN 2.11, 9).',
  ),
  'no_number_format': LintCode(
    name: 'no_number_format',
    problemMessage: 'Format money through lib/design/format: no NumberFormat '
        'or toStringAsFixed outside lib/design/ (DESIGN 4, 8).',
  ),
  'one_control_row': LintCode(
    name: 'one_control_row',
    problemMessage: 'A screen has one control row: use one of '
        'SegmentedControl, ChipRow or PeriodControl (SPEC 3.3, DESIGN 9).',
  ),
  'no_custom_paint': LintCode(
    name: 'no_custom_paint',
    problemMessage: 'CustomPaint and CustomPainter are only for charts in '
        'lib/design/charts/ (DESIGN 9).',
  ),
  'min_text_size': LintCode(
    name: 'min_text_size',
    problemMessage: 'Text is at least 13 pt, except tabLabel, weekday, '
        'chartLabel and chartAxis (DESIGN 2.5, 9).',
  ),
  'no_gradient_on_data': LintCode(
    name: 'no_gradient_on_data',
    problemMessage: 'A gradient or ShaderMask is only for the page, card, '
        'fade, selected fill and hero number fill (DESIGN 9, 14.1).',
  ),
  'no_infinite_animation': LintCode(
    name: 'no_infinite_animation',
    problemMessage: 'No loop, no overshoot on a data mark, and no Duration '
        'literal outside lib/design/motion/ (DESIGN 2.10, 9).',
  ),
  'no_glow_except_endpoint': LintCode(
    name: 'no_glow_except_endpoint',
    problemMessage: 'Blur and coloured shadows are only for the end-point '
        'mark and the documented elevation (DESIGN 9).',
  ),
  'chart_requires_table': LintCode(
    name: 'chart_requires_table',
    problemMessage: 'A chart needs ChartFrame, one label and a ChartTable; '
        'ChartFrame(preview: true) needs the label only (DESIGN 7.1, 9).',
  ),
  'hidden_mode_semantics': LintCode(
    name: 'hidden_mode_semantics',
    problemMessage: 'A money widget needs a hidden state; a hidden label '
        'masks amounts as "\$······" and keeps dates, counts and % '
        '(DESIGN 4, 6.6, 9).',
  ),
};

final class _ScanRule extends DartLintRule {
  const _ScanRule(this.name, LintCode code) : super(code: code);

  final String name;

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      for (final finding in scanUnit(unit, path: resolver.path)) {
        if (finding.code == name) {
          reporter.reportErrorForOffset(
            code,
            finding.offset,
            finding.length,
          );
        }
      }
    });
  }
}
