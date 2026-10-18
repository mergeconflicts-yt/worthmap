import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../typography/app_text.dart';
import 'glass_card.dart';

/// N-09: the card for a key this release does not know or does not show.
/// The label comes from l10n in T10; until then the caller passes it
/// (DECISION-PENDING: T06-L10N-CONSTANTS).
class UnavailableCard extends StatelessWidget {
  const UnavailableCard({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Text(
        label,
        style: AppText.body.copyWith(color: context.tokens.textPrimary),
      ),
    );
  }
}
