import 'package:flutter/material.dart';

import '../design/design.dart';
import '../features/accounts/account_draft.dart';
import '../features/accounts/account_models.dart';
import '../l10n/generated/app_localizations.dart';
import 'hidden_amounts.dart';
import 'router.dart';

/// Phase 1 entry widget. The router carries the Phase 1 routes with their
/// Sections (T09); the lock and the real screens land in T10. No amounts.
/// No network.
///
/// P20: the app owns the hidden-amount controller, so the state survives
/// navigation and the lock. A test can pass its own controller.
class ContourApp extends StatefulWidget {
  const ContourApp({
    super.key,
    this.router,
    this.hiddenAmounts,
    this.accountsGateway,
    this.accountDrafts,
  });

  /// Test seam: a prebuilt router. The app builds its own otherwise.
  final ContourRouter? router;

  /// Test seam: the hidden-amount state. The app builds its own otherwise.
  final HiddenAmountsController? hiddenAmounts;

  /// The account port for C01. The future vault composition injects the SQL
  /// gateway; null keeps the factual unavailable state (P21 gate).
  final AccountsGateway? accountsGateway;

  /// The C01 draft store. The composition injects the P13 adapter.
  final AccountDraftStore? accountDrafts;

  @override
  State<ContourApp> createState() => _ContourAppState();
}

class _ContourAppState extends State<ContourApp> {
  late final ContourRouter _router = widget.router ??
      ContourRouter(
        accounts: widget.accountsGateway,
        accountDrafts: widget.accountDrafts,
      );
  late final HiddenAmountsController _hiddenAmounts =
      widget.hiddenAmounts ?? HiddenAmountsController();

  @override
  void initState() {
    super.initState();
    // The stored bit is read once, before the first screen can show an
    // amount. A store failure keeps the initial state (hidden amounts are
    // never revealed by an error).
    _hiddenAmounts.load();
  }

  @override
  void dispose() {
    if (widget.hiddenAmounts == null) {
      _hiddenAmounts.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HiddenAmountsHost(
      controller: _hiddenAmounts,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        onGenerateTitle: (BuildContext context) =>
            AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router.build(),
      ),
    );
  }
}
