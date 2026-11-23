// P3-25 (SCREEN X66; flow F06 step 3; SPEC 8.6): Teach once.
//
// The person taps the date cell and the amount cell of one row. The app stores
// the layout fingerprint and the column bands. It stores no row values and no
// file content. The next statement with the same layout imports without a
// question.
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'import_controller.dart';

/// X66: teach one statement layout.
class X66TeachOnce extends StatefulWidget {
  const X66TeachOnce({
    required this.controller,
    required this.onClose,
    super.key,
  });

  final ImportController controller;
  final VoidCallback onClose;

  @override
  State<X66TeachOnce> createState() => _X66TeachOnceState();
}

class _X66TeachOnceState extends State<X66TeachOnce> {
  int? _dateCell;
  int? _amountCell;
  bool _saving = false;

  void _tap(int index) {
    setState(() {
      if (_dateCell == null) {
        _dateCell = index;
      } else if (index == _dateCell) {
        _dateCell = null;
        _amountCell = null;
      } else if (_amountCell == null) {
        _amountCell = index;
      } else if (index == _amountCell) {
        _amountCell = null;
      } else {
        _amountCell = index;
      }
    });
  }

  Future<void> _save() async {
    final date = _dateCell;
    final amount = _amountCell;
    if (date == null || amount == null || _saving) return;
    setState(() => _saving = true);
    final saved = await widget.controller.teach(
      dateCell: date,
      amountCell: amount,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cells = widget.controller.outcome?.sampleCells ?? const [];
    final page = widget.controller.outcome?.statement.rows.isNotEmpty == true
        ? widget.controller.outcome!.statement.rows.first.page
        : 1;
    final dateText = _dateCell == null ? null : cells[_dateCell!].text;
    return DetailScreen(
      header: ScreenHeader(
        title: l.importTeachTitle,
        dateLine: l.importTeachSubtitle(widget.controller.fileName ?? ''),
        leading: AppIconButton(
          icon: AppIcons.close,
          semanticLabel: l.importCancel,
          onPressed: widget.onClose,
        ),
      ),
      children: <Widget>[
        Text(
          l.importTeachKicker(widget.controller.fileName ?? ''),
          style: AppText.labelCaps,
        ),
        Text(l.importTeachLead, style: AppText.body),
        GlassCard(
          title: l.importTeachSample,
          meta: l.importTeachPage(page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.importTeachNeedThree,
                style: AppText.caption.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
              const VSpace(Space.s),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: <Widget>[
                  for (var i = 0; i < cells.length && i < 8; i++)
                    AppButton(
                      label: cells[i].text,
                      variant: i == _dateCell || i == _amountCell
                          ? AppButtonVariant.neutral
                          : AppButtonVariant.ghost,
                      fullWidth: false,
                      compact: true,
                      semanticLabel: l.importSemanticStep(cells[i].text),
                      onPressed: () => _tap(i),
                    ),
                ],
              ),
            ],
          ),
        ),
        GlassCard(
          title: l.importTeachSteps,
          meta: _dateCell == null
              ? '0 of 2'
              : (_amountCell == null ? '1 of 2' : '2 of 2'),
          child: Column(
            children: <Widget>[
              SelectRow(
                name: l.importTeachDate,
                value: dateText ??
                    l.importTeachStepNow(
                      l.importTeachDate,
                      1,
                    ),
                chevron: false,
              ),
              SelectRow(
                name: l.importTeachDetails,
                value: l.importTeachStepNext(l.importTeachDetails, 2),
                chevron: false,
              ),
              SelectRow(
                name: l.importTeachAmount,
                value: _amountCell == null
                    ? l.importTeachStepNext(l.importTeachAmount, 3)
                    : cells[_amountCell!].text,
                chevron: false,
              ),
            ],
          ),
        ),
        AppButton(
          label: l.importTeachSave,
          onPressed: _dateCell == null || _amountCell == null || _saving
              ? null
              : _save,
        ),
        AppButton(
          label: l.importTeachContinue,
          variant: AppButtonVariant.ghost,
          onPressed: widget.onClose,
        ),
      ],
    );
  }
}
