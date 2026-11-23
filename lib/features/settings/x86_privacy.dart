import 'package:flutter/widgets.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// SPEC 6.1 X86 (base): Privacy and network. Network off, the Delete-all
/// entry with its caption. No real data values (Phase 1: no vault size yet).
///
/// DECISION-PENDING: G14/T11. The Delete-all intent plumbing and its
/// confirm flow are T11; this screen ships the destructive confirm entry
/// only.
class X86Privacy extends StatelessWidget {
  const X86Privacy({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    return DetailScreen(
      header: ScreenHeader(
        title: l.x86Title,
        dateLine: l.x86SubLine,
        leading: AppIconButton(
          icon: AppIcons.back,
          variant: AppIconButtonVariant.onPage,
          semanticLabel: l.x80Back,
        ),
      ),
      children: [
        // Hero without number: kicker, statement, context line.
        Text(
          l.x86HeroKicker,
          style: AppText.labelCaps.copyWith(color: role.text),
        ),
        const VSpace(Space.s),
        Text(l.x86HeroLine, style: AppText.titleScreen),
        const VSpace(Space.s),
        Text(
          l.x86HeroContext,
          style: AppText.line.copyWith(color: tokens.textSecondary),
        ),
        const VSpace(Space.xl),
        GlassCard(
          title: l.x86NetworkTitle,
          meta: l.x86NetworkMeta,
          child: Column(
            children: [
              SelectRow(
                name: l.x86PriceService,
                line: l.x86PriceServiceLine,
                chevron: false,
              ),
              ToggleRow(
                name: l.x86TurnOff,
                description: l.x86TurnOffLine,
                value: false,
                onChanged: (value) {
                  // Phase 1: the gateway is off by default and not wired to
                  // this toggle yet (T11 owns the off gate and its confirm).
                },
                semanticLabel: l.x86TurnOffSpoken,
              ),
            ],
          ),
        ),
        GlassCard(
          title: l.x86OnPhoneTitle,
          child: Column(
            children: [
              SelectRow(
                name: l.x86Database,
                value: l.x86DatabaseValue,
                chevron: false,
              ),
              SelectRow(
                name: l.x86Speech,
                value: l.x86OnPhoneValue,
                chevron: false,
              ),
              SelectRow(
                name: l.x86TextRecognition,
                value: l.x86OnPhoneValue,
                chevron: false,
              ),
              SelectRow(
                name: l.x86RecoverySnapshots,
                value: l.x86OnPhoneValue,
                chevron: false,
              ),
            ],
          ),
        ),
        AppButton(
          label: l.x86DeleteAll,
          variant: AppButtonVariant.destructive,
          onPressed: () {
            // DECISION-PENDING: T11. Destructive confirm UI only in
            // Phase 1; the intent plumbing lands with T11.
          },
        ),
        const VSpace(Space.s),
        Text(
          l.x86DeleteAllCaption,
          style: AppText.caption.copyWith(color: tokens.textSecondary),
        ),
      ],
    );
  }
}
