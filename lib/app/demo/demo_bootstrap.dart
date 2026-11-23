// P29 demo bootstrap (debug only). It opens the synthetic in-memory vault
// before the router exists, then starts the normal app with the demo router.
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import '../app.dart';
import '../router.dart';
import 'demo_composition.dart';

/// Starts the demo composition and the normal app.
class DemoBootstrap extends StatefulWidget {
  const DemoBootstrap({super.key});

  @override
  State<DemoBootstrap> createState() => _DemoBootstrapState();
}

class _DemoBootstrapState extends State<DemoBootstrap> {
  /// A real SQLite file for the debug demo when the runner sets
  /// `DEMO_DB_PATH`. Empty keeps the in-memory demo.
  static const String _dbPath = String.fromEnvironment('DEMO_DB_PATH');

  late final Future<ContourRouter> _router =
      DemoComposition.build(dbPath: _dbPath);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContourRouter>(
      future: _router,
      builder: (BuildContext context, AsyncSnapshot<ContourRouter> snapshot) {
        if (snapshot.hasData) {
          return ContourApp(router: snapshot.data);
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => ColoredBox(
              color: context.tokens.surfacePage,
              child: Center(
                child: Text(
                  snapshot.hasError
                      ? AppLocalizations.of(context).demoFailed
                      : AppLocalizations.of(context).demoStarting,
                  style: AppText.body,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
