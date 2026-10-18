import 'package:contour/app/widgets/default_layout.dart';
import 'package:contour/app/widgets/layout_model.dart';
import 'package:contour/app/widgets/registry.dart';
import 'package:contour/features/home/widgets/test_widget_catalogue.dart';

/// The Phase 1 test registry and validated default bundle.
WidgetRegistry testRegistry() => WidgetRegistry(testWidgetCatalogue());

LayoutBundle testBundle({int layoutVersion = 1}) =>
    testDefaultLayout(layoutVersion: layoutVersion);

/// Convenience: a section from a list of `key:size` pairs.
LayoutSection section(
  String key,
  List<LayoutPlacement> placements, {
  String? title,
}) =>
    LayoutSection(key: key, titleKey: title, placements: placements);

LayoutPlacement placed(String key, WidgetSize size) =>
    LayoutPlacement(itemKey: key, size: size);
