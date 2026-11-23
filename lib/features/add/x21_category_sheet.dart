// P22 (SCREENS X21; flow F03 step 3; SPEC 8.16): the category sheet.
//
// The sheet reads a supplied list and returns one choice. It writes nothing:
// the choice lands in the X20 draft when the sheet closes. A category with no
// `data.category` role shows its name only; DESIGN 2.4 forbids an invented
// colour (DECISIONS P22-CATEGORY-DOT).
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'payment_category_style.dart';
import 'payment_models.dart';

/// X21: search, a 4-column grid of category tiles and "New category".
class X21CategorySheet extends StatefulWidget {
  const X21CategorySheet({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.onNewCategory,
    super.key,
  });

  final List<CategorySummary> categories;
  final String? selectedId;

  /// Null clears the category (an uncategorised payment is allowed, F03-A).
  final ValueChanged<CategorySummary?> onSelected;

  /// Opens C03 when the category editor is released (P28).
  final VoidCallback? onNewCategory;

  @override
  State<X21CategorySheet> createState() => _X21CategorySheetState();
}

class _X21CategorySheetState extends State<X21CategorySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final visible = <CategorySummary>[
      for (final category in widget.categories)
        if (_query.trim().isEmpty ||
            category.name.toLowerCase().contains(_query.trim().toLowerCase()))
          category,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppField(
          label: l.paymentCategorySearch,
          semanticLabel: l.paymentCategorySearch,
          onChanged: (value) => setState(() => _query = value),
        ),
        const VSpace(Space.l),
        if (widget.categories.isEmpty)
          Text(
            l.paymentCategoryEmpty,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          )
        else if (visible.isEmpty)
          Text(
            l.paymentCategoryNoMatch,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          )
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final columns = scale > 1.3 ? 2 : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * Space.s) / columns;
              return Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: <Widget>[
                  for (final category in visible)
                    SizedBox(
                      width: width,
                      child: _CategoryTile(
                        name: category.name,
                        selected: category.id == widget.selectedId,
                        onPressed: () => widget.onSelected(category),
                      ),
                    ),
                ],
              );
            },
          ),
        if (widget.onNewCategory != null) ...<Widget>[
          const VSpace(Space.l),
          AppButton(
            label: l.paymentCategoryNew,
            variant: AppButtonVariant.ghost,
            onPressed: widget.onNewCategory,
          ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.selected,
    required this.onPressed,
  });

  final String name;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SelectTile(
      label: name,
      semanticLabel: selected
          ? AppLocalizations.of(context).paymentCategorySelected(name)
          : name,
      selected: selected,
      dotColor: categoryDotTint(context, name),
      onPressed: onPressed,
    );
  }
}

/// Opens X21 and returns the choice. A null result means the sheet closed
/// without a choice; a chosen "none" is [CategorySummary] with an empty id.
Future<CategorySummary?> showCategorySheet(
  BuildContext context, {
  required List<CategorySummary> categories,
  required String? selectedId,
  VoidCallback? onNewCategory,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<CategorySummary>(
    context,
    title: l.paymentCategoryTitle,
    semanticLabel: l.paymentCategorySpoken,
    children: <Widget>[
      X21CategorySheet(
        categories: categories,
        selectedId: selectedId,
        onSelected: (category) => Navigator.of(context).pop(category),
        onNewCategory: onNewCategory,
      ),
    ],
  );
}
