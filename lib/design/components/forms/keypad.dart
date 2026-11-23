import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../tokens/tokens.g.dart';
import '../../typography/app_text.dart';
import '../interaction/app_interaction.dart';

/// DESIGN 6.4: `Keypad`. A 3 × 4 grid of `size.key` keys with no fill and no
/// edge. A press shows `surface.tile`; digits use `AppText.key`; Delete uses
/// `text.secondary`.
class Keypad extends StatelessWidget {
  const Keypad({
    required this.onDigit,
    required this.onDelete,
    required this.deleteLabel,
    required this.decimalLabel,
    super.key,
  });

  /// Receives '1'-'9', '0' and '.'.
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  /// The visible Delete word and its spoken name.
  final String deleteLabel;

  /// The spoken name for the decimal point.
  final String decimalLabel;

  @override
  Widget build(BuildContext context) {
    const rows = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
      <String>['.', '0', 'delete'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final row in rows)
          Row(
            children: <Widget>[
              for (final key in row)
                Expanded(
                  child: _Key(
                    label: key == 'delete' ? deleteLabel : key,
                    semanticLabel: switch (key) {
                      'delete' => deleteLabel,
                      '.' => decimalLabel,
                      _ => key,
                    },
                    secondary: key == 'delete',
                    onPressed: key == 'delete' ? onDelete : () => onDigit(key),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    required this.label,
    required this.semanticLabel,
    required this.secondary,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final bool secondary;
  final VoidCallback onPressed;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AppInteraction(
          onActivated: widget.onPressed,
          hoverTint: false,
          borderRadius: BorderRadius.circular(RadiusTokens.tile),
          child: SizedBox(
            height: SizeTokens.key,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _pressed ? tokens.surfaceTile : null,
                borderRadius: BorderRadius.circular(RadiusTokens.tile),
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: widget.secondary
                      ? AppText.body.copyWith(color: tokens.textSecondary)
                      : AppText.key.copyWith(color: tokens.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
