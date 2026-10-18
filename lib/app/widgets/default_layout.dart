import 'layout_model.dart';

/// Phase 1 default layout bundle (SPEC W8, W13). This is the test default file:
/// the approved X03 catalogue is open (WIDGET-X03-DEFAULT), so it references the
/// test widgets only. A release bundle is a compiled constant with the same
/// shape. The file holds keys only, never amounts, text or personal data.
// DECISION-PENDING: WIDGET-X03-DEFAULT
LayoutBundle testDefaultLayout({int layoutVersion = 1}) {
  LayoutSection section(
    String key, {
    String? title,
    List<LayoutPlacement> placements = const <LayoutPlacement>[],
  }) =>
      LayoutSection(key: key, titleKey: title, placements: placements);

  final home = SurfaceLayout(
    surfaceKey: 'screen:home',
    sections: <LayoutSection>[
      section(
        'today',
        title: 'section.today',
        placements: const <LayoutPlacement>[
          LayoutPlacement(itemKey: 'test.own', size: WidgetSize.full),
        ],
      ),
      section(
        'more',
        title: 'section.more',
        placements: const <LayoutPlacement>[
          LayoutPlacement(itemKey: 'test.alpha', size: WidgetSize.half),
          LayoutPlacement(itemKey: 'test.gamma', size: WidgetSize.half),
        ],
      ),
    ],
  );

  SurfaceLayout plain(String surfaceKey) => SurfaceLayout(
        surfaceKey: surfaceKey,
        sections: <LayoutSection>[section('main')],
      );

  final tiles = SurfaceLayout(
    surfaceKey: 'tiles:quickLook',
    sections: <LayoutSection>[
      section(
        'untitled',
        placements: const <LayoutPlacement>[
          LayoutPlacement(itemKey: 'test.tile.a', size: WidgetSize.full),
        ],
      ),
    ],
  );

  final surfaces = <String, SurfaceLayout>{
    'screen:home': home,
    'screen:spending': plain('screen:spending'),
    'screen:moneyIn': plain('screen:moneyIn'),
    'screen:wealth': plain('screen:wealth'),
    'screen:investments': plain('screen:investments'),
    'screen:calendar': plain('screen:calendar'),
    'screen:goals': plain('screen:goals'),
    'screen:protect': plain('screen:protect'),
    'screen:tax': plain('screen:tax'),
    'tiles:quickLook': tiles,
  };

  final targets = <String, AddTarget>{
    'screen:home':
        const AddTarget(targetSection: 'more', anchors: <String>['test.own']),
    'screen:spending': const AddTarget(targetSection: 'main'),
    'screen:moneyIn': const AddTarget(targetSection: 'main'),
    'screen:wealth': const AddTarget(targetSection: 'main'),
    'screen:investments': const AddTarget(targetSection: 'main'),
    'screen:calendar': const AddTarget(targetSection: 'main'),
    'screen:goals': const AddTarget(targetSection: 'main'),
    'screen:protect': const AddTarget(targetSection: 'main'),
    'screen:tax': const AddTarget(targetSection: 'main'),
    'tiles:quickLook': const AddTarget(targetSection: 'untitled'),
  };

  return LayoutBundle(
    layoutVersion: layoutVersion,
    catalogueVersion: 1,
    surfaces: surfaces,
    add: AddBlock(
      widgets: <String, AddWidgetEntry>{
        'test.alpha': const AddWidgetEntry(
          itemKey: 'test.alpha',
          addSize: WidgetSize.half,
          since: 1,
        ),
        'test.beta': const AddWidgetEntry(
          itemKey: 'test.beta',
          addSize: WidgetSize.full,
          since: 1,
        ),
        'test.own': const AddWidgetEntry(
          itemKey: 'test.own',
          addSize: WidgetSize.full,
          since: 1,
        ),
        'test.tile.a': const AddWidgetEntry(
          itemKey: 'test.tile.a',
          addSize: WidgetSize.full,
          since: 1,
        ),
      },
      targets: targets,
    ),
  );
}
