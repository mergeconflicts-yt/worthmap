// P3-25 (SCREEN X63; flow F06 step 1): the import hub.
//
// The hub offers the permitted source and lists saved layouts and past
// imports. PDF only in this release; CSV, Excel, OFX, QIF, CAMT, MT940, QR and
// receipt photo are absent, not disabled (SPEC 5.5).
library;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'import_controller.dart';
import 'import_models.dart';

/// X63: choose a PDF, saved layouts and history.
class X63ImportHub extends StatelessWidget {
  const X63ImportHub({
    required this.controller,
    required this.onClose,
    required this.onChoose,
    required this.onOpenBatch,
    super.key,
  });

  final ImportController controller;
  final VoidCallback onClose;
  final VoidCallback onChoose;
  final void Function(ImportBatchView batch) onOpenBatch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reading = controller.step == ImportStep.reading;
    return DetailScreen(
      header: ScreenHeader(
        title: l.importTitle,
        dateLine: l.importSubtitle,
        leading: AppIconButton(
          icon: AppIcons.close,
          semanticLabel: l.importCancel,
          onPressed: onClose,
        ),
      ),
      children: <Widget>[
        Text(l.importKicker, style: AppText.labelCaps),
        Text(
          l.importLead,
          style: AppText.line.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? context.tokens.textSecondary
                : context.tokens.textSecondary,
          ),
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppButton(
                label: reading ? l.importReading : l.importChoosePdf,
                icon: AppIcons.import,
                onPressed: reading ? null : onChoose,
                semanticLabel: l.importSemanticFile,
              ),
              const VSpace(Space.s),
              Text(
                l.importChoosePdfHelper,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _layouts(context, l),
        _history(context, l),
        Text(
          l.importTip,
          style: AppText.caption.copyWith(color: context.tokens.textSecondary),
        ),
      ],
    );
  }

  Widget _layouts(BuildContext context, AppLocalizations l) {
    final layouts = controller.layouts;
    return GlassCard(
      title: l.importSavedLayouts,
      meta: '${layouts.length}',
      child: Column(
        children: <Widget>[
          if (layouts.isEmpty)
            SelectRow(
              name: l.importSavedLayoutsNone,
              chevron: false,
            )
          else
            for (final layout in layouts)
              SelectRow(
                name: layout.name,
                line: layout.usedCount == 1
                    ? l.importLayoutUsedOnce
                    : l.importLayoutUsed(layout.usedCount),
                chevron: false,
              ),
        ],
      ),
    );
  }

  Widget _history(BuildContext context, AppLocalizations l) {
    final history = controller.history;
    return GlassCard(
      title: l.importHistory,
      meta: '${history.length}',
      child: Column(
        children: <Widget>[
          if (history.isEmpty)
            SelectRow(name: l.importHistoryNone, chevron: false)
          else
            for (final batch in history)
              SelectRow(
                name: batch.label,
                line: _historyLine(batch, l),
                chevron: true,
                onTap: () => onOpenBatch(batch),
                semanticLabel: l.importSemanticHistoryRow(
                  _dateOf(batch),
                  batch.label,
                ),
              ),
        ],
      ),
    );
  }

  String _historyLine(ImportBatchView batch, AppLocalizations l) {
    final date = _dateOf(batch);
    return batch.existing > 0
        ? l.importHistoryLine(date, batch.existing, batch.staged)
        : l.importHistoryLineShort(date, batch.staged);
  }

  String _dateOf(ImportBatchView batch) {
    final local =
        DateTime.fromMillisecondsSinceEpoch(batch.createdAtMs).toLocal();
    return formatDate(
      LocalDate(local.year, local.month, local.day),
      DateStyle.short,
    );
  }
}
