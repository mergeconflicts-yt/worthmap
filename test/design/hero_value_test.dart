import 'package:contour/core/money.dart';
import 'package:contour/design/design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final amount = Money.fromMinor(412365, Currency.usd);

  group('formatHeroValue', () {
    test('splits the currency mark, whole units and cents', () {
      final hero = formatHeroValue(ValueSpec.real(amount));
      expect(hero.parts.isAmount, isTrue);
      expect(hero.parts.signMark, r'$');
      expect(hero.parts.whole, '4,123');
      expect(hero.parts.fraction, '.65');
      expect(hero.parts.marker, '');
      expect(hero.semanticsLabel, r'$4,123.65');
    });

    test('keeps the true minus sign with the currency mark', () {
      final hero = formatHeroValue(
        ValueSpec.real(Money.fromMinor(-412365, Currency.usd)),
      );
      expect(hero.parts.signMark, '\u2212\$');
      expect(hero.parts.whole, '4,123');
    });

    test('a currency with no minor units has no fraction part', () {
      final hero = formatHeroValue(
        ValueSpec.real(Money.fromMinor(412365, Currency.jpy)),
      );
      expect(hero.parts.signMark, '\u00A5');
      expect(hero.parts.whole, '412,365');
      expect(hero.parts.fraction, '');
    });

    test('zero cents leave no fraction part (SPEC Appendix B)', () {
      final hero = formatHeroValue(
        ValueSpec.real(Money.fromMinor(18790000, Currency.usd)),
      );
      expect(hero.parts.whole, '187,900');
      expect(hero.parts.fraction, '');
      expect(hero.semanticsLabel, r'$187,900');
    });

    test('a hidden amount keeps the mark and the mask only', () {
      final hero = formatHeroValue(ValueSpec.real(amount), hidden: true);
      expect(hero.parts.signMark, r'$');
      expect(hero.parts.whole, hiddenMask);
      expect(hero.parts.fraction, '');
      expect(hero.semanticsLabel, 'Amount hidden');
      expect(hero.semanticsLabel, isNot(contains('4,123')));
    });

    test('the state word is its own part', () {
      final hero = formatHeroValue(ValueSpec.estimated(amount, 'Est.'));
      expect(hero.parts.marker, 'Est.');
      expect(hero.parts.whole, '4,123');
      expect(hero.semanticsLabel, r'$4,123.65 Est.');
    });

    test('a hidden estimated value keeps the marker as its own part', () {
      final hero =
          formatHeroValue(ValueSpec.estimated(amount, 'Est.'), hidden: true);
      expect(hero.parts.signMark, r'$');
      expect(hero.parts.whole, hiddenMask);
      expect(hero.parts.fraction, '');
      expect(hero.parts.marker, 'Est.');
      expect(hero.semanticsLabel, 'Amount hidden Est.');
    });

    test('a none-recorded value has no amount parts', () {
      final hero = formatHeroValue(
        const ValueSpec.noneRecorded('None recorded'),
      );
      expect(hero.parts.isAmount, isFalse);
      expect(hero.parts.plain, 'None recorded');
      expect(hero.semanticsLabel, 'None recorded');
    });

    test('a currency code stands in when there is no mark', () {
      final hero = formatHeroValue(
        ValueSpec.real(Money.fromMinor(100, Currency('XAU', minorUnits: 2))),
      );
      expect(hero.parts.signMark, 'XAU');
    });
  });
}
