import 'dart:convert';
import 'dart:io';

/// Shared loader and Dart emitter for `tool/gen_tokens.dart` and
/// `tool/check_tokens.dart`. Never imported by `lib/`.
const String kTokensJsonPath = 'lib/design/tokens/tokens.json';
const String kTokensDartPath = 'lib/design/tokens/tokens.g.dart';

/// A leaf token: its dotted path, its `$type` and its JSON node.
final class TokenLeaf {
  const TokenLeaf(this.path, this.type, this.node);

  final String path;
  final String type;
  final Map<String, dynamic> node;
}

Map<String, dynamic> readTokensJson() =>
    jsonDecode(File(kTokensJsonPath).readAsStringSync())
        as Map<String, dynamic>;

String readCommittedDart() => File(kTokensDartPath).readAsStringSync();

List<TokenLeaf> flattenTokens(Map<String, dynamic> root) {
  final leaves = <TokenLeaf>[];
  void walk(Map<String, dynamic> node, List<String> prefix) {
    if (node.containsKey(r'$type')) {
      leaves.add(TokenLeaf(prefix.join('.'), node[r'$type'] as String, node));
      return;
    }
    for (final entry in node.entries) {
      if (entry.key.startsWith(r'$')) {
        continue;
      }
      walk(entry.value as Map<String, dynamic>, <String>[...prefix, entry.key]);
    }
  }

  walk(root, const <String>[]);
  return leaves;
}

String camel(List<String> parts) {
  final buffer = StringBuffer(parts.first);
  for (final part in parts.skip(1)) {
    buffer
      ..write(part[0].toUpperCase())
      ..write(part.substring(1));
  }
  return buffer.toString();
}

String _nameAfter(String path) {
  final parts = path.split('.').sublist(1);
  return camel(parts);
}

String colorExpression(String hex) {
  final digits = hex.startsWith('#') ? hex.substring(1) : hex;
  final argb = digits.length == 6 ? 'FF$digits' : digits;
  return 'Color(0x${argb.toUpperCase()})';
}

String doubleExpression(num value) {
  if (value is int) {
    return '${value.toInt()}.0';
  }
  if (value == value.roundToDouble()) {
    return '${value.toInt()}.0';
  }
  return value.toString();
}

String _stopsExpression(int count) {
  final stops = <String>[];
  for (var i = 0; i < count; i++) {
    final value = count == 1 ? 0.0 : i / (count - 1);
    if (value == 0) {
      stops.add('0.0');
    } else if (value == 1) {
      stops.add('1.0');
    } else {
      stops.add(value.toStringAsFixed(3));
    }
  }
  return stops.join(', ');
}

String _colorsExpression(List<dynamic> stops) =>
    stops.map((stop) => colorExpression(stop as String)).join(', ');

String _gradientExpression(Map<String, dynamic> value) {
  final colors = value['stops'] as List<dynamic>;
  final buffer = StringBuffer('GradientSpec(\n')
    ..writeln('      angle: ${doubleExpression(value['angle'] as num)},')
    ..writeln('      colors: <Color>[${_colorsExpression(colors)}],')
    ..writeln('      stops: <double>[${_stopsExpression(colors.length)}],')
    ..write('    )');
  return buffer.toString();
}

String _spotlightExpression(Map<String, dynamic> value) =>
    'SpotlightSpec(color: ${colorExpression(value['color'] as String)}, '
    "anchor: '${value['anchor']}')";

String _shadowLayerExpression(Map<String, dynamic> layer) {
  final buffer = StringBuffer('ShadowLayer(\n')
    ..writeln('        dx: ${doubleExpression(layer['dx'] as num)},')
    ..writeln('        dy: ${doubleExpression(layer['dy'] as num)},')
    ..writeln('        blur: ${doubleExpression(layer['blur'] as num)},')
    ..writeln('        spread: ${doubleExpression(layer['spread'] as num)},')
    ..writeln('        color: ${colorExpression(layer['color'] as String)},')
    ..writeln('        inset: ${layer['inset'] as bool},')
    ..write('      )');
  return buffer.toString();
}

String _elevationExpression(Map<String, dynamic> value) {
  final layers = value['layers'] as List<dynamic>;
  final buffer = StringBuffer('ElevationSpec(\n')
    ..writeln('    layers: <ShadowLayer>[');
  for (final layer in layers.cast<Map<String, dynamic>>()) {
    buffer.writeln('      ${_shadowLayerExpression(layer)},');
  }
  buffer.writeln('    ],');
  final fill = value['fill'];
  if (fill != null) {
    buffer.writeln('    fill: ${colorExpression(fill as String)},');
  }
  final blur = value['blur'];
  if (blur != null) {
    buffer.writeln('    blur: ${doubleExpression(blur as num)},');
  }
  buffer.write('  )');
  return buffer.toString();
}

String generateTokensDart(Map<String, dynamic> root) {
  final leaves = flattenTokens(root);

  final darkColors = <String>[];
  final lightColors = <String>[];
  final darkGradients = <String>[];
  final lightGradients = <String>[];
  final shared = <String, List<String>>{};

  for (final leaf in leaves) {
    final category = leaf.path.split('.').first;
    final name = _nameAfter(leaf.path);
    final value = leaf.node[r'$value'];
    switch (category) {
      case 'color':
        if (leaf.type == 'color') {
          final map = value as Map<String, dynamic>;
          darkColors.add(
            '  static const Color $name = ${colorExpression(map['dark'] as String)};',
          );
          lightColors.add(
            '  static const Color $name = ${colorExpression(map['light'] as String)};',
          );
          final mark = map['lightMark'];
          if (mark != null) {
            lightColors.add(
              '  static const Color ${name}Mark = ${colorExpression(mark as String)};',
            );
          }
        } else if (leaf.type == 'gradient') {
          final map = value as Map<String, dynamic>;
          darkGradients.add(
            '  static const GradientSpec $name = ${_gradientExpression(map['dark'] as Map<String, dynamic>)};',
          );
          lightGradients.add(
            '  static const GradientSpec $name = ${_gradientExpression(map['light'] as Map<String, dynamic>)};',
          );
        } else if (leaf.type == 'spotlight') {
          final map = value as Map<String, dynamic>;
          darkGradients.add(
            '  static const SpotlightSpec $name = ${_spotlightExpression(map['dark'] as Map<String, dynamic>)};',
          );
          lightGradients.add(
            '  static const SpotlightSpec $name = ${_spotlightExpression(map['light'] as Map<String, dynamic>)};',
          );
        }
      case 'space':
      case 'size':
      case 'radius':
      case 'border':
        final className = switch (category) {
          'space' => 'SpaceTokens',
          'size' => 'SizeTokens',
          'radius' => 'RadiusTokens',
          _ => 'BorderTokens',
        };
        shared.putIfAbsent(className, () => <String>[]).add(
              '  static const double $name = ${doubleExpression(value as num)};',
            );
      case 'motion':
        shared.putIfAbsent('MotionTokens', () => <String>[]).add(
              '  static const int $name = ${(value as num).toInt()};',
            );
      case 'glow':
        shared.putIfAbsent('GlowTokens', () => <String>[]).add(
              '  static const double $name = ${doubleExpression(value as num)};',
            );
      case 'font':
        if (leaf.type == 'fontFamily') {
          shared.putIfAbsent('FontTokens', () => <String>[]).add(
                "  static const String $name = '${value as String}';",
              );
        } else {
          shared.putIfAbsent('FontTokens', () => <String>[]).add(
                '  static const int $name = ${(value as num).toInt()};',
              );
        }
      case 'type':
        final map = value as Map<String, dynamic>;
        shared.putIfAbsent('TypeTokens', () => <String>[]).add(
              '  static const TypeStyle $name = TypeStyle(\n'
              '    size: ${doubleExpression(map['size'] as num)},\n'
              '    weight: ${(map['weight'] as num).toInt()},\n'
              '    letterSpacing: ${doubleExpression(map['letterSpacing'] as num)},\n'
              '    lineHeight: ${doubleExpression(map['lineHeight'] as num)},\n'
              '    uppercase: ${map['uppercase'] as bool},\n'
              '  );',
            );
      case 'elevation':
        final map = value as Map<String, dynamic>;
        shared.putIfAbsent('ElevationTokensDark', () => <String>[]).add(
              '  static const ElevationSpec $name = ${_elevationExpression(map['dark'] as Map<String, dynamic>)};',
            );
        shared.putIfAbsent('ElevationTokensLight', () => <String>[]).add(
              '  static const ElevationSpec $name = ${_elevationExpression(map['light'] as Map<String, dynamic>)};',
            );
    }
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: $kTokensJsonPath')
    ..writeln('// Regenerate: dart run tool/gen_tokens.dart')
    ..writeln()
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln()
    ..writeln("import 'token_types.dart';")
    ..writeln();

  void writeClass(String name, List<String> members) {
    if (members.isEmpty) {
      return;
    }
    buffer
      ..writeln('abstract final class $name {')
      ..writeln('  const $name._();')
      ..writeln()
      ..writeln(members.join('\n\n'))
      ..writeln('}')
      ..writeln();
  }

  writeClass('ColorTokensDark', darkColors);
  writeClass('ColorTokensLight', lightColors);
  writeClass('GradientTokensDark', darkGradients);
  writeClass('GradientTokensLight', lightGradients);
  for (final entry in shared.entries) {
    writeClass(entry.key, entry.value);
  }
  return buffer.toString();
}

Future<void> formatDartFile(String path) async {
  final result = await Process.run('dart', <String>['format', path]);
  if (result.exitCode != 0) {
    stderr.writeln(result.stderr);
    throw ProcessException('dart', <String>['format', path]);
  }
}
