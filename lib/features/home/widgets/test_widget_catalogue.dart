import 'package:contour/app/widgets/layout_model.dart';
import 'package:contour/app/widgets/read_store.dart';
import 'package:contour/app/widgets/registry.dart';
import 'package:contour/design/design.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// Phase 1 test widgets (SPEC W8). They exercise the framework with the same
/// host; the approved X03 catalogue is open (WIDGET-X03-DEFAULT). They never
/// enter a release layout.
///
/// AGENTS 6.9: the preview cache-miss words come from l10n
/// (T06-L10N-CONSTANTS closed 2026-11-22).
// DECISION-PENDING: WIDGET-X03-DEFAULT

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
        metricKeys: const <MetricKey>[MetricKey('test.alpha')],
        builder: (context) =>
            _card(context, title: 'Test alpha', body: 'Alpha body'),
        previewBuilder: (context, resident) => _card(
          context,
          title: 'Test alpha',
          body: resident == null
              ? AppLocalizations.of(context).widgetNotLoadedYet
              : formatValueState(resident).text,
        ),
      ),
      WidgetDescriptor(
        key: 'test.beta',
        kind: WidgetKind.widget,
        nameKey: 'test.beta.name',
        allowedSizes: const <WidgetSize>{WidgetSize.full},
        specRule: 'W-A',
        metricKeys: const <MetricKey>[MetricKey('test.beta')],
        builder: (context) =>
            _card(context, title: 'Test beta', body: 'Beta body'),
        previewBuilder: (context, resident) => _card(
          context,
          title: 'Test beta',
          body: resident == null
              ? AppLocalizations.of(context).widgetNotLoadedYet
              : formatValueState(resident).text,
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
          body: resident == null
              ? AppLocalizations.of(context).widgetNotLoadedYet
              : formatValueState(resident).text,
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
          body: resident == null
              ? AppLocalizations.of(context).widgetNotLoadedYet
              : formatValueState(resident).text,
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
          body: resident == null
              ? AppLocalizations.of(context).widgetNotLoadedYet
              : formatValueState(resident).text,
        ),
      ),
    ];
