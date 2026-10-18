import 'package:contour/app/widgets/editor.dart';
import 'package:contour/app/widgets/layout_model.dart';
import 'package:contour/app/widgets/layout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save then load returns the stored layout', () async {
    final repo = InMemoryLayoutRepository();
    const commit = LayoutCommit(
      surfaceKey: 'screen:home',
      sections: <LayoutSection>[
        LayoutSection(
          key: 'today',
          titleKey: 'section.today',
          placements: <LayoutPlacement>[
            LayoutPlacement(itemKey: 'test.own', size: WidgetSize.full),
          ],
        ),
      ],
      baseLayoutVersion: 3,
      newInThisVersion: <String>{'test.own'},
    );
    await repo.save(commit);

    final loaded = await repo.load('screen:home');
    expect(loaded, isNotNull);
    expect(loaded!.baseLayoutVersion, 3);
    expect(loaded.sections.single.placements.single.itemKey, 'test.own');
    expect(loaded.toSurfaceLayout().surfaceKey, 'screen:home');
    await repo.dispose();
  });

  test('load misses before a save', () async {
    final repo = InMemoryLayoutRepository();
    expect(await repo.load('screen:home'), isNull);
    await repo.dispose();
  });

  test('clear removes a saved surface', () async {
    final repo = InMemoryLayoutRepository();
    await repo.save(
      const LayoutCommit(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[],
        baseLayoutVersion: 1,
        newInThisVersion: <String>{},
      ),
    );
    await repo.clear('screen:home');
    expect(await repo.load('screen:home'), isNull);
    await repo.dispose();
  });

  test('changes fires with the surface key', () async {
    final repo = InMemoryLayoutRepository();
    final events = <String>[];
    final subscription = repo.changes.listen(events.add);
    await repo.save(
      const LayoutCommit(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[],
        baseLayoutVersion: 1,
        newInThisVersion: <String>{},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, <String>['screen:home']);
    await subscription.cancel();
    await repo.dispose();
  });
}
