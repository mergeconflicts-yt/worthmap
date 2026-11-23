import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../tokens/space.dart';
import '../../typography/app_text.dart';

/// DESIGN 6.3: `ToggleRow` — name (`body` 500), description (`caption`),
/// switch. On = `action.primary.fill`; the state is also visible by switch
/// position. State carries no advice text.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    required this.name,
    required this.value,
    required this.onChanged,
    this.description,
    this.semanticLabel,
    super.key,
  });

  final String name;

  /// The grey description line.
  final String? description;

  /// The current switch state.
  final bool value;

  final ValueChanged<bool> onChanged;

  /// The spoken description (AGENTS 6.9). Required while the row is
  /// interactive.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.m),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.body),
                if (description != null) ...[
                  const SizedBox(height: Space.xxs),
                  Text(
                    description!,
                    style: AppText.caption.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      toggled: value,
      child: row,
    );
  }
}
