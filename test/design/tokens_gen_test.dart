import 'package:flutter_test/flutter_test.dart';

import '../../tool/token_gen_lib.dart';

void main() {
  test('generation is deterministic', () {
    final first = generateTokensDart(readTokensJson());
    final second = generateTokensDart(readTokensJson());
    expect(first, equals(second));
  });

  test('the committed file matches regeneration', () {
    String squash(String value) => value.replaceAll(RegExp(r'\s+'), '');
    expect(
      squash(generateTokensDart(readTokensJson())),
      equals(squash(readCommittedDart())),
    );
  });

  test('every declaration name is unique inside its class', () {
    final source = generateTokensDart(readTokensJson());
    final classes = source.split('abstract final class ').skip(1);
    expect(classes, isNotEmpty);
    final declaration = RegExp(r'static const \S+ (\w+) =');
    for (final block in classes) {
      final names =
          declaration.allMatches(block).map((match) => match.group(1)).toList();
      expect(
        names.toSet().length,
        equals(names.length),
        reason: 'duplicate declaration in ${block.split('\n').first}',
      );
    }
  });
}
