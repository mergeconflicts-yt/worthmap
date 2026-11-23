// P3-25 (SCREEN X88; flow F06): the import failure.
//
// One neutral state card, one primary action and one ghost action. The caption
// "Nothing from this file was added" is true: no row is staged on a failure.
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'import_controller.dart';
import 'import_models.dart';

/// X88: the file could not be read.
class X88ImportError extends StatelessWidget {
  const X88ImportError({
    required this.controller,
    required this.onChoose,
    required this.onTeach,
    required this.onClose,
    super.key,
  });

  final ImportController controller;
  final VoidCallback onChoose;
  final VoidCallback onTeach;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = _message(l, controller.failure);
    return DetailScreen(
      header: ScreenHeader(
        title: l.importTitle,
        dateLine: controller.fileName,
        leading: AppIconButton(
          icon: AppIcons.close,
          semanticLabel: l.importCancel,
          onPressed: onClose,
        ),
      ),
      children: <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const IconTile(icon: AppIcons.info),
              const VSpace(Space.m),
              Text(
                _title(l, controller.failure),
                textAlign: TextAlign.center,
                style: AppText.bodyStrong,
              ),
              const VSpace(Space.xxs),
              Text(
                controller.failure == ImportFailure.notPdf
                    ? l.importErrorBody(controller.fileName ?? '')
                    : text,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        AppButton(
          label: l.importErrorChoose,
          onPressed: onChoose,
        ),
        if (controller.outcome?.sampleLine != null)
          AppButton(
            label: l.importErrorTeach,
            variant: AppButtonVariant.ghost,
            onPressed: onTeach,
          ),
        Text(
          l.importErrorNothingAdded,
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: context.tokens.textSecondary),
        ),
      ],
    );
  }

  String _title(AppLocalizations l, ImportFailure? failure) =>
      failure == ImportFailure.notPdf
          ? l.importErrorNotPdfTitle
          : l.importErrorTitle;

  String _message(AppLocalizations l, ImportFailure? failure) =>
      switch (failure) {
        ImportFailure.notWired => l.importErrorUnavailable,
        ImportFailure.notPdf => l.importErrorNotPdf,
        ImportFailure.damaged => l.importErrorDamaged,
        ImportFailure.tooLarge => l.importErrorTooLarge,
        ImportFailure.unsupportedFilter => l.importErrorEncryption,
        ImportFailure.unsupportedEncryption => l.importErrorEncryption,
        ImportFailure.locked => l.importErrorLocked,
        ImportFailure.wrongPassword => l.importErrorLocked,
        ImportFailure.noText => l.importErrorNoText,
        ImportFailure.noRows => l.importErrorNoRows,
        ImportFailure.duplicateFile => l.importErrorDuplicate,
        ImportFailure.sendFailed => l.importErrorSend,
        ImportFailure.undoFailed => l.importErrorUndo,
        ImportFailure.templateFailed => l.importErrorUndo,
        null => l.importErrorNoRows,
      };
}
