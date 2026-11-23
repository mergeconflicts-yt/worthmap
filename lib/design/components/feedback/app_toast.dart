import 'dart:async';

import 'package:flutter/material.dart';

import '../../motion/motion.dart';
import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/token_types.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.6: `AppToast`. A `surface.sheet` pill with one "Undo" in
/// `action.neutral.fill`, 5 s, above the tab bar. It appears only after a
/// confirmed write (SPEC 8.18).
class AppToast extends StatelessWidget {
  const AppToast({
    required this.message,
    required this.undoLabel,
    required this.onUndo,
    super.key,
  });

  final String message;
  final String undoLabel;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceSheet,
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
        border: Border.all(color: tokens.surfaceGlassEdge),
        boxShadow: tokens.elevationSheet.shadows,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: Space.card, right: Space.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                message,
                style: AppText.bodyS.copyWith(color: tokens.textPrimary),
              ),
            ),
            const HSpace(Space.s),
            Semantics(
              button: true,
              label: undoLabel,
              excludeSemantics: true,
              child: AppInteraction(
                onActivated: onUndo,
                enabled: onUndo != null,
                borderRadius: BorderRadius.circular(RadiusTokens.pill),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.actionNeutralFill,
                    borderRadius: BorderRadius.circular(RadiusTokens.pill),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: SizeTokens.touchMin,
                      minHeight: SizeTokens.touchMin,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.card,
                        ),
                        child: Text(
                          undoLabel,
                          style: AppText.buttonS.copyWith(
                            color: tokens.textOnInverse,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dismiss handle for one visible toast.
typedef ToastDismiss = void Function();

/// The toast sits above the floating tab bar: 14 pt lift + 64 pt bar + 8 pt.
const double _toastBottom = SizeTokens.tabBar + 14 + 8;

/// Shows one [AppToast] above the tab bar. The caller shows it only after a
/// confirmed write. [duration] is injectable for tests.
ToastDismiss showAppToast(
  BuildContext context, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
  Duration duration = Motion.toast,
}) {
  final overlay = Overlay.of(context);
  var closed = false;
  late final OverlayEntry entry;
  Timer? timer;

  void close() {
    if (closed) {
      return;
    }
    closed = true;
    timer?.cancel();
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: Space.page,
      right: Space.page,
      bottom: MediaQuery.paddingOf(context).bottom + _toastBottom,
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Material(
          type: MaterialType.transparency,
          child: AppToast(
            message: message,
            undoLabel: undoLabel,
            onUndo: () {
              close();
              onUndo();
            },
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  timer = Timer(duration, close);
  return close;
}
