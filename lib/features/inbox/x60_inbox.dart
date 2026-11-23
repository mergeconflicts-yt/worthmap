// P25 (SCREENS X60, X62; flow F07 steps 1–5; SPEC 5.5): the Inbox list.
//
// The screen reads one controller. It never writes: a decision stages, and the
// confirm bar calls `ConfirmInboxBatch`. Uncertainty stays unticked (F07-A) and
// the label reads the exact ticked count and total (F07-B).
library;

import 'package:flutter/material.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'inbox_controller.dart';
import 'inbox_models.dart';
import 'x61_item_sheet.dart';

/// X60: header, hero, decision card, ready rows and the confirm bar.
class X60Inbox extends StatefulWidget {
  const X60Inbox({
    required this.gateway,
    required this.onClose,
    this.controller,
    this.showToast = true,
    super.key,
  });

  final InboxGateway gateway;
  final VoidCallback onClose;

  /// Test and golden seam: a prepared controller. The caller owns it.
  final InboxController? controller;
  final bool showToast;

  @override
  State<X60Inbox> createState() => _X60InboxState();
}

class _X60InboxState extends State<X60Inbox> {
  late final InboxController _controller =
      widget.controller ?? InboxController(gateway: widget.gateway);

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final empty = _controller.state == InboxViewState.ready &&
            _controller.pendingCount == 0;
        return DetailScreen(
          header: ScreenHeader(
            title: l.inboxTitle,
            dateLine: empty
                ? l.inboxEmptySubline
                : l.inboxSubline(_controller.pendingCount),
            leading: AppIconButton(
              icon: AppIcons.back,
              semanticLabel: l.inboxBack,
              onPressed: widget.onClose,
            ),
            actions: const <Widget>[HideAmountsButton()],
          ),
          children: empty ? _empty(l) : _populated(l),
        );
      },
    );
  }

  List<Widget> _empty(AppLocalizations l) => <Widget>[
        ObHero(
          kicker: l.inboxEmptyKicker,
          value: ValueSpec.real(Money.zero(Currency.usd)),
          contextLine: l.inboxEmptyLine,
        ),
        GlassCard(
          child: Column(
            children: <Widget>[
              const IconTile(icon: AppIcons.check),
              const VSpace(Space.m),
              Text(l.inboxEmptyTitle, style: AppText.bodyStrong),
              const VSpace(Space.xxs),
              Text(
                l.inboxEmptyBody,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ];

  List<Widget> _populated(AppLocalizations l) {
    final totals = _controller.totals;
    final money = totals == null
        ? null
        : Money.fromMinor(
            totals.netMinor.abs(),
            Currency.of(totals.currencyCode),
          );
    return <Widget>[
      ObHero(
        kicker: l.inboxHeroKicker,
        value: money == null
            ? ValueSpec.missing(l.inboxNoTotal)
            : ValueSpec.real(money),
        contextLine: _controller.decision != null
            ? l.inboxDecisionLine(
                _controller.tickedCount,
                _controller.pendingCount,
              )
            : l.inboxReadyLine(
                _controller.tickedCount,
                _controller.pendingCount,
              ),
      ),
      if (_controller.decisionOpen) _decisionCard(l),
      _readyCard(l),
      _confirmAction(l),
    ];
  }

  Widget _decisionCard(AppLocalizations l) {
    final decision = _controller.decision!;
    final amount = Money.fromMinor(
      decision.amountMinor.abs(),
      Currency.of(decision.currencyCode),
    );
    final date = formatDate(decision.date, DateStyle.short);
    return GlassCard(
      variant: GlassCardVariant.stage,
      title: l.inboxDecisionTitle,
      meta: l.inboxDecisionMeta(
        1,
        _controller.rows.where((row) => row.needsDecision).length,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.inboxDecisionQuestion, style: AppText.bodyStrong),
          const VSpace(Space.m),
          SelectRow(
            name: decision.fromName,
            line: l.inboxDecisionFrom(date),
            trailing: MoneyText(
              ValueSpec.real(-amount),
              style: AppText.numberXS,
            ),
            chevron: false,
          ),
          const VSpace(Space.xxs),
          SelectRow(
            name: decision.toName,
            line: l.inboxDecisionTo(date),
            trailing: MoneyText(
              ValueSpec.real(amount),
              style: AppText.numberXS,
            ),
            chevron: false,
          ),
          const VSpace(Space.m),
          Text(
            l.inboxDecisionCaption,
            style: AppText.caption.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const VSpace(Space.m),
          AppButton(
            label: l.inboxDecisionYes,
            onPressed: () => _controller.decide(true),
          ),
          const VSpace(Space.s),
          AppButton(
            label: l.inboxDecisionNo,
            variant: AppButtonVariant.ghost,
            onPressed: () => _controller.decide(false),
          ),
        ],
      ),
    );
  }

  Widget _readyCard(AppLocalizations l) {
    final rows = _controller.rows;
    return GlassCard(
      title: l.inboxReadyTitle,
      meta: l.inboxReadyMeta(_controller.tickedCount),
      child: Column(
        children: <Widget>[
          for (final row in rows)
            if (!(_controller.decisionOpen &&
                _controller.decision!.itemId == row.id)) ...<Widget>[
              _row(l, row),
              const VSpace(Space.xxs),
            ],
          if (rows.isEmpty)
            Text(
              l.inboxNoneRecorded,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(AppLocalizations l, InboxRow row) {
    final money =
        Money.fromMinor(row.amountMinor.abs(), Currency.of(row.currencyCode));
    final checked = _controller.ticked.contains(row.id);
    final category = row.categoryName == null
        ? l.inboxCategoryMissing
        : row.isUnsure
            ? l.inboxCategoryUnsure(row.categoryName!)
            : row.categoryName!;
    return SelectRow(
      leading: AppCheckbox(
        value: checked,
        onChanged: row.isUnsure || row.needsDecision
            ? null
            : (_) => _controller.toggle(row.id),
        semanticLabel: l.inboxRowCheckSpoken(
          row.title.isEmpty ? l.inboxPaymentFallback : row.title,
        ),
      ),
      name: row.title.isEmpty ? l.inboxPaymentFallback : row.title,
      line: l.inboxRowLine(formatDate(row.date, DateStyle.short), category),
      trailing: MoneyText(
        ValueSpec.real(money),
        style: AppText.numberXS,
      ),
      onTap: () => _openItem(l, row),
      semanticLabel: l.inboxRowSpoken(
        row.title.isEmpty ? l.inboxPaymentFallback : row.title,
        formatMoney(money),
      ),
    );
  }

  Widget _confirmAction(AppLocalizations l) {
    final totals = _controller.totals;
    final label = totals == null
        ? l.inboxConfirmEmpty
        : l.inboxConfirm(
            totals.count,
            formatMoney(
              Money.fromMinor(
                totals.netMinor.abs(),
                Currency.of(totals.currencyCode),
              ),
            ),
          );
    if (_controller.decisionOpen) {
      // SPEC 5.5: while a decision is open its affirmative choice owns the
      // filled action; Confirm stays ghost.
      return AppButton(
        label: label,
        variant: AppButtonVariant.ghost,
        onPressed: null,
      );
    }
    return ConfirmBar(
      label: label,
      onPressed: _controller.canConfirm ? _confirm : null,
    );
  }

  Future<void> _openItem(AppLocalizations l, InboxRow row) async {
    await showInboxItemSheet(
      context,
      row: row,
      onConfirm: () => _confirmOne(row),
      onDelete: () => _controller.deleteRow(row),
    );
  }

  Future<void> _confirmOne(InboxRow row) async {
    final confirmation = await _controller.gateway.confirm(<int>{row.id});
    if (!mounted) {
      return;
    }
    await _controller.load();
    _showUndo(confirmation);
  }

  Future<void> _confirm() async {
    final confirmation = await _controller.confirm();
    if (confirmation == null || !mounted) {
      return;
    }
    _showUndo(confirmation);
  }

  void _showUndo(InboxConfirmation confirmation) {
    if (!widget.showToast) {
      return;
    }
    final l = AppLocalizations.of(context);
    showAppToast(
      context,
      message: l.inboxConfirmedToast(confirmation.count),
      undoLabel: l.inboxUndo,
      onUndo: () => _controller.undo(confirmation),
    );
  }
}
