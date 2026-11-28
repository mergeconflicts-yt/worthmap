import 'dart:io';

import 'package:contour/app/hidden_amounts.dart';
import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required HiddenAmountsController controller}) {
  return HiddenAmountsHost(
    controller: controller,
    child: MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(
        section: Section.spending,
        child: SingleChildScrollView(child: child),
      ),
    ),
  );
}

Money _usd(int major) => Money.fromMinor(major * 100, Currency.usd);

void main() {
  group('P20 hidden state controller', () {
    test('starts visible and toggles with one notification', () async {
      final controller = HiddenAmountsController(
        store: MemoryHiddenAmountsStore(),
      );
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      expect(controller.hidden, isFalse);
      await controller.toggle();
      expect(controller.hidden, isTrue);
      expect(notifications, 1);
      await controller.setHidden(true);
      expect(notifications, 1);
      await controller.setHidden(false);
      expect(controller.hidden, isFalse);
      expect(notifications, 2);
    });

    test('the stored bit loads and persists through the port', () async {
      final store = MemoryHiddenAmountsStore(initial: true);
      final controller = HiddenAmountsController(store: store);
      await controller.load();
      expect(controller.hidden, isTrue);

      await controller.setHidden(false);
      expect(await store.read(), isFalse);
    });

    test('a missing bit keeps the initial state', () async {
      final controller = HiddenAmountsController(
        store: MemoryHiddenAmountsStore(),
        initial: true,
      );
      await controller.load();
      expect(controller.hidden, isTrue);
    });

    test('the file store survives a new instance and holds no amount',
        () async {
      final directory = await Directory.systemTemp.createTemp('contour-hide');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileHiddenAmountsStore(directory: directory.path);

      expect(await store.read(), isNull);
      await store.write(true);
      final reopened = FileHiddenAmountsStore(directory: directory.path);
      expect(await reopened.read(), isTrue);

      final text = await File(
        '${directory.path}/contour-hidden-amounts.preference',
      ).readAsString();
      expect(text.trim(), 'hidden=true');
    });
  });

  group('P20 hidden state drives the components', () {
    testWidgets('MoneyText masks text and speech without changing data',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = HiddenAmountsController();
      await tester.pumpWidget(
        _wrap(
          MoneyText(
            ValueSpec.real(_usd(3940)),
            style: AppText.numberM,
          ),
          controller: controller,
        ),
      );
      expect(find.text(r'$3,940.00'), findsOneWidget);

      await controller.toggle();
      await tester.pumpAndSettle();
      expect(find.text('\$$hiddenMask'), findsOneWidget);
      expect(find.text(r'$3,940.00'), findsNothing);
      expect(find.bySemanticsLabel(amountHiddenLabel), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the hero masks the number and keeps the context words',
        (tester) async {
      final controller = HiddenAmountsController();
      await tester.pumpWidget(
        _wrap(
          ObHero(
            kicker: 'SPENT',
            value: ValueSpec.real(_usd(3940)),
            contextLine: 'October: \$1,260 left',
            hiddenContextLine: 'October: \$$hiddenMask left',
          ),
          controller: controller,
        ),
      );
      expect(find.text('3,940'), findsOneWidget);

      await controller.toggle();
      await tester.pumpAndSettle();
      expect(find.text(hiddenMask), findsOneWidget);
      expect(find.text('October: \$$hiddenMask left'), findsOneWidget);
      expect(find.text('October: \$1,260 left'), findsNothing);
    });

    testWidgets('the hidden state persists across navigation', (tester) async {
      final controller = HiddenAmountsController();
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SectionScope(
                    section: Section.wealth,
                    child: MoneyText(
                      ValueSpec.real(_usd(182332)),
                      style: AppText.numberM,
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
          controller: controller,
        ),
      );
      await controller.toggle();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('\$$hiddenMask'), findsOneWidget);
      expect(find.text(r'$182,332.00'), findsNothing);
    });

    testWidgets('a chart keeps percentages and masks amounts', (tester) async {
      final controller = HiddenAmountsController();
      await tester.pumpWidget(
        _wrap(
          SplitBar(
            title: 'Needs and wants',
            period: 'October',
            columns: const <String>['Part', 'Amount', 'Share'],
            parts: <SplitBarPart>[
              SplitBarPart(
                name: 'Needs',
                amount: _usd(2890),
                mark: ChartMark.needs,
              ),
              SplitBarPart(
                name: 'Wants',
                amount: _usd(1050),
                mark: ChartMark.wants,
              ),
            ],
          ),
          controller: controller,
        ),
      );
      await controller.toggle();
      await tester.pumpAndSettle();

      expect(find.text('\$$hiddenMask'), findsNWidgets(2));
      expect(find.text('73.4%'), findsOneWidget);
      expect(find.text('26.6%'), findsOneWidget);
    });
  });

  group('P20 period hero', () {
    testWidgets('the period variant draws the background chart',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ObHero(
            kicker: 'SPENT',
            value: ValueSpec.real(_usd(3940)),
            variant: ObHeroVariant.period,
            contextLine: '1–13 Oct 2026',
            backgroundChart: const SizedBox(key: Key('chart')),
          ),
          controller: HiddenAmountsController(),
        ),
      );
      expect(find.byKey(const Key('chart')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ObHero),
          matching: find.byType(ShaderMask),
        ),
        findsWidgets,
      );
      expect(find.byType(ObHero), findsOneWidget);
    });

    testWidgets('the period variant masks its chart in the hidden state',
        (tester) async {
      final controller = HiddenAmountsController(initial: true);
      await tester.pumpWidget(
        _wrap(
          ObHero(
            kicker: 'SPENT',
            value: ValueSpec.real(_usd(3940)),
            variant: ObHeroVariant.period,
            backgroundChart: MoneyText(
              ValueSpec.real(_usd(303)),
              style: AppText.chartLabel,
            ),
          ),
          controller: controller,
        ),
      );
      expect(find.text('\$$hiddenMask'), findsWidgets);
      expect(find.text(r'$303.00'), findsNothing);
    });
  });
}
