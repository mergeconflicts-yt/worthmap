import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMoney', () {
    test('groups thousands and keeps two minor units', () {
      expect(
        formatMoney(Money.fromMinor(412365, Currency.usd)),
        r'$4,123.65',
      );
    });

    test('uses the currency minor units (JPY has none)', () {
      expect(
        formatMoney(Money.fromMinor(412365, Currency.jpy)),
        '\u00A5412,365',
      );
    });

    test('keeps the sign before the mark', () {
      expect(
        formatMoney(Money.fromMinor(-412365, Currency.usd)),
        r'-$4,123.65',
      );
    });

    test('falls back to the code when no mark is known', () {
      expect(formatMoney(Money.fromMinor(100, Currency.twd)), r'NT$1.00');
    });

    test('can omit the symbol', () {
      expect(
        formatMoney(Money.fromMinor(100, Currency.usd), showSymbol: false),
        '1.00',
      );
    });
  });

  group('MoneyText', () {
    testWidgets('shows the hidden mask with the currency mark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MoneyText(
            amount: Money.fromMinor(412365, Currency.usd),
            state: ValueState.real,
            hidden: true,
          ),
        ),
      );
      expect(find.text(r'$······'), findsOneWidget);
    });

    testWidgets('shows the amount when not hidden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MoneyText(
            amount: Money.fromMinor(412365, Currency.usd),
            state: ValueState.real,
          ),
        ),
      );
      expect(find.text(r'$4,123.65'), findsOneWidget);
    });

    testWidgets('shows the none-recorded label, never a zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyText(
            amount: null,
            state: ValueState.noneRecorded,
            noneRecordedLabel: 'None recorded',
          ),
        ),
      );
      expect(find.text('None recorded'), findsOneWidget);
    });
  });

  group('ObHero', () {
    testWidgets('masks the number when hidden', (tester) async {
      await tester.pumpWidget(
        goldenHelper(
          ObHero(
            kicker: 'Available · today',
            amount: Money.fromMinor(412365, Currency.usd),
            state: ValueState.real,
            hidden: true,
          ),
        ),
      );
      expect(find.text(r'$······'), findsOneWidget);
    });
  });
}

Widget goldenHelper(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: SectionScope(
        section: Section.home,
        child: Scaffold(body: child),
      ),
    );
