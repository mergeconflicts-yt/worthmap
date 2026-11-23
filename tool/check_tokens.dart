import 'dart:io';

import 'token_gen_lib.dart';

void main() {
  final failures = <String>[];

  _checkRegeneration(failures);
  _checkDarkAndLight(failures);
  _checkNoColourLiterals(failures);
  _checkUnusedTokens(failures);

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

/// T03-UNUSED-TOKENS (DESIGN 9): every generated token member must have a
/// consumer, or a documented reserve entry here. The reserve holds later
/// phase families whose consumers do not exist yet; a token leaves the
/// reserve when its component lands. Recorded in docs/DECISIONS.md
/// (T03-UNUSED-TOKENS, 2026-11-22).
const Map<String, String> kReservedUnusedTokens = <String, String>{
  // Chart colour families (charts land in a later phase; T11 charts note).
  r'dataAssetClass\w*': 'asset-class chart colours and marks',
  r'dataCategory\w*': 'category chart colours and marks',
  r'dataSeries\w*': 'series chart colours and marks',
  r'dataHeat\w*': 'heat scale colours',
  r'dataFlow\w*': 'flow chart colours',
  r'dataDebt\w*': 'debt chart colour and mark',
  r'dataSigned\w*': 'signed chart glyph colours',
  // Chart geometry (painters land with the charts).
  r'draw\w*': 'chart painter geometry',
  r'glyph\w*': 'calendar/symbol glyph geometry',
  r'meter[SM]': 'smaller capsule meters',
  r'ringStroke\w*': 'ring painters',
  r'vial\w*': 'goal vials',
  r'calendarCell\w*': 'Plan calendar cells',
  r'endDot\w*': 'brand end dot geometry',
  r'haloRadius': 'brand halo geometry',
  r'hairline': 'chart hairline width',
  r'markMaxOpacity': 'chart mark opacity cap',
  // Later widget sizes (WIDGET catalogue rows land in later phases).
  r'badge[LS]': 'later badge sizes',
  r'row(M|Holding)': 'later row heights',
  r'tileQuick\w*': 'Quick look tile sizes',
  r'tabBar': 'tab bar height (the tab bar lands with T09 tabs)',
  r'toggleTrack': 'ToggleRow track geometry',
  // Motion tokens (animations land with later components; DESIGN 13).
  r'fast|settle|revisit|press\w*|dismiss': 'motion tokens',
  // Font weight names: weights are consumed inside TypeToken weights; these
  // named constants document the same values for the design reference.
  r'weight\w*': 'named font weights (values flow through TypeTokens)',
  // Raw base palette values (DESIGN 2.1): the colour tokens carry the same
  // hex literally; the palette members name the Obsidian base colours for
  // the design reference.
  r'palette\w*': 'raw Obsidian base palette names',
};

bool _isReserved(String member) {
  for (final pattern in kReservedUnusedTokens.keys) {
    if (RegExp('^$pattern\$').hasMatch(member)) {
      return true;
    }
  }
  return false;
}

void _checkUnusedTokens(List<String> failures) {
  final generated = File(kTokensDartPath).readAsStringSync();
  final memberPattern = RegExp(r'static const \w[\w<>, ]*?\s+(\w+)\s*=');
  final members = <String>{};
  for (final match in memberPattern.allMatches(generated)) {
    members.add(match.group(1)!);
  }

  // A member referenced anywhere in lib, test or tool has a consumer. A
  // member referenced only inside tokens.g.dart (a composite definition) is
  // also consumed: the theme reads the composite.
  final declaredLine = RegExp(r'^\s*static const', multiLine: true);
  final internalBody = generated
      .split('\n')
      .where((line) => !declaredLine.hasMatch(line))
      .join('\n');
  final used = <String>{};
  for (final root in <String>['lib', 'test', 'tool']) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.path.endsWith('tokens.g.dart')
          ? internalBody
          : entity.readAsStringSync();
      used.addAll(
        RegExp(r'\b(\w+)\b').allMatches(source).map((m) => m.group(1)!),
      );
    }
  }

  final unused = members.where((m) => !used.contains(m)).toList()..sort();
  final unreserved = unused.where((m) => !_isReserved(m)).toList();
  for (final member in unreserved) {
    failures.add(
      'token member "$member" has no consumer and no reserve entry '
      '(add the consumer, or a documented reserve entry in '
      'tool/check_tokens.dart).',
    );
  }
}

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
