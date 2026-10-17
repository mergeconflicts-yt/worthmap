# Feature implementation contracts

Version 1.0 · 16 October 2026 · ARCH-FINAL-001.

This is the implementation map for the final architecture baseline. SPEC and its full references own product meaning. Usage flows own the journey and correction gates. System design, Database design, Execution safety and Widget framework own the technical contracts. This map does not close an undefined financial rule or claim that a feature is implemented.

## 1 Rules shared by every feature

- **One source:** an accepted fact has one authoritative record. Typed links connect the effects of an event. No second cash, debt, investment or goal ledger is allowed. A goal allocation does not add an asset.
- **One result:** every repeated number uses the same canonical key, dependency set, exact calculation and shared read revision. A widget, hero, chart label and table cannot calculate their own version. Different periods, currencies or methodologies use different explicit keys.
- **Atomic writes:** an authored command validates expected revisions and commits its effects, history, dependency changes, receipt and required small shared values together. No partial event, linked document selection or admitted batch. Unknown outcomes resolve the original operation. A failed derived read cannot repeat a financial write.
- **No invented values:** Missing, Expected, Estimated, Updating and unavailable states remain explicit. Zero requires evidence. Future income, vests and schedules cannot enter actual balances. A partial known subtotal must retain its coverage state and date.
- **Bounded work:** paged reads, stable cursors, cooperative worker scheduling, limits on native work, bounded decoded files, finite forecast windows and cache budgets apply to every row below. Large history never authorizes a full synchronous UI calculation or unbounded writer transaction.
- **Retention:** keep accepted structured facts, original exact input precision, identity/provenance, corrections, method versions and input pins needed for reproducible history. Raw import sources are temporary unless the person explicitly retains a supported attachment. Drafts do not expire silently. Disposable results have quotas; authoritative history does not have an automatic purge.
- **Access:** route, release, feature, platform, lock and permission checks apply to all entry paths. Off-screen modules release work. Native OS widgets and shortcuts only open generic routes behind unlock; they receive no financial snapshot.

## 2 Complete journey map

Table names below are current reference tables where present. The next section distinguishes families that still need typed migrations. Each feature task must include its F-number, SPEC rule, current gates, source tables, canonical keys, command, dependency closure, bounded queries and acceptance cases. A new feature cannot hide its permanent data in a generic JSON record.

| FLOW | AUTHORITATIVE INPUT AND SHARED RESULT | SAVE AND INVALIDATION BOUNDARY | FAILURE, RETENTION AND REQUIREMENTS |
|---|---|---|---|
| F01 | Local settings/person/account prerequisites; encrypted lifecycle control; shared Home snapshot | Account/opening-observation command; lock policy transition; Phase 1 widget host | AuthPort attempt/epoch checks, device credential, key failure; G01; PF-01; S01/S06/S07 |
| F02 | metric_values, current projections, pinned exact series; Home/About/Search/hide state | Read-only navigation; display preferences use their own command, no financial invalidation | Same number/revision across places, in semantics/tooltips; local search; screen-driven recalculation; G05 |
| F03 | transactions, transaction_splits, financial event and account/category identities | One Save/edit/soft-delete with expected revisions; exact split invariant; cash, spending, budget, forecast and net-worth scopes | Back retains encrypted draft; concurrent edit, repeated taps; G01 / G06 / G12 |
| F04 | Transient audio/QR/image input → structured draft → F03 records | Explicit form Save only; no capture callback posts money | On-device engine admission; leave/lock/background; denied permission; QR/file limits; G07 / G12 |
| F05 | transfer_links, transfer_fx, transactions, obligations and settlement allocations | Both principals and actual fee once in one event; source/destination balances and forecast invalidate together | Local FX evidence; match/retry; expense or duplicate card debt; currency settlement tests; G01 |
| F06 | Immutable parse configuration/source identity; staged_rows, claims and batch | Private preview → explicit Send marker/count → F07 financial Confirm | No formulas/macros/network reference; locale, broken/password-protected; cancellation/resume; source-needed; G07 |
| F07 | Published inbox_items and source claims; shared eligible count | Freeze review selection; all selected financial effects plus claims/count/receipt; withdrawal differs from financial Undo | Revision-bound keyset cursor; all routes, ≤5,000 selected rows; limits; duplicate/late command tests; G06 |
| F08 | Canonical payments/splits/refund links, budgets and tags | Edit/refund/reimbursement/classification command; dirty affected period/category/budget scopes | Refund counted once, split totals; state preserved, unknown budget; period fixtures; G14 |
| F09 | Categories, typed rule/template data, schedules, stable occurrences/locators and decisions | User decisions are authored; automatic Expected generation is operational; reconciliation is one command | Bounded non-backtracking rules, identity; skip/partial settlement, no posting; G02 / G05 |
| F10 | accounts, balance anchors, manual/public quotes, local FX and typed valuation metadata | New account/value observation selects evidence; refresh of public data is separate; invalidate value/debt/net-worth keys | No fabricated opening trade; manual/interest/contribution/weight; account methods need exact fixtures; G01 / G03 / G14 |
| F11 | Holdings/events/lots/quote and FX evidence; position/allocation/return projections | A read creates no authored value; method/benchmark/target changes are authored configuration | CAGR/XIRR/TWR and gains use SPEC; insufficient history/ambiguous origin; interpolation as price evidence |
| F12 | position_observations, investment events, lots and ordering evidence | X45 Apply is direct structured review; observation is not trade history; ledger edits invalidate future lot/return ranges | Cross-route dedupe, no invented cancellation and corrections; uncovered coverage remains explicit; G03 |
| F13 | Typed grants, vest schedules and vest events linked to holdings/cash/tax effects | Expected schedule separate from confirmed vest; matched posting reused in one linked event | No double salary/vesting/cash effect and withholding fixtures, revised dependencies; G02 / G03 |
| F14 | Schedules, occurrence decisions, obligations, statements and actual settlement links | Finite Expected generation; explicit accept/edit/match/skip command; forecast scopes dirty from earliest affected date | One unpaid remainder, no duplicate occurrence across edits, local data; missing account balances stay Missing |
| F15 | Typed goals/account allocations; shared account values and calculator inputs | One allocation transaction validates active percentage closure; goal changes do not move cash | Exact remainder/rounding, shared; missing values, deleted targets; G09 / G12 |
| F16 | Typed payslip/policy/claim/person/emergency data; authenticated attachments; linked cash/events | X69 selected areas or X69b Save policy confirms directly; source claim and all chosen links commit together | Private parsing; no forced Inbox; reused only through match; attachments leave no dangling accepted records; G12 |
| F17 | Typed tax dates/limits/contributions and calculator presets; versioned pure results | Saving a preset records inputs only; explicit record/goal/debt command creates a real effect | No result auto-posts money; country/year/method/currency; formula/rounding/solver fixtures for calculator; G09 / G14 |
| F18 | month_closes, immutable numbered close_revisions and typed evidence bridges | Save and finish only; private complete preparation then one bounded authored command; snapshot is a separate job | No partial close or evidence truncation; preserved after backdated edits; reply/snapshot failure; EXECUTION; G10 |
| F19 | Typed settings/source policy, provider state, feature gates; three layout tables | Source changes revoke capability; networking is explicit opt-in; layout Done is one preference transaction | Disable/re-enable ABA races; no network request; layout aliases; previews use resident results only |
| F20 | Encrypted local snapshot, manifest, file/key leases and generation pointer | Verify staged generation → explicit confirmation → quiesce and atomic activation; fresh epoch | No merge/export; old pending commands; reviewable inputs, not automatic; off; lock policy cannot roll back |
| F21 | Lifecycle/deletion journal, key/file inventory, privacy settings | Revoke admission/epochs → drain real writer leases → remove data/keys → clear control last | Restart resumes deleting; late native files; key loss is not consent; no clipboard, OS search index or OS; S06/PF-01 |

## 3 Physical model coverage

**Reference** means that the listed mechanism exists in SCHEMA.sql, not that production code exists. **Extend** requires an explicit typed Drift table/migration/query fixture before the corresponding feature can ship. The reference DDL has 89 ordinary tables and one FTS virtual table; it is not a claim that every SPEC9 family already has a physical implementation.

| SPEC FAMILY | REFERENCE / REQUIRED EXTENSION |
|---|---|
| Settings, Person | Extend: typed settings/person and person links; lock bootstrap belongs to native device control, not a new financial vault |
| Account, BalanceSnapshot, ValuationRule | Reference: accounts, balance_anchors, current_balance_anchors; extend typed method parameters and complete account subtypes |
| CardDetails, LoanDetails, CardStatement | Reference: card_statements plus obligations/settlement graph; extend card/loan metadata and typed amortisation inputs |
| Transaction, TransactionSplit, TransactionLine, TransferFx | Reference: transactions, transaction_splits, transfer_links, transfer_fx; extend typed receipt line items; never count both lines and splits |
| Category, CategoryRule, Tag, TransactionTag | Reference: categories; extend typed bounded rule, tag and join families |
| RecurringRule, PriceChange, ExpectedIncome | Reference: schedules, occurrence/locator/decision/obligation families; extend versioned price-change observations and source-specific income metadata |
| Budget, BudgetLimit, BudgetTemplate | Extend: typed period/category/currency inputs and templates; derived carry-forward uses the shared projection protocol |
| Payslip | Extend: typed gross/deduction/benefit/line families with event and matched-posting FKs |
| Security, FundHolding | Reference: securities, public instrument/detail and series families; extend dated constituent weights and coverage |
| Holding, Lot, InvestmentTransaction, RealisedGain | Reference: holdings, immutable observations, events, lots, generation-bound allocations and results; any new specific-lot election needs an authored contract |
| PriceQuote, FxRate | Reference: immutable public/manual quote and FX observations, selection pointers and history pins; no remote FX |
| Benchmark, TargetMix | Extend: authored benchmark selection and exact allocation target groups; underlying public series and shared results reuse reference mechanisms |
| EquityGrant, VestSchedule, VestEvent | Extend: typed grant/schedule/vest relationships; link confirmed effects to the existing event/holding/posting families |
| InsurancePolicy, Claim | Extend: typed policy/coverage/person/nominee/claim bridges; premiums and payouts link to existing obligations/transactions |
| Goal, GoalAllocation | Extend: typed goal/account allocation inputs with transactional percentage invariant; no stored second account value |
| TaxDate, TaxSavingLimit, ContributionLimit | Extend: typed country/year/currency records and contribution evidence links; expected tax does not create cash |
| Debt, DebtPayment | Reference: canonical account/postings/settlements; extend debt-specific metadata and payment bridges, not a debt ledger |
| EmergencySheetEntry | Extend: typed versioned record with entity references; no passwords or secrets |
| NetWorthSnapshot, MonthClose | Reference: month_closes, close_revisions, close_* evidence and exact result payload; no independent editable snapshot balance |
| ImportBatch, ImportMappingTemplate, ParserTemplate | Reference: batches, sources, immutable parse configuration and job-input links; extend reusable mapping/template libraries with supported grammar/version |
| InboxItem, CaptureSource | Reference: inbox_items, source identities/claims and publication revision; extend durable source policy/config revision and typed adapter configuration |
| ChangeLog, CalculatorPreset | Reference: immutable change_log and operation receipts; extend typed versioned calculator input presets |
| FinancialEvent, OperationIntent/Receipt, SourceIdentity, CloseRevision, DependencyRevision, Draft | Reference: event/operation/source/close/dependency/draft families with immutable receipts and lifecycle retention |
| Computed views and projections (SPEC9.8) | Reference: canonical keys, metric values, input pins, summaries, exact points, chart buckets, dirty ranges and generation pointers; never an authored history source |
| LayoutSurface, LayoutSection, LayoutItem | Reference: three typed layout tables, migration005, bounded Q18 and writer reference model; no widget definitions or calculated values in preferences |

All future typed families use the authored/immutable/operational distinction in SYSTEM_DESIGN 5.2. Their feature migrations must extend entity registration, identity conflict guards, revision/retention rules, reverse-reference indexes, snapshot closure, dependency invalidation and exact fixtures as applicable. A new permanent family cannot inherit correctness merely because it has a UUID or JSON codec.

## 4 Financial calculation coverage

All modules use the same exact kernel, injected clock, currency/rounding rules and StateValue. Calculator selection is release-gated. The cited SPEC section is the formula authority; an unresolved correction gate prevents that formula's release. Save inputs and method versions when needed for repeatability, not an unbounded cache per slider position.

| SPEC | MODULE / CALCULATION INPUT AND ACCEPTANCE |
|---|---|
| 13.1 | Monthly investing: start value, contributions, step-up, dates, rates and fees; annuity timing, zero-rate and rounding fixtures |
| 13.2 | Goal amount: target date/value, inflation and current allocation; no duplicate goal asset; missing/expired-date cases |
| 13.3 | Target mix: exact current values and authored targets; exact split, totals and currency closure |
| 13.4 | Financial independence: expenses, horizon, inflation and explicit rates; no advice or automatic financial record |
| 13.5 | Withdrawals: schedule and scenario inputs; end-date, depletion and rounding fixtures; no invented forecast certainty |
| 13.6 | Inflation: dated nominal value, period and rate; reverse and zero-rate cases |
| 13.7 | Home loan: principal/rate/term/fees and payment timing; amortisation sums and final-payment precision |
| 13.8 | Rent or own: separate cash-flow scenarios, transaction costs and time basis; comparable dated scope, no recommendation |
| 13.9 | Life cover: typed dependants/liabilities/assets and explicit assumptions; result only, not policy creation |
| 13.10 | Emergency fund: named expense basis and duration; shared spending input with coverage, no independent total |
| 13.11 | Currency: exact amount and selected local FX observation/date; missing FX and precision cases |
| 13.12 | Returns/benchmarks: dated flows, valuations, fees, basis and coverage; XIRR bracketing/convergence/ambiguity, TWR timing, CAGR duration and benchmark total-return basis |
| 13.13 | Cost basis/realised gains: ordered acquisitions, disposals, method and FX evidence; exact lot closure, backdated edit and full-rebuild equivalence |
| 13.14 | v2 withdrawal simulations: explicit seed, algorithm/distribution/model versions and work limits; no unseeded randomness, remote simulation or recommendation |
| 13.15 | Target amount per group: exact targets and available amount; largest-remainder closure and unchanged original holdings |
| 13.16 | Loans/debts: principal, payments, rate/fee and dated terms; no duplicate payment/cash ledger; partial settlement and recalculation |

## 5 Data quality acceptance

- Domain tests precede production number changes. Use Appendix A and independent high-precision oracle fixtures, including 0/2/3-decimal currencies, large checked integers, fractional quantities and prices, zero/negative/ambiguous solver cases and missing intervals. A Python schema test is not that oracle.
- An independent full replay from retained facts must equal each incremental result for the same method, scope and cutoff. Cover edit, undo, re-import, backdate, soft-delete, quote replacement, clock rollover and restore. Compare exact values **and** coverage/state/input provenance.
- Invariants include split conservation, exact percentage allocation, transfer conservation with one real fee, one cash posting per economic effect, lot quantity/cost closure, one obligation remainder and immutable saved-close reproduction. They must survive randomized seeded command sequences and every supported migration fixture.
- App tests compare one key on every active surface after a command and after late worker responses. No two consumers may show incompatible values as current. Exact chart/table/crosshair and spoken values must agree; geometry reduction cannot alter the number.
- Deleting all rebuildable caches must preserve accepted history, choices, deduplication receipts, retained evidence and selected close values. Rebuild only results; never infer missing authored facts from a chart or replace lost data with zero.

## 6 Delivery and remaining gates

The implementation order is SYSTEM_DESIGN 14: platform/cipher and exact types; command/shared-state foundation and Phase 1 widgets; import/basic cash; investments/returns; charts; recovery/privacy; optional public provider. Each phase must implement its typed storage extensions before its feature code is accepted.

PF-01 is an unresolved platform capability requirement. S01–S07, DB-A–F, W-A–L and P01–P22 are implementation evidence requirements, not passed measurements. G01–G14, the product/design questions in DECISIONS, missing catalogue defaults and unfinished calculation definitions remain prerequisites for their affected features. A complete architecture review cannot establish an OS guarantee or decide an undefined financial formula. The current package is the final technical baseline; future feature work must satisfy these contracts and use a reviewed change if it needs a different one.
