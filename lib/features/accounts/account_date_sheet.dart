// P21 (SPEC 6.6; flow C01): the inclusive balance-date sheet.
//
// Day, month and year are three number fields. The sheet validates a real
// calendar date and returns it; the controller stores a `LocalDate`, so no
// text reaches the data layer.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/dates.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opens the date sheet and returns the chosen date, or null on dismiss.
///
/// [title] overrides the sheet title for a caller outside C01 (X26 uses
/// "Date"). The spoken name follows the same label.
Future<LocalDate?> showAccountDateSheet(
  BuildContext context, {
  required LocalDate initial,
  String? title,
  String? semanticLabel,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<LocalDate>(
    context,
    title: title ?? l.accountDateTitle,
    semanticLabel: semanticLabel ?? title ?? l.accountDateSpoken,
    children: <Widget>[AccountDateSheet(initial: initial)],
  );
}

/// The sheet content. It is public so a golden can render it directly.
class AccountDateSheet extends StatefulWidget {
  const AccountDateSheet({required this.initial, super.key});

  final LocalDate initial;

  @override
  State<AccountDateSheet> createState() => _AccountDateSheetState();
}

class _AccountDateSheetState extends State<AccountDateSheet> {
  late final TextEditingController _day =
      TextEditingController(text: widget.initial.day.toString());
  late final TextEditingController _month =
      TextEditingController(text: widget.initial.month.toString());
  late final TextEditingController _year =
      TextEditingController(text: widget.initial.year.toString());
  bool _invalid = false;

  @override
  void dispose() {
    _day.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  LocalDate? _read() {
    final day = int.tryParse(_day.text.trim());
    final month = int.tryParse(_month.text.trim());
    final year = int.tryParse(_year.text.trim());
    if (day == null || month == null || year == null) {
      return null;
    }
    try {
      return LocalDate(year, month, day);
    } on ArgumentError {
      return null;
    }
  }

  void _submit() {
    final date = _read();
    if (date == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(date);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppField(
                label: l.accountDateDay,
                semanticLabel: l.accountDateDay,
                controller: _day,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _invalid = false),
              ),
            ),
            const HSpace(Space.m),
            Expanded(
              child: AppField(
                label: l.accountDateMonth,
                semanticLabel: l.accountDateMonth,
                controller: _month,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _invalid = false),
              ),
            ),
            const HSpace(Space.m),
            Expanded(
              flex: 2,
              child: AppField(
                label: l.accountDateYear,
                semanticLabel: l.accountDateYear,
                controller: _year,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _invalid = false),
              ),
            ),
          ],
        ),
        if (_invalid) ...<Widget>[
          const VSpace(Space.xs),
          Text(
            l.accountDateInvalid,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
        ],
        const VSpace(Space.l),
        AppButton(label: l.accountDateUse, onPressed: _submit),
      ],
    );
  }
}
