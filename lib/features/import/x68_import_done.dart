// P3-25 (SCREEN X68; flow F06 steps 5-6): the import result.
//
// The counts are the exact staged rows. "Undo this import" removes every
// staged item until one is confirmed (SPEC 8.18).
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'import_controller.dart';

/// X68: counts, Open the Inbox and Undo this import.
class X68ImportDone extends StatelessWidget {
  const X68ImportDone({
    required this.controller,
    required this.onOpenInbox,
    required this.onClose,
    super.key,
  });

  final ImportController controller;
  final VoidCallback onOpenInbox;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = controller.staged;
    return DetailScreen(
      header: ScreenHeader(
        title: l.importDoneTitle,
        dateLine: controller.fileName ?? l.importTitle,
        leading: AppIconButton(
          icon: AppIcons.close,
          semanticLabel: l.importCancel,
          onPressed: onClose,
        ),
      ),
      children: <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.importDoneKicker(controller.fileName ?? ''),
                style: AppText.labelCaps,
              ),
              const VSpace(Space.s),
              Text('$total', style: AppText.numberXL),
              const VSpace(Space.xxs),
              Text(
                l.importDoneLine(
                  total,
                  controller.decisionCount,
                  controller.noCategoryCount,
                  controller.readyCount,
                ),
                style: AppText.body,
              ),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            children: <Widget>[
              SelectRow(
                name: l.importReady,
                value: '${controller.readyCount}',
                chevron: false,
              ),
              SelectRow(
                name: l.importDecisions,
                value: '${controller.decisionCount}',
                chevron: false,
              ),
              SelectRow(
                name: l.importNoCategory,
                value: '${controller.noCategoryCount}',
                chevron: false,
              ),
            ],
          ),
        ),
        AppButton(
          label: l.importDoneOpenInbox,
          icon: AppIcons.inbox,
          onPressed: onOpenInbox,
        ),
        AppButton(
          label: l.importDoneUndo,
          variant: AppButtonVariant.ghost,
          onPressed: controller.busy ? null : controller.undo,
        ),
        Text(
          l.importDoneCaption,
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: context.tokens.textSecondary),
        ),
      ],
    );
  }
}
