import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';

/// SPEC 6.1 X02: the App lock silhouette. A generic blurred Home silhouette
/// with no real data sits behind; centred mark and words; two unlock
/// actions at the bottom. No amounts, no hero, no data card.
///
/// The unlock actions are wired to the T08 lock controller in the app
/// composition (DECISION-PENDING: T09-AUTH-GATE-WIRING).
class X02Lock extends StatelessWidget {
  const X02Lock({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l.x02Spoken,
      child: Stack(
        children: [
          _HomeSilhouette(kicker: l.x03HeroKicker),
          PageBackground(
            child: Padding(
              padding: const EdgeInsets.only(
                top: Space.xxl,
                left: Space.page,
                right: Space.page,
                bottom: Space.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(child: BrandMark(point: 76)),
                  const VSpace(Space.xl),
                  Text(
                    l.x02Locked,
                    style: AppText.titleScreen,
                    textAlign: TextAlign.center,
                  ),
                  const VSpace(Space.s),
                  Text(
                    l.x02Line,
                    style: AppText.line.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  AppButton(
                    label: l.x02Unlock,
                    onPressed: () {
                      // DECISION-PENDING: T09-AUTH-GATE-WIRING. Starts the
                      // authentication attempt through the T08 controller.
                    },
                  ),
                  const VSpace(Space.s),
                  AppButton(
                    label: l.x02UsePasscode,
                    variant: AppButtonVariant.ghost,
                    onPressed: () {
                      // DECISION-PENDING: T09-AUTH-GATE-WIRING. Invokes the
                      // operating system's device credential.
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fixed generic silhouette behind the lock: kicker text, a neutral
/// line shape and two empty card shapes, blurred. No real data or chart.
class _HomeSilhouette extends StatelessWidget {
  const _HomeSilhouette({required this.kicker});

  final String kicker;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role(context.section);
    final blurred = ImageFilter.blur(sigmaX: 11, sigmaY: 11);
    return ColoredBox(
      color: tokens.surfacePage,
      child: Opacity(
        opacity: 0.75,
        child: ImageFiltered(
          imageFilter: blurred,
          child: Padding(
            padding: const EdgeInsets.only(
              top: Space.xl,
              left: Space.page,
              right: Space.page,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Generic silhouette kicker; carries no data.
                  kicker,
                  style: AppText.labelCaps.copyWith(color: role.text),
                ),
                const VSpace(Space.m),
                const TrackShape.rect(height: 32, width: 140),
                const VSpace(Space.m),
                const TrackShape.pill(height: 14, width: 90),
                const VSpace(Space.xl),
                const TrackShape.tile(height: 120),
                const VSpace(Space.card),
                const TrackShape.tile(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
