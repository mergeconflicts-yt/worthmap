import 'package:contour/design/design.dart';
import 'package:contour/features/add/payment_models.dart';
import 'package:contour/features/add/x21_category_sheet.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<CategorySummary> _categories = <CategorySummary>[
  CategorySummary(id: 'c1', name: 'Rent'),
  CategorySummary(id: 'c2', name: 'Groceries'),
  CategorySummary(id: 'c3', name: 'Dining'),
  CategorySummary(id: 'c4', name: 'Coffee'),
  CategorySummary(id: 'c5', name: 'Transport'),
];

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionScope(
        section: Section.spending,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.page),
            child: child,
          ),
        ),
      ),
    );

void main() {
  testWidgets('every category shows as a tile with its name', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X21CategorySheet(
          categories: _categories,
          selectedId: 'c3',
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final category in _categories) {
      expect(find.text(category.name), findsOneWidget);
    }
    expect(
      find.bySemanticsLabel('Dining, selected'),
      findsOneWidget,
      reason: 'the chosen tile names its state',
    );
    expect(find.text('New category'), findsNothing);
  });

  testWidgets('the search field filters the tiles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X21CategorySheet(
          categories: _categories,
          selectedId: null,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No category matches.'), findsOneWidget);
  });

  testWidgets('a tile reports the chosen category', (tester) async {
    CategorySummary? chosen;
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X21CategorySheet(
          categories: _categories,
          selectedId: null,
          onSelected: (value) => chosen = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(chosen!.id, 'c2');
  });

  testWidgets('no categories is a known empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        X21CategorySheet(
          categories: const <CategorySummary>[],
          selectedId: null,
          onSelected: (_) {},
          onNewCategory: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No categories yet.'), findsOneWidget);
    expect(find.text('New category'), findsOneWidget);
  });
}
