import 'package:contour/app/widgets/editor.dart';
import 'package:contour/app/widgets/layout_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  final registry = testRegistry();
  final bundle = testBundle();

  LayoutEditor home() => LayoutEditor(
        registry: registry,
        bundle: bundle,
        surfaceKey: 'screen:home',
      );

  test('opens on the default layout', () {
    final editor = home();
    expect(editor.isDefaultScope, isTrue);
    expect(editor.canUndo, isFalse);
    expect(editor.sections.first.key, 'today');
  });

  test('hide removes a placement and undo restores it', () {
    final editor = home();
    editor.hide('test.own');
    expect(editor.contains('test.own'), isFalse);
    expect(editor.canUndo, isTrue);
    editor.undo();
    expect(editor.contains('test.own'), isTrue);
    expect(editor.canUndo, isFalse);
  });

  test('moves a widget within its section', () {
    final editor = home();
    editor.moveDown('test.alpha');
    final more = editor.sections.last;
    expect(more.placements.map((p) => p.itemKey).toList(), <String>[
      'test.gamma',
      'test.alpha',
    ]);
  });

  test('moves a widget at an edge without change', () {
    final editor = home();
    editor.moveUp('test.alpha');
    expect(editor.canUndo, isFalse);
    expect(editor.sections.last.placements.first.itemKey, 'test.alpha');
  });

  test('moves a section', () {
    final editor = home();
    editor.moveSectionDown('today');
    expect(editor.sections.first.key, 'more');
    expect(editor.sections.last.key, 'today');
  });

  test('add inserts at the target and marks the key new', () {
    final editor = LayoutEditor(
      registry: registry,
      bundle: bundle,
      surfaceKey: 'screen:spending',
    );
    expect(editor.isDefaultScope, isTrue);
    editor.add('test.alpha');
    expect(editor.contains('test.alpha'), isTrue);
    final section = editor.sections.single;
    expect(section.key, 'main');
    expect(section.placements.single.size, WidgetSize.half);
    final result = editor.done();
    expect(result, isA<SaveLayout>());
    expect(
      (result as SaveLayout).commit.newInThisVersion,
      contains('test.alpha'),
    );
  });

  test('add is a no-op when the widget is already present', () {
    final editor = home();
    editor.add('test.alpha');
    expect(editor.canUndo, isFalse);
  });

  test('add rejects an unknown key', () {
    final editor = home();
    expect(
      () => editor.add('ghost'),
      throwsA(isA<LayoutFormatError>()),
    );
  });

  test('done stamps the base layout version', () {
    final editor = LayoutEditor(
      registry: registry,
      bundle: testBundle(layoutVersion: 4),
      surfaceKey: 'screen:home',
    );
    editor.hide('test.own');
    final result = editor.done();
    expect(result, isA<SaveLayout>());
    final commit = (result as SaveLayout).commit;
    expect(commit.surfaceKey, 'screen:home');
    expect(commit.baseLayoutVersion, 4);
    expect(commit.isEmpty, isFalse);
  });

  test('resetToDefault returns to the default layout', () {
    final editor = home();
    editor.hide('test.own');
    editor.resetToDefault();
    expect(editor.contains('test.own'), isTrue);
    expect(editor.isDefaultScope, isTrue);
  });

  test('cancel leaves the saved layout untouched', () {
    final saved = SurfaceLayout(
      surfaceKey: 'screen:home',
      sections: <LayoutSection>[
        section(
          'today',
          <LayoutPlacement>[placed('test.own', WidgetSize.full)],
        ),
      ],
    );
    final editor = LayoutEditor(
      registry: registry,
      bundle: bundle,
      surfaceKey: 'screen:home',
      saved: saved,
    );
    editor.hide('test.own');
    expect(editor.contains('test.own'), isFalse);
    expect(saved.sections.first.placements.single.itemKey, 'test.own');
  });

  test('take rejects a Moves=No widget', () {
    final editor = home();
    expect(
      () => editor.take('test.own'),
      throwsA(isA<LayoutFormatError>()),
    );
  });

  test('take and insert move a widget across surfaces', () {
    final homeEditor = home();
    final taken = homeEditor.take('test.alpha');
    expect(taken, isNotNull);
    expect(taken!.itemKey, 'test.alpha');

    final spending = LayoutEditor(
      registry: registry,
      bundle: bundle,
      surfaceKey: 'screen:spending',
    );
    spending.insert('main', taken);
    expect(spending.contains('test.alpha'), isTrue);
    // Cross-surface: the key is new to the spending surface.
    final moved = spending.done();
    expect(moved, isA<SaveLayout>());
    expect(
      (moved as SaveLayout).commit.newInThisVersion,
      contains('test.alpha'),
    );
  });

  // N-04: a move between sections of one surface is not a new key.
  test('take and insert on one surface is not new', () {
    final editor = home();
    final taken = editor.take('test.alpha');
    expect(taken, isNotNull);
    editor.insert('today', taken!);
    expect(editor.contains('test.alpha'), isTrue);
    final result = editor.done();
    expect(result, isA<SaveLayout>());
    expect(
      (result as SaveLayout).commit.newInThisVersion,
      isNot(contains('test.alpha')),
    );
  });

  test('hasChanges reports any session change', () {
    final editor = home();
    expect(editor.hasChanges, isFalse);
    editor.hide('test.own');
    expect(editor.hasChanges, isTrue);
  });

  // N-03 (W-J): Default then Done returns the surface to inheritance.
  test('done at the default returns InheritDefault', () {
    expect(home().done(), isA<InheritDefault>());
  });

  // N-04: add then hide reports no new key (it leaves the default).
  test('add then hide returns to inheritance', () {
    final editor = LayoutEditor(
      registry: registry,
      bundle: bundle,
      surfaceKey: 'screen:spending',
    );
    editor.add('test.beta');
    editor.hide('test.beta');
    expect(editor.done(), isA<InheritDefault>());
  });

  // N-04: a widget added in an earlier release is not new again at Done.
  test('an earlier-release addition is not new', () {
    final saved = SurfaceLayout(
      surfaceKey: 'screen:home',
      sections: <LayoutSection>[
        section(
          'today',
          <LayoutPlacement>[placed('test.own', WidgetSize.full)],
        ),
        section(
          'more',
          <LayoutPlacement>[
            placed('test.alpha', WidgetSize.half),
            placed('test.gamma', WidgetSize.half),
            placed('test.beta', WidgetSize.full),
          ],
        ),
      ],
    );
    final editor = LayoutEditor(
      registry: registry,
      bundle: bundle,
      surfaceKey: 'screen:home',
      saved: saved,
    );
    editor.hide('test.gamma');
    final result = editor.done();
    expect(result, isA<SaveLayout>());
    expect(
      (result as SaveLayout).commit.newInThisVersion,
      isNot(contains('test.beta')),
    );
  });

  // N-13: hiding an absent key changes nothing and pushes no undo snapshot.
  test('hide of an absent key is a no-op', () {
    final editor = home();
    editor.hide('ghost');
    expect(editor.canUndo, isFalse);
    expect(editor.hasChanges, isFalse);
  });
}
