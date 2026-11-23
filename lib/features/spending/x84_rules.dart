// P28 (SCREEN X84; flow F09 step 1; SPEC 9.3): categories and rules.
//
// One control row switches Categories and Rules. A rule only proposes a
// category; the list shows its use count. "Add a rule" opens C03. Category
// editing (C03 for a category) stays out of this task (P28-CATEGORY-EDIT).
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'repeating_controller.dart';
import 'repeating_models.dart';

/// X84: the rules list with a Categories/Rules switch.
class X84Rules extends StatefulWidget {
  const X84Rules({
    required this.gateway,
    required this.onClose,
    required this.onAddRule,
    this.controller,
    super.key,
  });

  final RepeatingGateway gateway;
  final VoidCallback onClose;
  final VoidCallback onAddRule;
  final RulesController? controller;

  @override
  State<X84Rules> createState() => _X84RulesState();
}

class _X84RulesState extends State<X84Rules> {
  late final RulesController _controller =
      widget.controller ?? RulesController(gateway: widget.gateway);
  bool _showRules = true;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        return DetailScreen(
          header: ScreenHeader(
            title: l.rulesTitle,
            dateLine: l.rulesSubline,
            leading: AppIconButton(
              icon: AppIcons.back,
              semanticLabel: l.repeatingBack,
              onPressed: widget.onClose,
            ),
          ),
          children: <Widget>[
            Text(
              l.rulesKicker(_controller.rules.length).toUpperCase(),
              style: AppText.labelCaps.copyWith(
                color: tokens.role(context.section).text,
              ),
            ),
            Text(l.rulesStatement, style: AppText.titleSection),
            Text(
              l.rulesLine,
              style: AppText.caption.copyWith(color: tokens.textSecondary),
            ),
            ChipRow(
              items: <ChipItem>[
                ChipItem(
                  label: l.rulesShowCategories,
                  semanticLabel: l.rulesShowCategories,
                  variant: ChipVariant.choice,
                  selected: !_showRules,
                  onPressed: () => setState(() => _showRules = false),
                ),
                ChipItem(
                  label: l.rulesShowRules,
                  semanticLabel: l.rulesShowRules,
                  variant: ChipVariant.choice,
                  selected: _showRules,
                  onPressed: () => setState(() => _showRules = true),
                ),
              ],
            ),
            if (_controller.state == RepeatingState.failed)
              Text(l.spendingLoadFailed, style: AppText.bodyStrong)
            else if (_showRules)
              _rulesCard(l)
            else
              _categoriesCard(l),
          ],
        );
      },
    );
  }

  Widget _rulesCard(AppLocalizations l) {
    final rules = _controller.rules;
    return GlassCard(
      title: l.rulesCard,
      meta: l.rulesMeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (rules.isEmpty)
            Text(
              l.rulesEmpty,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            )
          else
            for (final rule in rules.take(6)) ...<Widget>[
              SelectRow(
                name: l.rulesWhen(rule.pattern),
                line: l.rulesCategory(rule.categoryName),
                trailing: Text(
                  l.rulesUsed(rule.hitCount),
                  style: AppText.caption.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                chevron: false,
              ),
              const VSpace(Space.xxs),
            ],
          if (rules.length > 6) ...<Widget>[
            const VSpace(Space.s),
            Text(
              l.rulesMore(rules.length - 6),
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
          const VSpace(Space.m),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppButton(
                label: l.rulesAdd,
                variant: AppButtonVariant.ghost,
                fullWidth: false,
                onPressed: widget.onAddRule,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoriesCard(AppLocalizations l) {
    final categories = _controller.categories;
    return GlassCard(
      title: l.rulesShowCategories,
      meta: '${categories.length}',
      child: Column(
        children: <Widget>[
          if (categories.isEmpty)
            Text(
              l.rulesCategoriesEmpty,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            )
          else
            for (final category in categories)
              SelectRow(
                name: category.name,
                chevron: false,
                semanticLabel: category.name,
              ),
        ],
      ),
    );
  }
}
