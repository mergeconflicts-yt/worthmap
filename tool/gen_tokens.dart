import 'dart:io';

import 'token_gen_lib.dart';

Future<void> main() async {
  final root = readTokensJson();
  final dart = generateTokensDart(root);
  final out = File(kTokensDartPath)..writeAsStringSync(dart);
  await formatDartFile(out.path);
  stdout.writeln('Wrote ${out.path}');
}
