import 'package:contour/app/widgets/layout_model.dart';
import 'package:contour/app/widgets/registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

LayoutBundle withSurface(LayoutBundle base, String key, SurfaceLayout surface) {
  return LayoutBundle(
    layoutVersion: base.layoutVersion,
    catalogueVersion: base.catalogueVersion,
    surfaces: <String, SurfaceLayout>{...base.surfaces, key: surface},
    add: base.add,
    renames: base.renames,
  );
}

LayoutBundle withAdd(LayoutBundle base, AddBlock add) => LayoutBundle(
      layoutVersion: base.layoutVersion,
      catalogueVersion: base.catalogueVersion,
      surfaces: base.surfaces,
      add: add,
      renames: base.renames,
    );

LayoutBundle withRenames(LayoutBundle base, Map<String, String> renames) =>
    LayoutBundle(
      layoutVersion: base.layoutVersion,
      catalogueVersion: base.catalogueVersion,
      surfaces: base.surfaces,
      add: base.add,
      renames: renames,
    );

void main() {
  final registry = testRegistry();
  final base = testBundle();

  test('the test default file is valid', () {
    expect(() => registry.validate(base), returnsNormally);
  });

  test('rejects an unknown widget key', () {
    final bad = withSurface(
      base,
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[placed('nope', WidgetSize.full)]),
        ],
      ),
    );
    expect(
      () => registry.validate(bad),
      throwsA(isA<LayoutFormatError>()),
    );
  });

  test('rejects an unknown surface key', () {
    final bad = withSurface(
      base,
      'screen:bogus',
      const SurfaceLayout(
        surfaceKey: 'screen:bogus',
        sections: <LayoutSection>[],
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a missing surface', () {
    final surfaces = Map<String, SurfaceLayout>.of(base.surfaces)
      ..remove('screen:tax');
    final bad = LayoutBundle(
      layoutVersion: base.layoutVersion,
      catalogueVersion: base.catalogueVersion,
      surfaces: surfaces,
      add: base.add,
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a size the widget does not allow', () {
    final bad = withSurface(
      base,
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[placed('test.beta', WidgetSize.half)]),
        ],
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a duplicate widget key on one surface', () {
    final bad = withSurface(
      base,
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[
            placed('test.alpha', WidgetSize.half),
            placed('test.alpha', WidgetSize.full),
          ]),
        ],
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a tile on a screen surface', () {
    final bad = withSurface(
      base,
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section(
            's',
            <LayoutPlacement>[placed('test.tile.a', WidgetSize.full)],
          ),
        ],
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a Moves=No widget off its own surface', () {
    final bad = withSurface(
      base,
      'screen:spending',
      SurfaceLayout(
        surfaceKey: 'screen:spending',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[placed('test.own', WidgetSize.full)]),
        ],
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a reserved section-key case variant', () {
    final bad = withSurface(
      base,
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[section('Untitled', <LayoutPlacement>[])],
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('accepts the exact reserved untitled key', () {
    expect(() => registry.validate(base), returnsNormally);
    expect(base.surfaces['tiles:quickLook']!.sections.first.key, 'untitled');
  });

  test('rejects too many sections', () {
    final sections = <LayoutSection>[
      for (var i = 0; i <= maxSectionsPerSurface; i++)
        section('s$i', const <LayoutPlacement>[]),
    ];
    final bad = withSurface(
      base,
      'screen:home',
      SurfaceLayout(surfaceKey: 'screen:home', sections: sections),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects an add entry for an unknown key', () {
    final bad = withAdd(
      base,
      AddBlock(
        widgets: <String, AddWidgetEntry>{
          'ghost': const AddWidgetEntry(
            itemKey: 'ghost',
            addSize: WidgetSize.full,
            since: 1,
          ),
        },
        targets: base.add.targets,
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects an add size a widget does not allow', () {
    final bad = withAdd(
      base,
      AddBlock(
        widgets: <String, AddWidgetEntry>{
          'test.beta': const AddWidgetEntry(
            itemKey: 'test.beta',
            addSize: WidgetSize.half,
            since: 1,
          ),
        },
        targets: base.add.targets,
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a since value out of range', () {
    final bad = withAdd(
      base,
      AddBlock(
        widgets: <String, AddWidgetEntry>{
          'test.alpha': const AddWidgetEntry(
            itemKey: 'test.alpha',
            addSize: WidgetSize.half,
            since: 99,
          ),
        },
        targets: base.add.targets,
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a missing add target for a surface', () {
    final targets = Map<String, AddTarget>.of(base.add.targets)
      ..remove('screen:tax');
    final bad = withAdd(
      base,
      AddBlock(
        widgets: base.add.widgets,
        targets: targets,
      ),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects an add anchor that is not a catalogue key', () {
    final targets = Map<String, AddTarget>.of(base.add.targets)
      ..['screen:home'] = const AddTarget(
        targetSection: 'more',
        anchors: <String>['ghost'],
      );
    final bad = withAdd(
      base,
      AddBlock(widgets: base.add.widgets, targets: targets),
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a rename to an unknown key', () {
    final bad = withRenames(base, <String, String>{'old.a': 'ghost'});
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });

  test('rejects a cyclic rename', () {
    final bad = withRenames(
      base,
      <String, String>{'test.alpha': 'test.beta', 'test.beta': 'test.alpha'},
    );
    expect(() => registry.validate(bad), throwsA(isA<LayoutFormatError>()));
  });
}
