@Tags(<String>['golden'])
library;

import 'package:contour/core/dates.dart';
import 'package:contour/design/design.dart';
import 'package:contour/features/home/x03_home_first.dart';
import 'package:contour/features/settings/x80_settings.dart';
import 'package:contour/features/settings/x86_privacy.dart';
import 'package:contour/features/start/x01_welcome.dart';
import 'package:contour/features/start/x02_lock.dart';
import 'package:contour/features/wealth/x40_wealth.dart';
import 'package:contour/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/wealth/fake_wealth_gateway.dart';
import 'golden_harness.dart';

/// SPEC 16.3 banned words (data-only rule, AGENTS 2.2). The check runs over
/// every string the Phase 1 screens show.
const List<String> _bannedWords = <String>[
  'should',
  'recommend',
  'too much',
  'risky',
  'on track',
  'behind',
  'great',
  'sell',
  'buy',
  'warning',
];

void main() {
  // One fixture per Phase 1 screen: name, surface size, builder.
  final screens = <(String, Size, Widget Function(BuildContext))>[
    (
      'x01_welcome',
      const Size(420, 1800),
      (context) => const X01Welcome(),
    ),
    (
      'x02_lock',
      const Size(420, 900),
      (context) => const X02Lock(),
    ),
    (
      'x03_home_first',
      const Size(420, 1600),
      (context) => X03HomeFirstRun(today: LocalDate(2026, 10, 13)),
    ),
    (
      'x40_wealth',
      const Size(420, 2600),
      (context) => X40Wealth(gateway: FakeWealthGateway()),
    ),
    (
      'x80_settings',
      const Size(420, 4800),
      (context) => X80Settings(onClose: () {}),
    ),
    (
      'x86_privacy',
      const Size(420, 1500),
      (context) => const X86Privacy(),
    ),
  ];

  test('Phase 1 screen strings carry no advice words', () async {
    final l = lookupAppLocalizations(const Locale('en'));
    final all = <String>[
      l.x01Kicker,
      l.x01Title,
      l.x01Line,
      l.x01PhoneRowName,
      l.x01PhoneRowLine,
      l.x01EyeRowName,
      l.x01EyeRowLine,
      l.x01ShieldRowName,
      l.x01ShieldRowLine,
      l.x01CurrencyCardTitle,
      l.x01CurrencyCardMeta,
      l.x01CurrencyName,
      l.x01CurrencyLine,
      l.x01CurrencySpoken,
      l.x01Start,
      l.x01Caption,
      l.x02Locked,
      l.x02Line,
      l.x02Unlock,
      l.x02UsePasscode,
      l.x02Spoken,
      l.x03Today,
      l.x03DateLine('13 October 2026', 'USD'),
      l.x03HeroKicker,
      l.x03HeroDash,
      l.x03HeroLine,
      l.x03GetStartedTitle,
      l.x03GetStartedMeta,
      l.x03GetStartedSpoken,
      l.x03Step1,
      l.x03Step1Line,
      l.x03Step2,
      l.x03Step2Line,
      l.x03Step3,
      l.x03Step3Line,
      l.x03Step4,
      l.x03Step4Line,
      l.x03Step5,
      l.x03Step5Line,
      l.x03StepsCaption,
      l.x03Next30Title,
      l.x03Next30Meta,
      l.x03Next30Line,
      l.x03InboxAction,
      l.x03SettingsAction,
      l.x80Title,
      l.x80SubLine,
      l.x80HeroKicker,
      l.x80HeroLine,
      l.x80HeroContext,
      l.x80CardCapture,
      l.x80CaptureSources,
      l.x80CaptureSourcesValue,
      l.x80Categories,
      l.x80CategoriesValue,
      l.x80CategoriesLine,
      l.x80RulesValue,
      l.x80Accounts,
      l.x80AccountsValue,
      l.x80ScreensHome,
      l.x80ScreensSpending,
      l.x80ScreensMoneyIn,
      l.x80ScreensWealth,
      l.x80ScreensInvestments,
      l.x80ScreensCalendar,
      l.x80ScreensGoals,
      l.x80ScreensProtect,
      l.x80ScreensTax,
      l.x80WidgetsShown(4),
      l.x80WidgetsCount(4),
      l.x80RestoreWidgets,
      l.x80RecoveryLine,
      l.x80RecoveryValueDate,
      l.x80Features,
      l.x80FeaturesValue,
      l.x80Appearance,
      l.x80AppearanceValue,
      l.x80About,
      l.x80AboutValue,
      l.x80ImportLayouts,
      l.x80ImportLayoutsValue,
      l.x80CardMoney,
      l.x80MainCurrency,
      l.x80Accounts,
      l.x80MonthStart,
      l.x80MonthStartValue,
      l.x80NumberFormat,
      l.x80NumberFormatValue,
      l.x80CardScreens,
      l.x80ScreensMeta,
      l.x80MainNumberRow,
      l.x80MainNumberValue,
      l.x80CardSafety,
      l.x80AppLock,
      l.x80AppLockValue,
      l.x80Recovery,
      l.x80RecoveryValue,
      l.x80PrivacyRow,
      l.x80PrivacyValue,
      l.x80Back,
      l.x80RowOpen,
      l.x86Title,
      l.x86SubLine,
      l.x86HeroKicker,
      l.x86HeroLine,
      l.x86HeroContext,
      l.x86NetworkTitle,
      l.x86NetworkMeta,
      l.x86PriceService,
      l.x86PriceServiceLine,
      l.x86TurnOff,
      l.x86TurnOffLine,
      l.x86TurnOffSpoken,
      l.x86OnPhoneTitle,
      l.x86Database,
      l.x86DatabaseValue,
      l.x86Speech,
      l.x86OnPhoneValue,
      l.x86TextRecognition,
      l.x86RecoverySnapshots,
      l.x86DeleteAll,
      l.x86DeleteAllCaption,
      l.x86RowRead,
      l.wealthKicker,
      l.wealthHeroKicker,
      l.wealthChartTitle,
      l.wealthSeriesNetWorth,
      l.wealthSeriesInvestments,
      l.wealthSeriesCash,
      l.wealthOwn,
      l.wealthOwe,
      l.wealthOwnOweTitle,
      l.wealthTypeCash,
      l.wealthTypeInvestments,
      l.wealthTypeCard,
      l.wealthNoBalance,
      l.wealthMissing,
      l.wealthLoadFailed,
    ];
    final lowered = all.map((s) => s.toLowerCase()).toList();
    for (final word in _bannedWords) {
      expect(
        lowered.where((s) => s.contains(word)),
        isEmpty,
        reason: 'banned advice word "$word" appears in a Phase 1 string',
      );
    }
    // Unknown is never zero (SPEC 16.3): no bare "$0" string exists.
    for (final s in lowered) {
      expect(s.contains(r'$0'), isFalse, reason: 'string "$s" shows a zero');
    }
  });

  for (final theme in <(String, ThemeData)>[
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final scale in goldenScales) {
      for (final (name, size, build) in screens) {
        testWidgets('$name ${theme.$1} ${scale}x', (tester) async {
          await loadContourFonts();
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            goldenApp(
              theme: theme.$2,
              section: Section.home,
              textScale: scale,
              child: Builder(builder: build),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('screens_${name}_${theme.$1}_${scale}x.png'),
          );
        });
      }
    }
  }
}
