// P3-25 (SCREENS X63, X64, X65, X66, X68, X88; flow F06): the import flow.
//
// One route hosts the five steps, so the chosen file and its parsed rows stay
// in one controller. The flow reads the PDF on this phone, shows the parsed
// rows and sends drafts to the Inbox. It writes no payment.
library;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../features/accounts/account_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../accounts/account_picker_sheet.dart';
import 'import_controller.dart';
import 'import_models.dart';
import 'x63_import_hub.dart';
import 'x65_import_preview.dart';
import 'x66_teach_once.dart';
import 'x68_import_done.dart';
import 'x88_import_error.dart';

/// X63 and its steps.
class X63Import extends StatefulWidget {
  const X63Import({
    required this.gateway,
    required this.intake,
    required this.accounts,
    required this.onClose,
    required this.onOpenInbox,
    this.controller,
    super.key,
  });

  final ImportGateway gateway;
  final ImportFileIntake intake;
  final AccountsGateway accounts;
  final VoidCallback onClose;
  final VoidCallback onOpenInbox;
  final ImportController? controller;

  @override
  State<X63Import> createState() => _X63ImportState();
}

class _X63ImportState extends State<X63Import> {
  late final ImportController _controller = widget.controller ??
      ImportController(gateway: widget.gateway, intake: widget.intake);

  final TextEditingController _password = TextEditingController();
  List<AccountSummary> _accounts = const <AccountSummary>[];
  AccountSummary? _account;
  bool _dialogOpen = false;
  bool _teaching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onController);
    _controller.load();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.accounts.listAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _account = accounts.isEmpty ? null : accounts.first;
      });
    } on AccountsError {
      // The picker states the reason; the import still reads the file.
    }
  }

  void _onController() {
    if (!mounted) return;
    if (_controller.step == ImportStep.password && !_dialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPassword());
    }
    if (_controller.step == ImportStep.preview && _teaching) {
      setState(() => _teaching = false);
    }
    if (_controller.step == ImportStep.failed) {
      setState(() => _teaching = false);
    }
  }

  Future<void> _openPassword() async {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    final l = AppLocalizations.of(context);
    final wrong = _controller.passwordError != null;
    final confirmed = await showAppDialog<bool>(
      context,
      leading: const IconTile(icon: AppIcons.lock),
      title: l.importPasswordTitle,
      body: wrong ? l.importPasswordWrong : l.importPasswordBody,
      primaryLabel: l.importPasswordOpen,
      secondaryLabel: l.importCancel,
      semanticLabel: l.importPasswordTitle,
      barrierDismissible: false,
      onPrimary: () => Navigator.of(context).pop(true),
      onSecondary: () => Navigator.of(context).pop(false),
      child: AppField(
        label: l.importPasswordField,
        semanticLabel: l.importPasswordField,
        controller: _password,
        obscureText: true,
        autofocus: true,
        onSubmitted: (_) => Navigator.of(context).maybePop(),
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (confirmed == true) {
      await _controller.submitPassword(_password.text);
      _password.clear();
      if (!mounted) return;
      if (_controller.step == ImportStep.password) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openPassword());
      }
    } else {
      _controller.cancelPassword();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickAccount() async {
    final picked = await showAccountPicker(
      context,
      accounts: _accounts,
      onAdd: null,
    );
    if (picked != null && mounted) {
      setState(() => _account = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        if (_teaching) {
          return X66TeachOnce(
            controller: _controller,
            onClose: () => setState(() => _teaching = false),
          );
        }
        switch (_controller.step) {
          case ImportStep.preview:
            return X65ImportPreview(
              controller: _controller,
              account: _account,
              accounts: _accounts,
              onAccount: () => _pickAccount(),
              onClose: widget.onClose,
              onTeach: () => setState(() => _teaching = true),
            );
          case ImportStep.done:
            return X68ImportDone(
              controller: _controller,
              onOpenInbox: widget.onOpenInbox,
              onClose: widget.onClose,
            );
          case ImportStep.failed:
            return X88ImportError(
              controller: _controller,
              onChoose: _controller.chooseFile,
              onTeach: () => setState(() => _teaching = true),
              onClose: widget.onClose,
            );
          case ImportStep.idle:
          case ImportStep.reading:
          case ImportStep.password:
          case ImportStep.sending:
            return X63ImportHub(
              controller: _controller,
              onClose: widget.onClose,
              onChoose: _controller.chooseFile,
              onOpenBatch: _controller.openBatch,
            );
        }
      },
    );
  }
}
