import 'package:contour/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
        theme: AppTheme.dark(),
        home: SectionScope(
          section: Section.home,
          child: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('Enter activates once and ignores the key repeat',
      (tester) async {
    var count = 0;
    await tester
        .pumpWidget(app(AppButton(label: 'Go', onPressed: () => count++)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

    expect(count, 1);
  });

  testWidgets('Space activates once and ignores the key repeat',
      (tester) async {
    var count = 0;
    await tester
        .pumpWidget(app(AppButton(label: 'Go', onPressed: () => count++)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);

    expect(count, 1);
  });

  testWidgets('a disabled control cannot activate', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      app(const AppButton(label: 'Disabled', onPressed: null)),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

    expect(count, 0);
  });

  testWidgets('Tab reaches enabled controls in order', (tester) async {
    final reached = <String>[];
    await tester.pumpWidget(
      app(
        Column(
          children: <Widget>[
            AppButton(label: 'First', onPressed: () => reached.add('first')),
            AppButton(label: 'Second', onPressed: () => reached.add('second')),
          ],
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(reached, <String>['first', 'second']);
  });

  testWidgets('a focused control shows the focus ring', (tester) async {
    await tester.pumpWidget(app(AppButton(label: 'Go', onPressed: () {})));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final rings = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((DecoratedBox box) {
      final decoration = box.decoration;
      if (decoration is! BoxDecoration) {
        return false;
      }
      final border = decoration.border;
      return border is Border && border.top.width == BorderTokens.focusRing;
    });
    expect(rings, isNotEmpty);
  });
}
