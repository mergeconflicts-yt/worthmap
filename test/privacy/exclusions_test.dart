import 'package:contour/data/backup/exclusions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every protected path kind is recordable and idempotent', () {
    final exclusions = BackupExclusionsStub();
    for (final kind in ProtectedPathKind.values) {
      exclusions.exclude(kind);
      exclusions.exclude(kind); // idempotent
      expect(exclusions.isExcluded(kind), isTrue);
    }
    expect(exclusions.recorded, hasLength(ProtectedPathKind.values.length));
  });

  test('an unrecorded kind is not excluded', () {
    final exclusions = BackupExclusionsStub();
    exclusions.exclude(ProtectedPathKind.databaseGeneration);
    expect(
      exclusions.isExcluded(ProtectedPathKind.recovery),
      isFalse,
    );
  });
}
