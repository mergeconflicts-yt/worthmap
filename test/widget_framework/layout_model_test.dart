import 'package:contour/app/widgets/layout_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WidgetSize', () {
    test('parses known ids', () {
      expect(WidgetSize.fromId('full'), WidgetSize.full);
      expect(WidgetSize.fromId('half'), WidgetSize.half);
    });

    test('rejects an unknown id', () {
      expect(
        () => WidgetSize.fromId('wide'),
        throwsA(isA<LayoutFormatError>()),
      );
    });
  });

  group('LayoutBundle.canonicalKey', () {
    test('follows a rename chain to its end', () {
      const bundle = LayoutBundle(
        layoutVersion: 3,
        catalogueVersion: 1,
        surfaces: <String, SurfaceLayout>{},
        add: AddBlock(
          widgets: <String, AddWidgetEntry>{},
          targets: <String, AddTarget>{},
        ),
        renames: <String, String>{'old.a': 'mid.b', 'mid.b': 'new.c'},
      );
      expect(bundle.canonicalKey('old.a'), 'new.c');
      expect(bundle.canonicalKey('mid.b'), 'new.c');
      expect(bundle.canonicalKey('new.c'), 'new.c');
      expect(bundle.canonicalKey('unseen'), 'unseen');
    });
  });

  group('LayoutPlacement', () {
    test('equality uses key and size', () {
      const a = LayoutPlacement(itemKey: 'x', size: WidgetSize.half);
      const b = LayoutPlacement(itemKey: 'x', size: WidgetSize.half);
      const c = LayoutPlacement(itemKey: 'x', size: WidgetSize.full);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.withSize(WidgetSize.full), c);
    });
  });

  group('SurfaceLayout', () {
    test('isExplicitEmpty is true for no sections', () {
      const surface = SurfaceLayout(surfaceKey: 'screen:home', sections: []);
      expect(surface.isExplicitEmpty, isTrue);
    });
  });
}
