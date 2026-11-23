// P28 (SCREEN C03; flow F09 step 1; SPEC 9.3): the rule editor.
//
// One match text and one category. Save writes one rule; it never
// reclassifies a past payment. A declined offer writes nothing (F09-D).
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'repeating_models.dart';

/// C03: match text, category choice and Save.
class C03RuleEditor extends StatefulWidget {
  const C03RuleEditor({
    required this.gateway,
    required this.onClose,
    required this.onSaved,
    this.categories,
    super.key,
  });

  final RepeatingGateway gateway;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  /// Test and golden seam: prepared options. Null loads them.
  final List<NamedOption>? categories;

  @override
  State<C03RuleEditor> createState() => _C03RuleEditorState();
}

class _C03RuleEditorState extends State<C03RuleEditor> {
  final TextEditingController _match = TextEditingController();
  List<NamedOption> _categories = const <NamedOption>[];
  String? _categoryId;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final prepared = widget.categories;
    if (prepared != null) {
      setState(() => _categories = prepared);
      return;
    }
    try {
      final options = await widget.gateway.categoryOptions();
      if (mounted) {
        setState(() => _categories = options);
      }
    } on Object {
      // Save stays disabled without a category.
    }
  }

  @override
  void dispose() {
    _match.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _match.text.trim().isNotEmpty && _categoryId != null;

  Future<void> _save() async {
    if (!_canSave) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.gateway.saveRule(
        RuleDraft(
          pattern: _match.text,
          categoryId: _categoryId!,
        ),
      );
      if (mounted) {
        widget.onSaved();
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FormScreen(
      close: AppIconButton(
        icon: AppIcons.close,
        semanticLabel: l.paymentsClose,
        onPressed: widget.onClose,
      ),
      primaryAction: AppButton(
        label: l.c03Save,
        onPressed: _canSave ? _save : _save,
      ),
      children: <Widget>[
        Text(l.c03Title, style: AppText.titleScreen),
        AppField(
          label: l.c03Match,
          semanticLabel: l.c03Match,
          hint: l.c03MatchHint,
          controller: _match,
          onChanged: (_) => setState(() {}),
        ),
        Text(l.c03Category, style: AppText.labelCaps),
        ChipRow(
          items: <ChipItem>[
            for (final category in _categories)
              ChipItem(
                label: category.name,
                semanticLabel: category.name,
                variant: ChipVariant.choice,
                selected: category.id == _categoryId,
                onPressed: () => setState(() => _categoryId = category.id),
              ),
          ],
        ),
        if (_failed)
          Text(
            l.c03Invalid,
            style: AppText.caption.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
      ],
    );
  }
}
