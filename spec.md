# Contour — Product Specification (SPEC.md)

Version 1.2 core — 15 October 2026. Split into a short core and a full reference; no rule, number, screen or open decision changes. History: `docs/DECISIONS.md`.

- This file is the short core: the product rules that every builder must know first.
- Full detail: `docs/spec/SPEC_REFERENCE.md`. It has the same authority and the same section numbers. A citation "SPEC 4.4" is section 4.4 in both files. When this file gives no detail, read the reference.
- Contour is a local-first personal finance app for iPhone and Android. It shows the whole financial position with almost no typing. Records stay on the phone; optional public market requests are the only network feature.
- PF-01 (SYSTEM_DESIGN 12.2) blocks real-user iOS persistence and release until platform feasibility is resolved.

## 0. How to use this document

- Build in the releases and phases of section 17. Start a phase only after the previous phase passes its acceptance tests.
- When two parts disagree, this order wins: section 2, section 3, section 4, then the rest.
- Use only the screen ids in 5.4. When text and a screenshot (`docs/screens/<id>.png`) disagree, the text wins.
- The final look is Obsidian (dark and Obsidian Light) in `contour-design.html`. Slabs-look screenshots are out of date for style and layout. When a prototype number differs from Appendix A, Appendix A wins.
- `code style` = a name in the code. "Quotes" = text that the user sees.
- Related documents: `AGENTS.md` (workflow), `SYSTEM_DESIGN.md` (modules, storage, privacy enforcement), `DATABASE_DESIGN.md` (tables, migrations), `DESIGN.md` (style; wins on style), `docs/screens/SCREENS.md` (screen layout), `docs/USAGE_FLOWS.md` (journeys, gates G01–G14), `docs/WIDGET_CATALOGUE.md` (widgets), `docs/DECISIONS.md` (decisions, open questions).
- Full detail: docs/spec/SPEC_REFERENCE.md §0.

## 1. Product blueprint

- Promise (1.1): "Know your money in 3 seconds. Enter almost nothing. Your financial records stay on your phone." When market access is on, tell the user that the provider receives public symbol/asset requests and connection metadata (10.5).
- Primary user (1.2): anyone who manages personal finances, from one bank account and one card to many accounts, markets and currencies. Every feature works for the simplest case (one account, one card, no investments). Complex cases add to the simple path and never break it.
- What the app is not (1.3): not an investment or trading app (it never buys, sells or moves money); not an advisor; not connected to banks, brokers, pension portals, credit bureaus or government systems; it never asks for their passwords.
- Core loop (1.4): Capture → Inbox (confirm, change, delete) → Glance (Home) → Monthly close (about 10 minutes).
- Success measures (1.5): 90% of payments without typing; under 10 minutes of input a month; Home understood in 3–5 seconds.
- Trust (1.6): open-source code; no account, sign-up or email address; three plain privacy facts in onboarding.
- Full detail: docs/spec/SPEC_REFERENCE.md §1.

## 2. Product rules

These rules are fixed. Every feature follows them.

- Local first. All user data is stored and processed on the device. No server stores or reads user data. No account and no sign-in.
- Data only. The app shows facts: amounts, changes, splits, dates and the results of the user's own inputs. It never gives advice, recommendations, warnings, scores or "you should" text.
  - Allowed: "You spent $3,940 of your $5,200 limit." (The limit is the user's own number.)
  - Allowed: comparisons with the user's own history: "Rent is 46% of spending. 12-month average: 46%."
  - Allowed: calculations from the user's own targets, in neutral words: "To reach it by March 2027: $813 a month."
  - Not allowed: "You spend too much", "on track", "behind", "risky", "safe", "good", "bad", "sell", "buy", "recommend", "should", targets or thresholds the user did not enter.
  - Banned words (checked on every golden screen, 16.3): should, recommend, too much, risky, safe (as advice), on track, behind, good, bad, great, sell, buy, warning. ("Sold" in history is allowed.)
- Neutral facts, not alarms. Dates, payments due and low balances show as facts in the normal style. No red alert banners, no alarm sounds, no "warning" words.
- Low input. About 10 minutes a month of data entry. Automate everything that needs no decision. Every capture goes to the Inbox (or the form) before it is saved.
- Glanceable. Each screen starts with one large number, one short line that explains it, and at most one chart.
- Global. Any currency, locale and country. Country features are data files (parsers, templates), never hard-coded logic.
- Offline. All user records, capture, imports, calculations, search, charts and recovery run on the phone. Only optional public symbol, price, instrument-detail and approved public asset requests use the network (10.5). Exchange rates come from manual entry or local files.
- No outgoing user records. No email connection, cloud backup, external file export, remote inference, shared-folder or LAN sync. Operating-system backup and device-transfer paths are excluded. Local recovery copies stay in protected app storage; they cannot recover a lost phone.
- Full detail: docs/spec/SPEC_REFERENCE.md §2.

## 3. Ease of use and easy input (top priority)

If a feature makes the app harder to use or data harder to enter, change or remove the feature.

### Input targets (3.1, measured in integration tests)

| Task | Maximum |
|---|---|
| Add a typical expense (amount, category, today) | 3 taps or 1 voice sentence, under 5 seconds |
| Add an expense from a QR receipt | 2 taps |
| Import a monthly bank file the second time (saved layout) | 4 taps from the share sheet to "Sent to the Inbox" |
| Confirm a vest event | 2 taps |
| Update all prices | 0 taps if price updates are on, else 1 tap |
| First useful screen after install | under 60 seconds, with one required choice |
| Confirm 20 Inbox items | under 60 seconds |
| Monthly close | under 10 minutes |

### Input rules (3.2)

- Never ask for data the app can work out (date, currency, category, account).
- Amount first (keypad ready). Main actions in the bottom half (one-handed use).
- One destination: voice, QR, receipt, quick add and imports fill the same form or the same Inbox.
- Fix later: never block Save for optional fields. Batch actions on many items.
- Clear errors: what happened and what the user can do, in one or two sentences. No error codes.
- DECISION-PENDING X20-RECENT: recent-payment chips and "Repeat last" are deferred.

### Interface rules (3.3)

- Simple first. Advanced features are off by default (Settings > Features).
- One row of controls per screen: at most one segmented control or one chip row. Choices inside a form do not count. Open question CONTROL-ROW-SCOPE: does a switch inside one card count? Until decided, the rule applies without change.
- One add control per screen. On tab screens it is the tab bar Add button only. A screen without the tab bar may have one "+" in the header.
- One main action per screen, the only filled button.
- Plain words (technical terms get an (i) definition). One top line on every screen (TOPLINE-001).
- Sizes: touch targets at least 44 x 44 pt; text at least 13 pt (exceptions in 7.3); text contrast at least 4.5:1.
- Every swipe has a button. Swipes are shortcuts only.
- Colour is never the only signal. Names in words; flow symbols ● spending, ◆ investing, ★ money in; gains and losses always signed (+ or –).
- Empty states give the next step in words, without a second add button. No setup walls (one required choice: main currency).
- Widgets (WIDGETS-001): every card on a tab screen is a widget the person can hide, reorder and add; the hero stays fixed; hiding never deletes data (catalogue: `docs/WIDGET_CATALOGUE.md`).

### Usability checks (3.4): five new people do the 3.1 and 1.5 tasks without help before each phase is accepted.

- Full detail: docs/spec/SPEC_REFERENCE.md §3.

## 4. Money logic and trust rules

Wrong numbers destroy trust. Everything in this section is required.

### Money rules (4.1, 4.2)

- Money = integer minor units + ISO 4217 currency code (JPY 0, USD 2, KWD 3 decimals).
- Never floating point for money. `Decimal` for maths, then round to minor units. Quantities: `Decimal`, up to 8 decimal places.
- Rounding: half to even for conversions, half up for display. Percentages in one split add to exactly 100% (largest remainder).
- Totals show in the main currency; each item keeps its original currency. Convert at the item's date rate; a nearest earlier rate gives "Est.".
- Transfers between own accounts and card repayments are not spending. Refunds reduce spending. Reimbursable payments are not personal spending. One purchase from many sources = one payment.
- Estimated values show "Est.".

### Trust rules (4.3)

- Count each asset once. Liabilities include more than loans. Incoming cash is not always income. Saving is not growth. Goals do not create wealth. Cover is not wealth.
- Expected is never in totals: unvested shares, projected pensions, money owed to you and expected dividends are "Expected" and never in net worth.
- Unknown is never zero: nothing recorded shows "None recorded"; a missing value shows "Missing"; never "$0".
- Averages state their coverage. Every summary shows its basis one tap away.

### Main numbers (4.4) — formulas and edge cases in the reference

| Number | Plain meaning |
|---|---|
| Net worth | What you own – what you owe, at today's prices and rates; Expected items excluded |
| What you own | Current values of all assets included in net worth |
| What you owe | All liability balances (loans, cards, pay-later, money borrowed, taxes due) |
| Cash you can use | Balances of accounts marked as cash you can use |
| Due before next income | Cash payments due from today until the day before the next income (or next 30 days) |
| Available until [date] | Cash you can use – payments due before the next income |
| Money in (month) | Income in the month (no transfers, loans, sale proceeds, refunds) |
| Money out / Spent (month) | Expenses minus refunds (no transfers, card repayments, reimbursables) |
| Kept (month) | Money in – money out; Kept % = kept ÷ money in |
| Spent vs limit | Spent ÷ the user's monthly limits (no limit: same day last month) |
| Month gone | Share of the budget month that has passed |
| Months covered | Cash you can use ÷ average monthly spending (complete months, up to 12) |

### Investment numbers (4.5)

| Number | Plain meaning |
|---|---|
| Value | Quantity x latest price x FX rate, plus cash in investment accounts |
| Today | Value now – value at each market's previous close |
| Invested | Cost basis of holdings held now, with buy fees and taxes |
| Unrealised gain | Value – invested, for holdings not sold |
| Realised gain | Per sale: proceeds – fees – cost of the shares sold; fixed at the sale |
| Dividends | Cash dividends and interest received (after withholding tax) |
| Total gain since you started | Price gain + dividends + currency effect = unrealised + realised + dividends |
| Price gain | Gain from price changes, in each holding's own currency |
| Currency effect | Gain or loss from exchange-rate changes since purchase |
| Time-weighted return | Return without deposit timing; for benchmarks (13.12) |
| Money-weighted return | The user's own return with timing (XIRR) |
| Yield on cost | Dividends in the period ÷ invested |
| Share of investments / of net worth | Holding value ÷ investments value, or ÷ net worth |

### Other number rules

- Glance priority (4.6): needs action → available money → this month → overall position → progress. Open question GLANCE-ORDER: Home now puts net worth first (6.2).
- What changed (4.7): net worth change = You kept + Markets + Currency + Values; the parts add up; a missing part is "Missing", never a residual. Shown only in About this number. Open question NW-ABOUT-ENTRY: the entry point to `X40bAboutNumber`.
- Cash flow forecast (4.8): each account's expected balance day by day until the next income; card spending reaches cash only at the statement payment; show the lowest expected balance and its date.
- Value states (4.9): Real, Estimated, Expected, None recorded, Missing, Old price, Hidden ("$⋯⋯").
- Full detail: docs/spec/SPEC_REFERENCE.md §4.

## 5. Information architecture and navigation

- Tab bar (5.1): Home (`X10Home`), Spending (`X30SpendingOut`), Add (centre; long-press = voice), Wealth (`X40WealthOverview`), Plan (`X50Calendar`).
- Sub-tabs (5.2): only Plan has sub-tabs (Calendar, Goals, Protect, Tax). Spending and Wealth have none. A sub-tab appears only when its release ships (v1: Calendar; v1.1: Goals, Protect; v1.2: Tax).
- Add (5.3): Home and Spending open the expense form (`X20AddExpense`); other tabs open the chooser (`X29AddChooser`) with the context option first.
- Screen map (5.4): the list of valid screen ids is in the reference.
- Full detail: docs/spec/SPEC_REFERENCE.md §5.

## 6. Screen specifications

- Layout of each screen: `docs/screens/SCREENS.md`. Content, actions, rules and states per screen: the reference.
- All screens follow 3.3 and section 7. Each has an Obsidian hero. Sample values come from Appendix A. Every chart has "Show as table" unless it is a preview chart (PREVIEW-CHART).

| Area | Purpose | Main screens |
|---|---|---|
| 6.1 Start | First open, one required choice, app lock | `X01Welcome`, `X02Lock`, `X03HomeFirstRun` |
| 6.2 Home | Glance: net worth, Quick look, next 30 days, this month | `X10Home`, `X40bAboutNumber`, X11–X15 |
| 6.3 Add and capture | Amount-first form, voice, QR, receipt, transfers | X20–X29, X87 |
| 6.4 Inbox and import | Confirm every capture; read files on the phone | X60–X69b, X88 |
| 6.5 Spending | Spent for the period against the limit, by category, repeating, money in | X30–X39b |
| 6.6 Wealth | Net worth, what you own and owe, Expected items | X40, X41–X42b, X46–X49 |
| 6.7 Investments | Value, gains, holdings, allocation, dividends, returns | X43–X45, X89 |
| 6.8 Plan | Calendar, cash flow, goals, protection, tax, calculators | X50–X59b |
| 6.9 Month close and Settings | Monthly close; settings, recovery, privacy | X70, X71, X80–X86 |

### Open items in section 6

- DECISION-PENDING SUBS-TOTAL (6.2): the Subscriptions Quick look tile and the "Subscriptions" category measure different things.
- Open question AS-OF-DATE (6.2): the prototype hides the Home date line; until decided, the header keeps date and currency.
- DECISION-PENDING X20-RECENT (6.3): recent payment chips are deferred; not in the v1 design.
- DECISION-PENDING CONTROL-ROW-SCOPE and ADD-CONTROL-SCOPE (6.6): the You own / You owe tabs and the dashed "None recorded" tiles on Wealth.
- Open question TREE-TARGETS (6.7): small treemap tiles can be under 44 pt; List is the full accessible path.
- Open question ALL-BASIS (6.7): hero "All" gain and Holdings "Since bought" gain use different bases.
- DECISION-PENDING NW-TARGET-PACE (6.8): the "At +$16,900 a year · 2074 · Est." row needs a wording and Est. rule.
- DECISION-PENDING NOT-ASSIGNED-DISPLAY (6.8): "Not assigned" is not shown in the v1 design.
- Open (SPEC-SYNC-001, 6.6): data model for pension subtypes, direct bonds and recurring deposits.
- `X82GmailBridge` is obsolete and unshipped (no route, setup action or switch).
- Full detail: docs/spec/SPEC_REFERENCE.md §6.

## 7. Design system "Obsidian"

DESIGN.md is the implementation guide and wins on style. All values come from `lib/design/tokens/tokens.json`.

- Obsidian: near-black page with one neutral spotlight; Obsidian Light is an equal designed theme, not an inversion.
- Metal cards with a fine silver rim (METAL-RIM-001); card titles sit above the cards (CARD-TITLE-OUT).
- One luminous hero number per screen, at most one chart. Section colour on chrome only; data colours on data only; glow only on chart end-point marks.
- Calm motion (MOTION-002): each chart draws in once (≤ 900 ms), no loops, no count-up of the hero, reduce motion = no animation.
- Accessibility minimums: text 13 pt (12 pt tab labels, weekday headers, chart labels; 11 pt chart axes); touch 44 pt; contrast 4.5:1; font scale to 200%; every chart has a spoken label and "Show as table" (preview charts: label only).
- Full detail: docs/spec/SPEC_REFERENCE.md §7 and DESIGN.md.

## 8. Data input

- Input ladder (8.1): use the highest level available: 1. Automatic (0 taps: repeating, vests, values, prices; v1.1 notifications, FinanceKit, watched folder); 2. One tap (shared statements, QR, receipt photo, screenshot); 3. One sentence (voice, quick add); 4. Form (about 3 taps).
- All sources feed the Inbox (or the form). Each fact is stored once and used everywhere (8.2).
- Parsing, OCR, QR and voice run on the device only. Audio is never saved. Parsers never write to the database.
- No email connection of any kind; local attachments use the normal import path (8.12). Never request SMS permission.
- Full detail (parser grammar, voice test sentences, dedupe, templates): docs/spec/SPEC_REFERENCE.md §8.

## 9. Data model

- Authored tables have `id` (UUID v7), `createdAt`, `updatedAt`, `deletedAt` (soft delete). Money fields end in `Minor` with a `currency`. Every value record has a `source`. Confirmed changes write `ChangeLog`.
- Entities:
  - Settings and people: `Settings`, `Person`.
  - Accounts and values: `Account`, `BalanceSnapshot`, `ValuationRule`, `CardDetails`, `LoanDetails`, `CardStatement`.
  - Payments and budget: `Transaction`, `TransactionSplit`, `TransactionLine`, `TransferFx`, `Category`, `CategoryRule`, `Tag`, `TransactionTag`, `RecurringRule`, `PriceChange`, `Budget`, `BudgetLimit`, `BudgetTemplate`, `Payslip`, `ExpectedIncome`.
  - Investments: `Security`, `FundHolding`, `Holding`, `Lot`, `InvestmentTransaction`, `RealisedGain`, `LotAllocation`, `PriceQuote`, `FxRate`, `Benchmark`, `TargetMix`.
  - Shares from work: `EquityGrant`, `VestSchedule`, `VestEvent`.
  - Protection and plans: `InsurancePolicy`, `Claim`, `Goal`, `GoalAllocation`, `TaxDate`, `TaxSavingLimit`, `Debt`, `DebtPayment`, `EmergencySheetEntry`, `ContributionLimit`.
  - Snapshots, imports, history: `NetWorthSnapshot`, `ImportBatch`, `ImportMappingTemplate`, `ParserTemplate`, `InboxItem`, `CaptureSource`, `MonthClose`, `ChangeLog`, `CalculatorPreset`.
  - Lifecycle and supporting: `FinancialEvent`, `OperationIntent`, `OperationReceipt`, `SourceIdentity`, `CloseRevision`, `DependencyRevision`, `Draft`.
- Computed views are rebuildable projections, not facts.
- Full detail (fields, enums, rules): docs/spec/SPEC_REFERENCE.md §9, DATABASE_DESIGN.md.

## 10. Platforms, stack and architecture

- Platforms (10.1): iOS 16+ and Android 8.0+ (API 26+), phones only in v1. PF-01 blocks real-user iOS persistence and release (SYSTEM_DESIGN 12.2).
- Stack (10.2): Flutter, Riverpod, go_router, Drift over SQLCipher, on-device speech and OCR, `CustomPainter` charts.
- Layers (10.3): UI → application → domain (pure Dart) → data → platform.
- Network policy (10.5):
  - No network by default. Only an explicitly enabled public-data provider fetches public symbols, prices, history, instrument details, logos and approved public assets, through one gateway in `lib/data/prices/`.
  - Never send balances, quantities, holdings, account names, personal search text, transaction dates, files, transcripts, database IDs or device identifiers.
  - FX rates are manual or local import only. No email, upload, cloud OCR or speech, analytics, crash service, telemetry, remote configuration, cloud backup, export or sync. No Contour server.
- Future platforms (10.6, v2): tablets, Mac and Windows from the same code, independent local data per device.
- Full detail: docs/spec/SPEC_REFERENCE.md §10.

## 11. Security and privacy

- Encrypted database, app lock, blur in the app switcher.
- Imported files and images are deleted after parsing (receipt images kept, encrypted, only when the user turns it on).
- Widgets are launch-only. Data paths are excluded from OS backup and device transfer.
- "Delete all data" removes records, recovery copies, keys and caches after a confirm.
- Full detail: docs/spec/SPEC_REFERENCE.md §11.

## 12. Symbols, prices and instrument details

- One local `MarketDataGateway`, off by default. Never replace a known quote with zero. No remote FX.
- Full detail: docs/spec/SPEC_REFERENCE.md §12.

## 13. Calculators and formulas

- Calculators are pure Dart in `domain/calculators/`, with unit tests. Results come only from the user's inputs.
- Tools: Monthly investing (13.1), Goal amount (13.2), Target mix (13.3, 13.15), Financial independence (13.4), Withdrawals (13.5, 13.14), Inflation (13.6), Home loan (13.7), Rent or own (13.8), Life cover (13.9), Emergency fund (13.10), Currency (13.11), Returns TWR/XIRR (13.12), Cost basis and realised gains (13.13), Loans and debts (13.16).
- Full detail (formulas, test values): docs/spec/SPEC_REFERENCE.md §13.

## 14. Same device recovery

- Encrypted recovery snapshots stay in protected app storage on this phone; up to eight weekly snapshots. No folder, export or transfer. A snapshot cannot recover a lost phone or a removed app.
- Full detail: docs/spec/SPEC_REFERENCE.md §14.

## 15. Widgets and shortcuts

- Launch-only controls behind app unlock. No financial text or amounts pass to widgets, Siri, OS search, shortcuts or the clipboard.
- Full detail: docs/spec/SPEC_REFERENCE.md §15.

## 16. Quality and tests

- Unit tests for every section 4 number (Appendix A data) and calculator. Goldens for every final screen: dark and Light, scale 1.0 and 2.0.
- Automated interface checks (16.3) on every golden screen: banned words (section 2), text size, touch targets, one control row, one add control, contrast, percentages add to 100, unknown is not zero.
- Full detail: docs/spec/SPEC_REFERENCE.md §16.

## 17. Releases, phases and acceptance

Every phase passes the usability checks (3.4) and the automated checks (16.3).

| Release / phase | Scope |
|---|---|
| v1 Phase 1 — Base | Project, tokens, themes, encrypted database, ChangeLog, app lock, Welcome, first-run Home, Privacy screen, component gallery |
| v1 Phase 2 — Capture, Inbox, Spending | Add expense/income/transfer, quick add, voice, rules, repeating, Inbox, all Spending screens, accuracy rules, undo, hide amounts |
| v1 Phase 3 — One-tap imports | Share into the app, CSV/Excel, bank formats, PDF with Teach once, QR, receipt photo, holdings screenshot, batch undo |
| v1 Phase 4 — Position | Accounts and assets, Wealth, Investments (basic Returns), Home final, Calendar and cash flow, Monthly close, local recovery |
| v1.1 | Local capture sources, payslip/loan/policy imports, benchmark, sector allocation, currency transfers, Protect, Goals and net worth target |
| v1.2 | Tax and year, Emergency sheet, Tools and calculators, money lent and borrowed, contribution limits, target mix |
| v2 (off by default) | Time machine, joint accounts, custom budget periods, money flow, report builder, withdrawal simulations, family view; tablets, Mac and Windows |

- Acceptance tests per phase: docs/spec/SPEC_REFERENCE.md §17.

## 18. Out of scope

- Any server, account, cloud or LAN sync, outgoing export or remote processing of user records.
- Direct bank, broker, pension, credit-bureau or government connections. AI services off the device.
- Advice, recommendations, behaviour alerts, scores or targets the user did not enter. Tax calculation or filing.
- Full detail: docs/spec/SPEC_REFERENCE.md §18.
