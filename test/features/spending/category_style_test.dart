import 'package:contour/design/design.dart';
import 'package:contour/features/spending/category_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known category names take their glyph and colour', () {
    expect(categoryStyleFor(name: 'Rent', index: 0).icon, AppIcons.house);
    expect(categoryStyleFor(name: 'Rent', index: 0).mark, ChartMark.rent);
    expect(
      categoryStyleFor(name: 'Groceries', index: 1).icon,
      AppIcons.basket,
    );
    expect(
      categoryStyleFor(name: 'Dining out', index: 2).icon,
      AppIcons.utensils,
    );
    expect(categoryStyleFor(name: 'Shopping', index: 3).icon, AppIcons.bag);
    expect(categoryStyleFor(name: 'Transport', index: 4).icon, AppIcons.car);
    expect(categoryStyleFor(name: 'Utilities', index: 5).icon, AppIcons.zap);
    expect(
      categoryStyleFor(name: 'Subscriptions', index: 6).icon,
      AppIcons.repeat,
    );
    expect(categoryStyleFor(name: 'Fun', index: 7).icon, AppIcons.ticket);
    expect(categoryStyleFor(name: 'Other', index: 8).mark, ChartMark.other);
  });

  test('an unknown name takes the next categorical colour and the more glyph',
      () {
    final first = categoryStyleFor(name: 'Pottery', index: 0);
    final second = categoryStyleFor(name: 'Pottery', index: 1);
    expect(first.icon, AppIcons.more);
    expect(second.icon, AppIcons.more);
    expect(first.mark, isNot(second.mark));
  });
}
