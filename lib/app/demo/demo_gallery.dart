// P29 demo menu (debug only). It gives the in-memory demo a starting screen,
// because the tab shell is not mounted (P18-SHELL-MOUNT).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// The demo start screen with one row per Phase 2 area.
class DemoGallery extends StatelessWidget {
  const DemoGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DetailScreen(
      header: ScreenHeader(
        title: l.demoTitle,
        dateLine: l.demoNote,
      ),
      children: <Widget>[
        GlassCard(
          child: Column(
            children: <Widget>[
              _row(context, l.demoSpending, '/x30'),
              _row(context, l.demoAddPayment, '/x20'),
              _row(context, l.demoAllPayments, '/x37'),
              _row(context, l.demoInbox, '/x60'),
              _row(context, l.importTitle, '/x63'),
              _row(context, l.demoRepeating, '/x34'),
              _row(context, l.demoRules, '/x84'),
              _row(context, l.demoHistory, '/c06'),
              _row(context, l.demoHome, '/x03'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String path) {
    return SelectRow(
      name: label,
      onTap: () => GoRouter.of(context).push(path),
      semanticLabel: label,
    );
  }
}
