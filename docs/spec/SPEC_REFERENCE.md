# Contour — Product Specification Reference (SPEC_REFERENCE.md)

- This file is the product specification detail. `SPEC.md` is the short core.
- Three sections live in their own files: §6 `SPEC_SCREENS.md`, §9 `SPEC_DATA_MODEL.md`, §13 and Appendix A `SPEC_CALCULATIONS.md`.
- Both files have the same authority and the same section numbers. "SPEC n.n" means section n.n in both; this file holds the detail.
- Paths in `code style` (for example `docs/screens/`, `docs/DECISIONS.md`) are relative to the repository root.

**Version 1.1.3 — 16 October 2026. This version only shortens the text; no rule, number or decision changes.** The version history (SPEC-SYNC-001, DESIGN-HTML-014, DESIGN-HTML-015, ARCH-001, ARCH-REVIEW-001, DB-001, NUM-001–003) is in `docs/DECISIONS.md`.

Contour is a local-first personal finance app for iPhone and Android. It shows the whole financial position (income, spending, cash, investments, debts, protection, plans) with almost no typing. Financial records stay on the phone. Optional public market requests are the only network feature. PF-01 (SYSTEM_DESIGN 12.2) blocks real-user iOS persistence and release until platform feasibility is resolved.

## 0. How to use this document

- This file is the main instruction for the AI coding tool. Build in the releases and phases of section 17. Start a phase only after the previous phase passes its acceptance tests.

| DOCUMENT | OWNS |
|---|---|
| AGENTS.md | Workflow, commands, code conventions, roles, definition of done |
| docs/approved-architecture/SYSTEM_DESIGN.md | Modules, storage, workers, derived data, privacy enforcement, recovery, performance plan |
| docs/approved-architecture/DATABASE_DESIGN.md | Tables, constraints, codecs, queries, migrations |
| DESIGN.md | Tokens, type, components, charts, style rules (wins on style) |
| docs/screens/SCREENS.md | Layout of each screen, by screen id (DESIGN.md 14 points to it) |
| docs/flows/USAGE_FLOWS.md | Journeys, save boundaries, correction gates G01–G14 |
| docs/spec/spec-widgets.md and docs/approved-architecture/widget-framework.md | Widgets and Quick look tiles |
| docs/DECISIONS.md | Decisions, history and open questions |

- Screenshots: `docs/screens/<screen id>.png` (for example `X10Home.png`). They are
  not in this checkout yet; use the screen description in `docs/screens/SCREENS.md`.
  Text wins over a screenshot. See docs/DECISIONS.md (SCREEN-REFERENCES).
- The final look is Obsidian (dark and Obsidian Light). The `contour-design.html`
  figure is not in this checkout yet. Appendix A wins over prototype numbers.
  See docs/DECISIONS.md (SCREEN-REFERENCES).
- Conflicts inside this file: section 2 wins, then 3, then 4, then the rest.
- Use only the screen ids in 5.4.
- `code style` = names in code. "Quotes" = text the user sees.

## 1. Product blueprint

### 1.1 Promise

"Know your money in 3 seconds. Enter almost nothing. Your financial records stay on your phone."

- When market access is on, tell the user that the provider receives public symbol/asset requests and connection metadata (10.5).

### 1.2 Primary user

- Anyone who manages personal finances, from one bank account and one card to many accounts, markets and currencies. Design and test across this range.
- Every feature works for the simplest case: one bank account, one card, no investments. Complex cases (currencies, investments, employer share plans) add to this path and never break it.

### 1.3 What the app is not

- Not an investment or trading app. It never buys, sells or moves money.
- Not an advisor. It shows facts only (section 2).
- Not connected to banks, brokers, pension portals, credit bureaus or government systems. It never asks for those passwords.

### 1.4 Core loop

1. **Capture:** automatic, 1 tap or 1 sentence (8.1).
2. **Inbox:** every capture lands in one Inbox. The user confirms, changes or deletes. The app learns from each change.
3. **Glance:** Home shows needs action, available money, this month, overall position, progress (4.6).
4. **Monthly close:** a guided flow of about 10 minutes, once a month.

### 1.5 Success measures

| MEASURE | TARGET |
|---|---|
| Payments that arrive without typing (automatic, 1 tap or Inbox confirm) | at least 90% |
| Input time per month, primary user | under 10 minutes |
| Time to understand Home (user test) | 3 to 5 seconds |
| Time to understand a category screen (user test) | under 30 seconds |
| Users active after 3 months (user tests only; the app never reports it) | main product measure |

### 1.6 Trust

- Publish the source code under an open-source licence (choose before release; Appendix C).
- Store privacy declarations match the audited release, provider and native SDK behaviour. Do not preselect a collection or sharing label before that check. Apply current store definitions.
- No account, no sign-up, no email address.
- Onboarding shows three plain privacy facts on one screen.

## 2. Product rules

These rules are fixed for every feature.

- **Local first.** All user data is stored and processed on the device. No server stores or reads user data. No account, no sign-in.
- **Data only.** Show facts: amounts, changes, splits, dates, results of the user's own inputs. Never advice, recommendations, warnings, scores or "you should" text.
  - Allowed: "You spent $3,940 of your $5,200 limit." (the user's own limit).
  - Allowed: own-history comparison: "Rent is 46% of spending. 12-month average: 46%."
  - Allowed: neutral calculation from the user's target: "To reach it by March 2027: $813 a month."
  - Not allowed: "You spend too much", "on track", "behind", "risky", "safe", "good", "bad", "sell", "buy", "recommend", "should", targets or thresholds the user did not enter.
- **Neutral facts, not alarms.** Dates, payments due and low balances use the normal style. No red alert banners, alarm sounds or "warning" words.
- **Low input.** About 10 minutes a month. Automate everything that needs no decision. Every capture goes to the Inbox (or the form) before it is saved.
- **Glanceable.** Each screen starts with one large number, one short explaining line, and at most one main chart.
- **Global.** Any currency, locale and country. Country-specific features are optional data files (parsers, templates), never hard-coded logic.
- **Offline.** User records, capture, imports, calculations, search, charts and recovery run on the phone. Only optional public symbol, price, instrument-detail and approved public asset requests use the network (10.5). Exchange rates come from manual entry or local files.
- **No outgoing user records.** No email connection, cloud backup, external file export, remote inference, shared-folder or LAN sync. Operating-system backup and device-transfer paths are excluded. Local recovery copies stay in protected app storage; they cannot recover a lost phone.

## 3. Ease of use and easy input (top priority)

These goals come before every other feature. If a feature makes use or input harder, change or remove the feature.

### 3.1 Input targets (measured in integration tests)

| TASK | MAXIMUM |
|---|---|
| Add a typical expense (amount, category, today) | 3 taps or 1 voice sentence, under 5 seconds |
| Add an expense from a QR receipt | 2 taps |
| Import a monthly bank file the second time (saved layout) | 4 taps from the share sheet to "Sent to the Inbox" |
| Confirm a vest event | 2 taps |
| Update all prices | 0 taps if price updates are on, else 1 tap |
| First useful screen after install | under 60 seconds, one required choice |
| Confirm 20 Inbox items | under 60 seconds |
| Monthly close | under 10 minutes |

### 3.2 Input rules

- **Never ask for data the app can work out.** Date: today. Currency: last used. Category: merchant rule. Account: last used for that category.
- **Amount first.** The expense form opens with the keypad ready and the amount active.
- **One-handed use.** Main actions sit in the bottom half of the screen.
- **Input shortcuts are not advice.** Most-used categories show as chips. Recent-payment chips are deferred (DECISION-PENDING X20-RECENT, 6.3).
- **One destination.** Voice, QR, receipt, quick add and imports fill the same form or the same Inbox.
- **Fix later.** Save without a category is allowed. Never block Save for optional fields.
- **Batch actions.** Change category, tag or account for many selected items at once.
- **Repeat last (with X20-RECENT).** A recent-payment chip ("Coffee 6.40") fills the form again with today's date.
- **Clear errors.** One or two sentences: what happened and what the user can do. No error codes.

### 3.3 Interface rules

- **Simple first.** Advanced features are off by default. Turn them on in Settings > Features (6.9).
- **One row of controls per screen:** at most one segmented control or one chip row.
  - Plan: its sub-tabs (Calendar, Goals, Protect, Tax).
  - Spending, Wealth, Investments: no sub-tabs; the row is the period chips under the hero chart.
  - A deeper view is its own screen with Back and one control for its own choice.
  - Choices inside a form (for example category chips) do not count.
  - Open question CONTROL-ROW-SCOPE: does a switch inside one card (You own / You owe on Wealth, Holdings menus on Investments) count? Until decided, the rule applies unchanged.
- **One add control per screen.** On tab screens it is the tab bar Add button only. No header "+" and no "Add ..." button with a plus icon. A screen without the tab bar may have one header "+".
- **One main action per screen,** the only filled button.
- **Plain words.** "Money in", "Money out", "What you own", "What you owe", "Payment", "To use", "Kept". A technical term (for example "time-weighted return") has an (i) button with a short definition.
- **Consistent places.** Back: top left. Home: Hide amounts, Inbox and Settings top right. Filters: top right on deeper screens, or in the header of the card they act on. Period: chip row under the hero chart.
- **One top line on every screen (TOPLINE-001).** Left: Back or Close (if any), then the page label (kicker: metric or page name). Right: up to 3 tool buttons. Plan: section tabs left, tools right, no page label. The page title is a screen-reader heading only. A long label wraps only between " · " parts. Look: DESIGN 6.7 ScreenHeader (section colour, 13 pt caps).
- **Sizes.** Touch targets at least 44 x 44 pt. Text at least 13 pt (exceptions in 7.3). Text contrast at least 4.5:1.
- **Every swipe has a button.** Swipes are shortcuts only.
- **Colour is never the only signal.** Every type colour also has its name in words. Payment flows have a symbol: ● spending, ◆ investing, ★ money in. Gains and losses always have a sign (+ or –).
- **Empty states give the next step** in words, without a second add button.
- **No setup walls.** Onboarding has one required choice (main currency).
- **Widgets on tab screens (WIDGETS-001).** Keys, names, defaults and empty states: `docs/WIDGET_CATALOGUE.md`.
  - Every card on a tab screen is a widget: Home, Spending (Out and Money in), Wealth, Investments, Plan (Calendar, Goals, Protect, Tax). The hero is not a widget and stays fixed. Detail screens and sheets stay fixed.
  - The person can hide, reorder and add widgets, also from another tab screen (for example "By category" on Home). A widget shows the same numbers as on its own screen and opens that screen. A widget with its own controls (Holdings with its view switch; What you own / What you owe) stays on its own screen.
  - Entry points: "Edit widgets" row at the end of each tab screen, and Settings > "Screens and widgets" (each tab screen with its widget count). Both open the same edit mode. "Restore the default widgets" resets every screen.
  - Edit mode: each widget has Hide, Move up, Move down (button path for the drag) and a drag handle. Widget content ignores taps.
  - Edit bar, one row (WIDGETS-004): Cancel, Undo, Default, Add widget, Done.
    - Undo: one change back at a time, this session.
    - Default: this screen's default widgets and order (Home: also the default Quick look tiles). Undo can reverse it.
    - Add widget: no plus icon (tab bar Add stays the only add control). Its sheet lists widgets hidden on this screen first, then widgets of other tab screens.
    - Cancel: leave edit mode and restore the screen as it was. Done: keep the changes; the only filled button.
    - Look: DESIGN 6.7 WidgetEditBar.
  - Hiding a widget never deletes data. The layout is a local preference (one record per screen: ordered widget ids). It is not financial data and not in ChangeLog.

### 3.4 Usability checks before each phase is accepted

- Five people who did not build the app do the 3.1 tasks and the 1.5 comprehension tasks without help. Record time and taps.
- A task fails if a person needs help or exceeds the target. Fix and retest before the next phase.

## 4. Money logic and trust rules

Wrong numbers destroy trust. Everything in this section is required.

### 4.1 Money and currency

- Store money as **integer minor units** with an ISO 4217 code, using the currency's minor unit count (JPY 0, USD 2, KWD 3).
- Never use floating point for money. Use `Decimal` (package `decimal`) for maths, then round to minor units.
- **Rounding:** half to even for conversions, half up for display.
- **Main currency:** the user picks one (default from device region). Totals use it. Each item keeps its original currency and amount.
- **Conversion:** rate of the item's date. No rate for that date: nearest earlier rate, marked "Est.".
- **Display:** device locale number formats. Compact forms only where space is small ($187.9k). Indian numbering (lakh, crore) is a Settings option.
- **Quantities:** `Decimal`, up to 8 decimal places.
- **Percentages in one split add up to exactly 100%** (largest-remainder rounding).

### 4.2 Accuracy rules

- **Transfers are not spending.** A transfer between own accounts: same amount (±0.5% for currency conversion), opposite sign, dates within 5 days, both accounts the user's. A card bill paid from a bank account is a transfer to the card account. Link both sides with `transferPairId`. Exclude transfers from income and spending. Uncertain match → Inbox: "Is this a transfer between your own accounts?".
- **Refunds:** a positive amount from a merchant with an earlier expense. It reduces spending in the original category, in the refund month (setting: purchase month). Uncertain match → Inbox: "Refund of an earlier purchase?".
- **Reimbursable payments:** a payment marked "Reimbursable" is not personal spending. Until repaid, it is "Owed to you" (Expected).
- **One purchase, one payment.** Merge reports of the same purchase from several sources (notification, email, receipt, statement) into one payment with the most detailed fields. The statement is the final source for the amount. Uncertain match → Inbox: "Same purchase twice?".
- **Cash you can use:** balances of accounts marked "Counts as cash you can use" (default: current, savings, cash). Never deposits before maturity, pensions, property or investments.
- **One value method per asset (9.2).** Net worth uses the latest value from that method and shows the date of the last real (not estimated) value.
- **Estimated values show "Est."** (interest growth, contributions, depreciation, old prices, old exchange rates). Tap shows the basis.

### 4.3 Trust rules for every number

| RULE | HOW THE APP HANDLES IT |
|---|---|
| Count each asset once | Assets group cash, investments, retirement, deposits, property, vehicles, other. Shares from work inside a brokerage are in investments as "Of which: shares from work", never added again. |
| Liabilities include more than loans | Loans, card balances, pay-later plans, money borrowed and taxes due are all "What you owe". |
| Moving money is not spending | Transfers between own accounts and card repayments never count as spending. |
| Incoming cash is not always income | Loan money received, transfers and sale proceeds are money in, not income. Only the gain part of a sale is a gain. |
| Saving is not growth | Money put in and market growth always show separately. |
| Goals do not create wealth | Money assigned to a goal is the same money. Totals never add goals on top. |
| Cover is not wealth | Insurance cover and death benefits are never in net worth. Only a recorded cash or surrender value can be, labelled as such. |
| Owned is not expected | Unvested shares, projected pensions, money owed to you and expected dividends are "Expected", never in net worth. Wealth shows them in "Expected, not in net worth". |
| Unknown is not zero | Nothing recorded: "None recorded", never "$0" or "uninsured". Missing balance: "Missing", never zero. |
| Coverage of averages | A 12-month average uses only complete months. With fewer, the label says so: "Average of 9 months". |
| Every summary shows its basis | Period, currency, coverage and update date are one tap away ("About this number", X40bAboutNumber). Each value shows its source: "Imported", "Captured", "Manual" or "Est.". |

### 4.4 Main numbers (definitions)

| NUMBER | DEFINITION |
|---|---|
| Net worth | What you own – what you owe, in the main currency, at today's prices and rates. Expected items excluded. |
| What you own | Sum of current values of all assets with `includeInNetWorth = true`. |
| What you owe | Sum of all liability balances (loans, cards, pay-later plans, money borrowed, taxes due). |
| Cash you can use | Sum of balances of accounts with `isLiquid = true`. |
| Due before next income | Cash payments due from today to the day before the next expected income: repeating payments, card statement amounts (full), EMIs, premiums, repeating investments, user-entered taxes due. Same payment events as the forecast (4.8). A card purchase is spending on the purchase date; it reduces available cash only through the statement payment. Never count both as cash due. No next income date: next 30 days, labelled "next 30 days". |
| Available until [date] | Cash you can use – due before next income. |
| Money in (month) | Income transactions in the month. Excludes transfers, loan money received, sale proceeds, refunds (they reduce spending) and reimbursements. |
| Money out / Spent (month) | Expense transactions in the month, minus refunds. Excludes transfers, card repayments and reimbursable payments. |
| Kept (month) | Money in – money out. Kept % = kept ÷ money in. |
| Spent vs limit | Spent ÷ sum of the user's monthly limits. No limit: compare with spending on the same day of the previous month. |
| Month gone | (Today's day number – 1 + share of today) ÷ days in the budget month. Shown as a line or tick in meters. |
| Months covered | Cash you can use ÷ average monthly spending (complete months only, up to 12). |

### 4.5 Investment numbers (definitions)

| NUMBER | DEFINITION |
|---|---|
| Value | Σ (quantity x latest price x FX rate) + cash in investment accounts. |
| Today | Value now – value at the previous close of each holding's market, at today's rate. A closed market shows today's close. The screen states market status ("US closed at 4:00 pm. India and Taiwan: today's close."). |
| Invested | Cost basis of holdings held now (average cost by default, FIFO as a per-account option), including buy fees and taxes. |
| Unrealised gain | Value – invested, for holdings not sold. Also as % of invested. |
| Realised gain | Per sale: proceeds – fees – cost basis of shares sold. Fixed at sale time. Shown for this year and all time. |
| Dividends | Cash dividends and interest from investments, after withholding tax (stored separately). |
| Total gain since you started | Price gain + dividends + currency effect, since the first investment transaction. Equals unrealised + realised + dividends. |
| Price gain | Gain from price changes in each holding's own currency, at the purchase-date rate. |
| Currency effect | Gain or loss from exchange-rate changes between purchase date and today (or sale date), for holdings in other currencies. |
| Time-weighted return | 13.12. Compares holdings with a benchmark. |
| Money-weighted return | 13.12 (XIRR). The user's own return, including deposit timing. |
| Yield on cost | Dividends in the period ÷ invested. |
| Share of investments / of net worth | Holding value ÷ investments value, or ÷ net worth. |

### 4.6 Glance priority

Order on Home and at the top of each category screen: consequence first, then frequency. (The user's main number is first on Home; a saved layout replaces the order below it; 5.5.)

1. **Needs action:** facts with a date or a missing step (payment due, renewal, filing date, items to check, low expected balance). Neutral, never alarms.
2. **Available money:** cash you can use, what is due, next income.
3. **This month:** money in, spent against limit, kept.
4. **Overall position:** net worth, what you own, what you owe.
5. **Progress:** goals, debt paid off, money put into investments.

### 4.7 What changed (attribution)

- **Net worth, this month =** "You kept" (money in – money out) + "Markets" (price changes of investments and market-priced assets) + "Currency" (exchange-rate effect on items in other currencies) + "Values" (new real values, depreciation, interest, contributions to valued assets, if not zero). The parts add up to the total change. Hide a zero part.
- Opening net worth, closing net worth and every part use the same period and cut-off. "You kept" equals the kept amount shown elsewhere for that period.
- Each part needs source data. Never put an unexplained difference into "Values". Never treat a missing part as zero. Incomplete source data: mark the attribution "Missing" (4.9).
- **Investments, all time:** price + dividends + currency = total gain (4.5).
- **Where:** in About this number (X40bAboutNumber) only, not as a block on Wealth. Net worth has no (i) button; the entry point to X40bAboutNumber is open (NW-ABOUT-ENTRY).

### 4.8 Cash flow forecast

- Calculate each account's expected balance day by day until the next income (or 30 days), from repeating payments, card statements, EMIs, premiums, repeating investments, taxes due and expected income.
- Card spending reaches the paying account only when the statement is paid.
- A card charge after a statement closes is not part of that statement. It stays in spending and the calendar on its charge date, but creates no cash payment before its own statement payment date. Available money and the forecast use this same timing.
- Show the **lowest expected balance** and its date per paying account: "Checking, lowest expected: $4,035 on 30 Oct."
- A balance expected below zero shows its date and amount in the same neutral style.
- Mark uncertain items (estimated amounts, income without a fixed date) "Est.".

### 4.9 States every value can have

| STATE | MEANING | HOW IT LOOKS |
|---|---|---|
| Real | From a statement, import, capture or dated manual entry | Normal |
| Estimated | Calculated by a rule since the last real value | "Est." label |
| Expected | Not owned yet (vests, money owed to you, expected dividends) | "Expected" label, never in totals. A future vest shows "Expected" for its date and status; its value at today's price also has "Est." ("NVDA · 15 Nov · $3,949 Est.") |
| None recorded | Nothing entered for this type | Grey row, "None recorded" |
| Missing | A value is due but not entered (for example a statement not imported) | "Missing since [date]" |
| Old price | Price older than the last market close (offline) | Status banner and "Est." on totals |
| Hidden | Amounts hidden by the user | "$·⋯·" (currency mark stays); percentages stay visible. Charts keep their shape and hide text and amount labels. Spoken labels are masked too |

### 4.10 Transfer costs and fees

- Principal and fee are separate postings. The two principal postings of a transfer move value between the user's own accounts. They are neither money in nor money out, and they change net worth only when the two accounts differ in net-worth scope.
- A charged fee is a cost. Post it once, in the paying account's currency, for the amount actually charged. It is money out: it reduces cash and net worth, and it counts in Spent and therefore in Kept. It is not part of the transfer principal and never a second copy of the transfer amount.
- Only the charged amount posts. A percentage or a preview shown before Save is a calculation, not a posting. A repeated Save returns the first result (F05-D).
- The exchange spread is a comparison only. The difference between the rate received and the mid-market rate is shown ("plus $5.96 from the rate difference"). It is never posted, never added to the fee and never counted as money out. "What this transfer costs" may add both for comparison; the saved cost is the fee alone, and its caption says so.
- Capitalised fees stay in cost basis. A fee or tax included in an investment's cost basis is part of Invested (4.5), and a sale fee reduces proceeds. It is not money out and does not change net worth by itself, because the value moved into or out of the asset.
- No category unless set. A fee carries the fee kind and no category until the user sets one. It is never folded into the transfer's category or the user's chosen transfer amount. The spending breakdown accounts for every money-out amount, so an uncategorised fee is not lost from Spent.
- Fees count against limits. Spent includes fees (4.4), so a fee counts against the sum of the user's limits. It has no limit of its own unless its category has one. The app shows the arithmetic, not a warning (2).
- One fee per event. A transfer, card repayment or occurrence settlement posts at most one fee; a second fee is a second event. A fee is never merged with or duplicated from the transfer amount.
- Boundary transfer. When one account counts in net worth and the other does not, the principal changes net worth without changing Kept. The printed four-part bridge has no part for this, so the attribution shows Missing until a part is defined (DECISIONS P2-TRANSFER-BOUNDARY). The transfer, the account balances and net worth stay correct.

### 4.11 Refunds, reimbursements and money owed to you

- Two different cases. A refund is money a merchant returns for an earlier purchase. A reimbursement is money another party pays back for a payment the user made. Neither is income, and neither is a second copy of the original amount.
- Refund rule. A confirmed refund reduces spending in the original category, in the refund month by default. The setting "Refunds" (Settings > Money) chooses the refund month or the purchase month. The reduction applies to the period totals; the original payment is not rewritten. An unmatched positive amount from a merchant becomes an Inbox decision (4.2).
- Reimbursable payment. A payment marked Reimbursable is not personal spending from its own date. The money owed back is an expectation. The confirmed repayment is a positive posting linked to the payment, excluded from income, and it reduces the expectation once.
- Refund expected. A payment marked Refund expected stays in spending. The expectation tracks the money coming back. The confirmed refund applies the period rule above.
- One reason per payment. Reimbursable and Refund expected are exclusive. Turning one on clears the other and its open expectation; the payment amount, date and category do not change.
- Expectation record. An expectation is a known incoming amount with an optional date, a kind (reimbursement, refund, deposit, other money owed) and, for a reimbursement or a refund, a link to its payment. It is Expected: it is never cash you can use, never income and never in net worth. "Owed to you" lists it with its basis and count (4.3, 4.9).
- Expectations without a payment. A deposit held by another party, or other money owed, is an expectation with no linked payment. It follows the same Expected rules.
- Partial receipt. Each confirmed repayment or refund reduces the remaining expectation once. A receipt never exceeds the remaining amount; a larger receipt keeps its unallocated part, and no remainder becomes zero silently (8.17).
- Cancel an expectation. While no money is confirmed, the user can cancel an expectation. A reimbursable payment then counts as personal spending from its own date, and a refund expectation closes with spending unchanged. The change is recorded; it is not a silent reclassification.
- Reverse a confirmed receipt. A reversal is a compensating posting dated when it happens. It reopens the expectation with the remainder and never rewrites a past period (8.18).
- Passed dates are facts. An expectation whose date has passed keeps its date and its Expected state. It is never labelled overdue, late or missed (2).
- No double count. The original payment, the expectation and each confirmed receipt keep separate identities and typed links, so one amount is never counted twice in spending, income or "Owed to you".
- Test values. Appendix A's "Owed to you" is $2,640: a work reimbursement of $640 and a rent deposit of $2,000. Both are Expected, and neither is in net worth.

## 5. Information architecture and navigation

### 5.1 Tab bar

| TAB | SECTION COLOUR | OPENS |
|---|---|---|
| Home | blue-violet | X10Home |
| Spending | coral-magenta | X30SpendingOut |
| Add (centre) | white in dark, dark in Obsidian Light | Tap: 5.3. Long-press: voice input (X24VoiceListening) |
| Wealth | gold | X40WealthOverview |
| Plan | amber-orange | Plan, sub-tab Calendar (X50Calendar) |

- Floating tab bar, 64 pt, icon-only Add pill. The active tab shows its section colour. Sizes and colours: DESIGN 2.7 `size.tabBar`.
- Home header: Hide amounts, Inbox (count badge), Settings. A Search field sits below the Home title (5.5).
- Search also opens from the Spending header (X15Search). All payments has its own search field. Tools open from the Plan header.

### 5.2 Sub-tabs (one control row)

- **Plan:** Calendar, Goals, Protect, Tax, as a segmented control in the header row.
- **Spending:** no sub-tabs. One page (X30SpendingOut); its control row is the period chips.
  - Rows open Repeating (X34Repeating) and Money in (X31SpendingIn) as own screens with Back.
  - Budget content (limit per category, left, today tick) is part of Spending. Budget (X32Budget) stays a screen. Edit limits (X33EditLimits) returns to Spending.
- **Wealth:** no sub-tabs. Every item in You own and You owe opens its own screen.
- A sub-tab appears only when its release ships (17). v1: Plan shows Calendar only. Goals and Protect: v1.1. Tax: v1.2.

### 5.3 What Add does

| CURRENT TAB | TAP ON ADD |
|---|---|
| Home, Spending | Expense form (X20AddExpense) |
| Wealth | Chooser (X29AddChooser): Something you own or owe first, then Expense, Income, Transfer, Import a file |
| Plan > Goals | Chooser, A goal first |
| Plan > Protect | Chooser, A policy first |
| Plan > Calendar or Tax | Chooser, A repeating payment first |

- The expense form has a type switch: Expense, Income, Transfer.
- Long-press Add on any tab starts voice input in the expense form.

### 5.4 Screen map (screen id = screenshot file name in docs/screens/)

- Names, templates and sections of every id: SCREENS.md "Index". Build only the ids below.
- Reference only, not built: Home options X10aHomeToUse ("after bills" first), X10bHomeOverview, X10cHomeGlance; typography TypeAHome (chosen) to TypeGHome.
- X10Home is the final Home. X30 is one page.
- X82 (Gmail bridge) is obsolete and unshipped.

| GROUP | SCREEN IDS |
|---|---|
| 1. Start and Home | X01, X02, X03, X10Home, X40bAboutNumber, X11, X12, X13, X14, X15 |
| 2. Add and capture | X20, X21, X22, X23, X24, X25, X26, X26b, X27, X28, X87, X29 |
| 3. Inbox and import | X60, X61, X62, X63, X64, X65, X66, X67, X69, X69b, X68, X88 |
| 4. Spending | X30, X30c, X31, X32, X33, X34, X35, X36, X37, X38, X39, X39b |
| 5. Wealth | X40, X46, X41, X41c, X41d, X41e, X41f, X41b, X42, X42b, X47, X48, X49 |
| 5b. Investments | X43, X43j, X44, X43c (class), X43b (market), X43d (sector), X43e, X43f, X43g, X43h, X45, X89 |
| 6. Plan | X50, X50b, X51, X52, X53, X55, X56, X57, X58, X59, X59b |
| 7. Monthly close and settings | X70, X71, X80, X81, X82, X83, X84, X85, X86 |

### 5.5 Entry points and action order

- One filled action per screen (3.3). Precedence: (1) an unresolved decision that blocks the screen's task; (2) the screen's task action (Save, Confirm selected, Show results, Create account); (3) every other action in neutral or ghost style. A blocking decision owns the filled action until it is resolved; the task action is secondary until then.
- Inbox (X60). While a "needs a decision" item is unresolved, that decision's affirmative choice is the filled action and its other choice is secondary. Confirm is secondary while any decision is unresolved. When none remain, Confirm selected becomes the filled action; the confirm bar stays after the list in the scroll flow (DESIGN 6.6). An item sheet (X61) keeps its own Confirm as the item action.
- Add context. The tab bar Add follows 5.3. A screen that knows a narrower context overrides its tab default for its own Add:
  - Repeating (X34) and a repeating detail (X35): the schedule editor (C02).
  - A calendar day sheet (X51): a payment form dated to that day; the repeating choice inside the form is explicit and opens C02 only after that choice.
  - Home and the Spending root: the expense form. Wealth, Goals and Protect: the chooser with the context option first (5.3). Plan > Tax (v1.2): the repeating option first.
  - A screen without the tab bar has at most one header add action, with the same context rule. No screen shows two add controls.
- Long-press Add starts voice input in the payment form on every screen that shows the Add control, including Repeating. The override changes the tap only.
- Disabled entries. A feature that is not released, not available on the platform or not permitted is absent from navigation, the Add chooser, deep links and shortcuts. A direct link to an unavailable target returns to the nearest available parent with a factual status; it never enables the feature (shared contract 6).
- Search entry. Search sits below the Home title (X10) and in the Spending header (X30); All payments (X37) has its own search field. Search opens X15 and runs on this phone only. No other header carries a search control.
- Main number. Settings > Screens and widgets > Main number on Home (X13) chooses the hero number: Available until [date], Net worth (default), Spent this month, Cash you can use now. The choice replaces the hero number and its basis line. The net-worth target line, the 12-month change figure and the 12-month chart belong to net worth and appear only when net worth is the main number. The hero is not a widget: hide, reorder and add never change it (W1–W3).
- Glance order. The main number is first. Below it, the default layout follows 4.6: needs action, available money, this month, overall position, progress. A saved layout replaces that default order and keeps every card available (W4, W13).

## 6. Screen specifications

- Full text (sections 6.1–6.10): `SPEC_SCREENS.md`. Same section numbers and authority.

## 7. Design system "Obsidian"

Product rules only. DESIGN.md and DESIGN_REFERENCE win on style; values come from `lib/design/tokens/tokens.json`. Features use only DESIGN components and charts. Obsidian replaced Slabs (SPEC-SYNC-001).

### 7.1 Idea

Look, themes, glow (GLOW-001), flow glyphs and motion (MOTION-002): DESIGN 14.1, 12, 2.9, 2.11, 2.10.

- One hero number per screen, at most one chart.
- Section colour on chrome only. Data never uses section colours; chrome never uses data colours.
- Flow glyphs wherever a payment flow shows: ● spending, ◆ investing, ★ money in.
- Every chart: spoken label with main values, and "Show as table" (preview charts: label only, PREVIEW-CHART). A short key states size and colour meaning where not obvious.
- Obsidian Light is an equal designed theme. Both themes are golden-tested (16.2).
- Motion never counts up money, never animates money changes "since last open", and treats gain and loss the same. Reduce motion: final state at once.

### 7.2 Colour roles

Role names and values: DESIGN 2.2–2.4.

- Every text pair ≥ 4.5:1 in both themes (tested).
- Data palette: green = gain and money in; red = loss and spending; violet = investing; cyan = cash; categorical palette for categories (incl. Needs, Wants), asset classes, markets.
- Gain/loss colours only for signed values and flows.
- A new user category takes the next colour of a fixed palette. A category colour used as text passes 4.5:1.
- Colour is never the only signal (3.3).

### 7.3 Type

Fonts, sizes, weights, 200% scaling (hero ≥ 40 pt): DESIGN 2.5. At 200%, rows wrap, nothing is cut off, side-by-side tiles stack.

### 7.4 Shape, depth and spacing

Radii, spacing, shadows, minimum sizes (rows 54 pt, primary buttons 52 pt, other targets 44 pt), tab bar: DESIGN 2.6–2.9.

### 7.5 Components

Anatomy: DESIGN 6. Product rules:

- Hero period change: amount, then %.
- Payment row amount: + for money in.
- Empty type tile ("None recorded") opens Add: choose type. It is not an add control.

### 7.6 Charts

Chart types and frame rules: DESIGN 7. Product rules:

- Multi-line charts use one scale from $0. The label states the period basis (Wealth 1M = last 30 days).
- A bar above the scale has a break mark and a label.
- Bubble pack and Holdings treemap: area = value now, colour = period gain.
- Labelled donut: ≤ 8 parts; parts under 3% are listed, not labelled.

## 8. Data input

### 8.1 Input ladder

All sources feed the Inbox (voice and manual: the form). Use the highest available level.

| LEVEL | SOURCES | RELEASE |
|---|---|---|
| 1. Automatic (0 taps) | Repeating payments, vests, value methods, public symbols/prices/details; Android notifications (8.13), FinanceKit (8.14), watched folder (8.15) | v1: first four. v1.1: rest |
| 2. One tap (1–2) | Shared statement (PDF, CSV, Excel, bank formats), QR receipt, receipt photo, holdings screenshot; payslip, loan statement, policy | v1; last three v1.1 |
| 3. One sentence | Voice (8.10), quick add (8.3) | v1 |
| 4. Form (~3 taps) | Amount-first form, smart defaults | v1 |

### 8.2 Enter once, use everywhere

Store each fact once; link it everywhere.

| INPUT | FILLS |
|---|---|
| Bank/card statement | Balances, income, spending, transfers, repeating payments, cash flow, card balances |
| Payslip | Gross, net, deductions, tax withheld, pension, share purchase plan, benefits |
| Broker/share-plan statement | Holdings, transactions, dividends, fees, lots, shares from work |
| Loan statement | Amount left, interest, fees, EMIs, next payment |
| Policy document | Covered people or asset, cover, excess, premium schedule, renewal, policy number, nominee |
| Receipt, photo, voice | One payment, cash spending, shared or reimbursable purchase |
| Tax document | Tax-year income, tax withheld, filing data; checked against entries, never accepted blindly |

- A loan is one record, shown in What you owe, linked property, cash flow forecast and net worth.
- Net pay is matched to the salary deposit. Mismatch → Inbox.

### 8.3 Quick add

One line, on-device rules, no AI service.

- Grammar (any order): `[amount] [currency?] [words] [date words?] [#category?] [@account?]`.
- Amount: first number, locale separators. Currency: ISO code or symbol, either side.
- Dates: today, yesterday, weekday (most recent past), 12/10, 12 Oct, -2d. Category: #food or a rule match.
- Must pass: `lunch 180`, `180 lunch`, `taxi 340 yesterday`, `€12.50 coffee`, `coffee 12,50 EUR`, `rent 25000 #housing @bank`, `lunch 18 at subway`.
- Optional: platform on-device language model for hard sentences. Never a server.

### 8.4 Receipt photo (OCR)

- Camera or local image → verified on-device OCR (iOS Apple Vision; Android audited bundled engine from the foundation spike; engine policy 8.19). No telemetry, model download or cloud fallback.
- Read total (largest amount near total words, local language), date, merchant (first lines), currency. Outline read fields; tap another line to change one.
- Keep the image (encrypted) only if "Keep the receipt image" is on.

### 8.5 QR and barcode receipts

- Verified local decoder (iOS platform; Android audited bundled; engine policy 8.19). No network SDK or model download.
- Parsers: `canParse(payload)`, `parse(payload)`. v1: generic URL with amount/date parameters, EPC QR (SEPA), one national e-receipt. New parsers are data or plug-ins, never core changes.
- No match: offer the receipt photo.

### 8.6 Files and statements

- **CSV/Excel:** detect delimiter, encoding (UTF-8, UTF-16, Windows-1252), header row, date format, decimal mark. First import: mapping X67CsvMapping, saved as `ImportMappingTemplate` keyed by header signature (saved layouts below).
- **OFX/QFX, QIF, CAMT.053, MT940.**
- **Broker CSV:** map ticker, quantity, price, value, date, type. Presets are data files.
- **PDF statements:** on-device text (stored PDF password), table columns, `ParserTemplate` fingerprint. Match: import with no questions. No match: Teach once (X66TeachOnce): user taps date, details, amount (and sign words) of one row; app builds, previews and saves a template. Templates stay in encrypted storage; export disabled (10.5).
- **Payslip, loan, policy:** same PDF pipeline (`ParserTemplate.kind = payslip | loanStatement | policy`), Teach once, review (X69, X69b).
- After parsing, delete the temporary copy; keep parsed rows and file hash.

**Statement balance rows (G01).** A statement row is a payment, a credit or a balance; an opening balance, a closing balance and an available or limit line are balance rows, and only an opening or closing balance is an account observation. Balance rows are never Inbox items, never count as new rows and never write a payment; the preview keeps them apart from transaction rows, and Send to Inbox writes no anchor. An observation becomes an anchor only through its own explicit balance acceptance, one confirmed command that writes one `BalanceSnapshot` with the source account, the row's local calendar date, the account currency and the exact minor amount, and selects it. The date is inclusive: the amount is the account balance at the end of that date and already contains every posting dated on or before it, so the imported rows on or before that date stay as history and are never counted twice. A row dated on or before the selected anchor's date is already covered: it writes no new observation and the import re-adds nothing. A different amount for the selected anchor's date is a correction: a new observation with `supersedes_anchor_id` names the selected anchor and the pointer moves to it; the old row is never updated. A row later than the selected anchor is a new observation for its date. Only the account currency is accepted (10.5). With no balance row, or with no accepted observation, the account keeps its selected anchor or stays Missing; an imported row never writes zero.

**Saved layouts (G15).** One contract for X63, X65, X66 and X67. It adds no financial rule.

- **Identity.** A saved layout has one fingerprint for each format. The source account is a preview choice and is not part of identity.
  - CSV and Excel: the header signature. SHA-256, lower-case hex, of the header row cells after normalisation (a non-breaking space becomes a space, each run of whitespace becomes one space, the text is trimmed and case-folded), sorted in ascending byte order and joined with `U+001F`. Column order is not identity: the same headers in another order give the same signature, and the mapping applies by header name; a duplicated header name appears once for each occurrence. Delimiter, encoding, header row number, date order, decimal mark, sign convention and column mapping are not identity: X67 corrects them without a new signature.
  - PDF: the layout fingerprint. SHA-256, lower-case hex, of the normalised detected table header line, the x position of each word on that line in 10 pt bands, and the first page width in whole points. The word positions are the word anchors; with the page width and the column bands of the taught row they are the table geometry. A file with no detected header line uses the text `noheader` and the page width.
  - Never in a fingerprint: a row value, amount, date, merchant, account number, file name, file hash or file content. The file hash stays the duplicate check (8.9); it is not layout identity.
- **Mapping fields.** CSV and Excel: date column, details column, amount column or a money-out and a money-in column, optional balance column, sign convention (signed amount, a sign column, or DR/CR words), decimal mark, date order, encoding and delimiter. PDF: date band, details band, amount band, optional balance band, money-out and money-in sign words, decimal mark and date order. A balance column or band marks balance rows; those rows stay out of staging (P3-05).
- **When a layout may be saved.** Only after a usable preview: at least one candidate row with a date and an amount, and no unresolved password, decryption or parser failure. For a new layout, Save writes the template first, then the preview can be sent. A cancelled, failed or empty preview writes no template and no batch. Re-teaching a known fingerprint writes a newer template row; the newest row for a fingerprint is applied and the older row is kept for the batches that used it.
- **Version and unsupported state.** A template version starts at 1 and names its mapping semantics: the fingerprint input, the column or band meanings and the row rules. A parser change that alters any of them increments the version; a stored row keeps the version it was written with. A stored template whose version the installed parser does not serve is unsupported. It is never reinterpreted or migrated: the next file with that fingerprint opens X66 Teach once (PDF) or X67CsvMapping (CSV/Excel), and X65 shows no match. Teaching the layout again inserts a newer row. Each batch records the parser and template versions it used.
- **Storage.** Saved layouts use `import_parse_configs`: append-only and immutable by trigger, with `parser_id` `pdf-template` or `csv-mapping`, the template version in `config_version`, and the fingerprint inside `config_json`. Other rows in that table describe one import and are not saved layouts. `ImportMappingTemplate` and `ParserTemplate` (SPEC 9) are logical entities over this table, not new tables (P3-TEMPLATE-TABLE). A dedicated table is a later, reviewed migration.

**Import withdrawal (G16).** "Undo this import" on X68 withdraws one import batch before any of its items is confirmed.

- **Scope.** It removes the remaining staged rows and Inbox items of that batch, sets the batch to `discarded`, marks its staged source claims `discarded`, keeps the publication marker as evidence and keeps the source identities reserved. It does not touch a confirmed payment, another batch, the parse configuration, the saved layout or a balance observation.
- **Boundary.** It is allowed only while no item of the batch is confirmed. A deleted Inbox item does not block it: its claim is already `discarded` and its staged row is gone. After one confirmation, the whole batch is not withdrawable: the command refuses and writes nothing. That payment is removed by its own Undo or its confirmed batch Undo (8.18).
- **Counts and revisions.** One transaction removes the remaining undecided items, lowers the pending Inbox count by the number of pending items it removes and advances `inbox_revision` once. No balance, spending total or net worth changes. A partial withdrawal is not possible. A repeated withdrawal is refused with the withdrawn state and writes nothing.
- **Not Undo.** It is a staging action, not a financial command: no operation receipt, no ChangeLog, no compensating posting and no Activity history entry. A confirmed batch is reversed only by the 8.18 Undo, which writes compensating records and appears in Activity history (F07-D).
- **States.** X68 offers the action while the batch has at least one pending item and no confirmed item; after one confirmation it is absent and the confirmed items use Activity history. A withdrawn batch leaves the X63 history list and its Inbox rows; the batch row and claims stay stored as evidence. A restart after the commit does not restore the rows (F06-C).
- **Recovery.** A lost reply resolves the same batch; the owner reads its status before a retry. A proven rollback leaves the batch and its rows unchanged.

### 8.7 Screenshot of holdings

- On-device OCR finds rows with ticker, quantity, value. Show only differences from holdings (X45UpdatePositions).

### 8.8 Share into the app

- **Entry.** The iOS share extension (iOS 16+) and the Android share intent and file-open intent (Android 8.0+). One file per share; a multi-item share is refused. Intake works while the app is locked, but only while the device is unlocked (protection below); an app lock does not block intake.
- **Types.** One list for iOS and Android. The first bytes and a successful decode decide the type; the file name and the declared type are hints. A file outside the list is refused before any byte is staged. iOS maps its uniform type identifiers and Android its MIME types to this list.

| Group | Extensions | Read as |
|---|---|---|
| Data | `.csv`, `.tsv`, `.txt` | delimited text, plain text or MT940 |
| Data | `.ofx`, `.qfx`, `.qif` | bank exchange text |
| Data | `.xml` | XML, including CAMT.053 |
| Document | `.pdf` | PDF |
| Sheet | `.xls` | OLE2 workbook |
| Sheet | `.xlsx` | ZIP workbook |
| Image | `.jpg`, `.jpeg`, `.png`, `.heic`, `.heif`, `.webp` | local image |

An archive, a folder, an alias or shortcut, a link and an executable are not in the list.

- **Bound.** One file of at most 100 MiB encoded, the same on both platforms. This is the largest parser limit (SYSTEM_DESIGN 10), so one check runs before staging. A type with a smaller limit keeps it after intake: PDF 50 MiB and 500 pages, image 20 MiB encoded and 12 megapixels decoded, XLSX 50 MiB encoded and 250 MiB expanded. The parser reports its own limit in a factual message.
- **Staging object.** The extension writes the exact received bytes once to one new opaque staging object and never appends, truncates or rewrites it. The bytes are encrypted with the object key. The name is 16–128 characters of `A-Z`, `a-z`, `0-9`, `_` and `-`, with no user text. The extension also writes an authenticated descriptor of at most 4 KiB: display name (at most 255 characters), format hint, byte count, SHA-256 digest, creation time, install epoch and a lease reference. The descriptor holds no financial value, account, category, parsed row or key. The extension writes no database row and no `import_sources` row; the app creates those after unlock and stamps its own database epoch.
- **Protection.** iOS: complete file protection (`NSFileProtectionComplete`). Android: credential-encrypted, app-private storage. The staging object and its descriptor are excluded from OS backup and device transfer. No temporary plaintext copy and no external storage. Bytes are accepted only while the device is unlocked and that class is available; if the write cannot get it, nothing is kept.
- **Staging key.** Each object has its own random 256-bit key, wrapped by the platform key store and independent of the ledger key and the recovery keys. The extension holds a staging capability and an epoch-scoped writer lease, never the database key, the ledger or a financial DTO (SYSTEM_DESIGN 10; DATABASE_DESIGN 10). The descriptor holds the key reference (`staging_key_reference`), never the key.
- **Lifetime.** The object and its key live until the app parses the file, the user discards the import, the install epoch rotates or a restore replaces the database epoch; then both are deleted. There is no wall-clock expiry. An object with no descriptor or no live lease is an orphan: it is deleted at the next unlocked start after reconciliation, never while a lease is live or unknown. A recovery snapshot omits the object and its key; a restore marks the batch `sourceNeeded`.
- **Refusal and retry.** A refused share stages no bytes and creates no batch or Inbox row:

| Condition | Message |
|---|---|
| Type not in the list | "This app cannot read this file type." |
| Over 100 MiB | "This file is <size>. The largest file this app can read is 100 MB." |
| More than one file | "Share one file at a time." |
| A link, not a file | "This is a link. This app reads files, not links." |
| Content not on this phone | "This file is not on this phone yet. Share it again when it is." |
| Protection or staging failure | "The file could not be saved on this phone. Share it again." |
| No free space | "The file could not be saved on this phone. Free some space and share it again." |

`<size>` is the formatted encoded size. No message contains a file name, path, amount or content. Retry is a new share of the same file, which makes a new object; nothing is queued, retried in the background or downloaded. The intake never resolves a URL, starts a cloud download, opens an iCloud or Drive placeholder, or asks a provider for bytes that are not already local. An iCloud item whose download status is not current is refused with the "not on this phone" message.

- **Logs.** The intake path logs an event name and a count only. No file name, path, amount, account, merchant, digest or content enters a log, an error or a crash field; an error carries a safe code.
- The app parses only after unlock and only from the staging object, then deletes the object. F06-A: a normal, localised, broken or repeated file takes the same intake path; a refused or broken file stages nothing. F06-D: no source content is logged, and no raw file is kept after parsing.

### 8.9 Duplicates, merchants, categories, repeating items

- `dedupeHash = SHA-256(accountId, date, amountMinor, currency, normalised merchant)`; investments: (accountId, securityId, date, type, quantity).
- Near duplicate (same amount and currency, ±2 days, merchant similarity ≥ 0.8) → Inbox "Same purchase twice?". File hash seen before → ask first.
- Merchant normalisation: upper case; strip card and store numbers, dates, network words, extra spaces; show a clean name ("WHOLEFDS MKT 10231" → "Whole Foods").
- Category order: user rules (priority), learned rules, default keyword rules, none. After 2 changes for one merchant, offer a rule once.
- Generate repeating items and vests on start and daily where the OS allows. Generation never writes an actual payment: an occurrence stays Expected until a confirmation or an accepted match (8.17). `autoCreate = false` routes the proposal to the Inbox.
- Same merchant, amount ±10%, 3+ months → Inbox "Add as repeating?".
- **Price changes:** a different repeating amount is recorded and shown ("Netflix $15.49 to $17.99") in needs-attention facts and on the item.

### 8.10 Voice input

- **On device only** (8.19). iOS: `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` or the newer on-device API. Android 12+: check availability, then `SpeechRecognizer.createOnDeviceSpeechRecognizer`; the offline preference flag is not enough. Other devices: typed entry unless an audited bundled engine exists.
- Unavailable: "Voice input is not available on this device for [language]. You can type instead." No server fallback.
- Audio never saved; transcript kept only until Save or Cancel. Ask permission at first Speak tap, after explainer X87.
- **Parsing =** quick add parser plus: spoken numbers ("forty", "twelve fifty", "1.2k"); currency words ("dollars", "bucks", "euros", "rupees"); merchant after "at"/"from" (fuzzy match); category after "for"/"on"; dates ("last Friday", "two days ago"); account after "with", "using", "on my"; "got", "received", "salary" → Income.
- One payment per sentence. Second amount: after Save, "1 more amount found. Add it next?". No amount: keypad stays active; never guess.
- Output: `ExpenseDraft` with per-field confidence. Never writes to the database.

| TEST SENTENCE (MUST PASS) | AMOUNT | CURRENCY | MERCHANT | CATEGORY | DATE |
|---|---|---|---|---|---|
| Spent 40$ for food today at Starbucks | 40.00 | USD | Starbucks | Food | today |
| Spent forty dollars on food at star bucks | 40.00 | USD | Starbucks | Food | today |
| Paid twelve fifty for parking yesterday | 12.50 | default | — | Parking | yesterday |
| Taxi 340 with cash | 340.00 | main | — | Transport (rule) | today |
| Bought groceries at Tesco for 1.2k last Friday | 1,200.00 | main | Tesco | Groceries | last Friday |
| 40 at Starbucks and 12 for parking | 40.00, then 12.00 | main | Starbucks / — | rule / Parking | today |
| Coffee 4 euros 50 using my Visa | 4.50 | EUR | — | Coffee | today |
| Got 500 salary bonus | 500.00 | main | — | Income | today |
| Lunch at Subway | empty, keypad active | — | Subway | rule | today |

### 8.11 Manual entry

Every record can be added and edited by hand; this is the fallback for everything.

### 8.12 Local input from mail apps

- No IMAP, Graph, Gmail, Google Drive or Apps Script connector; no email credentials or uploads.
- An already local attachment uses the normal import path. No remote download; no links opened.
- Notification text: 8.13. Raw message text is not kept.
- X82GmailBridge is obsolete and unshipped: no route, no feature switch.

### 8.13 Android payment notifications (v1.1, optional)

- With Notification access, read only user-selected apps; parse with templates. Never store full text. Never request SMS permission.

### 8.14 iPhone FinanceKit (v1.1, where available)

- After permission, read Wallet-connected accounts on device. Needs Apple's entitlement; hide where unavailable.

### 8.15 Watched folder (v1.1, optional)

- Watch only an app-owned local staging folder, never cloud or document-provider folders. New PDF/CSV bytes enter the Inbox when the unlocked app opens.

### 8.16 Drafts

- A draft keeps the structured inputs of one form. It survives Back, Close, lock, background and process death, so no typed work is lost. It holds no audio, transcript, raw file bytes, file name, PDF password, email text or attachment content; a "filled from your voice" or "please check" marker on a field is a draft state, not source text (8.10, 10.5; F04).
- Identity. Each draft has its own ID, a form type, a schema version and the revisions of the records it references. The form type names the editor: payment, transfer, account, scheduled payment, category or rule, and later editors by the same rule. Drafts never share an ID and none replaces another.
- Opening a form. A form with a kept draft of its type offers that draft, most recent first. The draft selector (C11) lists every kept draft and resumes the selected one. A new draft starts only by explicit choice; a capture path never replaces a kept draft silently. On resume the referenced records are checked again: a record that no longer exists shows its factual state and its field asks again (F03 recovery).
- Fields kept. Only the form's editable inputs. Derived facts, outcomes and imported source rows are never draft fields.

| EDITOR | DRAFT FIELDS |
|---|---|
| Payment (X20, X25) | type (expense or income), amount, currency, date, account, category, tags, note, merchant text, split parts, check markers |
| Transfer (X26) | From, To, amount, date, fee |
| Account (C01) | name, type, currency, institution, isLiability, isLiquid, includeInNetWorth, ownership percent, minimum balance, overdraft limit, colour, opening balance and its date |
| Scheduled payment (C02) | name, kind, amount, currency, account, category, recurrence, start and end date, auto-create, autopay, trial end, renewal date, cancellation address |
| Category or rule (C03) | name, parent, kind, colour, icon, isEssential; for a rule the match type, pattern, category, priority and origin |

- Durability. The editor writes the draft when a field value is committed: a field loses focus, a sheet returns Done, or amount entry ends (keypad dismissed or another field takes focus). It also writes before the app leaves the foreground or locks. A keystroke or keypad digit still inside the editor is not a separate write. After the last write, process death keeps the draft.
- Back and Close keep the draft and show "Draft kept". Back from a child sheet keeps the parent draft and drops only that sheet's edits. An explicit Discard deletes the payload and any temporary attachment material, writes no financial record, and returns to the caller unchanged.
- Save. Save validates the current values and the referenced records. A validation failure keeps the editable draft and writes nothing. A submission freezes the payload, its digest and the expected record revisions with one operation ID, and marks the draft submitted; repeat taps return the same operation. The commit deletes the payload and temporary material in the same transaction and marks the draft committed with its operation ID. A proven rollback returns it to editing, and the next Save uses a new operation ID. An unknown outcome stays submitted until the original operation ID is resolved through its receipt (SYSTEM_DESIGN 6; DATABASE_DESIGN 6).
- No expiry. A draft stays until Save commits or the user discards it. Age, count and background time never remove it.
- Bounds. One payload stays within the schema bound (256 KiB). A larger payload is a validation failure next to the affected field: nothing is written and the editor stays open.
- App and schema versions. A draft carries the schema version of its form. After an upgrade it migrates to the current form schema, or it keeps its payload and shows its unsupported state with Discard only (DATABASE_DESIGN 10).
- Lock, background and restore. Lock and background keep the draft, stop capture hardware and clear the transcript (F04). A restore invalidates drafts of the old database generation; they are not offered (SYSTEM_DESIGN 5.2, 13.2).
- Delete all data removes drafts with the rest of the records (11).
- Draft values are personal data. They never appear in a log, an error message or a diagnostic (2, 10.5).

### 8.17 Occurrences, matching and confirmation

- Terms. An Expected occurrence is a dated payment that a rule or a user expects. A match candidate is a staged record that may be the same payment as an existing one. A decision is the user's explicit choice about a candidate or an occurrence. An obligation is the amount expected on a date with one stable identity; a settlement is an accepted payment applied to it (DATABASE_DESIGN 4.3).
- Source identity. Every incoming record carries a stable source identity: namespace, account scope and source row identity. A repeat of a known identity returns its staged, accepted or tombstoned result; it never creates a second payment or a second Inbox item. A content fingerprint (8.9) is a candidate, never proof (DATABASE_DESIGN 6).
- Candidates. Equal content, a near duplicate (same amount and currency, ±2 days, merchant similarity 0.8 or more) or a possible transfer pair is a candidate. The app never merges, links or deletes on similarity alone. An undecided candidate stays unticked, and its affected items wait (F07-A).
- Linked pairs. A transfer pair links two confirmed postings once. A confirmation reuses an existing confirmed posting, never copies an existing pair, and leaves an uncertain counterpart unresolved (F05-B).
- One proposal per occurrence. A schedule produces one Expected occurrence per slot, with `(schedule_id, occurrence_key)` as its identity. A due occurrence appears at most once in the Inbox. Re-running the generator, reopening the app or a retry never adds a second proposal (F09-A).
- Generation is never an actual. The generator writes Expected proposals only. A payment becomes actual by an explicit confirmation of the occurrence or by accepting a matching payment. No rule, timer or background job creates a confirmed payment (DATABASE_DESIGN 4.3).
- Review path. The schedule option "Add it to the Inbox to confirm" chooses where a due proposal waits: in the Inbox, or as a ready proposal with one confirm action on its own detail. Both routes use the same confirmation command and the same checks. No setting creates an actual payment without a confirmation, so the earlier caption "Off: added automatically" does not apply.
- Unpaid remainder. A confirmed payment settles the obligation once. Unpaid = obligation − accepted settlements (1,240 − 500 = 740); the forecast and "due before next income" read the unpaid amount and never subtract the original again (F05-C). A partial payment keeps the occurrence open with its remainder.
- Over-payment. A settlement never exceeds the remaining obligation. A larger payment keeps its unallocated part; no remainder becomes zero silently. A cross-currency settlement stays unavailable until conversion evidence is defined (v1.1).
- Decisions. Accept, edit, skip, match and cancel each append an explicit, dated decision. Each is one action. A decision is durable; an undo adds a compensating decision and keeps the occurrence identity.
- Rule edits. A changed rule keeps every occurrence identity: unchanged slots keep their proposal, changed slots need a review before submission, and matched, confirmed or partly settled occurrences keep their identity and settlements. Amount or date similarity never proves an unchanged slot.
- One obligation, many aliases. A card statement, a recurring rule and a one-off entry can point to one obligation. The forecast, the calendar and "due before next income" read it once, and a statement payment reduces cash and the statement remainder once (F05-C).
- One-off future payments. A dated payment that happens once is created with recurrence off and keeps its own obligation identity. It is not a rule with one occurrence, it never generates a second occurrence, and it stays Expected until a confirmation or an accepted match.
- Price changes. A different actual amount records a dated price change ("was $15.49"). Editing an estimate never rewrites an earlier actual payment (8.9).
- Confirmation is atomic. A confirmation writes the payment, its links, its decisions and the ChangeLog in one transaction. A repeated confirmation returns the first result (F07-D); if one selected row fails, nothing is accepted (F07-C).
- Expected is never in a total. Until confirmation, an occurrence changes no balance, no spending total and no net worth (4.3, 4.9).

### 8.18 Undo and activity history

- Scope. Undo reverses one confirmed financial event or one confirmed batch: a payment (create, edit or delete), a transfer with its fee, a split change, a confirmed occurrence decision or a settlement, and an Inbox confirmation batch. A settings, layout, category or rule change is corrected by editing it again; Activity history lists it as a change, but Undo does not reverse it.
- Undo is a new command. It has its own operation ID and receipt, writes compensating records and a ChangeLog entry, and never rewrites an old row or replays stored JSON. An edit is undone by restoring the earlier values as a new revision. The original record keeps its identity.
- Whole event or batch. One command reverses every effect of the event or batch: linked postings, splits, tags, attachments, decisions and settlements. A batch is never partly undone.
- Toast. After a commit the app shows one toast that names the event and offers one Undo for 5 seconds (DESIGN 6.6). The toast appears only after a confirmed write; a failed or unconfirmed write shows neither success nor Undo. After it closes, the same action stays in Activity history.
- History access. Settings > App > Activity history (C06) lists confirmed events and batches, newest first: what happened, when, the affected records and the state (reversible, reversed, blocked). One entry opens its records and the one action its state allows. History is local and holds no raw source text.
- No age limit in history. The 5 seconds apply to the toast only. An entry stays while its records exist, and a reversed entry keeps its place next to its compensating record.
- Dependencies. If a later authoritative record depends on the target (a settlement, an allocation, a saved close or a later edit), Undo does not proceed and writes nothing. The entry opens the dependency sheet, which names each blocking record and its reason. The user opens that record, resolves it with its own controls, and starts Undo again, or cancels. Undo never edits or deletes a dependent record on the user's behalf, and it never overwrites a newer value.
- Identities. Undo keeps source identities reserved and keeps soft-deleted records as history. A repeated Undo of the same event returns the first result and writes nothing new.
- Occurrences. Undoing a confirmed occurrence decision adds a compensating decision and keeps the occurrence identity; it never reopens a suppressed proposal by dropping a pointer (8.17).
- Attachment files. A soft-deleted record keeps the files that Undo, history and recovery need; explicit deletion removes them after those references go (DATABASE_DESIGN 10).
- Editor Undo is separate. The widget editor's Undo reverses one edit-session action before Done and writes nothing (W5; DATABASE_DESIGN 5.1). It is not an entry in Activity history.
- Staging is not Undo. "Undo this import" (X68) withdraws the staged rows and Inbox items of one unconfirmed batch, changes no financial record and writes no ChangeLog, receipt or Activity history entry; a batch with one confirmed item is not withdrawable (8.6).
- Privacy. Activity history is personal data on this phone. It never appears in a log, an error message or a network request.

### 8.19 Local capture engines

- Rule. Speech, text recognition, QR and barcode decoding, and any later capture engine, run on the phone. No engine sends audio, images, text, identifiers or metrics to a server, downloads a model at run time, or falls back to a remote service.
- Verified engine. An engine counts as verified only when all of these hold:
  - it exposes an on-device mode and the app uses that mode;
  - it works with every network interface off, on each supported OS version, in a recorded test;
  - its telemetry or metrics are off or absent; an SDK that cannot disable them is rejected;
  - its dependency passes the licence and release rules and its network statement is in `docs/DECISIONS.md`;
  - availability is checked by an explicit API, never by a user preference flag alone.
- Named engines. iOS speech uses `SFSpeechRecognizer` with on-device recognition. Android 12+ speech uses the on-device `SpeechRecognizer` after its availability check; Android 8–11 keeps typed entry unless an audited bundled engine is verified. Text recognition uses Apple Vision on iOS and an audited bundled engine on Android. QR and barcode use the platform decoder on iOS and an audited bundled decoder on Android. ML Kit is excluded because its terms include network metrics (SYSTEM_DESIGN 10).
- Unavailable. When the engine or the language is unavailable, the app says so in one sentence and keeps typed or file entry: "Voice input is not available on this device for [language]. You can type instead." It does not retry in the background, does not prompt again and does not use a server.
- Permission. The explainer (X87) comes before the OS prompt and only on the first use. A denial keeps manual entry; Settings may offer the permission again. No automatic prompt after a denial.
- Data. Audio is never saved. The transcript is held only until Save, Cancel, leaving the capture, background or lock. Images are deleted after parsing unless the user keeps the receipt image. An engine receives only the capture content, never account names, balances or other records.
- Output. Recognition fills draft fields with a check marker per field. An uncertain field stays editable and is marked. Low confidence never invents a value: no amount leaves the keypad active, and no category is guessed.
- Feature availability. A capture source that needs an unavailable engine is absent or shown as unavailable in Settings. It never blocks the manual form.
- Evidence per engine. The task that adds an engine records its name and version, its availability check, the network-off test log, its telemetry statement and its dependency entry. Without these, the engine does not ship.
- No degraded mode. An engine that cannot meet these conditions is removed, not replaced by a remote call.

## 9. Data model

- Full text (sections 9.1–9.9): `SPEC_DATA_MODEL.md`. Same section numbers and authority.

## 10. Platforms, stack and architecture

### 10.1 Platforms

- v1: iOS 16+, Android 8.0+ (API 26+), phones only.
- PF-01 (SYSTEM_DESIGN 12.2) blocks real-user iOS persistence and release until the no-OS-copy rule has a compliant path. Exclusion flags or undecryptable copies do not resolve it.

### 10.2 Stack

| AREA | CHOICE |
|---|---|
| Framework | Flutter stable, Dart, null safety |
| State / navigation | Riverpod / go_router |
| Database | Drift over a pinned SQLCipher native build via FFI; verify release linkage at foundation. Not obsolete `sqlcipher_flutter_libs`; no silent cipher swap |
| Secure storage / lock | flutter_secure_storage (Keychain, Keystore) / local_auth |
| Speech | speech_to_text, on-device forced; small native plug-in for newest APIs |
| OCR, barcode, QR | Local adapters (Apple Vision; audited bundled Android engine and decoder); verified local models only; no telemetry or remote fallback |
| Camera, files | camera, on-device document scanner; audited inbound file and share adapters; no outgoing share or export |
| CSV, Excel, PDF | csv, excel, on-device PDF text (e.g. pdfrx); check licences |
| Charts, fonts | CustomPainter only (7.6); Inter Display and Inter, bundled (OB-FONT, POLISH-001) |
| Localisation | intl, gen-l10n; English only in v1 |
| Recovery crypto | Audited authenticated encryption, same device; binding verified in foundation spike |
| Widgets, shortcuts | iOS WidgetKit, App Intents; Android Glance, App Shortcuts, Quick Settings tile; shared via app group or file |
| Email networking | Not permitted |
| Tests | flutter_test, golden_toolkit, integration_test |

### 10.3 Layers

- UI: screens, widgets; no business logic.
- Application: Riverpod providers, controllers.
- Domain: pure Dart entities, money maths, calculators, parsers, rules, forecasts, attribution; no Flutter; 100% unit tested.
- Data: drift, repositories, backup, price providers, capture.
- Platform: OCR, barcode, camera, files, biometrics, speech, notification access, widgets, shortcuts.

Module contracts: SYSTEM_DESIGN 3.

### 10.4 Folder structure

Top level: AGENTS.md 3.

- `lib/domain/: entities/, numbers/ (section 4), forecast/, calculators/, importers/ (csv, excel, ofx, qif, camt053, mt940, pdf, payslip, loan, policy, ocr_text, qr/), rules/ (category, repeating, vests, transfer and refund matching).`
- `lib/data/: db/ (tables, DAOs, migrations), repositories/, prices/, capture/ (notifications/, financekit/, local_folder/), backup/.`
- `lib/features/: home, inbox, add, imports, spending, budget, repeating, wealth, accounts, investments, holding, allocation, gains, dividends, returns, owe, plan, calendar, cashflow, goals, protect, tax, tools, month_close, settings.`
- `native/ios/ (WidgetKit, App Intents, share extension); native/android/ (Glance, shortcuts, tile, notification listener).`

### 10.5 Network policy

Gateway contract, fixed provider routes, redirects, logo limits, cancel behaviour and tests: SYSTEM_DESIGN 11.

- No network by default. Only an enabled public-data provider fetches public catalogues, prices and history, instrument details, logos and approved public assets.
- One gateway in `lib/data/prices/` takes only typed public requests. No arbitrary URL or generic request object.
- Never send balances, quantities, holdings, account names, personal search text, transaction dates, files, transcripts, database IDs or device identifiers. The provider sees connection metadata and requested public IDs; this is not anonymous.
- FX: manual or local import only; remote FX needs an explicit policy change. Benchmarks use the symbol and price contract.
- Forbidden: email, upload, cloud OCR or speech, analytics, crash service, remote fonts, telemetry, remote config, cloud backup, external export, sync, any Contour server.
- Public logos and assets: ARCH-REQ-002. Each asset class needs an audited typed request, licence, bounded decoder, local cache. No active content. The network switch covers assets.
- Network off stops future requests and cancels pending ones where possible; it cannot retract sent bytes.
- Enforce with dependency and import checks, native binary review and device traffic tests, not a Dart lint alone.

### 10.6 Future platforms: tablets, Mac and Windows (v2)

Same code base on iPad, Android tablets, macOS, Windows. v1 must not block this.

| FEATURE (BEHIND AN INTERFACE IN LIB/DATA/ OR LIB/APP/) | IPHONE / ANDROID | MAC | WINDOWS |
|---|---|---|---|
| Encrypted database | SQLCipher | SQLCipher | SQLCipher build (verify before v2) |
| Secure key storage | Keychain / Keystore | Keychain | Credential Manager (DPAPI) |
| App lock | Face ID, fingerprint, passcode | Touch ID, password | Windows Hello |
| Text recognition | Verified local adapters | Apple Vision | Windows.Media.Ocr (verify local-only) |
| Voice input | On-device speech | On-device speech | On-device speech (verify) |
| Share into the app | Share extension / intent | Drag and drop, "Open with", Services | Drag and drop, "Open with" |
| QR, notification capture, FinanceKit | Yes, where available | No | No |
| Widgets | WidgetKit, Glance | WidgetKit | Not planned |

- **Device isolation:** independent local data per install. No cloud-folder, LAN or backup-file transfer; encryption is no exception. Any transfer feature needs a product and privacy revision first.
- **v1 rules:** pure-Dart domain and core; platform features behind interfaces, none in `lib/domain/`, `lib/core/`, `lib/features/`; templates adapt to window size class (DESIGN 13), features never check platform or width; confirmed mutations go through repositories that atomically write ChangeLog and revisions (maintenance: SYSTEM_DESIGN 5.2); keyboard and pointer everywhere.

## 11. Security and privacy

Key lifecycle, lock and delete steps: SYSTEM_DESIGN 12.

| AREA | RULE |
|---|---|
| Database | SQLCipher; random 256-bit key material under device-bound Keychain/Keystore; data key in memory while unlocked |
| App lock | Biometrics or passcode on open and after timeout: immediately, 1 min (default), 5 min, off |
| App switcher | Blur in background |
| Screenshots | Allowed; Android setting blocks (FLAG_SECURE) |
| Imported files | Delete the app copy after parsing; keep rows and hash |
| Images | Deleted after parsing unless "Keep the receipt image" is on (then encrypted) |
| Clipboard | Read only on "Paste" |
| Widgets, intents | Launch-only; no snapshots, text arguments or OS search donation (15) |
| Emergency sheet | Local preview; no credentials, no export (10.5) |
| System copies | Exclude database, WAL, staging, attachment, recovery and app-group paths from OS/cloud backup and device transfer; keys never sync. Verify on real devices before release |
| Delete all data | After confirm: remove active, staged and recovery generations, attachments, keys, templates, cached prices, secure-storage entries |

## 12. Symbols, prices and instrument details

Request contract and fetch lifecycle: SYSTEM_DESIGN 11.

- MarketDataGateway (local): catalogue and search by validated public ID, latest prices, fixed-range history, text instrument details. All providers share one restricted contract.
- Off by default. Provider credentials: secure storage, sent only to that provider when needed. No backend proxy for a shared key.
- Catalogue search runs on the phone. History uses standard public windows, never purchase dates. Batches hold only public IDs; padding is not anonymity.
- Cache quotes and metadata encrypted, with provider, timestamp, currency, precision, raw/adjusted basis. Never replace a known quote with zero after a failure.
- Market status: public data or a bundled calendar. Never follow metadata URLs or fetch active content. Logos: typed asset request only (10.5).
- Manual price and FX entry and local CSV import stay available. Missing rate → dependent totals Missing; older supported rate → Estimated (4.1).
- One audited provider first. Verify terms, licence, coverage, rate limits and total-return/history basis before enabling.

## 13. Calculators and formulas

- Full text (sections 13.1–13.16): `SPEC_CALCULATIONS.md`. Same section numbers and authority.

## 14. Same device recovery

- Snapshots stay encrypted in protected app-private storage. Exclude them from OS backup, cloud storage and device transfer. No folder chooser, outgoing share or export.
- Keep up to eight completed weekly snapshots within explicit storage limits. A completed month close can request one more. Background execution is best effort; finish after unlock when resources permit. Show the last completed snapshot date.
- Capture a consistent database state and its retained-attachment manifest. Use authenticated encryption and a device-bound recovery key independent of database rekey.
- Keep at least one prior verified snapshot until its replacement passes validation. If space is short, stop and keep that snapshot.
- Restore only a validated local snapshot, after confirmation. Install a complete staged database and attachment generation. Keep the previous generation until the restored state opens. Invalidate pending jobs and stale drafts. No row-wise timestamp merge.
- A snapshot cannot recover a lost phone, an uninstalled app or unavailable device keys (no-transfer policy).
- SYSTEM_DESIGN defines crash boundaries, key handling and retention. Never copy an active database file without a consistent SQLite backup/checkpoint procedure.

## 15. Widgets and shortcuts

- Launch-only controls open an allowed route behind app unlock.
- No financial text, amounts, summaries or spoken sentences pass through Siri, OS search or shortcut services.
- Widgets hold generic launch actions only. Financial snapshots are deferred (platform widget features can relay them to other devices).
- Voice capture starts only inside the unlocked app, after the user selects Speak and the local engine is available. A shortcut never restarts the microphone.
- No private record goes to Spotlight, a widget timeline, the clipboard or an outbound intent.

## 16. Quality and tests

### 16.1 Unit tests

- Calculators (section 13 values), money maths, rounding, currency conversion, largest-remainder percentages, every section 4 definition with Appendix A data, cash flow forecast, attribution adding up, quick add and voice parsers, every importer with `test/fixtures/` files, dedupe, transfer and refund matching, category rules, repeating generation and price changes, vest events, realised gains, TWR and XIRR, backup encrypt and decrypt.

### 16.2 Golden tests

- Every final screen (section 6), Obsidian Light and dark, font scale 1.0 and 2.0, Appendix A data.
- Reference for both themes at scale 1.0: Obsidian figures in `contour-design.html`. Slabs-look screenshots are not a style reference.

### 16.3 Automated interface checks (every golden screen)

| CHECK | RULE |
|---|---|
| Banned words | should, recommend, too much, risky, safe (as advice), on track, behind, good, bad, great, sell, buy, warning. "Sold" in history is allowed. |
| Text size | No text under 13 pt. Exceptions: tab labels 12, chart axis labels 11. |
| Touch targets | Every tappable element at least 44 x 44 pt. |
| One control row | Per screen (forms excluded). |
| One add control | Per screen. |
| Contrast | Every text and background pair at least 4.5:1. |
| Percentages | Any split adds up to 100. |
| Unknown is not zero | A missing-data fixture shows "None recorded" or "Missing", never "$0". |

### 16.4 Integration tests

- Onboarding; add expense (3 taps); voice expense in airplane mode; quick add; CSV import with mapping; PDF with Teach once and the second month without questions; Inbox confirm with the ticked total; transfer detection; vest confirm; monthly close; same-device recovery; interrupted restore; OS-backup exclusion.

### 16.5 Performance

- Baseline acceptance targets (not measurements): cold start under 1.5 s with 50,000 payments; 60 fps scrolling; local staging of 5,000 CSV rows under 3 s; ten-year forecast and return queries under 300 ms with current maintained projections.
- Measure fresh calculation and cold full rebuild apart from warm projection queries. A first request must not meet the query target by returning stale data. Confirm commits have a separate durability budget.
- `docs/architecture/PERFORMANCE_PLAN.md` defines devices, dataset tiers, p95 budgets, memory bounds, import/confirm phases and failure tests. Its large and stress tiers extend the baseline.

### 16.6 Accessibility

- Screen-reader labels on all charts and controls. "Show as table" on every chart except preview charts (PREVIEW-CHART). Dynamic type to 200%. Respect reduce motion. Focus order follows visual order.
- With amounts hidden, no amount shows in text, tables or spoken labels. Charts keep their shape without text (4.9).
- Sideways regions (Quick look, Next 30 days) are focusable and scroll with the arrow keys.

### 16.7 Sample data mode

- A setting loads the Appendix A data set, marked "Sample data", for screenshots, golden tests and user tests.

## 17. Releases, phases and acceptance

Every phase also passes the usability checks (3.4) and automated checks (16.3).

### 17.1 Release v1 — the core

**Phase 1 — Base**

- Project, folders, Riverpod, go_router, tokens, fonts, light and dark themes.
- Encrypted database (v1 tables), migrations, repositories, ChangeLog.
- App lock, background blur, Welcome (X01), first-run Home (X03), Settings skeleton, Privacy and network (X86).
- Component and chart gallery (debug builds). Network policy test.
- **Accept when:** app opens with the lock on both platforms; components render in light and dark; database cannot open without the key; unit tests pass.

**Phase 2 — Capture, Inbox and Spending**

- Add expense, income, transfer (X20–X26); quick add; voice (X24, X25); categories and rules; repeating payments with price changes (X34, X35); Inbox (X60–X62).
- Spending (one page), Where it goes, Money in, Budget, Edit limits, Category detail, All payments, Payment detail (X30–X39b); accuracy rules (4.2); undo; hide amounts.
- **Accept when:** 3.1 input targets pass; voice test sentences pass in airplane mode; transfer, refund and reimbursement fixtures give the expected totals; nothing from voice is saved before Save.

**Phase 3 — One-tap imports**

- Share into the app; CSV and Excel with mapping; OFX, QIF, CAMT.053, MT940; PDF with passwords and Teach once; QR receipts; receipt photo; holdings screenshot; cross-source merge; batch undo (X27, X28, X63–X68, X88, X45).
- **Accept when:** fixture files import with expected rows; a second import of the same file is detected; a taught PDF template imports the next month with no questions; no network calls during imports.

**Phase 4 — Position: Home, Wealth, Investments, Plan basics, backup**

- Accounts and all asset types with value methods, forms (X42, X42b). Account, Retirement, Cash and bank, Car, Term deposit, Loan and Card detail (X41, X41c–X41f, X47, X48). What you owe (X46). Shares from work (X49). Wealth (X40) with Expected and None recorded. About this number (X40b).
- Investments (X43), Holding detail (X44), Allocation by class, market, currency (X43b, X43c), Gains and tax (X43e), Dividends (X43f), Investment insights (X43h), glossary (X43j), basic Returns (X43g: XIRR, cumulative and annualised TWR; PERF-001), public market data (off by default), local/manual FX, offline state (X89).
- Home final (X10) and sheets (X11–X15), Calendar and Cash flow forecast (X50, X50b, X51), Monthly close and Month summary (X70, X71), Backup (X83).
- **Accept when:** users understand Home in 3–5 seconds (user test); every section 4 number matches the Appendix A fixture; attribution adds up; interest and contribution projections match fixtures; TWR and XIRR fixtures pass (13.12); a local snapshot restores with identical totals; an interrupted restore keeps a valid generation; monthly close takes under 10 minutes with test data.

### 17.2 Release v1.1 — automatic capture, deeper investments, protection, goals

- Local capture sources (X81): Android notifications, FinanceKit when verified, app-owned staging folder, widgets and launch-only shortcuts. No email network connector or Gmail bridge (X82).
- Payslip, loan statement and policy imports (X69, X69b).
- Benchmark comparison on Returns (X43g). Allocation by sector with "Include what is inside funds" (X43d). Transfer between currencies with costs (X26b).
- Protect: policies, claims, "None recorded" types (X55, X56). Goals (X52, X53), with the net worth target and its line under net worth on Home and Wealth.
- **Accept when:** no disallowed traffic from any capture source; at least 90% of a test month's payments arrive without typing; no email body or notification text is stored; each source can be turned off and its data stays; benchmark fixtures pass; a payslip fixture fills all 5 areas and matches the deposit.

### 17.3 Release v1.2 — tax, records and tools

- Tax and year (X58), Emergency sheet local preview (X57), Tools and all calculators (X59, X59b, 13.1–13.11, 13.15, 13.16), money lent and borrowed, contribution limits, target mix.
- **Accept when:** every section 13 test value passes; banned-word check passes on every calculator result; emergency sheet holds no passwords and has no outgoing export.

### 17.4 Release v2 — advanced (off by default, Settings > Features)

- Time machine (any past date), joint accounts and "My share", custom budget periods, money flow chart, report builder, withdrawal simulations, stress tests and sensitivity (13.14), family view (uses Person).
- Tablets, Mac and Windows, with independent local data per device (10.6).
- **Accept when:** these features' fixtures pass; the same simulation seed gives the same result; turning a feature off hides it everywhere without data loss.

## 18. Out of scope

- Any server, account, cloud or LAN sync, outgoing export or remote processing of user records. No future-release exception under the current privacy policy.
- Direct bank, broker, pension, credit-bureau or government connections (open banking, aggregators, screen scraping).
- AI services that run off the device.
- Advice, recommendations, behaviour alerts, scores, or targets the user did not enter.
- Tax calculation, filing and country tax rules (the app only collects the user's numbers for a return).
- Credit reports, disputes, per-country deposit-protection rules (manual credit score field only, v1.2 or later).
- Guessing which subscriptions are "unused".
- Shared editing between people (v2 family view first).
- Watch layouts.

## Appendix A — Sample data set

- Full text: `SPEC_CALCULATIONS.md`. Same section numbers and authority.

## Appendix B — Words and copy rules

- Write short, plain sentences. One idea per sentence. Active voice.
- Use these terms everywhere, with no synonyms: **payment, money in, money out, spent, kept, available until [date], cash you can use, what you own, what you owe, net worth, invested, unrealised gain, realised gain, dividends, expected, none recorded, missing, Est., Inbox, to check, needs a decision.**
- **In cash:** the part of kept that is not invested. Kept = invested + in cash (4.4). Do not use "saved" or "savings" for it. "Savings" stays an account name.
- **Needs and wants:** the two parts of spent, from the user's category tag (`isEssential`). They are labels, not judgements. The app sets no target for them.
- **Expected vs Est.:** a future vest or payment is "Expected" (date and status). A value from today's price or a rule is "Est." ("NVDA · 15 Nov · $3,949 Est.").
- **Hidden amounts:** "$·⋯·", currency mark kept.
- Use **gain**, not "P&L". Rankings use "highest" and "lowest", never "best" or "worst".
- Dates: "22 Oct", "in 9 days", "Tuesday, 13 October". For payments, never use relative words without the date ("soon").
- Amounts: currency symbol, thousands separators, cents only where they matter (payments, prices, splits).
- Changes: always signed and, where useful, with a period ("+$5,490 this month", "+0.3% today").
- Facts, not judgements (section 2). Compare only with the user's own history or own targets.
- Errors: what happened, then what the user can do. No codes. Example: "This file has no rows the app can read. Read it as a photo, teach the layout, or choose another file."
- Privacy lines are specific: "Read on this phone. Nothing is sent." Never vague promises.

## Appendix C — Decisions log

Full entries and open questions: `docs/DECISIONS.md` (by id).

| DECISION | CHOICE |
|---|---|
| Design direction | Obsidian, with Obsidian Light as an equal theme. See SPEC-SYNC-001, POLISH-001. |
| Typography | Inter Display (hero number) and Inter, SIL OFL 1.1, bundled. See POLISH-001 (closes OB-FONT). |
| Home | See HOME-BOARD, HOME-REPEAT (adopted in SPEC-SYNC-001). Other content one tap away. |
| Navigation | Home, Spending, Add, Wealth, Plan. Spending and Wealth have no sub-tabs. One control row and one add control per screen. |
| Investments | Total gain split into price, dividends, currency, and into unrealised, realised. Allocation by class, market, sector, currency. Dividend calendar. Returns with TWR, XIRR, benchmark. Basic Returns in v1 Phase 4: see PERF-001. |
| Trust | Rules in 4.3, from the 24-category review. |
| NUM-001, NUM-002, NUM-003, ARCH-001 | See DECISIONS and Appendix A. NUM-001: never fill missing attribution with a residual. ARCH-001: network only for public symbols, prices, instrument details. |
| Not adopted | Bank connections, credit reports, deposit-protection rules, "unused subscription" guesses, predictive "likely to exceed" labels. |
| Open before release | Open-source licence; real-device tests at 200% text and with screen readers; SQLCipher/native engine integration and system-design validation steps. |
