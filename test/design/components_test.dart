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

    test('keeps the true minus sign before the mark', () {
      expect(
        formatMoney(Money.fromMinor(-412365, Currency.usd)),
        '\u2212\$4,123.65',
      );
    });

    test('sign none hides the sign', () {
      expect(
        formatMoney(
          Money.fromMinor(-412365, Currency.usd),
          sign: SignStyle.none,
        ),
        r'$4,123.65',
      );
    });

    test('sign negativeOnly keeps a negative sign only', () {
      expect(
        formatMoney(
          Money.fromMinor(412365, Currency.usd),
          sign: SignStyle.negativeOnly,
        ),
        r'$4,123.65',
      );
    });

    test('sign always adds a plus to a gain', () {
      expect(
        formatMoney(
          Money.fromMinor(24680, Currency.usd),
          sign: SignStyle.always,
        ),
        '+\$246.80',
      );
      expect(
        formatMoney(
          Money.fromMinor(-24680, Currency.usd),
          sign: SignStyle.always,
        ),
        '\u2212\$246.80',
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

    test('formats the accepted USD minimum exactly', () {
      expect(
        formatMoney(Money.fromMinor(Money.minMinor.toInt(), Currency.usd)),
        '\u2212\$92,233,720,368,547,758.08',
      );
    });
  });

  group('formatValueState', () {
    final amount = Money.fromMinor(412365, Currency.usd);

    test('real shows the amount with no marker', () {
      final p = formatValueState(ValueSpec.real(amount));
      expect(p.text, r'$4,123.65');
      expect(p.semanticsLabel, r'$4,123.65');
    });

    test('estimated shows the Est. marker in pixels and semantics', () {
      final p = formatValueState(ValueSpec.estimated(amount, 'Est.'));
      expect(p.text, r'$4,123.65 Est.');
      expect(p.semanticsLabel, r'$4,123.65 Est.');
    });

    test('expected shows the Expected marker in pixels and semantics', () {
      final p = formatValueState(ValueSpec.expected(amount, 'Expected'));
      expect(p.text, r'$4,123.65 Expected');
      expect(p.semanticsLabel, r'$4,123.65 Expected');
    });

    test('old price shows the Est. marker', () {
      final p = formatValueState(ValueSpec.oldPrice(amount, 'Est.'));
      expect(p.text, r'$4,123.65 Est.');
    });

    test('none recorded shows its label, never a zero', () {
      final p = formatValueState(const ValueSpec.noneRecorded('None recorded'));
      expect(p.text, 'None recorded');
      expect(p.semanticsLabel, 'None recorded');
    });

    test('missing shows its phrase, never a zero', () {
      final p =
          formatValueState(const ValueSpec.missing('Missing since 22 Oct'));
      expect(p.text, 'Missing since 22 Oct');
    });

    test('a none-recorded value with an empty label is rejected', () {
      expect(
        () => formatValueState(const ValueSpec.noneRecorded('')),
        throwsArgumentError,
      );
    });

    test('hidden estimated keeps the marker but masks the amount', () {
      final p = formatValueState(
        ValueSpec.estimated(amount, 'Est.'),
        hidden: true,
      );
      expect(p.text, r'$······ Est.');
      expect(p.semanticsLabel, 'Amount hidden Est.');
      expect(p.semanticsLabel, isNot(contains('4,123')));
    });

    // N-05: Not available and Loading present their labels.
    test('not available shows its reason label', () {
      final p = formatValueState(
        const ValueSpec.notAvailable('Not available in this release'),
      );
      expect(p.text, 'Not available in this release');
      expect(p.semanticsLabel, 'Not available in this release');
    });

    test('loading shows its interim label', () {
      final p = formatValueState(const ValueSpec.loading('Loading'));
      expect(p.text, 'Loading');
      expect(p.semanticsLabel, 'Loading');
    });

    // N-14: every state label must be non-empty.
    test('an empty marker on an amount state is rejected', () {
      expect(
        () => formatValueState(ValueSpec.estimated(amount, '')),
        throwsArgumentError,
      );
      expect(
        () => formatValueState(ValueSpec.expected(amount, '')),
        throwsArgumentError,
      );
    });
  });

  group('MoneyText', () {
    testWidgets('shows the hidden mask with the currency mark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MoneyText(
            ValueSpec.real(Money.fromMinor(412365, Currency.usd)),
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
            ValueSpec.real(Money.fromMinor(412365, Currency.usd)),
          ),
        ),
      );
      expect(find.text(r'$4,123.65'), findsOneWidget);
    });

    testWidgets('shows the none-recorded label, never a zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyText(ValueSpec.noneRecorded('None recorded')),
        ),
      );
      expect(find.text('None recorded'), findsOneWidget);
    });

    testWidgets('missing never shows the none-recorded label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyText(ValueSpec.missing('Missing since 22 Oct')),
        ),
      );
      expect(find.text('Missing since 22 Oct'), findsOneWidget);
      expect(find.text('None recorded'), findsNothing);
    });

    testWidgets('masks the accessible name in hidden mode', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: MoneyText(
            ValueSpec.real(Money.fromMinor(412365, Currency.usd)),
            hidden: true,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Amount hidden'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ObHero', () {
    testWidgets('masks the number when hidden', (tester) async {
      await tester.pumpWidget(
        goldenHelper(
          ObHero(
            kicker: 'Available · today',
            value: ValueSpec.real(Money.fromMinor(412365, Currency.usd)),
            hidden: true,
          ),
        ),
      );
      expect(find.text(r'$······'), findsOneWidget);
    });

    testWidgets('shows the Estimated marker', (tester) async {
      await tester.pumpWidget(
        goldenHelper(
          ObHero(
            kicker: 'Available · today',
            value: ValueSpec.estimated(
              Money.fromMinor(412365, Currency.usd),
              'Est.',
            ),
          ),
        ),
      );
      expect(find.text(r'$4,123.65 Est.'), findsOneWidget);
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
