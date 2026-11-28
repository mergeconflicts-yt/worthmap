# Contour — Phase 4 Tasks (Position)

Version: 2026-11-28. Status: **first screens built** (X40, X50 with the X51
day sheet, X42b). Account details, investments, Home final, month close and
recovery are planned. Scope: v1 Phase 4 only (SPEC 17.1). Authority order:
AGENTS.md, SPEC.md + docs/spec/, SYSTEM_DESIGN in
`docs/approved-architecture/SYSTEM_DESIGN.md`, DATABASE_DESIGN in
`docs/approved-architecture/DATABASE_DESIGN.md`, EXECUTION_SAFETY,
DESIGN.md + docs/design/, docs/screens/SCREENS.md, docs/flow.md +
docs/flows/USAGE_FLOWS_REFERENCE.md. Do not inspect wealthfolio/. PF-01 stays
in force. Use synthetic data only. Do not invent financial or privacy rules.

## Phase 4 scope

SPEC 17.1, "Phase 4 — Position: Home, Wealth, Investments, Plan basics,
backup":

- Accounts and all asset types with value methods, forms (X42, X42b). Account,
  Retirement, Cash and bank, Car, Term deposit, Loan and Card detail (X41,
  X41c–X41f, X47, X48). What you owe (X46). Shares from work (X49). Wealth
  (X40) with Expected and None recorded. About this number (X40b).
- Investments (X43), Holding detail (X44), Allocation by class, market,
  currency (X43b, X43c), Gains and tax (X43e), Dividends (X43f), Investment
  insights (X43h), glossary (X43j), basic Returns (X43g: XIRR, cumulative and
  annualised TWR; PERF-001), public market data (off by default), local and
  manual FX, offline state (X89).
- Home final (X10) and sheets (X11–X15), Calendar and Cash flow forecast
  (X50, X50b, X51), Monthly close and Month summary (X70, X71), Backup (X83).
- Accept when: users understand Home in 3–5 seconds (user test); every
  section 4 number matches the Appendix A fixture; attribution adds up;
  interest and contribution projections match fixtures; TWR and XIRR fixtures
  pass (13.12); a local snapshot restores with identical totals; an
  interrupted restore keeps a valid generation; monthly close takes under 10
  minutes with test data.

## Delivery status (2026-11-28)

- Built and tested:
  - P4-01 value projections (`lib/domain/values/value_projection.dart`, 26
    tests) and P4-01b: one number per item in Appendix A and every sample.
  - X40 Wealth: net worth hero, 1M/1Y/5Y chips, the three-series chart, the
    You own / You owe tabs with type tiles, the Not in net worth card from
    synthetic values, and the load, empty and error states. Tests:
    `test/features/wealth/x40_wealth_test.dart`, `test/app/demo_wealth_test.dart`
    plus four X40 goldens (light and dark at 1.0 and 2.0).
  - X50 Plan calendar: the month grid, flow glyphs, the before and after next
    income lists, and the X51 day sheet inside `lib/features/plan/x50_plan.dart`.
    Tests: `test/features/plan/x50_plan_test.dart` plus goldens.
  - X42b minimal account editor for a bank account, cash or credit card, with
    an inclusive opening balance (P21). The deposit form is not built.
  - X10 Home with data in the debug demo (DECISIONS `P4-HOME-DATA`). The
    release path still shows X03 until the vault composition.
- Absent and needed in this phase:
  - The account detail family, X40b, X46, X47, X48 and X49.
  - The whole investments model: securities, holdings, lots, investment
    transactions, realised gain, quotes and FX.
  - The X43 family, X89, X11–X15, X50b, X70, X71 and X83.
- Schema: the reference DDL already holds `accounts`, `balance_anchors`,
  `current_balance_anchors`, `securities`, `price_quotes`, `current_quotes`,
  `manual_quotes`, `fx_observations`, `holdings`, `investment_transactions`,
  `lots`, `lot_allocations`, `position_observations`, `month_closes`,
  `close_revisions`, `local_jobs` and `attachment_manifests`
  (`lib/data/db/schema/reference_schema.dart`). Schema version 10 adds
  `valuation_rules`, `card_details` and `loan_details`. Phase 4 adds typed
  reads and writers; it does not add a second model.
- Unchanged and not closed by Phase 4: `PF-01`, DB-A, DB-B,
  `T07-CIPHER-BUILD`, T08/T11 native bindings, `P21-UNWIRED-GATEWAY`.

## Start state (Phase 3 PDF slice, 2026-11-23)

- Accepted slice: `docs/PHASE3_ACCEPTANCE.md`; DECISIONS `P3-PDF-SUBSET`.
  CSV, Excel, OFX, QIF, CAMT.053, MT940, QR, receipt photo, holdings
  screenshot, share intake and `G03` are deferred with no route.
- `P3-32` (full phase acceptance) stays planned and deferred.
- Test state (measured 2026-11-28): `flutter test` 1200 pass; golden tests
  221 pass; `dart format`, `flutter analyze`, `custom_lint`,
  `check_tokens` and `check_contrast` (545 pairs) pass.
- Present and reusable: `lib/data/repositories/accounts.dart` (anchors,
  Missing, inclusive cut-off), `lib/app/wealth_gateway.dart` (net worth,
  own and owe, change), `lib/app/plan_gateway.dart` (Expected occurrences to
  45 days), `lib/domain/periods/` (period maths, budget month),
  `lib/domain/numbers/` (net worth target, wealth change), the imported
  balance anchors, the Inbox, and the whole `lib/design` set (charts,
  `TypeTile`, `SymbolCalendar`, `GaugeMeter`, `CapsuleMeter`).

## Correction gates this phase needs

A gate is prerequisite documentation work, not user approval. Land the
documentation change in its own pull request before dependent feature code
(USAGE_FLOWS "Implementation handoff" step 1; AGENTS 9). Status comes from
the gate table in `docs/flows/USAGE_FLOWS_REFERENCE.md`.

| Gate | Blocks in Phase 4 | Status | Task |
|---|---|---|---|
| `G03` Investment events | Holdings, lots, sales, position observations, X44 and all returns | **Open** | P4-11 |
| `G04` Basic returns | X43g XIRR/TWR; PERF-001 corrects SPEC 4.5, 6.7, 13.12, 17 and DESIGN X43/X43g/X43j together | **Open** | P4-17 |
| `G09` Goals and expected values | Vest expectations at today's price (X49); goals and target mix stay v1.1 | Not closed; goals stay v1.1 | P4-09 |
| `G10` Month close | X70/X71 revisions, coverage and evidence pins | **Open** | P4-21 |
| `G11` Local recovery | X83 generations, attachment and key leases, atomic switch | **Open** | P4-22 |
| `G14` Financial definitions | The four-part net worth bridge and the dated fixtures behind every section 4 number | Closed 2026-11-22 for the bridge and calculator definitions; the dated fixture is still needed | P4-10, P4-23 |

`G01`, `G02`, `G05`, `G06`, `G12`, `G13` stay closed and are used here as
written. `G07` is closed for voice only. `G08` holds: no mail connector.

## Planning gaps recorded in DECISIONS

These are decisions the sources do not settle. They go to
`docs/DECISIONS.md` "Open questions" with the preferred option when their
task starts:

- `CONTROL-ROW-SCOPE` — the X40 You own / You owe tabs and the X43 card
  controls may count as a second control row (SCREENS X40, X43; SPEC 3.3).
- `ADD-CONTROL-SCOPE` — X40 shows "None recorded" tiles that open Add. Check
  them against the one-add-control rule.
- `NW-ABOUT-ENTRY` — SPEC 4.7 leaves the entry point to X40b open. X10 and
  X40 show no (i) button.
- `REGULAR-INVEST` — the X43 "Regular investments" card needs a meaning the
  sources do not define.
- `NW-TARGET-PACE` — the "At +$X a year · [year] · Est." row needs a wording
  and an Est. rule. Goals ship in v1.1; the target line is only drawn when a
  target record exists.
- `TREE-TARGETS` — small treemap tiles can be under 44 pt. List is the full
  accessible path until decided.
- `P4-SCREEN-REFS` — `docs/screens/*.png` are absent in this checkout.
  Screens are built from `docs/screens/SCREENS.md`; record this per screen as
  Phase 2 and 3 did.
- `P4-VALUE-METHOD-BASIS` — decided 28 Nov 2026. The fixture regeneration it
  needs is P4-01b.
- `P4-RULE-STORAGE` — decided 28 Nov 2026. Schema version 10 holds the
  value rule, card details and loan details.

## Order and parallel tracks

- Track A — accounts and wealth: P4-01, P4-01b, P4-02, P4-02b, then P4-03 to
  P4-08. P4-09 follows P4-11; P4-10 follows P4-18.
- Track B — investments: P4-11 to P4-17. Starts with the P4-11 domain model.
  P4-09 needs P4-11.
- Track C — forecast and Home: P4-20 (needs P4-04), then P4-18 (needs
  P4-20), then P4-19 and P4-10.
- Track D — close and recovery: P4-21 (needs P4-18 and P4-20), then P4-22
  (`G11`).
- P4-01b lands after P4-01 and before P4-23.
- P4-23 runs last.

Shared files (`router.dart`, `tokens.json`, `pubspec.yaml`, database schema,
`docs/DECISIONS.md`) change in small separate pull requests (AGENTS 10).

## Tasks

### P4-01 — Value methods and projections (domain)

- Objective: build the pure projection for each value method and the rule
  that a new real value restarts the projection. Refs: SPEC 4.3–4.5, 9.2;
  SPEC 6.6; DATABASE_DESIGN 4.1; SCREENS X41c–X41f; DECISIONS
  `P4-VALUE-METHOD-BASIS`.
- Depends on: none (basis decided 28 Nov 2026). Blocks P4-02 to P4-08, P4-10
  and P4-11.
- Owner: Domain builder. Files allowed: `lib/domain/values/*`,
  `lib/core/`, `test/domain/values/*`.
- Contract: methods `marketPrice`, `interest`, `contribution`, `weightPrice`,
  `manual`, `depreciation`, `capitalAccount` (SPEC 9.2). Inputs are a real
  value, its date, a rule and a `LocalDate` "as of". Outputs are real,
  estimated (with the method named) or unavailable with a reason. No
  `DateTime.now()`, no `double`, no advice words. The basis is SPEC 9.2:
  actual days, 365-day year, the selected compounding, one half-even round,
  a stop at maturity.
- Acceptance: deposit $10,000 at 4.1% monthly gives $10,278 on 13 Oct 2026
  and $10,312 at maturity; simple interest gives $10,272.96; pension $22,700
  plus $500 a month plus 5% a year gives $23,933.95; depreciation stops at
  zero; a leap day counts once; a missing price or rate is unavailable,
  never zero.
- Evidence: `test/domain/values/value_projection_test.dart` (26 tests).
  Reviewer: product and finance.

### P4-01b — Regenerate the Appendix A value fixtures (done)

- Objective: align Appendix A and the screen samples with the decided basis.
- Refs: SPEC 4.7, 9.2; Appendix A in `docs/spec/spec-calculation.md`;
  DECISIONS `P4-VALUE-METHOD-BASIS`; SCREENS X10, X40, X41b–X41f, X42b;
  `docs/spec/spec-widgets.md`.
- Depends on: P4-01. Blocks P4-23. Owner: Planner + design owner for the
  goldens. Files allowed: SPEC and SCREENS documents, `docs/DECISIONS.md`,
  feature test fixtures, `test/golden/*`.
- Contract: one number per item, used everywhere. Retirement $23,934 and
  its growth +$234; deposit $10,278 and its interest +$278; maturity stays
  $10,312; what you own $197,462; net worth $187,822. Shift the earlier
  levels by the same −$78 so every change stays: 30 September close
  $182,332, 12-month start $170,922, 1-month start $181,222. Keep the
  monthly bridge with Values $0. The net worth target becomes $812,178 to
  go and $4,778 a month. Update every screen sample, widget sample and test
  constant, and regenerate the goldens.
- Status: done 2026-11-28 (this change).
- Acceptance: every section 6 total comes from Appendix A; the attribution
  adds up; no test constant keeps the old values; all AGENTS 4 commands pass
  and every changed golden is checked.
- Evidence: the document diff, the test list and the regenerated goldens.
  Reviewer: product and finance + design and accessibility.

### P4-02 — Account and asset reads (data) (done for reads and create)

- Objective: typed reads for the account list, its type, value method and
  details, plus the writes for a new account with its dated value.
- Refs: SPEC 9.2; DATABASE_DESIGN 4.1–4.3; DECISIONS `CLOSED-G01`.
- Depends on: P4-01. Blocks P4-03 to P4-10.
- Owner: Data builder. Files allowed: `lib/data/repositories/accounts.dart`,
  `lib/data/repositories/valuations.dart`, `test/data/*`, `lib/data/db/`.
- Contract: one read model per screen family: account row, method details
  (card, loan, grant, deposit), current value with its state and date, and
  the inclusion and liquidity switches. Authored writes go through the single
  command writer with `ChangeLog` and revision bumps (AGENTS 6.5).
- Acceptance: F10-A to F10-E pass; a liability is stored signed and shown
  positive; a card credit and an overdraft keep their signs; a value edit
  restarts the estimate; an unknown value is Missing; no query feeds totals
  without an Appendix A test.
- Evidence: repository tests with Appendix A data and a migration note (no
  schema change expected). Reviewer: product and finance + privacy and
  security.
- Status: reads and account create are done (2026-11-28):
  `AccountRepository.findById` returns the account row, its institution and
  its value at the read date; `planCreateAccount` stores the institution,
  ownership share, minimum balance and overdraft limit. Tests:
  `test/data/account_detail_test.dart` (5). The value method has no storage;
  see `P4-RULE-STORAGE` and P4-02b.

### P4-02b — Value-rule and account-detail storage (data) (done)

- Objective: add the tables that hold the value method, card details and loan
  details, so a saved account reopens with its rule.
- Refs: SPEC 9.2; DATABASE_DESIGN 4.1; DECISIONS `P4-RULE-STORAGE`.
- Depends on: the `P4-RULE-STORAGE` decision; P4-01. Blocks P4-03, P4-04.
- Owner: Data builder. Files allowed: `lib/data/db/migrations/v010_*.dart`,
  `lib/data/db/migration.dart`, `lib/data/repositories/accounts.dart`,
  `test/data/migration_010_test.dart`, `test/data/*`.
- Contract: one authored row per account per method family, with UUID v7,
  timestamps, soft delete and revision; parameters as bounded JSON; the last
  real value and date; a method enum that matches SPEC 9.2. A new real value
  restarts the estimate (P4-01). Card and loan details hold the SPEC 9.2
  fields. The migration is additive and runs inside the existing transaction.
- Acceptance: a fresh vault and an upgraded version 9 vault both hold the
  tables; a rule round-trips; a second rule for one account replaces the
  first through a command; a deleted account keeps its rule row soft-deleted;
  the migration test uses a version 9 fixture; all AGENTS 4 commands pass.
- Evidence: migration test, repository tests. Reviewer: product and finance +
  privacy and security.
- Status: done (2026-11-28). Schema version 10 adds `valuation_rules`,
  `card_details` and `loan_details`; the rule round-trip is in
  `AccountRepository.ruleFor` and `planSaveRule`. Tests:
  `test/data/migration_010_test.dart` (3); the rule tests in
  `test/data/account_detail_test.dart`.

### P4-03 — Add, choose type and the typed forms (X42) (in progress)

- Objective: wire the type chooser and the shared form family for each
  asset type listed in SPEC 6.6.
- Refs: SCREENS X42, X42b; SPEC 5.3, 6.6; flows F10.
- Depends on: P4-02. Blocks P4-04.
- Owner: Feature builder. Files allowed: `lib/features/wealth/*`
  (X42, the form family), `lib/features/accounts/*`, l10n, one route group,
  `test/golden/*`.
- Contract: type list as SPEC 6.6 (Cash, Investments, Retirement, Deposits,
  Things, You owe, Other) with counts as meta. Each type opens its form with
  the required and optional fields in the SPEC 6.6 table. Save writes the
  account, its dated value and its method in one command. Cancel writes
  nothing. X42b keeps the amount-first reference look.
- Acceptance: each type saves and reopens with its value; a missing required
  field blocks Save with a factual message; the type list matches the
  SPEC 6.6 groups; goldens at 1.0 and 2.0, light and dark.
- Evidence: widget tests per type, goldens, F10-A. Reviewer: product and
  finance + design and accessibility.
- Status (2026-11-28): the type model and the deposit save path are done.
  - `AccountKind` now holds the full SPEC 6.6 type set with the authored
    database value, the seven groups and the liability flag. The three
    gateways map a stored type through `AccountKind.fromDatabase`.
  - `DepositSetup` and `DepositGateway.createDeposit` write the account, the
    inclusive anchor and the `interest` rule with bounded JSON parameters in
    one commit. Tests: `test/features/accounts/account_setup_vault_test.dart`
    (two new cases).
  - Remaining: the X42 chooser, the shared form family for pension, vehicle,
    property, gold, loan, card and the manual types, the type facts and the
    goldens.

### P4-04 — Account detail family (X41, X41c–X41f, X41b)

- Objective: build the five account detail screens and the update-value
  sheet.
- Refs: SCREENS X41, X41b–X41f; SPEC 6.6; flows F10 step 4.
- Depends on: P4-03. Blocks P4-05 to P4-08.
- Owner: Feature builder. Files allowed: `lib/features/accounts/*`,
  `lib/features/wealth/*` (rows that open them), l10n, routes, goldens.
- Contract: one template per kind. Checking shows recorded balances only (a
  day without a record is not zero), the last 30 days, the two switches,
  payments due from the account, recent payments and the last statement.
  Retirement shows the last statement as a solid point and the rule estimate
  as a dashed line, and the parts add up to the change. Cash and bank shows
  Available until [date] and the until-next-income chart. Car shows value and
  loan left on one scale. Deposit shows the term bar and maturity. X41b
  saves a real value and date and restarts the estimate.
- Acceptance: F10-B to F10-E pass; the estimates restart; Missing and Est.
  labels follow SPEC 4.9; the X41b cancel keeps the old value; goldens.
- Evidence: widget tests with Appendix A values, goldens, one test per state.
  Reviewer: product and finance + design and accessibility.

### P4-05 — What you owe (X46)

- Objective: the owed total, loans, cards and the empty other type.
- Refs: SCREENS X46; SPEC 6.6; flows F10 step 1.
- Depends on: P4-04. Blocks P4-07.
- Owner: Feature builder.
- Contract: total from liability balances; split bar with largest-remainder
  shares; payments a month and interest and fees from recorded payments;
  loan gauge (paid off, left, borrowed); card facts (full, minimum, paying
  account after payment, limit used); "None recorded" other tile with the
  caption.
- Acceptance: the Appendix A figures match; an empty type shows None
  recorded; the row opens X47 or X48; goldens.
- Evidence: widget tests, goldens. Reviewer: product and finance + design.

### P4-06 — Loan detail (X47)

- Objective: the amortisation schedule and the next payments.
- Refs: SCREENS X47; SPEC 6.6, 13.7, 13.16; flows F10.
- Depends on: P4-05.
- Owner: Feature builder with Domain builder for the schedule.
- Contract: exact monthly schedule from the rate, EMI and day; principal and
  interest split; left after each EMI; last EMI date; paid from and full
  schedule links. No rounding drift: the final EMI clears the balance.
- Acceptance: 13.16 and the four X47 sample rows match; a floating rate
  with a reset date does not invent a new schedule; goldens.
- Evidence: schedule unit tests, widget tests, goldens. Reviewer: product and
  finance.

### P4-07 — Card detail (X48)

- Objective: the statement view of one card.
- Refs: SCREENS X48; SPEC 6.6, 9.2; flows F10.
- Depends on: P4-05.
- Owner: Feature builder.
- Contract: full amount and minimum from the statement record; due date and
  days; paying account after payment; limit used with new spending since the
  statement; statement close, interest, fees, annual fee, instalment plans.
  "Pay this card" opens the transfer form.
- Acceptance: a card credit stays positive-owed; the limit bar uses percent
  tokens; missing statement shows Missing, never 0; goldens.
- Evidence: widget tests, goldens. Reviewer: product and finance + design.

### P4-08 — Wealth completion (X40)

- Objective: complete X40 to the SPEC 6.6 contract.
- Refs: SPEC 6.6; SCREENS X40; DECISIONS `CONTROL-ROW-SCOPE`,
  `ADD-CONTROL-SCOPE`; flows F10.
- Depends on: P4-04 to P4-07. Blocks P4-10.
- Owner: Feature builder. Files allowed: `lib/features/wealth/*`,
  `lib/app/wealth_gateway.dart`.
- Contract: type totals from the account records (not demo values); the
  type facts; the Expected card (unvested shares at today's price, owed to
  you, dividends next 6 months); tile taps to their screens; empty types with
  the Add route. Resolve `CONTROL-ROW-SCOPE` and `ADD-CONTROL-SCOPE` first.
- Acceptance: every type total equals the sum of its accounts; Expected
  items never enter the totals; a missing account makes its type Missing;
  goldens at 1.0 and 2.0.
- Known gaps at P4-01b (28 Nov 2026): the type facts read "[n] accounts"
  instead of the SCREENS facts ("401(k) · Est.", "Est. · 12 Nov"); the period
  chips clip at the right edge at 2.0 text scale. Fix both here.
- Evidence: widget tests, goldens, one test per state. Reviewer: product and
  finance + design.

### P4-09 — Shares from work (X49)

- Objective: grants, vest schedules and the Expected view.
- Refs: SCREENS X49; SPEC 6.6, 9.5; flows F13; `G09` (expectation part).
- Depends on: P4-08 and the security model (P4-11). Blocks P4-23.
- Owner: Feature builder with Data builder for the grant tables.
- Contract: up to 12 months of vests and share purchases at today's price
  with "Est."; past vests never become owned holdings without confirmation;
  an Inbox item appears on the vest date; unvested, tax withheld and share of
  net worth. No pension or broker connection.
- Acceptance: F13-A to F13-D pass; a repeated generation makes no duplicate;
  withholding and net shares reconcile; goldens.
- Evidence: widget tests, repository tests, goldens. Reviewer: product and
  finance + privacy and security.

### P4-10 — About this number (X40b)

- Objective: the attribution sheet behind the net worth number.
- Refs: SPEC 4.7; SCREENS X40b; DECISIONS `P2-TRANSFER-BOUNDARY`,
  `NW-ABOUT-ENTRY`; flows F02.
- Depends on: P4-08 and P4-18. Blocks P4-23.
- Owner: Feature builder with Domain builder for the bridge.
- Contract: four parts (kept, markets, currency, values) on one period and
  cut-off; hide a zero part; a missing part marks the attribution Missing; a
  boundary transfer marks it Missing until a part is defined. Entry point per
  `NW-ABOUT-ENTRY`.
- Acceptance: the parts add up to the total change on Appendix A; no
  residual fill (NUM-001); Missing never shows 0; goldens.
- Evidence: domain tests, widget tests, goldens. Reviewer: product and
  finance.

### P4-11 — Investments model (domain and data)

- Objective: holdings, lots, investment transactions, realised gain and
  position observations.
- Refs: SPEC 4.5, 9.4; DATABASE_DESIGN 4.4–4.6; flows F11, F12; `G03`.
- Depends on: P4-01. Blocks P4-12 to P4-17.
- Owner: Domain builder + Data builder, two pull requests in this order.
- Contract: average cost first (FIFO per account later); buy fees and taxes
  in cost basis; sale proceeds less fees and cost; realised gain fixed at
  the sale; split, transfer, vest, ESPP and dividend types; exact quote
  precision; a position observation never invents trades or cost.
- Acceptance: Appendix A totals; F11-B (100 to 121 over 730 days gives 21%
  total and 10% annual); F12-A to F12-E; a duplicate observation is
  idempotent; incomplete broker rows stay drafts.
- Evidence: domain tests with 13.12 fixtures, repository tests. Reviewer:
  product and finance + privacy and security.

### P4-12 — Prices, FX and the offline state (X89)

- Objective: local/manual FX, the off-by-default public price path and the
  stale-price state.
- Refs: SPEC 12, 4.1, 4.9; SYSTEM_DESIGN 11; SCREENS X89; flows F19.
- Depends on: P4-11. Blocks P4-13, P4-17.
- Owner: Data builder + Feature builder for X89.
- Contract: network only in `lib/data/prices/`; quotes and metadata encrypted
  with provider, timestamp, currency and precision; a failed update keeps the
  last quote and date; a missing rate makes dependent totals Missing; older
  rate marks Estimated. X89 keeps the caller period and shows last prices and
  "Today's change Missing", never +$0.
- Acceptance: no request while the switch is off; no request during import;
  a wrong or missing rate never becomes zero; the offline banner and Est.
  labels match SPEC 4.9; goldens.
- Evidence: fake gateway tests, network policy test, goldens. Reviewer:
  privacy and security + product and finance.

### P4-13 — Investments hub (X43)

- Objective: the value hero, holdings card, currency card, gain card and
  rows.
- Refs: SPEC 6.7; SCREENS X43; flows F11.
- Depends on: P4-11, P4-12. Blocks P4-14 to P4-17.
- Owner: Feature builder.
- Contract: chips 1D/1M/1Y/All (default 1D); change = value less money put
  in, percent = TWR; cost-basis dashed line; facts; Holdings · Sectors ·
  Markets with Bubbles · List · Tree; filter and sort; sold status; currency
  card; total gain with the three parts. Resolve `REGULAR-INVEST` and
  `TREE-TARGETS` first. Write nothing financial.
- Acceptance: F11-A (exact dates across cards, chart and table), F11-C to
  F11-F; hidden amounts in List only; every bubble has a spoken label;
  goldens.
- Evidence: widget tests, goldens. Reviewer: product and finance + design
  and accessibility.

### P4-14 — Holding detail (X44)

- Objective: one holding with its price history, position facts, lots and
  sources.
- Refs: SCREENS X44; SPEC 6.7, 9.4.
- Depends on: P4-13. Blocks P4-23.
- Owner: Feature builder.
- Contract: price chart with end dot, average-cost line and lots at their
  price; spent, unrealised, dividends, shares of investments and net worth,
  realised; where the shares came from; lots with dates and gains; next vest
  and sector. A missing price makes the value Missing.
- Acceptance: F11-A; lot gains sum to the unrealised gain; goldens.
- Evidence: widget tests, goldens. Reviewer: product and finance.

### P4-15 — Allocation (X43b, X43c, X43d)

- Objective: one grouping screen for class, market, sector and currency.
- Refs: SCREENS X43b–X43d; SPEC 6.7.
- Depends on: P4-13. Blocks P4-23.
- Owner: Feature builder.
- Contract: group chips; ring chart with largest first and whole-percent
  shares that add to 100; groups with value, share and holdings; a caption
  per grouping; sector look-through toggle off by default; target mix "Not
  set" until v1.1.
- Acceptance: shares use `Percent.split`; the ring and the key agree; a
  missing value makes the group Missing; goldens.
- Evidence: widget tests, goldens. Reviewer: product and finance + design.

### P4-16 — Gains, dividends, insights and glossary (X43e, X43f, X43h, X43j)

- Objective: the four read-only analysis screens.
- Refs: SCREENS X43e, X43f, X43h, X43j; SPEC 6.7, 4.5, 4.7.
- Depends on: P4-13. Blocks P4-23.
- Owner: Feature builder.
- Contract: gains split into unrealised by holding and sales in the period;
  dividends received and expected with the calendar (solid received, dashed
  expected, Est.); insights limited to facts from recorded data; the glossary
  opens on its term and returns to the caller with the same period. No
  advice words, no benchmark claim.
- Acceptance: dividend totals equal the recorded and expected rows; the
  glossary labels match SPEC 4.5; goldens.
- Evidence: widget tests, goldens. Reviewer: product and finance + design.

### P4-17 — Returns (X43g)

- Objective: cumulative TWR, annualised TWR, XIRR and the metric
  availability rules.
- Refs: SPEC 4.5, 13.12; SCREENS X43g; flows F11; `G04`, PERF-001.
- Depends on: P4-11, P4-12, P4-13; the `G04` documentation correction.
- Owner: Domain builder then Feature builder. Files allowed:
  `lib/domain/returns/*`, `lib/features/investments/*`.
- Contract: one period control for exactly those dates and currency.
  Under one full year: cumulative TWR and the money-weighted return for the
  period, never labelled XIRR. Annual periods: XIRR per year; annualised TWR
  is the CAGR of the return index. Each metric is available or Missing on
  its own. Multiple XIRR roots or no result gives Not available. The
  benchmark chart stays v1.1.
- Acceptance: F11-B (100 to 121, 730 days, 21% total, 10% annual), F11-C
  (deposits without growth give 0%), F11-D, F11-E, F11-F; results within
  0.01 points of the reference fixture; goldens.
- Evidence: formula unit tests, widget tests, goldens. Reviewer: product and
  finance.

### P4-18 — Home final and its sheets (X10–X14)

- Objective: complete Home with data and add the three sheets.
- Refs: SPEC 6.2, 4.6, 5.5; SCREENS X10–X14; flows F02; DECISIONS
  `P2-SPEND-NEXT-INCOME`, `X10-DUE-BASIS`, `GL-TIMELINE-HEIGHT`.
- Depends on: P4-04, P4-09, P4-13, P4-20. Blocks P4-19, P4-10.
- Owner: Feature builder.
- Contract: the main-number choice; the sheets for main number, available
  breakdown and hidden amounts; the target line and 12-month line; the
  attention card; the shortcut row. Close `P2-SPEND-NEXT-INCOME` and
  `X10-DUE-BASIS` when the next income date exists.
- Acceptance: Home opens in 3–5 seconds for five test users; every section 4
  number matches the fixture; hidden amounts keep chart shape; goldens at
  1.0 and 2.0.
- Evidence: widget tests, user-test note, goldens. Reviewer: design and
  accessibility + product and finance.

### P4-19 — Search (X15)

- Objective: one local search over payments, merchants, accounts and notes.
- Ref: SCREENS X15; SPEC 6.2, 6.5; flows F02; DECISIONS `P2-SEARCH-ENTRY`.
- Depends on: P4-18. Blocks P4-23.
- Owner: Feature builder.
- Contract: one field and the chips All, Payments, Merchants, Accounts and
  Notes (control row). A merchant result opens Category detail; a payment
  result opens Payment detail. Results come from local records only; the
  screen writes nothing and makes no network call. Close
  `P2-SEARCH-ENTRY` and add the Search control to X30 and X37.
- Acceptance: an empty query shows recent items; a Missing value stays
  Missing; no result is written; goldens.
- Evidence: widget tests, goldens. Reviewer: design and accessibility +
  privacy and security.

### P4-20 — Cash flow forecast (X50b, X51)

- Objective: the lowest expected balance and the event-day step chart.
- Refs: SPEC 4.8, 4.4; SCREENS X50b, X51; flows F14.
- Depends on: P4-04 (balances) and the occurrence reads. Blocks P4-18,
  P4-21.
- Owner: Feature builder with Domain builder for the forecast.
- Contract: day-by-day balance per paying account from repeating payments,
  statements, EMIs, premiums, repeating investments and taxes due; card
  charges reach cash only through the statement payment; event-day balances
  only; below-zero shown in the same neutral style; no next income means
  "next 30 days". The X51 day sheet keeps the caller month and day.
- Acceptance: F14-A (2,415 due, 19,035 left), F14-B, F14-C, F14-D, F14-E;
  the step chart and the table agree; goldens.
- Evidence: forecast unit tests, widget tests, goldens. Reviewer: product and
  finance.

### P4-21 — Monthly close and month summary (X70, X71)

- Objective: the five-step close and the saved summary.
- Refs: SPEC 6.9; SCREENS X70, X71; flows F18; `G10`.
- Depends on: P4-04, P4-18, P4-20. Blocks P4-22.
- Owner: Feature builder with Data builder for the close tables.
- Contract: step n of 5 with Skip; a missing statement is named "missing";
  continue or skip records progress; a month is closed only after "Save and
  finish"; the close saves its revision atomically and then requests a
  snapshot; a snapshot failure keeps the close. Later corrections create a
  traceable revision.
- Acceptance: F18-A to F18-E; close under 10 minutes with test data; a
  skipped step keeps Missing or Est. labels; goldens.
- Evidence: widget tests, repository tests, timing note, goldens. Reviewer:
  product and finance + design.

### P4-22 — Private recovery (X83)

- Objective: the local snapshot list, a new snapshot and restore.
- Refs: SPEC 14; SCREENS X83; flows F20; SYSTEM_DESIGN 12–13; `G11`.
- Depends on: P4-21, `G11`. Blocks P4-23.
- Owner: Data builder + Feature builder.
- Contract: encrypted snapshot in app-private storage, excluded from OS
  backup; up to eight; authenticated encryption with a device-bound key;
  capture a consistent database state; validate before publish; keep the
  last valid snapshot; restore stages a complete generation and switches
  atomically after confirmation; no export, share, merge or cloud path.
- Acceptance: F20-A to F20-F; restored totals match; an interrupted restore
  keeps one valid generation; a failed snapshot keeps the old one; goldens.
- Evidence: repository tests with a damaged and a valid snapshot; interruption
  fixture; goldens. Reviewer: privacy and security + product and finance.

### P4-23 — Phase 4 acceptance

- Objective: run the SPEC 17.1 acceptance and write the report.
- Refs: SPEC 17.1; AGENTS 7; `docs/PHASE3_ACCEPTANCE.md` as the shape.
- Depends on: P4-01 to P4-22. Blocks v1 release planning.
- Owner: Feature builder with all reviewers. Files allowed:
  `docs/PHASE4_ACCEPTANCE.md`, `integration_test/phase4_*.dart`,
  `docs/TASKS_PHASE4.md` (status only), `docs/DECISIONS.md`.
- Contract: every accept item with evidence, or a stated not-met item.
- Acceptance: the 3–5 second Home user test; every section 4 number against
  Appendix A; attribution adds up; interest and contribution projections;
  13.12 TWR and XIRR; a snapshot restore with identical totals; an
  interrupted restore keeps a valid generation; a close under 10 minutes;
  all AGENTS 4 commands pass.
- Evidence: the report with command logs and the device note. Reviewer:
  product and finance + design and accessibility + privacy and security.

## Phase 4 exit criteria

- SPEC 17.1 "Accept when" items pass with evidence, or are named as not met.
- AGENTS 7 definition of done for every task.
- No gate stays open for a shipped feature. `G03`, `G04`, `G09`, `G10` and
  `G11` close in their own documentation pull requests before the code that
  needs them.
- `P2-SEARCH-ENTRY`, `P2-SPEND-NEXT-INCOME`, `X10-DUE-BASIS` and
  `GL-TIMELINE-HEIGHT` close with the tasks that settle them.
- Device gates keep their status. Phase 4 does not close `PF-01`, DB-A,
  DB-B, `T07-CIPHER-BUILD` or the T08/T11 native bindings.

## Not in Phase 4

- Goals (X52, X53) and the net worth target record: v1.1 (`G09`).
- Protect and policies (X55, X56), the emergency sheet (X57): v1.1 and v1.2.
- Tax and year (X58), Tools and calculators (X59, X59b): v1.2.
- The benchmark chart on Returns, allocation by sector inside funds, a
  target mix against current values: v1.1.
- CSV, Excel, OFX, QIF, CAMT.053, MT940, QR, receipt photo, holdings
  screenshot and share intake: deferred Phase 3 items with no route.
- Local capture sources (X81): v1.1. No email connector (X82), ever.
- Any network path, export, sync, analytics or remote processing.
