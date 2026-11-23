// P29 (SPEC 4.9, 8.18; DESIGN 6.6): the visible Hide amounts control.
//
// One header control toggles the app-level presentation bit. It writes no
// financial record. It is absent when no controller is mounted (a preview or a
// golden that does not need the control).
library;

import 'package:flutter/widgets.dart';

import '../design/design.dart';
import '../l10n/generated/app_localizations.dart';
import 'hidden_amounts.dart';

/// A header icon that toggles the hidden-amount state.
class HideAmountsButton extends StatelessWidget {
  const HideAmountsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = HiddenAmountsControllerScope.maybeOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final hidden = HiddenAmountsScope.resolve(context, null);
    return AppIconButton(
      icon: hidden ? AppIcons.show : AppIcons.hide,
      semanticLabel: hidden ? l.hideAmountsShow : l.hideAmountsHide,
      onPressed: controller.toggle,
    );
  }
}
