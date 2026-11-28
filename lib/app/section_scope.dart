// T09 (DESIGN 3; SCREENS.md screen table): the route-to-Section mapping.
//
// The router sets the section for a route; components read
// `context.section` through the design `SectionScope`. Phase 1 routes all
// map to the Home section per SCREENS.md (X01, X02, X03, X80, X86 are Home
// screens; the lock screen covers everything).
library;

import '../design/design.dart';
import 'router.dart';

export '../design/theme/section.dart'
    show Section, SectionScope, SectionContext;

/// The Section of a route (DESIGN 3; SCREENS.md screen table).
Section sectionForRoute(AppRoute route) {
  return switch (route) {
    AppRoute.welcome || AppRoute.lock || AppRoute.home => Section.home,
    AppRoute.wealth || AppRoute.accountEditor => Section.wealth,
    AppRoute.plan => Section.plan,
    AppRoute.paymentAdd => Section.spending,
    AppRoute.transferAdd ||
    AppRoute.voiceCapture ||
    AppRoute.spending ||
    AppRoute.whereItGoes ||
    AppRoute.moneyIn ||
    AppRoute.budget ||
    AppRoute.editLimits ||
    AppRoute.category ||
    AppRoute.allPayments ||
    AppRoute.paymentDetail ||
    AppRoute.repeating ||
    AppRoute.repeatingDetail ||
    AppRoute.scheduleEditor =>
      Section.spending,
    AppRoute.rules || AppRoute.ruleEditor => Section.home,
    AppRoute.inbox ||
    AppRoute.importHub ||
    AppRoute.history ||
    AppRoute.settings ||
    AppRoute.privacy ||
    AppRoute.gallery =>
      Section.home,
  };
}
