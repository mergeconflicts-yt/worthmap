import 'package:flutter/widgets.dart';

import '../../icons/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../buttons/app_button.dart';

/// DESIGN 6.7, SPEC W4: the edit-mode control row. The words come from l10n
/// (T10); a feature passes them in.
final class WidgetEditBarLabels {
  const WidgetEditBarLabels({
    required this.add,
    required this.cancel,
    required this.undo,
    required this.resetDefault,
    required this.done,
  });

  final String add;
  final String cancel;
  final String undo;
  final String resetDefault;
  final String done;
}

/// DESIGN 3.3, SPEC W4: one control row for edit mode: Add, Undo, Reset to
/// default, Cancel, Done. It never adds a second row; it scrolls if the row is
/// longer than the screen.
class WidgetEditBar extends StatelessWidget {
  const WidgetEditBar({
    required this.labels,
    this.onAdd,
    this.onCancel,
    this.onUndo,
    this.onResetDefault,
    this.onDone,
    super.key,
  });

  final WidgetEditBarLabels labels;
  final VoidCallback? onAdd;
  final VoidCallback? onCancel;
  final VoidCallback? onUndo;
  final VoidCallback? onResetDefault;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceTrack,
        borderRadius: BorderRadius.circular(RadiusTokens.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s,
          vertical: Space.xs,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              AppButton(
                label: labels.add,
                icon: AppIcons.add,
                variant: AppButtonVariant.soft,
                compact: true,
                fullWidth: false,
                onPressed: onAdd,
              ),
              const HSpace(Space.s),
              AppButton(
                label: labels.undo,
                variant: AppButtonVariant.ghost,
                compact: true,
                fullWidth: false,
                onPressed: onUndo,
              ),
              const HSpace(Space.s),
              AppButton(
                label: labels.resetDefault,
                variant: AppButtonVariant.ghost,
                compact: true,
                fullWidth: false,
                onPressed: onResetDefault,
              ),
              const HSpace(Space.s),
              AppButton(
                label: labels.cancel,
                variant: AppButtonVariant.ghost,
                compact: true,
                fullWidth: false,
                onPressed: onCancel,
              ),
              const HSpace(Space.s),
              AppButton(
                label: labels.done,
                variant: AppButtonVariant.primary,
                compact: true,
                fullWidth: false,
                onPressed: onDone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
