// X40 (SCREENS X40; SPEC 5.1): Wealth, tab root.
//
// The overview is not built yet. The screen keeps the tab shell, the section
// colour and one factual line; it shows no invented numbers.
library;

import 'package:flutter/widgets.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

class X40Wealth extends StatelessWidget {
  const X40Wealth({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TabRootScreen(
      header: ScreenHeader(title: l.tabWealth),
      children: <Widget>[
        UnavailableCard(label: l.sectionNotAvailable),
      ],
    );
  }
}
