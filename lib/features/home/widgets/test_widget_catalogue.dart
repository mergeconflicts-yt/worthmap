import 'package:contour/app/widgets/layout_model.dart';
import 'package:contour/app/widgets/registry.dart';
import 'package:contour/design/design.dart';
import 'package:flutter/widgets.dart';

/// Phase 1 test widgets (SPEC W8). They exercise the framework with the same
/// host; the approved X03 catalogue is open (WIDGET-X03-DEFAULT). They never
/// enter a release layout.
///
/// The words "Not loaded yet" and "None recorded" come from l10n in a later
/// task (T10). They are constants here so the framework tests are exact.
// DECISION-PENDING: WIDGET-X03-DEFAULT
const String testNotLoadedLabel = 'Not loaded yet';

Widget _card(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return GlassCard(
    title: title,
    child: Text(
      body,
      style: AppText.body.copyWith(color: context.tokens.textPrimary),
    ),
  );
}

/// The test catalogue: two movable widgets, one "Moves = No" widget and a tile.
List<WidgetDescriptor> testWidgetCatalogue() => <WidgetDescriptor>[
      WidgetDescriptor(
        key: 'test.alpha',
        kind: WidgetKind.widget,
        nameKey: 'test.alpha.name',
        allowedSizes: const <WidgetSize>{WidgetSize.full, WidgetSize.half},
        specRule: 'W-A',
        builder: (context) =>
            _card(context, title: 'Test alpha', body: 'Alpha body'),
        previewBuilder: (context, resident) => _card(
          context,
          title: 'Test alpha',
          body: resident?.toString() ?? testNotLoadedLabel,
        ),
      ),
      WidgetDescriptor(
        key: 'test.beta',
        kind: WidgetKind.widget,
        nameKey: 'test.beta.name',
        allowedSizes: const <WidgetSize>{WidgetSize.full},
        specRule: 'W-A',
        builder: (context) =>
            _card(context, title: 'Test beta', body: 'Beta body'),
        previewBuilder: (context, resident) => _card(
          context,
          title: 'Test beta',
          body: resident?.toString() ?? testNotLoadedLabel,
        ),
      ),
      WidgetDescriptor(
        key: 'test.own',
        kind: WidgetKind.widget,
        nameKey: 'test.own.name',
        ownSurface: 'screen:home',
        movable: false,
        allowedSizes: const <WidgetSize>{WidgetSize.full},
        specRule: 'W3.9',
        builder: (context) =>
            _card(context, title: 'Test own', body: 'Own controls'),
        previewBuilder: (context, resident) => _card(
          context,
          title: 'Test own',
          body: resident?.toString() ?? testNotLoadedLabel,
        ),
      ),
      WidgetDescriptor(
        key: 'test.gamma',
        kind: WidgetKind.widget,
        nameKey: 'test.gamma.name',
        allowedSizes: const <WidgetSize>{WidgetSize.half},
        specRule: 'W-A',
        builder: (context) =>
            _card(context, title: 'Test gamma', body: 'Gamma body'),
        previewBuilder: (context, resident) => _card(
          context,
          title: 'Test gamma',
          body: resident?.toString() ?? testNotLoadedLabel,
        ),
      ),
      WidgetDescriptor(
        key: 'test.tile.a',
        kind: WidgetKind.tile,
        nameKey: 'test.tile.a.name',
        tileParentKey: 'home.quickLook',
        allowedSizes: const <WidgetSize>{WidgetSize.full},
        specRule: 'W12',
        builder: (context) =>
            _card(context, title: 'Test tile', body: 'Tile value'),
        previewBuilder: (context, resident) => _card(
          context,
          title: 'Test tile',
          body: resident?.toString() ?? testNotLoadedLabel,
        ),
      ),
    ];
