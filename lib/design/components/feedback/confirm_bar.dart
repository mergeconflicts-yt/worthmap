import 'package:flutter/widgets.dart';

import '../buttons/app_button.dart';

/// DESIGN 6.6: `ConfirmBar`. A primary button with the exact ticked count and
/// total. It sits after the list, in the scroll flow; it never floats over
/// rows or decision buttons.
///
/// The caller builds [label] from l10n and the exact `MoneyText` total; the
/// bar never formats a number itself.
class ConfirmBar extends StatelessWidget {
  const ConfirmBar({
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      semanticLabel: semanticLabel ?? label,
      onPressed: onPressed,
    );
  }
}
