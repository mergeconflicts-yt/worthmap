// X50 (SCREENS X50; SPEC 5.1): Plan, tab root (Calendar).
//
// The calendar is not built yet. The screen keeps the tab shell, the section
// colour and one factual line; it shows no invented numbers.
library;

import 'package:flutter/widgets.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

class X50Plan extends StatelessWidget {
  const X50Plan({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TabRootScreen(
      header: ScreenHeader(title: l.tabPlan),
      children: <Widget>[
        UnavailableCard(label: l.sectionNotAvailable),
      ],
    );
  }
}
