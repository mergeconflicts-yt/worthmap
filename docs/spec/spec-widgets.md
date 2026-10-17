# Contour — SPEC: widgets (SPEC_WIDGETS.md)

Source: `docs/spec/SPEC_WIDGETS.md`. Edit the source, then run `python3 -I tool/build_handoff.py`.

- Part of the SPEC. Same authority as `SPEC.md` and `SPEC_REFERENCE.md`. Cite sections as "SPEC W n" (for example SPEC W3).
- This file owns the widget rules and the catalogue: product behaviour, independence, edit mode, storage, acceptance, every widget and every Quick look tile.
- Widget and tile catalogue (keys, names, default sets, order, samples, empty states): W11 and W12 in this file. Look: DESIGN 6.7 (WidgetSlot, WidgetEditBar, AddWidgetSheet, TileListSheet). Storage: DATABASE_DESIGN 5.1.
- Decisions: WIDGETS-001...006, HOME-QUICKLOOK, WIDGET-NAMES, WIDGET-CATALOGUE (docs/DECISIONS.md).
- Version 1.3 — 16 October 2026. Includes the former widget catalogue (WIDGETS-006). Adds W13 Layout as data (WIDGETS-007). ARCH-REVIEW-004 corrections: pair width (W3.2, W-A), preview states (W5), the add block, retained sections, renames and "New in this version" (W13), cash-flow definitions and states (W11.1).

## W1. Terms

| TERM | MEANING |
|------|---------|
| Widget | One card on a tab screen, with its title above the card (CARD-TITLE-OUT). |
| Tile | One item in the Home Quick look widget. Tiles follow the same rules as widgets (W3). |
| Surface | A list of widgets or tiles that the person can change: one tab screen, or the Quick look tiles. |
| Registry | The list in code of every widget and tile: key, name, own screen, "Moves" value, allowed sizes, builder. |
| Section | A titled group of widgets on a surface, for example "This month" or "More". It moves as one (W13). |
| Default layout file | The data file that ships inside each app release. It gives every surface its default sections, widgets, order and sizes (W13). |
| Size | How wide a widget is: `full` or `half`. Two half widgets next to each other share one row (W13). |
| Home-screen widget | A phone OS widget (WidgetKit, Glance). It is **not** a widget in this file. It is launch-only (SPEC 15, ARCH-001). |

## W2. Scope

- **Customisable screens (9):** Home, Spending, Money in, Wealth, Investments, Calendar, Goals, Protect, Tax. The amounts-hidden Home (X12) uses the Home layout.
- **Every card on these screens is a widget.** 30 widgets (W11) and 8 Quick look tiles, 4 default and 4 in the library (W12).
- **Not widgets:** the screen hero (fixed, never moves), detail screens, sheets, dialogs and forms.
- **Layout as data:** what a surface shows comes from the default layout file plus the person's saved layout, never from screen code (W13).

## W3. Independence (WIDGETS-005, from v1 Phase 1)

Every widget is independent from the first build. Do not build fixed cards first and convert them later.

1. **One widget = one module.** It has one stable key, one builder, its own states and its own tests. It is in the registry.
2. **No links between widgets.** A widget never reads, writes or waits for another widget's state. Hide, move or add one widget → no other widget changes. One exception is width only: a half-width widget next to it in the same section can change between a shared row and its own row (W13). Its content, numbers, state, focus and data requests do not change.
3. **Shared numbers, not shared state.** A widget reads only the shared metric providers of the central read store (SYSTEM_DESIGN, one provider per canonical metric). It never runs its own database query or calculation. So the same number is equal on every screen.
4. **Own states.** Each widget shows its own Loading, Missing, None recorded, Estimated, Hidden-amounts and Not available states (SPEC 4.3). One widget in a failed or Missing state never blocks, hides or changes another widget or the screen.
5. **The screen knows no widget detail.** A screen reads its surface layout and builds each shown key from the registry, in the stored order. A screen file has no widget-specific code.
6. **New widget = registry entry.** A new widget or tile needs: key and l10n name in W11/W12, default position (or "library only"), empty state, hidden-amount behaviour, registry entry, goldens (Dark and Light, text scale 1.0 and 2.0) and a docs/DECISIONS.md entry. It needs no change to a screen file or to another widget.
7. **A hidden widget does no work.** It holds no subscription, timer, animation or chart geometry. Showing it again subscribes again.
8. **Location-free.** A widget shows the same numbers, words, period and destination on any screen (SPEC 2: no added total, score or judgement). It opens its own screen.
9. **Own controls stay home.** A widget with its own controls ("Moves" = No, for example Holdings with its view switch, What you own / What you owe) stays on its screen. It can still be hidden and reordered.
10. **Unknown keys are safe.** A stored key that the registry does not know (older or newer catalogue) is skipped. The screen still renders.

## W4. What the person can do

- Hide, reorder and add widgets on each customisable screen.
- Add a widget from another tab screen (for example "By category" on Home), except "Moves" = No widgets.
- Change the Quick look tiles: show, hide and reorder (a "Tiles" button opens TileListSheet).
- Hiding never deletes data.
- Restore defaults for one screen (Default) or for all screens (Settings > "Restore the default widgets").

## W5. Edit mode (WIDGETS-001...004)

- **Entry points:** "Edit widgets" row at the end of each tab screen; Settings > "Screens and widgets" (each screen with "[n] widgets" or "[n] shown"). Both open the same edit mode.
- **Per widget:** Hide, Move up, Move down (the button path for the drag), drag handle. Widget content ignores taps. Move up on the first widget of a section moves it to the end of the previous section; Move down on the last widget moves it to the start of the next section. At that boundary the button says "Move to [section name]" (no title: "Move to section [n]").
- **Per section:** Move section up, Move section down, on the section's edit header. Every section has an edit header in edit mode, also a section with no title (DESIGN 6.7). Empty sections show in edit mode only, so a widget can move into them.
- **Edit bar, one row (WIDGETS-004):** Cancel (icon) · Undo (icon) · Default · Add widget · Done (filled icon). It wraps at 200% text.
  - Undo: one change back at a time, in this session.
  - Default: this screen's default widgets and order (Home: also the default Quick look tiles). Undo can reverse it.
  - Add widget: no plus icon; the tab bar Add stays the only add control (SPEC 3.3). The sheet lists widgets hidden on this screen first, then widgets of other tab screens. Each row shows a live preview of the widget with the same numbers (inert; amounts masked when hidden, also on X12); a tap shows it full size (WIDGETS-006b). The preview reads the shared values that are already loaded; it starts no query, refresh, calculation or timer (W3). A value that is not loaded shows "Not loaded yet": never a sample, never zero, never Missing. A screen reader reads one label per preview: the name and the main visible values. Where a widget goes and its size come from the default layout file (W13); the person then moves it with the section controls. A customised screen also shows the group "New in this version" (W13).
  - Cancel: leave edit mode and restore the screen as it was at open.
  - Done: keep the changes. It is the only filled button.
- No extra control row. Every drag has a button path. Keyboard and screen reader can do every action.

## W6. Data rules

- **Hide amounts:** every amount shows "$·…". Counts, dates and percentages stay (SPEC 4.9).
- **Unknown is never zero (SPEC 4.3).** With nothing recorded, show "None recorded" or "Missing", or hide the widget (W11 column "Empty").
- **Release and feature gates:** a widget for a feature that is off or not released is absent from the screen and from "Add widget". The stored layout keeps its key.
- **Home-screen widgets** never show in-app widget content (SPEC 15).

## W7. Storage (WIDGETS-002)

- The layout is a local display preference, not financial data: `layout_surfaces`, `layout_sections` and `layout_items` (DATABASE_DESIGN 5.1).
- Rows list the stored sections and items in order: shown items and kept items (keys that this release does not know or does not show). A known key that is not listed is hidden. No row for a surface = the default layout file of the installed release (W13).
- One write command replaces a surface's rows atomically through the single command writer. No ChangeLog entry, no financial dependency revision. Nothing is computed from it.
- Keys (screen.widget, tile.name) are stable and never shown. Names are l10n strings.
- Kept in recovery snapshots. `catalogue_version` lets a migration map renamed keys.

## W8. Build order

- **v1 Phase 1:** registry, WidgetSlot and WidgetSection host, the default layout file and its build-time validation, surface layout read and write (sections, items, sizes, layout version), edit mode, and the default layout of X03HomeFirstRun. X03 is a state of Home: it uses surface screen:home, not a surface of its own (SCREEN-SET-001; its catalogue entry is open, WIDGET-X03-DEFAULT). Accept with test widgets and a test layout file.
- **Each later phase:** a screen's cards arrive as registry widgets with their catalogue rows. A phase adds widgets; it never changes the widget framework.

## W9. Acceptance

| ID | CHECK |
|----|-------|
| W-A | Hide, move or add one widget: every other widget renders the same (golden and widget tests). Only exception: the width of a half-width partner in the same section (W3.2). |
| W-B | One widget throws or has Missing input: the screen and all other widgets still render. |
| W-C | The same widget on two screens shows identical numbers, period and destination. |
| W-D | A hidden widget creates no provider subscription or chart work. |
| W-E | Adding a test widget changes only the registry, the catalogue and l10n; no screen file changes. |
| W-F | Unknown stored key: skipped, no crash. A removed section: its widgets move and hide; its unknown keys stay. Cancel, Undo, Default and Done do what W5 says. |
| W-G | Hide amounts, text scale 2.0, light and dark, keyboard and screen reader pass on edit mode and on Add widget previews (one spoken label per preview; "Show full size"). |
| W-H | Restore defaults deletes the surface rows only; no financial record changes. |
| W-I | A changed test default layout file changes an untouched surface with no screen-code change. |
| W-J | After a layout version change, a customised surface keeps its order; new widgets (also library-only) show under "New in this version" in Add widget until the next Done; removed keys are skipped; renamed keys show under their new key. |
| W-K | A section moves as one; a widget moves between sections (drag and buttons); two half widgets share a row; above the reflow text scale each takes the full width; hiding one half widens only its partner. |
| W-L | An invalid default layout file fails the build, never the app at run time: unknown key or format, size not allowed, duplicate key or section, gate missing, missing surface, title string missing, wrong kind, a "Moves" = No widget on another surface, since above the file version, missing add entry or target, bad anchor, rename collision, too many sections or widgets, a lower layout_version than the last release, a changed since, or a removed allowed size. |

## W10. Open items

- Home card slot after "This month" stays open (HOME-GOALS-NAME, docs/DECISIONS.md Open questions).
- **SUBS-TOTAL** and **REGULAR-INVEST** stay open (docs/DECISIONS.md).
- **LAYOUT-UPGRADE:** the new-release rule in W13 is the interim rule until the person confirms it (DECISION-PENDING: LAYOUT-UPGRADE).
- **Cash-flow widgets (W11.1):** CASHFLOW-BALANCE, CASHFLOW-DUE-WINDOW, CASHFLOW-COLOUR and CASHFLOW-REPEAT stay open. Both widgets are not available for production until they close.
- **WIDGET-HALF-REFLOW:** the text scale at which half-width pairs stack (interim: above 1.3 on phones).

## W11. Widget catalogue

Columns: Key · Name (l10n; * = name given because the card has no title, WIDGET-NAMES) · Pos (default order on its own screen) · Shows (SPEC Appendix A samples) · Opens · Moves · Empty.

### W11.1 Home (X10Home, surface `screen:home`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| home.quickLook | Quick look | 1 | Tiles that scroll sideways (W12). Meta "today". | each tile opens its screen | Yes | not shown when no tile is shown or recorded |
| home.next30Days | Next 30 days | 2 | Meta "$2,415 due before 1 Nov" (SPEC 4.4). Glyph timeline 13 Oct – 12 Nov: ● spending, ◆ investing, ★ money in, with name and amount. Preview chart: no table (PREVIEW-CHART). | Calendar (X50) | Yes | "No dated payments in the next 30 days." |
| home.thisMonth | This month | 3 | Meta "October · day 13 of 31". Money in $8,200 "Salary · 1 Oct"; Spent $3,940 "of $5,200 limit · 76%" with a meter and a today tick; split bar Needs $2,890 35.2% · Wants $1,050 12.8% · Invested $0 0.0% · In cash $4,260 52.0% (Percent.split). | Money in (X31), Spending (X30) | Yes | Money in "None recorded" before the first income |
| home.repeating | Repeating | 4 | Meta "$2,084 a month". Next 3 unpaid repeating payments: Netflix 18 Oct $17.99, Phone 20 Oct $45, Health 28 Oct $210; "All repeating payments · 7". Text only (HOME-REPEAT). | Repeating (X34), each row X35 | Yes | not shown with no repeating payment |
| home.goalsProgress | Goals progress | 5 | Meta "goals · debt paid". House 66%, Emergency 50%, Car loan 58% with meters; "Put into investments in 2026 · $6,000". | Goals (X52), Loan (X47), Investments (X43) | Yes | before goals exist: debts paid off and money put into investments only |
| home.cashFlowActual | Cash flow, actual | library | Half width. Pill "Actual". Meta "October" (the calendar month to today, the same period as This month). Rows Money in $8,200, Money out $3,940; boxes Kept $4,260 and Kept % 52.0% (SPEC 4.4: kept = money in − money out; Kept % = kept ÷ money in). | Spending (X30) | Yes | Money in "None recorded" before the first income; other fields: states below |
| home.cashFlowExpected | Cash flow, expected | library | Half width. Pill "Expected". Meta "to 1 Nov" (to the next expected income). Rows Expected in +$8,200 "Expected · 1 Nov" (SPEC 4.9, never in a total); Due before next income −$2,415 (SPEC 4.4). Boxes Payments 5 and Balance on 1 Nov $25,435 Est. (DECISION-PENDING: CASHFLOW-BALANCE). SPEC 13 cash sample. | Cash flow (X50b) | Yes | not shown when the window has no dated payment and no expected income; other fields: states below |

Fixed on Home: hero (NET WORTH, target line, 12-month line), footer ("Prices 4:00 pm · 9 of 9 accounts updated · snapshot 11 Oct"; last private recovery snapshot).

Library widgets ("library") are not shown by default. "Add widget" lists them under "Hidden on Home". The default layout file puts them after This month (add.targets, W13), at half width. Two half-width widgets next to each other share one row; above the reflow text scale each takes the full width (WIDGETS-005b).

**Cash-flow widgets: definitions, states and open items (WIDGETS-005b, ARCH-REVIEW-004).** Both widgets are not available for production until CASHFLOW-BALANCE, CASHFLOW-DUE-WINDOW, CASHFLOW-COLOUR and CASHFLOW-REPEAT close (docs/DECISIONS.md Open questions).

- **Words and formulas.** Only Appendix B words: money in, money out, kept, Kept %, due before next income, expected, Est. No "Net". Money in, money out, kept and Kept % follow SPEC 4.4 for the calendar month to today. Due before next income and its 30-day fallback follow SPEC 4.4 (DECISION-PENDING: CASHFLOW-DUE-WINDOW; the person's card used a window that includes the income day): the same value and words as the Next 30 days meta ("$2,415 due before 1 Nov"). Payments = the count of those payments.
- **Balance on [next income date] (DECISION-PENDING: CASHFLOW-BALANCE):** SPEC 4 has no definition. Interim (preferred option): the SPEC 4.8 forecast at the end of the next income date, summed over accounts with isLiquid = true: cash you can use + expected income to that date − cash payments due to that date, the income day included. Label "Est."; never in a total; Expected income stays marked. Sample: $21,450 + $8,200 − $2,415 − $1,800 (rent, 1 Nov) = $25,435 = Checking $10,435 + Savings $15,000. Its window includes the income day; the Due row does not (CASHFLOW-DUE-WINDOW).
- **Colour (DECISION-PENDING: CASHFLOW-COLOUR):** the person asked for green Money in and red Money out, copied from a reference card (HOME-TRIAL-004d). DESIGN allows colour only on flow glyphs and signed changes. This is a recorded deviation for a DESIGN decision; it is not removed.
- **Repeated numbers (DECISION-PENDING: CASHFLOW-REPEAT):** with This month and Next income also shown, $8,200, $3,940, $4,260 and 52.0% can show twice. The same number always uses the same word.
- **Spoken labels** say the visible values only, in the visible words.

| FIELD | INPUT UNKNOWN OR ABSENT | SHOWS |
|-------|-------------------------|-------|
| Money in | No income recorded this month | "None recorded" |
| Money out | No expense recorded this month | "None recorded" |
| Money in or money out | A source is missing (for example a statement not imported) | "Missing since [date]" |
| Kept, Kept % | Money in or money out is None recorded | "Not available"; never $0, 0% or a partial difference |
| Kept, Kept % | Money in or money out is Missing | "Missing" (SPEC 4.7: a missing part is never zero) |
| Kept % | Money in is $0 or less | "Not available" |
| Window | No next expected income date | "next 30 days" (SPEC 4.4); meta "next 30 days" |
| Expected in | No expected income in the window | "No expected income recorded." |
| Due before next income | No dated payment in the window | "None due"; Payments 0 (a known count) |
| Balance on [date] | Any liquid account balance Missing, or CASHFLOW-BALANCE not approved | "Missing" / "Not available" |
| Whole card (expected) | No dated payment and no expected income | Not shown |

Test values (Appendix A, 13 Oct; SPEC 13): full sample as in the table above. Partial cases from the same sample: (1) salary not recorded: Money in "None recorded", Money out $3,940, Kept and Kept % "Not available"; (2) no expense recorded: Money in $8,200, Money out "None recorded", Kept and Kept % "Not available"; (3) Visa statement Missing: Money out "Missing since [date]", Kept and Kept % "Missing"; (4) no next income date: meta "next 30 days", Expected in "No expected income recorded.", Due = the SPEC 4.4 30-day value, Balance "Not available"; (5) no payments and no expected income: the expected card is not shown.

### W11.2 Spending (X30SpendingOut, surface `screen:spending`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| spending.byCategory | By category | 1 | Meta "October". Needs/wants split bar; ring per category, largest first: name, spent, "$X left" or "Paid"; Show as table (spent, limit, left, 12-month average). | Category detail (X36) | Yes | "No spending recorded in October." |
| spending.repeatingMoneyIn | Repeating and money in * | 2 | Repeating "$2,084 a month · 7 payments · 3 changes"; Money in "$8,200 · October · avg $9,267 a month". | X34, X31 | Yes | each row "None recorded" |
| spending.paymentsLimits | All payments and limits * | 3 | All payments "42 · October"; Edit limits "$5,200 · 8 categories". | Transactions (X37), Edit limits (X33) | Yes | "0 payments" (a known count); limits "None set" |

Fixed: hero with 1W · 1M · 6M · 1Y and the period bars.

### W11.3 Money in (X31SpendingIn, surface `screen:moneyIn`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| moneyIn.nextIncome | Next income * | 1 | $8,200 "Salary · 1 Nov · in 19 days" — Expected, never in a total (SPEC 4.9). | Calendar (X50) | Yes | "No expected income recorded." |
| moneyIn.sources | Sources | 2 | Meta "12 months · $111,200". Salary $98,400 88.5%; Bonus $6,000 5.4%; Rent received $5,800 5.2%; Interest & dividends $1,000 0.9%; Owed to you $2,640 "Expected · 2 items". | each source | Yes | "None recorded" |

Fixed: hero with 1M · 6M · 1Y and "Where money in went".

### W11.4 Wealth (X40WealthOverview, surface `screen:wealth`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| wealth.ownOwe | What you own and owe * | 1 | You own $197,540 / You owe $9,640 tabs; split bar and type tiles (Investments $129,800, Retirement $24,010, Cash & bank $21,450, Car $12,000, Deposits $10,280; empty types "None recorded"); You owe: Car loan $8,400, Visa $1,240; Show as table. | each type | No (own tabs) | empty types show "None recorded" |
| wealth.notInNetWorth | Not in net worth | 2 | Meta "Expected". Unvested shares $31,595 "160 shares at today's price"; Owed to you $2,640; Dividends, next 6 months $245 "Est." (SPEC 4.3: owned is not expected; no total). | X49, X46, X43f | Yes | not shown when all three are "None recorded" |

Fixed: hero (net worth, 1M · 1Y · 5Y, three-line chart and table).

### W11.5 Investments (X43Investments, surface `screen:investments`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| investments.holdings | Holdings * | 1 | Group menu Holdings · Sectors · Markets; views Bubbles · List · Tree; filter sheet; total $129,800 and gain for the period. | Holding detail (X44) | No (own controls) | "No holdings recorded." |
| investments.byCurrency | By currency | 2 | Meta "in USD". US dollar $107,600 82.9%; Indian rupee $12,600 9.7%; Taiwan dollar $9,600 7.4%. | — | Yes | not shown with one currency |
| investments.regular | Regular investments | 3 | VTI $500 "25 Oct"; NVDA $3,949 Est. "15 Nov". | Repeating detail (X35), Vests (X49) | Yes | not shown with none |
| investments.totalGain | Total gain since you started | 4 | Meta "+$40,430". Price +$39,174 · Dividends +$1,950 · Currency −$694; unrealised +$31,600, realised +$6,880 (SPEC 4.5). | Gains (X43e) | Yes | "Missing" before the first valuation |
| investments.returnsTax | Returns, dividends and tax * | 5 | Returns "1M · 1Y · 3Y"; Dividends $410 "in 2026"; Gains and tax. | X43g, X43f, X43e | Yes | rows "None recorded" |

Fixed: hero (value, 1D · 1M · 1Y · All, cost-basis line, fact row).

### W11.6 Calendar (X50Calendar, surface `screen:calendar`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| calendar.month | October | 1 | Meta "to 15 Nov". Symbol calendar 1 Oct – 15 Nov (● ◆ ★, at most 3 a day, "+N"); row "Cash flow until 1 Nov · Checking lowest · 30 Oct · $4,035" (SPEC 4.8). | Day sheet (X51), Cash flow (X50b) | Yes | days without marks |
| calendar.beforeIncome | Before next income | 2 | Meta "$2,415 from Checking". Dated rows 18 Oct – 30 Oct, then "From next income": Salary +$8,200 Expected, Car insurance −$780, NVDA vest +$3,949 Est. | each row | Yes | "Nothing due before the next income." |

Fixed: the Plan tabs (Calendar · Goals · Protect · Tax) and the top line.

### W11.7 Goals (X52Goals, surface `screen:goals`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| goals.netWorthTarget | Net worth target | 1 | Ring 18.8%, "$187,900 of $1,000,000", rows By Dec 2040 "$4,777 a month · Est.", At +$16,900 a year "2074 · Est.", Financial independence. | Tools (X59) | Yes | not shown with no target |
| goals.glance | Goals at a glance * | 2 | Three equal vials: House deposit 66%, Emergency fund 50%, Japan trip 32%; Show as table. | Goal rows | Yes | not shown with no goal |
| goals.list | Goals | 3 | House deposit $39,440 "of $60,000 · Dec 2028 · Brokerage 40%"; Emergency fund $15,000; Japan trip $1,935. | Goal detail | Yes | "No goals yet." |

Fixed: hero "ASSIGNED TO 3 GOALS $56,375".

### W11.8 Protect (X55Protect, surface `screen:protect`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| protect.premiums | Premiums this year * | 1 | Ring by policy: Health $2,520, Car $780, Term life $640; Show as table. | Policy detail (X56) | Yes | not shown with no policy |
| protect.cover | Cover | 2 | Meta "3 of 6 types". Health $50,000; Car "Full cover"; Term life $500,000; Disability, Home, Travel "None recorded" (caption: "None recorded" is not "no cover"). | X56 | Yes | every type "None recorded" |
| protect.policies | Policies | 3 | Health "Used this year: $1,200 of $50,000"; Car "Renews 4 Nov: $780 · last year $720"; Term life "$640 a year · next 3 Jan". | X56 | Yes | "No policies recorded." |
| protect.emergencySheet | Emergency sheet | 4 | Meta "on this phone". "Accounts, policies, loans, contacts"; "Nominees: 7 of 9 entered · Will: not entered". | X57 | Yes | "Not started" |

Fixed: hero "PREMIUMS A YEAR $3,940".

### W11.9 Tax (X58Tax, surface `screen:tax`)

| KEY | NAME | POS | SHOWS | OPENS | MOVES | EMPTY |
|-----|------|-----|-------|-------|-------|-------|
| tax.dates | Tax dates | 1 | Dated tax rows (for example advance tax 15 Dec $1,800; filing date 15 Apr). | each date | Yes | "No tax dates recorded." |
| tax.savingRoom | Tax-saving room | 2 | Used and remaining room per limit, with a meter. | Limits | Yes | "None recorded" |
| tax.returnFigures | For your tax return | 3 | Label-value rows for the year (on this phone; no external export). | — | Yes | "Missing" per value |
| tax.feesInterest | Fees and interest paid * | 4 | "Loan $470 · currency fees $112 · bank fees $48" and the total. | Transactions (X37) | Yes | "$0" only when the records are complete; else "Missing" |

Fixed: hero "2026 so far".

## W12. Quick look tiles (home.quickLook, surface `tiles:quickLook`, HOME-QUICKLOOK)

Tile lines: icon and name, value, one short fact. Edit: Home edit mode > Quick look "Tiles" > switch per tile, Move up / Move down. A shown tile appears only when its kind is recorded.

| KEY | NAME | DEFAULT | VALUE · FACT (SAMPLE) | DATA | OPENS |
|-----|------|---------|------------------------|------|-------|
| tile.cash | Cash | Yes (1) | $21,450 · "available now" | cash you can use (SPEC 4.4) | Cash and bank (X41d) |
| tile.cardBill | Card bill | Yes (2) | $1,240 · "Visa · 22 Oct" — the nearest bill only, never a sum across dates; with more cards "+N more · $X by [date]" | card statement (SPEC 6 Home) | Card (X48) or You owe |
| tile.investments | Investments | Yes (3) | $129,800 · "+$550 today" | investments value and today's change (SPEC 4.5) | Investments (X43) |
| tile.subscriptions | Subscriptions | Yes (4) | $28.98 · "a month" (exact cents; a trial is named) | repeating rules of kind subscription (DECISION-PENDING SUBS-TOTAL) | Repeating (X34) |
| tile.retirement | Retirement | No | $24,010 · "401(k) · Est." | retirement accounts | Retirement (X41c) |
| tile.deposits | Deposits | No | $10,280 · "Est. · 12 Nov" (next maturity) | deposit accounts | Deposit (X41f) |
| tile.owe | What you owe | No | $9,640 · "loan and card" | debts (SPEC 4.4 what you owe) | You owe (X46) |
| tile.nextIncome | Next income | No | $8,200 · "Expected · 1 Nov" — Expected, never in a total | expected income (SPEC 4.9) | Money in (X31) |

With no tile shown, the Quick look widget is hidden.

## W13. Layout as data (WIDGETS-007, from v1 Phase 1)

Every customisable surface is a fixed hero plus a layout. The app reads the layout from data when it starts. A new release can change a screen's structure by changing data, not screen code.

**Model**

- Layout = ordered **sections**. Section = section key, l10n title (or no title), ordered **placements**. Placement = widget key + size (`full` or `half`).
- The hero is not in the layout. It stays fixed (W2).
- Quick look tiles stay one widget with its own tile list (W12).

**Default layout file**

- One declarative data file ships inside each app release, compiled into the app. It has a `layout_version` number and the default layout of all nine surfaces and the tile list. The first released file has `layout_version` 1.
- An **add block** gives, for every widget that the person can add, its add size, the `layout_version` that introduced it (`since`) and where it goes: a section and anchor widgets ("after This month"), with a default target per surface. The registry gives the allowed sizes only; their order means nothing.
- The registry validates the file when the app is built: every key exists, each size is allowed for that widget, no key appears twice on a surface, release and feature gates are declared, "Moves" = No widgets stay on their own surface, and all W-L checks. An invalid file fails the build (W-L).
- The file holds keys only: no amounts, text or personal data.

**Loading**

- At start, for each surface: saved layout (if the person changed it) or the default layout file → registry → release, feature and platform gates → placements. The screen host draws the result.
- Rendering never writes the layout. Unknown keys are skipped (W3.10).
- The app never reads a layout file from a writable folder, an import, a shared file or a recovery snapshot. Snapshots hold the saved rows only.

**What the person can change (W4, W5)**

- Show, hide, reorder and add widgets.
- Move a whole section up or down. Move a widget to another section of the same surface.
- Sections take their titles from the file; the person does not rename them in v1. A section with no shown widget is not drawn; in edit mode it is drawn, so a widget can move into it.
- The size comes from the file. The person does not change sizes in v1. If a release no longer allows a saved size, the widget shows at its other size and the saved size stays.

**New release (interim rule; DECISION-PENDING: LAYOUT-UPGRADE)**

- A surface the person never changed uses the new default layout file at once.
- A surface the person changed keeps its sections, order and sizes.
- Widgets new in that `layout_version` show in Add widget under "New in this version". No banner, badge or prompt.
- Keys that a release removes are skipped. Renamed keys are mapped by a rename list in the file (`catalogue_version`) when the layout is read; the next Done saves the new keys. A release changes no saved row.
- "Default" on a screen restores that surface from the installed release's file.

**Never remote**

- A layout file arrives only inside an app release. The app never downloads a layout, a widget or a screen structure (AGENTS 2 and 12: no remote configuration).

**Storage:** `layout_sections`, `layout_items` with section and size, and `base_layout_version` on `layout_surfaces` (reference migration 005; DATABASE_DESIGN 5.1).

**Details of the release rule**

- A saved section that the new file no longer has stays, without a title. The person can move its widgets out, hide them, or move the section. Keys that the release does not know stay in it.
- A section that is new in the file is not added to a customised surface automatically. Its widgets show in Add widget; adding one adds its section.
- "New in this version" lists widgets (also library-only widgets and widgets from other screens) whose `since` is after the saved layout's `base_layout_version` and that are not saved on that screen. Only a customised screen has the group.
- "Seen" (interim): the next Done of an edit session on that screen saves the installed `layout_version` as `base_layout_version`, also when nothing else changed. The group then clears, also after an unrelated change. Cancel, opening Add widget and Undo do not clear it. Default returns the screen to the file, with no group.
- A layout saved by a newer app version than the installed one is read-only in edit mode ("Saved by a newer version of the app. Default is available."); Default stays available. DESIGN 6.7 shows this state.
- Section keys come from the file, never from the person. `untitled` is reserved. The Quick look tile list has only one untitled section and full-size tiles.
- Limits per surface: 16 sections, 256 widgets, 64 KiB. Keys from the file never reach 64 KiB; a saved layout from another version with long non-ASCII keys can. A larger saved layout from another version stays readable and can be reset.
