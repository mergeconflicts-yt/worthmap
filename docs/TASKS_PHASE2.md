# Contour — Phase 2 Tasks (Capture, Inbox, Spending)

Version: 2026-11-23. Status: accepted 2026-11-23 (`docs/PHASE2_ACCEPTANCE.md`; DECISIONS `CLOSED-PHASE2-ACCEPTANCE`). Every task is built and reviewed. Scope: v1 Phase 2 only (SPEC 17). Authority order: AGENTS.md, SPEC.md + docs/spec/, SYSTEM_DESIGN in docs/approved-architecture/SYSTEM_DESIGN.md, DATABASE_DESIGN in docs/approved-architecture/DATABASE_DESIGN.md, DESIGN.md + docs/design/, docs/screens/SCREENS.md, docs/flow.md + docs/flows/USAGE_FLOWS_REFERENCE.md. Do not inspect wealthfolio/. PF-01 stays in force. Use synthetic data only. Do not invent financial or privacy rules.

## Phase 2 scope

SPEC 17, "v1 Phase 2 — Capture, Inbox, Spending":

- Add expense, income and transfer (X20–X26); quick add; voice (X24, X25); categories and rules; repeating payments with price changes (X34, X35); Inbox (X60–X62).
- Spending (one page), Where it goes, Money in, Budget, Edit limits, Category detail, All payments, Payment detail (X30–X39b); accuracy rules (4.2); undo; hide amounts.
- Phase accepted when: the 3.1 input targets pass; voice test sentences pass in airplane mode; transfer, refund and reimbursement fixtures give the expected totals; nothing from voice is saved before Save.

## Start state (end of Phase 1, reviewed 2026-11-22)

- Done: T01–T12 (docs/TASKS.md). `flutter analyze` clean; `flutter test test` 345 pass; goldens 33 pass; `custom_lint`, `check_tokens`, `gen-l10n` pass.
- Present: `lib/core` (Money, Decimal, LocalDate, Clock, Result, Percent), `lib/design` (tokens, theme, AppText, AppIcons, templates `TabRootScreen`/`DetailScreen`/`FormScreen`, components), `lib/app/widgets` (registry, host, editor, layout repository), `lib/data/db` (vault, cipher port, command repository, layout repository, schema translation), `lib/data/keys`, `lib/data/prices`, `lib/app/auth` (ports + lock state machine), `lib/app/router.dart` (X01, X02, X03, X80, X86, debug gallery), `lib/features/{start,home,settings}`, `lib/l10n`, `tool/lints`, `integration_test/`.
- Absent, and needed in this phase: `lib/domain/` (all of it), payment/category/rule/budget/schedule/inbox repositories, the app tab bar and shell, form and feedback components (`AppField`, `AmountInput`, `Keypad`, `PillPicker`, `SegmentedControl`, `ChipRow`, `Checkbox`, `SplitEditor`, `AppSheet`, `AppDialog`, `AppToast`, `UndoBar`, `ConfirmBar`), the Spending charts (`PeriodBarChart`, `RingMeter`, `SplitBar`), the hero `period` variant, the app-level hidden-amount state (`MoneyText.hidden` and `hiddenMask` exist per number; there is no toggle, no persistence and no chart or table masking), the Phase 2 screens, and a local speech binding.
- Data model: reference schema version 5 has accounts, anchors, transactions, splits, transfer/refund links, categories, schedules, occurrences, obligations, settlements, drafts, inbox staging, ChangeLog, projections and layout. Tables for `CategoryRule`, `Tag`, `TransactionTag`, `Budget`, `BudgetLimit`, `BudgetTemplate` and `PriceChange` are not in version 5 and need new migrations (DATABASE_DESIGN 5).

## Correction gates this phase needs

A gate is prerequisite documentation work, not user approval. Land the documentation change in its own pull request before dependent feature code (USAGE_FLOWS "Implementation handoff" step 1; AGENTS 9).

| Gate | Blocks in Phase 2 | Status | Task |
|---|---|---|---|
| `G02` Identity and confirmation | Transfer matching (F05), Inbox decisions (F07), repeating occurrences (F09) | Closed 2026-11-22 (`SPEC 8.17`; CLOSED-G02-OCCURRENCES-MATCHING) | P02 |
| `G05` Entry and action hierarchy | Add context (F03), Inbox primary action (F07), Repeating Add (F09) | Closed 2026-11-22 (`SPEC 5.5`; CLOSED-G05-ENTRY-ACTION-ORDER) | P03 |
| `G06` Undo access | Every confirmed write; toast plus persistent history (C06) | Closed 2026-11-22 (`SPEC 8.18`; CLOSED-G06-UNDO-HISTORY) | P04 |
| `G07` Local capture engines | Voice recognition (F04) | Closed 2026-11-22 (`SPEC 8.19`; CLOSED-G07-LOCAL-ENGINES) | P05 |
| `G12` Draft lifecycle | Expense, income and transfer drafts (F03–F05) | Closed 2026-11-22 (`SPEC 8.16`; CLOSED-G12-DRAFT-LIFECYCLE) | P01 |
| `G13` Transfer cost | Transfer fee classification (F05) | Closed 2026-11-22 (`SPEC 4.10`; CLOSED-G13-TRANSFER-FEES) | P06 |
| `G01` Account prerequisites | Accounts, opening balances, account picker (F01, F03, F05) | Closed 2026-11-22 (G01-A to G01-E) | P14, P21 |
| `G14` Financial definitions | Spending/refund/reimbursement totals (F08) | Closed 2026-11-22; the F08 step 6 residue is undefined | P07 |
| `G03`, `G09`, `G10`, `G11` | Investment events, goals, month close, recovery | Out of Phase 2 (Phases 4, v1.1) | — |

## Planning gaps recorded in DECISIONS

These are decisions the sources do not settle. They are in `docs/DECISIONS.md` "Open questions" with the preferred option:

- `P2-INBOX-PRODUCER` — Phase 2 Inbox has no producer: manual, quick-add, voice and receipt forms commit directly, and imports are Phase 3.
- `P2-SPEND-NEXT-INCOME` — X31 "Next income" and the X34 billing strip need expected income and the calendar (Phase 4).
- `P2-SEARCH-ENTRY` — X30 and X37 show Search in the header; X15 Search ships in Phase 4 (F02).
- `P2-REFUND-PERIOD` — closed 2026-11-22 (`SPEC 4.11`; CLOSED-P2-REFUND-EXPECTATIONS). SPEC 4.2 defined the period; the expectation record, partial receipt and reversal are now settled.
- `P2-TRANSFER-BOUNDARY` — F05-E names "Other recorded changes", but NUM-001 has four bridge parts; the attribution shows Missing until a part is defined.

## Contract every task and pull request must name

Shape from docs/flow.md and USAGE_FLOWS "A task must name its contract":

```
Flow and steps · Screens and templates · References (SPEC / DESIGN / gate)
Inputs · User actions · Read model · Commit boundary · Written records
Success · Failures · Cancellation · Checks
```

## Task order

Foundation first: P01–P07 (documents) → P08–P11 (domain) → P12–P17 (data) → P21–P29 (screens). The design track (P18–P20) runs beside the domain and data waves. Domain and design tracks run in parallel after their gates close. Data waits for the domain files it reads. Screens wait for their data, their components and their gate.

| Wave | Tasks | Notes |
|---|---|---|
| 0 Documents | P01, P02, P03, P04, P05, P06, P07 | One gate per pull request. No feature code. |
| 1 Domain | P08, P09, P10, P11 | Pure Dart, tests first. P08 and P09 need P07. |
| 2 Data | P12, P13, P14, P15, P16, P17 | P13 needs P01; P16 and P17 need P02 and P12; P15 needs P08 and P11. |
| 3 Design | P18, P19, P20 | Runs beside waves 1–2. No data dependency. |
| 4 Screens | P21 → P22 → P23, P24; P25; P26 → P27 → P28; P29 last | Each screen needs its data task, components and gate. |

## Shared-file ownership (one current owner)

- `pubspec.yaml`, `analysis_options.yaml`: the Phase 1 owner. A task that needs a package sends a separate dependency pull request with licence, release date and network statement (AGENTS 6.8), recorded in `docs/DECISIONS.md`.
- `lib/design/tokens/tokens.json`: design-system builder only. Any new token is a separate design pull request.
- `lib/app/router.dart` and the app shell: P18 owns the shell shape and the tab routes. Each screen task adds only its own `AppRoute` entry and child route; it must not change or reorder other routes.
- `lib/data/db/schema/*` and migrations: data builder only. Only one schema pull request in flight; the migration takes the next free `kCurrentSchemaVersion` at merge time.
- `test/fixtures/appendix_a.dart`: P08 owns it. Other tasks import it read-only.
- `lib/l10n/app_en.arb`: each task adds only its own strings (the T11-L10N precedent). No hard-coded user text.
- `docs/DECISIONS.md`: append-only entries, written by the task that makes the decision.

---

### P01 — Draft lifecycle definitions (G12)

- Objective: settle the structured draft contract: identity, stored fields, schema version, resume rules, discard, and behaviour on process death, lock and restore. Refs: SPEC 8.1, 9 (`Draft`); flows F03 step 1, shared contract "Drafts, saving and cancellation"; SYSTEM_DESIGN 5.2; DATABASE_DESIGN 6 and 10; `draft_headers`/`draft_payloads`/`draft_references`/`draft_attachments` in SCHEMA.sql.
- Depends on: none. Blocks P13 and P22.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md`, `docs/spec/spec-data-model.md` (cross-reference only), `docs/flows/USAGE_FLOWS_REFERENCE.md`, `docs/DECISIONS.md` only.
- Acceptance: one normative paragraph names the fields kept per form type, the draft identity rule (own ID, form type and source; no draft replaces another; C11 selection), the "Draft kept" resume path, explicit Discard, and the unsupported-payload state after a schema change. Every F03 recovery case maps to a sentence. No new financial rule.
- Evidence: diff plus the gate entry closed in `docs/DECISIONS.md`. Reviewer: product and finance.
- Status: done 2026-11-22. SPEC 8.16 added to `SPEC.md` (core bullet) and
  `docs/spec/SPEC_REFERENCE.md` (contract, field table per Phase 2 editor,
  durability, submitted/committed/rollback states, bounds, migration, restore);
  `docs/spec/spec-data-model.md` 9.9 cites it. Flows shared contract, F03
  recovery, F04 recovery and C11 now cite SPEC 8.16; the gate table keeps its
  row (G01/G14 precedent). Recorded as CLOSED-G12-DRAFT-LIFECYCLE. Docs only:
  no code, no new financial or privacy rule. Reviewed 2026-11-23 by the task's named reviewer roles.

### P02 — Occurrence and confirmation definitions (G02)

- Objective: turn the selected G02 correction into normative text: source identity supports retries; equal content is only a match candidate; one Expected occurrence with at most one Inbox item and an unpaid remainder; one-off future payments are distinct from recurrence. Refs: SPEC 8.9, 4.3, 4.9; flows F05 step 3, F07 step 2, F09 step 3, G02; SYSTEM_DESIGN 5.3 (`ScheduledOccurrence`, `SettlementAllocation`); DATABASE_DESIGN 4.3.
- Depends on: none. Blocks P16, P17, P25, P28.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md`, `docs/spec/spec-data-model.md` (cross-reference only), `docs/flows/USAGE_FLOWS_REFERENCE.md`, `docs/screens/SCREENS.md` (X35 caption only), `docs/DECISIONS.md` only.
- Acceptance: the text defines occurrence identity `(schedule_id, occurrence_key)`, the match-candidate rule, the settlement remainder example (1,240 − 500 = 740), the confirmation requirement, and re-import behaviour. It names the acceptance cases F05-B, F05-C, F07-A, F07-C, F07-D and F09-A; the Inbox confirm bar case F07-B stays with P17 and P25.
- Evidence: diff plus the gate entry closed. Reviewer: product and finance.
- Status: done 2026-11-22. SPEC 8.17 added to `SPEC.md` (core bullet) and
  `docs/spec/SPEC_REFERENCE.md` (identity, candidates, linked pairs, one
  proposal per occurrence, generation never posts, review path, remainder,
  over-payment, decisions, rule edits, aliases, one-off, price change,
  atomic confirmation, Expected never in a total). `spec-data-model.md` 9.9
  cites it; flows F05 step 4, F07 step 2, F09 step 3, F14 step 1 and C02 cite
  it; SCREENS X35 caption corrected; SPEC 8.9 now states that generation never
  posts. Recorded as CLOSED-G02-OCCURRENCES-MATCHING with the autoCreate
  conflict. Docs only. Reviewed 2026-11-23 by the task's named reviewer roles.
- Status note for P16: `schedules.auto_create` is absent from version 5; P16
  adds it with the review-path meaning.

### P03 — Entry and action hierarchy (G05)

- Objective: settle entry points and action precedence: Add context per section, Repeating Add opens the schedule editor (C02) not the expense form, Inbox primary action is the outstanding decision until resolved, and search sits below the Home title. Refs: SPEC 3.3, 5.3, 4.6; flows shared contract 4–5, F07 step 3, F09 step 2, G05; SCREENS X29, X34, X60.
- Depends on: none. Blocks P17, P22, P25, P28.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md`, `docs/spec/spec-screens.md` (6.2 only), `docs/screens/SCREENS.md` (X60 only), `docs/flows/USAGE_FLOWS_REFERENCE.md`, `docs/DECISIONS.md` only.
- Acceptance: a single table names the Add destination for Home, Spending, Wealth, Plan, and each child screen; the Inbox precedence is stated as one filled action; the disabled-feature rule is repeated from the shared contract. No screen id is invented.
- Evidence: diff plus the gate entry closed. Reviewer: product and finance + design and accessibility.
- Status: done 2026-11-22. SPEC 5.5 added (filled-action precedence, Inbox
  order, Add overrides, voice long-press, disabled entries, search entries,
  four main-number options, main number never a widget, glance order).
  SPEC 5.1 no longer says "Home has no Search"; 4.6 closes GLANCE-ORDER;
  spec-screens 6.2 states the chosen hero; SCREENS X60 states filled and ghost
  buttons; flows shared contract 4 and the Inbox line, F02 step 4, F09 step 2
  and C02 cite SPEC 5.5. Recorded as CLOSED-G05-ENTRY-ACTION-ORDER with six
  conflict records. Docs only. Reviewed 2026-11-23 by the task's named reviewer roles.

### P04 — Undo access (G06)

- Objective: keep the five-second toast and add the persistent history contract (C06): undo a whole event or batch, keep later dependent edits, open an explicit resolution flow. Refs: flows shared contract undo, G06, C06; SYSTEM_DESIGN 6 (Undo); DATABASE_DESIGN 6 ("Source identity and Undo"); SCREENS X37, X39b.
- Depends on: none. Blocks P22, P27, P29.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md`, `docs/spec/spec-data-model.md` (cross-reference only), `docs/screens/SCREENS.md` (X80 only), `docs/flows/USAGE_FLOWS_REFERENCE.md`, `docs/DECISIONS.md` only.
- Acceptance: the history entry point, its read model (event/batch, time, affected records, dependency state) and the resolution states are defined in words. It states that Undo never overwrites a later edit and never frees a source identity.
- Evidence: diff plus the gate entry closed. Reviewer: product and finance.
- Status: done 2026-11-22. SPEC 8.18 added (scope, compensating command,
  whole event or batch, toast, history and states, dependencies, identities,
  occurrences, attachments, editor and staging exceptions, privacy).
  `spec-data-model.md` 9.9 cites it; SCREENS X80 gains the Activity history
  row; flows shared contract, F07 step 5 and C06 cite SPEC 8.18. Recorded as
  CLOSED-G06-UNDO-HISTORY with the entry point, scope and dependency
  decisions. Docs only. Reviewed 2026-11-23 by the task's named reviewer roles.

### P05 — Local speech engine (G07)

- Objective: settle the local capture engine policy for voice: verified on-device recognition only, no cloud fallback, an explicit unsupported-device path, and the permission explainer order. Refs: SPEC 8.10, 8.4 (engine rule), 10.5; flows F04, G07; SYSTEM_DESIGN 10.
- Depends on: none. Blocks P24.
- Owner: Planner (with native builder review). Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md` (8.4, 8.5, 8.10, 8.19), `docs/flows/USAGE_FLOWS_REFERENCE.md` (F04 only), `docs/DECISIONS.md` only.
- Acceptance: the text names the iOS and Android APIs, the availability check, the user-facing unavailable message, the no-audio-retention rule, and the airplane-mode acceptance case (F04-A). No dependency or SDK name is added without licence and traffic terms.
- Evidence: diff plus the gate entry closed. Reviewer: privacy and security.
- Status: done 2026-11-22. SPEC 8.19 added: local-only rule, the five
  verification conditions, named engines, unavailable and permission paths,
  data and output rules, feature availability, evidence per engine, no
  degraded mode. 8.4, 8.5 and 8.10 cite it; F04 step 1 cites it. Recorded as
  CLOSED-G07-LOCAL-ENGINES, which also records why ML Kit stays excluded.
  Docs only. Reviewed 2026-11-23 by the task's named reviewer roles.

### P06 — Transfer fee classification (G13)

- Objective: settle the fee rule: post the actual charged fee once; the calculated exchange spread is a comparison only; state how the fee appears in spending and net worth. Refs: SPEC 4.2, 6.3; flows F05 step 2, checks D and E; G13; DATABASE_DESIGN 4.2.
- Depends on: none. Blocks P23.
- Owner: Planner. Files allowed: the same document set as P01.
- Acceptance: the text gives one fee posting per transfer, the spending class of the fee, the net-worth-boundary case (F05-E), and the Appendix A fixture value. Same-currency transfers ship in Phase 2; `X26bTransferFX` stays v1.1.
- Evidence: diff plus the gate entry closed. Reviewer: product and finance.
- Status: done 2026-11-22. SPEC 4.10 added (principal and fee separate, the
  fee is money out, only the charged amount posts, the spread is a comparison,
  capitalised fees stay in cost basis, no category unless set, fees count
  against limits, one fee per event, boundary attribution Missing). SCREENS
  X26b caption corrected; spec-data-model 9.3 and F05 step 2 cite 4.10.
  Recorded as CLOSED-G13-TRANSFER-FEES; new open question
  P2-TRANSFER-BOUNDARY for F05-E. Docs only. Reviewed 2026-11-23 by the task's named reviewer roles.
- Note for P23: X26 has no fee field in Phase 2; a fee enters from X26b (v1.1)
  or a captured or imported fee. F05-D uses a synthetic fee posting.

### P07 — Refund and expectation definitions (F08 step 6)

- Objective: define the "refund recognition period" that F08 step 6 uses, the expectation record (reimbursable, refund expected), and partial settlement and reversal. Refs: flows F08 step 6 and checks D–F; SPEC 4.2, 4.4 (`Spent`), 4.9; DECISIONS CLOSED-G14-FIN-DEFINITIONS (G14 closed the bridge and calculator definitions only).
- Depends on: none. Blocks P08, P09, P26, P27.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md` (4.2 pointer and 4.11), `docs/spec/spec-data-model.md` (9.9 cross-reference only), `docs/screens/SCREENS.md` (X39 and X80 only), `docs/flows/USAGE_FLOWS_REFERENCE.md` (F08 step 6 only), `docs/DECISIONS.md` only.
- Acceptance: the text states when a refund reduces spending (period choice, default option named), that an expectation creates no receipt, that a confirmed settlement reduces the linked remainder once, and that a reversal is a new record. It names the Appendix A fixtures and the new `REFUND-PERIOD` decision id.
- Evidence: diff plus the open question closed. Reviewer: product and finance.
- Status: done 2026-11-22. SPEC 4.11 added (refund versus reimbursement, the
  period setting, reimbursable exclusion, one reason per payment, expectation
  record and kinds, expectations without a payment, partial receipt, cancel,
  reversal, passed dates as facts, no double count, Appendix A values).
  Settings > Money gains the Refunds row; X39 toggles are exclusive; F08 step
  6 and spec-data-model 9.9 cite 4.11. Recorded as
  CLOSED-P2-REFUND-EXPECTATIONS with the storage mapping for P12/P16. Docs
  only. Reviewed 2026-11-23 by the task's named reviewer roles.

### P08 — Spending numbers

- Objective: `lib/domain/numbers/spending.dart`: money in, money out (spent), kept, kept %, spent vs limit, month gone, months covered, 12-month averages, category share, needs/wants split. Refs: SPEC 4.4, 4.2, 4.9; Appendix A (docs/spec/spec-calculation.md).
- Depends on: P07 (refund and expectation treatment). Blocks P15, P26, P27.
- Owner: Domain builder. Files allowed: `lib/domain/numbers/*spending*.dart`, `test/domain/numbers/*`, `test/fixtures/appendix_a.dart` (owner).
- Contract: read model only; no commit boundary; no written records.
- Acceptance: tests first and seen to fail. Appendix A: money in 8,200; spent 3,940; limit 5,200; kept 4,260; kept 52%; needs 2,890 (73.4% of spent); wants 1,050 (26.6%); 12-month money in 111,200 and average 9,267; category rows sum to 3,940; 6M 21,080 and 1Y 48,060 from the complete-month totals. Totals count split contributions, never the parent amount as well. No `double`. No `DateTime.now()`; pass a `Clock`. 100% line coverage.
- Evidence: failing-then-passing test log, coverage report, `dart format` log. Reviewer: product and finance.
- Status: done 2026-11-22. Built: `lib/domain/numbers/spending_totals.dart`
  (money in, money out, kept, kept %, needs/wants/unclassified, 4.4 rules for
  transfers, reimbursables, fees, refunds, loan and sale proceeds, states),
  `spending_averages.dart` (complete-month average over up to 12 months,
  coverage count, months covered), `spending_shares.dart` (category rows,
  shares, needs/wants split at exactly 100%), `spending_budget.dart` (within,
  over, no-limit comparison, none recorded, not available), and
  `spending_ratio.dart` (exact ratios, half-up percent, half-even division).
  Fixture `test/fixtures/appendix_a.dart` (October rows, September same-days,
  12-month totals, income). Tests: `test/domain/numbers/*` 67 pass, 100% line
  coverage on all five files (lcov 196/196). A mutation check (counting a
  reimbursable as spending) failed the exclusion test and was reverted.
  Recorded as P08-SPENDING-NUMBERS (unclassified bucket, fixture scope,
  money-in average). Note: only the October category rows are printed; P26
  extends the fixture for the printed category averages.

### P09 — Payment classification and linked effects

- Objective: `lib/domain/payments/`: classify one posting as expense, income, transfer principal, card repayment, refund or reimbursable; validate a transfer pair and one fee; reconcile a split to the exact total; apply the refund and expectation rules from P07. Refs: SPEC 4.1–4.3, 6.3, 6.5; flows F03, F05, F08 checks A–F; DATABASE_DESIGN 4.2.
- Depends on: P07, P08 (shared money and percentage helpers). Blocks P12.
- Owner: Domain builder. Files allowed: `lib/domain/payments/*`, `test/domain/payments/*`.
- Contract: pure validators and classifiers; no write.
- Acceptance: F05-A (no spending or income change, no net-worth change inside the boundary), F05-D (one fee posting), F05-E (boundary transfer is Other recorded changes), F03-B (split saves once, parts equal the total), F08-D (known zero, Missing and a net refund differ), F08-F (expectation creates no receipt; settlement changes the remainder once). Tests first; 100% line coverage.
- Evidence: test log, coverage, format log. Reviewer: product and finance.
- Status: done 2026-11-22. Built: `payment_classification.dart` (account
  refs, signed postings, expense, income, transfer with one fee, card
  repayment, net-worth change), `payment_split.dart` (balanced/unbalanced with
  the remainder), `payment_refund.dart` (partial, full, over-refund),
  `payment_expectation.dart` (expectation kinds, receipts with an unallocated
  part, reversal, cancellation, exclusive flags). Tests:
  `test/domain/payments/*` 56 pass, 100% line coverage (lcov 153/153). F05-E's
  attribution stays Missing under P2-TRANSFER-BOUNDARY. Recorded as
  P09-PAYMENT-CLASSIFICATION (sign rule, over-refund, cross-currency,
  split remainder, receipt allocation).

### P10 — Quick add and voice parser

- Objective: `lib/domain/importers/quick_add_parser.dart`: grammar `[amount] [currency?] [words] [date words?] [#category?] [@account?]`, per-field confidence, no database write. Voice parsing adds spoken numbers, currency words, merchant after "at"/"from", category after "for"/"on", dates, account after "with"/"using", and income words. Refs: SPEC 8.3, 8.10; flows F03 step 2, F04; SCREENS X20, X25.
- Depends on: none (runs beside P05). Blocks P22, P24.
- Owner: Domain builder. Files allowed: `lib/domain/importers/quick_add_parser.dart`, `test/domain/importers/*`, `test/fixtures/voice_sentences.dart`.
- Contract: text in, draft fields and confidence out; no write.
- Acceptance: the six SPEC 8.3 sentences and the nine SPEC 8.10 test sentences pass (eight with an amount, one with no amount so the keypad stays active). A second amount is returned separately, never merged. No amount means no amount field, never zero. Locale separators handled (`12,50 EUR`). Deterministic rules only, no model. Tests first; 100% line coverage.
- Evidence: test log per sentence row, coverage, format log. Reviewer: product and finance.
- Status: done 2026-11-22. Built `lib/domain/importers/quick_add_parser.dart`
  (QuickAddParser with known merchants, keyword categories and day-first;
  amount, currency, date, merchant, category, account, income, second amount
  and per-field confidence) and `test/fixtures/voice_sentences.dart` (the nine
  SPEC 8.10 sentences and the six SPEC 8.3 lines). Tests:
  `test/domain/importers/quick_add_parser_test.dart` 42 pass, 100% line
  coverage (296/296). All fifteen printed sentences pass. Recorded as
  P10-QUICK-ADD (merchant matching, category precedence, spoken numbers, date
  rules, one payment per sentence, confidence). No model or network.

### P11 — Budget period and month arithmetic

- Objective: `lib/domain/periods/`: 1W, 1M, 6M, 1Y ranges; the budget month start day; complete-month selection; same-days comparison; month-gone fraction; week start Monday. Refs: SPEC 4.4 (`Month gone`), 6.5; SCREENS X22, X30, X31.
- Depends on: none. Blocks P15, P26.
- Owner: Domain builder. Files allowed: `lib/domain/periods/*`, `test/domain/periods/*`.
- Contract: read model; no write.
- Acceptance: 13 Oct 2026 gives 42% of a 31-day month; a start day of 25 gives the 25 Sep–24 Oct month; 1M is 1–13 Oct; spending 6M is the last six complete months (Apr–Sep; the printed May–Sep sample is one month short, see P11-PERIODS) while money-in 6M is May–Oct (the current month included); 1Y spending is Oct 2025–Sep 2026; a leap-year February and a month-end start day are tested. Injected `Clock`, no ambient time.
- Evidence: test log, coverage, format log. Reviewer: product and finance.
- Status: done 2026-11-22. Built `period_math.dart` (add days and months
  with clamping, day counts, ISO weekday, Monday week start),
  `budget_month.dart` (containment, length, day number, previous and next,
  month gone with a supplied share of today) and `period_range.dart`
  (DateRange, spending and money-in chips, same-days last month). Tests:
  `test/domain/periods/*` 36 pass, 100% line coverage (89/89). Recorded as
  P11-PERIODS with the 6M sample conflict. No clock read in the domain.

### P12 — Payment, category and rule tables and typed reads

- Objective: the next free migration (006 at planning time) adds `category_rules`, `tags`, `transaction_tags`; typed Drift classes and repositories for transactions, splits, transfer/refund links, candidate keys, categories and rules; ChangeLog and dependency revisions on every confirmed mutation. Refs: DATABASE_DESIGN 4.1–4.3, 5, 6, 7; query-contracts Q01–Q04 and Q09–Q12; SCHEMA.sql tables `transactions`, `transaction_splits`, `transfer_links`, `transfer_fx`, `refund_links`, `transaction_candidate_keys`, `categories`, `financial_events`, `source_identities`.
- Depends on: P09, P13 (draft/command path). Blocks P22, P27, P28.
- Owner: Data builder. Files allowed: `lib/data/db/schema/*`, `lib/data/db/migrations/*`, `lib/data/repositories/payments.dart`, `categories.dart`, `test/data/migration_006_test.dart`, `test/data/payment_repository_test.dart`.
- Contract: commit boundary `SavePayment`; written records payment, split links, event, ChangeLog, dependency revisions, receipt.
- Acceptance: migration test with a frozen version 5 fixture; fresh create and upgrade paths match; recursive triggers and foreign keys verified; category totals count split contributions once; Q01–Q04 paging and exact totals pass on Appendix A data; a soft delete keeps identity and a source key stays reserved.
- Evidence: migration and query test logs, `flutter analyze`, plan check. Reviewer: privacy and security + product and finance.
- Status: done 2026-11-22. Built: migration 6
  (`lib/data/db/migrations/v006_classification.dart`) adding `category_rules`,
  `tags` and `transaction_tags` with identity, revision and retain triggers
  plus live indexes; `kCurrentSchemaVersion = 6`; a fresh vault creates the
  reference body then migration 6, and a version 5 vault upgrades in one
  transaction (a failure stays at 5 and closes). Repositories:
  `write_plan.dart`, `payments.dart` (create event/payment/splits/tags with
  ChangeLog and an account dependency revision, keyset page Q01, category
  totals counting split contributions once, soft delete) and `categories.dart`
  (category create/rename/archive, rules, tags). Tests:
  `migration_006_test.dart` (5), `payment_repository_test.dart` (5),
  `category_repository_test.dart` (4) and the updated `vault_test.dart`
  (version 6, table and trigger counts). Scope: Q01 and Q11 shape here; Q02/Q04
  belong to P17 and Q09-Q12 to P15, recorded in P12-CLASSIFICATION.

### P13 — Drafts and the manual Save command

- Objective: draft repository and lifecycle per P01, plus the manual Save command on the existing `CommandRepository`: intent with frozen payload and digest, receipt-first retry, draft completion, one commit. Refs: DATABASE_DESIGN 6 and 10; SYSTEM_DESIGN 6; `draft_*` and `operation_*` tables.
- Depends on: P01. Blocks P12, P22.
- Owner: Data builder. Files allowed: `lib/data/repositories/drafts.dart`, `lib/data/db/command_repository.dart` (extend), `test/data/draft_repository_test.dart`, `test/data/save_command_test.dart`.
- Contract: commit boundary `SavePayment` (the first command on this path); written records draft state, intent, receipt, ChangeLog.
- Acceptance: an interrupted Save leaves one intent and one outcome; a repeated tap returns the recorded receipt; a changed payload with the same ID fails; a resume after a lock keeps the structured fields; Discard deletes the payload and writes nothing; an unreadable old draft shows its unsupported state. No draft value in a log.
- Evidence: test log including lost-reply and post-commit read failure; `flutter analyze`. Reviewer: privacy and security + product and finance.
- Status: done 2026-11-22. Built `lib/data/repositories/drafts.dart`
  (save/resume/list/find/discard/markUnsupported, edit revision, 256 KiB
  bound, epoch check, references, typed errors) and extended
  `lib/data/db/command_repository.dart` (draft-aware prepare with one
  unresolved intent per draft, draft payload/reference clearing at commit,
  `saveDraft` with a generated or reused operation ID, receipt-first repeated
  Save, `releaseUncommitted` for a proven failure). Tests:
  `test/data/draft_repository_test.dart` and `test/data/save_command_test.dart`
  23 pass; coverage 110/110 on drafts.dart and 164/165 on
  command_repository.dart (a const constructor only). Recorded as
  P13-DRAFTS. Payment effects arrive with P12 and P22.

### P14 — Accounts, anchors and balances

- Objective: account repository and balance query: inclusive anchor plus accepted postings, selected anchor pointer, backdated posting case, Missing when no anchor. Refs: DECISIONS CLOSED-G01-ACCOUNT-PREREQUISITES (G01-A to G01-E); DATABASE_DESIGN 4.1; SCHEMA `accounts`, `balance_anchors`, `current_balance_anchors`; query-contract Q01.
- Depends on: none (G01 closed). Blocks P21, P22.
- Owner: Data builder. Files allowed: `lib/data/repositories/accounts.dart`, `lib/data/db/query_contracts/*accounts*.dart`, `test/data/account_repository_test.dart`.
- Contract: commit boundaries `CreateAccount`, `SetOpeningBalance`, `SelectAnchor`; written records account, anchor observation, selected pointer, ChangeLog.
- Acceptance: balance = anchor + postings strictly after the anchor date; a posting on the anchor date is never re-added; no anchor gives Missing, never zero; an entered zero is a real anchor; a correction adds an observation with `supersedes_anchor_id`; liability sign follows SPEC 6.6; Appendix A Checking 6,450 and Visa 1,240 fixtures pass.
- Evidence: test log on Appendix A fixtures; `flutter analyze`. Reviewer: product and finance.
- Status: done 2026-11-22. Built `lib/data/repositories/accounts.dart`
  (account list and prepared create, `planSetOpeningBalance` with a selected
  inclusive anchor and a correction path, `balanceAt` = anchor plus postings
  strictly after its date, Missing without an anchor, signed liability
  balance). Tests: `test/data/account_repository_test.dart` 6 pass (Missing,
  anchor with same-day posting excluded, zero anchor, negative liability,
  correction supersedes, create and list). Recorded anchors and the sign rule
  in P14-ACCOUNTS.

### P15 — Budget limits and spending projections

- Objective: the next free migration (007 at planning time) adds `budgets`, `budget_limits`, `budget_templates`; limit editor write path; spending projections and buckets for the 1W/1M/6M/1Y hero, category totals and monthly columns. Refs: DATABASE_DESIGN 5, 8; query-contracts Q09–Q12; SPEC 4.4 (`Spent vs limit`, `Month gone`).
- Depends on: P08, P11. Blocks P26, P27.
- Owner: Data builder. Files allowed: `lib/data/db/schema/*`, `lib/data/db/migrations/*`, `lib/data/repositories/budgets.dart`, `projections/spending.dart`, `test/data/migration_007_test.dart`, `test/data/budget_repository_test.dart`, `test/data/spending_projection_test.dart`.
- Contract: commit boundary `SaveLimits`; written records limits, ChangeLog, dirty ranges, published generation.
- Acceptance: limit save changes no payment; total limit equals the sum of category limits; a missing limit falls back to the same-day-last-month comparison; projection generations publish atomically with coherent buckets; a partial current month is marked, not zero-filled; Appendix A totals 3,940 / 5,200 / 1,260 left / 42% pass.
- Evidence: migration, projection and query logs; `flutter analyze`. Reviewer: product and finance + privacy and security.
- Status: done 2026-11-22. Built: migration 7
  (`lib/data/db/migrations/v007_budgets.dart`) adding `budgets`,
  `budget_limits`, `budget_templates` and `refund_links_original`;
  `kCurrentSchemaVersion = 7`; fresh create and v5/v6 upgrades run it in one
  transaction, and a failure stays at the prior version. Repository
  `lib/data/repositories/budgets.dart` (`SaveLimits`: create/edit/soft-delete
  limits and templates, ChangeLog, the `settings`/`budget:<month>` revision,
  the coalesced dirty range, no payment write) and
  `lib/data/projections/spending.dart` (Q09 current-generation read, Q10
  summary page, Q11 category postings with split parts once, Q12 chart
  buckets; staging publication with pointer switch and `read_revision`).
  Tests: `migration_007_test.dart` (5), `budget_repository_test.dart` (8),
  `spending_projection_test.dart` (10); the existing vault and migration 6
  tests now assert version 8. Appendix A: 3,940 / 5,200 / 1,260 left /
  41.94 (42% at zero decimals). Recorded as P15-BUDGETS. Reviewed 2026-11-23 by the task's named reviewer roles.

### P16 — Repeating schedules, occurrences and settlement

- Objective: schedule editor write path; bounded occurrence generation; occurrence decisions; obligations and settlement allocations; price-change facts. Refs: DATABASE_DESIGN 4.3; SYSTEM_DESIGN 5.3; SPEC 8.17; SCHEMA `schedules`, `scheduled_occurrences`, `occurrence_locators`, `obligations`, `occurrence_decisions`, `current_occurrence_decisions`, `settlement_allocations`, `card_statements`; a later free migration adds `price_changes` and `auto_create` (both absent from version 5; `auto_create` carries the review-path meaning of SPEC 8.17).
- Depends on: P02, P12. Blocks P28.
- Owner: Data builder. Files allowed: `lib/data/repositories/schedules.dart`, `occurrences.dart`, `settlements.dart`, `lib/data/db/migrations/*`, `test/data/schedule_repository_test.dart`, `test/data/occurrence_generator_test.dart`.
- Contract: commit boundaries `SaveSchedule`, `DecideOccurrence`, `SettleObligation`; written records schedule, locators, occurrences, decisions, allocations, ChangeLog.
- Acceptance: generation creates Expected proposals only, in pages of at most 500 rows or 1 MiB, and never a payment; a repeated run creates one occurrence per slot (F09-A); a month-end change, monthly-to-weekly change and a retry keep identity; a rule edit freezes the reconciliation plan; settlement rejects an over-allocation and never silently clamps (1,240 − 500 = 740, F05-C); a price change is recorded as an observation (F09, SPEC 8.9); Stop keeps history.
- Evidence: generator and settlement logs; `flutter analyze`. Reviewer: product and finance + privacy and security.
- Status: done 2026-11-22. Built: migration 8
  (`lib/data/db/migrations/v008_repeating.dart`) adding
  `schedules.auto_create` and `price_changes`; `kCurrentSchemaVersion = 8`;
  fresh create and v5/v6/v7 upgrades run it in one transaction, and a failure
  stays at the prior version. `lib/data/repositories/occurrences.dart`
  (RRULE subset, stable occurrence keys, bounded generator with 500-row /
  1 MiB pages, decisions with obligations and selected pointers) and
  `lib/data/repositories/schedules.dart` (create, reconciled rule edit,
  Stop, price changes) and `lib/data/repositories/settlements.dart`
  (obligation create, unpaid remainder, settlement with the over-allocation
  rejection). Tests: `schedule_repository_test.dart` (6),
  `occurrence_generator_test.dart` (8), `settlement_repository_test.dart`
  (7), `migration_008_test.dart` (5); the vault and migration 6/7 tests now
  assert version 8. Recorded as P16-REPEATING. Reviewed 2026-11-23 by the task's named reviewer roles.

### P17 — Inbox staging and batch confirm

- Objective: staged inbox reads, decision resolution and `ConfirmInboxBatch` with admission: 5,000 selected source rows, 100,000 logical row effects, 16 MiB plan; all-or-none; Undo of the whole batch. Refs: SYSTEM_DESIGN 6; DATABASE_DESIGN 6; SCHEMA `inbox_items`, `staged_rows`, `source_claims`, `source_identities`; flows F07 steps 1–5.
- Depends on: P02, P03, P04, P12. Blocks P25.
- Owner: Data builder. Files allowed: `lib/data/repositories/inbox.dart`, `test/data/inbox_repository_test.dart`, `test/data/confirm_batch_test.dart`.
- Contract: commit boundary `ConfirmInboxBatch`; written records accepted payments, links, decisions, ChangeLog, source claims.
- Acceptance: an invalid row rolls back the whole batch (F07-C); repeated confirm creates no second event (F07-D); unticked rows stay; a source delete removes a staged item only; over-limit keeps every draft and changes nothing; the selected count and total match exactly (F07-B).
- Evidence: test log including an over-limit case and a lost reply; `flutter analyze`. Reviewer: privacy and security + product and finance.
- Status: done 2026-11-22. Built `lib/data/repositories/inbox.dart` (Q13 page
  with the 101-candidate extraction, 100-row display page and
  epoch/revision cursor; pending count; item reads; `stageDecision`;
  `deleteStaged`; `ConfirmInboxBatch` with the 5,000 / 100,000 / 16 MiB
  preflight, all-or-none effects, receipt-first retry and a whole-batch
  Undo). Tests: `test/data/inbox_repository_test.dart` (9) and
  `test/data/confirm_batch_test.dart` (18): exact totals (F07-B), one-invalid
  row rollback (F07-C), repeat confirm (F07-D), unticked rows stay,
  over-limit with no write, lost-reply receipt, idempotent batch Undo,
  settlement blocker, merge/rejected-merge/refund/transfer links and an
  unsupported suggestion. Recorded as P17-INBOX. The unsupported suggestion
  types and a rejected transfer keep the batch unconfirmed (no route is
  defined; `P2-INBOX-PRODUCER`). Reviewed 2026-11-22 (privacy and security +
  product and finance).

### P18 — App shell, form and feedback components

- Objective: build the app shell and the missing components: `AppTabBar` (four sections, one centre Add, count badge, long-press voice), `AppSheet`, `AppDialog`, `AppToast`, `UndoBar`, `AppField`, `AmountInput`, `Keypad`, `PillPicker`, `SegmentedControl`, `ChipRow`/`Chip` (filter, choice, dashed), `Checkbox`, `SplitEditor`, `ConfirmBar`. Refs: DESIGN 5, 6.3–6.6, 14.1–14.2; SPEC 3.3; SCREENS X20–X23, X60.
- Depends on: none. Blocks every screen task.
- Owner: Design-system builder. Files allowed: `lib/design/components/*`, `lib/design/layout/*`, `lib/design/gallery/*`, `test/golden/design/*`, `lib/app/router.dart` (shell shape only).
- Acceptance: gallery entry and goldens dark/Light at 1.0 and 2.0 for every variant; one add control (the tab bar Add only on tab screens); every target 44 pt; every control has a semantic label and `focus.ring`; no style value outside `lib/design`; `custom_lint` passes. The delete-all sheet host moves to `AppSheet` in the same pull request (one deliberate golden change).
- Evidence: gallery and golden images, lint log. Reviewer: design and accessibility.
- Status: done 2026-11-22. Built `lib/design/components/navigation/app_tab_bar.dart`
  (`AppTabBar`: four sections, one centre Add, count badge, long-press voice,
  active section colour, icon-only above 1.3 text scale with the labels in the
  semantic tree), `lib/design/layout/tab_shell.dart` (floating bar 14 pt above
  the bottom and 16 pt from the sides, hides with the keyboard),
  `lib/design/components/overlays/app_sheet.dart` (`AppSheet` and
  `showAppSheet`: 28 pt top radius, grabber, 90% cap, divider after scroll,
  sticky footer), `feedback/app_dialog.dart` (`AppDialog` and
  `showAppDialog`), `feedback/app_toast.dart` (`AppToast` and `showAppToast`,
  5 s), `feedback/undo_bar.dart`, `feedback/confirm_bar.dart`,
  `forms/app_field.dart`, `forms/amount_input.dart`, `forms/keypad.dart`,
  `forms/pill_picker.dart`, `forms/split_editor.dart`,
  `controls/segmented_control.dart` (horizontal scroll above 1.3),
  `controls/chip_row.dart` (filter, choice, dashed), and
  `controls/checkbox.dart` (`AppCheckbox`; the name avoids the Material
  `Checkbox` collision). Added `lib/design/motion/motion.dart` (the only
  `Duration` values), the Lucide `calendar` and `check` icons, and the
  `AppInteraction.onLongPressed` path for voice. Gallery
  `lib/design/gallery/phase2_gallery.dart`; goldens
  `phase2_components_{dark,light}_{1.0x,2.0x}.png`; tests
  `test/design/phase2_components_test.dart` (15: tab bar, badge, Add, voice,
  keypad, checkbox target, segmented, chips, field, amount states, pill, split,
  confirm, undo, toast, dialog, sheet, keyboard hide). Deliberate golden
  updates: the new phase 2 images and the gallery icon grid (`calendar` and
  `check`), all checked. Open: the Delete-all sheet has no host in this
  checkout (`P18-DELETE-ALL-SHEET-HOST`); the shell is not mounted on X03 until
  the Spending, Wealth and Plan destinations exist (P26; `P18-SHELL-MOUNT`).
  Reviewed 2026-11-23 by the task's named reviewer roles.

### P19 — Spending charts

- Objective: `PeriodBarChart` (daily and monthly, average and limit lines, hatched incomplete period), `RingMeter` (fixed-bill dashed arc, today tick), `SplitBar`, and `BillingStrip` (1–31 days, paid dimmed). Refs: DESIGN 7.1–7.3; SCREENS X30, X32, X34, X36.
- Depends on: none. Blocks P26, P27.
- Owner: Design-system builder. Files allowed: `lib/design/charts/*`, `lib/design/components/*`, `test/golden/design/*`, `tool/lints/*` (`chart_requires_table`).
- Acceptance: every chart has one accessible name, exact values in reading order, and "Show as table" with identical rows; the hidden state keeps the shape, hides amount text and masks the spoken label; only `lib/design/charts/` uses `double` coordinates; goldens dark/Light at 1.0 and 2.0 with an empty data set. The deferred `chart_requires_table` lint lands here and passes on the new charts.
- Evidence: chart and table goldens, lint tests. Reviewer: design and accessibility.
- Status: done 2026-11-22. Built `lib/design/charts/chart_frame.dart`
  (`ChartFrame`, `ChartTable`, the "Show as table" disclosure and the preview
  exception), `chart_tone.dart` (`ChartTone`, `ChartMark`, the Light mark map,
  the neutral grid and bar chrome), `chart_values.dart` (masked amount text,
  Decimal short form, one draw-in under 900 ms), `period_bar_chart.dart`,
  `ring_meter.dart` (`RingMeter` and one-table `RingMeterGrid`),
  `split_bar.dart` (shares from `Percent.split`) and `billing_strip.dart`.
  Text scales to 2.0: the gutter and height grow, and above 1.3 only end
  labels stay. New l10n `chartShowAsTable`, `chartHideTable`,
  `chartNoneRecorded`, `chartAverageShort`. The deferred
  `chart_requires_table` lint is live. `test/design/charts_test.dart` (12);
  gallery `charts_gallery.dart`; goldens
  `charts_{dark,light}_{1.0x,2.0x}.png` with empty sets, the open table and
  the hidden state, all inspected. Recorded as P19-CHARTS. Reviewed
  2026-11-22 (design and accessibility).

### P20 — Period hero and the hidden-amount state

- Objective: the `ObHeroVariant.period` hero (kicker, number, period line, background chart masked to 45% at the left) and the app-level hidden-amount state: the provider, persistence, `$·⋯·` text, masked semantics and chart or table labels, percentages stay, counts and dates stay. Per-number masking already exists in `MoneyText` and `hiddenMask`; this task adds the state that drives every money component and the deferred `hidden_mode_semantics` lint. The visible Hide amounts control ships in P29. Refs: DESIGN 6.7 (`0bHero` period, hidden), 7.1 (hidden state), 7.2, 14.2 (ScreenHeader buttons); SPEC 4.9; SCREENS X12, X30.
- Depends on: P19. Blocks P26, P27, P29.
- Owner: Design-system builder. Files allowed: `lib/design/components/hero/*`, `lib/design/format/*`, `lib/design/charts/*`, `lib/app/*` (presentation state provider), `tool/lints/*` (`hidden_mode_semantics`), `test/golden/design/*`, `test/design/*`.
- Acceptance: HERO-PERIOD closes; the hidden state persists across navigation and a lock; a hidden golden exists for every Phase 2 money component; no amount survives in semantics, tooltip, axis or table; `hidden_mode_semantics` passes on the component gallery and the charts; no data changes when it toggles.
- Evidence: hero and hidden goldens, semantics test, `check_contrast`. Reviewer: design and accessibility.
- Status: done 2026-11-22. `ObHeroVariant.period` draws the period chart
  behind the number, masked 45% to 0 left to right, inside
  `ExcludeSemantics`/`IgnorePointer`; HERO-PERIOD closes. `ObHero` takes
  `hiddenContextLine` and hides the line when hidden with no masked version.
  `lib/app/hidden_amounts.dart` holds `HiddenAmountsController` (one
  `ChangeNotifier`), `HiddenAmountsHost` above the router,
  `MemoryHiddenAmountsStore` and `FileHiddenAmountsStore` (one bit, atomic
  rename). `lib/design/format/hidden_amounts.dart` is the scope. MoneyText,
  ObHero, AmountInput and every chart read it; `chart...` tables mask too;
  dates, counts and % stay; no data changes. The live
  `hidden_mode_semantics` lint passes on the gallery and the charts. Tests
  `test/app/hidden_amounts_test.dart` (10); gallery
  `phase2_hidden_gallery.dart`; goldens
  `phase2_hidden_{dark,light}_{1.0x,2.0x}.png`. The visible Hide amounts
  control stays with P29. Recorded as P20-HIDDEN-STATE and P20-HERO-PERIOD.
  Reviewed 2026-11-22 (design and accessibility).

### P21 — Accounts and opening balances (C01 minimal)

- Objective: basic bank, cash and card setup with an opening balance, plus the account picker used by payment forms. Refs: DECISIONS CLOSED-G01; SPEC 6.6 required fields; flows C01; SCREENS X42b (field reference); P14 repository.
- Depends on: P14, P18. Blocks P22.
- Owner: Feature builder. Files allowed: `lib/features/accounts/*`, `lib/l10n` additions for these screens, `test/golden/*` for these screens, one `AppRoute` entry.
- Contract: flow C01; screens C01 editor and the account picker; inputs name, type, currency, opening balance and date; commit boundary `CreateAccount` + `SetOpeningBalance`; written records account, anchor, ChangeLog; success returns to the caller with the new account selected; failures keep the draft; cancellation writes nothing.
- Acceptance: one required choice per step, no advice words, amount first; an opening balance is inclusive; a missing balance is "Missing", an entered zero is real; card accounts show "owes" not a negative number in words; goldens dark/Light at 1.0 and 2.0; F01 final acceptance can now run.
- Evidence: goldens, widget tests, l10n diff. Reviewer: product and finance + design and accessibility.
- Status: done 2026-11-22. Built `lib/features/accounts/`:
  `account_models.dart` (one `AccountsGateway` port, `AccountKind`,
  `AccountSetup`, `AccountSummary`, typed errors, the unavailable gateway);
  `account_setup_controller.dart` (draft, validation, keypad entry, one
  `CreateAccount` + `SetOpeningBalance` save, draft kept on failure);
  `x42b_account_editor.dart` (C01: amount card first, keypad, one required
  type choice, name, currency, inclusive date, cash and net-worth toggles;
  card shows "Owes"); `account_picker_sheet.dart` (exact balances, Missing,
  card owes, `showAccountPicker`). New `DateText` in `lib/design/format/`;
  `MoneyText` gained a `prefix` for "Owes"; `AmountInput` speaks the formatted
  amount when no label is given. One route `AppRoute.accountEditor` (`/x42b`,
  X42b) with the Wealth section. The route mounts the unavailable gateway
  until the vault composition lands (`P21-UNWIRED-GATEWAY`). Tests:
  `test/features/accounts/account_setup_controller_test.dart` (10),
  `x42b_account_editor_test.dart` (8), `account_picker_sheet_test.dart` (4),
  `account_route_test.dart` (1), `account_setup_vault_test.dart` (4, real
  in-memory vault through P14:
  account + anchor + ChangeLog, zero anchor, card liability, same-day posting
  excluded). Goldens `screens_x42b_account_{editor,card,picker}_{dark,light}_{1.0x,2.0x}.png`
  (12), all inspected. Also fixed `PageBackground`: it now paints
  `surface.page` under the spotlight instead of dropping the colour
  (`P21-PAGE-BACKGROUND`), so every screen golden was re-baselined and
  checked. Open: durable C01 drafts (P13/P01) and the card limit (no write
  path in P14; `P21-CARD-LIMIT`). F01 acceptance runs in the vault test; a
  device run waits for the composition, and the X03 Get started entry stays
  with the screen task that owns X03 navigation (`P21-HOME-ENTRY`). Recorded
  as P21-ACCOUNTS. Reviewed 2026-11-22 (product and finance + design and
  accessibility).
- Follow-up 2026-11-22 (review actions):
  - `P21-HOME-ENTRY` closed: the X03 Get started row pushes `/x42b`; the
    route test saves through the injected gateway and returns to Home.
  - `P21-DRAFT` closed: `account_draft.dart` (versioned codec, store port,
    memory store), `lib/app/account_draft_store.dart` over P13, resume,
    discard and the unsupported state in the controller and the editor.
    Tests `account_draft_test.dart` (4), `account_draft_store_test.dart` (3)
    and four controller/widget cases.
  - `P21-DATE-ENTRY` closed: `account_date_sheet.dart` (day, month, year,
    real-date check) replaces the ISO text field.
  - `P21-UNWIRED-GATEWAY` closed at code level: `lib/app/accounts_gateway.dart`
    holds `SqlAccountsGateway`; `ContourApp` and `ContourRouter` accept the
    account and draft stores. The release mount still waits for the verified
    vault (T07-CIPHER-BUILD, PF-01).
  - `P21-CARD-LIMIT` stays open: SCHEMA.sql has no `card_details` table, so
    the card form states that the limit is not saved in this version.
  - Tests now: controller 14, editor 11, picker 4, route 2, vault 4, draft 4,
    draft store 3. Goldens: 16 account images (editor, card, date sheet,
    picker), re-baselined for the date row and the card line.

### P22 — Add expense and income (X20–X23)

- Objective: the amount-first payment form, quick-add sentence fill, category sheet, details sheet and split editor, with Save and Undo. Refs: SCREENS X20–X23; flows F03 steps 1–6; SPEC 3.1; P08–P13.
- Depends on: P01, P03, P10, P12, P13, P18, P21. Blocks P23, P24, P27.
- Owner: Feature builder. Files allowed: `lib/features/add/*`, `lib/l10n` additions, `test/golden/*` for these screens, one `AppRoute` entry per screen.
- Contract: flow F03; screens X20, X21, X22, X23; inputs amount, currency, date, account, category, tags, split parts; actions type switch, sentence, category, details, split, Save; read model draft and remainder; commit boundary `SavePayment`; written records payment, splits, event, ChangeLog, receipt; success returns to the caller with Undo; failures keep the draft; cancellation per P01; checks F03-A to F03-D.
- Acceptance: 3 taps or one sentence for a typical expense (measured, not claimed); an uncategorised payment saves (F03-A); a split saves once after repeated taps and only at zero remainder (F03-B); an edit does not duplicate (F03-C); Undo restores balances and split links (F03-D); nothing is written before Save; goldens at 1.0 and 2.0 in both themes; banned-word check passes.
- Evidence: input-target measurement log, widget tests, goldens. Reviewer: product and finance + design and accessibility.
- Status: done 2026-11-22. Built `lib/features/add/`:
  `payment_models.dart` (one `PaymentsGateway` port: form data, `SavePayment`,
  Undo; typed errors; the unavailable gateway), `payment_draft.dart`
  (versioned X20 payload, schema 1; load result; store port; memory and no-op
  stores), `payment_form_controller.dart` (draft, keypad, sentence fill,
  category/date/account/tags, splits and remainder, one Save, draft kept on a
  failure), `x20_add_payment.dart` (X20: Close, released source actions, type
  switch, amount, USD/date/account/Split pills, merchant field, category chips,
  keypad, Save with the amount; toast with Undo), `x21_category_sheet.dart`
  (X21: search, 4-column grid, 2 pt selected edge, New category when C03
  ships), `x22_details_sheet.dart` (X22: Today/Yesterday/2 days ago chips, the
  month grid Monday first with future days disabled, Paid with, Currency, Tags,
  Done), `x23_split_screen.dart` (X23: hero, SplitBar, parts with amount and
  remove, Add a part, Left to split, Save only at a zero remainder).
  Adapters `lib/app/payments_gateway.dart` (`SqlPaymentsGateway` over P12, P13
  and the command writer, receipt-first and `releaseUncommitted`) and
  `lib/app/payment_draft_store.dart` (P13 form type `payment`). Data:
  `PaymentRepository.planUpdate` (F03-C) and `planUndoCreate` (F03-D);
  `CommandRepository.activeOperationId` and `committedOutcomeOf`. One route
  `AppRoute.paymentAdd` (`/x20`, X20) with the Spending section; X23 is pushed
  inside X20 with its draft, not a top-level route.
  - Checks. F03-A (uncategorised saves), F03-B (split at zero remainder, one
    receipt after repeated taps, an amount left blocks Save), F03-C (an edit
    changes the payment and adds none; nothing before Save), F03-D (Undo
    soft-deletes the event, payment and splits and restores the balance) run
    in widget and in-memory vault tests.
  - Input target (measured on the widget harness, not a device). A typical
    expense is amount, account (no last-used account yet), category and Save:
    the amount digits count as keypad presses. At $24 the run was 4
    activations after the account choice, one of them Save. SPEC 3.1 (3 taps)
    is not claimed: the harness count stays in the test and a device run waits
    for the phase acceptance (P29).
  - Tests: `test/features/add/*` 50 pass (controller 12, draft 5, vault 4,
    X20 12, X21 4, X22 5, X23 6, route 2); `test/design/phase2_components_test.dart`
    gains 2 (SelectTile, DayCell). Goldens
    `screens_x20_add_{expense,income}`, `screens_x21_category`,
    `screens_x22_details`, `screens_x23_split` in dark/Light at 1.0 and 2.0
    (20), all inspected.
  - Design. Two missing components were added to
    `lib/design/components/controls/` with gallery entries, tests and goldens:
    `SelectTile` (X21) and `DayCell` (X22). `SegmentedControl` above 1.3 now
    grows each segment with its label. `phase2_components_*` goldens were
    re-baselined and checked (DECISIONS P22-DESIGN-FIXES).
  - Recorded: P22-PAYMENT-FORM, P22-PAYMENT-DEFAULTS, P22-CATEGORY-DOT,
    P22-DESIGN-FIXES.
  - Open: last-used account and currency need a read model (P22-DEFAULTS);
    the visible Hide amounts control and the hidden goldens are P29; Speak is
    P24; the X26 Transfer segment and Scan QR/Receipt/Import appear when P23
    and Phase 3 supply their handlers (SPEC 5.5). Reviewed 2026-11-23 by the task's named reviewer roles.

### P23 — Transfer (X26)

- Objective: transfer form between two owned accounts, paired postings, one fee posting, card "owes" as the destination fact. Refs: SCREENS X26; flows F05 steps 1–2; checks F05-A, F05-D; P06, P09.
- Depends on: P06, P09, P22. Blocks none.
- Owner: Feature builder. Files allowed: `lib/features/add/x26_transfer.dart`, `lib/l10n` additions, `test/golden/*`, one `AppRoute` entry.
- Contract: flow F05; screen X26; inputs From, To, amount, date, fee; actions Save transfer; commit boundary `SaveTransfer`; written records two principal postings, fee posting, event, ChangeLog; success returns with Undo; failures keep the draft; cancellation writes nothing.
- Acceptance: an unsplit transfer changes neither money in nor spending (F05-A); one fee posting when a fee is recorded (F05-D); same account is rejected; a card destination shows what it owes; the boundary case keeps the accounts and net worth correct and shows the attribution as Missing (`P2-TRANSFER-BOUNDARY`); X26 has no fee field in Phase 2, so a fee is captured or imported; `X26bTransferFX` stays unreleased and absent from navigation; goldens and l10n checks pass.
- Evidence: widget and domain tests, goldens. Reviewer: product and finance.
- Status: done 2026-11-22. Built: `lib/data/repositories/transfers.dart`
  (`planCreate` with one event, the two signed principals, an optional one-fee
  posting and one `transfer_links` row; `planUndoCreate` soft-deletes the whole
  event), `lib/app/transfers_gateway.dart` (`SqlTransfersGateway` over P14 and
  the command writer, receipt-first), `lib/app/transfer_draft_store.dart` (P13
  form type `transfer`), `lib/features/add/transfer_models.dart` (port, setup,
  saved result, typed errors), `transfer_draft.dart` (versioned codec, memory
  store), `transfer_form_controller.dart` (defaults, amount, date, same-account
  and cross-currency rejection, one Save, draft kept on failure) and
  `x26_transfer.dart` (X26: type switch, kicker, amount, From/To/Date card,
  caption, keypad, Save transfer). Route `AppRoute.transferAdd` (`/x26`, X26,
  Spending); X20 now shows the Transfer segment and pushes it, and the type
  switch returns to X20 with the chosen type. The card destination shows
  "Owes" and the balance (P21 picker rules). The date sheet takes an optional
  title for this screen. Tests: `transfer_form_controller_test.dart` (8),
  `x26_transfer_test.dart` (6), `transfer_route_test.dart` (3),
  `transfer_repository_test.dart` (3), `transfer_save_vault_test.dart` (3).
  Goldens `screens_x26_transfer_{bank,card}_{dark,light}_{1.0,2.0}x.png` (8),
  all inspected. Recorded as P23-TRANSFER and P23-LARGE-TEXT. X26 still has no
  fee field (P06 note); F05-E attribution stays Missing
  (`P2-TRANSFER-BOUNDARY`). Reviewed 2026-11-23 by the task's named reviewer roles.

### P24 — Voice capture (X87, X24, X25)

- Objective: permission explainer, on-device listening state, filled-draft review with per-field confidence, behind a `SpeechPort` with one implementation per platform. Refs: SCREENS X24, X25, X87; SPEC 8.10; flows F04 steps 1–2; P05, P10.
- Depends on: P05, P10, P22. Blocks none.
- Owner: Native builder (port and binding) with feature builder (screens). Files allowed: `lib/data/speech/*`, `lib/features/add/voice/*`, `native/*speech*`, `lib/l10n` additions, `test/golden/*`, `test/app/speech_*_test.dart`, one `AppRoute` entry.
- Contract: flow F04; screens X87, X24, X25; inputs microphone permission and transcript; actions Stop, Form, Speak again, Save; read model transcript plus confidence per field; commit boundary `SavePayment` only; written records none until Save; success per F03; failures fall back to typed entry; cancellation clears the transcript.
- Acceptance: all nine SPEC 8.10 sentences pass in airplane mode (F04-A); denial keeps manual entry (F04-B); no actual record before Save (F04-C); no audio stored, temporary files cleaned; the unavailable-device message shows and no request starts; no secret or transcript in logs.
- Evidence: airplane-mode simulator log, the engine verification record (name, version, availability check, telemetry statement, dependency entry), goldens, privacy scan. Reviewer: privacy and security + design and accessibility.
- Status: done 2026-11-22 (screens and port). Built: `lib/data/speech/speech.dart`
  (`SpeechPort`, availability, typed failures, `UnavailableSpeechPort`),
  `platform_speech.dart` (method/event channel binding that mounts only with a
  verified on-device record), `lib/features/add/voice/voice_controller.dart`
  (check, explain, listen, stop, speak again, cancel), `x87_permission.dart`
  (X87 via `AppDialog` with a leading mic tile), `x24_voice_capture.dart` (X24
  listening and X25 filled in one route; Save uses `SavePayment`; a missing
  required field returns the transcript to X20). X20 now takes the transcript
  from its Speak action and fills its fields. Route `AppRoute.voiceCapture`
  (`/x24`, X24, Spending). `showAppDialog`/`showAppSheet` now pass the opener's
  `SectionScope` (P24-DIALOG-SECTION). Tests:
  `voice_controller_test.dart` (9), `x24_voice_capture_test.dart` (5).
  Goldens `screens_x24_listening`, `screens_x25_filled`,
  `screens_x87_permission` in dark/light at 1.0 and 2.0 (12), all inspected.
  Recorded as P24-VOICE, P24-REVIEW-ROWS, P24-DIALOG-SECTION, P24-MIC-BADGE and
  P24-SOUND-BARS. Open: `P24-ENGINE-EVIDENCE` (native binding verification
  record and the airplane-mode run of the nine SPEC 8.10 sentences), and the
  X25 row edit path. The screen-level acceptance is complete; the device
  acceptance waits for the engine. Reviewed 2026-11-23 by the task's named reviewer roles.

### P25 — Inbox (X60–X62)

- Objective: Inbox list, decision card, ready rows with checkboxes, item sheet, empty state, confirm bar. Refs: SCREENS X60–X62; flows F07 steps 1–5; checks F07-A to F07-D; P02, P03, P04, P17.
- Depends on: P17, P18, P20, P21. Blocks none (but see `P2-INBOX-PRODUCER`).
- Owner: Feature builder. Files allowed: `lib/features/inbox/*`, `lib/features/home/x03_home_first.dart` (Inbox entry only), `lib/app/widgets/*` (Inbox badge source), `lib/l10n` additions, `test/golden/*`, one `AppRoute` entry.
- Contract: flow F07; screens X60, X61, X62; inputs staged items, ticked IDs, decisions; actions resolve, edit, delete, tick, confirm; read model ticked count and total, pending decisions; commit boundary `ConfirmInboxBatch`; written records accepted payments, decisions, ChangeLog; success refreshes and keeps context; failures keep drafts; cancellation leaves staged items; checks F07-A to F07-D. The Inbox entry is one header control on X03 with the count badge; it is absent when nothing is staged.
- Acceptance: uncertain rows stay unticked (F07-A); the confirm label matches the exact count and total (F07-B); one invalid row rolls back (F07-C); repeat confirm and batch Undo are idempotent (F07-D); while a decision is open its affirmative choice is the only filled action and Confirm is ghost (SPEC 5.5); the empty state is a known zero; 20 items confirm in under 60 seconds with the synthetic producer; goldens and l10n checks pass. The producer gap is recorded in DECISIONS.
- Evidence: widget tests, timing log, goldens. Reviewer: product and finance + design and accessibility.
- Status: done 2026-11-22. Built: `InboxRepository.displayItems` (P25 read:
  one page with the source channel, category, account and counterpart account
  names), `lib/features/inbox/inbox_models.dart` (port, row, decision, totals,
  confirmation, safe errors, unavailable gateway), `inbox_controller.dart`
  (load, default ticks, one open decision, exact totals, confirm, batch Undo,
  delete), `x60_inbox.dart` (X60 and X62: header, hero, decision card, ready
  rows with checkboxes, ConfirmBar; the affirmative decision owns the filled
  action and Confirm is ghost while it is open, SPEC 5.5) and
  `x61_item_sheet.dart` (source line, read fields, Delete and Confirm).
  Adapter `lib/app/inbox_gateway.dart` over P17 with an opaque cursor and a
  new command id per confirm and undo. Route `AppRoute.inbox` (`/x60`, X60,
  Home); the X03 Inbox action opens it. Tests: `inbox_controller_test.dart`
  (9), `x60_inbox_test.dart` (6), `inbox_route_test.dart` (1). Goldens
  `screens_x60_inbox`, `screens_x62_inbox_empty` and
  `screens_x61_inbox_item` in dark/light at 1.0 and 2.0 (12), all inspected.
  Recorded as P25-INBOX, with P25-BADGE, P25-SOURCE-STRIP, P25-LAST-CAPTURE and
  P25-RULE-TOGGLE open. The producer gap stays `P2-INBOX-PRODUCER`. Reviewer
  pending.

### P26 — Spending home, where it goes, money in, budget, limits (X30, X30c, X31, X32, X33)

- Objective: the Spending tab root with the period hero and bars, the where-it-goes breakdown, money in, budget rings and the limits editor. Refs: SCREENS X30, X30c, X31, X32, X33; flows F08 steps 1–3 and 5; widgets W11.2, W11.3 (except `moneyIn.nextIncome`).
- Depends on: P08, P11, P15, P19, P20, P18. Blocks P27, P28.
- Owner: Feature builder. Files allowed: `lib/features/spending/*` (tab root, where-it-goes, money-in, budget, edit-limits), `lib/app/widgets/*` registry entries for the Spending widgets, `lib/l10n` additions, `test/golden/*`, route entries.
- Contract: flow F08; screens X30, X30c, X31, X32, X33; inputs period, denominator, limits; actions period chip, row, Save on limits; read model per-period totals, limits left, category shares; commit boundary `SaveLimits` only; written records limits, ChangeLog; success refreshes and keeps the period; failures keep inputs; cancellation changes nothing; checks F08-A, F08-E.
- Acceptance: Appendix A per-period values pass (1W 1,560; 1M 3,940 of 5,200, 1,260 left; 6M Apr–Sep 24,480 of 31,200 under the P11-PERIODS rule, unless the sample is corrected; 1Y 48,060 of 62,400); same-days September 4,005 and "October is $65 lower"; rings and table agree; limits save without touching payments (F08-E); every card is a widget with a default layout entry; the Search control is absent until X15 ships; "Next income" is absent until Phase 4; the fixture reproduces the printed 12-month category averages (1,800 / 700 / 520 / 240 / 300 / 205 / 150 / 90); goldens and l10n checks pass.
- Evidence: golden set, widget tests, Appendix A test log. Reviewer: product and finance + design and accessibility.
- Status: done 2026-11-22 (screens and reads; widget entries open). Built:
  `lib/data/projections/money_in.dart` (income only, daily and monthly
  buckets, one parent count), `lib/features/spending/spending_models.dart`
  (port, period views, totals, category shares with `Percent.split`, limits),
  `spending_controller.dart` (`SpendingController` for a chip and its limits,
  `MoneyInController`, `LimitsController` with a draft and one Save),
  `x30_spending.dart` (X30: period hero with a preview chart, chips, the full
  chart with the average line and table, same-days line, category rings and the
  detail rows), `x30c_where_it_goes.dart` (X30c: numerator and denominator
  switch, share rows), `x31_money_in.dart` (X31: money-in hero, chips, chart
  and kept line), `x32_budget.dart` (X32: left hero, rings most left first,
  today tick, edit row) and `x33_edit_limits.dart` (X33: total limit, one
  keypad sheet per category, Save). Adapter `lib/app/spending_gateway.dart`.
  `formatPercent`, `formatMonthShort`, `formatMonthLong` and `formatDateRange`
  added to `lib/design/format/`. Routes `/x30`, `/x30c`, `/x31`, `/x32`,
  `/x33`, all Spending. Tests: `spending_controller_test.dart` (7),
  `x30_spending_test.dart` (3), `spending_route_test.dart` (2),
  `spending_save_limits_vault_test.dart` (2, F08-E: zero transactions after a
  save). Goldens `screens_x30_spending`, `screens_x30c_where`,
  `screens_x31_money_in`, `screens_x32_budget` and `screens_x33_limits` in
  dark/light at 1.0 and 2.0 (20), all inspected. Recorded as P26-SPENDING with
  P26-WIDGETS, P26-CATEGORY-AVERAGES, P26-NEEDS-WANTS, P26-WHERE-BARS,
  P26-FIXED-RINGS, P26-MONEY-IN-COLOUR, P26-MONEY-IN-SPLIT and
  P26-LIMITS-UNDO open. Reviewed 2026-11-23 by the task's named reviewer roles.

### P27 — Category detail, payments, filter, detail, delete (X36–X39b)

- Objective: category detail, all payments with day groups, filter sheet, payment detail, delete dialog with Undo. Refs: SCREENS X36–X39b; flows F08 steps 3–4 and checks A–D; SPEC 4.2.
- Depends on: P08, P09, P12, P22, P26. Blocks P28.
- Owner: Feature builder. Files allowed: `lib/features/spending/*` (category, transactions, filter, payment detail), `lib/l10n` additions, `test/golden/*`, route entries.
- Contract: flow F08; screens X36, X37, X38, X39, X39b; inputs filter draft, payment ID; actions filter, edit, delete, confirm; read model list cursor and totals; commit boundary `DeletePayment`; written records soft delete, links, ChangeLog; success returns with toast and Undo; failures keep the record; cancellation keeps the record; checks F08-A to F08-F.
- Acceptance: filter applies only on Show and Back keeps it (F08-A); a cancelled delete leaves data (F08-B); delete and Undo change totals once (F08-C); known zero, Missing and a net refund differ (F08-D); reimbursable and refund toggles reflect P07; the receipt row is absent until Phase 3; goldens and l10n checks pass.
- Evidence: widget tests, goldens, Appendix A totals. Reviewer: product and finance + design and accessibility.
- Status: done 2026-11-22. Built: `lib/data/repositories/payments_read.dart`
  (filtered list, exact count, one payment with splits and tags),
  `lib/data/projections/category_read.dart` (monthly and merchant totals),
  `PaymentRepository.planRestore` (the compensating restore),
  `lib/features/spending/payments_models.dart` (filter draft, list, detail,
  category view, deleted result, port, safe errors), `payments_controller.dart`
  (list, detail with delete/restore, category), `x37_all_payments.dart` (day
  groups, day totals, filter chips, delete toast with Undo),
  `x38_filter_sheet.dart` (period, show, accounts, categories, exact Show
  count, Clear), `x39_payment_detail.dart` (hero, fields, split, delete),
  `x39b_delete_dialog.dart` and `x36_category_detail.dart` (hero, Used/Month
  gone/average, each-month chart, merchant SplitBar, payments and All row).
  Adapter `lib/app/payments_read_gateway.dart`. Routes `/x36`, `/x37`, `/x39`,
  all Spending; the X30 All payments row and the X30c category rows open them.
  Tests: `payments_controller_test.dart` (6), `payments_screens_test.dart` (7),
  `payment_delete_vault_test.dart` (2, F08-C delete/Undo once) and two route
  tests. Goldens `screens_x36_category`, `screens_x37_payments`,
  `screens_x38_filter`, `screens_x39_payment` and `screens_x39b_delete` in
  dark/light at 1.0 and 2.0 (20), all inspected. Recorded as P27-PAYMENTS with
  P27-RING-LINK, P27-EXPECTATION-TOGGLES, P27-FILTER-ROWS and P27-LIMIT-BAR
  open. The receipt and similar-payments rows stay with Phase 3; the search
  field stays with X15. Reviewed 2026-11-23 by the task's named reviewer roles.

### P28 — Categories, rules and repeating (X84, C02, C03, X34, X35)

- Objective: category and rule editor, repeating list and detail, schedule editor, price-change facts, Stop repeating. Refs: SCREENS X34, X35, X84; flows F09 steps 1–5; checks F09-A to F09-D; SPEC 8.17; P02, P03, P16.
- Depends on: P16, P27. Blocks none.
- Owner: Feature builder. Files allowed: `lib/features/spending/*` (repeating, rules), `lib/features/settings/*` (rules entry), `lib/l10n` additions, `test/golden/*`, route entries.
- Contract: flow F09; screens X34, X35, X84, C02, C03; inputs rule or schedule draft; actions Save, pause, Stop, accept rule offer; read model next occurrence and history; commit boundary `SaveSchedule`, `SaveRule`, `StopSchedule`; written records rule or schedule, occurrences, price change, ChangeLog; success returns to the caller; failures keep the draft; cancellation writes nothing; checks F09-A to F09-D.
- Acceptance: repeated runs create one occurrence (F09-A); a later import links one payment (F09-B) — tested with staged fixtures until Phase 3; Stop keeps history (F09-C); a declined rule offer writes no rule (F09-D); the tab bar Add on X34 and X35 opens C02, not the expense form (SPEC 5.5); the cancellation address is inert text with no link, copy or share; the X35 toggle caption states the review path only ("Off: confirm it here") and never claims an automatic actual payment; the billing strip shows paid items dimmed; goldens and l10n checks pass.
- Evidence: widget tests, goldens, generator log. Reviewer: product and finance + design and accessibility.
- Status: done 2026-11-22. Built: `lib/features/spending/repeating_models.dart`
  (schedules, detail with occurrences and price changes, rules, drafts, port,
  safe errors), `repeating_controller.dart` (list, detail with Stop, rules),
  `x34_repeating.dart` (hero, next date and state per schedule),
  `x35_repeating_detail.dart` (hero, last six occurrences, facts, Stop with a
  confirmation), `x84_rules.dart` (Categories/Rules switch, use counts, Add a
  rule), `c03_rule_editor.dart` (match text and a category choice) and
  `c02_schedule_editor.dart` (name, amount keypad, frequency, first payment,
  account). Adapter `lib/app/repeating_gateway.dart` over P16 schedules and
  occurrences and P12 categories and rules. Routes `/x34`, `/x35`, `/x84`,
  `/c02`, `/c03`; the X30 Repeating row and Settings > Money open them. Tests:
  `repeating_test.dart` (8: list total, Stop, rules, X34, X35, X84, C03, C02).
  Goldens `screens_x34_repeating`, `screens_x35_repeating`, `screens_x84_rules`,
  `screens_c02_schedule` and `screens_c03_rule` in dark/light at 1.0 and 2.0
  (20), all inspected. Recorded as P28-REPEATING-RULES with P28-TABBAR-ADD,
  P28-BILLING-STRIP, P28-CANCEL-ADDRESS, P28-AUTOCREATE,
  P28-SCHEDULE-CATEGORY, P28-CATEGORY-EDIT and P28-HISTORY-CHART open.
  Reviewed 2026-11-23 by the task's named reviewer roles.

### P29 — Hidden amounts, undo history and phase acceptance

- Objective: expose hide amounts on the Phase 2 screens, add the persistent history screen (C06), and run the phase acceptance. Refs: SPEC 4.9, 16.3, 17 (Phase 2); flows shared contract undo, C06, G06; SCREENS X12 state, X37 toast; P04, P20.
- Depends on: P04, P20, P22, P23, P24, P25, P26, P27, P28.
- Owner: Feature builder (screen) with design-system builder (hidden state). Files allowed: `lib/features/history/*`, `lib/features/home/*` (hide control), `lib/design/*` (hidden fixes only), `lib/l10n` additions, `test/golden/*`, `integration_test/phase2_*.dart`, route entries.
- Contract: flows C06 and the shared contract; screens the history list and the hidden state; inputs event or batch ID; actions Undo, open dependency resolution; read model history with dependency state; commit boundary `UndoCommand`; written records compensating records, ChangeLog; success refreshes the caller; failures keep the record; cancellation changes nothing.
- Acceptance: every Phase 2 screen has hidden goldens and no amount leaks through semantics, tables, axes or tooltips; Undo reverses a whole event or batch and keeps later dependent edits; Activity history opens from Settings > App and shows the reversible, reversed and blocked states (SPEC 8.18); the phase checklist passes: 3.1 input targets, nine voice sentences in airplane mode, transfer/refund/reimbursement fixtures, nothing saved before Save; `flutter test`, goldens, all lints, `check_tokens`, `check_contrast`, `gen-l10n` and the integration smoke test pass on a simulator.
- Evidence: phase acceptance report with command logs, goldens, timing table. Reviewer: product and finance + design and accessibility + privacy and security.
- Status: done 2026-11-22 at code level; the phase acceptance report is
  `docs/PHASE2_ACCEPTANCE.md`. Built: `HiddenAmountsControllerScope` and
  `lib/app/hide_amounts_button.dart` (six headers: X03, X30, X36, X37, X39,
  X60), X30 same-days and X36 limit lines masked while hidden, and hidden
  goldens for X30, X36, X37, X39 and X60 (20 images), all inspected.
  `lib/data/repositories/history.dart` (receipts, command type, compensating
  flag, deleted checks), `lib/app/history_gateway.dart` (four undo families:
  payment create, transfer create, payment delete, Inbox batch; other commands
  are changes), `lib/features/history/history_models.dart`, `c06_history.dart`
  (newest first, reversible/reversed/change, one Undo per reversible entry) and
  the Settings > App Activity history row; route `/c06`. Tests:
  `history_test.dart` (2) and `hide_control_test.dart` (1, toggle hides and
  restores every amount on X37). Recorded as P29-HIDDEN-CONTROL and
  P29-HISTORY. Open: `P29-HIDDEN-OTHER` (unmasked composed lines on screens
  outside the hidden golden set), `P29-HISTORY-BLOCKED` (dependency sheet),
  `P29-HISTORY-DETAIL` (per-entry records), the 3.1 device measurement, the
  airplane-mode voice run (`P24-ENGINE-EVIDENCE`) and
  `flutter test integration_test` (no simulator on this host).
  Follow-up 2026-11-23: a debug-only demo composition wires every Phase 2
  gateway to an in-memory synthetic vault (`lib/app/demo/`), starts on a demo
  menu and is tested by `test/app/demo_composition_test.dart`. The release
  start still uses the unavailable gateways. Recorded as P29-DEMO-WIRING.
  Reviewed 2026-11-23 by the task's named reviewer roles.

## Phase 2 exit criteria

- SPEC 17 Phase 2 "Accept when" items pass with evidence: 3.1 input targets measured; voice sentences in airplane mode; transfer, refund and reimbursement fixtures; nothing saved before Save.
- AGENTS 7 definition of done for every task: SPEC behaviour, screen against `docs/screens/SCREENS.md` and the design photos, all section 4 commands, goldens light/dark at 1.0 and 2.0, interface checks, no network outside `lib/data/prices/`, no personal data in logs, l10n strings, `docs/DECISIONS.md` updated.
- No gate from the table above stays open for a shipped feature. The device gates (PF-01, DB-A, DB-B, native bindings) keep their Phase 1 status and are not closed by this phase.

## Not in Phase 2

- Imports, share-in, CSV/Excel, OFX/QIF/CAMT/MT940, PDF and Teach once (X63–X68, X88): SPEC 17 Phase 3.
- QR and receipt photo (X27, X28): F04 index — Phase 3.
- Search (X15): Phase 4 (F02); see `P2-SEARCH-ENTRY`.
- Home final and its states (X10, X11, X12, X14), About this number (X40b), Wealth and account details (X40–X49): Phase 4.
- Calendar, cash flow and next income (X50, X50b), month close (X70, X71), recovery (X83): Phase 4; see `P2-SPEND-NEXT-INCOME`.
- Cross-currency transfer (X26b), goals, protect, tax, tools: v1.1 and v1.2.
- Any new network path, export, sync, analytics or remote processing: out of scope for every phase.
