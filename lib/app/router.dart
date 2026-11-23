// T09 (SPEC 5.1-5.4; DESIGN 3; AGENTS 11): the Phase 1 router.
//
// Rules implemented here:
//   - every route carries its Section (DESIGN 3; SCREENS.md screen table);
//   - a deep link waits behind unlock: when the gate is closed, the router
//     redirects to X02 and preserves the target, so unlocking continues to
//     it without replaying Save/Confirm/Delete (no such mutation route
//     exists; the redirect drops query parameters so a pasted URL can never
//     carry an amount or a command);
//   - no amounts in URLs or logs: every incoming location is reduced to a
//     bare path, and router logs carry event names only (AGENTS 2.6);
//   - an unavailable target returns to the nearest parent (the Home tab
//     root in Phase 1);
//   - a tab re-select returns to the tab root;
//   - the gallery is a debug-only route.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/speech/speech.dart';
import '../design/design.dart';
import '../features/accounts/account_draft.dart';
import '../features/accounts/account_models.dart';
import '../features/accounts/x42b_account_editor.dart';
import '../features/add/payment_draft.dart';
import '../features/add/payment_models.dart';
import '../features/add/transfer_draft.dart';
import '../features/add/transfer_models.dart';
import '../features/add/voice/x24_voice_capture.dart';
import '../features/add/x20_add_payment.dart';
import '../features/add/x26_transfer.dart';
import '../features/history/c06_history.dart';
import '../features/history/history_models.dart';
import '../features/home/x03_home_first.dart';
import '../features/import/import_models.dart';
import '../features/import/x63_import.dart';
import '../features/inbox/inbox_models.dart';
import '../features/inbox/x60_inbox.dart';
import '../features/settings/x80_settings.dart';
import '../features/settings/x86_privacy.dart';
import '../features/spending/c02_schedule_editor.dart';
import '../features/spending/c03_rule_editor.dart';
import '../features/spending/payments_models.dart';
import '../features/spending/repeating_models.dart';
import '../features/spending/spending_models.dart';
import '../features/spending/x30_spending.dart';
import '../features/spending/x30c_where_it_goes.dart';
import '../features/spending/x31_money_in.dart';
import '../features/spending/x32_budget.dart';
import '../features/spending/x33_edit_limits.dart';
import '../features/spending/x34_repeating.dart';
import '../features/spending/x35_repeating_detail.dart';
import '../features/spending/x36_category_detail.dart';
import '../features/spending/x37_all_payments.dart';
import '../features/spending/x39_payment_detail.dart';
import '../features/spending/x84_rules.dart';
import '../features/start/x01_welcome.dart';
import '../features/start/x02_lock.dart';
import 'payments_gateway.dart';
import 'section_scope.dart';

/// The Phase 1 route paths. Screen ids per SPEC 5.4 and SCREENS.md.
enum AppRoute {
  welcome('/x01', 'X01'),
  lock('/x02', 'X02'),
  home('/x03', 'X03'),
  accountEditor('/x42b', 'X42b'),
  paymentAdd('/x20', 'X20'),
  transferAdd('/x26', 'X26'),
  voiceCapture('/x24', 'X24'),
  settings('/x80', 'X80'),
  inbox('/x60', 'X60'),
  importHub('/x63', 'X63'),
  spending('/x30', 'X30'),
  whereItGoes('/x30c', 'X30c'),
  moneyIn('/x31', 'X31'),
  budget('/x32', 'X32'),
  editLimits('/x33', 'X33'),
  category('/x36', 'X36'),
  allPayments('/x37', 'X37'),
  paymentDetail('/x39', 'X39'),
  repeating('/x34', 'X34'),
  repeatingDetail('/x35', 'X35'),
  rules('/x84', 'X84'),
  scheduleEditor('/c02', 'C02'),
  ruleEditor('/c03', 'C03'),
  history('/c06', 'C06'),
  privacy('/x86', 'X86'),
  gallery('/dev/gallery', 'GALLERY');

  const AppRoute(this.path, this.screenId);

  final String path;

  /// The SPEC screen id, used for the semantic label and the logs.
  final String screenId;
}

/// The router-visible gate. T08's `LockController` backs the real
/// implementation; tests inject a scripted gate.
abstract interface class LockGate {
  /// True when an unlocked session may reach private routes.
  bool get admissionOpen;
}

/// A gate that reports open. Placeholder until T10 wires X02 to the
/// LockController (DECISION-PENDING: T09-AUTH-GATE-WIRING). Never used on a
/// path that holds user data in Phase 1: Phase 1 screens carry no records.
final class AlwaysOpenGate implements LockGate {
  const AlwaysOpenGate();

  @override
  bool get admissionOpen => true;
}

/// Safe router log events (no locations, no amounts; AGENTS 2.6).
enum RouterLogEvent {
  deepLinkDeferred,
  deepLinkResumed,
  unknownTargetRouted,
  tabReselect,
  galleryOpened,
}

/// Builds the Phase 1 router. [screens] supplies the widget builders so the
/// router stays free of feature imports (T10 fills them).
final class ContourRouter {
  ContourRouter({
    LockGate? gate,
    this.onLog,
    AccountsGateway? accounts,
    AccountDraftStore? accountDrafts,
    PaymentsGateway? payments,
    PaymentDraftStore? paymentDrafts,
    TransferGateway? transfers,
    TransferDraftStore? transferDrafts,
    SpeechPort? speech,
    InboxGateway? inbox,
    SpendingGateway? spending,
    PaymentsReadGateway? paymentsRead,
    RepeatingGateway? repeating,
    HistoryGateway? history,
    ImportGateway? imports,
    ImportFileIntake? importFiles,
    ImportPasswordVault? importPasswords,
    String? initialLocation,
    Widget? gallery,
    bool demoEntries = false,
  })  : _initialLocation = initialLocation ?? AppRoute.welcome.path,
        _demoEntries = demoEntries,
        _gallery = gallery,
        _gate = gate ?? const AlwaysOpenGate(),
        _accounts = accounts ?? const UnavailableAccountsGateway(),
        _accountDrafts = accountDrafts,
        _payments = payments ?? const UnavailablePaymentsGateway(),
        _paymentDrafts = paymentDrafts,
        _transfers = transfers ?? const UnavailableTransferGateway(),
        _transferDrafts = transferDrafts,
        _speech = speech ?? const UnavailableSpeechPort(),
        _inbox = inbox ?? const UnavailableInboxGateway(),
        _spending = spending ?? const UnavailableSpendingGateway(),
        _paymentsRead = paymentsRead ?? const UnavailablePaymentsReadGateway(),
        _repeating = repeating ?? const UnavailableRepeatingGateway(),
        _history = history ?? const UnavailableHistoryGateway(),
        _imports = imports ?? const UnavailableImportGateway(),
        _importFiles = importFiles ?? const UnavailableFileIntake(),
        _importPasswords = importPasswords;

  final LockGate _gate;

  /// The account port for C01. The app composition injects the SQL gateway
  /// when the vault is open; the default is the factual unavailable state.
  final AccountsGateway _accounts;

  /// The C01 draft store. The app composition injects the P13 adapter; null
  /// keeps the form in memory only.
  final AccountDraftStore? _accountDrafts;

  /// The payment port for X20. The default is the factual unavailable state.
  final PaymentsGateway _payments;

  /// The X20 draft store. Null keeps the form in memory only.
  final PaymentDraftStore? _paymentDrafts;

  /// The transfer port for X26. The default is the factual unavailable state.
  final TransferGateway _transfers;

  /// The X26 draft store. Null keeps the form in memory only.
  final TransferDraftStore? _transferDrafts;

  /// The local speech port for P24. The default states that voice is
  /// unavailable until a native binding passes the SPEC 8.19 record.
  final SpeechPort _speech;

  /// The Inbox port for X60. Without a producer the page is empty.
  final InboxGateway _inbox;

  /// The Spending port for X30–X33. The default states the vault is closed.
  final SpendingGateway _spending;

  /// The payment list, detail and category port for X36–X39.
  final PaymentsReadGateway _paymentsRead;

  /// The repeating and rules port for X34, X35, X84, C02 and C03.
  final RepeatingGateway _repeating;

  /// The activity history port for C06.
  final HistoryGateway _history;

  /// The PDF import port for X63.
  final ImportGateway _imports;

  /// The local file intake for X63. Unavailable until a verified binding.
  final ImportFileIntake _importFiles;

  /// The X64 password vault. Null keeps the password in the dialog only.
  final ImportPasswordVault? _importPasswords;

  /// The first route. The demo composition starts on the gallery.
  final String _initialLocation;

  /// A debug gallery replacement (the demo menu). Null keeps the placeholder.
  final Widget? _gallery;

  /// Demo composition only: Home offers Spending and Add while the tab shell
  /// is not mounted (P18-SHELL-MOUNT).
  final bool _demoEntries;

  /// Event-name sink for the app's count-only log surface.
  final void Function(RouterLogEvent event)? onLog;

  /// The deferred deep-link target, restored after unlock. Path only; any
  /// query is dropped (no amounts in URLs).
  String? _pendingLocation;

  /// The locked route stays available behind a closed gate: X02 itself must
  /// not redirect to itself.
  bool _onLockRoute(GoRouterState state) =>
      state.matchedLocation == AppRoute.lock.path;

  /// Reduces a location to its bare path (drops the query and fragment).
  static String bareLocation(Uri uri) => uri.path;

  GoRouter build() {
    return GoRouter(
      initialLocation: _initialLocation,
      redirect: (context, state) {
        // An unavailable target returns to the nearest parent: the Home tab
        // root in Phase 1 (SPEC 5.4). The check runs before the gate so a
        // pasted junk path cannot lock the app on an unknown screen.
        final path = bareLocation(state.uri);
        final known = AppRoute.values.any((route) => route.path == path);
        if (!known) {
          onLog?.call(RouterLogEvent.unknownTargetRouted);
          return AppRoute.home.path;
        }
        final bare = path;
        if (_onLockRoute(state) || _gate.admissionOpen) {
          if (_pendingLocation != null && _gate.admissionOpen) {
            final target = _pendingLocation;
            _pendingLocation = null;
            onLog?.call(RouterLogEvent.deepLinkResumed);
            return target;
          }
          return null;
        }
        // A deep link behind unlock waits: redirect to X02 and keep the
        // bare target. It never replays a mutation because only the path
        // survives.
        _pendingLocation = bare;
        onLog?.call(RouterLogEvent.deepLinkDeferred);
        return AppRoute.lock.path;
      },
      routes: [
        _route(AppRoute.welcome, const X01Welcome()),
        _route(AppRoute.lock, const X02Lock()),
        GoRoute(
          path: AppRoute.home.path,
          name: AppRoute.home.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.home,
            X03HomeFirstRun(
              onSpending: _demoEntries
                  ? () => context.push(AppRoute.spending.path)
                  : null,
              onAddPayment: _demoEntries
                  ? () => context.push(AppRoute.paymentAdd.path)
                  : null,
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.accountEditor.path,
          name: AppRoute.accountEditor.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.accountEditor,
            X42bAccountEditor(
              gateway: _accounts,
              drafts: _accountDrafts,
              onClose: () => context.pop(),
              onSaved: (AccountSummary account) => context.pop(account),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.paymentAdd.path,
          name: AppRoute.paymentAdd.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.paymentAdd,
            X20AddPayment(
              gateway: _payments,
              drafts: _paymentDrafts,
              today: paymentToday(),
              initialKind: state.extra is PaymentKind
                  ? state.extra! as PaymentKind
                  : PaymentKind.expense,
              onClose: () => context.pop(),
              onSaved: (SavedPayment saved) => context.pop(saved),
              onAddAccount: () => context.push<AccountSummary>(
                AppRoute.accountEditor.path,
              ),
              onTransfer: () async {
                final saved = await context.push<SavedTransfer>(
                  AppRoute.transferAdd.path,
                );
                if (saved != null && context.mounted) {
                  context.pop();
                }
              },
              onSpeak: () async {
                final result = await context.push<Object?>(
                  AppRoute.voiceCapture.path,
                );
                if (result is SavedPayment) {
                  if (context.mounted) {
                    context.pop();
                  }
                  return null;
                }
                return result is String ? result : null;
              },
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.transferAdd.path,
          name: AppRoute.transferAdd.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.transferAdd,
            X26Transfer(
              gateway: _transfers,
              drafts: _transferDrafts,
              today: paymentToday(),
              onClose: () => context.pop(),
              onSaved: (SavedTransfer saved) => context.pop(saved),
              onSwitchType: (PaymentKind kind) => context.go(
                AppRoute.paymentAdd.path,
                extra: kind,
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.spending.path,
          name: AppRoute.spending.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.spending,
            X30Spending(
              gateway: _spending,
              onWhereItGoes: () => context.push(AppRoute.whereItGoes.path),
              onAllPayments: () => context.push(AppRoute.allPayments.path),
              onRepeating: () => context.push(AppRoute.repeating.path),
              onMoneyIn: () => context.push(AppRoute.moneyIn.path),
              onBudget: () => context.push(AppRoute.budget.path),
              onEditLimits: () => context.push(AppRoute.editLimits.path),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.whereItGoes.path,
          name: AppRoute.whereItGoes.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.whereItGoes,
            X30cWhereItGoes(
              gateway: _spending,
              onClose: () => context.pop(),
              onCategory: (String id) => context.push(
                AppRoute.category.path,
                extra: id,
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.moneyIn.path,
          name: AppRoute.moneyIn.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.moneyIn,
            X31MoneyIn(
              gateway: _spending,
              onClose: () => context.pop(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.budget.path,
          name: AppRoute.budget.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.budget,
            X32Budget(
              gateway: _spending,
              onClose: () => context.pop(),
              onEditLimits: () => context.push(AppRoute.editLimits.path),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.editLimits.path,
          name: AppRoute.editLimits.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.editLimits,
            X33EditLimits(
              gateway: _spending,
              onClose: () => context.pop(),
              onSaved: () => context.pop(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.category.path,
          name: AppRoute.category.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.category,
            X36CategoryDetail(
              gateway: _paymentsRead,
              categoryId: state.extra is String ? state.extra! as String : '',
              onClose: () => context.pop(),
              onOpenPayment: (String id) => context.push<DeletedPayment>(
                AppRoute.paymentDetail.path,
                extra: id,
              ),
              onAllPayments: (String categoryId) => context.push(
                AppRoute.allPayments.path,
                extra: PaymentFilter(
                  period: PaymentPeriod.thisMonth,
                  show: PaymentShowFilter.moneyOut,
                  categoryId: categoryId,
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.allPayments.path,
          name: AppRoute.allPayments.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.allPayments,
            X37AllPayments(
              gateway: _paymentsRead,
              initialFilter: state.extra is PaymentFilter
                  ? state.extra! as PaymentFilter
                  : null,
              onClose: () => context.pop(),
              onOpenPayment: (String id) => context.push<DeletedPayment>(
                AppRoute.paymentDetail.path,
                extra: id,
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.paymentDetail.path,
          name: AppRoute.paymentDetail.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.paymentDetail,
            X39PaymentDetail(
              gateway: _paymentsRead,
              paymentId: state.extra is String ? state.extra! as String : '',
              onClose: () => context.pop(),
              onDeleted: (DeletedPayment deleted) => context.pop(deleted),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.repeating.path,
          name: AppRoute.repeating.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.repeating,
            X34Repeating(
              gateway: _repeating,
              onClose: () => context.pop(),
              onOpenSchedule: (String id) => context.push(
                AppRoute.repeatingDetail.path,
                extra: id,
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.repeatingDetail.path,
          name: AppRoute.repeatingDetail.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.repeatingDetail,
            X35RepeatingDetail(
              gateway: _repeating,
              scheduleId: state.extra is String ? state.extra! as String : '',
              onClose: () => context.pop(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.rules.path,
          name: AppRoute.rules.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.rules,
            X84Rules(
              gateway: _repeating,
              onClose: () => context.pop(),
              onAddRule: () => context.push(AppRoute.ruleEditor.path),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.scheduleEditor.path,
          name: AppRoute.scheduleEditor.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.scheduleEditor,
            C02ScheduleEditor(
              gateway: _repeating,
              onClose: () => context.pop(),
              onSaved: () => context.pop(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.ruleEditor.path,
          name: AppRoute.ruleEditor.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.ruleEditor,
            C03RuleEditor(
              gateway: _repeating,
              onClose: () => context.pop(),
              onSaved: () => context.pop(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.history.path,
          name: AppRoute.history.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.history,
            C06History(
              gateway: _history,
              onClose: () => context.pop(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.inbox.path,
          name: AppRoute.inbox.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.inbox,
            X60Inbox(
              gateway: _inbox,
              onClose: () => context.pop(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.importHub.path,
          name: AppRoute.importHub.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.importHub,
            X63Import(
              gateway: _imports,
              intake: _importFiles,
              accounts: _accounts,
              onClose: () => context.pop(),
              onOpenInbox: () => context.push(AppRoute.inbox.path),
              passwords: _importPasswords,
            ),
          ),
        ),
        GoRoute(
          path: AppRoute.voiceCapture.path,
          name: AppRoute.voiceCapture.screenId,
          builder: (context, state) => _screenScaffold(
            AppRoute.voiceCapture,
            X24VoiceCapture(
              gateway: _payments,
              speech: _speech,
              drafts: _paymentDrafts,
              today: paymentToday(),
              onClose: () => context.pop(),
              onSaved: (SavedPayment saved) => context.pop(saved),
              onContinueWithForm: (String transcript) =>
                  context.pop(transcript),
            ),
          ),
        ),
        _route(AppRoute.settings, const X80Settings()),
        _route(AppRoute.privacy, const X86Privacy()),
        if (kDebugMode)
          GoRoute(
            path: AppRoute.gallery.path,
            name: AppRoute.gallery.screenId,
            builder: (context, state) => _screenScaffold(
              AppRoute.gallery,
              _screenScaffold(
                AppRoute.gallery,
                _gallery ?? const _PlaceholderScreen(),
              ),
            ),
          ),
      ],
    );
  }

  GoRoute _route(AppRoute route, Widget screen) {
    return GoRoute(
      path: route.path,
      name: route.screenId,
      builder: (context, state) => _screenScaffold(route, screen),
    );
  }

  /// Wraps the screen in the route's SectionScope (DESIGN 3).
  Widget _screenScaffold(AppRoute route, Widget screen) {
    if (route == AppRoute.gallery) {
      onLog?.call(RouterLogEvent.galleryOpened);
    }
    return SectionScope(
      section: sectionForRoute(route),
      child: screen,
    );
  }

  /// A tab re-select returns to the tab root (SPEC 5.1). Phase 1 has one
  /// tab (Home); the API takes the section so T10's tab bar can call it.
  void selectTab(Section section, BuildContext context) {
    final root = section == Section.home ? AppRoute.home.path : null;
    final target = root ?? AppRoute.home.path;
    final current = GoRouterState.of(context).matchedLocation;
    if (current == target) {
      onLog?.call(RouterLogEvent.tabReselect);
    }
    GoRouter.of(context).go(target);
  }

  /// Exposes the pending target for tests.
  String? get pendingLocationForTest => _pendingLocation;
}

/// A neutral placeholder until T10 builds the screens. No amounts, no data.
/// A neutral placeholder for the debug gallery route until T11 ships the
/// design gallery route. No amounts, no data.
final class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.tokens.surfacePage,
      child: const SizedBox.expand(),
    );
  }
}
