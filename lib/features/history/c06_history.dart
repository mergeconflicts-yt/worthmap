// P29 (SCREEN C06; SPEC 8.18): activity history.
//
// Newest first. A reversible entry offers one Undo; a reversed entry keeps its
// place next to the compensating record; a change (settings, category, rule)
// has no Undo. No amount, merchant or account name appears in the history.
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'history_models.dart';

/// C06: the confirmed operations and their state.
class C06History extends StatefulWidget {
  const C06History({
    required this.gateway,
    required this.onClose,
    super.key,
  });

  final HistoryGateway gateway;
  final VoidCallback onClose;

  @override
  State<C06History> createState() => _C06HistoryState();
}

class _C06HistoryState extends State<C06History> {
  List<HistoryEntry> _entries = const <HistoryEntry>[];
  bool _loading = true;
  bool _failed = false;
  final Set<String> _running = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final entries = await widget.gateway.load();
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _undo(HistoryEntry entry) async {
    setState(() => _running.add(entry.operationId));
    final ok = await widget.gateway.undo(entry);
    if (!mounted) {
      return;
    }
    setState(() {
      _running.remove(entry.operationId);
      _failed = !ok;
    });
    if (ok) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DetailScreen(
      header: ScreenHeader(
        title: l.historyTitle,
        dateLine: l.historySubline,
        leading: AppIconButton(
          icon: AppIcons.back,
          semanticLabel: l.paymentsBack,
          onPressed: widget.onClose,
        ),
      ),
      children: <Widget>[
        if (_loading)
          Text(l.spendingLoading, style: AppText.caption)
        else if (_failed && _entries.isEmpty) ...<Widget>[
          Text(l.historyLoadFailed, style: AppText.bodyStrong),
          AppButton(
            label: l.spendingRetry,
            variant: AppButtonVariant.soft,
            onPressed: _load,
          ),
        ] else if (_entries.isEmpty)
          GlassCard(
            child: Text(
              l.historyEmpty,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          )
        else
          GlassCard(
            child: Column(
              children: <Widget>[
                for (final entry in _entries) ...<Widget>[
                  _row(l, entry),
                  const VSpace(Space.xxs),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(AppLocalizations l, HistoryEntry entry) {
    final reversible = entry.state == HistoryEntryState.reversible;
    return SelectRow(
      name: _label(l, entry.commandType),
      line: _when(entry.committedAtMs),
      chevron: false,
      trailing: reversible
          ? AppButton(
              label: l.historyUndo,
              variant: AppButtonVariant.ghost,
              compact: true,
              fullWidth: false,
              onPressed: _running.contains(entry.operationId)
                  ? null
                  : () => _undo(entry),
            )
          : Text(
              entry.state == HistoryEntryState.reversed
                  ? l.historyReversed
                  : l.historyChange,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
      semanticLabel:
          '${_label(l, entry.commandType)}, ${_when(entry.committedAtMs)}',
    );
  }

  static String _label(AppLocalizations l, String commandType) =>
      switch (commandType) {
        'payment.create' => l.historyPaymentAdded,
        'payment.edit' => l.historyPaymentChanged,
        'payment.delete' || 'payment.undo' => l.historyPaymentDeleted,
        'transfer.create' || 'transfer.undo' => l.historyTransferAdded,
        'inbox.confirm' => l.historyInboxConfirmed,
        'budget.saveLimits' => l.historyLimitsSaved,
        'schedule.create' || 'schedule.stop' => l.historyScheduleChanged,
        'categoryRule.create' => l.historyRuleCreated,
        _ => l.historyChange,
      };

  static String _when(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.day} ${_months[date.month - 1]} ${date.year}, '
        '${two(date.hour)}:${two(date.minute)}';
  }

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
