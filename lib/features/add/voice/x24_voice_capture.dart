// P24 (SCREENS X24, X25; SPEC 8.19; flows F04 steps 1–3): the voice screen.
//
// One route holds the two states of the reference: X24 while the microphone is
// open, X25 when the transcript is final and the form is filled. The screen
// never writes before Save (F04-C) and never stores audio. A denial or an
// absent on-device engine keeps typed entry (F04-B).
//
// X25 saves through the same P22 payment controller and gateway, so the commit
// boundary stays `SavePayment` and Undo works the same way (SPEC 8.18). When a
// required field is still missing, the primary action returns the transcript to
// X20, which fills its own form; nothing is written.
library;

import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../data/speech/speech.dart';
import '../../../design/design.dart';
import '../../../domain/importers/quick_add_parser.dart' show DraftField;
import '../../../l10n/generated/app_localizations.dart';
import '../../accounts/account_models.dart';
import '../payment_draft.dart';
import '../payment_form_controller.dart';
import '../payment_models.dart';
import 'voice_controller.dart';
import 'x87_permission.dart';

/// X24 (listening) and X25 (filled) in one FormScreen.
class X24VoiceCapture extends StatefulWidget {
  const X24VoiceCapture({
    required this.gateway,
    required this.speech,
    required this.onClose,
    required this.onSaved,
    required this.onContinueWithForm,
    this.today,
    this.drafts,
    this.voice,
    this.payment,
    this.showToast = true,
    super.key,
  });

  /// The payment port. Save is the same `SavePayment` as X20.
  final PaymentsGateway gateway;

  /// The on-device speech port.
  final SpeechPort speech;

  /// Close: stops recognition, clears the transcript, writes nothing.
  final VoidCallback onClose;

  /// Save success: returns to the caller with the confirmed payment.
  final ValueChanged<SavedPayment> onSaved;

  /// The transcript goes to X20 when the form still needs a required field.
  final ValueChanged<String> onContinueWithForm;

  final LocalDate? today;
  final PaymentDraftStore? drafts;

  /// Test and golden seam: prepared controllers. The caller owns them.
  final VoiceController? voice;
  final PaymentFormController? payment;

  final bool showToast;

  @override
  State<X24VoiceCapture> createState() => _X24VoiceCaptureState();
}

class _X24VoiceCaptureState extends State<X24VoiceCapture> {
  late final LocalDate _today = widget.today ?? _localToday();
  late final VoiceController _voice =
      widget.voice ?? VoiceController(port: widget.speech);
  late final PaymentFormController _payment = widget.payment ??
      PaymentFormController(
        gateway: widget.gateway,
        today: _today,
        drafts: widget.drafts,
      );
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _payment.initialize();
    await _voice.initialize();
    if (!mounted) {
      return;
    }
    await _maybeExplainPermission();
  }

  /// X87 shows once before the system prompt.
  Future<void> _maybeExplainPermission() async {
    if (_asked || _voice.stage != VoiceStage.permission) {
      return;
    }
    _asked = true;
    final allowed = await showMicrophonePermission(context);
    if (!mounted) {
      return;
    }
    if (allowed) {
      await _voice.requestPermission();
    } else {
      _voice.declinePermission();
    }
  }

  @override
  void dispose() {
    if (widget.voice == null) {
      _voice.dispose();
    }
    if (widget.payment == null) {
      _payment.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_voice, _payment]),
      builder: (BuildContext context, _) {
        final stage = _voice.stage;
        return FormScreen(
          close: AppIconButton(
            icon: AppIcons.close,
            semanticLabel: l.voiceClose,
            onPressed: _close,
          ),
          primaryAction: _primaryAction(l, stage),
          children: <Widget>[
            SegmentedControl(
              segments: <String>[l.paymentTypeExpense, l.paymentTypeIncome],
              selectedIndex: _payment.kind == PaymentKind.income ? 1 : 0,
              semanticLabel: l.paymentTypeLabel,
              onChanged: (index) => _payment.setKind(
                index == 0 ? PaymentKind.expense : PaymentKind.income,
              ),
            ),
            ...switch (stage) {
              VoiceStage.listening => _listening(l),
              VoiceStage.filled => _filled(l),
              VoiceStage.failed => _failed(l),
              VoiceStage.denied => _unavailable(
                  l.voiceDeniedTitle,
                  l.voiceDeniedBody,
                ),
              VoiceStage.unavailable => _unavailable(
                  l.voiceUnavailableTitle,
                  l.voiceUnavailableBody,
                ),
              VoiceStage.permission || VoiceStage.checking => <Widget>[
                  Text(l.voiceChecking, style: AppText.caption),
                ],
            },
          ],
        );
      },
    );
  }

  Widget _primaryAction(AppLocalizations l, VoiceStage stage) {
    if (stage == VoiceStage.filled) {
      return Row(
        children: <Widget>[
          Expanded(
            child: AppButton(
              label: l.voiceSpeakAgain,
              variant: AppButtonVariant.ghost,
              fullWidth: false,
              onPressed: _speakAgain,
            ),
          ),
          const HSpace(Space.s),
          Expanded(
            child: AppButton(
              label: _payment.canSave
                  ? l.voiceSaveWithAmount(_amountLabel(context))
                  : l.voiceContinueInForm,
              fullWidth: false,
              onPressed: _saveOrContinue,
            ),
          ),
        ],
      );
    }
    return AppButton(
      label: l.voiceTypeInstead,
      variant: AppButtonVariant.ghost,
      onPressed: _close,
    );
  }

  List<Widget> _listening(AppLocalizations l) {
    final tokens = context.tokens;
    return <Widget>[
      GlassCard(
        variant: GlassCardVariant.stage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l.voiceListeningTitle,
                    style: AppText.bodyStrong,
                  ),
                ),
                AppButton(
                  label: l.voiceStop,
                  variant: AppButtonVariant.ghost,
                  fullWidth: false,
                  compact: true,
                  onPressed: _stop,
                ),
              ],
            ),
            const VSpace(Space.m),
            Text(
              _voice.transcript.isEmpty
                  ? l.voiceListeningEmpty
                  : _voice.transcript,
              style: AppText.titleSection.copyWith(
                color: _voice.transcript.isEmpty
                    ? tokens.textSecondary
                    : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
      Text(
        l.voiceListeningCaption,
        style: AppText.caption.copyWith(color: tokens.textSecondary),
      ),
      AmountInput(
        value: null,
        emptyText: formatMoney(Money.zero(_payment.currency)),
        emptySemanticLabel: l.paymentAmountNotFilled,
      ),
    ];
  }

  List<Widget> _filled(AppLocalizations l) {
    final tokens = context.tokens;
    final unsure = _payment.unsureFields;
    final filledCount = <String>{
      if (_payment.enteredAmount != null) 'amount',
      if (_payment.merchantText.isNotEmpty) 'merchant',
      if (_payment.category != null) 'category',
      'date',
    }.length;
    return <Widget>[
      Text(
        l.voiceFilledKicker.toUpperCase(),
        style: AppText.labelCaps.copyWith(
          color: tokens.role(context.section).text,
        ),
        semanticsLabel: l.voiceFilledKicker,
      ),
      GlassCard(
        variant: GlassCardVariant.stage,
        title: l.voiceYouSaid,
        meta: l.voiceOnThisPhone,
        child: Text(
          _voice.transcript,
          style: AppText.titleSection,
        ),
      ),
      GlassCard(
        title: l.voiceForm,
        meta: l.voiceFilledMeta(filledCount, unsure.length),
        child: Column(
          children: <Widget>[
            _reviewRow(
              l.voiceRowAmount,
              _amountLabel(context),
              check: unsure.contains(DraftField.amount),
            ),
            const VSpace(Space.xxs),
            _reviewRow(
              l.voiceRowWhere,
              _payment.merchantText.isEmpty
                  ? l.voiceNoneRecorded
                  : _payment.merchantText,
              check: unsure.contains(DraftField.merchant),
            ),
            const VSpace(Space.xxs),
            _reviewRow(
              l.voiceRowCategory,
              _payment.category?.name ?? l.paymentAllCategories,
              check: unsure.contains(DraftField.category),
            ),
            const VSpace(Space.xxs),
            _reviewRow(
              l.voiceRowDate,
              _dateLabel(l),
              check: unsure.contains(DraftField.date),
            ),
            const VSpace(Space.xxs),
            _reviewRow(
              l.voiceRowPaidWith,
              _accountLabel(l),
              check: unsure.contains(DraftField.account),
            ),
          ],
        ),
      ),
      Text(
        l.voiceReviewCaption,
        style: AppText.caption.copyWith(color: tokens.textSecondary),
      ),
      if (!_payment.canSave)
        Text(
          l.voiceChooseAccount,
          style: AppText.caption.copyWith(color: tokens.textSecondary),
        ),
    ];
  }

  Widget _reviewRow(String name, String value, {required bool check}) {
    return SelectRow(
      name: name,
      value: value,
      chevron: false,
      line: check ? AppLocalizations.of(context).voiceCheckThis : null,
      semanticLabel: check
          ? AppLocalizations.of(context).voiceRowSpokenCheck(name, value)
          : AppLocalizations.of(context).voiceRowSpoken(name, value),
    );
  }

  List<Widget> _failed(AppLocalizations l) => <Widget>[
        Text(l.voiceNoSpeech, style: AppText.bodyStrong),
        AppButton(
          label: l.voiceSpeakAgain,
          variant: AppButtonVariant.soft,
          onPressed: _speakAgain,
        ),
      ];

  List<Widget> _unavailable(String title, String body) {
    final tokens = context.tokens;
    return <Widget>[
      Text(title, style: AppText.bodyStrong),
      Text(
        body,
        style: AppText.caption.copyWith(color: tokens.textSecondary),
      ),
    ];
  }

  String _amountLabel(BuildContext context) {
    final amount = _payment.enteredAmount;
    if (amount == null) {
      return AppLocalizations.of(context).voiceNoneRecorded;
    }
    if (HiddenAmountsScope.resolve(context, null)) {
      return hiddenMask;
    }
    return formatMoney(amount);
  }

  String _dateLabel(AppLocalizations l) {
    final date = _payment.date;
    if (date == _today) {
      return l.paymentDateToday;
    }
    return formatDate(date, DateStyle.short);
  }

  String _accountLabel(AppLocalizations l) {
    final account = _payment.account;
    if (account == null) {
      return l.voiceChooseAccountRow;
    }
    return account.kind == AccountKind.card
        ? l.voiceAccountCheck(account.name)
        : account.name;
  }

  Future<void> _stop() async {
    await _voice.stop();
    if (!mounted || _voice.stage != VoiceStage.filled) {
      return;
    }
    await _payment.parseSentence(_voice.transcript);
  }

  Future<void> _speakAgain() async {
    await _voice.speakAgain();
  }

  Future<void> _saveOrContinue() async {
    if (!_payment.canSave) {
      widget.onContinueWithForm(_voice.transcript);
      return;
    }
    final saved = await _payment.save();
    if (saved == null || !mounted) {
      return;
    }
    if (widget.showToast) {
      final l = AppLocalizations.of(context);
      showAppToast(
        context,
        message: l.paymentSavedToast,
        undoLabel: l.paymentUndo,
        onUndo: () async {
          try {
            await widget.gateway.undoPayment(saved);
          } on Object {
            // The record stays; the caller refreshes to its current state.
          }
        },
      );
    }
    widget.onSaved(saved);
  }

  Future<void> _close() async {
    await _voice.cancel();
    widget.onClose();
  }
}

LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
