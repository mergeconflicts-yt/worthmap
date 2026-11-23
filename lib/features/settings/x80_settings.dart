import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// SPEC 6.1 X80 (skeleton list): Settings. DetailScreen with Back, the
/// hero without number and the five cards. No export or sync control.
///
/// Phase 1 builds the skeleton list; the target screens (X81, X84, X63,
/// X40, X13, X83, X85) are later releases.
class X80Settings extends StatelessWidget {
  const X80Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    return DetailScreen(
      header: ScreenHeader(
        title: l.x80Title,
        dateLine: l.x80SubLine,
        leading: AppIconButton(
          icon: AppIcons.back,
          variant: AppIconButtonVariant.onPage,
          semanticLabel: l.x80Back,
        ),
      ),
      children: [
        // Hero without number: kicker, statement, context line.
        Text(
          l.x80HeroKicker,
          style: AppText.labelCaps.copyWith(color: role.text),
        ),
        const VSpace(Space.s),
        Text(l.x80HeroLine, style: AppText.titleScreen),
        const VSpace(Space.s),
        Text(
          l.x80HeroContext,
          style: AppText.line.copyWith(color: tokens.textSecondary),
        ),
        const VSpace(Space.xl),
        GlassCard(
          title: l.x80CardCapture,
          child: Column(
            children: [
              SelectRow(
                name: l.x80CaptureSources,
                value: l.x80CaptureSourcesValue,
              ),
              SelectRow(
                name: l.x80Categories,
                value: l.x80CategoriesValue,
                semanticLabel: l.x80Categories,
                onTap: () => GoRouter.of(context).push('/x84'),
              ),
              SelectRow(
                name: l.x80ImportLayouts,
                value: l.x80ImportLayoutsValue,
                semanticLabel: l.x80ImportLayouts,
                onTap: () => GoRouter.of(context).push('/x63'),
              ),
            ],
          ),
        ),
        GlassCard(
          title: l.x80CardMoney,
          child: Column(
            children: [
              SelectRow(
                name: l.x80MainCurrency,
                value: 'USD',
                chevron: false,
              ),
              SelectRow(name: l.x80Accounts, value: '9'),
              SelectRow(
                name: l.x80MonthStart,
                value: l.x80MonthStartValue,
                chevron: false,
              ),
              SelectRow(
                name: l.x80NumberFormat,
                value: l.x80NumberFormatValue,
                chevron: false,
              ),
            ],
          ),
        ),
        GlassCard(
          title: l.x80CardScreens,
          meta: l.x80ScreensMeta,
          child: Column(
            children: [
              SelectRow(
                name: l.x80MainNumberRow,
                value: l.x80MainNumberValue,
              ),
            ],
          ),
        ),
        GlassCard(
          title: l.x80AppCard,
          child: Column(
            children: [
              SelectRow(
                name: l.x80ActivityHistory,
                value: l.x80ActivityHistoryValue,
                semanticLabel: l.x80ActivityHistory,
                onTap: () => GoRouter.of(context).push('/c06'),
              ),
            ],
          ),
        ),
        GlassCard(
          title: l.x80CardSafety,
          child: Column(
            children: [
              SelectRow(name: l.x80AppLock, value: l.x80AppLockValue),
              SelectRow(name: l.x80Recovery, value: l.x80RecoveryValue),
              SelectRow(
                name: l.x80PrivacyRow,
                value: l.x80PrivacyValue,
                // The real Settings navigates to X86 (F02/SPEC 5.3, Phase 2).
                // Prototype affordance, debug builds only: walk to the X86
                // skeleton. No state changes.
                onTap:
                    kDebugMode ? () => GoRouter.of(context).go('/x86') : null,
                semanticLabel: kDebugMode ? l.x80PrivacySpoken : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
