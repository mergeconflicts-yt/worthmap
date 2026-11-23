import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// One design or privacy finding in a Dart file.
final class LintFinding {
  const LintFinding({
    required this.code,
    required this.offset,
    required this.length,
  });

  /// The rule name, for example `no_color_literals`.
  final String code;
  final int offset;
  final int length;
}

/// Scans [source] as [path]. This is the test entry point; the plugin calls
/// [scanUnit] with the analyzer unit.
List<LintFinding> scanSource(
  String source, {
  String path = 'lib/example.dart',
}) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  return scanUnit(result.unit, path: path);
}

/// Runs every rule on one compilation unit.
///
/// `chart_requires_table` and `hidden_mode_semantics` are P19/P20 rules. They
/// check a whole file or one widget class, not a single expression.
List<LintFinding> scanUnit(CompilationUnit unit, {required String path}) {
  final normalized = _normalizePath(path);
  if (!_applies(normalized)) {
    return const <LintFinding>[];
  }
  final visitor = _RuleVisitor(normalized);
  unit.accept(visitor);
  final findings = <LintFinding>[...visitor.findings];
  if (_isCharts(normalized)) {
    findings.addAll(_chartFindings(unit, normalized));
  }
  return findings;
}

/// The chart modules that are infrastructure, not a data chart.
const Set<String> _nonChartModules = <String>{
  'chart_frame.dart',
  'chart_tone.dart',
  'chart_values.dart',
  'brand_mark.dart',
};

/// DESIGN 7.1: a chart module needs a ChartFrame and a ChartTable, unless it
/// is a preview chart (`ChartFrame(preview: true)`).
List<LintFinding> _chartFindings(CompilationUnit unit, String path) {
  final name = path.split('/').last;
  if (_nonChartModules.contains(name)) {
    return const <LintFinding>[];
  }
  final source = unit.toSource();
  final paints = source.contains('CustomPaint') ||
      source.contains('extends CustomPainter');
  if (!paints) {
    return const <LintFinding>[];
  }
  final hasFrame = source.contains('ChartFrame');
  final hasTable = source.contains('ChartTable');
  final preview = source.contains('preview: true');
  if (!hasFrame || (!hasTable && !preview)) {
    return <LintFinding>[
      const LintFinding(code: 'chart_requires_table', offset: 0, length: 1),
    ];
  }
  return const <LintFinding>[];
}

/// custom_lint passes an absolute path. The rules make decisions on the
/// project-relative path, so cut it at `/lib/`.
String _normalizePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/lib/');
  if (index >= 0) {
    return normalized.substring(index + 1);
  }
  return normalized;
}

/// The rules apply to authored library code. Tests, tools, generated files and
/// the localization output are not app code.
bool _applies(String path) =>
    path.startsWith('lib/') &&
    !path.endsWith('.g.dart') &&
    !path.contains('/generated/') &&
    !path.contains('/l10n/');

bool _isDesign(String path) => path.startsWith('lib/design/');

bool _isCharts(String path) => path.startsWith('lib/design/charts/');

bool _isMotion(String path) => path.startsWith('lib/design/motion/');

String _typeName(InstanceCreationExpression node) =>
    node.constructorName.type.name2.lexeme;

bool _isNumeric(Expression expression) {
  if (expression is IntegerLiteral || expression is DoubleLiteral) {
    return true;
  }
  if (expression is PrefixExpression && expression.operator.lexeme == '-') {
    return _isNumeric(expression.operand);
  }
  return false;
}

bool _hasNumericArgument(ArgumentList arguments) =>
    arguments.arguments.any((Expression argument) {
      if (argument is NamedExpression) {
        return _isNumeric(argument.expression);
      }
      return _isNumeric(argument);
    });

bool _hasNamedArgument(
  ArgumentList arguments,
  Set<String> names,
) =>
    arguments.arguments.whereType<NamedExpression>().any(
        (NamedExpression argument) => names.contains(argument.name.label.name));

double? _numericNamedArgument(
  ArgumentList arguments,
  String name,
) {
  for (final argument in arguments.arguments.whereType<NamedExpression>()) {
    if (argument.name.label.name != name) {
      continue;
    }
    final value = argument.expression;
    if (value is IntegerLiteral) {
      return value.value?.toDouble();
    }
    if (value is DoubleLiteral) {
      return value.value;
    }
  }
  return null;
}

final class _RuleVisitor extends RecursiveAstVisitor<void> {
  _RuleVisitor(this.path);

  final String path;
  final List<LintFinding> findings = <LintFinding>[];

  void _report(String code, AstNode node) {
    findings.add(
      LintFinding(code: code, offset: node.offset, length: node.length),
    );
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkCreation(_typeName(node), node.argumentList, node);
    super.visitInstanceCreationExpression(node);
  }

  /// Checks one constructor call. Dart parses `Foo()` as a
  /// [MethodInvocation] and `const Foo()` as an [InstanceCreationExpression],
  /// so both visitors call this method.
  void _checkCreation(
    String type,
    ArgumentList arguments,
    AstNode node,
  ) {
    if (!_isDesign(path)) {
      if (type == 'Color') {
        _report('no_color_literals', node);
      }
      if (type == 'TextStyle') {
        _report('no_text_style', node);
      }
      if (<String>{
            'EdgeInsets',
            'EdgeInsetsDirectional',
            'SizedBox',
            'Padding',
          }.contains(type) &&
          _hasNumericArgument(arguments)) {
        _report('no_raw_spacing', node);
      }
      if (<String>{
        'BoxDecoration',
        'BoxShadow',
        'BorderRadius',
        'BorderRadiusDirectional',
        'Border',
        'BorderSide',
        'ShapeDecoration',
        'RoundedRectangleBorder',
      }.contains(type)) {
        _report('no_raw_decoration', node);
      }
      if (type == 'Container' || type == 'DecoratedBox') {
        _report('no_raw_containers', node);
      }
      if (type == 'Material' &&
          _hasNamedArgument(arguments, <String>{
            'color',
            'elevation',
            'shape',
            'borderRadius',
            'shadowColor',
            'surfaceTintColor',
          })) {
        _report('no_raw_containers', node);
      }
      if (<String>{
        'ElevatedButton',
        'TextButton',
        'OutlinedButton',
        'IconButton',
        'Chip',
        'ActionChip',
        'FilterChip',
        'ChoiceChip',
      }.contains(type)) {
        _report('no_material_buttons', node);
      }
      if (type == 'Icon') {
        _report('no_raw_icons', node);
      }
      if (type == 'NumberFormat') {
        _report('no_number_format', node);
      }
      if (type == 'CustomPaint') {
        _report('no_custom_paint', node);
      }
      if (type == 'LinearGradient' ||
          type == 'RadialGradient' ||
          type == 'SweepGradient' ||
          type == 'ShaderMask') {
        _report('no_gradient_on_data', node);
      }
    } else {
      // These rules also run on lib/design/.
      if (type == 'CustomPaint' && !_isCharts(path)) {
        _report('no_custom_paint', node);
      }
      if ((type == 'LinearGradient' ||
              type == 'RadialGradient' ||
              type == 'SweepGradient') &&
          _isCharts(path) &&
          !path.contains('brand_mark')) {
        // The hero fill, page spotlight, card and selected fill are allowed by
        // DESIGN 14.1. A chart's data fill is the open case; charts land in T11.
        // The brand mark's contour line is a brand element (DESIGN 6.7), not a
        // data fill; its source asset is absent (T10-BRANDMARK).
        _report('no_gradient_on_data', node);
      }
      if (type == 'BoxShadow') {
        Expression? color;
        for (final argument
            in arguments.arguments.whereType<NamedExpression>()) {
          if (argument.name.label.name == 'color') {
            color = argument.expression;
            break;
          }
        }
        if (_isNonBlackColor(color)) {
          _report('no_glow_except_endpoint', node);
        }
      }
    }

    if (type == 'TextStyle') {
      final size = _numericNamedArgument(arguments, 'fontSize');
      if (size != null && size < 13) {
        _report('min_text_size', node);
      }
    }
    if (type == 'Duration' && !_isMotion(path)) {
      _report('no_infinite_animation', node);
    }
  }

  bool _isNonBlackColor(Expression? expression) {
    if (expression is InstanceCreationExpression) {
      return _colorValue(expression.argumentList) != 0xFF000000 &&
          _colorValue(expression.argumentList) != 0x00000000;
    }
    if (expression is MethodInvocation) {
      return _colorValue(expression.argumentList) != 0xFF000000 &&
          _colorValue(expression.argumentList) != 0x00000000;
    }
    return false;
  }

  int? _colorValue(ArgumentList arguments) {
    final first =
        arguments.arguments.isEmpty ? null : arguments.arguments.first;
    return first is IntegerLiteral ? first.value : null;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final target = node.target;
    if (target == null) {
      _checkCreation(name, node.argumentList, node);
    } else if (target is SimpleIdentifier) {
      _checkCreation(target.name, node.argumentList, node);
      if ((target.name == 'ImageFilter' || target.name == 'MaskFilter') &&
          name == 'blur') {
        _report('no_glow_except_endpoint', node);
      }
    }

    if (name == 'copyWith' && !_isDesign(path)) {
      final changesType = node.argumentList.arguments
          .whereType<NamedExpression>()
          .any((NamedExpression argument) => <String>{
                'fontSize',
                'fontWeight',
                'letterSpacing',
                'height',
                'fontFamily',
                'fontFeatures',
                'foreground',
                'decoration',
              }.contains(argument.name.label.name));
      if (changesType) {
        _report('no_text_style', node);
      }
    }
    if (name == 'copyWith') {
      final size = _numericNamedArgument(node.argumentList, 'fontSize');
      if (size != null && size < 13) {
        _report('min_text_size', node);
      }
    }

    if (!_isDesign(path)) {
      if (name == 'toStringAsFixed' || name == 'toStringAsPrecision') {
        _report('no_number_format', node);
      }
    }

    if (name == 'repeat') {
      _report('no_infinite_animation', node);
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix.name;
    final name = node.identifier.name;
    _checkQualified(prefix, name, node);
    super.visitPrefixedIdentifier(node);
  }

  static final RegExp _hexColour = RegExp(
    r'^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$',
  );

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (!_isDesign(path) && _hexColour.hasMatch(node.value)) {
      _report('no_color_literals', node);
    }
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier) {
      _checkQualified(target.name, node.propertyName.name, node);
    }
    super.visitPropertyAccess(node);
  }

  void _checkQualified(String prefix, String name, AstNode node) {
    if (!_isDesign(path)) {
      if (prefix == 'Colors') {
        _report('no_color_literals', node);
      }
      if (prefix == 'Icons') {
        _report('no_raw_icons', node);
      }
      if (prefix == 'GoogleFonts') {
        _report('no_text_style', node);
      }
      if (prefix == 'AppIcons' && name == 'add') {
        _report('no_add_icon', node);
      }
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_isCharts(path) &&
        node.extendsClause?.superclass.name2.lexeme == 'CustomPainter') {
      _report('no_custom_paint', node);
    }
    if (_isDesign(path) && !path.startsWith('lib/design/gallery/')) {
      _checkHiddenState(node);
    }
    super.visitClassDeclaration(node);
  }

  static final RegExp _moneyField =
      RegExp(r'\b(?:Money|ValueSpec)\??\s+[a-zA-Z_]');

  /// DESIGN 4, 6.6: a widget that shows money has a hidden state. The class
  /// counts as a money widget when it holds a Money or ValueSpec field, or
  /// formats one in its body. It satisfies the rule with a `hidden` field or
  /// by reading [HiddenAmountsScope].
  void _checkHiddenState(ClassDeclaration node) {
    final hasBuild = node.members
        .whereType<MethodDeclaration>()
        .any((MethodDeclaration method) => method.name.lexeme == 'build');
    if (!hasBuild) {
      return;
    }
    final source = node.toSource();
    final showsMoney = _moneyField.hasMatch(source) ||
        source.contains('formatMoney(') ||
        source.contains('formatValueState(') ||
        source.contains('formatHeroValue(') ||
        source.contains('chartAmountText(') ||
        source.contains('MoneyText(');
    if (!showsMoney) {
      return;
    }
    if (RegExp(r'\bhidden\b').hasMatch(source) ||
        source.contains('HiddenAmountsScope')) {
      return;
    }
    findings.add(
      LintFinding(
        code: 'hidden_mode_semantics',
        offset: node.name.offset,
        length: node.name.length,
      ),
    );
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      _checkControlRow(node);
    }
    super.visitMethodDeclaration(node);
  }

  void _checkControlRow(MethodDeclaration node) {
    final enclosing = node.thisOrAncestorOfType<ClassDeclaration>();
    final className = enclosing?.name.lexeme ?? '';
    if (className.endsWith('Form')) {
      return;
    }
    var count = 0;
    final visitor = _ControlVisitor(
      onControl: (AstNode control) {
        count++;
        if (count == 2) {
          _report('one_control_row', control);
        }
      },
    );
    node.accept(visitor);
  }
}

/// Counts the three control-row components inside one `build` method.
final class _ControlVisitor extends RecursiveAstVisitor<void> {
  _ControlVisitor({required this.onControl});

  final void Function(AstNode node) onControl;

  static const Set<String> _controls = <String>{
    'SegmentedControl',
    'ChipRow',
    'PeriodControl',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(_typeName(node), node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) {
      _check(node.methodName.name, node);
    }
    super.visitMethodInvocation(node);
  }

  void _check(String type, AstNode node) {
    if (_controls.contains(type)) {
      onControl(node);
    }
  }
}
