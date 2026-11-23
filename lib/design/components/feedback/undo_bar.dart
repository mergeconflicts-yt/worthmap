import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.6: `UndoBar`. An inline bar after a list action: a 52 pt pill with
/// a `surface.glassEdge` edge, a 15 pt message and one underlined "Undo".
/// It never floats over rows and never shows a spinner.
class UndoBar extends StatelessWidget {
  const UndoBar({
    required this.message,
    required this.undoLabel,
    required this.onUndo,
    required this.semanticLabel,
    super.key,
  });

  final String message;
  final String undoLabel;
  final VoidCallback? onUndo;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onUndo != null;
    return Align(
      heightFactor: 1,
      child: Semantics(
        label: semanticLabel,
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surfaceSheet,
            borderRadius: BorderRadius.circular(RadiusTokens.pill),
            border: Border.all(color: tokens.surfaceGlassEdge),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.only(
                left: Space.card,
                right: Space.xs,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      message,
                      style: AppText.bodyS.copyWith(color: tokens.textPrimary),
                    ),
                  ),
                  Semantics(
                    button: true,
                    enabled: enabled,
                    label: undoLabel,
                    excludeSemantics: true,
                    child: AppInteraction(
                      onActivated: onUndo,
                      enabled: enabled,
                      borderRadius: BorderRadius.circular(RadiusTokens.pill),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: SizeTokens.touchMin,
                          minHeight: SizeTokens.touchMin,
                        ),
                        child: Center(
                          child: Text(
                            undoLabel,
                            style: AppText.buttonS.copyWith(
                              color: enabled
                                  ? tokens.textPrimary
                                  : tokens.disabled,
                              decoration: TextDecoration.underline,
                              decorationColor: enabled
                                  ? tokens.textPrimary
                                  : tokens.disabled,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
