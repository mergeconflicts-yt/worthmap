import 'package:contour/core/money.dart';
import 'package:flutter/material.dart';

import '../components/buttons/app_button.dart';
import '../components/buttons/icon_button.dart';
import '../components/buttons/info_button.dart';
import '../components/hero/ob_hero.dart';
import '../components/surfaces/glass_card.dart';
import '../components/surfaces/screen_header.dart';
import '../components/surfaces/widget_slot.dart';
import '../format/money_text.dart';
import '../icons/app_icons.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../typography/app_text.dart';

/// DESIGN 0.5, 10: the gallery entry for the Phase 1 components. Each variant
/// and the hidden-amount state appear here (T05).
class ComponentsGallery extends StatelessWidget {
  const ComponentsGallery({super.key});

  static final Money _amount = Money.fromMinor(412365, Currency.usd);
  static final Money _gain = Money.fromMinor(24680, Currency.usd);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.surfacePage,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _heading(context, 'GlassCard'),
            GlassCard(
              title: 'Spending this month',
              meta: 'Jun 2026',
              child: Text(
                'Card body',
                style: AppText.body.copyWith(color: tokens.textPrimary),
              ),
            ),
            const VSpace(Space.l),
            GlassCard(
              variant: GlassCardVariant.stage,
              title: 'Trend',
              titleOpens: true,
              child: Text(
                'Stage body (a chart)',
                style: AppText.body.copyWith(color: tokens.textPrimary),
              ),
            ),
            const VSpace(Space.l),
            GlassCard(
              variant: GlassCardVariant.wide,
              child: Text(
                'Wide body',
                style: AppText.body.copyWith(color: tokens.textPrimary),
              ),
            ),
            const VSpace(Space.xxl),
            _heading(context, 'AppButton'),
            for (final variant in AppButtonVariant.values) ...<Widget>[
              AppButton(
                label: _labelFor(variant),
                variant: variant,
                onPressed: () {},
              ),
              const VSpace(Space.m),
            ],
            AppButton(
              label: 'Ghost with icon',
              variant: AppButtonVariant.ghost,
              icon: AppIcons.filter,
              onPressed: () {},
            ),
            const VSpace(Space.m),
            const AppButton(label: 'Disabled', onPressed: null),
            const VSpace(Space.xxl),
            _heading(context, 'IconButton and InfoButton'),
            const Row(
              children: <Widget>[
                AppIconButton(
                  icon: AppIcons.back,
                  semanticLabel: 'Back',
                ),
                HSpace(Space.m),
                AppIconButton(
                  icon: AppIcons.close,
                  semanticLabel: 'Close',
                  variant: AppIconButtonVariant.onCard,
                ),
                HSpace(Space.m),
                AppIconButton(
                  icon: AppIcons.more,
                  semanticLabel: 'More',
                  variant: AppIconButtonVariant.plain,
                ),
                HSpace(Space.m),
                InfoButton(semanticLabel: 'About this number'),
              ],
            ),
            const VSpace(Space.xxl),
            _heading(context, 'ObHero'),
            ObHero(
              kicker: 'Available · today',
              amount: _amount,
              state: ValueState.real,
              contextLine: 'After bills and set-asides',
              onInfo: () {},
              infoLabel: 'About available',
            ),
            const VSpace(Space.xxl),
            ObHero(
              kicker: 'Available · today',
              amount: _amount,
              state: ValueState.real,
              hidden: true,
              noneRecordedLabel: 'None recorded',
            ),
            const VSpace(Space.xxl),
            ObHero(
              kicker: 'Net worth',
              amount: Money.fromMinor(12980000, Currency.usd),
              state: ValueState.real,
              variant: ObHeroVariant.detail,
              sideFigures: <HeroSideFigure>[
                HeroSideFigure(
                  value: MoneyText(
                    amount: _gain,
                    state: ValueState.real,
                    style: AppText.numberS.copyWith(color: tokens.stateGain),
                  ),
                  period: 'this month',
                ),
                HeroSideFigure(
                  value: MoneyText(
                    amount: _amount,
                    state: ValueState.real,
                    style: AppText.numberS.copyWith(color: tokens.textPrimary),
                  ),
                  period: 'invested',
                ),
              ],
            ),
            const VSpace(Space.xxl),
            _heading(context, 'ScreenHeader'),
            ScreenHeader(
              title: 'Home',
              dateLine: 'Friday 19 June',
              kicker: 'Home · this month',
              leading: const AppIconButton(
                icon: AppIcons.back,
                semanticLabel: 'Back',
              ),
              actions: const <Widget>[
                AppIconButton(
                  icon: AppIcons.hide,
                  semanticLabel: 'Hide amounts',
                ),
                AppIconButton(
                  icon: AppIcons.inbox,
                  semanticLabel: 'Inbox',
                ),
                AppIconButton(
                  icon: AppIcons.settings,
                  semanticLabel: 'Settings',
                ),
              ],
            ),
            const VSpace(Space.xxl),
            _heading(context, 'WidgetSlot (editing)'),
            WidgetSlot(
              variant: WidgetSlotVariant.editing,
              toolRow: Text(
                'Widget tools',
                style: AppText.caption.copyWith(color: tokens.textSecondary),
              ),
              child: GlassCard(
                title: 'Spending this month',
                child: Text(
                  'Card body',
                  style: AppText.body.copyWith(color: tokens.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(AppButtonVariant variant) => switch (variant) {
        AppButtonVariant.primary => 'Primary action',
        AppButtonVariant.neutral => 'Neutral',
        AppButtonVariant.ghost => 'Ghost',
        AppButtonVariant.soft => 'Soft',
        AppButtonVariant.destructive => 'Delete payment',
      };

  Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: Text(
          text.toUpperCase(),
          style:
              AppText.labelCaps.copyWith(color: context.tokens.textSecondary),
        ),
      );
}
