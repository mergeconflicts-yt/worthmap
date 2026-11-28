// P29 (SPEC 6.1 X80; SCREENS X80): Settings.
//
// DetailScreen with Back, the hero without a number and the five cards of the
// reference: Capture, Money, Screens and widgets, Safety and App. Every row
// has a grey icon tile. No export or sync control.
//
// The counts are the SCREENS X80 sample values until their reads are wired
// (P26-WIDGETS, P3-01). No row writes data.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// X80: Settings, five cards with icon rows.
class X80Settings extends StatelessWidget {
  const X80Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    Widget row({
      required AppIconData icon,
      required String name,
      String? line,
      String? value,
      String? semanticLabel,
      VoidCallback? onTap,
    }) {
      return SelectRow(
        leading: IconTile(
          icon: icon,
          variant: IconTileVariant.neutral,
        ),
        name: name,
        line: line,
        trailing: value == null
            ? null
            : Text(
                value,
                style: AppText.bodyS.copyWith(color: tokens.textPrimary),
                textAlign: TextAlign.end,
              ),
        semanticLabel: semanticLabel,
        onTap: onTap,
        stackValue: true,
      );
    }

    return DetailScreen(
      header: ScreenHeader(
        kicker: l.x80HeroKicker,
        leading: AppIconButton(
          icon: AppIcons.back,
          variant: AppIconButtonVariant.onPage,
          semanticLabel: l.x80Back,
          onPressed: () => context.pop(),
        ),
      ),
      children: <Widget>[
        Text(
          l.x80HeroLine,
          style: AppText.titleScreen.copyWith(color: tokens.textPrimary),
        ),
        const VSpace(Space.s),
        Text(
          l.x80HeroContext,
          style: AppText.line.copyWith(color: tokens.textSecondary),
        ),
        GlassCard(
          variant: GlassCardVariant.list,
          title: l.x80CardCapture,
          child: Column(
            children: <Widget>[
              row(
                icon: AppIcons.mic,
                name: l.x80CaptureSources,
                value: l.x80CaptureSourcesValue,
              ),
              row(
                icon: AppIcons.viewTree,
                name: l.x80Categories,
                line: l.x80CategoriesLine,
                value: l.x80RulesValue,
                semanticLabel: l.x80Categories,
                onTap: () => context.push('/x84'),
              ),
              row(
                icon: AppIcons.import,
                name: l.x80ImportLayouts,
                value: l.x80ImportLayoutsValue,
                semanticLabel: l.x80ImportLayouts,
                onTap: () => context.push('/x63'),
              ),
            ],
          ),
        ),
        GlassCard(
          variant: GlassCardVariant.list,
          title: l.x80CardMoney,
          child: Column(
            children: <Widget>[
              row(
                icon: AppIcons.bank,
                name: l.x80MainCurrency,
                value: 'USD',
              ),
              row(
                icon: AppIcons.card,
                name: l.x80Accounts,
                value: l.x80AccountsValue,
              ),
              row(
                icon: AppIcons.calendar,
                name: l.x80MonthStart,
                value: l.x80MonthStartValue,
              ),
              row(
                icon: AppIcons.more,
                name: l.x80NumberFormat,
                value: l.x80NumberFormatValue,
              ),
            ],
          ),
        ),
        GlassCard(
          variant: GlassCardVariant.list,
          title: l.x80CardScreens,
          meta: l.x80ScreensMeta,
          child: Column(
            children: <Widget>[
              row(
                icon: AppIcons.chart,
                name: l.x80MainNumberRow,
                value: l.x80MainNumberValue,
              ),
              row(
                icon: AppIcons.house,
                name: l.x80ScreensHome,
                value: l.x80WidgetsShown(4),
              ),
              row(
                icon: AppIcons.chart,
                name: l.x80ScreensSpending,
                value: l.x80WidgetsCount(4),
              ),
              row(
                icon: AppIcons.bank,
                name: l.x80ScreensMoneyIn,
                value: l.x80WidgetsCount(2),
              ),
              row(
                icon: AppIcons.bank,
                name: l.x80ScreensWealth,
                value: l.x80WidgetsCount(2),
              ),
              row(
                icon: AppIcons.chart,
                name: l.x80ScreensInvestments,
                value: l.x80WidgetsCount(5),
              ),
              row(
                icon: AppIcons.calendar,
                name: l.x80ScreensCalendar,
                value: l.x80WidgetsCount(2),
              ),
              row(
                icon: AppIcons.check,
                name: l.x80ScreensGoals,
                value: l.x80WidgetsCount(3),
              ),
              row(
                icon: AppIcons.shield,
                name: l.x80ScreensProtect,
                value: l.x80WidgetsCount(4),
              ),
              row(
                icon: AppIcons.receipt,
                name: l.x80ScreensTax,
                value: l.x80WidgetsCount(4),
              ),
              SelectRow(
                name: l.x80RestoreWidgets,
                chevron: false,
              ),
            ],
          ),
        ),
        GlassCard(
          variant: GlassCardVariant.list,
          title: l.x80CardSafety,
          child: Column(
            children: <Widget>[
              row(
                icon: AppIcons.lock,
                name: l.x80AppLock,
                value: l.x80AppLockValue,
              ),
              row(
                icon: AppIcons.safe,
                name: l.x80Recovery,
                line: l.x80RecoveryLine,
                value: l.x80RecoveryValueDate,
              ),
              row(
                icon: AppIcons.shield,
                name: l.x80PrivacyRow,
                value: l.x80PrivacyValue,
                // Debug builds walk to the X86 skeleton. No state changes.
                onTap:
                    kDebugMode ? () => GoRouter.of(context).go('/x86') : null,
                semanticLabel: kDebugMode ? l.x80PrivacySpoken : null,
              ),
            ],
          ),
        ),
        GlassCard(
          variant: GlassCardVariant.list,
          title: l.x80AppCard,
          child: Column(
            children: <Widget>[
              row(
                icon: AppIcons.zap,
                name: l.x80Features,
                value: l.x80FeaturesValue,
              ),
              row(
                icon: AppIcons.show,
                name: l.x80Appearance,
                value: l.x80AppearanceValue,
              ),
              row(
                icon: AppIcons.info,
                name: l.x80About,
                value: l.x80AboutValue,
              ),
              row(
                icon: AppIcons.repeat,
                name: l.x80ActivityHistory,
                value: l.x80ActivityHistoryValue,
                semanticLabel: l.x80ActivityHistory,
                onTap: () => context.push('/c06'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
