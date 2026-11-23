// P27 (SCREENS X39, X39b; flow F08 step 4; SPEC 8.18): one payment.
//
// Delete opens X39b and confirm soft-deletes the event, the payment and its
// splits in one command (F08-B, F08-C). The caller shows the 5 s toast with
// Undo. The expectation toggles of the reference need P07 storage and stay out
// of this task (P27-EXPECTATION-TOGGLES).
library;

import 'package:flutter/material.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/money.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import 'payments_controller.dart';
import 'payments_models.dart';
import 'x39b_delete_dialog.dart';

/// X39: hero, fields, split and the delete action.
class X39PaymentDetail extends StatefulWidget {
  const X39PaymentDetail({
    required this.gateway,
    required this.paymentId,
    required this.onClose,
    required this.onDeleted,
    this.controller,
    super.key,
  });

  final PaymentsReadGateway gateway;
  final String paymentId;
  final VoidCallback onClose;

  /// Returns the committed delete to the caller for the toast and Undo.
  final ValueChanged<DeletedPayment> onDeleted;
  final PaymentDetailController? controller;

  @override
  State<X39PaymentDetail> createState() => _X39PaymentDetailState();
}

class _X39PaymentDetailState extends State<X39PaymentDetail> {
  late final PaymentDetailController _controller = widget.controller ??
      PaymentDetailController(
        gateway: widget.gateway,
        paymentId: widget.paymentId,
      );

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
        final view = _controller.view;
        return DetailScreen(
          header: ScreenHeader(
            title: l.paymentsDetailTitle,
            dateLine: view?.merchantName,
            leading: AppIconButton(
              icon: AppIcons.back,
              semanticLabel: l.paymentsBack,
              onPressed: widget.onClose,
            ),
            actions: const <Widget>[HideAmountsButton()],
          ),
          children: <Widget>[
            if (_controller.state == PaymentsViewState.loading)
              Text(l.spendingLoading, style: AppText.caption)
            else if (view == null) ...<Widget>[
              Text(l.spendingLoadFailed, style: AppText.bodyStrong),
            ] else ...<Widget>[
              _hero(l, view),
              _fields(l, view),
              if (view.splits.isNotEmpty) _split(l, view),
              if (_controller.errorCode == PaymentsReadErrorCode.deleteFailed)
                Text(
                  l.paymentsDeleteFailed,
                  style: AppText.caption.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              AppButton(
                label: l.paymentsDelete,
                variant: AppButtonVariant.ghost,
                icon: AppIcons.trash,
                onPressed: () => _delete(l, view),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _hero(AppLocalizations l, PaymentDetailView view) {
    final amount = Money.fromMinor(
      view.amountMinor,
      Currency.of(view.currencyCode),
    );
    return ObHero(
      kicker: l.paymentsDetailKicker(
        formatDate(view.date, DateStyle.monthYear),
      ),
      value: ValueSpec.real(amount),
      contextLine: l.paymentsDetailLine(
        view.merchantName ?? l.paymentsPaymentFallback,
        view.accountName,
      ),
      hiddenContextLine: null,
    );
  }

  Widget _fields(AppLocalizations l, PaymentDetailView view) {
    final category = view.splits.isNotEmpty
        ? l.paymentsSplitInto(view.splits.length)
        : view.categoryName ?? l.paymentsNoCategory;
    return GlassCard(
      child: Column(
        children: <Widget>[
          SelectRow(
            name: l.paymentsFieldCategory,
            value: category,
            chevron: false,
          ),
          SelectRow(
            name: l.paymentsFieldAccount,
            value: view.accountName,
            chevron: false,
          ),
          SelectRow(
            name: l.paymentsFieldTags,
            value: view.tags.isEmpty ? l.paymentsNone : view.tags.join(', '),
            chevron: false,
          ),
          if (view.note != null && view.note!.isNotEmpty)
            SelectRow(
              name: l.paymentsFieldNote,
              value: view.note!,
              chevron: false,
            ),
        ],
      ),
    );
  }

  Widget _split(AppLocalizations l, PaymentDetailView view) {
    final currency = Currency.of(view.currencyCode);
    return GlassCard(
      variant: GlassCardVariant.stage,
      title: l.paymentsSplitTitle,
      meta: l.paymentsSplitMeta(view.splits.length),
      child: SplitBar(
        title: l.paymentsSplitTitle,
        period: formatDate(view.date, DateStyle.monthYear),
        parts: <SplitBarPart>[
          for (final split in view.splits)
            SplitBarPart(
              name: split.categoryName.isEmpty
                  ? l.paymentsUncategorised
                  : split.categoryName,
              amount: Money.fromMinor(split.amountMinor.abs(), currency),
              mark: ChartMark.neutral,
            ),
        ],
        columns: <String>[
          l.paymentsFieldCategory,
          l.spendingChartAmountColumn,
          l.paymentsSplitTitle,
        ],
      ),
    );
  }

  Future<void> _delete(AppLocalizations l, PaymentDetailView view) async {
    final amount = Money.fromMinor(
      view.amountMinor.abs(),
      Currency.of(view.currencyCode),
    );
    final confirmed = await showDeletePaymentDialog(
      context,
      name: view.merchantName ?? l.paymentsPaymentFallback,
      amount: formatMoney(amount),
      date: formatDate(view.date, DateStyle.short),
    );
    if (!confirmed || !mounted) {
      return;
    }
    final deleted = await _controller.delete();
    if (deleted == null || !mounted) {
      return;
    }
    widget.onDeleted(deleted);
  }
}
