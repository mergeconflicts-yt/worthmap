# Contour — Decisions and Open Questions

Version 1.0 — 17 October 2026. This file records design and product decisions and
any conflict between sources (AGENTS.md sections 1 and 9). A conflict names the
sources, the options and the preferred option. Feature code never changes
SPEC.md, DESIGN.md or AGENTS.md; it records the item here.

## Open questions

- Phase 2 planning gaps (2026-11-22, from `docs/TASKS_PHASE2.md`). Each
  names the source conflict, the options and the preferred option. They
  block only the named Phase 2 tasks.

- `P2-INBOX-PRODUCER`. SPEC 17 puts the Inbox (X60–X62) in Phase 2, but no
  Phase 2 source feeds it: manual, quick-add, voice and receipt forms commit
  directly (flows "Drafts, saving and cancellation"), and imports arrive in
  Phase 3 (F06). The X60 sample rows name Notifications, Mail app and
  Statement sources, which are Phase 3 and v1.1 (F19, G08).
  DECISION-PENDING: P2-INBOX-PRODUCER.
- Options. (a) Build the Inbox read model, decisions and Confirm batch (P17,
  P25) with a test-only staged producer and synthetic fixtures, so Phase 3
  imports plug in without rework. (b) Move the Inbox screens to Phase 3 and
  keep only the batch command in Phase 2.
- Preferred. (a). It matches the Phase 1 pattern (test widgets behind the
  real host), keeps the phase order in SPEC 17, and no real capture path is
  invented. The 3.1 target "confirm 20 Inbox items in under 60 s" is measured
  with the synthetic producer and reported as such.

- `P2-SPEND-NEXT-INCOME`. X31 has a "Next income" card and X34 has a
  billing-day strip built from dated payments; the X31 card and the
  `moneyIn.nextIncome` widget need expected income and the calendar (F14,
  Phase 4). SPEC 17 Phase 2 does not include the calendar.
- Options. (a) Ship both screens without the next-income card and without
  the `moneyIn.nextIncome` widget, and add them in Phase 4. (b) Add
  `ExpectedIncome` in Phase 2. (c) Derive a next income date from repeating
  income schedules, which Phase 2 does store.
- Preferred. (a). (c) would add a financial meaning the sources do not
  define. The X34 strip itself is dated paid and unpaid items and can ship;
  only the "next income" card and widget wait.

- `P2-SEARCH-ENTRY`. SCREENS X30 and X37 show Search in the header, but the
  Search screen X15 is Phase 4 (F02 index), and SPEC 17 Phase 2 does not
  list search. A disabled feature must be absent from navigation (flows
  shared contract 6).
- Options. (a) Omit the search control on X30 and X37 until X15 ships.
  (b) Build a Phase 2 list filter as the only search and add X15 later.
- Preferred. (a). Filters (X38) already cover the Phase 2 use, and one  search entry point with one behaviour avoids a second, incompatible
  search in Phase 4.

- Preferred. (a). Filters (X38) already cover the Phase 2 use, and one  search entry point with one behaviour avoids a second, incompatible
  search in Phase 4.

- `GL-TIMELINE-HEIGHT`. DESIGN_REFERENCE 6.7 gives the `GlyphTimeline`
  sideways scroll region as 104 high. The reference photo of X10 (owner
  image, 23 Nov 2026) shows a two-line name and amount label above the line,
  the day numbers under it, and a two-line label below; those blocks do not
  fit 104, and the top labels clip.
- Options. (a) Build the region 118 high so every block fits as the
  reference shows. (b) Keep 104 and drop the labels to one line.
- Preferred. (a). The reference is the approved look; the 104 figure reads
  as the axis height, not the whole region. Goldens use 118.
  DECISION-PENDING: GL-TIMELINE-HEIGHT.

- `X10-DUE-BASIS`. The X10 "Next 30 days" meta computes "$X due before
  [today + 30 days]". SCREENS X10's sample is "$2,415 due before 1 Nov" —
  before the next income. The Home read model carries no next-income date
  (the upcoming list holds no income kind yet; see P2-SPEND-NEXT-INCOME).
- Options. (a) Keep the today + 30 days window until the model carries the
  next income, then change the meta basis in one change. (b) Derive the next
  income from repeating income schedules now (option (c) there, which it
  declines for Phase 2).
- Preferred. (a). The window stays factual; the basis changes when the
  calendar data exists.

- `P2-TRANSFER-BOUNDARY`. F05-E says a transfer across the included/excluded
  net worth boundary "counts as Other recorded changes", but NUM-001 defines
  the bridge with four parts only (kept, markets, currency, values), and G14
  closed on that four-part form. A boundary transfer changes net worth
  without changing Kept, so the printed bridge cannot add up for that
  period. The REVIEW-002 F01 detail is absent from this checkout.
  DECISION-PENDING: P2-TRANSFER-BOUNDARY.- Options. (a) Show the attribution as Missing for any period with a
  boundary transfer; the totals stay correct (preferred for Phase 2).
  (b) Add a fifth part "Other recorded changes" to NUM-001 and extend the
  About sheet table and the Appendix A fixture. (c) Treat the leaving
  principal as money out, which breaks "transfers are not spending".
- Preferred. (a) now, because it is factual and easy to undo, and (c) is
  rejected. (b) is a NUM-001 change and needs its own specification pull
  request. Until then F05-E's wording is superseded.

- The router carries a `LockGate` port. The placeholder `AlwaysOpenGate` is
  wired only because Phase 1 screens hold no user records and X02 (the lock
  screen) is still a silhouette until T10 builds it. DECISION-PENDING:
  T09-AUTH-GATE-WIRING.
- Preferred resolution. T10 wires X02 to the T08 `LockController`, and the
  app composition replaces `AlwaysOpenGate` with a gate backed by the
  controller's admission state, in the T10 pull request.


- The native bindings — iOS local authentication and Android
  BiometricPrompt/device credentials, the lock-screen blur, and the
  device-protected lifecycle control store — are not in this checkout. T08
  ships the ports (`AuthPort`, `KeyStore`, `LifecycleControlStore`) with
  typed outcomes, in-memory test doubles and the full state machine; the app
  composition must never reach a platform package directly (AGENTS 6.7).
  DECISION-PENDING: T08-NATIVE-AUTHPORT, T08-NATIVE-KEYSTORE,
  T08-NATIVE-CONTROLSTORE.
- Preferred resolution. Native builder implements each binding behind its
  port, one pull request per binding, with the simulator lock/unlock log
  (T08 evidence) and the no-secret-in-logs check.
- T10 needed four components that did not exist: `SelectRow`, `ToggleRow`,
  `CapsuleMeter` and the `BrandMark`, plus a 40 pt `IconTile`, an empty
  `TrackShape` for silhouettes, and a `phone` icon. Per DESIGN.md 10
  (find, compose, variant, token, component) they land in `lib/design/`,
  tokens only, each covered by goldens (`extra_components_golden_test.dart`)
  — a design-ownership cross recorded like T06-DESIGN-COMPONENTS. Notes:
  - `CapsuleMeter` draws its fill with integer flex weights, so no `double`
    exists and no charts-folder exception applies (AGENTS 12).
  - The `BrandMark` painter lives under `lib/design/charts/` because the
    DESIGN 9 law (and the `no_custom_paint` lint) confines `CustomPainter`
    to that folder; it draws the brand, not data. The lint plugin exempts
    that one file from `no_gradient_on_data`: the contour line gradient is
    the brand element DESIGN 6.7 describes, not a data fill (the brand
    source asset is absent; see T10-BRANDMARK).
  - The gallery goldens changed once, deliberately: the icon grid gained
    the `phone` icon (one extra cell). Checked in the regenerated images.
- Preferred resolution. The design owner reviews the five components and
  the BrandMark approximation against the reference; the brand asset
  replaces the painter when `docs/brand/*.svg` return.
- T11's file list did not include l10n, but AGENTS 6.9 requires every
  visible string of the Delete-all confirm sheet in l10n. Five strings were
  added to `lib/l10n/app_en.arb` (`deleteAllSheet*`), owned by this task.
- Preferred resolution. None needed; the record closes the file-ownership
  deviation (AGENTS 9: easier to undo, factual, no conflict with another
  owner — no other task owns the Delete-all sheet).

- The pinned SQLCipher native build, its FFI binding verification and the
  encrypted-WAL/temp/FTS device evidence are not in this checkout (gate DB-A,
  DATABASE_DESIGN 11). T07 ships the vault open path behind a `VaultCipher`
  port that fails closed: the production `SqlCipherVaultCipher` (PRAGMA key,
  `cipher_version`, `cipher_integrity_check`, authenticated read) cannot pass
  on the host build, because the host SQLite has no cipher. A test-only
  scripted cipher simulates the fail-closed semantics, and
  `UnverifiedOpenCipher` (synthetic/test data only, PF-01) allows development
  vaults without claiming confidentiality.
- Preferred resolution. Land the pinned SQLCipher build behind the port in a
  native-builder pull request, run the DB-A device matrix, then wire the app
  entry through the production cipher. Do not switch to Drift's
  SQLite3MultipleCiphers or `sqlcipher_flutter_libs` (SYSTEM_DESIGN 5.1).
- The reference upgrade scripts (`002_shared_state.sql`,
  `003_review_guards.sql`, `004_full_review.sql`, `005_layout_sections.sql`)
  and their frozen version 1.1-1.4 fixtures are absent from this checkout.
  T07 creates fresh vaults at the current reference version (SCHEMA.sql,
  database schema version 5) and fails closed with a typed, safe code on an
  old-version file. No invented migration runs.
- Preferred resolution. Return the reference migration scripts and frozen
  fixtures, then implement each upgrade as a separate data-builder pull
  request with the old-version fixtures and rollback tests (DB-B), per
  DATABASE_DESIGN 10 (migration contract).
- T07 executes the translated reference DDL verbatim and reads through
  owner-validated statements; no drift table classes are generated yet. The
  roll-up note that "build_runner waits for T07 generators" changes: typed
  drift table classes land with the repositories that own typed reads
  (DB-D/DB-E query variants), not with the schema translation.
- Preferred resolution. Add drift table classes per read model, one pull
  request per family, when a typed read is first needed.


## Decided

### P4-VALUE-METHOD-BASIS

- Decision (2026-11-28, owner). The value projection basis is:
  - actual days, with 365 days in a year and a leap day counted once;
  - the compounding the user selects, with complete periods at the period
    rate and the remaining days at simple pro-rata of the annual rate;
  - each contribution grows from its own date at simple pro-rata of the
    annual rate, so no order is invented;
  - one half-to-even round to the currency's minor unit at the end;
  - a maturity date stops growth; renewal is a new write.
- Consequence. The projection lives in `lib/domain/values/`. With this basis
  the Appendix A deposit is $10,278 today (not $10,280) and $10,312 at
  maturity; the pension is $23,934 (not $24,010). Net worth becomes $187,822
  and the 30 September close $182,332, so the four-part bridge keeps
  Values $0 and the change stays +$5,490.
- Follow-up (done 2026-11-28, `P4-01b`). The Appendix A values, the
  attribution example, the screen samples, the test constants and the
  goldens moved in one change. The levels move by −$78 (30 September close $182,332,
  12-month start $170,922, 1-month start $181,222) so every change figure
  stays the same: +$5,490 this month, +$16,900 in 12 months, +$6,600 in 1
  month. This supersedes the fixture arithmetic quoted in FIN-3-03 and
  CLOSED-G14-FIN-DEFINITIONS; their text stays as the record of its date.

### P4-PLAN

- Decision (2026-11-28). X50 reads the retained Expected occurrences from
  today to 45 days ahead and writes nothing. The window ends at a real
  occurrence date, so no invented day appears on the calendar.

- Calendar. New `SymbolCalendar`: Monday first, cells 72 high (96 above 1.3
  text scale), one flow glyph per event (up to three, then "+N"), a month mark
  on the first day of a month, today outlined, past days in `text.secondary`.
  A day with events is a button that opens the X51 sheet. Amounts stay out of
  the cells, as DESIGN 6.7 says.

- Amounts. X50 keeps cents ("−$17.99"), unlike X30 and X40 which round to
  whole units for their layouts. `MoneyText(trimZeroFraction: true)` drops
  only an all-zero fraction.

- Card. "Before next income" lists the events before the next income date and
  then "From next income". When the range holds no income, the title is
  "Next 45 days"; the demo has no income schedule, so it shows that title.

- Not built, and recorded so the screen is not read as complete: the
  Calendar · Goals · Protect · Tax SegmentTabs (Goals is v1.1, Protect and
  Tax are v1.2; a tab that opens nothing would be a dead control), the X50b
  cash-flow row (no balance forecast read), and the calendar's legend
  amounts.

- Evidence: `test/features/plan/x50_plan_test.dart` (3),
  `test/app/demo_plan_test.dart` (1), and four X50 goldens (dark and light at
  1.0 and 2.0), all checked.

### P4-WEALTH

- Decision (2026-11-28, owner's Wealth mockup). X40 now follows the reference:
  the `NET WORTH` kicker with the Home controls (hide, Inbox with count,
  Settings), the number with the change and its share at the right, the target
  line, the three-series chart, the period chips, the own/owe card and the
  "Not in net worth" card.

- Periods. 1D, 1W and 1M are rolling days; 1Y and 5Y use month ends; MAX
  starts at the first live balance anchor. Every period ends at today, never
  at a future date. The change is end − start; the share is change ÷ start
  through `Decimal`, formatted to one decimal. A short history keeps 5Y
  Missing (`wealth_change`, SPEC 4.3).

- Chart. `MultiLineChart` gains a right y axis in four steps from $0 and three
  x labels (first, middle, last). The plot stops before the y labels, so a
  label never covers a line. Net worth uses `ChartMark.gain`, investments
  `invested`, cash `inCash`; no new token.

- Own/owe card. `AmountTabs` carries the two totals with a mark under the
  selected tab. `SplitLine` is the thin line across every recorded own and owe
  type. `TypeTileGrid` shows the fixed type slots (3 per row, 2 above 1.3 text
  scale, 1 at 2.0); a type with no record is a dashed tile with "None
  recorded". Recorded types in the demo are investments, cash and bank, and
  cards.

- Not in net worth. The demo passes the SCREENS samples (unvested shares
  $31,595, owed to you $2,640, dividends $245) as synthetic values, like the
  target. The release path passes none, so the card stays out until the
  records exist.

- Not built and not claimed: the row chevrons (the detail screens do not
  exist), the "160 shares at today's price" fact (no share record), the "Edit
  widgets" control (no editor route on this tab), and X40b "About this
  number" (needs the NUM-001 parts: markets, currency, values). The demo
  target stays synthetic, as on Home.

- Evidence: `test/domain/numbers/wealth_change_test.dart` (6),
  `test/features/wealth/x40_wealth_test.dart` (3),
  `test/app/demo_wealth_test.dart` (1), and four X40 goldens (dark and light
  at 1.0 and 2.0), all checked.

### CHART-NO-TABLE

- Decision (2026-11-28, owner's request). No chart shows a "Show as table"
  row. `ChartFrame.showTable` and `SplitStrip.showTable` default to false;
  the components keep the option for a gallery demo.
- Consequence. The spoken label stays the one accessible name with the exact
  values. On X40 the month-end rows are no longer on screen. Where a chart
  already listed its values in a legend or a tile (X10 split, X30 bars,
  X40 own/owe), nothing visible is lost.
- Sources changed: SPEC 6, 7 and 16.6; SPEC_REFERENCE 7 and 16.6; DESIGN 7;
  DESIGN_REFERENCE typography and chart sections; AGENTS 6.9; SCREENS
  "Charts"; spec-screens; spec-widgets; SYSTEM_DESIGN 9. This supersedes
  PREVIEW-CHART as a table exception.
- Evidence: `test/design/charts_test.dart`; every golden with a chart is
  regenerated and checked.

### WIDTH-RECLAIM

- Decision (2026-11-28, owner request). Reclaim horizontal space:
  - `space.page` 20 -> 16, `space.cardPad` 18 -> 16 (tokens.json, generated).
  - Chart y-label gutter 44 -> 40 pt, and the axis labels use `chartAxis` 11
    (DESIGN 7.2) instead of `labelCaps` 13.
  - The X40 type tile grid gap 12 -> 8 pt.
- Result at 402 pt: card content 326 -> 338 pt (84.1% of the screen); a chart in
  a card plots 278 -> 302 pt (75.1%). The X40 chart on the page plots 322 pt.
- Sources changed: DESIGN 5 (`space.page`); DESIGN_REFERENCE 4 (spacing table).
- Evidence: `flutter test`, 221 goldens regenerated and checked.

### GOLDEN-DATE-STABILITY

- Problem (2026-11-28). `FakePaymentsReadGateway` read `DateTime.now()` for its
  synthetic rows, and X37 read the same clock for the "Today" and "Yesterday"
  labels. The 24 category, payment-list and payment-detail goldens (dark and
  light, scale 1.0 and 2.0) failed on 28 Nov 2026 because the rows moved from
  24 Nov to 28 Nov. The screens had no defect; the fixture date moved with the
  host clock and the baselines did not.

- Decision. The fake takes an optional `today` and defaults to the fixed
  `FakePaymentsReadGateway.defaultToday` (24 Nov 2026), so every test is
  deterministic. `X37AllPayments` takes an optional `today`, as X10 already
  does; the app composition passes none, so the screen reads the local date.

- Evidence. The 24 regenerated images are byte-identical to the 24 Nov
  baselines, which proves the only difference was the date. `flutter test test`
  1173 pass; `flutter test --tags golden` 213 pass.

- Files: `lib/features/spending/x37_all_payments.dart`,
  `test/features/spending/fake_payments_read_gateway.dart`,
  `test/features/spending/payments_screens_test.dart`,
  `test/golden/design/payments_golden_test.dart`,
  `test/golden/design/hidden_phase2_golden_test.dart`.

### P4-HOME-SPLIT

- Decision (2026-11-23, closing the Home design gaps). Schema version 9 adds
  `categories.is_essential`: 1 = the user's need, 0 = want, NULL = not tagged.
  SPEC 4.4 defines Needs and Wants from that tag; the app adds no judgement.
  Migration 9 has a fresh-create path, a version 8 upgrade and a failed-upgrade
  test that stays at 8.

- The Home split is Needs, Wants, (Unclassified when any), Invested and In
  cash. Shares use `Percent.split` over money in. In cash is money in minus
  spent (kept); Invested is zero when there are no holdings, and Missing when
  holdings exist but their cost basis is not read here. An untagged category
  is Unclassified, never guessed into Needs or Wants.

- Layout changes for the mockup: `HomeTileGrid` makes equal-height tiles per
  row and shrinks a long value instead of wrapping digits; the hero change
  figure sits at the right of the number; `GlyphTimeline` draws the date axis
  with item labels; `SplitStrip` carries the four parts; the footer states the
  account count because prices and recovery are off.

- Still open: the net-worth target line and Goals progress need a goal record
  (G09, v1.1), the bottom bar needs Wealth and Plan screens, Search needs X15,
  and the split bar is horizontal rather than the mockup's vertical strip.

### P4-HOME-MONTH

- Decision (2026-11-23, owner's This month mockup for X10 Home). The two
  tiles are Money in and Spent with no icon: the label, the value and the
  facts alone. The Spent tile carries the limit line "of $5,200 limit · 76%"
  and the `CapsuleMeter` inside the tile, with the today tick at the month
  gone. The tile values are the largest element (`numberL`, DESIGN 6.4) and
  whole amounts drop the ".00" (DESIGN 4); real cents stay.

- Component changes. `HomeTile.icon` is optional and `HomeTile` gains
  `footer` and `valueStyle`; `HomeTileGrid` defaults the value to `numberM`,
  so Quick look values also grow. `CapsuleMeter.today` draws the tick with
  integer weights only (no `double`).

- Still open: the mockup's neutral capsule fill (#E4E5EA dark, #2A2C33 light,
  DESIGN 6.4 METAL-RIM-001) needs its own colour token, and `tokens.json` changes
  in a separate pull request. Until then the meter keeps the section colour.

- Decision (2026-11-23, owner follow-up). X10 shows no decimal places in any
  number: money rounds half up to whole currency units for the pixels and the
  spoken amount (the read model keeps exact minor units), and shares use
  `Percent.split(scale: 0)`, which still adds to exactly 100%. The two This
  month tiles draw no bottom border (`HomeTile.openBottom`) and merge into the
  split. The split has no "Show as table": its legend lists every value and the
  chart label keeps them for the reader, so `ChartFrame(showTable: false)`
  adds that one exception to AGENTS 6.9.

- Decision (2026-11-23, Quick look mockup). A tile is three lines: the title
  with a 36 pt neutral glyph (`size.badgeS`, `text.control`), the number, and
  one small fact. The card tile drops the "Owes " prefix and its fact is the
  card name (`HomeSummary.cardName`, one card only). Cash keeps "available
  now" and Subscriptions "a month". Tiles stack at 200% (SCREENS X10).

- Still open: the mockup's card fact "Visa · 22 Oct" needs a statement date,
  and the investment fact "+$550 today" needs the holdings and prices read
  (Phase 5). Both lines stay absent or name-only until that data exists.

- Decision (2026-11-23, owner follow-up). The hero change and "12 months"
  align their bottom to the net worth number's bottom, and the net worth line
  is 72 high (was 96). A Quick look glyph is a bare 16 pt `text.control` icon
  with no tile or border, level with the title. The investments line is
  "+/− amount today" in `state.gain` or `state.loss` (zero and hidden use
  `text.secondary`). The debug demo passes the synthetic $550 through
  `SqlHomeGateway.investmentsTodayMinor`; the release path passes none.

### P4-TAB-BAR

- Decision (2026-11-23, owner asked for the bottom menu). SPEC 5.1's tab bar
  now mounts on the four roots: Home `/x03`, Spending `/x30`, Wealth `/x40`
  and Plan `/x50`, with the Add pill between Spending and Wealth. A detail
  screen has no bar. `sectionForRoute` maps Home to `Section.home` (it
  wrongly used Wealth), Wealth to `Section.wealth` and Plan to `Section.plan`.
- Wealth and Plan are placeholders: `TabRootScreen`, a title and one
  "Not available in this version." card. `X40Wealth` and `X50Plan` carry no
  numbers until the screens ship.
- Geometry (owner follow-up): the bar floats 8 pt from the sides (was 16) and
  uses 8 pt at both ends and between the five items, so the padding is equal.
- Still open: the Add opens the expense form (X20) on every tab until the
  chooser (X29) exists; the long-press voice entry and the Home Inbox badge
  on the tab are not wired. The tab bar is not in the X10 golden, which
  renders the screen alone.


### P4-HOME-TOP

- Decision (2026-11-23, owner's top-section mockup for X10 Home). The top
  line is the kicker "NET WORTH" with the hide, Inbox (with a count badge) and
  Settings controls at the right. X10 shows no "Today" title or date line; the
  number, the 12-month change, the optional target line and the net worth line
  follow. This resolves AS-OF-DATE for X10 only; X03 keeps its title and date
  line, and the SPEC open item remains for the other screens.

- Order. Line 1 kicker and controls. Line 2 net worth, with the signed change
  at the right in `state.gain` or `state.loss` and "12 months" under it. At
  large text the change moves under the number and the number fits on one
  line. Line 3 the target line only when a target exists and net worth is
  known: a 36 pt bar and "18.8% of $1,000,000 target · Dec 2040". Line 4 one
  plain line chart with an end dot, no fill, baseline or axis labels.

- Target data. The goals record (G09) is v1.1 and does not exist. The read
  model carries an optional `HomeNetWorthTarget`; `SqlHomeGateway` accepts the
  target amount and date and computes the share with SPEC 13.2
  (`netWorthTargetShare`, exact and rounded once). The debug demo passes the
  synthetic $1,000,000 target by Dec 2040; the release composition passes
  none, so the line is absent. A missing net worth or a zero target hides the
  bar, never shows 0%.

- Hidden state. The target amount masks as "$······" and the spoken line says
  "Amount hidden"; the share and the date stay. The 12-month change and the
  chart follow the existing hidden rules.

- Components. `ScreenHeader.title` is optional and its kicker takes the free
  space so actions stay at the right. `ObHero.kicker` is optional and
  `ObHero.minFontSize` is settable. `AreaLineChart` gains a `line` variant.
  New `TargetProgressLine` and `CountBadge` (also used by the tab bar).
  `formatMonthYear` and `formatMoney(trimZeroFraction:)` live in
  `lib/design/format/`.

- Still open: the line does not open Goals until X52 ships; Search (X15) is
  not on X10 yet; the release target waits for the goals record.

### P4-LOCAL-DEMO-VAULT

- Decision (2026-11-23, owner asked for the app's real database). The debug
  demo can open a real SQLite file when the runner sets
  `DEMO_DB_PATH`, for example
  `flutter run --dart-define=DEMO_DB_PATH=$HOME/contour-demo.db`. The second
  start reopens the file and does not seed again. Empty keeps the in-memory
  demo.

- The file holds synthetic data only. It opens through
  `UnverifiedOpenCipher`, because no verified SQLCipher build is in the
  repository (`T07-CIPHER-BUILD`, gate DB-A). It is therefore not encrypted
  and must not hold personal data. It stays behind `kDebugMode` and is never a
  release path.

- Release stays on the unavailable gateways. Real-user persistence waits for
  the pinned cipher build, the DB-A evidence and the PF-01 copy-confinement
  decision (AGENTS 2.1).

- Evidence: `test/app/demo_persistence_test.dart` builds the file vault twice,
  closes each, and asserts the same account count.


### P4-HOME-DATA

- Decision (2026-11-23, owner asked for Home with data). The debug demo now
  mounts X10 instead of X03 when a `HomeGateway` exists. The release start keeps
  X03, because its vault composition still waits for `PF-01` and
  `T07-CIPHER-BUILD`.

- Read model. Net worth is the sum of `include_in_net_worth` balances. Cash is
  the sum of `is_liquid` balances. Card bill is the sum of liability balances
  shown as owed. Money in and Spent come from the existing P26 and P15 reads
  for the current month. Inbox is `pendingCount`; repeating is the active
  schedule count; Recent is the five newest money-out payments. A missing
  balance makes its total Missing, never zero.

- Layout. X10 shows the hero with the 12-month change figure, the 12-month
  net worth line, Quick look as a 2-column tile grid (Cash, Card bill,
  Investments, Subscriptions), the next 30 days as a timeline, this month with
  the limit meter, the income split strip (Invested, In cash) and the footer.
  New design components: `AreaLineChart`, `HomeTileGrid`, `GlyphTimeline`,
  `SplitStrip`.

- Still absent, because their data or record type does not exist yet: the
  net-worth target line (no goal record), Needs and Wants in the split (the
  category essential tag is not in the schema, `P26-NEEDS-WANTS`), the goals
  progress card (goals are v1.1), the prices and snapshot footer facts, and the
  four-section tab bar (Wealth and Plan screens do not exist).

- Hidden state. Every amount is `MoneyText` or a chart amount text; the hero
  context line and the chart labels are hidden with the number. Counts stay.

- Historical reads. `AccountRepository.balanceAt` now returns Missing for a
  date before the selected anchor, instead of the anchor balance. The 12-month
  series depends on that rule; a month before an anchor is a gap.

- Evidence: `test/features/home/x10_home_test.dart` (2),
  `test/app/demo_home_test.dart` (data from the in-memory demo), and
  `test/golden/design/home_golden_test.dart` (4, dark and light at 1.0 and 2.0).
  At 2.0 the six-digit hero wraps at the group boundary as `HeroAmount` already
  documents; no digit is lost.


### CLOSED-G16-IMPORT-WITHDRAWAL

- Gate: TASKS_PHASE3 G16 "Import staging and withdrawal": preview to Inbox,
  "Undo this import" and batch scope. The printed sources put withdrawal in
  EXECUTION_SAFETY 2.7 and SPEC 8.18 ("Staging is not Undo"), but the boundary,
  the refusal, the counts and the screen states were not written. Sources:
  SCREENS X63, X68; flows F06 steps 5–6, F07 step 5; SPEC 8.18;
  SYSTEM_DESIGN 10; EXECUTION_SAFETY 2.

- Decision (2026-11-23, P3-06). SPEC 8.6 "Import withdrawal (G16)" is
  normative:
  - Scope. One batch: its staged rows and Inbox items only. The batch becomes
    `discarded`, its staged source claims become `discarded`, the publication
    marker stays as evidence and the source identities stay reserved. No
    confirmed payment, other batch, parse configuration, saved layout or
    balance observation changes.
  - Boundary. Only while no item is confirmed. A deleted Inbox item does not
    block it: its claim is already `discarded` and its staged row is gone.
    After one confirmation the batch refuses and writes nothing; that payment
    uses its own Undo or its confirmed batch Undo (8.18).
  - Counts. One transaction removes the remaining undecided items, lowers the
    pending Inbox count by the number of pending items it removes and advances
    `inbox_revision` once. No balance, spending total or net worth changes. No
    partial withdrawal. A repeated call is refused with the withdrawn state.
  - Not Undo. No operation receipt, ChangeLog, compensating posting or Activity
    history entry. A confirmed batch is reversed only by the 8.18 Undo
    (F07-D).
  - States. X68 offers the action while the batch has at least one pending
    item and no confirmed item; after one confirmation it is absent. A
    withdrawn batch leaves the X63 history list and its Inbox rows; the batch
    row and claims stay as evidence. A restart after the commit does not
    restore the rows (F06-C).

- Conflict resolved (AGENTS 9). P3-19's contract line lists ChangeLog, but
  8.18 says staging is not Undo and ChangeLog records confirmed authored
  changes. Winner: a withdrawal writes no ChangeLog; P3-19's contract line is
  corrected in this change. The EXECUTION_SAFETY 2 rule also holds: a batch
  reaches `done` only with no pending candidate; a withdrawal is `discarded`,
  never `done`.

- Consequences. G16 closes; P3-19 builds on the rule and P3-29 follows. The
  built withdrawal already matches the scope and the confirmed-item refusal,
  but it refuses any claim that is not `staged`, so a deleted Inbox item also
  blocks it; P3-19 narrows the refusal to accepted claims. The X68 action state
  (absent after one confirmation) is a screen change outside this gate. No new
  financial rule.

### P3-BALANCE-ROWS

- Gap: TASKS_PHASE3 P3-05 and the G01 row. `CLOSED-G01-ACCOUNT-PREREQUISITES`
  fixed the inclusive anchor and the replay ban, but not how a statement's
  opening and closing rows become observations. The PDF slice detects and
  excludes balance rows and writes no anchor, so the gap stayed open. Sources:
  flows F06 step 4; SPEC 8.6, 4.3; DECISIONS
  `CLOSED-G01-ACCOUNT-PREREQUISITES`; DATABASE_DESIGN 4; table-map 3, 17.

- Decision (2026-11-23, P3-05). SPEC 8.6 "Statement balance rows (G01)" is
  normative:
  - Row kinds. A row is a payment, a credit or a balance; opening, closing and
    available or limit lines are balance rows, and only opening and closing
    balances are account observations.
  - Separation. Balance rows are never Inbox items, never count as new rows and
    never write a payment; Send to Inbox writes no anchor.
  - Acceptance. Its own confirmed command writes one `BalanceSnapshot` (source
    account, local date, account currency, exact minor amount) and selects it.
    Nothing is auto-selected.
  - Inclusive date. The amount is the account balance at the end of its local
    date and already contains every posting on or before it. Imported rows on or
    before that date stay as history and are never counted twice.
  - Covered. A row dated on or before the selected anchor's date writes nothing
    and the import re-adds nothing.
  - Correction. A different amount for the selected anchor's date is a new
    observation with `supersedes_anchor_id`; the pointer moves to it and the
    old row is never updated. A row later than the selected anchor is a new
    observation for its date.
  - Currency. Only the account currency is accepted (10.5).
  - Missing. No balance row, or no acceptance, keeps the selected anchor or
    leaves the balance Missing; an imported row never writes zero.

- Conflict resolved (AGENTS 9). SPEC 9 lists `BalanceSnapshot`; the schema
  stores `balance_anchors` with `inclusive = 1`, `supersedes_anchor_id` and the
  `current_balance_anchors` selection pointer. Winner: one authored observation
  selected by pointer, not a second balance table. No schema change.

- Consequences. P3-05 and the G01 statement sub-rule close; P3-18 can carry the
  balance rows without staging them, and the acceptance remains its own
  confirmed command. The preview acceptance control is a screen change outside
  this gate (SCREENS is not in P3-05's file list); until it lands, the code
  keeps the rows out of staging and writes no anchor, which matches the safety
  rule. `P3-BALANCE-ROWS` closes. The `docs/PHASE3_ACCEPTANCE.md` known-gaps
  line loses it (file-list deviation, T11/T12 precedent). No new financial
  rule; G01 is reused.

### PDF-INTAKE-PICKER

- Decision (2026-11-23, PDF build). The release router mounts
  `PlatformImportFileIntake` over the `contour/import_intake` method channel.
  iOS presents `UIDocumentPickerViewController(forOpeningContentTypes:
  [.pdf], asCopy: true)`; Android opens `ACTION_OPEN_DOCUMENT` for
  `application/pdf`. Both return one file of at most 100 MiB whose first bytes
  are `%PDF-`. The adapter checks the bound and the signature again, holds the
  bytes only in memory, maps a cancel to null and a native refusal to a typed
  `ImportFailure`. The iOS picker deletes its temporary copy after the read.
  There is no permission request, database row, network call or log.

- Why no staging object. The in-app picker runs with the app unlocked and
  reads the file the user chose directly. The protected staging object and its
  key belong to the share path, where the app is not running (SPEC 8.8;
  P3-21, P3-22). This build keeps that path unchanged.

- Scope. This is the X63 "Import a file" path only. The share extension, the
  share intent and the share staging key stay planned (`P3-INTAKE-BINDING`;
  P3-21, P3-22). The debug demo keeps `SyntheticFileIntake`, so the recorded
  `P3-PDF-SUBSET` demo behaviour is unchanged. CSV, Excel, OFX, QIF, CAMT.053,
  MT940, broker files, OCR, QR and receipt photos stay deferred.

- Evidence. `test/app/import_intake_test.dart` (7) and
  `flutter build ios --simulator --debug`. Android is not built here (no
  Android SDK in this environment); its build and emulator evidence stays
  open. The X88 `tooLarge` copy still reads "This file is too large to read."
  and does not name the 100 MB bound; the bound message in SPEC 8.8 stays with
  the share path.

### CLOSED-G08-SHARE-INTAKE

- Gate: flows G08 "Provider capture" and the TASKS_PHASE3 note that "the
  intake bound (bytes, types) is missing". The printed sources fix the
  principle but give no number: SPEC 8.8 says "bounded local bytes",
  "protected staging", "no ledger or database key" and "never resolve remote
  URLs or trigger cloud downloads"; SYSTEM_DESIGN 10 gives the per-format
  parser limits and the staging capability; DATABASE_DESIGN 9–10 give the
  source lease, the staging-key separation, retention and the install epoch;
  EXECUTION_SAFETY 2 keeps parsing private.

- Decision (2026-11-23, P3-02). SPEC 8.8 "Share into the app" is normative:
  - Types. One extension list for iOS and Android: data (CSV, TSV, TXT, OFX,
    QFX, QIF, XML), document (PDF), sheet (XLS, XLSX) and image (JPG, JPEG,
    PNG, HEIC, HEIF, WebP). The first bytes and a successful decode decide;
    the platform UTI/MIME maps to the list.
  - Bound. One file, 100 MiB encoded, the same on both platforms. It is the
    largest parser limit; PDF 50 MiB, image 20 MiB and the XLSX expansion cap
    stay parser limits with their own factual message.
  - Staging. One opaque object, exact bytes, encrypted with the object key,
    written once, no user text in the name, with an authenticated descriptor
    of at most 4 KiB (display name, type, size, digest, time, install epoch,
    lease and key reference). The extension writes no database row and no
    `import_sources` row; the app creates them after unlock and stamps its own
    database epoch. An Android content URI is read once.
  - Protection. iOS complete file protection; Android credential-encrypted
    app-private storage; excluded from backup and device transfer. The device
    must be unlocked; an app lock does not block intake.
  - Key. Random 256 bits per object, wrapped by the platform key store and
    separate from the ledger and recovery keys. The extension holds a staging
    capability and an epoch-scoped writer lease only.
  - Lifetime. Until the app parses the file, the user discards the import, the
    install epoch rotates or a restore replaces the database epoch; no
    wall-clock expiry. Orphans are deleted at the next unlocked start after
    reconciliation, never while a lease is live or unknown. Snapshots omit the
    object and key; a restore marks the batch `sourceNeeded`.
  - Refusal and retry. A factual message per condition, no bytes staged, and a
    new share as the only retry; no queue, background retry or download.

- Conflict resolved (AGENTS 9). The gate asks for one bound, while
  SYSTEM_DESIGN 10 has four per-format limits. Option not taken: per-type
  intake bounds, because each platform would need several admission paths and
  the filter could disagree with the parser. Winner: one 100 MiB intake bound;
  the parser keeps its smaller per-format limits. SPEC 8.8 also says "images"
  without a list, so the decision names the six image extensions.

- Consequences. The intake-bound part of G08 lifts for P3-21 (iOS share
  extension) and P3-22 (Android share intent); P3-20's staging-key adapter
  reads the same key and lifetime rules. `P3-INTAKE-BINDING` stays open:
  the release still mounts `UnavailableFileIntake` until those pull requests
  land. `P3-SHARE-BOUNDS` closes. No new dependency, network path or financial
  rule. F06 step 1 now states the F06-A and F06-D intake sentences, and the
  intake path logs an event name and a count only.

### CLOSED-G15-IMPORT-TEMPLATE

- Gate: TASKS_PHASE3 G15 — "Import template and mapping". It was open because
  the saved-layout contract was absent: no fingerprint input per format, no
  mapping field list, no save rule, no versioning rule and no unsupported state.
  Sources: SPEC 8.6; flows F06 steps 3–4; SCREENS X63, X65, X66, X67;
  SYSTEM_DESIGN 10; DATABASE_DESIGN 5.

- Decision (2026-11-23, P3-01). SPEC 8.6 "Saved layouts" is normative:
  - Identity. One fingerprint per format, and the source account is not part
    of it. CSV and Excel use the header signature: SHA-256, lower-case hex,
    of the normalised header cells, sorted in ascending byte order and joined
    with `U+001F`. Column order is not identity; the mapping applies by header
    name. Delimiter, encoding, header row number, date order, decimal mark,
    sign convention and column mapping are mapping, not identity. PDF uses the
    layout fingerprint: SHA-256 of the normalised detected header line, each
    word's x position in 10 pt bands, and the first page width in whole
    points. The word positions are the word anchors; with the page width and
    the column bands they are the table geometry. No row value, amount, date,
    merchant, account number, file name, file hash or content enters a
    fingerprint.
  - Mapping fields. CSV/Excel: date, details, amount or money out and money
    in, optional balance column, sign convention, decimal mark, date order,
    encoding, delimiter. PDF: date, details and amount bands, optional
    balance band, money-out and money-in words, decimal mark, date order.
    Balance rows stay out of staging (P3-05).
  - Save rule. A template is saved only after a usable preview: one row with a
    date and an amount, and no unresolved password, decryption or parser
    failure. A cancelled, failed or empty preview writes no template and no
    batch. A re-teach writes a newer row; the older row stays for its batches.
  - Version. A template version starts at 1 and names its mapping semantics.
    A parser change that alters them increments the version. A stored template
    that the installed parser does not serve is unsupported: it is never
    reinterpreted or migrated, X65 shows no match, and the next file opens X66
    or X67. Each batch records the parser and template versions it used.

- Conflict resolved (AGENTS 9). SPEC 9 lists `ImportMappingTemplate` and
  `ParserTemplate` as entities, but the reference schema has no such tables.
  Option not taken: add two tables and a migration before any template exists.
  Winner: the logical-entity reading. `import_parse_configs` already holds an
  immutable parser version, identity version, config version and config JSON,
  is append-only by trigger, and is linked from `import_batches` and
  `import_job_inputs` (SYSTEM_DESIGN 10; DATABASE_DESIGN 5, table-map 39).
  `parser_id` is `pdf-template` or `csv-mapping`. This closes the planning gap
  `P3-TEMPLATE-TABLE`; a dedicated table stays a later, reviewed migration.

- Consequences. G15 lifts for F06 steps 3–4 and for P3-08 (header signature
  and column mapping), P3-17 (template storage), P3-27 (CSV mapping) and
  P3-28 (Teach once). `P3-PDF-TEXT` now covers only the text engine: the
  fingerprint input no longer depends on the engine choice, but the engine
  must return text with word x positions and page width. The built PDF reader
  already computes this fingerprint and stores the column bands; P3-08 must
  compute the header signature exactly, and P3-17 stores `csv-mapping` rows
  when the CSV path lands. No new financial rule and no dependency. G15 has no
  row in the flows gate table (it was raised in TASKS_PHASE3 and closes here),
  so no flows table change is made. The P3-01 file list did not name
  `docs/PHASE3_ACCEPTANCE.md`; its known-gaps line loses `P3-TEMPLATE-TABLE`
  in this change (recorded, T11/T12 precedent).

### P3-PDF-SUBSET

- Decision (2026-11-23, owner confirmed in this working session). Phase 3 is
  delivered as a PDF-only import slice. Only a local PDF statement is accepted.
  CSV, Excel, OFX, QFX, QIF, CAMT.053, MT940, QR receipts, receipt photos,
  holdings screenshots, share extensions and the Teach-once layout for any
  other format are not built and have no route, tile or switch. They stay
  planned in `docs/TASKS_PHASE3.md`.

- PDF support. `lib/domain/importers/pdf/` reads objects by scanning `obj`
  bodies (a damaged cross-reference table does not stop a read), expands object
  streams, decodes Flate, ASCIIHex, ASCII85 and RunLength streams with PNG and
  TIFF predictors, and extracts text with `BT`, `Tf`, `Tm`, `Td`, `TD`, `T*`,
  `TL`, `Tj`, `TJ`, `'` and `"`. Fonts: `/ToUnicode` CMaps, WinAnsi and
  `/Differences` glyph names. `/MediaBox` supplies the page width.

- Passwords. The Standard security handler supports RC4 revisions 2, 3 and 4
  (V 1, 2 and 4 with `/CFM /V2`), with user and owner password checks.
  AES-128 (`AESV2`) and AES-256 (`AESV3`, revisions 5 and 6) return
  `unsupportedEncryption`, and X88 states that this version cannot open the
  protection. X64 offers "Remember for this layout": the password goes to the
  platform secure store under a SHA-256 key of the file name, so the key ring
  holds no personal text. A wrong saved password is cleared and the dialog
  returns. A saved password opens the next copy without a question. The
  password never reaches a log, an error or a screen message
  (`SecureImportPasswordStore`).

- Statement rows. A row needs a date and an amount. Sign words (`DR`, `CR`,
  parentheses, trailing minus), thousands and decimal separators, and day-first
  versus month-first numeric dates follow SPEC 8.6 and 4.3. An ambiguous date or
  an amount without decimals is `unsure`. Opening and closing balance lines are
  `balance` rows and are not staged. A balance row that carries a real anchor
  would need P3-05 and is not written (`P3-BALANCE-ROWS`).

- Layouts. A template stores the fingerprint (normalised header text, column
  positions and page width), the column bands and a version. It stores no row
  values and no file content. The next statement with the same header imports
  with no question. A different header does not match. Templates live in
  `import_parse_configs` with `parser_id = 'pdf-template'`; the table is
  append-only, so a re-teach creates a newer row and the newest one wins. A
  dedicated table is a later change (`P3-TEMPLATE-TABLE`).

- Staging. `ImportStagingRepository` writes source identities, the parse
  config, the batch, staged rows, claims and Inbox items, then publishes the
  marker and `inbox_revision` in one transaction. It writes no payment. A
  second import of the same file digest asks first. A row whose source identity
  is known counts as "already in app". Withdrawal removes every staged row until
  one is decided. No new schema table was added; the reference tables from
  version 5 carry the data.

- Intake. The release composition mounts `UnavailableFileIntake`: there is no
  file picker or share binding yet, so choosing a file states that import is not
  available. The debug demo mounts `SyntheticFileIntake` with an in-memory PDF.
  A verified local picker, iOS share extension and Android share intent stay
  planned (`P3-INTAKE-BINDING`).

- Privacy. The PDF bytes stay in memory and are dropped after the send. No
  network call, no source copy on disk and no raw file name in a log or error.
  The import path adds no dependency.


### CLOSED-PHASE2-ACCEPTANCE

- Decision (2026-11-23, owner confirmed in this working session). Phase 2
  (SPEC 17 "Capture, Inbox, Spending", tasks P01–P29) is accepted. Every
  review named in `docs/TASKS_PHASE2.md` closed on 2026-11-23 with the roles
  the task states: product and finance, design and accessibility, privacy and
  security. The acceptance record is `docs/PHASE2_ACCEPTANCE.md`.

- Accepted exceptions, recorded as facts and not as passes. (a) The SPEC 3.1
  three-tap target is not met: the X20 harness measured four activations after
  the account choice, and no device run exists. The three-tap claim is not
  made in any string or document. (b) `P24-ENGINE-EVIDENCE` stays open: no
  verified on-device speech engine and no airplane-mode run of the nine SPEC
  8.10 sentences. Voice ships behind `UnavailableSpeechPort` and the typed
  entry path. (c) `flutter test integration_test` was not run on this host.

- The device gates keep their Phase 1 status and are not closed by this
  acceptance: `PF-01`, DB-A, DB-B, `T07-CIPHER-BUILD`, the T08/T11 native
  bindings and `P21-UNWIRED-GATEWAY`. Personal-data persistence stays off
  until `PF-01` and the cipher gate close, as AGENTS 2.1 requires.

- The Phase 2 planning gaps (`P2-INBOX-PRODUCER`, `P2-SPEND-NEXT-INCOME`,
  `P2-SEARCH-ENTRY`, `P2-TRANSFER-BOUNDARY`) and the follow-up ids in
  `docs/TASKS_PHASE2.md` stay open. They move to the phase that owns them and
  do not block Phase 3 planning.


### P14-ACCOUNTS

- DECISIONS CLOSED-G01 is the contract: an anchor is the balance at the end
  of its local date, inclusive; the balance is anchor plus accepted postings
  strictly after that date; no selected anchor is Missing, never zero; an
  entered zero is a real anchor; a correction adds an observation with
  `supersedes_anchor_id` and moves the selected pointer in the same command.

- Sign. The stored anchor and transaction amounts are signed, so a liability
  account carries a negative balance (Visa -1,240 in the sample) and the
  screen shows the owed amount as its positive value. This follows the signed
  posting rule (P09) and the net worth "own - owe" rule (SPEC 4.4). It is
  recorded because the printed G01 text says "signed per SPEC 6.6" without
  naming the storage sign.

- Writes go through the command writer (`CreateAccount`,
  `SetOpeningBalance`, `SelectAnchor`), write the ChangeLog entry and advance
  the account dependency revision. The anchor row is never rewritten.

### P12-CLASSIFICATION

- SPEC 9.3 / DATABASE_DESIGN 4.1, 5: schema version 6 adds `category_rules`,
  `tags` and `transaction_tags` in one small migration. Rules and tags are
  authored rows with the reference identity, audit, revision and retain
  guards plus the insert trigger that registers them for history.
  `transaction_tags` is a bridge keyed by its two foreign keys, like
  `event_attachments`; it is not an authored entity and writes no ChangeLog
  row of its own. `tags.name` is unique while live.

- Upgrade path. A fresh vault runs the reference version 5 body and then
  migration 6. A version 5 vault upgrades in one transaction inside
  `verifyExistingVault`; a failed upgrade rolls back every object, keeps the
  version at 5 and throws `SchemaError(migrationFailed)`. Versions below 5
  still fail closed (DB-B: the reference scripts are absent).

- Q01–Q04. P12 delivers Q01 (account payment page, keyset) and the exact
  category totals that count split contributions once (Q11 shape). Q02 and
  Q04 (selected-account filters and candidate matching) belong to P17, and
  Q09–Q12 projection reads to P15, because both need the staging and
  projection tables those tasks own. Recorded so the query contract is not
  claimed twice.

- Write contract. A repository returns a `WritePlan`: the ChangeLog entries
  and a closure that writes inside the command transaction. A payment creates
  one ChangeLog entry for the event, one for the payment and one per split;
  tag links are bridge rows. The account dependency revision advances once per
  command. The financial event takes the running operation id, so the plan
  reads the single running intent (the writer runs one command at a time).

- Finding for the next schema change. `spec-data-model.md` lists
  `Category.isEssential` (the needs/wants tag), but version 5 and migration 6
  have no such column, and `transactions` has no `reimbursementStatus` column
  (P07 records that one). P08 computes needs and wants from the row tag, so a
  screen cannot yet read the tag from the vault. The migration owner (P15 or
  the phase's next schema change) adds `isEssential` to `categories` and the
  reimbursement status in one small migration, with the same guards. No
  value is guessed in the meantime.

### P13-DRAFTS

- SPEC 8.16 / DATABASE_DESIGN 6: the editable draft lives in
  `draft_headers`, `draft_payloads` and `draft_references`. Each save
  increments `edit_revision`; the payload is bounded at 256 KiB; a draft of
  an older database epoch is not offered; Discard deletes the payload and
  references; an unreadable payload keeps its bytes and becomes
  `unsupported`, where only Discard remains.

- Identity is the draft ID and the form type. Version 5 has no source column,
  and the printed contract names no source, so several drafts of one type
  coexist and the form offers the most recent editing one. The earlier
  P01 note that said "form type and source" is corrected here.

- Save. `CommandRepository.saveDraft` is the manual Save. It allocates the
  operation ID when the draft has no active attempt, reuses the submitted one
  after a crash, and returns the recorded receipt after a commit, so a
  repeated tap runs nothing twice. A payload that differs from the frozen
  attempt fails with `digestMismatch`; a second attempt for one draft fails
  with `invalidState` (one unresolved intent per draft). The commit clears
  the draft payload and references in the same transaction.

- Recovery. T07's `execute` leaves a failed attempt `submitted`, which its
  test asserts. `releaseUncommitted` is the explicit recovery: after a proven
  uncommitted failure it marks the attempt `rejected` and returns the draft to
  `editing`, so the next Save allocates a new operation ID (DATABASE_DESIGN 6).
  P22 calls it on a typed failure; a lost response resolves through the
  receipt instead.

- Payment effects are not part of this task. P12 writes the transaction and
  its links, and P22 supplies the form and its codec; P13 proves the draft
  lifecycle and the commit envelope with a neutral authored row.

- Log privacy (AGENTS 2.6): no payload value is logged or printed. Draft and
  command errors carry a safe code only.

### P11-PERIODS

- SPEC 6.5: the chips cover these ranges. 1W is the last seven days including
  today (a rolling week; the Monday start belongs to the calendar grid in
  X22). 1M is the current budget month to date. For multi-month chips,
  spending counts complete months only, because a monthly limit has no closed
  value for a partial month, while money in ends with the current month to
  date. So spending 6M is the last six complete months, spending 1Y the last
  twelve, money-in 6M is six months to date and money-in 1Y twelve months to
  date. The 1M chip includes the partial month in both cases.

- Conflict recorded (AGENTS 9). X30's 6M sample reads "May-Sep 2026, $21,080
  of $26,000, AVG $4,216", which is five months and five limits, while the
  chip is 6M. Under this rule the window is Apr-Sep 2026: $24,480 of $31,200,
  AVG $4,080. The 1Y sample ("Oct 2025-Sep 2026", 12 months, 62,400 = 12
  limits) and the 12-month average of 4,005 both support the rule, so the 6M
  sample is one month short. Preferred: keep the rule. P26 recomputes the 6M
  values, and the design sample needs its own documentation correction.

- Month gone uses `(day number - 1 + share of today) / days` (4.4). The app
  boundary supplies the part of today elapsed; the domain never reads the
  clock. 13 October in a 31-day month is 41.94% at day end, shown as 42%. The
  same value is 38.71% at the start of the day and 40.32% at midday.

- A start day above a month's length uses that month's last day (31 starts on
  28/29 February, 30 April), so no month is skipped. The start day is inside
  the current month when today is on or after it, otherwise the month began
  in the previous calendar month.

- Same days last month keeps the current day number and stops at the previous
  month's last day (31 March compares with 1-28 February).

### P10-QUICK-ADD

- SPEC 8.3 / 8.10: the parser is pure text in, draft out, with no model, no
  network and no database. The caller supplies the day, the main currency,
  the known merchants, the keyword category table and the numeric-date order,
  so no locale or category is hard-coded and no user data leaves the phone.

- Merchant matching is normalised equality (case, spaces and punctuation
  ignored): "star bucks" resolves to "Starbucks". No edit-distance or
  model-based match is added, because a wrong merchant is a wrong record and
  the app must not guess.

- Category precedence: an explicit "#tag", then "for"/"on" plus a word, then
  a keyword rule from the caller's table, then the income fallback "Income"
  when the sentence reads as money in. The parser never invents another
  category. P28 supplies the default keyword rules; this task owns only the
  lookup.

- Spoken amounts: whole numbers 0-99 in words; a tens word after a whole
  amount reads as the minor part ("twelve fifty" = 12.50); a unit after a
  tens word is a compound ("forty two" = 42). A number word or digit before
  a time unit ("two days ago") belongs to the date, not the amount.

- Dates: today, yesterday, a weekday (most recent past), "last <weekday>",
  "<n> days ago", "-<n>d", "12 Oct [year]" and "12/10" with the day-first
  setting. A bare day and month resolve to the most recent occurrence not
  after today, because a Phase 2 payment date is never in the future
  (X22). An impossible date leaves today and is not guessed.

- One payment per sentence. A second amount ends the first draft's text: the
  first clause is parsed and the second amount is reported separately
  ("40 at Starbucks and 12 for parking" gives 40 at Starbucks and a second
  12), so the second clause never leaks a category or merchant into the
  first payment (SPEC 8.10).

- Confidence: an explicit amount, date, merchant, "#" category or "@" account
  is filled; a spoken account ("with", "using", "on my") is unsure, because a
  spoken account name needs a check (X25). Absent fields stay absent; the
  amount is never filled with zero.

### P09-PAYMENT-CLASSIFICATION

- SPEC 4.2 / 4.10 / 4.11 / 8.17: the classifier writes signed postings. A
  posting is negative when money leaves the account and positive when it
  enters it, so a card purchase is negative on the card and a payment to the
  card is positive there (DATABASE_DESIGN 4.2, G01-B). A transfer writes one
  debit, one credit and at most one fee posting. Net worth sums only postings
  on accounts in scope, so a transfer inside the scope is zero (F05-A) and a
  boundary transfer leaves a real change (F05-E; its attribution stays Missing
  under P2-TRANSFER-BOUNDARY).

- Cross-currency transfers are rejected in this phase. X26b and the v1.1
  release own them; a guessed mid-rate is forbidden (F05 recovery).

- A refund is rejected when it is larger than the original payment minus its
  earlier refunds. A refund cannot return more than was paid, and clamping it
  would invent an amount. A full refund leaves a known zero, which is not the
  same as no refund (F08-D).

- A split part is positive and names a category; the parts must equal the
  total exactly. An unbalanced split reports the remainder (positive or
  negative) so X23 can disable Save; it never rounds or clamps (SPEC 4.1).

- A receipt larger than the expectation keeps its unallocated part and
  applies only the remainder (4.11, 8.17). A reversal reopens the remainder of
  the applied amount and leaves later receipts accounted for.

### P08-SPENDING-NUMBERS

- SPEC 4.4 / Appendix B: needs and wants are "the two parts of spent, from
  the user's category tag (isEssential)". A payment may have no category
  (SPEC 6.3 allows it), so its tag is unknown. Guessing a tag would be a
  judgement the app must not make (SPEC 2, 4.3). Decision: money out is
  partitioned into needs, wants and unclassified; an amount without a
  category is unclassified. The split adds to exactly 100% when spending is
  positive (SPEC 4.1). Appendix A has no unclassified amount, so the sample
  stays 73.4 / 26.6 / 0.

- Averages. The average helper takes complete months and is generic, so money
  in reuses it. 111,200 / 12 = 9,266.67 in minor units; the screen shows
  "$9,267" at 0 decimal places (Appendix B: cents only where they matter).
  Rounding is half to even (SPEC 4.1).

- Fixture scope. Only October's category rows are printed. The other complete
  months carry their printed totals as one row each; the per-category 12-month
  history is not printed. P08 therefore asserts October's category rows and
  the printed totals (3,940 / 5,200 / 4,005 average / 21,080 over 6 months /
  48,060 over 12 months). P26 must extend the fixture to reproduce the printed
  per-category averages (1,800 / 700 / 520 / 240 / 300 / 205 / 150 / 90) before
  its goldens.

- Month gone and the same-days comparison are P11 (periods), not P08, to keep
  one owner for the budget month. P08's plan line is adjusted.

### CLOSED-P2-REFUND-EXPECTATIONS

- Open question P2-REFUND-PERIOD (recorded 2026-11-22, P07). F08 step 6
  recognised a refund under a "selected refund recognition period" and left
  partial settlement, attribution and reversal "behind G14". SPEC 4.2 already
  fixes the period (the refund month by default, with a purchase-month
  setting); the expectation record, partial receipt and reversal were
  undefined. Sources: flows F08 step 6 and checks D–F; SPEC 4.2, 4.3, 4.4,
  4.9; SCREENS X31, X39; spec-data-model 9.3, 9.9.

- Decision (2026-11-22, P07). SPEC 4.11 is the normative rule:
  - Refund and reimbursement are different. A refund reduces spending in the
    original category under the period setting. A reimbursable payment is not
    personal spending from its own date.
  - One reason per payment. Reimbursable and Refund expected are exclusive;
    turning one on clears the other and its open expectation. A payment
    cannot be both, so one amount is never counted twice.
  - Expectation. A known incoming amount with an optional date, a kind
    (reimbursement, refund, deposit, other money owed) and a typed link to its
    payment when there is one. It is Expected: not cash, not income, not net
    worth. "Owed to you" lists it.
  - Partial receipt and reversal. Each confirmed receipt reduces the
    remainder once (8.17's rule); a reversal is a compensating posting dated
    when it happens and reopens the remainder (8.18).
  - Cancel. While nothing is confirmed, an expectation can be cancelled; a
    reimbursable payment then counts as spending from its own date, recorded,
    not silent.
  - Passed dates stay facts; no "overdue" wording (SPEC 2).

- Storage mapping (preferred, for P12 and P16). An expectation is an incoming
  obligation (`obligations.direction = 'in'`) with settlement allocations
  (8.17); a merchant refund uses `refund_links`, which already carries a
  partial amount. `transactions` version 5 has no reimbursement kind and no
  `reimbursementStatus` column, although spec-data-model 9.3 lists both, so
  P12 adds the status (or a distinct kind) in its migration and records the
  choice. No new table is needed for an expectation.

- Also added. Settings > Money gains the "Refunds" row (refund month default,
  purchase month option), which 4.2 referenced but no screen listed. X39's
  two toggles are marked exclusive.

- Consequences. The P2-REFUND-PERIOD open question is closed. P08 and P09 may
  apply the rules; P12 adds the reimbursement status in its migration; P27
  builds the two toggles, the expectation rows and the cancellation path; P26
  shows "Owed to you" in the Money in sources with its Expected state.

### CLOSED-G13-TRANSFER-FEES

- Gate: flows G13 — "SPEC 6.3 can treat charged fee plus calculated exchange
  spread as a fee posting". Selected correction: post the actual charged fee
  once; show the exchange spread as a comparison only; reconcile fee
  classification with spending and net worth first. Sources: flows F05;
  SPEC 4.2, 4.4, 4.5; SYSTEM_DESIGN 5.3; DATABASE_DESIGN 4.2, 6; SCREENS X26,
  X26b.

- What the printed sources already fixed: a transfer links its two principal
  postings and any documented fee once through typed links (SYSTEM_DESIGN
  5.3; DATABASE_DESIGN 4.2, 6); a fee is also its own fee transaction
  (spec-data-model 9.3); a transfer principal is never income or spending
  (SPEC 4.2); investment buy fees and taxes are in cost basis and sale fees
  reduce proceeds (SPEC 4.5); the X26b sample gives fee $12.00 and spread
  $5.96, with a saved cost of the fee only.

- Decision (2026-11-22, P06). SPEC 4.10 is the normative rule:
  - The charged fee is money out. It reduces cash and net worth and counts in
    Spent and Kept. This is the only classification where the four-part net
    worth bridge stays exact: if the fee left cash but not Kept, the bridge
    would not add up, and NUM-001 forbids a residual.
  - The spread is a comparison. It is never posted and never part of money
    out. The displayed total may add both; the saved cost is the fee.
  - A capitalised investment fee is not money out. It is part of Invested, or
    it reduces sale proceeds, and it does not change net worth by itself.
  - One fee per event; a repeated Save returns the first result (F05-D).

- Conflict recorded (AGENTS 9). Sources: SCREENS X26b's caption "Saved as a
  fee, not as spending" reads as "fees are not in Spent"; SPEC 4.4 defines
  Spent as money out and the bridge needs the fee in Kept. Winner: SPEC 4.4,
  SPEC 4.7 (NUM-001, no residual) and the printed fee-in-cost-basis rule.
  Effect: the X26b caption now reads "Saved as a fee, not as part of the
  transfer". No amount changes.

- Consequences. G13 lifts for F05. P23 builds X26, which has no fee field in
  Phase 2: a same-currency transfer fee enters from X26b (v1.1) or from a
  captured or imported fee. F05-D is exercised with a synthetic fee posting at
  domain and repository level. The boundary-transfer attribution is a new
  open question, P2-TRANSFER-BOUNDARY, and 4.10 shows it as Missing until it
  closes. The flows gate table keeps its G13 row (G01/G14 precedent).

### CLOSED-G07-LOCAL-ENGINES

- Gate: flows G07 — "ML Kit metrics and the generic Android offline preference
  conflict with the network policy". Selected correction: verified local
  engines only; no cloud fallback; unsupported devices keep typed or file
  entry. Sources: flows F04, F06, F12, F19; SPEC 8.4, 8.5, 8.10, 10.5;
  SYSTEM_DESIGN 10.

- What the printed sources already fixed: SYSTEM_DESIGN 10 excludes ML Kit
  because its terms include network metrics, requires Apple Vision and
  audited bundled Android engines, requires bundled models that are never
  app-downloaded, and stops capture and clears audio on lock or background;
  SPEC 8.10 requires the on-device speech APIs, an explicit availability
  check (the offline preference flag is not enough), the unavailable message
  and typed entry; SPEC 8.4 and 8.5 require local OCR and decoding with no
  telemetry, model download or cloud fallback; SPEC 10.5 forbids cloud OCR
  and speech.

- Decision (2026-11-22, P05). SPEC 8.19 is the normative engine policy. It
  defines "verified" as five conditions: an exposed on-device mode, a
  recorded network-off test on each supported OS version, telemetry off or
  absent, a dependency licence and network statement in DECISIONS, and an
  explicit availability API. It adds the evidence each engine task must
  record, the permission order, the data and output rules, and the rule that
  an engine which cannot meet them is removed rather than downgraded to a
  remote call.

- Conflict resolved (AGENTS 9). Sources: the gate names ML Kit metrics
  against the network policy; SYSTEM_DESIGN 10 excludes ML Kit. Option not
  taken: use ML Kit with metrics disabled, because its terms include network
  metrics and the app cannot prove their absence on every device. Winner:
  SYSTEM_DESIGN 10 and the local-first rule (SPEC 2). ML Kit stays excluded.

- Consequences. G07 lifts for F04 (voice, Phase 2), F06 and F12 (OCR and
  holdings screenshot, Phase 3) and F19 (capture sources, v1.1). Per-engine
  verification evidence stays with its task, led by P24 for voice; no
  dependency is added by this documents change. Android 8–11 has no verified
  speech path in this phase and keeps typed entry. The flows gate table keeps
  its G07 row (G01/G14 precedent).

### CLOSED-G06-UNDO-HISTORY

- Gate: flows G06 — "SPEC gives only a five-second toast". Selected
  correction: keep the toast and add persistent history access; undo a
  complete event or batch; keep later dependent edits; open an explicit
  resolution flow (UX-010). Sources: flows shared contract and C06, F07 step
  5, F08; SYSTEM_DESIGN 6; DATABASE_DESIGN 6; SCREENS X37, X39b.

- What the printed sources already fixed: Undo is a new command on the whole
  event or batch, it checks current revisions and downstream references, and
  it never writes old values over later edits or frees a source identity
  (SYSTEM_DESIGN 6); a compensating command keeps tombstones and receipt
  identity and never replays stored JSON (DATABASE_DESIGN 6); a repeated
  decision appends a compensating decision (DATABASE_DESIGN 4.3); soft
  deletion keeps files that Undo needs (SYSTEM_DESIGN 6, DATABASE_DESIGN 10);
  the toast lasts 5 seconds with one Undo (DESIGN 6.6; X39b).

- Decision (2026-11-22, P04). SPEC 8.18 is the normative contract. Three
  points needed an explicit reading:
  - Entry point. Persistent history opens from Settings > App > Activity
    history (C06). C06 is an implementation contract with no screen id, so
    one settings row is named and X80 gains it.
  - Scope. Undo applies to confirmed financial events and batches. A
    settings, layout, category or rule change is corrected by editing it
    again, because none of them forms a financial event. The widget editor's
    own Undo reverses one pre-Done session action and is not history
    (DATABASE_DESIGN 5.1).
  - Dependencies. A blocking later record stops Undo and writes nothing; the
    dependency sheet names it and the user resolves it with its own controls.
    Undo never edits or deletes a dependent record on the user's behalf. This
    is the conservative reading of "open an explicit resolution flow" and "no
    arbitrary overwrite" (C06).

- Consequences. G06 lifts for every confirmed write. P22, P23 and P27 show
  the toast; P17 undoes a whole confirm batch; P28 undoes an occurrence
  decision; P29 builds Activity history and its dependency sheet, and adds
  the X80 row. The history has no age limit; only the toast has 5 seconds.
  The flows gate table keeps its G06 row (G01/G14 precedent).

### CLOSED-G05-ENTRY-ACTION-ORDER

- Gate: flows G05 — "Home priority/chooser rules conflict; entry controls
  and Inbox primary-action precedence are incomplete; Repeating uses general
  expense Add". Selected correction: reconcile the combined Home
  hero/chooser scope; search below the Home title; the main number in
  Settings; Repeating Add opens a schedule form; an unresolved Inbox
  decision owns the primary action and Confirm is secondary until decisions
  are resolved. Sources: flows F02, F07, F09, F19; SPEC 3.3, 4.6, 5.1–5.3;
  SCREENS X10, X13, X29, X34, X60, X80.

- What the printed sources already fixed: the tab Add table (5.3), the Add
  chooser order (X29, shared contract 4), the Inbox precedence sentence
  (shared contract, F07 step 3), Repeating as its own screen with Back
  (5.2), and the settings group "Screens and widgets" (X80).

- Conflicts found and resolved (AGENTS 9):
  - Home search. SPEC 5.1 said "Home has no Search"; F02 step 4 and SCREENS
    X10 put a Search field below the Home title. Winner: the selected G05
    correction and the two screen sources. 5.1 now says the field exists.
  - Main number path. The G05 correction says "Settings > App > Home"; F02,
    X13 and X80 say "Settings > Screens and widgets > Main number on Home",
    and X80 has no "App > Home" section. Winner: the screen sources. The
    path is "Screens and widgets".
  - Hero versus chooser. SCREENS X10 and spec-screens 6.2 call net worth "the
    hero", while X13 chooses one of four numbers. Winner: X13 and F02 step 4
    (the chooser exists). The hero is the chosen main number, net worth by
    default; the net-worth target line, 12-month figure and chart stay with
    net worth.
  - Inbox primary action. X60 drew ghost decision buttons and a filled
    Confirm bar, so Confirm filled while a decision was open. Winner: the G05
    correction and 3.3 (one filled action). The open decision's affirmative
    choice is filled; Confirm is ghost until no decision remains.
  - Calendar Add. 5.3 gives Plan > Calendar a repeating option first; F14
    step 1 and C02 give a calendar day a dated one-off payment with an
    explicit repeating choice. Both stand: the tab-level Add keeps 5.3, a day
    sheet opens the dated payment form.
  - Repeating Add. 5.3 sent every Spending Add to the expense form. Winner:
    the G05 correction. X34 and X35 open C02.

- Decision (2026-11-22, P03). SPEC 5.5 is the normative entry and action
  order. It states the filled-action precedence, the Inbox order, the Add
  overrides (Repeating, calendar day), the voice long-press, disabled
  entries, the search entries, the four main-number options, and that the
  main number is never a widget. It closes GLANCE-ORDER: the chosen main
  number is first, 4.6 is the default order below it, and a saved layout
  replaces that order.

- Consequences. G05 lifts for F02, F07, F09 and F19. P22, P23 and P24 use
  the Add context; P25 uses the Inbox order; P28 uses the Repeating Add;
  Phase 4 Home implements the main-number choice. X60 now states the filled
  and ghost buttons, and spec-screens 6.2 states the chosen hero. The flows
  gate table keeps its G05 row (G01/G14 precedent).

### CLOSED-G02-OCCURRENCES-MATCHING

- Gate: flows G02 — "content hashes and autoCreate can suppress real events
  or create actual payments from schedules". Selected correction: source
  identity supports retries; equal content is only a match candidate; track
  one Expected occurrence and its unpaid remainder; require confirmation or
  an accepted matching record; define one-off future payments apart from
  recurrence. Sources: flows F05–F07, F09, F13–F14; SPEC 8.9, 4.3, 4.9;
  SYSTEM_DESIGN 5.3; DATABASE_DESIGN 4.3, 6.

- What the printed sources already fixed: `SourceIdentity` and the uniqueness
  tuple (DATABASE_DESIGN 6); `ScheduledOccurrence` with a captured rule
  revision, `SettlementAllocation`, one canonical obligation (SYSTEM_DESIGN
  5.3); occurrence identity, rule-edit reconciliation, bounded generation,
  decision records, settlement remainder and typed aliases (DATABASE_DESIGN
  4.3); the dedupe fingerprint and near-duplicate rule (SPEC 8.9); the
  schedules, locators, obligations, settlements and decision tables in
  SCHEMA.sql.

- Decision (2026-11-22, P02). SPEC 8.17 is the normative contract. Two
  points needed an explicit reading:
  - Review path, not creation. The schedule option "Add it to the Inbox to
    confirm" (`autoCreate`) chooses where a due proposal waits: in the Inbox,
    or on its own detail with one confirm action. Both routes use the same
    confirmation command. No setting writes an actual payment without a
    confirmation.
  - One-off apart from recurrence. A dated payment that happens once is
    created with recurrence off and keeps its own obligation identity. It is
    not a rule with one occurrence and never generates a second one.

- Conflict recorded (AGENTS 9). Sources: SPEC 8.9 ("`autoCreate = false` →
  Inbox item") and SCREENS X35 ("Off: added automatically") imply that the
  option can create an actual payment; DATABASE_DESIGN 4.3 ("generating an
  occurrence never creates an accepted payment") and the selected G02
  correction require a confirmation. Winner: SPEC 2 (data only, trusted
  records), SPEC 4.3 ("Expected is never in totals") and DATABASE_DESIGN 4.3.
  Effect: X35's caption now reads "Off: confirm it here"; P28 implements and
  checks it. No other screen text changes.

- Consequence. G02 lifts for F05–F07 and F09, and for F13–F14 when those
  phases plan. `schedules.auto_create` is absent from SCHEMA.sql version 5
  and from table-map.md, so P16 adds it in the schedule-family migration,
  with the same review-path meaning. P16, P17, P23, P25 and P28 consume SPEC
  8.17. The flows gate table keeps its G02 row (G01/G14 precedent); the four
  behavioural lines now cite SPEC 8.17.

### CLOSED-G12-DRAFT-LIFECYCLE

- Gate: flows G12 — "no durable-draft contract for Close, process death and
  multiple unfinished forms". Selected correction: encrypted drafts keep only
  structured editable fields; Back/Close keeps them; explicit Discard deletes
  them; Save clears them after commit; no automatic expiry; separate draft
  IDs; schema-aware migration. Source: flows G12, F03–F06, F10, F15–F17;
  SPEC 8.1; SYSTEM_DESIGN 5.2; DATABASE_DESIGN 6, 10.

- What the printed sources already fixed: SYSTEM_DESIGN 5.2 (own ID, form
  type, schema version, referenced revisions, no expiry, no overwrite, Save
  clears in the confirmed transaction, migration or unsupported state,
  restore invalidation); DATABASE_DESIGN 6 (intent before submission,
  receipt-first retry, one unresolved intent per draft, 256 KiB payload
  chunks) and 10 item 4 (unsupported payload); the draft tables in
  SCHEMA.sql (`draft_headers` status editing/submitted/committed/discarded/
  unsupported with DB epoch and edit revision, `draft_payloads` ≤ 256 KiB,
  `draft_references` with expected revisions, `draft_attachments`). The
  flows' shared contract already stated the user-visible behaviour.

- Decision (2026-11-22, P01). SPEC 8.16 is the normative draft contract. Two
  points were not printed; each is a direct consequence of the selected
  correction, not a new financial or privacy rule:
  - Durability boundary. A field value is written at field commit (focus
    loss, a sheet returns Done, or amount entry ends when the keypad is
    dismissed or another field takes focus) and before background or lock;
    never per keystroke or per keypad digit. The correction requires
    process-death recovery, and without a stated boundary no test can tell
    whether the draft was lost.
  - Coexistence. Every draft has its own ID and form type; a capture never
    replaces a kept draft. A form offers the kept draft of its type (most
    recent first), a new draft starts only by explicit choice, and C11 lists
    every kept draft. This follows "separate draft IDs" and "Resume never
    overwrites another draft". (P13: version 5 has no draft source column, so
    the identity is the ID and the form type; the SPEC text already names no
    source.)

- Also stated in 8.16, from printed text: the draft fields per Phase 2 editor
  (from the screen sections and spec-data-model 9.2/9.3), no audio,
  transcript, raw file or password in a draft (SPEC 8.10, 10.5, F04), the
  submitted/committed/rollback states with one operation ID (SYSTEM_DESIGN 6,
  DATABASE_DESIGN 6), the 256 KiB bound as a field validation failure, and
  restore invalidation (SYSTEM_DESIGN 13.2).

- Consequences. G12 no longer blocks F03–F06, F10 or F15–F17. P13 builds the
  draft repository and the manual Save command against 8.16; P21 (account
  editor), P22, P23, P24 and P28 consume it. Migration and rollback tests stay
  P13 evidence, so DB-B (absent reference upgrade scripts) is unaffected. The
  flows gate table keeps its G12 row as the record of the original gap,
  matching the G01 and G14 precedents; its behavioural text now cites SPEC
  8.16.

### FIXED-SCREEN-MATERIAL-ANCESTOR

- Found 2026-11-22 while running the app on an iOS simulator (the first
  on-device use). Every Phase 1 screen renders its text without a
  `Material` widget ancestor: `PageBackground` (the page canvas under all
  three layout templates and X01) painted only a `DecoratedBox`, and no
  template adds a `Scaffold` or `Material`. On a device build with Flutter
  3.47 the text paints with the framework's error pattern (red text, yellow
  double underline) and `AppIconButton` (which asserts a `Material`
  ancestor) would fail. The committed goldens hid the gap: the golden
  harness wraps every screen in `Material(type: transparency)`, so the host
  tests never saw the app's real shell.
- Fix (design-system change): `PageBackground` now provides the page's
  `Material(type: MaterialType.transparency)` itself, so every template and
  screen inherits the required ancestor from one place. Verified on the
  iPhone 18 Pro simulator: X01 renders exactly as the approved dark golden.
  `flutter analyze` clean; `flutter test` 345 pass; the 33 goldens are
  unchanged (the harness wrapper and the new in-app wrapper now match, and
  double-transparent Materials paint nothing).
- Consequence: the golden harness's `Material` wrapper stays (it simulates
  the app shell); a future template change must keep the Material ancestor
  on the page canvas, not re-introduce it per screen.

### CR-19-NATIVE-BINDINGS

- Decision (2026-11-22, Track A device-gate implementation). The T08
  platform bindings and the T11 exclusion channel are implemented behind
  their reviewed ports; the app composition stays deliberately unwired
  until PF-01 and DB-A close (no real-user persistence on a noncompliant
  path; Phase 1 screens carry no records):
  - `PlatformAuthPort` (`lib/app/auth/platform_auth_port.dart`) runs the
    OS challenge through `local_auth` and maps the typed native codes to
    the port outcomes; the attempt tuple stays with `LockController`.
  - `SecureKeyStore` (`lib/data/keys/secure_key_store.dart`) implements the
    sync `KeyStore` port with a documented preload + write-through + flush
    contract (the port is sync, the platform store is async). iOS stores
    the key as a Keychain item with `WhenUnlockedThisDeviceOnly`, never
    synchronised; Android uses hardware-backed KeyStore AES-GCM storage
    with `resetOnError = false` (a platform error never erases the key).
    `VaultKey.fromBytes` was added for the preload (exact 32 bytes).
  - `FileControlStore` (`lib/app/auth/file_control_store.dart`) implements
    the sync `LifecycleControlStore` port over one small file: temp file,
    flush, atomic same-directory rename; missing/unreadable/unsupported
    never substitute a default. dart:io exposes no fsync; device
    durability and iOS file protection stay with S06.
  - `NativeBackupExclusions` (`lib/data/backup/backup_exclusions_native.dart`)
    applies every path kind's exclusion at `open` over the
    `contour/backup_exclusions` method channel and re-fires single kinds as
    write-through. The iOS handler sets `isExcludedFromBackupKey`
    (ios/Runner/AppDelegate.swift); the Android handler reports the
    manifest-level truth (`allowBackup="false"` + extraction rules,
    android/.../MainActivity.kt). The Android runner now extends
    `FlutterFragmentActivity` (the `local_auth` requirement) and the
    manifest adds only `USE_BIOMETRIC`; iOS Info.plist adds
    `NSFaceIDUsageDescription`. The X02 unlock prompt string went to l10n
    (`x02UnlockPrompt`).
  - Packages (AGENTS 6.8): `local_auth 3.0.2` (BSD-3-Clause, Flutter
    Authors) and `flutter_secure_storage 11.2.0` (BSD-3-Clause). Both run
    fully on device, make no network calls, and had releases within the
    last 12 months.
  - Host checks: `flutter analyze` clean; `custom_lint` clean; `check_tokens`
    OK; `check_contrast` OK (545 pairs); `flutter test` 345 pass (26 new:
    outcome mapping, key store preload/flush/fail-closed, control store
    round-trip/atomic write, exclusions apply-at-open/failure).
  - Build evidence: the iOS simulator build succeeds (`flutter build ios
    --simulator --debug`, 45 s), which compiles the new AppDelegate channel
    glue and both plugin pods. The Android build cannot run on this host
    (no Android SDK); its compile check (FlutterFragmentActivity + channel)
    stays with the device gate. The integration smoke-test rerun timed out
    on this host and is inconclusive; T12's earlier documented pass stands
    and the app runtime is unchanged (the composition stays unwired).
  - Still open (device gates, unchanged in force): DB-A (the pinned
    SQLCipher native build + FFI verification; `sqlcipher_flutter_libs`
    stays forbidden, no build wiring was attempted), DB-B
    (T07-MIGRATION-SOURCES: the reference upgrade scripts and frozen
    fixtures are absent from this checkout and cannot be invented),
    T07-TYPED-TABLES (lands with the first typed read in Phase 2), S06
    (auth/keychain/control device evidence), S01 (cipher and
    backup/transfer device evidence), the real delete-all sequence (F21
    device work), and PF-01.

### CLOSED-G01-ACCOUNT-PREREQUISITES

- G01 asks for two definitions before basic bank, cash and card setup plus
  opening balances move to the base phase: the inclusive balance anchor and
  the accepted postings after it (docs/flow.md, USAGE_FLOWS_REFERENCE G01).
  The printed architecture already fixes most of it: `BalanceAnchor` is an
  immutable inclusive dated observation, balance = anchor plus later
  accepted postings (SYSTEM_DESIGN 6.2, G01); observations never rewrite,
  a correction adds an observation and moves the selected pointer, and the
  explicit selection is authoritative (DATABASE_DESIGN 4); the schema fixes
  `balance_anchors.inclusive = 1` with `supersedes_anchor_id`; the current
  anchor per account is an explicit selection row (table-map 3, 17).
  DECISION-PENDING: G01-ACCOUNT-PREREQUISITES.

- Decision (2026-11-22, owner delegated this session; "research and
  choose"). The remaining definitions follow from the printed rules:
  - G01-A. Inclusive anchor. A balance anchor is the account's balance as at
    the end of its local calendar date, inclusive of every posting dated on
    or before that date. Its `balance_minor` already contains them; no
    posting dated on or before the anchor date is ever re-added. This is the
    `inclusive = 1` the schema already enforces.
  - G01-B. Accepted postings. A posting is accepted for balance purposes
    when it is a confirmed actual record (never Expected, never an
    estimate), and its date is strictly after the selected anchor's date.
    `balance(account, cut-off) = anchor.balance_minor + sum of accepted
    postings with anchor.date < posting date <= cut-off`, all in the
    anchor's currency; signed per SPEC 6.6 liability rules. Expected
    occurrences and valuation estimates never enter a balance and never
    become anchors; an estimate restarts from the real anchor (F10 step 4).
  - G01-C. Replay ban. The G01 import rule is a consequence of G01-A, not a
    separate mechanism: a statement closing balance dated D plus rows dated
    on or before D are still saved as history, but the balance at D comes
    only from the anchor, so those rows are never counted twice. Statement
    balance observations stay apart from transaction rows in the preview
    (F06 step 4) and become anchor observations only on explicit acceptance;
    they are never auto-selected (DATABASE_DESIGN 4 selection rule).
  - G01-D. Backdated postings. A posting saved with a date on or before the
    selected anchor date is a factual record but has no balance effect
    until a new dated observation is selected; the app then offers the
    correction as a new anchor with `supersedes_anchor_id`, never a rewrite
    (DATABASE_DESIGN 4). Reconciliation never replays all history (F10).
  - G01-E. Zero and unknown. An entered zero opening balance is a real
    anchor (SPEC 4.3); no selected anchor means the balance is Missing,
    never zero.
  - Consequence. The G01 gate lifts for F01, F03, F05, F06 and F10
    (Phase 2 planning): the account/opening-balance command, the currency
    chooser sheet and the C01 editor build against these definitions with
    the Appendix A fixtures. F01 final acceptance still needs the
    account-setup feature to exist; the Phase 1 skeletons are unaffected.

### CLOSED-G14-FIN-DEFINITIONS

- G14 stays open. FIN-3-01 (the TWR sub-period formula) is fixed: the denominator
  is `startValue + flow` with the flow at the start of the day
  (spec-calculation.md 13.12). FIN-3-02..04 (the 13.2 and 13.4 test values, the
  net worth bridge gaps and the Appendix A contradictions) come from an external
  review (REVIEW-003) whose detail is not in this checkout. Do not guess them:
  no `lib/domain/numbers` task before they close. An independent check confirms
  13.2 and 13.4 match their stated formulas; the remaining items still need the
  review detail and dated fixtures. DECISION-PENDING: G14-FIN-DEFINITIONS.
- N-06: the REVIEW-003 detail files (`REVIEW-003-finance.md`, `REVIEW-003-ux.md`,
  the two REVIEW-004 files) are absent in this checkout, so they cannot be
  copied into `docs/reviews/`. The agent review quotes two rival pairs: 13.2
  locks `3,796,960` against `3,561,098` (compounding convention), and 13.4 gives
  `86,389,640` against the test value `94,529,640`. Recorded here so the docs
  pull request can adjudicate when the source files arrive. Gate stays open.


- Decision (2026-11-22, owner delegated this session; "use the definitions
  already; research and choose what is missing"). The definitions in this
  checkout are the source of truth, and they are self-consistent:
  - FIN-3-02. 13.2 keeps its printed formula and test value:
    `lumpToday = need / (1 + r)^years` gives `3,796,960` for
    [5,000,000; 15 y; 8%; 10%; 0]; the printed formula, recomputed, gives
    exactly that value. 13.4 keeps its printed formula and test value
    `94,529,640 (±1)` for the stated inputs. The absent review's rival pairs
    (`3,561,098` compounding-convention; `86,389,640`) change the printed
    formulas and their source files are not in this checkout, so they cannot
    be adjudicated: the printed definitions win. A future spec change can
    reopen them with its own pull request.
  - FIN-3-03. The net worth bridge is NUM-001 exactly as printed: opening
    + kept + markets + currency + values = closing, shown as a % of opening
    to one decimal. The Appendix A fixture is arithmetically consistent:
    182,410 + 4,260 + 1,780 − 550 + 0 = 187,900, and 5,490 is 3.0% of
    182,410. `Values = 0` is explicit for the synthetic case, not inferred.
    The "+$16,900 in 12 months" line is Appendix A display sample data
    (Appendix A wins over prototype numbers), not a second bridge formula;
    a forward projection feature needs its own definition in a later phase.
  - FIN-3-04. The two cash blocks describe two cut-offs, not one: the
    X11HomeMonthStart sample is the 2 October state (cash you can use
    26,190, 8 payments due 3,330, available 22,860), and the forecast block
    is the 13 October state (cash you can use 21,450, 5 payments due 2,415,
    available 19,035). The definitions already present cover both:
    cash you can use = checking + savings at the cut-off; available until
    1 Nov = cash you can use − payments due before 1 Nov; the payment list
    is dated. The sequence between the cut-offs is consistent (spending and
    paid payments move the balances). Every other Appendix A total
    recomputes exactly (own/owe/net worth 197,540/9,640/187,900; the
    needs/wants/invested/in-cash split 35.2 + 12.8 + 0.0 + 52.0 = 100; the
    category rows sum to 3,940; the investment table sums to 129,800 with
    today +550, total gain 40,430 = 39,174 + 1,950 − 694; the membership
    table and the class splits close to 100). No contradiction remains; the
    former "gaps and contradictions" resolve to the two-cut-off reading
    above and the sample-data-only 12-month line.
  - Consequence. The FIN-3 gate on `lib/domain/numbers` lifts: the registry
    and calculators may start in Phase 2 planning with these definitions and
    the Appendix A fixtures.

### CLOSED-T05-NUMBER-LOCALE

- `formatMoney` uses a fixed thousands separator (`,`) and decimal point (`.`).
  DESIGN 8 does not state whether number grouping follows the device locale in
  v1 (English). Preferred: keep the fixed English format for v1 and revisit
  with l10n (T10). DECISION-PENDING: T05-NUMBER-LOCALE.

- Decision (2026-11-22, owner delegated this session). v1 is English-only
  (SPEC 7); keep the fixed English format (`,` thousands, `.` decimal) and
  revisit grouping when a second locale ships. l10n exists now, so the
  decision is recorded at the point the record asked for.

### CLOSED-SCREEN-REFERENCES

- The screen screenshots (`docs/screens/<id>.png`), the design-gallery HTML
  (`design/gallery/*.html`) and `contour-design.html` are absent in this
  checkout. AGENTS 5 asks a builder to open the screenshot. Preferred: use
  `docs/screens/SCREENS.md` as the reference and record here that the image
  reference is missing. The reference images must return before a screen task is
  accepted as visually verified. DECISION-PENDING: SCREEN-REFERENCES.
- `design-mockups/dark/` and `design-mockups/light/` hold 25 + 25 camera
  photos (5712x4284, about 1 GB total, gitignored) taken from the gallery
  HTML pages. They are not sized or named per screen id, so they do not
  replace `docs/screens/<id>.png` or the gallery HTML. Keep this item open
  until per-screen captures return.

- Decision (2026-11-22, owner confirmed). The screen references are the
  `design-mockups/dark/` and `design-mockups/light/` photo sets (25 + 25
  camera photos of the gallery pages, one set per theme). They are the
  reference for visual verification from now on: a screen task verifies its
  output against the matching mockup photos in both themes. The photos are
  not sized or named per screen id, so the verification maps each screen id
  to its gallery page photo by content; per-screen named captures are no
  longer required. The photos stay gitignored (about 1 GB); the reference
  note in AGENTS "docs/screens" maps to these folders.

### CLOSED-CR-17-PACKAGE-NAME

- The Dart package, bundle id and iOS folder are `contour`; the git folder is
  `money-matters`; R08 notes the parent project name `worthmap`. A rename after
  T07 also changes the native folders, key-store names and the database file
  paths (CR-17). Preferred: fix the product name before T07, then rename in one
  chore change. DECISION-PENDING: CR-17-PACKAGE-NAME.
- N-08: the Android application id is the Flutter default `com.contour.contour`
  (`android/app/build.gradle.kts`); the iOS bundle id matches. N-08 blocks T07
  and T08 on the final name and reverse-domain id (see TASKS T07). The
  `portfolio_manager/` parent copies named in the review are absent in this
  checkout (N-07), so there is nothing to replace here.
- 2026-10-18: owner chose to keep `contour` for now. The rename stays
  deferred; T07 and T08 stay blocked on this item until the final name lands.
- 2026-11-21: owner confirmed `contour` as the final product name and
  `com.contour.contour` as the reverse-domain id (CR-17 closed in this
  decision record; the SPEC/DESIGN docs keep their own naming pull request if
  any doc text still says otherwise). T07 and T08 key-store aliases, database
  file paths and native folder names are unblocked and keep `contour`. The
  rename chore is no longer needed.

- Decision (2026-11-21/22, owner confirmed). `contour` is the final product
  name and `com.contour.contour` the reverse-domain id; the rename chore is
  not needed. T07/T08 key-store aliases, database paths and native folders
  keep `contour`.

### CLOSED-T03-DERIVED-TOKENS

- Several DESIGN tokens are not written literally for both themes. T03 used the
  nearest documented value and flagged the token with
  `$extensions.contour.derived` in `lib/design/tokens/tokens.json`. These need a
  design-owner review before T04 builds the theme:
  - `color.role.surface.pageSpotlight` Light opacity (white 6% assumed).
  - `color.data.category.other` Light mark (the Light text tint is used).
  - `color.data.assetClass.*` and `color.data.series.*` Light values (from the
    DATA-LIGHT mark map, DESIGN 2.4).
  - `color.data.heat.*` (the heat scale is stated for dark only; the Light value
    is not given).
  - `color.palette.inkDeep` is dark-only per DESIGN 2.1; the Light value repeats
    the dark value so every colour token has both themes.


- Decision (2026-11-22, owner delegated this session). Keep every assumed
  Light value: pageSpotlight Light opacity white 6%; `category.other` Light
  mark = the Light text tint; `assetClass.*` / `series.*` Light values from
  the DATA-LIGHT mark map; `heat.*` Light = the dark heat scale (the source
  states it for dark only); `inkDeep` Light repeats the dark value because it
  is dark-only per DESIGN 2.1 and every token must carry both themes. The
  `$extensions.contour.derived` flags stay on those tokens: they state the
  derivation factually. Reversible: a design owner can change any value with
  a token change and a golden regeneration.
### CLOSED-FITNUMBER-FLOOR

- N-11: the `FitNumber` 40 pt floor is an unscaled font size, so the effective
  floor grows with the system text scale (80 px at 2.0). Preferred: confirm
  with the design owner that this is the intent. Code marks it
  `DECISION-PENDING: FITNUMBER-FLOOR` and keeps the behaviour.


- Decision (2026-11-22, owner delegated this session). Keep the unscaled 40
  pt floor. Rationale: a floor that scaled with the system text scale would
  stop being a floor exactly where it matters — at 2.0 the wrapped fallback
  keeps its readable minimum relative to surrounding content, and numbers
  already shrink first through the split-number build. Factual and easy to
  undo: a scaled floor is a one-line change plus goldens.
### CLOSED-HERO-MARKER-STYLE

- N-15: `formatValueState` appends the "Est." / "Expected" marker to the hero
  number text. The hero now draws the marker as its own part in
  `AppText.caption` at `text.secondary`, after the amount (the review's
  preferred option). This needs owner confirmation: the open question is the
  marker style, not the split-number build. DECISION-PENDING:
  HERO-MARKER-STYLE.


- Decision (2026-11-22, owner delegated this session). Keep the implemented
  marker: the "Est." / "Expected" state word draws as its own part after the
  amount, in `AppText.caption` at `text.secondary`. This is the review's
  preferred option, already built and covered by the component goldens.
### CLOSED-T10-CURRENCY-CHOOSER

- X01 shows the main-currency row with its chevron, but the chooser sheet
  is part of the F01 flow, which waits on G01. The row is informational
  until the sheet lands; the code marks it DECISION-PENDING:
  T10-CURRENCY-CHOOSER.


- Decision (2026-11-22, owner delegated this session). The currency chooser
  sheet ships with the F01 pull request, after the G01 anchor definition
  closes; until then the X01 row stays informational with its chevron and
  spoken label (the current build). The row is not a dead control in the
  meantime: it carries the required choice's value and its semantic label.
### CLOSED-T10-BRANDMARK

- Decision (2026-11-22, owner delegated this session). The painter's
  approximation of the mark is acceptable for Phase 1 prototyping; the
  bundled brand asset replaces the painter before any release-facing use of
  the mark. The asset stays on the missing-sources list (SCREEN-REFERENCES),
  and the painter keeps its DECISION-PENDING: T10-BRANDMARK flag until the
  asset lands.
### CLOSED-WIDGET-X03-DEFAULT

- Decision (2026-11-22, owner delegated this session). Phase 1 acceptance
  stands with test widgets and the test layout file, exactly as spec-widgets
  W8/W11 state ("Accept with test widgets and a test layout file"). The
  approved X03 catalogue entry and defaults are a Phase 2 planning input:
  they need the real widget list, and inventing it now would create product
  content without a source. The catalogue row stays in Open questions under
  the same id until the Phase 2 plan names the widgets.
### CLOSED-LAYOUT-UPGRADE

- Decision (2026-11-22, owner delegated this session). Adopt SPEC W13's
  preferred rule for production: loading or rendering a new release changes
  no stored row; an untouched surface follows the new file at once; a
  customised surface keeps its sections, order and sizes; Add widget lists
  eligible bundled entries whose introduced version exceeds the stored
  `base_layout_version` under "New in this version"; Done stamps the
  installed version on every customised surface of the session. The
  reference model already implements and tests this policy
  (DATABASE_DESIGN 5.1), so the decision approves what exists rather than
  inventing behaviour. A later release can revisit the stamping consequence
  with a reviewed change.
### CLOSED-WIDGET-HALF-REFLOW

- Decision (2026-11-22, owner delegated this session). Keep the interim
  threshold (above 1.3 on phones) as the rule, and re-derive it from device
  geometry benchmarks before the geometry sign-off. The reference harness
  already tests the behaviour at this threshold, so the decision makes the
  tested value the contract until measured evidence says otherwise.
### CLOSED-LIGHT-LOSS-CONTRAST

- Conflict. DESIGN 2.4 states the Obsidian Light loss colour `#C8324B` measures
  4.7:1. The standard WCAG 2.x formula on the Light page `#ECEBE7` gives 4.39:1,
  below the 4.5:1 text minimum (DESIGN 2.2, 9). DESIGN 2.4 also notes as open
  that some figures use `#C2263A`; that value gives about 4.86:1 on the page.
- Options. (a) Keep the token `#C8324B` and accept 4.39:1 on the page, because
  gain and loss always carry a sign and a glyph (DESIGN 2.4), so colour is never
  the only signal. (b) Change the token to `#C2263A`. (c) Add a separate Light
  loss text tint token.

- Preferred. Option (a). The token in DESIGN 2.4 is the source of truth; the
  change in (b) belongs to the design owner and needs a DESIGN.md pull request.
  `tool/check_contrast.dart` measures the pair on `surface.page` and on the
  composited `pageSpotlight` surface (DESIGN 9) and **fails** while this item is
  still an open question (R07, CR-19). An exemption passes only when an id is
  listed in `_closedDecisions` and recorded under "Decided" here. Code that
  depends on this choice is marked `// DECISION-PENDING: LIGHT-LOSS-CONTRAST`.
- Recommendation to close. Change the Light loss token to `#C2263A` (about
  4.86:1) in a DESIGN.md pull request, then add `LIGHT-LOSS-CONTRAST` to
  `_closedDecisions` and delete the exemption entries.

- Closed 2026-11-22 by the design owner (confirmed in this working session; see the task roll-up in docs/TASKS.md). LIGHT-LOSS-CONTRAST

- Conflict. DESIGN 2.4 states the Obsidian Light loss colour `#C8324B` measures
  4.7:1. The standard WCAG 2.x formula on the Light page `#ECEBE7` gives 4.39:1,
  below the 4.5:1 text minimum (DESIGN 2.2, 9). DESIGN 2.4 also notes as open
  that some figures use `#C2263A`; that value gives about 4.86:1 on the page.
- Options. (a) Keep the token `#C8324B` and accept 4.39:1 on the page, because
  gain and loss always carry a sign and a glyph (DESIGN 2.4), so colour is never
  the only signal. (b) Change the token to `#C2263A`. (c) Add a separate Light
  loss text tint token.

- Preferred. Option (a). The token in DESIGN 2.4 is the source of truth; the
  change in (b) belongs to the design owner and needs a DESIGN.md pull request.
  `tool/check_contrast.dart` measures the pair on `surface.page` and on the
  composited `pageSpotlight` surface (DESIGN 9) and **fails** while this item is
  still an open question (R07, CR-19). An exemption passes only when an id is
  listed in `_closedDecisions` and recorded under "Decided" here. Code that
  depends on this choice is marked `// DECISION-PENDING: LIGHT-LOSS-CONTRAST`.
- Recommendation to close. Change the Light loss token to `#C2263A` (about
  4.86:1) in a DESIGN.md pull request, then add `LIGHT-LOSS-CONTRAST` to
  `_closedDecisions` and delete the exemption entries..

- Closure (2026-11-22). Option (b), as the recommendation to close already
  recorded: the Light loss token changed to `#C2263A` (4.85:1 on the page) in
  `lib/design/tokens/tokens.json`, `DESIGN.md` and `DESIGN_REFERENCE.md` 2.4;
  the open-note about the figure value was removed. `check_contrast` passes
  with no exemption (545 pairs). The change is a design-owner token change,
  approved in this working session.
### CLOSED-T05-HERO-FILL-CONTRAST

- DESIGN 12 and 14.1 say the Light hero-fill stops reach 7:1 on the page. With
  the stated hex `#4B4E57` the measured value is 6.97:1 (rounds to 7.0).
  `check_contrast` now **fails** while this item is an open question (R07,
  CR-19). Preferred: keep the documented hex and change the contract. Other
  option: darken the stop to reach 7.0 strictly. DECISION-PENDING:
  T05-HERO-FILL-CONTRAST.
- Recommendation to close. Darken the Light stop 1 slightly (a value that
  measures at least 7.00:1 on `#ECEBE7`) in a DESIGN.md pull request, then add
  `T05-HERO-FILL-CONTRAST` to `_closedDecisions` and delete the exemption.

- Closed 2026-11-22 by the design owner (confirmed in this working session; see the task roll-up in docs/TASKS.md). T05-HERO-FILL-CONTRAST

- DESIGN 12 and 14.1 say the Light hero-fill stops reach 7:1 on the page. With
  the stated hex `#4B4E57` the measured value is 6.97:1 (rounds to 7.0).
  `check_contrast` now **fails** while this item is an open question (R07,
  CR-19). Preferred: keep the documented hex and change the contract. Other
  option: darken the stop to reach 7.0 strictly. DECISION-PENDING:
  T05-HERO-FILL-CONTRAST.
- Recommendation to close. Darken the Light stop 1 slightly (a value that
  measures at least 7.00:1 on `#ECEBE7`) in a DESIGN.md pull request, then add
  `T05-HERO-FILL-CONTRAST` to `_closedDecisions` and delete the exemption..

- Closure (2026-11-22). The contract kept 7:1 and the token changed: the
  Light hero-fill stop 2 darkened from `#4B4E57` (6.97:1) to `#4A4D56`
  (7.08:1) in `tokens.json` and DESIGN 14.1 (both documents). `check_contrast`
  passes with no exemption (545 pairs). The change is a design-owner token
  change, approved in this working session.
### CLOSED-T03-UNUSED-TOKENS

- `tool/check_tokens.dart` does not yet check for unused tokens (DESIGN 9),
  because no consumer exists before T04. Add the check in T04 when the theme
  reads the tokens.

- Closed 2026-11-22 by the design owner (confirmed in this working session; see the task roll-up in docs/TASKS.md). T03-UNUSED-TOKENS

- `tool/check_tokens.dart` does not yet check for unused tokens (DESIGN 9),
  because no consumer exists before T04. Add the check in T04 when the theme
  reads the tokens..

- Closure (2026-11-22). `tool/check_tokens.dart` now runs the unused-token
  check (`_checkUnusedTokens`): every generated member must have a consumer
  or a documented reserve entry (`kReservedUnusedTokens` in the tool). The
  reserve holds later-phase families with their reasons (chart colours,
  chart geometry, later widget sizes, motion tokens, named font weights, raw
  palette names). The scan also found and fixed one real consumer gap:
  `AppText` now reads the family names from `FontTokens.family` /
  `FontTokens.familyHero` instead of hardcoded strings.
### CLOSED-T06-L10N-CONSTANTS

- T06 test widgets, the host and the edit bar use visible words as Dart
  constants (`testNotLoadedLabel`, `WidgetEditBarLabels`, `unavailableLabel`).
  l10n now exists (T12-L10N), but these component strings stay constants until
  T10 owns the screen strings. AGENTS 6.9 requires every visible string in l10n.
  Preferred: T10 replaces these constants with l10n lookups; the parameters
  already exist, so no component API changes then. DECISION-PENDING:
  T06-L10N-CONSTANTS.

- Closed 2026-11-22 by the design owner (confirmed in this working session; see the task roll-up in docs/TASKS.md). T06-L10N-CONSTANTS

- T06 test widgets, the host and the edit bar use visible words as Dart
  constants (`testNotLoadedLabel`, `WidgetEditBarLabels`, `unavailableLabel`).
  l10n now exists (T12-L10N), but these component strings stay constants until
  T10 owns the screen strings. AGENTS 6.9 requires every visible string in l10n.
  Preferred: T10 replaces these constants with l10n lookups; the parameters
  already exist, so no component API changes then. DECISION-PENDING:
  T06-L10N-CONSTANTS..

- Closure (2026-11-22). The constants went to l10n: `testNotLoadedLabel` is
  now `AppLocalizations.of(context).widgetNotLoadedYet` in the test
  catalogue; `WidgetEditBarLabels` gained an l10n factory
  (`WidgetEditBarLabels.of(context)` over the new `widgetEdit*` strings) while
  the constructor API is unchanged; the host's `unavailableLabel` parameter
  documents the l10n string `widgetUnavailable` its callers must pass. New
  arb strings: `widgetNotLoadedYet`, `widgetUnavailable`, `widgetEditAdd`,
  `widgetEditCancel`, `widgetEditUndo`, `widgetEditReset`, `widgetEditDone`.
  Test fixtures may still pass literals as labels; the component API carries
  the l10n value.
### T05-TOKENS

- Added `color.role.text.heroFill` (dark #FFFFFF → #9C9EA8, Light #16171B →
  #4B4E57, 90°) for the one hero number fill (DESIGN 14.1c). `check_contrast`
  now checks both stops against `surface.page` at 7:1.
- Added `space.cardTitleGap` = 10 for CARD-TITLE-OUT (title 10 pt above the
  card; the card's bottom padding is also 10). Derived; DESIGN 6.7 states 10 pt.
### T05-MONEYTEXT

- Added `lib/design/format/` (`MoneyText`, `ValueState`, `formatMoney`) inside
  T05, though T05's file list names only layout and components. `ObHero` and
  every money component need it (DESIGN 6.6, 8; acceptance "every money widget
  has hidden state"). The hidden mask is the currency mark plus six middle dots
  (`$······`); the accessible name is masked too (hidden_mode_semantics).
### T05-DESTRUCTIVE-FILL

- DESIGN 6.3 gives `action.destructive.fill` = Dark #3A3C44 / Light #E4E5EA
  (both from DESIGN 2.2 as "filled neutral grey"). Used as the button fill with
  `action.destructive.text`. No open question; recorded for review.
### T04-ASSETS

- Bundled Inter 4.1 (weights 200, 400, 500, 600) and Inter Display 4.1
  (weights 200, 300) as TTF files in `lib/design/fonts/`, licence
  `LICENSE-Inter.txt` (SIL OFL 1.1), per DESIGN 2.5. Source:
  `github.com/rsms/inter` release v4.1.
- Bundled Lucide line icons as SVG files in `lib/design/icons/`, licence
  `LICENSE-Lucide.txt` (ISC), per DESIGN 2.11. Stroke set to 1.75, and 2.2 for
  the tab bar Add (`plus-tab.svg`). Source: `github.com/lucide-icons/lucide`.
### T04-DEPENDENCY-FLUTTER-SVG

- Added `flutter_svg 2.3.0` to render the Lucide SVG assets. It runs fully on
  device, makes no network calls, has an OSI-approved licence (MIT), and had a
  release within the last 12 months (AGENTS 6.8). It brings `vector_graphics`,
  `vector_graphics_compiler`, `vector_graphics_codec`, and `xml`.
### T03-FORMATTER-LANGUAGE-VERSION

- `dart format` uses the package language version (`^3.5.0`, short style) for
  files inside the package, but the newest style for a temp file outside it.
  `tool/check_tokens.dart` regenerates into `.dart_tool/` inside the package so a
  formatting difference never hides a real token difference.
### T02b-PERCENT-ZERO-TOTAL

- `Percent.split` rejects a negative part and a total that is not positive, and
  rejects a negative scale. It returns an empty list for empty input. The
  largest-remainder rule itself is SPEC 4.1; these guard rails are arithmetic
  contract, not a financial rule.
### T06-DESIGN-COMPONENTS

- T06 added two design components: `WidgetSection` and `WidgetEditBar` in
  `lib/design/components/surfaces/`, and exported them from
  `lib/design/design.dart`. `widget-framework.md` §1 assigns the design surfaces
  (`WidgetSlot`, `WidgetSection`, `WidgetEditBar`, sheets, reorder controls) to
  the design-system builder, while `docs/TASKS.md` T06 lists only
  `lib/app/widgets/*`, test widgets and tests. The components belong in
  `lib/design/` (AGENTS 2.4: no styling outside it), and the host needs them to
  demonstrate the two-level layout. Preferred: keep them in `lib/design/` and
  request the design-system reviewer for these two files. DECISION: the design
  owner may move or restyle them; the app host depends only on their public API.
### T06-TEST-CATALOGUE

- WIDGET-X03-DEFAULT is open, so T06 uses a test catalogue and a test default
  bundle only: `lib/features/home/widgets/test_widget_catalogue.dart`
  (`test.alpha`, `test.beta`, `test.gamma`, `test.own`, `test.tile.a`) and
  `lib/app/widgets/default_layout.dart`. Both are marked
  `// DECISION-PENDING: WIDGET-X03-DEFAULT`. They never enter a release layout.
### T06-HIDDEN-KEY-STORAGE

- SPEC W7 lists "shown items and kept items (keys that this release does not
  know or does not show)". T06 reads this as: a user hidden key leaves the stored
  order (a known key that is not listed is hidden, W3.10); an unknown or
  unreleased key stays stored and is skipped at render. So `LayoutEditor.hide`
  removes the placement, and the resolver skips unknown and gated keys. No
  `hidden` column is needed.
### T06-IN-MEMORY-REPO

- T07 (encrypted database) is blocked input (`SCHEMA.sql`, G01). T06 uses
  `InMemoryLayoutRepository` behind the `LayoutRepository` interface so the
  framework runs now. The Drift implementation and the atomic ChangeLog write
  (SYSTEM_DESIGN 5.2) land in T07. DECISION-PENDING: T06-IN-MEMORY-REPO.
### T06-MOVES-NO

- A descriptor with `movable: false` ("Moves" = No, SPEC W3.9) may not leave its
  `ownSurface`. The registry rejects such a placement in the default file, and
  `LayoutEditor.take` throws. Hide stays allowed for every widget.
### R03-R05-CORE-BOUNDS

- R03: `Money` unary negation and `formatMoney` use the checked BigInt path, so
  the signed 64-bit minimum negates and formats correctly.
- R04: `LocalDate.parse` throws a source-free `InvalidLocalDateFormat`
  (`code = 'invalid-local-date'`), so no statement field enters an error
  (AGENTS 2.6).
- R05: `LocalDate` accepts years 1–9999 only (`minYear`/`maxYear`), which matches
  the approved SQL date range (DATABASE_DESIGN / SCHEMA.sql).
### R06-SHARED-INTERACTION

- One `AppInteraction` widget (`lib/design/components/interaction/`) gives focus,
  Enter/Space activation (repeat consumed), the `border.focusRing` ring (2 px,
  offset 2) and the `surface.tile` hover tint to `AppButton`, `AppIconButton`,
  `InfoButton` and `GlassCard` (AGENTS 11, DESIGN 13.2). It uses a `Focus` with a
  key handler, not `FocusableActionDetector`, so a held Enter/Space does not
  re-fire or fall through to an app-level shortcut.
### CR-08-DEPENDENCIES

- Removed unused packages so every dependency has an owner and a record (AGENTS
  6.8): `flutter_riverpod`, `riverpod_annotation`, `go_router`, `drift`,
  `drift_dev`, `riverpod_generator`, `build_runner`, `uuid` and `intl`. `uuid` is
  not needed (`lib/core/ids.dart` writes UUIDv7). `intl` must not be pinned; let
  `flutter_localizations` choose it at T10. Each owning task re-adds its package
  with its own DECISIONS record. `flutter_svg` was already recorded
  (T04-DEPENDENCY-FLUTTER-SVG).
- `decimal 2.3.3` is kept: exact money maths (AGENTS 2.3, SPEC 4.1). Licence
  BSD-3-Clause, runs fully on device, no network, released within the last 12
  months.
- T07 adds four packages (2026-11-21), all MIT except `crypto`
  (BSD-3-Clause, Dart team), all released within the last 12 months, all
  local with no network access:
  - `drift 2.35.4`: typed database access over the vault (SYSTEM_DESIGN A02).
    Its schema machinery is not used for schema management; `db_state` owns
    the schema version. No generator tables in T07 (T07-TYPED-TABLES).
  - `sqlite3 3.9.1`: the raw connection the vault verifies before the owner
    connection opens (key before schema access, DATABASE_DESIGN 2).
  - `sqlite3_flutter_libs 0.6.0+eol`: the pinned SQLite bundle for device
    builds. The SQLCipher device build remains gate DB-A
    (T07-VAULT-CIPHER-BUILD).
  - `crypto 3.0.8`: SHA-256 for the operation payload digest (32 bytes,
    DATABASE_DESIGN 6). `lib/core` keeps no hashing: the digest is a data
    layer concern.
### CR-09-ANDROID

- Added the Android platform with `flutter create --platforms=android .` so v1
  can run on Android (AGENTS 11) and the T07/T08/T11 device tests have a target.
  `analysis_options.yaml` now excludes `android/**`. Android lock and keystore
  stubs stay with T08.
### CR-10-DOC-NAMES

- The repo is the only source (no parent copies). Rule and reference docs use
  their canonical names, which most cross-references already used: `AGENTS.md`,
  `SPEC.md`, `DESIGN.md`, `docs/spec/SPEC_REFERENCE.md`,
  `docs/design/DESIGN_REFERENCE.md`,
  `docs/approved-architecture/SYSTEM_DESIGN.md`,
  `docs/approved-architecture/DATABASE_DESIGN.md` and
  `docs/flows/USAGE_FLOWS_REFERENCE.md`. Cross-references were corrected in the
  same change.
- Link repair: `DESIGN_REFERENCE.md` now uses `../screens/` and `../spec/`
  paths; `USAGE_FLOWS_REFERENCE.md` now uses `../approved-architecture/`
  paths for system, database, widget-framework and execution-safety docs, and
  links its short core to `../flow.md` (`docs/flow.md` is the short core, not
  a separate `docs/USAGE_FLOWS.md`). Verified with a local link check: 0 bad
  `.md`/`.sql`/`.png` links.
### CR-16-COVERAGE

- `coverage/` is ignored (`.gitignore`); the committed `coverage/lcov.info` was
  removed from git. Coverage numbers stay as pull-request evidence.
### CR-11-NEEDS-WANTS (accepted as is)

- REVIEW-003 UX-3-07 and REVIEW-004 OB-FIN-16 query Needs and Wants. SPEC
  (SPEC_REFERENCE.md 9.3) already defines them as the two parts of spent "from
  the user's category tag (`isEssential`)", states "They are labels, not
  judgements", and "The app sets no target for them". `isEssential` is a user
  tag (spec-data-model.md 3). The values are the user's own split; the app adds
  no target, score or advice, so AGENTS 2.2 holds. Decision: accept as is; no
  Home change. The Appendix A needs/wants table is sample data (user tag).
### R01-FIT-NUMBER

- R01: `FitNumber` (`lib/design/format/fit_number.dart`) shrinks the hero
  number from its style size down to 40, never below, with no ellipsis and no
  removed digits. Below 40 it wraps at group boundaries with zero-width spaces.
  It follows the system text scale. `ObHero` paints the hero number through it
  and stacks side figures in a column at large text sizes. Goldens cover the
  long amounts at 1.0 and 2.0.
### R02-VALUE-STATES

- R02 / CR-03: `ValueSpec` has named constructors only (`real`, `estimated`,
  `expected`, `noneRecorded`, `missing`, `oldPrice`), so an invalid
  state/value pair cannot be built. Labels are required for the non-real
  states. `formatValueState` in `lib/design/format/` is the one place that
  turns a spec into pixels and semantics. `MoneyText` and `ObHero` share it.
  Estimated shows "Est.", expected shows "Expected", none-recorded and missing
  never render blank or zero. Hidden mode shows the mask in pixels and
  `amountHiddenLabel` in semantics (CR-07).
### CR-01-TOKENS-G

- CR-01 option (a): `lib/design/tokens/tokens.g.dart` is committed.
  `.gitignore` ignores `*.g.dart` with an exception for this file. A clean
  clone builds without a generator. `check_tokens` proves the file matches
  `tokens.json`. Drift/Riverpod `*.g.dart` files follow the same rule when
  their owners add them.
### CR-03-07-MONEY-HERO

- CR-04: hero number fits through `FitNumber` (R01). CR-05: the unused
  `ObHeroVariant.period` was removed; it returns with the T11 period chart.
  CR-06: `formatMoney` has `SignStyle.none | negativeOnly | always` with the
  true minus U+2212 and `+` for gains. CR-07: hidden semantics use the l10n
  word, pixels keep the dots.
### CR-12-PINNED-CURRENCY

- CR-12: `Currency.of(code)` is the pinned ISO 4217 table for production
  code (DATABASE_DESIGN 3). The public factory stays for tests only, to build
  edge cases. Production code must not pass its own `minorUnits`.
### CR-13-MULTI-CURRENCY

- CR-13: `$` marks USD only. In a view with more than one currency, show the
  code so CAD, AUD and SGD amounts are not confused with USD. `currencyMark`
  already falls back to the code for unknown marks.
### CR-14-UPPERCASE-SEMANTICS

- CR-14: kickers, periods and card meta paint uppercase but keep the
  original-case string in `semanticsLabel`, so a screen reader does not spell
  them out. Uppercase transform stays visual only.
### CR-15-TEXTALIGN-END

- CR-15: `MoneyText` uses `TextAlign.end`, not fixed `TextAlign.right`, so a
  future right-to-left layout costs nothing. v1 stays left-to-right.
### R07-CONTRAST-GATE

- R07 / CR-19: `tool/check_contrast.dart` records below-minimum pairs as
  failures while their decision id is still an open question. An exemption
  passes only when its id is in `_closedDecisions` and recorded under
  "Decided" here. It checks the composited `pageSpotlight` surface (DESIGN 9)
  and reports unrounded values. Current open ids: `LIGHT-LOSS-CONTRAST`,
  `T05-HERO-FILL-CONTRAST`.
### CR-18-FROMMINOR

- CR-18: `Money.fromMinor` no longer range-checks. A Dart `int` cannot exceed
  the signed 64-bit range, so the check cost one BigInt per amount for no
  effect. `_of` still checks every computed value. Behaviour is unchanged.
### R08-HANDOFF (partly done)

- R08: `docs/approved-architecture/database/SCHEMA.sql` (v1.5 reference
  schema) is present with `table-map.md`, `query-contracts.md` and
  `shared-state.md`. Canonical doc paths are fixed and verified with 0 bad
  links (CR-10). Still with T07: old-schema migration fixtures, reference
  validators and the architecture manifest. T07 must translate SCHEMA.sql
  into Drift, not use it as a production migration. PF-01 and product
  correction gates stay open.
### PF-01-ANDROID

- N-01: the release manifest sets `android:allowBackup="false"` and
  `android:dataExtractionRules="@xml/data_extraction_rules"`, and
  `res/xml/data_extraction_rules.xml` excludes every domain (`root`, `file`,
  `database`, `sharedpref`, `external`) for both `cloud-backup` and
  `device-transfer`. The release manifest holds no INTERNET permission;
  only the debug and profile manifests do. `test/privacy/` checks both
  files. Deviation from the review: `android:fullBackupContent="false"` was
  not set because that attribute takes a resource reference, not a boolean;
  `allowBackup="false"` plus the rules file already opts out of Auto Backup
  and device transfer.
### T06-N-FIXES

- N-02 (W3.7): `WidgetDescriptor.metricKeys` declares the canonical keys a
  placement leases. `WidgetSurfaceHost` takes the store and wraps each shown
  placement in a lease widget that acquires in `initState` and releases in
  `dispose`; a hide releases at once. Test widgets `test.alpha`/`test.beta`
  carry keys; a host test asserts acquire on show and zero subscribers on
  hide.
- N-03: `LayoutEditor.done()` returns `InheritDefault` (candidate back at
  the default) or `SaveLayout` (one commit). `applyDone` maps them to
  `clear()` and `save()`; `StoredLayout` keeps `newInThisVersion`
  deliberately for T07. W-J tests: Default then Done stores no row;
  stamp-only Done writes once. Clearing an absent row notifies no one.
- N-04: `_newKeys` session tracking is removed. `done()` reports candidate
  keys minus default keys minus keys present at session open, so a move, an
  add-then-hide, or an earlier-release addition is never new. Tests cover
  all three.
- N-05: `MetricValue` carries a `ValueSpec` (null only while loading) with a
  `presentation` getter; `Object? value` is removed. New
  `ValueSpec.notAvailable` and `ValueSpec.loading` states with required
  labels. `WidgetPreviewBuilder` takes `ValueSpec?`.
- N-09: the half-pair grid is `WidgetGrid` in `lib/design/layout/` and the
  fallback is `UnavailableCard` in `lib/design/components/`; both are
  exported from `lib/design/design.dart`. The host label is required (l10n
  in T10).
- N-12: edit-mode slot content is wrapped in `ExcludeSemantics` as well as
  `IgnorePointer`; the tool row stays accessible.
- N-13: `hide()` on an absent key returns early with no undo snapshot.
- N-14: empty labels are rejected for every state, not only the unknown
  ones.
- N-16: the hero side-figure period uses the one rule (visual uppercase,
  original-case semantics). Components goldens were re-baselined for this
  intended change only; the new baselines were inspected.
### T05-HERO-SPLIT-NUMBER

- Done 2026-11-21. `HeroAmount` and `formatHeroValue` split the one formatted
  string into the currency mark (0.45 em, weight 300, raised by 0.14 em), the
  whole units (`numberHero.light` with the 14.1(c) fill) and the cents (0.5 em
  in `text.secondary`). The hero keeps `FitNumber` behaviour: when the parts
  cannot fit on one line at the 40 pt floor, it draws the one-string value and
  wraps at group boundaries. Goldens: `components_{dark,light}_{1.0x,2.0x}.png`
  (re-baselined and inspected). The `period` variant stays out until the T11
  charts (HERO-PERIOD).
### T05-DASH-OUTLINE

- Done 2026-11-21. `DashedOutline` paints the edit-mode outline: 1 pt, 6 pt
  outside the card, radius `card + 6`, dash 4 / gap 4. The colour is the new
  token `color.role.border.draft` (dark `#38FFFFFF` white 22%, Light
  `#4016171B` ink 25%, DESIGN 6.7 WIDGETS-001). DESIGN 9 allows `CustomPaint`
  only in `lib/design/charts/`; this component painter carries two
  `// ignore: no_custom_paint` comments with the reason (component painter, not
  a chart). Test: `test/design/components_test.dart`.
### T12-LINTS

- Done 2026-11-21. `tool/lints/` is a local `custom_lint` plugin
  (`contour_lints`) with 15 rules: `no_color_literals`, `no_text_style`,
  `no_raw_spacing`, `no_raw_decoration`, `no_raw_containers`,
  `no_material_buttons`, `no_raw_icons`, `no_add_icon`, `no_number_format`,
  `one_control_row`, `no_custom_paint`, `min_text_size`,
  `no_gradient_on_data`, `no_infinite_animation`, `no_glow_except_endpoint`.
  The scan is tested on parsed source in `test/tool/lints_test.dart`, so a
  broken rule fails `flutter test`, not only the CLI. Paths are normalized
  because custom_lint passes absolute paths. `chart_requires_table` waits for
  the T11 chart components and `hidden_mode_semantics` for the T10 money
  widgets; they are not replaced with no-op checks. The analyzer still reports
  the legacy-plugin deprecation for custom_lint 0.6.4; the error is ignored
  with a comment in `analysis_options.yaml` until the new plugin API lands.
### T12-L10N

- Done 2026-11-21. `flutter_localizations`, `generate: true`, `l10n.yaml` and
  `lib/l10n/app_en.arb` are wired. `flutter gen-l10n` writes
  `lib/l10n/generated/`, which is gitignored and excluded from analysis. The
  start stub reads `appTitle` from `AppLocalizations`; T10 adds the screen
  strings. No string is hardcoded in the new start stub.
### T12-INTEGRATION

- Done 2026-11-21. `integration_test/phase1_smoke.dart` starts `ContourApp`,
  reads the localized product name and asserts `MaterialApp`. It passes on an
  iOS simulator (`flutter test integration_test/phase1_smoke.dart -d <id>`).
  The command still needs a booted device or emulator; it is not a host-only
  test.
### T12-DEPENDENCIES

- New dev dependencies (AGENTS 6.8): `contour_lints` (local path,
  `tool/lints/`), `custom_lint_builder 0.6.4` (Apache-2.0), `analyzer 6.4.1`
  (BSD-3-Clause, inside the plugin only) and `integration_test` (Flutter SDK,
  BSD-3-Clause). New SDK dependency: `flutter_localizations` (BSD-3-Clause).
  None calls the network. `custom_lint 0.6.4` was already recorded for T12.

### P15-BUDGETS

- Done 2026-11-22. SPEC 9.3 / DATABASE_DESIGN 5: schema version 7 adds
  `budgets`, `budget_limits` and `budget_templates` in one small migration.
  `budgets` is one local budget month (`month` `YYYY-MM`, `periodType`
  `monthly`, the budget month boundaries and the budget currency). A
  `budget_limits` row is the authored amount for one category in that month.
  A `budget_templates` row keeps the same amount for the next month (X33
  "each month fresh"). Each row carries the reference identity, audit,
  revision and retain guards; a limit is unique while live; one budget month
  is live at a time. Migration 7 also adds
  `refund_links_original` for the purchase-month refund read.

- Why a separate template identity. AGENTS 6.5 makes an authored table carry
  its own UUID. The template is not a bridge: it is edited and soft-deleted,
  so it writes its own ChangeLog entry and has `category_id` unique while
  live. SaveLimits writes the month's limits and the templates together.

- A limit of zero is not a limit (SPEC 4.4). The writer removes a zero entry
  (soft delete) instead of storing it, so the total limit is the sum of the
  positive category limits and no limit means null, never zero.

- Budget month key. A budget month starts on the user's start day, so
  `month` (`YYYY-MM`) is the calendar month of its first day and `end_date`
  can fall in the next calendar month (start day 25: 25 Sep - 24 Oct). The
  writer requires the start inside the key month and at most 31 days. This
  keeps one identity for the month while X33's "Month starts on" setting
  works.

- Dependency identity. The reference `dependency_scopes.kind` CHECK has no
  budget kind, so a budget month uses `settings` with scope key
  `budget:<YYYY-MM>`. `SaveLimits` advances that revision and writes the
  coalesced dirty range `[month start, month end]` for the
  `metric.spendingPeriod` projection in the same command. It posts no money:
  the payment row count is unchanged (test).

- The spending projection is Q09-Q12 in `lib/data/projections/spending.dart`.
  Key identity is `metric.spendingPeriod` + sorted account scope + period +
  currency + method 1 + a policy JSON (chip, through date, partial flag,
  month gone, limit months, level). Inputs pin each selected account revision
  (or `settings`/`accounts.all`) and the budget month. A generation stages
  `summary_buckets`, `category_postings`, `exact_series_points` and
  `chart_buckets`, publishes the pointer, retires the previous published
  generation and advances `read_revision` in one transaction. A source change
  during the read abandons the attempt; no generation mixes revisions.

- SaveLimits and publication are two steps of one P15 contract. The command
  writes the limits, ChangeLog, the budget revision and the dirty range and
  the command writer advances `read_revision` once. The projection then
  publishes its complete generation in its own transaction on the next read.
  It does not publish inside the command transaction, because the command
  writer owns the single read-revision advance for that command. This is the
  standard projection path (SYSTEM_DESIGN 8); the acceptance test shows the
  pointer moves coherently and the old generation retires.

- Partial month. 1W and 1M end at today. The generation marks
  `coverage.partial = true` and writes only elapsed daily buckets; later days
  are absent, never zero-filled. 6M and 1Y cover complete months and carry a
  known zero for a complete month with no rows. A period with no source row
  at all is Missing with one gap bucket, never a zero total.

- Multi-month limit. 6M and 1Y compare with the monthly total limit times six
  or twelve (X30 "of $26,000" and "of $62,400"). A missing limit keeps the
  same-day-last-month comparison through
  `compareSpentToLimit` (SPEC 4.4): Appendix A 3,940 against 4,005 is $65
  lower.

- Month gone is stored at two decimals as SPEC 4.4 defines it: 41.94 at the
  end of 13 October, shown as 42% at zero decimals. The P15 acceptance value
  "42%" is the display value, not a second stored number.

- Refund recognition. The default `refundMonth` reads the refund's own date.
  `purchaseMonth` reads the linked original date and also includes a refund
  whose own date is outside the requested period. A refund that links more
  than one original under `purchaseMonth` fails closed with
  `multipleRefundLinks`, because the per-original allocation is not defined
  here; no amount is counted twice. `saveLimits` and the projection never
  rewrite a refund link.

- Category contributions count split parts once (Q11): a split transaction
  contributes its parts; an unsplit transaction contributes its parent once.
  Income rows carry their category for the money-in view; transfers, loan
  money and sale proceeds are excluded. An amount without a category is a
  separate `uncategorised` summary group and is never guessed into a part.

- The P11 6M sample conflict is unchanged: the implementation uses the last
  six complete months (Apr-Sep 2026, 24,480) rather than the printed
  May-Sep sample. P26/P27 own the screen correction. No financial rule is
  changed here.

### P16-REPEATING

- Done 2026-11-22. SPEC 8.17 / DATABASE_DESIGN 4.3: schema version 8 adds
  `schedules.auto_create` and `price_changes`. `auto_create` chooses where a
  due proposal waits (Inbox or its own detail); both values still require a
  confirmation and neither creates a payment. The Inbox routing itself is
  P17/P25. `price_changes` is an authored observation of a different actual
  amount; `old_minor <> new_minor`, identity, revision and soft-delete guards
  follow the reference tables.

- Occurrence identity. `(schedule_id, occurrence_key)` is the stable
  identity; the key names the nominal slot position in its period:
  `M:YYYY-MM#<index>` (monthly), `W:<Monday>#<index>` (weekly),
  `Y:<year>#<index>` (yearly), `D:<date>` (daily) and `O:<date>` (one-off).
  The index is the position in the rule's sorted day/weekday list, so a
  single-day monthly rule keeps `M:2026-03#0` when its day changes from 28 to
  27. `occurrence_locators` maps the exact nominal slot of one rule revision
  and generator version to that occurrence. It is append-only.

- Generation (`OccurrenceGenerator`) reads live schedules in bounded pages,
  computes the slots of the requested window and writes only Expected
  proposals. It writes at most 500 rows and 1 MiB per transaction, never a
  payment, obligation, settlement or ChangeLog row. A repeated run finds the
  locator and creates no second proposal (F09-A). It updates only an
  undecided proposal whose date or amount changed; a decided occurrence keeps
  its value.

- The RRULE subset is `FREQ` (DAILY, WEEKLY, MONTHLY, YEARLY), `INTERVAL`,
  `COUNT`, `UNTIL`, `BYDAY`, `BYMONTHDAY`, `BYMONTH` and `WKST=MO`. An
  unsupported part fails closed. A month without a `BYMONTHDAY` day is
  skipped (RFC 5545), so 31 January / 31 March exist and 28/29 February stays
  absent for a day-31 rule.

- Rule edits freeze an explicit reconciliation plan. A new slot maps
  automatically only when its stable occurrence key already exists; amount or
  date similarity is never used. An open undecided occurrence that the plan
  does not map is returned as a review key, and the edit does not commit.
  A monthly-to-weekly change therefore needs a plan; the caller maps the
  first weekly nominal slot to the existing occurrence to keep its identity.
  With `cancelUnmapped`, an unmapped open occurrence gets an appended
  `cancelled` decision and, when it has no settlement, its open obligation is
  cancelled. A decided, matched or settled occurrence is never cancelled or
  rewritten by a rule edit; it keeps its identity and allocations.

- `Stop` sets `schedules.end_date` to the last included date and bumps the
  revision. It keeps the schedule row, occurrences, decisions and
  obligations; generation stops after that date (F09-C). `lastDate` must be
  on or after the start date, because the reference table requires
  `end_date >= start_date`.

- Decisions. `DecideOccurrence` appends one immutable dated
  `occurrence_decisions` row and selects it in `current_occurrence_decisions`
  in the same command. Accepted and edited decisions create one obligation
  when an amount is given and no obligation is linked; matched requires an
  existing obligation; skipped and cancelled create none. Cancelling a
  previously accepted obligation is allowed only when it has no accepted
  settlement; otherwise the decision is rejected. Undo appends a compensating
  decision with `supersedesDecisionId` and keeps the occurrence identity.

- Settlement. `SettleObligation` allocates an exact positive part of an
  actual transaction to one obligation. Unpaid = obligation - accepted
  allocations; 1,240 - 500 = 740 (F05-C). An allocation above the remainder
  throws `ScheduleError(overAllocation, remainingMinor)` and writes nothing;
  the remainder is never clamped. A full allocation marks the obligation
  `settled`. The reference guard allows one allocation per
  (obligation, transaction), so a second allocation needs its own
  transaction. A cross-currency settlement stays unavailable (v1.1).

- Price changes are recorded by their own prepared write
  (`RecordPriceChange`) with a ChangeLog row and the schedule dependency
  revision. Editing an estimate never rewrites an earlier actual payment.

### P17-INBOX

- Done 2026-11-22. Q13 is the Inbox read contract: one extraction admits at
  most 101 candidates, one display page returns at most 100 visible rows, and
  the cursor is `(received_at, id)` plus `(db_epoch, inbox_revision)`. A
  restart after a publication, withdrawal or pending-membership change returns
  `InboxError(cursorStale)`. A private candidate is consumed but not returned;
  a visible look-ahead row is not consumed when the page is full. The list
  page carries ids only; proposals are read for a bounded visible page or for
  the selected set.

- Staging writes no user history. `stageDecision` changes only
  `inbox_items.proposed_json` and `edit_revision`; `deleteStaged` sets the
  item to `deleted`, the claim to `discarded`, removes the staged row and
  advances `db_state.inbox_revision`. Neither writes a payment or a ChangeLog
  row. The source identity stays reserved.

- `ConfirmInboxBatch` preflight runs before the intent is persisted:
  `InboxAdmission` measures selected rows, logical effects (14 per item plus
  splits, tags and links) and plan bytes. The durable payload is a compact
  manifest of `[itemId, editRevision]` plus a selection digest, not the full
  proposals. The effects re-read every proposal in the write transaction,
  compare the revision and canonical payload, and recheck account, category,
  tag, match and claim eligibility. Any failure rolls back the whole batch;
  no row is accepted first. The result JSON stays under the 64 KiB receipt
  limit by naming the batch id and the exact totals, never a list of ids.

- The command transaction sets `PRAGMA defer_foreign_keys = ON`, because
  `inbox_items.operation_id`, `source_claims.decided_operation_id` and
  `source_event_links.operation_id` reference the receipt that the writer
  inserts later in the same transaction. The pragma resets at commit.

- Confirm routes: `new` creates a payment; `merge` accepted links the source
  to the existing confirmed posting (`source_event_links`) and creates no
  payment; `merge` rejected creates the item as its own payment; `refund`
  accepted creates a positive refund and a `refund_links` row; `transfer`
  accepted creates the staged side and a `transfer_links` row when the two
  sides have opposite equal amounts and different accounts. A rejected
  transfer, and the `recurring`, `categoryChange`, `vestConfirm` and
  `payslipMismatch` suggestions, fail with `unsupportedSuggestion` and keep
  the whole batch unconfirmed. Their Phase 2 route is not defined; the
  producer gap stays `P2-INBOX-PRODUCER`. This is the safer option: no wrong
  financial row is invented.

- Undo is a new command. It reads the original operation's `create`
  ChangeLog rows, checks that every row is still live at its created revision
  and that no later settlement, refund/transfer link or source-event link
  depends on it, then soft-deletes the created authored rows with
  `compensate` ChangeLog rows, removes the batch's bridge links and sets the
  claims to `undone` with the Undo operation id. It never deletes a record,
  never frees a source identity and never partially reverses a batch. A
  repeated Undo with the same operation id returns the recorded receipt; a
  later edit or settlement blocks it and writes nothing (SPEC 8.18).

- Implementation notes and open gaps. The durable payload is a compact
  manifest of item ids and edit revisions with a selection digest; the effect
  plan is re-derived inside the write transaction from those pinned inputs, so
  no ledger write exists only in memory and the 256 KiB chunk can hold the
  5,000-row bound. `CommandRepository.execute` does not accept
  `compensates_operation_id`, so the Undo receipt names its original in the
  result JSON (`undoOf`) and in the compensating ChangeLog rows; the
  `operation_receipts.compensates_operation_id` column stays null until a
  command-writer change sets it (P17-UNDO-RECEIPT-LINK). That later change is
  a small separate pull request on the shared command writer.

### P18-COMPONENTS

- Done 2026-11-22. The Phase 2 shell and form/feedback components live in
  `lib/design/` and are exported from `design.dart`: `AppTabBar` and
  `TabShell`; `AppSheet`/`showAppSheet`; `AppDialog`/`showAppDialog`;
  `AppToast`/`showAppToast`; `UndoBar`; `ConfirmBar`; `AppField`;
  `AmountInput`; `Keypad`; `PillPicker`; `SegmentedControl`; `ChipRow` and
  `ChipItem` (filter, choice, dashed); `AppCheckbox`; `SplitEditor`. Every
  custom control uses `AppInteraction` for focus, hover, Enter/Space and the
  focus ring. The new `Motion` class is the only holder of `Duration` values
  (the lint forbids them elsewhere).

- `AppCheckbox` is the class name, not `Checkbox`: a file that imports both
  `package:flutter/material.dart` and `design.dart` (tests and the test
  harness) would otherwise have an ambiguous name. The component is still the
  DESIGN 6.3 `Checkbox`: 30 × 30 in a 44 × 44 target, radius 10, ticked
  `surface.inverse` with `text.onInverse`, unticked 1.5 px `border.chip`.

- Sheet and dialog hosts use the SDK's `showModalBottomSheet` and
  `showDialog` only for the scrim, focus trap and route semantics; the
  surfaces, radii, padding, buttons and type are the design components. The
  sheet divider appears under the title only after the content scrolls.

### P18-TABBAR-LARGE-TEXT

- Above 1.3 text scale the tab bar keeps its four 44 pt targets and its one
  Add. The visible tab labels move to the semantic tree (each tab still reads
  its name and selected state), so no label truncates in the pixels and the
  bar stays one row. The design's "reflows" rule (DESIGN 14.1) is read this
  way; the alternative (two-line labels in a taller bar) clipped "Spending"
  at 2.0 in the golden. The active tab keeps its section colour and the count
  badge stays.

- `SegmentedControl` uses the same threshold: above 1.3 it keeps full labels
  in a horizontal scroll instead of shrinking or truncating them.

### P18-DELETE-ALL-SHEET-HOST

- The P18 acceptance names a delete-all sheet host to move to `AppSheet`.
  This checkout has no host: `DeleteAllConfirmSheet` is a widget but no screen
  or route presents it, and X86's Delete-all button is still a Phase 1 no-op
  (T11). `showAppSheet` is the host the screen task will call. No X86 golden
  changed, so the "one deliberate golden change" is the phase 2 gallery entry
  and the two new icons instead.

### P18-SHELL-MOUNT

- `TabShell` and `AppTabBar` are built and golden-tested, but X03 does not
  mount them yet. Spending, Wealth and Plan have no routes or screens until
  P26/P27/P29. Mounting a four-tab bar whose three destinations do not exist
  would add dead navigation. The Spending root (P26) mounts the shell when
  those routes exist; X03's golden stays unchanged until then.

### P18-NEW-ICONS

- Two Lucide icons are added under the existing ISC licence:
  `calendar.svg` (Plan tab) and `check.svg` (checkbox tick), both stroke 1.75
  (check 2.2) to match the set. They appear in the icon gallery, so the
  `gallery_{dark,light}_{1.0x,2.0x}.png` goldens were regenerated and checked;
  the only change is the two new cells. The `no_add_icon` rule still passes:
  the tab bar uses `AppIcons.addTabBar`, never `AppIcons.add`.

### P19-CHARTS

- Done 2026-11-22. The Spending charts are in `lib/design/charts/` and
  exported from `design.dart`: `PeriodBarChart` (daily and monthly, average and
  limit lines, hatched incomplete period), `RingMeter` and `RingMeterGrid`,
  `SplitBar`, and `BillingStrip`. `ChartFrame`, `ChartTable`, `ChartTone`,
  `ChartMark`, `ChartColours` and the shared draw motion are in the same
  folder.

- **One frame, one table.** Every chart sits in `ChartFrame`: the frame owns
  the one accessible name and the "Show as table" disclosure. The chart's own
  pixels are inside `ExcludeSemantics`, so the reader hears one label and not
  the axis text. The disclosure uses the new l10n strings `chartShowAsTable`
  and `chartHideTable`; an empty data set uses `chartNoneRecorded`. A preview
  chart passes `preview: true` and has no table (PREVIEW-CHART).

- **Values and state.** Charts take `Money` and format through
  `lib/design/format/`. `chartAmountText` keeps the currency mark and the six
  dots in the hidden state; whole amounts drop a zero fraction (DESIGN 4:
  cents only when the amount has cents). Shares come from `Percent.split`
  (largest remainder), so a split adds to exactly 100%. A known zero total has
  zero shares. Unknown values are left out and named "Missing" or "None
  recorded"; no chart draws an invented zero.

- **Text scale and drawing.** Chart text scales to 2.0. The value gutter and
  the height grow with the text; above 1.3 only the end value labels and the
  end date labels stay (DESIGN 7.1). Only `lib/design/charts/` uses `double`
  coordinates. Draw-in uses the new `Motion.drawBar` / `drawLine` / `drawDot`
  values (400, 520 and 300 ms, inside the 900 ms cap) and shows the final
  state under reduce motion.

- **Lints.** `chart_requires_table` is now live: a file in
  `lib/design/charts/` that paints and has no `ChartFrame`, or has a frame and
  no `ChartTable` unless it is a preview, is reported. Infrastructure modules
  (`chart_frame.dart`, `chart_tone.dart`, `chart_values.dart`,
  `brand_mark.dart`) are exempt. Rule tests are in `test/tool/lints_test.dart`.

- **Evidence.** Widget tests in `test/design/charts_test.dart` cover the
  label, the table, the preview exception, the empty set, the hidden text and
  label, incomplete periods, exact shares, a zero total, the ring label and
  the billing states. Gallery `lib/design/gallery/charts_gallery.dart`;
  goldens `charts_{dark,light}_{1.0x,2.0x}.png` show the charts, the empty
  data sets, the open table and the hidden state. All images were inspected.

- **Open.** `AreaLineChart`, `CapsuleMeter` integration, `GlyphTimeline` and
  the other 7.2 classes stay out until their screens need them. Goldens use
  `/`-separated daily values from Appendix A; no chart reads the section
  colour. Reviewed 2026-11-22 (design and accessibility).

### P20-HERO-PERIOD

- Done 2026-11-22. HERO-PERIOD closes. `ObHeroVariant.period` draws the
  period line behind the number, masked from 45% at the left end to 0 at the
  right. The chart is inside `ExcludeSemantics` and `IgnorePointer`: the hero
  number stays the one reader stop and the chart takes no taps. The variant
  adds no table; the screen's chart carries it.

- The gallery hero uses a preview `PeriodBarChart` (no table) at 136 pt. A
  hero context line can hold an amount, so `ObHero` now takes
  `hiddenContextLine`. When the state is hidden and no masked line is given,
  the context line is not drawn; a word that may hold an amount never
  survives a switch to hidden. This is the privacy-first option in AGENTS 9.

### P20-HIDDEN-STATE

- Done 2026-11-22. `lib/app/hidden_amounts.dart` holds the presentation state.
  `HiddenAmountsController` is a `ChangeNotifier`; `HiddenAmountsHost` mounts
  it as `HiddenAmountsScope` (in `lib/design/format/hidden_amounts.dart`)
  above the router, so the state survives navigation and the lock. Riverpod is
  not a dependency in this checkout (its owning task has not landed), so the
  provider is the smallest type that fits the current app: one controller, one
  inherited scope. A later Riverpod binding can wrap the same scope without
  changing a component.

- **Persistence.** `HiddenAmountsStore` is a one-bit port.
  `MemoryHiddenAmountsStore` is the fresh-install default;
  `FileHiddenAmountsStore` writes `hidden=true|false` with a temp file and an
  atomic same-directory rename (the T08 control-file pattern). It holds no
  amount, no name, no time and no financial data. A read or write failure
  keeps the in-memory state and never reveals amounts. No new dependency and
  no network call.

- **What the state changes.** `MoneyText`, `ObHero`, `AmountInput` and every
  P19 chart read the scope; an explicit `hidden:` argument still wins for one
  local case. Amounts become `$······` in the pixels and in the spoken name;
  dates, counts and percentages stay. Charts keep their shape and hide amount
  text, axis amount labels and table amounts. A chart's table rows are built
  from the same state, so the table cannot leak an amount. No data record,
  projection or stored value changes when the state toggles.

- **Lints.** `hidden_mode_semantics` is now live on `lib/design/`: a widget
  with a `Money` or `ValueSpec` field (or one that formats money in its body)
  must declare `hidden` or read `HiddenAmountsScope`. The gallery is exempt
  (it is not a component). Rule tests are in `test/tool/lints_test.dart`.

- **Evidence.** `test/app/hidden_amounts_test.dart` (10) covers the
  controller, the store round-trip and file contents, the mask in text and
  semantics, the hero, persistence across a route push, percentages in a
  chart, and the period hero. Gallery
  `lib/design/gallery/phase2_hidden_gallery.dart`; goldens
  `phase2_hidden_{dark,light}_{1.0x,2.0x}.png` show every Phase 2 money
  component in the hidden state. The visible Hide amounts control stays with
  P29 (as the task states). Reviewed 2026-11-22 (design and accessibility).

### P21-ACCOUNTS

- Done 2026-11-22. C01 is one feature port and one controller. The port
  (`AccountsGateway` in `lib/features/accounts/account_models.dart`) has
  `listAccounts` and `createAccount`. Its production adapter belongs to the
  app composition over `AccountRepository` + `CommandRepository` (T07/T09);
  tests supply an in-memory vault adapter. No widget reads the database
  (AGENTS 6.2).

- **Save boundary.** `AccountSetupController.save` sends one `AccountSetup`.
  The adapter combines P14's `planCreateAccount` and
  `planSetOpeningBalance` into one `WritePlan` and one command, so the
  account, the inclusive anchor, the selected anchor pointer and the
  ChangeLog rows commit together. A command failure writes nothing; the
  controller keeps every entry and sets a typed error.

- **Amount entry.** The keypad builds a decimal string of major units through
  `Decimal` and `Money.fromDecimal`; no `double`, no parsing in the widget.
  An entered zero is a real balance; an empty field is "Missing" (G01-E). A
  card stores a positive owed amount in the draft; the adapter negates it for
  the signed anchor. The screen and the picker show "Owes $1,240", never a
  negative number.

- **Date.** The anchor date is a `LocalDate`; the default is the local
  calendar date at open. The helper states that the balance includes the date
  (G01-A). An invalid date disables Save and names the format.

- **Route.** One `AppRoute.accountEditor` (`/x42b`, id X42b) with the Wealth
  section. X42b is the shared form-family reference; C01 has no X id of its
  own, so no id is invented. The route pops with the new account.

- **Evidence.** `test/features/accounts/account_setup_vault_test.dart` runs
  the real in-memory vault through P14: one save writes one account, one
  anchor, one selected pointer and two ChangeLog entries; a zero anchor is
  real; a card stores a liability; a posting on the anchor date is not added
  twice. The controller, editor and picker tests cover the rest. Goldens:
  `screens_x42b_account_{editor,card,picker}_{dark,light}_{1.0x,2.0x}.png`.
  Reviewed 2026-11-22 (product and finance + design and accessibility).

### P21-CARD-LIMIT

- Still open after the 2026-11-22 follow-up. SPEC 6.6 lists the card limit as
  a required field, DATABASE_DESIGN 4.1 names `CardDetails`, but
  `SCHEMA.sql` has no `card_details` table and P14 has no write path. A limit
  field would be lost on Save. The card form therefore states "The credit
  limit is not saved in this version." and stores nothing invented. The data
  task that adds the table and its migration adds the field; this needs its
  own schema pull request (AGENTS 6.5).

### P21-UNWIRED-GATEWAY

- Closed at code level 2026-11-22 (review follow-up). `lib/app/accounts_gateway.dart`
  holds `SqlAccountsGateway`: P14's account reads and the combined
  `CreateAccount` + `SetOpeningBalance` command. `ContourRouter` and
  `ContourApp` accept an `AccountsGateway` and an `AccountDraftStore`, so the
  app composition can mount both without a screen or route change. The
  in-memory vault test and the route test use the production gateway.
- The release path still does not mount it. `main` has no verified SQLCipher
  build (DECISION-PENDING T07-CIPHER-BUILD) and PF-01 blocks personal-data
  persistence on a noncompliant path. Until that gate closes, the route uses
  `UnavailableAccountsGateway`, shows one factual line and writes nothing.
  This is the privacy-first option in AGENTS 9.

### P21-DRAFT

- Closed 2026-11-22 (review follow-up). `lib/features/accounts/account_draft.dart`
  holds the versioned C01 payload (schema 1), the load result (loaded, none,
  unsupported) and the store port. `lib/app/account_draft_store.dart` writes
  it through P13's `DraftRepository` under form type `account`.
- The controller reads the newest editing draft once; a user edit before the
  read wins. Every field change queues a write; a successful Save discards
  the draft, an explicit Discard removes it, and Close keeps it (P01). An
  older schema or unreadable payload is kept and reported as unsupported; no
  new draft is written over it until Discard. A failed write keeps the form
  fields.
- The tests use an in-memory vault and the P13 store: save, resume, second
  save, discard, old schema and a wrong-shape payload. No draft value is
  logged.

### P21-PAGE-BACKGROUND

- Fixed `lib/design/layout/page_background.dart`: a `BoxDecoration` paints
  either its colour or its gradient, so the old code dropped `surface.page`
  and left the page transparent. The page colour is now a base layer under
  the spotlight. Every `screens_*` golden changed from a transparent,
  white-ringed page to the designed page; all images were regenerated and
  inspected. The fix is a shared design change, recorded here because it
  appears in the P21 goldens. `check_contrast` still passes.

### P21-HOME-ENTRY

- Closed 2026-11-22 (review follow-up). The X03 Get started row 1 pushes
  `/x42b`, so Close and Save return to Home. The route test fills the form,
  saves through an injected gateway and checks the return. Home still shows
  no account read model; that waits for the vault composition, and the hero
  keeps its first-run state.

### P21-DATE-ENTRY

- Closed 2026-11-22 (review follow-up). `account_date_sheet.dart` opens from
  the balance-date row: day, month and year fields, a real-calendar check and
  one "Use date" action. The controller stores a `LocalDate`; the row shows
  the formatted date with `DateText`. An impossible day (31 February) keeps
  the sheet open with one factual line.

### P22-PAYMENT-FORM

- Decision (2026-11-22, P22). X20–X23 are built against SCREENS X20–X23, flow
  F03 steps 1–6, SPEC 3.1, 3.2, 8.3, 8.16 and 9.3. The form is amount first,
  one `SegmentedControl` control row, the amount hero, currency/date/account
  and Split pills, the merchant field, the category chips and the keypad. Save
  writes one `SavePayment` command and returns to the caller with the 5 s
  toast and Undo (SPEC 8.18). A category is optional, so an uncategorised
  payment saves (F03-A).
- Draft. The X20 payload is versioned (schema 1) and keeps the SPEC 8.16
  fields: type, amount text, currency, date, account, category, tags, merchant
  text, split parts, "please check" markers and, for an edit, the edited
  record with its expected revision. The payload is written through P13 under
  form type `payment`; a committed Save seals it; an older schema is kept and
  shown as unsupported. A keypad digit is not a separate write (SPEC 8.16);
  the amount is written with the next committed field, on a sheet, or on Save.
- Save. The gateway calls `CommandRepository.saveDraft` when a draft exists,
  so a repeated tap returns the recorded receipt and writes nothing (F03-B).
  A typed failure resolves through the receipt first (a lost reply is a
  success); only a proven uncommitted attempt is released with
  `releaseUncommitted`, and the next Save allocates a new operation id. A form
  with no draft store creates a private draft header for the one command.
- Edit. One Save with an edit identity calls `PaymentRepository.planUpdate`:
  the payment keeps its row and event, the live splits are soft-deleted with
  ChangeLog entries, the new parts are inserted and the revision advances. A
  stale revision fails and writes nothing (F03-C).
- Undo. `PaymentRepository.planUndoCreate` soft-deletes the event, the payment
  and its splits and keeps every identity; the account revision advances.
  Dependency checks, Activity history and a repeatable Undo stay with P29
  (SPEC 8.18). X20 shows the toast because the Phase 2 caller screens (Home,
  Spending) do not exist yet; P23, P27 and P29 move it to the caller if the
  composition needs it.
- Sources. Speak appears only when P24 supplies its handler. Scan QR, Receipt
  photo and Import a file are Phase 3 and are absent (SPEC 5.5: an unreleased
  source is absent from navigation). The Transfer segment appears only when
  P23 supplies the X26 route, so no segment is a dead control.
- Save label. The label carries the amount ("Save $24.00", X20) and falls
  back to "Save" before an amount is entered.

### P22-PAYMENT-DEFAULTS

- SPEC 3.2 says never ask for what the app can work out: date is today,
  currency is the last used, account is the last used for the category.
  - Date: the local today from the app boundary; the controller never reads a
    clock.
  - Currency: the composition may supply the last used code. Until a settings
    or account read provides it, the first listed account's currency is used,
    then USD.
  - Account: not guessed. The form asks with the account pill and keeps Save
    inactive until an account is chosen, because a wrong source account is a
    real financial error and AGENTS 9 prefers the easier-to-undo option. The
    spending read model (P26) can add "last used for this category" later.
  - Category: not guessed. A merchant rule (P28) or a sentence may fill it.
- The pending decision is recorded here rather than invented: last-used
  account and currency need a read model, so `P22-DEFAULTS` stays open until
  P26 or P28 supplies one.

### P22-CATEGORY-DOT

- Conflict (AGENTS 9). SCREENS X20 and X21 name 16 category tiles with dots
  "from data.category (may repeat)", while DESIGN 2.4 defines eight category
  hues plus Other/Needs/Wants/Invested/In cash and says "Never invent a
  colour". Coffee, Health, Travel, Education, Gifts, Family support and
  Insurance have no role.
- Decision: a name with a DESIGN 2.4 role shows that role; a name without one
  uses the Other role. Every category keeps a dot and a chart segment, no
  colour is invented, and the name identifies the category. The palette needs
  its own design pull request if it should cover all 16 names.
- X20's selected choice chip uses the section `action.selected.fill` from the
  shared `ChipRow` (P18), not the 2 pt `text.primary` edge printed in SCREENS
  X20. DESIGN 6.3 and the built component win on style; the screen text is the
  older mockup note.

### P22-DESIGN-FIXES

- `SegmentedControl` above 1.3 text scale used a fixed 120 pt per segment, so
  "Expense" clipped in the phase 2 gallery. Each segment now keeps 120 pt as a
  minimum and grows with its label.
- `SelectTile` (X21) and `DayCell` (X22) had no design component. Adding them
  to `lib/design/components/controls/` keeps every radius, edge, fill and
  `data.category` role inside `lib/design` (DESIGN 9) and lets the design lint
  pass. Both are in the phase 2 gallery with a semantics test and goldens.
  `SelectTile` sizes its column to its content, so a tile is 80 pt tall in a
  loose parent and still fills a grid cell.

### P23-TRANSFER

- X26 is a form for two owned accounts in one currency, with no fee field
  (DECISIONS CLOSED-G13-TRANSFER-FEES). `SaveTransfer` writes one event, two
  principals (sending negative, receiving positive), one `transfer_links` row
  and, when a record carries one, one `fee` posting on the sending account
  (F05-D). The principal changes neither money in nor spending (F05-A).
- The sending account decides the currency. A different receiving currency
  keeps Save inactive and shows that two-currency transfers are not in this
  version; X26b stays v1.1 (SPEC 6.3).
- The form starts on the first two accounts when they exist, and a draft
  restores both account ids. A draft is one `transfer` record in the P13 store
  with schema version 1 (SPEC 8.16); Discard deletes the payload and writes
  nothing.
- Undo is one compensating command: soft delete of the event, both principals,
  the fee and the link. Identities stay reserved (SPEC 8.18).
- A successful Save pops X26, then pops X20, so the caller of the expense form
  receives the same return path. A type switch on X26 goes to X20 with that
  type as route extra (SPEC 5.5).
- At text scale above 1.3 the 40 pt account badge is omitted in the From/To
  rows; the shared `SelectRow` otherwise squeezes the name to a broken
  syllable at 2.0. The balance stays visible and the row keeps the "From" or
  "To" line. Recorded as P23-LARGE-TEXT; a wider `SelectRow` reflow belongs to
  the design system.
- Boundary and imported transfer cases keep their existing owners:
  `P2-TRANSFER-BOUNDARY` (F05-E attribution Missing) and F05-B/C (Inbox and
  statement matching, P17).

### P24-VOICE

- `SpeechPort` (SPEC 8.19) reports availability, asks the permission once,
  emits text transcripts and never carries audio. `UnavailableSpeechPort` is
  the mounted default: it states the device cannot use voice and starts no
  request. The platform binding (`PlatformSpeechPort`) mounts only when the
  native side reports both `verified` and `onDevice`; every other answer
  resolves to unavailable, with no cloud fallback.
- The native verification record and the airplane-mode run of the nine SPEC
  8.10 sentences are not available on this host. They stay open as
  `P24-ENGINE-EVIDENCE`; X87, X24 and X25 are built and tested against a
  scripted port, so the engine can mount without screen changes.
- X24 and X25 are one route (`/x24`, X24). X25 saves through the P22
  `SavePayment` path, so Undo is unchanged. When the transcript leaves a
  required field empty, the primary action returns the transcript to X20 and
  X20 fills its own fields; nothing is written before Save (F04-C).
- X25 rows are informational in this task. Editing a row opens X22 or X21 in
  the ordinary form; the review rows do not become a second editor. Recorded
  as P24-REVIEW-ROWS.
- `AppDialog` and `AppSheet` now place their content in the opener's
  `SectionScope`. Before this change a dialog or sheet opened from Spending
  used the Home role colour, because the modal route builds under the root
  navigator. The golden images render sheet and dialog content directly, so
  they did not catch the missing scope. Recorded as P24-DIALOG-SECTION.
- X87 uses the design `IconTile` (40 pt rounded square) as its badge; the
  reference draws a 56 pt circle. The dialog keeps one title, one primary and
  one ghost action. Recorded as P24-MIC-BADGE; a 56 pt badge variant belongs
  to the design system.
- The static sound bars of X24 are omitted: they are decorative, and the
  design system has no bar component. The listening card keeps the transcript
  as the single live region. Recorded as P24-SOUND-BARS.

### P25-INBOX

- `InboxRepository.displayItems` (P25 read addition) returns one page of
  pending items with the source channel, the category name, the account name
  and the counterpart account name. It reads only; `page`, `pendingCount`,
  `items`, `selection`, `stageDecision`, `deleteStaged`, `confirmBatch` and
  `undoBatch` keep their P17 meaning. The feature port maps these types so no
  widget imports the data layer.
- The confirm label reads `selection()` from the gateway on every tick
  (F07-B). A decision stages through `stageDecision`; the affirmative answer
  ticks the item, a rejection leaves it out of the batch (P17 has no route for
  "two payments").
- Uncertain rows start unticked and their checkbox is disabled (F07-A). The
  item sheet still offers Confirm, because the sheet is the review step; only
  a transfer candidate waits for its decision.
- The Inbox has no producer in Phase 2 (`P2-INBOX-PRODUCER`), so X62 is the
  normal state until imports arrive. The X03 Inbox action now opens X60; it
  keeps the factual "0 items" label. A count badge needs a design
  `AppIconButton` badge variant and a producer, recorded as `P25-BADGE`.
- Omitted from the reference: the source chips and the source SplitBar, the
  "Last capture by source" card on X62, the swipe-to-delete gesture and the
  "Always use this category" rule toggle. The first two need a source count
  read; the rule toggle needs a rule write path in the Inbox port. Recorded as
  `P25-SOURCE-STRIP`, `P25-LAST-CAPTURE` and `P25-RULE-TOGGLE`. Delete stays in
  the item sheet, which the reference also provides.

### P26-SPENDING

- The Spending number sources are the P15 projection (money out, limit, left,
  used, month gone, same-days previous, category buckets, chart buckets) and a
  new read, `MoneyInProjection` (P26), which sums income postings only:
  transfers, refunds, reimbursements, loan money and sale proceeds are not
  income (SPEC 4.4). A parent income posting counts once; its splits are parts
  of the same amount.
- `SqlSpendingGateway` is one port for X30–X33. `SaveLimits` is the only
  write; it sends the budget month key of the budget month's start date and
  writes no payment (F08-E). The vault test asserts zero transactions after a
  save.
- X30 uses `ObHeroVariant.period` with a preview chart behind the number and a
  full `PeriodBarChart` card with the average line and "Show as table". The
  limit line is not drawn on the chart: with a monthly limit of $5,200 the
  daily bars collapse. The limit stays in the hero line. The same-days
  comparison sits under the chart ("Same days in September: $4,005. This month
  is $65 lower.").
- X33 has one keypad sheet per category and one Save. A limit of zero removes
  the limit. There is no Undo for `SaveLimits` because no compensating command
  exists; the screen pops to X32 after a save and shows no toast rather than a
  dead Undo control. Recorded as P26-LIMITS-UNDO.
- Open, recorded here so they do not become silent gaps:
  `P26-WIDGETS` (the cards are screen sections, not registry widgets with a
  default layout entry), `P26-CATEGORY-AVERAGES` (the printed 12-month
  category averages are not read; the fixture stops at the October rows),
  `P26-NEEDS-WANTS` (needs/wants follows category tags that Phase 2 does not
  author), `P26-WHERE-BARS` (X30c shows share and amount without the 0–50%
  bar), `P26-FIXED-RINGS` (no fixed-bill tag, so every ring is solid),
  `P26-MONEY-IN-COLOUR` (the money-in chart uses the neutral bar chrome),
  and `P26-MONEY-IN-SPLIT` (the invested split, sources and next income belong
  to Phase 4).
- The category rings do not open X36 yet; P27 builds that screen. Search stays
  absent (P2-SEARCH-ENTRY) and Next income stays absent
  (P2-SPEND-NEXT-INCOME).

### P26-SPEND-LAYOUT

- Owner request, 23 Nov 2026, from the Home reference photos. X30 now matches
  the Home card language. The top line is the `SPENT` kicker with the Home
  actions (hide amounts and the sliders Edit limits button), not a "Spending"
  title and date line.
- Hero order: the number, the line "of $5,200 limit", then the range and the
  limit status. A current (partial) period says "$1,260 left"; a closed period
  says "within the limit" or "$X over the limit". This follows SPEC 6.5 and
  SCREENS X30.
- Block order is hero, `PeriodBarChart`, period chips, same-days line,
  `By category`, rows. This puts the time-period control after the chart, as
  the owner asked; SCREENS X30 lists the chips before the chart. Owner
  decision, recorded here; SPEC and SCREENS keep their own text.
- `By category` shows the Needs/Wants `SplitStrip` (`Percent.split`, one
  decimal) above a fixed three-ring grid. Untagged spending keeps an
  `Unclassified` part so the strip covers the whole period. Large text drops
  the grid to one ring per row.
- Owner follow-up, 23 Nov 2026. The limit moved onto the number line
  ("$3,940 of $5,200 limit") through `ObHero.numberSuffix`; at large text the
  suffix moves under the number so the hero stays on one line. Each category
  is now a `RingMeterVariant.card`: `surface.tile` fill, `radius.m`, a 44 pt
  ring with its track and no today tick, centred name, spent and status, and
  the name in `text.secondary`, the spent in `numberXS`, and the status in
  `bodyS`. The grid uses one equal gap (`Space.m`) in both directions and one
  row height.
- Owner follow-up, 23 Nov 2026: X30 shows no decimals. `wholeMoney` in
  `lib/design/format/money_format.dart` rounds half-up to whole currency
  units, and every amount on the page uses it: hero, limit, status, chart
  bars and average, same-days line, ring values and the rows. The table and
  legend keep the same whole values.
- Owner follow-up, 23 Nov 2026: the six rows are three cards, in the
  reference order: Repeating and Money in; Where it goes and Budget; All
  payments and Edit limits. Each row has a grey line and a right value.
  `SpendingGateway.loadRows` reads the monthly summaries:
  `SpendingRowsView` (budget month, left, limit, category count, money in and
  its 12-month average, payment count, repeating count, this month's price
  changes, monthly repeating total). `SqlSpendingGateway` takes the
  `RepeatingGateway` and `PaymentsReadGateway` for these reads.
  `RepeatingView.changesThisMonth` counts schedules with a price change this
  month. The rows use the budget month, not the chart period.
- `SelectRow.stackValue` moves the value under the line at large text, so a
  long line such as "October · avg $9,267 a month" keeps its width. The X30
  rows set it. At normal text the value stays at the right, as in the
  reference.
- The X30 row cards use `GlassCardVariant.list`: 18 pt left, 12 pt right,
  12 pt top and bottom. The right value allows for the chevron glyph's optical
  inset, so the text and the chevron look equally inset. With `SelectRow`'s
  12 pt vertical padding, the space above the first row, between two rows and
  below the last row is 24 pt. The normal card padding (18 top, 10 bottom)
  gave three different spaces.
- Additions: `SpendingCategoryView.isEssential` (filled by
  `SqlSpendingGateway` from the P12 category rows), `RingMeter.iconUsesMark`,
  `RingMeterVariant.card`, `RingMeterGrid.maxColumns`, and five Lucide category
  icons (basket, utensils, bag, zap, ticket) under the existing ISC licence.
  The icon gallery goldens gain five cells; the X30, X32, chart and hidden
  goldens were regenerated and checked.

### P27-PAYMENTS

- New P27 reads: `PaymentReadRepository` (filtered list, exact count, one
  payment with its splits and tags) and `CategoryReadRepository` (monthly net
  and merchant totals, split contributions counted through the split rows and
  an unsplit payment once). `SqlPaymentsReadGateway` maps them to the feature
  port and never formats money.
- `DeletePayment` is the P22 soft-delete plan (event, payment, splits) and the
  new `PaymentRepository.planRestore` is its compensating command. A vault test
  proves the order: balance and the list count change once on delete and
  return once on Undo (F08-C).
- X38 edits a draft. Only "Show" returns it to X37; a dismissed sheet keeps
  the applied filter (F08-A). The Show label reads the exact count from the
  gateway. A cancelled X39b leaves the payment (F08-B).
- X37 groups rows by day with the day total. Known zero is the factual empty
  state ("No payments"); a net refund keeps its signed amount in the rows and
  the category net (F08-D). The day label uses the device date only for
  "Today" and "Yesterday"; the payment dates are local calendar dates.
- The X30 "All payments" row and the X30c category rows now open X37 and X36.
  A category ring in X30 does not open X36: `RingMeter` has no tap target, and
  adding one is a design-system change (P27-RING-LINK).
- Omitted from the reference and recorded: the X37 search field (X15,
  P2-SEARCH-ENTRY), the receipt image and similar-payments rows (Phase 3),
  the reimbursable/refund-expectation toggles (`P27-EXPECTATION-TOGGLES`: P07
  defines the record but no storage path exists in Phase 2), the X38 Tags and
  Amount rows and the Custom period (`P27-FILTER-ROWS`), the X39 More menu, and
  the X36 limit bar with a today tick (`P27-LIMIT-BAR`). The category facts
  show Used, Month gone and the 12-month average.

### P28-REPEATING-RULES

- `SqlRepeatingGateway` reads P16 schedules and occurrences and P12 categories
  and rules. The repeating list shows the next slot from the RRULE, the state of
  the current month from an `actual` occurrence, and a monthly total that
  converts weekly (×52 ÷ 12) and yearly (÷12) amounts. A Missing amount adds
  nothing to the total.
- `SaveSchedule` writes one schedule with an RRULE from the frequency and the
  first payment date. It writes no occurrence and no payment (F09-A).
  `StopSchedule` sets the end date from today and keeps every confirmed
  occurrence (F09-C).
- C03 writes one `categoryRule` with origin `user`; it never reclassifies a
  past payment, and a declined offer writes nothing (F09-D). X84 is reachable
  from Settings > Money and shows the use count.
- X30 gains a Repeating row. The tab bar Add is still not mounted
  (P18-SHELL-MOUNT), so "Add opens C02" from the reference is recorded as
  P28-TABBAR-ADD; C02 has its own route today.
- Omitted from the reference and recorded: the X34 billing strip
  (`P28-BILLING-STRIP`: a design strip exists but its paid/expected dot model
  needs a component change), the X35 cancellation address
  (`P28-CANCEL-ADDRESS`: the schedules table has no address column), the
  "Add it to the Inbox to confirm" toggle (`P28-AUTOCREATE`: the column exists,
  but the review-path edit needs a schedule edit screen), a category on a
  schedule (`P28-SCHEDULE-CATEGORY`: no column; the screen shows the schedule
  kind), category editing in C03 (`P28-CATEGORY-EDIT`), the retrospective rule
  batch, and a one-off future payment (still X20 with an Expected state).
- X35 shows the last six occurrences as rows with their state, not as the
  six-column chart of the reference (`P28-HISTORY-CHART`).

### P29-SETTINGS-LAYOUT

- Owner request, 24 Nov 2026, from `design-mockups/dark/IMG_5139.png`. X80
  now follows the mock: a kicker-only `‹ SETTINGS` header, the statement
  "Everything is on this phone.", then five cards with icon rows.
- The header differs from SCREENS X80, which names a "Settings" title and the
  sub-line "on this phone". The mock shows only the kicker. The mock wins for
  this screen; SPEC content does not change.
- Rows use `IconTile` (neutral variant), the name, an optional grey line, a
  right value in `bodyS` `text.primary`, and a chevron. Values come from the
  mock/SCREENS samples until their reads are wired: 3 on, 16 categories /
  24 rules, 3 saved, USD, 9 accounts, 1st, 1,234.56, the ten screen widget
  counts, Face ID, Last snapshot / Sun 11 Oct, Prices only, Simple mode,
  System, Version 1.0.
- `Investments` shows 5 widgets in the mock; SCREENS X80 shows 0. The mock
  value is used and the conflict is recorded here.
- Activity history stays as the last App row. The mock does not show it, but
  Settings is the only entry to C06. It is placed after About so the first
  three App rows match the mock.
- Additions: `IconTileVariant.neutral` (a `surface.tile` tile with the same
  edge and icon), five `x80` strings for the sections, and the row values.
  The X80 and component goldens were regenerated and checked.

### P29-HIDDEN-CONTROL
- `HiddenAmountsControllerScope` exposes the one presentation controller; the
  reusable `HideAmountsButton` sits in six headers: X03, X30, X36, X37, X39 and
  X60. The button is absent when no controller is mounted (previews and simple
  goldens). Two screens composes no amount line while hidden: X30 replaces the
  same-days sentence and X36 replaces the limit line. Hidden goldens exist for
  X30, X36, X37, X39 and X60 in dark/light at 1.0 and 2.0.
- X31, X32, X33, X34, X35, X42b and the remaining detail screens read the same
  scope and mask their money components, but some composed caption or value
  strings still use `formatMoney` directly. Recorded as `P29-HIDDEN-OTHER`
  until each is masked and golden-checked; no data changes with the state
  (SPEC 4.9).

### P29-HISTORY

- `HistoryRepository` reads `operation_receipts` with the command type and a
  compensating receipt flag. `SqlHistoryGateway` maps four families to their
  compensating command: `payment.create` (soft delete), `transfer.create`
  (whole-event soft delete), `payment.delete` (restore) and `inbox.confirm`
  (whole-batch undo). Every other command is listed as a change with no Undo
  (settings, limits, schedules, rules), as SPEC 8.18 requires.
- A `payment.create` or `transfer.create` entry is shown as reversed when its
  payment or event is soft-deleted; a `payment.delete` entry is reversible
  while the payment is deleted and reversed after a restore. `inbox.confirm`
  uses the compensating receipt.
- The history does not evaluate dependency blocks and has no per-entry detail
  sheet; `P29-HISTORY-BLOCKED` and `P29-HISTORY-DETAIL` record this. The screen
  hides every amount, merchant and account name by construction.
- Phase acceptance is recorded in `docs/PHASE2_ACCEPTANCE.md`. The 3.1 input
  target and the airplane-mode voice run stay open with their device
  dependencies; the integration smoke test was not run on this host.

### P29-SELECTROW-2X

- The X80 Settings golden at 2.0 text scale shows the shared `SelectRow` name
  and value colliding on long rows ("Main number on Home" and "Net worth").
  This is a design-system layout limit, not a P29 data change. The row keeps
  the correct value in the tree and at 1.0. A reflow rule (value on its own
  line above 1.3) belongs to `SelectRow` and its whole golden set; recorded
  here so the changed image is not accepted as correct.

### P29-DEMO-WIRING

- A debug build starts `DemoBootstrap` (`lib/app/demo/`). It opens an
  **in-memory** vault with `UnverifiedOpenCipher`, seeds synthetic data, builds
  every Phase 2 gateway and starts the normal app with `ContourRouter`. A
  release build still starts `ContourApp` with the factual unavailable gateways
  (PF-01, T07-CIPHER-BUILD).
- The seed is synthetic only: three accounts, one income and nine expense
  categories, November limits, ten payments, one transfer, three schedules with
  generated Expected occurrences, and two rules. It runs through the single
  command writer, so Activity history and ChangeLog have real entries.
- The demo starts on X03 Home, because the tab shell is not mounted
  (P18-SHELL-MOUNT) and Spending has no tab. A demo-only **Go to** card on Home
  opens X30 Spending and X20 Add. The other screens stay in the debug menu at
  `/dev/gallery`; `DEMO_ROUTE` opens one directly. The card is absent when the
  router does not set the demo entries, so the product Home is unchanged.
- The X03 date line now reads today's local date and the main currency instead
  of the fixed sample text. A golden passes a fixed date so the image is
  stable. Recorded as P29-HOME-DATE.
- Limits reset when the app restarts: the store is memory only and writes no
  file. This is not a release path and makes no persistence claim.
- The demo proves the screens and gateways on one device: the Appendix A-like
  numbers appear in X30, seeded payments appear in X37, categories in X36,
  schedules in X34, rules in X84 and confirmed operations in C06. Tests
  `test/app/demo_composition_test.dart` build the same composition and assert
  the live numbers, payments and history.
- Voice stays unavailable (no verified engine). The Inbox stays empty (no
  producer). Both show their factual states in the demo.

### GOLDEN-IMAGES-IGNORED

- Decision (2026-11-24, owner request). Golden PNG baselines are local test
  output, not source. `.gitignore` now ignores `test/golden/**/*.png` and
  `test/golden/**/failures/`, and the eight committed baselines
  (`components_*`, `gallery_*`) are removed from the index.

- What stays tracked: the golden harness, the `*_golden_test.dart` files and
  the update command. `flutter test --tags golden --update-goldens` writes a
  fresh baseline on any machine; a reviewer compares those local images.

- Conflict with AGENTS.md 7 ("screen changes have goldens") and AGENTS.md 8
  (reference images in the pull request). The rule is unchanged: a screen
  change still needs a reviewed golden. Only the storage changes, so the
  review compares a generated image instead of a committed one.

- Consequence: a clean clone has no baseline. Golden tests fail until the
  first `--update-goldens` run, and no diff can prove that a baseline did not
  silently change. If the review evidence must be auditable in git, revert
  this entry and commit the images again.
