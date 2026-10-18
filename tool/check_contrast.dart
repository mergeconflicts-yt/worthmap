import 'dart:io';
import 'dart:math' as math;

import 'token_gen_lib.dart';

/// A measured pair below its minimum passes only when a closed decision exempts
/// it. The map holds `pair -> decision id`; the pair is `label|theme|background`.
/// It is a failure while the decision is still an open question (CR-19).
const Map<String, String> _exemptions = <String, String>{
  'state.loss|light|page': 'LIGHT-LOSS-CONTRAST',
  'state.loss|light|pageSpotlight': 'LIGHT-LOSS-CONTRAST',
  'data.signed.loss|light|page': 'LIGHT-LOSS-CONTRAST',
  'data.signed.loss|light|pageSpotlight': 'LIGHT-LOSS-CONTRAST',
  'text.heroFill.stop1|light|page': 'T05-HERO-FILL-CONTRAST',
};

/// Decision ids that are closed and permit their exemption to pass. Add an id
/// only when docs/DECISIONS.md records it under "Decided" with the reason.
/// The ids above are open questions, so their pairs fail until the design owner
/// supplies a compliant token or changes the contract (R07).
const Set<String> _closedDecisions = <String>{};

void main() {
  final tokenMap = _colorTokenMap();
  final glass = _gradientStopMap('color.role.surface.glass');
  final heroFill = _gradientStopMap('color.role.text.heroFill');
  final failures = <String>[];
  final warnings = <String>[];
  var checks = 0;

  /// A below-minimum pair fails unless a *closed* decision exempts it. An open
  /// decision keeps the failure visible (R07, CR-19).
  void record(String pair, String message) {
    final decision = _exemptions[pair];
    if (decision == null) {
      failures.add(message);
      return;
    }
    if (_closedDecisions.contains(decision)) {
      warnings.add('$message (exempt: $decision)');
      return;
    }
    failures.add('$message (open decision $decision; resolve or change the '
        'contract, then close it in docs/DECISIONS.md)');
  }

  void check(
    String label,
    String fgPath,
    String theme, {
    required List<_Bg> backgrounds,
    double min = 4.5,
    bool mark = false,
  }) {
    final fg = _resolve(tokenMap, fgPath, theme, mark: mark);
    if (fg == null) {
      failures.add('$label: missing token $fgPath ($theme).');
      return;
    }
    for (final bg in backgrounds) {
      if (bg.color == null) {
        failures.add('$label: missing background ${bg.label}.');
        continue;
      }
      checks++;
      final ratio = _contrast(fg, bg.color!);
      if (ratio + 1e-9 < min) {
        final message = '$label ($theme) on ${bg.label}: '
            '${ratio.toStringAsFixed(2)}:1 < ${min.toStringAsFixed(1)}:1';
        record('$label|$theme|${bg.label}', message);
      }
    }
  }

  for (final theme in <String>['dark', 'light']) {
    final page = _Bg(
      'page',
      _resolve(tokenMap, 'color.palette.page', theme),
    );
    // DESIGN 9: check the composited page. The top spotlight lays white over the
    // page, so this is the worst page surface for text.
    final spotlight = _Bg(
      'pageSpotlight',
      _over(_spotlightFill(theme), page.color!),
    );
    final sheet = _Bg(
      'sheet',
      _resolve(tokenMap, 'color.role.surface.sheet', theme),
    );
    final inverse = _Bg(
      'inverse',
      _resolve(tokenMap, 'color.role.surface.inverse', theme),
    );
    final destructive = _Bg(
      'destructive',
      _resolve(tokenMap, 'color.role.action.destructive.fill', theme),
    );
    final glassBgs =
        glass[theme]!.map((stop) => _Bg('glass', stop)).toList(growable: false);
    final tileColor = _resolve(tokenMap, 'color.role.surface.tile', theme);
    final tileBgs = glass[theme]!
        .map((stop) => _Bg('tile', _over(tileColor!, stop)))
        .toList(growable: false);

    for (final role in <String>[
      'primary',
      'secondary',
      'control',
    ]) {
      check(
        'text.$role',
        'color.role.text.$role',
        theme,
        backgrounds: <_Bg>[page, spotlight, ...glassBgs, ...tileBgs],
      );
    }
    check(
      'text.control on sheet',
      'color.role.text.control',
      theme,
      backgrounds: <_Bg>[sheet],
    );
    check(
      'icon.secondary',
      'color.role.icon.secondary',
      theme,
      backgrounds: <_Bg>[page, spotlight, ...glassBgs, ...tileBgs],
      min: 3.0,
    );
    check(
      'text.onInverse',
      'color.role.text.onInverse',
      theme,
      backgrounds: <_Bg>[inverse],
    );
    check(
      'action.destructive.text',
      'color.role.action.destructive.text',
      theme,
      backgrounds: <_Bg>[destructive],
    );
    check(
      'state.gain',
      'color.role.state.gain',
      theme,
      backgrounds: <_Bg>[page, spotlight],
    );
    check(
      'state.loss',
      'color.role.state.loss',
      theme,
      backgrounds: <_Bg>[page, spotlight],
    );
    check(
      'data.signed.gain',
      'color.data.signed.gain',
      theme,
      backgrounds: <_Bg>[page, spotlight],
    );
    check(
      'data.signed.loss',
      'color.data.signed.loss',
      theme,
      backgrounds: <_Bg>[page, spotlight],
    );

    final heroStops = heroFill[theme]!;
    for (var i = 0; i < heroStops.length; i++) {
      checks++;
      final ratio = _contrast(heroStops[i], page.color!);
      if (ratio + 1e-9 < 7.0) {
        final message = 'text.heroFill stop $i ($theme) on page: '
            '${ratio.toStringAsFixed(2)}:1 < 7.0:1';
        record('text.heroFill.stop$i|$theme|page', message);
      }
    }

    for (final section in _sections) {
      check(
        'section.$section.text',
        'color.section.$section.text',
        theme,
        backgrounds: <_Bg>[page, ...glassBgs, ...tileBgs],
      );
      final start = _resolve(
        tokenMap,
        'color.section.$section.gradientStart',
        theme,
      );
      final end = _resolve(
        tokenMap,
        'color.section.$section.gradientEnd',
        theme,
      );
      check(
        'text.onSection ($section)',
        'color.role.text.onSection',
        theme,
        backgrounds: <_Bg>[
          _Bg('$section.start', start),
          _Bg('$section.end', end),
        ],
      );
    }

    for (final category in _categories) {
      check(
        'category.$category text',
        'color.data.category.$category',
        theme,
        backgrounds: <_Bg>[page, ...glassBgs, ...tileBgs],
      );
      check(
        'category.$category mark',
        'color.data.category.$category',
        theme,
        backgrounds: <_Bg>[page, ...glassBgs, ...tileBgs],
        min: 3.0,
        mark: true,
      );
    }
  }

  _checkHeat(map: tokenMap, theme: 'dark', failures: failures);
  checks++;

  for (final warning in warnings) {
    stdout.writeln('check_contrast: warning: $warning');
  }
  if (failures.isEmpty) {
    stdout.writeln('check_contrast: OK ($checks pairs)');
    return;
  }
  for (final failure in failures) {
    stderr.writeln('check_contrast: $failure');
  }
  exitCode = 1;
}

const List<String> _sections = <String>[
  'home',
  'spending',
  'income',
  'wealth',
  'plan',
];

const List<String> _categories = <String>[
  'rent',
  'groceries',
  'dining',
  'shopping',
  'transport',
  'utilities',
  'subscriptions',
  'fun',
  'other',
  'needs',
  'wants',
  'invested',
  'inCash',
];

final class _Bg {
  const _Bg(this.label, this.color);

  final String label;
  final _Rgba? color;
}

/// White labels on the heat scale are checked at the strongest gain fill,
/// k = 60% (DESIGN 2.4).
void _checkHeat({
  required Map<String, Map<String, String>> map,
  required String theme,
  required List<String> failures,
}) {
  final base = _parse(map['color.data.heat.mixBase']![theme]!);
  final gain = _parse(map['color.data.heat.gain']![theme]!);
  const k = 0.6;
  final fill = _Rgba(
    base.r + (gain.r - base.r) * k,
    base.g + (gain.g - base.g) * k,
    base.b + (gain.b - base.b) * k,
    1,
  );
  const white = _Rgba(1, 1, 1, 1);
  final ratio = _contrast(white, fill);
  if (ratio + 1e-9 < 4.5) {
    failures.add(
      'heat gain label: ${ratio.toStringAsFixed(2)}:1 < 4.5:1',
    );
  }
}

Map<String, Map<String, String>> _colorTokenMap() {
  final map = <String, Map<String, String>>{};
  for (final leaf in flattenTokens(readTokensJson())) {
    if (leaf.type != 'color') {
      continue;
    }
    final value = leaf.node[r'$value'] as Map<String, dynamic>;
    map[leaf.path] = <String, String>{
      'dark': value['dark'] as String,
      'light': value['light'] as String,
      if (value['lightMark'] != null) 'lightMark': value['lightMark'] as String,
    };
  }
  return map;
}

/// The top page spotlight fills white over the page (DESIGN 2.2, 9). The value
/// is a spotlight token; the theme entry holds `color` and `anchor`.
_Rgba _spotlightFill(String theme) {
  var node = readTokensJson();
  for (final part in 'color.role.surface.pageSpotlight'.split('.')) {
    node = node[part] as Map<String, dynamic>;
  }
  final value = node[r'$value'] as Map<String, dynamic>;
  final entry = value[theme] as Map<String, dynamic>;
  return _parse(entry['color'] as String);
}

Map<String, List<_Rgba>> _gradientStopMap(String path) {
  final root = readTokensJson();
  var node = root;
  for (final part in path.split('.')) {
    node = node[part] as Map<String, dynamic>;
  }
  final value = node[r'$value'] as Map<String, dynamic>;
  final result = <String, List<_Rgba>>{};
  for (final theme in <String>['dark', 'light']) {
    final stops =
        (value[theme] as Map<String, dynamic>)['stops'] as List<dynamic>;
    result[theme] =
        stops.map((stop) => _parse(stop as String)).toList(growable: false);
  }
  return result;
}

_Rgba? _resolve(
  Map<String, Map<String, String>> map,
  String path,
  String theme, {
  bool mark = false,
}) {
  final entry = map[path];
  if (entry == null) {
    return null;
  }
  final key = mark && theme == 'light' && entry.containsKey('lightMark')
      ? 'lightMark'
      : theme;
  final hex = entry[key] ?? entry[theme];
  return hex == null ? null : _parse(hex);
}

_Rgba _parse(String hex) {
  final digits = hex.startsWith('#') ? hex.substring(1) : hex;
  final argb = digits.length == 6 ? 'FF$digits' : digits;
  final value = int.parse(argb, radix: 16);
  return _Rgba(
    ((value >> 16) & 0xFF) / 255,
    ((value >> 8) & 0xFF) / 255,
    (value & 0xFF) / 255,
    ((value >> 24) & 0xFF) / 255,
  );
}

_Rgba _over(_Rgba fg, _Rgba bg) => _Rgba(
      fg.r * fg.a + bg.r * (1 - fg.a),
      fg.g * fg.a + bg.g * (1 - fg.a),
      fg.b * fg.a + bg.b * (1 - fg.a),
      1,
    );

double _contrast(_Rgba a, _Rgba b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(_Rgba c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _channel(double value) => value <= 0.03928
    ? value / 12.92
    : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

final class _Rgba {
  const _Rgba(this.r, this.g, this.b, this.a);

  final double r;
  final double g;
  final double b;
  final double a;
}
