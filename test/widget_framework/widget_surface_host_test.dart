import 'package:contour/app/widgets/layout_model.dart';
import 'package:contour/app/widgets/read_store.dart';
import 'package:contour/app/widgets/resolver.dart';
import 'package:contour/app/widgets/widget_surface_host.dart';
import 'package:contour/design/design.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/design/golden_harness.dart';
import 'support.dart';

Widget wrap(Widget child) => goldenApp(
      theme: AppTheme.dark(),
      section: Section.home,
      textScale: 1,
      child: SingleChildScrollView(child: child),
    );

void main() {
  final registry = testRegistry();
  final resolver = LayoutResolver(registry: registry, bundle: testBundle());

  testWidgets('renders section titles and widgets', (tester) async {
    final surface = resolver.resolve(
      surfaceKey: 'screen:home',
      editing: false,
      isReleased: (_) => true,
    );
    await tester.pumpWidget(
      wrap(
        WidgetSurfaceHost(
          surface: surface,
          titleFor: (key) => key,
          unavailableLabel: 'Unavailable',
        ),
      ),
    );
    expect(find.text('section.today'), findsOneWidget);
    expect(find.text('section.more'), findsOneWidget);
    expect(find.text('Test own'), findsOneWidget);
    expect(find.text('Test alpha'), findsOneWidget);
    expect(find.text('Test gamma'), findsOneWidget);
  });

  testWidgets('pairs two half-size placements in one row', (tester) async {
    final surface = resolver.resolve(
      surfaceKey: 'screen:home',
      editing: false,
      isReleased: (_) => true,
    );
    await tester.pumpWidget(
      wrap(
        WidgetSurfaceHost(
          surface: surface,
          titleFor: (key) => key,
          unavailableLabel: 'Unavailable',
        ),
      ),
    );
    final rows = find.ancestor(
      of: find.text('Test alpha'),
      matching: find.byType(Row),
    );
    final paired = rows.evaluate().any(
          (element) => find
              .descendant(
                of: find.byElementPredicate((e) => e == element),
                matching: find.text('Test gamma'),
              )
              .evaluate()
              .isNotEmpty,
        );
    expect(paired, isTrue);
  });

  testWidgets('shows the empty state for an explicit-empty surface',
      (tester) async {
    const surface = ResolvedSurface(
      surfaceKey: 'screen:home',
      sections: <ResolvedSection>[],
      isExplicitEmpty: true,
    );
    await tester.pumpWidget(
      wrap(
        WidgetSurfaceHost(
          surface: surface,
          titleFor: (key) => key,
          unavailableLabel: 'Unavailable',
          emptyState: const Text('EMPTY'),
        ),
      ),
    );
    expect(find.text('EMPTY'), findsOneWidget);
  });

  testWidgets('edit mode wraps placements in a WidgetSlot', (tester) async {
    final surface = resolver.resolve(
      surfaceKey: 'screen:home',
      editing: true,
      isReleased: (_) => true,
    );
    await tester.pumpWidget(
      wrap(
        WidgetSurfaceHost(
          surface: surface,
          titleFor: (key) => key,
          unavailableLabel: 'Unavailable',
          editing: true,
          toolRowBuilder: (context, placement) =>
              Text('TOOL ${placement.itemKey}'),
        ),
      ),
    );
    expect(find.byType(WidgetSlot), findsNWidgets(3));
    expect(find.textContaining('TOOL '), findsNWidgets(3));
  });

  testWidgets('shows the unavailable label for an unknown key', (tester) async {
    const surface = ResolvedSurface(
      surfaceKey: 'screen:home',
      isExplicitEmpty: false,
      sections: <ResolvedSection>[
        ResolvedSection(
          key: 's',
          titleKey: null,
          placements: <ResolvedPlacement>[
            ResolvedPlacement(
              itemKey: 'gone',
              canonicalKey: 'gone',
              size: WidgetSize.full,
              descriptor: null,
              unavailable: true,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      wrap(
        WidgetSurfaceHost(
          surface: surface,
          titleFor: (key) => key,
          editing: true,
          unavailableLabel: 'GONE',
        ),
      ),
    );
    expect(find.text('GONE'), findsOneWidget);
  });

  // N-02: a shown placement holds a lease; hiding it releases the lease.
  testWidgets('placements acquire metric leases and release them on hide',
      (tester) async {
    final store = InMemoryReadStore();
    const alpha = MetricKey('test.alpha');
    final surface = resolver.resolve(
      surfaceKey: 'screen:home',
      editing: false,
      isReleased: (_) => true,
    );
    await tester.pumpWidget(
      wrap(
        WidgetSurfaceHost(
          surface: surface,
          titleFor: (key) => key,
          unavailableLabel: 'Unavailable',
          store: store,
        ),
      ),
    );
    expect(store.subscriberCount(alpha), 1);

    const emptied = ResolvedSurface(
      surfaceKey: 'screen:home',
      isExplicitEmpty: false,
      sections: <ResolvedSection>[
        ResolvedSection(
          key: 'more',
          titleKey: 'section.more',
          placements: <ResolvedPlacement>[
            ResolvedPlacement(
              itemKey: 'test.gamma',
              canonicalKey: 'test.gamma',
              size: WidgetSize.half,
              descriptor: null,
              unavailable: true,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      wrap(
        WidgetSurfaceHost(
          surface: emptied,
          titleFor: (key) => key,
          unavailableLabel: 'Unavailable',
          store: store,
        ),
      ),
    );
    expect(store.subscriberCount(alpha), 0);
  });
}
