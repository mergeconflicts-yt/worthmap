import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// N-01 (PF-01-ANDROID): the release manifest must opt out of cloud backup
// and device transfer, and it must hold no INTERNET permission until the
// price-gateway task lands. Only the debug and profile manifests may carry
// INTERNET.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('release manifest disables backup and has no INTERNET permission', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules='));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });

  test('extraction rules exclude every domain for backup and transfer', () {
    final rules = read(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    );
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    for (final domain in <String>[
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
    ]) {
      expect(
        RegExp('cloud-backup[\\s\\S]*exclude domain="$domain"').hasMatch(rules),
        isTrue,
        reason: 'cloud-backup must exclude $domain',
      );
      expect(
        RegExp('device-transfer[\\s\\S]*exclude domain="$domain"')
            .hasMatch(rules),
        isTrue,
        reason: 'device-transfer must exclude $domain',
      );
    }
  });
}
