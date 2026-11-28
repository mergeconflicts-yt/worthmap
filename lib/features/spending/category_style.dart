// P26 (SCREEN X30; SPEC 4.4): the glyph and chart mark of one spending
// category.
//
// Categories are the user's own records, so this is a best-effort visual map:
// a known keyword picks the matching Lucide glyph and categorical colour; any
// other name takes the next colour in the cycle so two rings never look the
// same by accident. The name and position still identify the category; colour
// is never the only signal (DESIGN 2.4).
library;

import '../../design/design.dart';

/// One category's glyph and data colour.
final class CategoryStyle {
  const CategoryStyle({required this.mark, required this.icon});

  final ChartMark mark;
  final AppIconData icon;
}

/// The style for [name], with [index] as the stable fallback position.
CategoryStyle categoryStyleFor({
  required String name,
  required int index,
}) {
  final key = name.toLowerCase();

  if (_has(key, <String>['rent', 'mortgage', 'housing', 'home'])) {
    return const CategoryStyle(mark: ChartMark.rent, icon: AppIcons.house);
  }
  if (_has(key, <String>['grocer', 'supermarket'])) {
    return const CategoryStyle(
      mark: ChartMark.groceries,
      icon: AppIcons.basket,
    );
  }
  if (_has(key, <String>['dining', 'restaurant', 'cafe', 'coffee', 'food'])) {
    return const CategoryStyle(
      mark: ChartMark.dining,
      icon: AppIcons.utensils,
    );
  }
  if (_has(key, <String>['shop', 'cloth', 'fashion', 'retail'])) {
    return const CategoryStyle(mark: ChartMark.shopping, icon: AppIcons.bag);
  }
  if (_has(key, <String>[
    'transport',
    'car',
    'fuel',
    'petrol',
    'taxi',
    'bus',
    'train',
    'travel',
    'flight',
  ])) {
    return const CategoryStyle(
      mark: ChartMark.transport,
      icon: AppIcons.car,
    );
  }
  if (_has(key, <String>[
    'utilit',
    'electric',
    'gas',
    'water',
    'energy',
    'bill',
  ])) {
    return const CategoryStyle(mark: ChartMark.utilities, icon: AppIcons.zap);
  }
  if (_has(key, <String>[
    'subscri',
    'stream',
    'phone',
    'mobile',
    'internet',
    'netflix',
    'spotify',
  ])) {
    return const CategoryStyle(
      mark: ChartMark.subscriptions,
      icon: AppIcons.repeat,
    );
  }
  if (_has(key, <String>[
    'fun',
    'entertain',
    'leisure',
    'game',
    'hobby',
    'sport',
  ])) {
    return const CategoryStyle(mark: ChartMark.fun, icon: AppIcons.ticket);
  }
  if (_has(
    key,
    <String>['health', 'medical', 'doctor', 'dentist', 'pharmac'],
  )) {
    return const CategoryStyle(mark: ChartMark.other, icon: AppIcons.shield);
  }
  if (_has(key, <String>['insur', 'protect'])) {
    return const CategoryStyle(mark: ChartMark.other, icon: AppIcons.shield);
  }
  if (_has(key, <String>['invest', 'saving', 'pension'])) {
    return const CategoryStyle(mark: ChartMark.other, icon: AppIcons.chart);
  }
  if (_has(key, <String>['fee', 'charge', 'interest', 'tax', 'bank'])) {
    return const CategoryStyle(mark: ChartMark.other, icon: AppIcons.bank);
  }
  if (_has(key, <String>['gift', 'donat'])) {
    return const CategoryStyle(mark: ChartMark.other, icon: AppIcons.receipt);
  }
  if (_has(key, <String>['other', 'uncategor'])) {
    return const CategoryStyle(mark: ChartMark.other, icon: AppIcons.more);
  }

  return CategoryStyle(
    mark: _cycle[index % _cycle.length],
    icon: AppIcons.more,
  );
}

bool _has(String text, List<String> parts) =>
    parts.any((part) => text.contains(part));

/// The categorical order for names this map does not know.
const List<ChartMark> _cycle = <ChartMark>[
  ChartMark.rent,
  ChartMark.groceries,
  ChartMark.dining,
  ChartMark.shopping,
  ChartMark.transport,
  ChartMark.utilities,
  ChartMark.subscriptions,
  ChartMark.fun,
  ChartMark.other,
];
