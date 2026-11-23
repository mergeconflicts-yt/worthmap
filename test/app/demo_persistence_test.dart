// P4 local demo vault: a real SQLite file for the debug demo.
//
// The file holds synthetic data only. The cipher is the synthetic adapter
// until DB-A and PF-01 close (DECISIONS P4-LOCAL-DEMO-VAULT). The second build
// must not seed again.
import 'dart:io';

import 'package:contour/app/demo/demo_composition.dart';
import 'package:contour/data/db/db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a file-backed demo seeds once and reopens',
    () async {
      final directory = await Directory.systemTemp.createTemp('contour-demo');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });
      final path = '${directory.path}/contour-demo.db';

      late Vault first;
      await DemoComposition.build(
        dbPath: path,
        onVault: (Vault vault) => first = vault,
      );
      final count = await _accountCount(first);
      expect(count, greaterThan(0));
      expect(File(path).existsSync(), isTrue);
      await first.close();

      // A second build opens the same file. No seed runs twice.
      late Vault second;
      await DemoComposition.build(
        dbPath: path,
        onVault: (Vault vault) => second = vault,
      );
      expect(await _accountCount(second), count);
      await second.close();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<int> _accountCount(Vault vault) async {
  final row = await vault.database
      .customSelect('SELECT COUNT(*) AS n FROM accounts')
      .getSingle();
  return row.data['n'] as int;
}
