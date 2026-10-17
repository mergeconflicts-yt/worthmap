import 'dart:io';

import 'token_gen_lib.dart';

void main() {
  final failures = <String>[];

  _checkRegeneration(failures);
  _checkDarkAndLight(failures);
  _checkNoColourLiterals(failures);

  if (failures.isEmpty) {
    stdout.writeln('check_tokens: OK');
    return;
  }
  for (final failure in failures) {
    stderr.writeln('check_tokens: $failure');
  }
  exitCode = 1;
}

/// Regenerates the Dart file into a temp path inside the package, formats it,
/// and compares it with the committed file. The temp path stays inside the
/// package so `dart format` uses the package language version.
void _checkRegeneration(List<String> failures) {
  final dir = Directory('.dart_tool/check_tokens_tmp')
    ..createSync(recursive: true);
  try {
    final temp = File('${dir.path}/tokens.g.dart')
      ..writeAsStringSync(generateTokensDart(readTokensJson()));
    final result = Process.runSync('dart', <String>['format', temp.path]);
    if (result.exitCode != 0) {
      failures.add('dart format failed: ${result.stderr}');
      return;
    }
    final formatted = temp.readAsStringSync().trim();
    final current = File(kTokensDartPath).readAsStringSync().trim();
    if (formatted != current) {
      failures.add(
        '$kTokensDartPath is out of date. Run: dart run tool/gen_tokens.dart',
      );
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}

const Set<String> _dualTypes = <String>{
  'color',
  'gradient',
  'spotlight',
  'elevation',
};

void _checkDarkAndLight(List<String> failures) {
  for (final leaf in flattenTokens(readTokensJson())) {
    if (!_dualTypes.contains(leaf.type)) {
      continue;
    }
    final isDarkOnly =
        ((leaf.node[r'$extensions'] as Map<String, dynamic>?)?['contour']
                as Map<String, dynamic>?)?['darkOnly'] ==
            true;
    final value = leaf.node[r'$value'];
    if (value is! Map<String, dynamic>) {
      continue;
    }
    if (!value.containsKey('dark')) {
      failures.add('${leaf.path} has no dark value.');
    }
    if (!value.containsKey('light') && !isDarkOnly) {
      failures.add('${leaf.path} has no Light value and is not darkOnly.');
    }
  }
}

final RegExp _colourLiteral = RegExp(
  r'Color\(|Colors\.|Color\.fromARGB|0x[0-9A-Fa-f]{8}\b',
);

void _checkNoColourLiterals(List<String> failures) {
  final lib = Directory('lib');
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final path = entity.path;
    if (path.startsWith('lib/design/') || path.endsWith('.g.dart')) {
      continue;
    }
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (_colourLiteral.hasMatch(lines[i])) {
        failures
            .add('$path:${i + 1} has a colour literal outside lib/design/.');
      }
    }
  }
}
