import 'package:contour/app/widgets/layout_model.dart';
import 'package:contour/app/widgets/registry.dart';
import 'package:contour/app/widgets/resolver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

LayoutBundle singleSurface(String key, SurfaceLayout surface) => LayoutBundle(
      layoutVersion: 1,
      catalogueVersion: 1,
      surfaces: <String, SurfaceLayout>{key: surface},
      add: const AddBlock(
        widgets: <String, AddWidgetEntry>{},
        targets: <String, AddTarget>{},
      ),
    );

void main() {
  final registry = testRegistry();
  final resolver = LayoutResolver(registry: registry, bundle: testBundle());

  test('resolves the default home surface', () {
    final resolved = resolver.resolve(
      surfaceKey: 'screen:home',
      editing: false,
      isReleased: (_) => true,
    );
    expect(resolved.sections, hasLength(2));
    expect(resolved.sections.first.key, 'today');
    expect(resolved.sections.first.titleKey, 'section.today');
    expect(resolved.sections.first.placements.single.itemKey, 'test.own');
    expect(resolved.sections.last.placements, hasLength(2));
  });

  test('skips an unknown stored key in normal mode', () {
    final bundle = singleSurface(
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[
            placed('gone', WidgetSize.full),
            placed('test.alpha', WidgetSize.half),
          ]),
        ],
      ),
    );
    final resolved = LayoutResolver(registry: registry, bundle: bundle)
        .resolve(surfaceKey: 'screen:home', editing: false);
    expect(resolved.sections.single.placements, hasLength(1));
    expect(resolved.sections.single.placements.single.itemKey, 'test.alpha');
  });

  test('shows an unknown stored key as a placeholder in edit mode', () {
    final bundle = singleSurface(
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[placed('gone', WidgetSize.full)]),
        ],
      ),
    );
    final resolved = LayoutResolver(registry: registry, bundle: bundle)
        .resolve(surfaceKey: 'screen:home', editing: true);
    final placement = resolved.sections.single.placements.single;
    expect(placement.unavailable, isTrue);
    expect(placement.descriptor, isNull);
  });

  test('hides a gated widget until its gate is on', () {
    final gatedRegistry = WidgetRegistry(<WidgetDescriptor>[
      WidgetDescriptor(
        key: 'g.x',
        kind: WidgetKind.widget,
        nameKey: 'g.x.name',
        allowedSizes: const <WidgetSize>{WidgetSize.full},
        featureGate: 'feature.x',
        builder: (_) => const SizedBox.shrink(),
        previewBuilder: (_, __) => const SizedBox.shrink(),
      ),
    ]);
    final bundle = singleSurface(
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[placed('g.x', WidgetSize.full)]),
        ],
      ),
    );
    final off = LayoutResolver(registry: gatedRegistry, bundle: bundle).resolve(
      surfaceKey: 'screen:home',
      editing: false,
      isReleased: (_) => false,
    );
    expect(off.sections, isEmpty);

    final on = LayoutResolver(registry: gatedRegistry, bundle: bundle).resolve(
      surfaceKey: 'screen:home',
      editing: false,
      isReleased: (_) => true,
    );
    expect(on.sections.single.placements.single.unavailable, isFalse);
  });

  test('keeps a gated widget as a placeholder in edit mode', () {
    final gatedRegistry = WidgetRegistry(<WidgetDescriptor>[
      WidgetDescriptor(
        key: 'g.x',
        kind: WidgetKind.widget,
        nameKey: 'g.x.name',
        allowedSizes: const <WidgetSize>{WidgetSize.full},
        featureGate: 'feature.x',
        builder: (_) => const SizedBox.shrink(),
        previewBuilder: (_, __) => const SizedBox.shrink(),
      ),
    ]);
    final bundle = singleSurface(
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[placed('g.x', WidgetSize.full)]),
        ],
      ),
    );
    final resolved =
        LayoutResolver(registry: gatedRegistry, bundle: bundle).resolve(
      surfaceKey: 'screen:home',
      editing: true,
      isReleased: (_) => false,
    );
    expect(resolved.sections.single.placements.single.unavailable, isTrue);
  });

  test('falls back to an allowed size (SPEC W3.11)', () {
    final bundle = singleSurface(
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('s', <LayoutPlacement>[placed('test.beta', WidgetSize.half)]),
        ],
      ),
    );
    final resolved = LayoutResolver(registry: registry, bundle: bundle)
        .resolve(surfaceKey: 'screen:home', editing: false);
    expect(resolved.sections.single.placements.single.size, WidgetSize.full);
  });

  test('drops an empty section in normal mode and keeps it in edit mode', () {
    final bundle = singleSurface(
      'screen:home',
      SurfaceLayout(
        surfaceKey: 'screen:home',
        sections: <LayoutSection>[
          section('empty', const <LayoutPlacement>[], title: 'section.empty'),
        ],
      ),
    );
    final normal = LayoutResolver(registry: registry, bundle: bundle)
        .resolve(surfaceKey: 'screen:home', editing: false);
    expect(normal.sections, isEmpty);

    final editing = LayoutResolver(registry: registry, bundle: bundle)
        .resolve(surfaceKey: 'screen:home', editing: true);
    expect(editing.sections, hasLength(1));
    expect(editing.sections.single.placements, isEmpty);
  });

  test('an explicit-empty saved surface shows no default (DB4-4)', () {
    const saved = SurfaceLayout(surfaceKey: 'screen:home', sections: []);
    final resolved = resolver.resolve(
      surfaceKey: 'screen:home',
      saved: saved,
      editing: false,
    );
    expect(resolved.isExplicitEmpty, isTrue);
    expect(resolved.sections, isEmpty);
  });

  test('applies the rename map to a stored key', () {
    final bundle = LayoutBundle(
      layoutVersion: 1,
      catalogueVersion: 1,
      surfaces: <String, SurfaceLayout>{
        'screen:home': SurfaceLayout(
          surfaceKey: 'screen:home',
          sections: <LayoutSection>[
            section(
              's',
              <LayoutPlacement>[placed('test.old', WidgetSize.full)],
            ),
          ],
        ),
      },
      add: const AddBlock(
        widgets: <String, AddWidgetEntry>{},
        targets: <String, AddTarget>{},
      ),
      renames: const <String, String>{'test.old': 'test.alpha'},
    );
    final resolved = LayoutResolver(registry: registry, bundle: bundle)
        .resolve(surfaceKey: 'screen:home', editing: false);
    final placement = resolved.sections.single.placements.single;
    expect(placement.canonicalKey, 'test.alpha');
    expect(placement.descriptor, isNotNull);
  });
}
