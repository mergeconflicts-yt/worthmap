import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// SPEC 6.1 X01: the Welcome start screen. One required choice (the main
/// currency), Start. No tab bar, no header. No amounts.
///
/// G01 is decided (DECISIONS CLOSED-G01-ACCOUNT-PREREQUISITES,
/// 2026-11-22); the currency chooser sheet and the Start flow land with F01
/// acceptance in Phase 2.
class X01Welcome extends StatelessWidget {
  const X01Welcome({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    return PageBackground(
      child: ListView(
        padding: const EdgeInsets.only(
          top: Space.xxl,
          left: Space.page,
          right: Space.page,
          bottom: Space.xxl,
        ),
        children: [
          // Hero without number (DESIGN 6.7): kicker, title, line.
          Text(
            l.x01Kicker,
            style: AppText.labelCaps.copyWith(color: role.text),
          ),
          const VSpace(Space.s),
          Text(l.x01Title, style: AppText.titleScreen),
          const VSpace(Space.s),
          Text(
            l.x01Line,
            style: AppText.line.copyWith(color: tokens.textSecondary),
          ),
          const VSpace(Space.xl),
          const BrandMark(point: 64),
          const VSpace(Space.xl),
          GlassCard(
            child: Column(
              children: [
                SelectRow(
                  name: l.x01PhoneRowName,
                  line: l.x01PhoneRowLine,
                  chevron: false,
                  leading: const IconTile(icon: AppIcons.phone),
                ),
                SelectRow(
                  name: l.x01EyeRowName,
                  line: l.x01EyeRowLine,
                  chevron: false,
                  leading: const IconTile(icon: AppIcons.show),
                ),
                SelectRow(
                  name: l.x01ShieldRowName,
                  line: l.x01ShieldRowLine,
                  chevron: false,
                  leading: const IconTile(icon: AppIcons.shield),
                ),
              ],
            ),
          ),
          const VSpace(Space.card),
          GlassCard(
            title: l.x01CurrencyCardTitle,
            meta: l.x01CurrencyCardMeta,
            child: SelectRow(
              name: l.x01CurrencyName,
              line: l.x01CurrencyLine,
              value: 'USD',
              semanticLabel: l.x01CurrencySpoken,
              // DECISION-PENDING: T10-CURRENCY-CHOOSER. The chooser sheet is
              // part of the F01 flow; the row is informational until then.
            ),
          ),
          const VSpace(Space.card),
          AppButton(
            label: l.x01Start,
            onPressed: () {
              // The Start action completes the currency choice and opens the
              // first-run Home (X03). Built with F01 in Phase 2 against the
              // decided G01 anchor (DECISIONS CLOSED-G01-ACCOUNT-PREREQUISITES).
              //
              // Prototype affordance, debug builds only: jump to the
              // first-run Home skeleton so the Phase 1 screens can be walked
              // on a simulator. No settings commit happens; F01 owns the
              // real flow and removes this shim.
              if (kDebugMode) {
                GoRouter.of(context).go('/x03');
              }
            },
          ),
          const VSpace(Space.s),
          Text(
            l.x01Caption,
            style: AppText.caption.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}
