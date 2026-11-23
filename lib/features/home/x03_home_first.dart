import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/hide_amounts_button.dart';
import '../../core/dates.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// SPEC 6.1 X03: Home, first run. Hero shows an em dash with the "add your
/// main account" line; Get started 0 of 5; Next 30 days with none recorded.
///
/// G01 is decided (DECISIONS CLOSED-G01-ACCOUNT-PREREQUISITES,
/// 2026-11-22): the Get started rows are valid against the decided anchor;
/// the final F01 acceptance and the account-setup feature land in Phase 2.
class X03HomeFirstRun extends StatelessWidget {
  const X03HomeFirstRun({
    this.onSpending,
    this.onAddPayment,
    this.today,
    super.key,
  });

  /// The date line date. Null reads the local clock at the app boundary; a
  /// golden passes a fixed date.
  final LocalDate? today;

  /// Demo composition only: opens Spending. Null keeps the product screen
  /// unchanged (the tab bar owns this entry, P18-SHELL-MOUNT).
  final VoidCallback? onSpending;

  /// Demo composition only: opens the Add form.
  final VoidCallback? onAddPayment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TabRootScreen(
      header: ScreenHeader(
        title: l.x03Today,
        dateLine: l.x03DateLine(
          formatDate(
            today ?? _localToday(),
            DateStyle.long,
          ),
          'USD',
        ),
        actions: [
          AppIconButton(
            icon: AppIcons.inbox,
            variant: AppIconButtonVariant.onPage,
            semanticLabel: l.x03InboxAction,
            onPressed: () => GoRouter.of(context).push('/x60'),
          ),
          const HideAmountsButton(),
          AppIconButton(
            icon: AppIcons.settings,
            variant: AppIconButtonVariant.onPage,
            semanticLabel: l.x03SettingsAction,
            onPressed: () {
              // The real Home opens Settings through the routed navigation
              // (F02, Phase 2). Prototype affordance, debug builds only:
              // walk to the X80 skeleton. No state changes.
              if (kDebugMode) {
                GoRouter.of(context).go('/x80');
              }
            },
          ),
        ],
      ),
      children: [
        ObHero(
          kicker: l.x03HeroKicker,
          value: ValueSpec.notAvailable(l.x03HeroDash),
          contextLine: l.x03HeroLine,
        ),
        if (onSpending != null || onAddPayment != null)
          GlassCard(
            title: l.demoGoTo,
            child: Column(
              children: [
                if (onSpending != null)
                  SelectRow(
                    name: l.demoSpending,
                    onTap: onSpending,
                    semanticLabel: l.demoSpending,
                  ),
                if (onAddPayment != null)
                  SelectRow(
                    name: l.demoAddPayment,
                    leading: const IconTile(icon: AppIcons.receipt),
                    onTap: onAddPayment,
                    semanticLabel: l.demoAddPayment,
                  ),
              ],
            ),
          ),
        GlassCard(
          title: l.x03GetStartedTitle,
          meta: l.x03GetStartedMeta,
          child: Column(
            children: [
              CapsuleMeter(
                value: 0,
                limit: 5,
                spokenLabel: l.x03GetStartedSpoken,
              ),
              const VSpace(Space.m),
              SelectRow(
                name: l.x03Step1,
                line: l.x03Step1Line,
                semanticLabel: l.x03Step1,
                onTap: () => GoRouter.of(context).push('/x42b'),
              ),
              SelectRow(
                name: l.x03Step2,
                line: l.x03Step2Line,
                semanticLabel: l.x03Step2,
                onTap: () => GoRouter.of(context).push('/x63'),
              ),
              SelectRow(
                name: l.x03Step3,
                line: l.x03Step3Line,
                semanticLabel: l.x03Step3,
              ),
              SelectRow(
                name: l.x03Step4,
                line: l.x03Step4Line,
                semanticLabel: l.x03Step4,
              ),
              SelectRow(
                name: l.x03Step5,
                line: l.x03Step5Line,
                semanticLabel: l.x03Step5,
              ),
              Text(
                l.x03StepsCaption,
                style: AppText.caption.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          title: l.x03Next30Title,
          meta: l.x03Next30Meta,
          child: Text(
            l.x03Next30Line,
            style: AppText.caption.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
