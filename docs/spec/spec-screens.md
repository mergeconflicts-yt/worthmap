# Contour — SPEC reference: Screen specifications (SPEC_SCREENS.md)

- Part of the SPEC reference. Same authority and section numbers as SPEC.md and SPEC_REFERENCE.md: "SPEC n.n" resolves here for these sections.
- Version 1.1.4 — 16 October 2026. Text moved from SPEC_REFERENCE.md. Entry names are the prototype list names (docs/screens/SCREENS.md Index).

## 6. Screen specifications

- Each entry gives content, actions, rules and states. Layout, kickers, labels, full sample rows and spoken labels: docs/screens/SCREENS.md (same ids). Chart and component look: DESIGN 6.7, 7.2.
- All screens follow 3.3 and section 7. Each has an Obsidian hero (7.1). Entry words (DESIGN-HTML-014): **hero, card, row, facts** (two or three small figures), **sheet, dialog**.
- Sample values come from Appendix A. Other prototype values (for example a receipt total or a claim amount) are design data only.
- "→ X" = opens screen X. Every chart has "Show as table", except a preview chart (PREVIEW-CHART).

### 6.1 Start

**Welcome (`X01Welcome`)**

- "Know your money in 3 seconds." Three privacy facts: "Your data stays on this phone" (no account, sign-up or servers); "You choose what the app reads" (shared files, sources you turn on); "Encrypted backups you own" (copies stay on this phone, 14).
- **Your main currency** is the only required choice. Default: phone region. Changeable later.
- Start. "Everything else is optional." Accounts, imports and app lock come later from Home.

**App lock (`X02Lock`)**: shows on open and after the lock timeout. No amount shows until unlock. Behind it: a fixed blurred Home silhouette with no data (POLISH-001). "Unlock with Face ID" (or fingerprint), primary; "Use passcode", secondary.

**Home, first run (`X03HomeFirstRun`)**

- Hero net worth "—": "Add your main account to see this number." (4.3).
- **Get started** ("0 of 5"): Add your main account, Share a bank statement, Add your first expense, Turn on the app lock, Set up local recovery. Each step is optional, skippable, and opens its screen.
- **Next 30 days**: "none recorded" until an account, card or repeating payment exists.

### 6.2 Home

**Home (`X10Home`, final)**

- One short board. The person can change its widgets (WIDGETS-001). Each number shows once. A number opens its breakdown; a card opens its screen.
- Net worth is the hero (DESIGN-HTML-011). This order differs from 4.6: open question GLANCE-ORDER (SPEC-SYNC-001).

1. **Header**: date and currency; Hide amounts, Inbox (count badge, count in label), Settings. A Search field below the title → `X15Search`. "Today" is a screen-reader heading only. Open question AS-OF-DATE: the prototype hides the date line; until decided, keep date and currency.
2. **Net worth hero**: no (i) button; a tap on the number → `X40bAboutNumber`. One change figure, 12 months ("+$16,900 · 12 months"); no daily change. Target line when a target exists (6.8) → Goals. 12-month line → Wealth.
3. **Quick look**: sideways tiles (name, value, one fact). A tile shows only when its kind is recorded. No tile → card hidden.
    - **Cash**: cash you can use, "available now" → `X41dCashBank`.
    - **Card bill**: nearest due date only, never a sum across dates ("$1,240 · Visa · 22 Oct"). More cards: "+N more · $X by [last due date]" → Wealth > You owe. One card → `X48CardDetail`.
    - **Investments**: value and today's change ("+$550 today") → `X43Investments`.
    - **Subscriptions**: monthly total of repeating payments of kind subscription, exact cents; a trial is named → `X34Repeating`. DECISION-PENDING: SUBS-TOTAL (tile and "Subscriptions" category measure different things).
    - **Tile choice (HOME-QUICKLOOK)**: edit mode > "Tiles" opens "Quick look tiles": switch per tile, Move up / Move down. Default: Cash, Card bill, Investments, Subscriptions. Library: Retirement ("401(k) · Est."), Deposits ("Est. · [next maturity]"), What you owe (loan and card), Next income ("Expected · [date]", never in a total).
4. **Next 30 days**: "$X due before [next income date]" (4.4) → Calendar.
    - Timeline on a real date scale, today to +30 days; dashed after the next income.
    - Symbols: ● spending (bills, card bills, loans, premiums, card charges), ◆ investing (repeating investments, vests), ★ money in (income, maturing deposits). Symbol area follows the amount for spending and investing.
    - Name and amount show. Notes ("was $15.49", "minimum $40", lowest balance) go in the spoken label and linked screens.
    - Focusable; arrow keys scroll. Preview chart; Calendar has the table. Look: DESIGN 6.7 GlyphTimeline.
5. **This month** ("[month] · day [n] of [days]"): **Money in** (amount, source, date) → `X31SpendingIn`; **Spent** ("of $5,200 limit · 76%", today tick) → Spending; one stacked bar of money in: **Needs, Wants** (spent, by isEssential, 9.3), **Invested, In cash** (kept) → Money in.
6. **Repeating** ("$2,084 a month" → `X34Repeating`): next 3 unpaid repeating payments this month as plain rows "[date] · [cadence]" (each → `X35RepeatingDetail`); "All repeating payments" (7). No chart, no colour (HOME-REPEAT). Hidden when none recorded.
7. **Goals progress**: up to 3 goals or debts with % and bar; "Put into investments in [year]: $6,000". Before goals exist (v1): debts paid off and money put into investments only.
8. **Footer**: price time, "9 of 9 accounts updated", last snapshot date → `X83Backup`.
- **Moved off Home** (one tap away): needs-your-attention cards (dated items are on the timeline; Inbox count is the badge); available until [date] and cash/due split (`X41dCashBank`, `X14ToUseBreakdown`, `X50bCashFlow`); money in "as usual" (Money in); own/owe by type and "Not in net worth" (Wealth); attribution (About this number); investments card; latest payments (`X37Transactions`).

**About this number (`X40bAboutNumber`)**, sheet titled "About net worth"; opens from a tap on the Home or Wealth hero number

- Facts Period, Currency, Coverage ("9 of 9"). $187,900 = own $197,540 − owe $9,640.
- **Change this month** (+$5,490 · +3.0%), attribution (4.7): You kept +$4,260, Markets +$1,780, Currency −$550, Values $0; "From $182,410 on 30 Sep to $187,900 on 13 Oct. The parts add up to the change."
- **Parts** with value, basis and source ("Captured", "Imported", "Est."; Retirement "Statement 31 Jul, then your rule"). Caption: rates used (INR 84.00, TWD 32.00 per USD); "Est." values grow by the user's rule between real updates.
- Done; "Open Wealth".

**Home, first days of a month (`X11HomeMonthStart`)** (sample 2 Oct)

- Days 1–7: "In the first 7 days of a month, Home shows last month first."
- Hero kept $3,880: "September is not closed yet. Kept 47% of money in. In August: 41%." After Save and finish (`X71MonthSummary`): "September closed" and "Make a private snapshot" → `X83Backup` (`G10`). Facts In → Money in, Out → Spending, Kept → Month summary.
- **Close September** ("5 steps, about 8 minutes") → `X70MonthClose`. **Net worth** $182,410 ("September close, 30 Sep") → Wealth.
- Then normal Home with that date's values ($26,190; 8 payments $3,330; available $22,860).

**Home, amounts hidden (`X12HomeHidden`)**: every amount "$····" (currency mark stays); percentages stay; charts keep shape without text; spoken labels masked. Long-press any large number to hide or show all.

**Home, main number (`X13MainNumberSheet`)**, sheet over Settings (Settings > Screens and widgets > "Main number on Home"); title "Main number on Home": one radio group; option, definition, today's value: Available until 1 Nov ($19,035); **Net worth** ($187,900; default, DESIGN-HTML-015); Spent this month ($3,940 of $5,200); Cash you can use now ($21,450). **Use [option]**; Cancel.

**Home, available breakdown (`X14ToUseBreakdown`)**, sheet

- "How $19,035 adds up": $19,035 = cash you can use $21,450 (Checking $6,450, Savings $15,000) − $2,415 due before 1 Nov.
- **Due before 1 Nov**: the five Appendix A payments (date, kind, paying account, amount, symbol → its screen). Total row.
- Caption: which accounts count; payments come from repeating items and card statements; the Netflix card charge ($17.99, 18 Oct) is not in this cash total.
- Done; "Change which accounts count" → Cash and bank.

**Search (`X15Search`)**: opens from the Search field below the Home title and from the Spending header; one field; chips All, Payments, Merchants, Accounts, Notes (control row). Merchant → Category detail; payment → Payment detail. "Search runs on this phone only."

### 6.3 Add and capture

**Add expense (`X20AddExpense`)**

- Source buttons Speak, Scan QR, Receipt photo, Import a file. Type switch Expense, Income, Transfer (control row). Keypad amount.
- Pills currency, date, paid with → details sheet.
- "Where or what? For example Starbucks". A typed sentence ("lunch 18 at subway") fills the fields (8.3).
- Category chips most-used first, then "All categories" → category sheet.
- Recent payment chips: DECISION-PENDING X20-RECENT (deferred by the person, 15 Oct 2026); not in the v1 design.
- Save label carries the amount ("Save $24.00").

**Choose a category (`X21CategorySheet`)**: "Find a category"; all categories; "New category". Colours can repeat (DESIGN 2.4); the name identifies the category.

**Date, account, currency (`X22DetailsSheet`)**: date chips; month calendar (weeks start Monday; future days not selectable); Paid with, Currency, Tags; **Done**.

**Split a payment (`X23Split`)**: split bar uses largest remainder (4.1). Parts: category, amount, Remove; "Add a part"; "Left to split". "Save split" is active only when nothing is left.

**Add expense, voice, listening (`X24VoiceListening`) and Add expense, voice, filled (`X25VoiceFilled`)**

- Listening "on this phone": **Stop**, live transcript. Nothing is saved until Save.
- After Stop or 1.5 s of silence: transcript stays; **Form** ("4 filled · 1 to check").
- Voice-filled fields: check, green outline. Unsure fields: dashed, "(check)". "Green: filled from your voice. Dashed: please check."
- "Speak again"; "Save $40.00".

**Add transfer (`X26Transfer`)**: From (balance), To (for a card: what it owes), Date. "A transfer moves money between your own accounts. It is not counted as spending." "Save transfer". Sample: $1,240 Checking → Visa, 22 Oct.

**Transfer, two currencies (`X26bTransferFX`)**: You send, They receive, Rate you got (with the day's mid-market rate), Fee (share of what is sent). **What this transfer costs** $18: fee $12.00 + $5.96 rate difference (13.11): "Fee $12.00, plus $5.96 from the rate difference. Saved as a fee, not as spending." Split bar. Date, Service, Note. "Save transfer".

**Scan QR receipt (`X27ScanQR`)**: "Read on this phone. Nothing is sent." "No QR code? Take a photo" → Receipt check.

**Receipt, check fields (`X28ReceiptReview`)**: read fields outlined; "Tap another line to change a field"; Where, Date, Total, Category; "Keep the receipt image" (encrypted on this phone); "Save [amount]".

**Microphone permission (`X87MicPermission`)**: dialog before the system prompt. Listens only while held or until Stop; speech becomes text on this phone; no audio is saved or sent. "Allow microphone"; "Not now".

**Add, chooser (`X29AddChooser`)**: five options; the context option first (5.3). Long-press Add to speak.

### 6.4 Inbox and import

**Inbox (`X60Inbox`)**

- "[n] to check · on this phone". Hero: total of ticked items. Source chips with counts (control row).
- **Needs a decision**, one at a time ("1 of 3"): transfer, same purchase twice, refund.
- **Ready to confirm**: unsure items are not ticked; unsure category shows "?".
- Confirm bar ("Confirm 8 ticked, $412.36") sits after the list, in the scroll flow.
- Tap a category to change it. Swipe left to delete (undo). After a category change, offer once: "Always use [category] for [merchant]?".

**Inbox item, edit (`X61InboxItemSheet`)**: source raw text and line ("From First Bank statement, line 18"); editable Name, Amount, Date, Category, Account; switch "Always use Groceries for PX Market" ("Creates a rule for next time"); Delete, **Confirm**.

**Inbox, empty (`X62InboxEmpty`)**: "0" (known zero). "Nothing to check. Everything captured is confirmed." Last capture by source → Capture sources.

**Import (`X63ImportHub`)**

- The app reads the file on this phone and sends drafts to the Inbox. The user confirms each.
- **Import types** (8): bank or card statement (PDF, CSV, Excel), broker positions (CSV or screenshot), payslip, loan statement, insurance policy, receipt photo, QR receipt, bank formats (OFX, QIF, CAMT.053, MT940).
- **Saved layouts** (name, type, use count). **History** → `X68ImportDone` (holds the undo). Undo works until that import's items are confirmed.
- Files can also be shared from the bank app or Files.

**PDF password (`X64PdfPassword`)**: names the bank; show/hide; "Remember for [bank]" (secure storage only); "Open PDF", Cancel.

**Import, preview (`X65ImportPreview`)**: facts Rows / Already in app / New; "Matched your saved layout "[name]"". Preview rows are drafts and open nothing. "Send 36 to the Inbox"; "Wrong layout? Teach again"; "The file copy is deleted after import."

**Teach once (`X66TeachOnce`)**: the user taps Date, Details and Amount of one row and the sign words (money out DR, money in CR). The app then reads the next statement without asking.

**CSV mapping (`X67CsvMapping`)**: each column → Date, Details, Money out, Money in or Ignore; date format; decimal mark; preview; "Save layout and continue".

**Import a payslip (`X69Payslip`)**

- Net pay $8,200: "Net pay matches your 1 Oct salary deposit." Gross $10,400 = net + tax $1,476 + pension $520 + share purchase plan $204.
- One payslip fills 5 areas (Income, Tax, Retirement, Investments, Benefits); each field shows "Goes to: [area]". "Add to these areas". Tax withheld also shows in Plan > Tax.

**Import a policy (`X69bPolicyImport`)**: 8 editable fields read on this phone (insurer, type, covered, cover, excess you pay, premium, renews, policy number). **It also adds** a repeating premium, a calendar renewal and an emergency sheet line. "Save policy". Sample DriveWell, car, $780 a year, renews 4 Nov.

**Import, done (`X68ImportDone`)**: count sent, split ready to confirm / need a decision / no category. "Open the Inbox". "Undo this import" removes every item of this file; works until they are confirmed.

**Import error (`X88ImportError`)**: neutral mark; "This file has no rows the app can read" and what happened ("[file] looks like a photo of a page."). "Read it as a photo (text recognition)", "Teach the layout", "Choose another file". "Nothing from this file was added."

### 6.5 Spending

**Spending, money out (`X30SpendingOut`)**: one page; Search in header; no sub-tab row (5.2, SPEND-TABS). Rows open Money in, Budget, Repeating, Where it goes, All payments and Edit limits.

- **Hero "SPENT"**: always the **total spent with the limit for the same period**, date range and limit status. Current month: "$X left". Past periods: "$X over the limit" only when over; else "within the limit". Averages show only as the dashed chart line.
- Samples: 1W $1,560 ("October: $1,260 left of $5,200"); 1M $3,940 of $5,200; 6M (May–Sep) $21,080 of $26,000; 1Y (Oct 2025 – Sep 2026) $48,060 of $62,400.
- **Chart**: neutral bars, no section colour on data; partial month hatched; dashed average (DESIGN 7.2 PeriodBarChart).
- **Chips 1W · 1M · 6M · 1Y** (default 1M; control row), then one factual highlight from the user's own history:
    - 1W: last 7 days, daily bars, average a day.
    - 1M: daily bars, average a day ("AVG $303 · INCL. RENT" when rent is in the month); a bar above the scale has a break mark and label. Highlight: "Same days in September: $4,005. October is $65 lower."
    - 6M, 1Y: complete months; current month hatched. Highlight: highest month or 12-month total.
- **By category**: Needs / Wants (isEssential); one ring per category = share of its limit (dashed for fixed bills), "left" or "Paid" → Category detail. Table: spent, limit, left, 12-month average.
- Rows Repeating → `X34Repeating`, Money in ("$8,200", "October · avg $9,267 a month") → `X31SpendingIn`. Links All payments, Edit limits.

**Spending, where it goes (`X30cWhereItGoes`)**: period button; "Of your $8,200 money in so far: spent 48%, kept 52%." One control "% of spending" / "% of money in". Per category %, amount, bar on one 0–50% scale, 12-month average mark. "Transfers between your own accounts and reimbursable payments are not counted."

**Spending, money in (`X31SpendingIn`)**

- Hero per period (1M $8,200; 6M May–Oct $49,200; 1Y $111,200); chips **1M · 6M · 1Y** (default 1M); one highlight ("Salary on 1 Oct. Kept so far: $4,260, 52%."; "Highest month: March, $16,400 with the bonus.").
- **Where money in went** (1M, 1Y): **Spent** = Needs + Wants; **Kept** = Invested + In cash (4.4, Appendix B). Period bar over a 12-month-average bar; fixed order Needs, Wants | Invested, In cash. A planned investment not yet paid is named ("$0 · VTI due 25 Oct"). Shares add to 100%.
- Next income ("in 19 days"). **Sources**, 12 months. Owed to you (Expected).

**Spending, budget (`X32Budget`)**: kept as a screen; Spending shows the same content. Ring per limit (today tick on variable limits, dashed for fixed bills); → Edit limits.

**Edit limits (`X33EditLimits`)**

- **Save** in header → Spending. Total limit $5,200 ("The sum of 8 category limits.").
- Per category: 12-month average and the limit. "Add a category limit".
- "Carry unspent money to next month": off by default (each month starts fresh).
- Limits are the user's own numbers; the app only compares.

**Spending, repeating (`X34Repeating`)**: per month ($2,084), per year, count by schedule ("5 monthly · 1 yearly · 1 trial"). 1–31 billing-day strip (dot size = amount; paid dimmed). List by date with neutral fact badge ("was $15.49", "trial ends", "was $720"). Empty only with none recorded: "To add a repeating payment, tap Add."

**Repeating payment (`X35RepeatingDetail`)**

- Netflix $17.99, "Up $2.50 from $15.49", $215.88 a year. Edit in header.
- Last 6 payments: an expected payment not yet charged is not drawn as paid.
- Cancellation address is inert local text (no browser, copy or share action).
- "Add it to the Inbox to confirm" (off: added automatically). "Stop repeating" (secondary).

**Category detail (`X36CategoryDetail`)**: spent, left, limit bar with today tick; facts used %, month gone %, 12-month average; monthly columns with average and limit lines; top places; payments newest first; "All [n]".

**All payments (`X37Transactions`)**: search; filter chips; payments by day. After a save: toast with Undo ("Lunch $15.00 added to Dining").

**Filter payments (`X38FilterSheet`)**: Period (This month, Last month, This year, Custom); Show (Money out, Money in, Transfers, No category); Accounts, Categories, Tags, Amount; "Clear"; "Show 42 payments".

**Payment detail (`X39TransactionDetail`)**: signed amount, merchant, account, source; Category (or "Split into [n]"), Tags, Note; **Split** card with Edit; switches Reimbursable ("Not counted as your spending until paid back") and Refund expected; receipt image (on this phone); similar payments; "Delete payment" → delete dialog.

**Delete payment (`X39bDeleteDialog`)**: "Delete this payment?"; "You can undo for 5 seconds after deleting."; "Delete payment" as filled neutral grey button (DESTRUCTIVE-ROLE, DESIGN-HTML-015); "Keep it".

### 6.6 Wealth

**Wealth (`X40WealthOverview`)**

- **Hero**: net worth (no (i) button), period change, target line when one exists (6.8).
- **Chart**: Net worth, Investments (whole portfolio, as on X43) and Cash (cash you can use) on one scale from $0; no area fill. Chips **1M · 1Y · 5Y** (default 1Y; control row). **1M = last 30 days (rolling)**, not month to date; the label says so. Short history: "Missing", "History starts [month year]", empty chart. Table: month-end values.
- **You own / You owe**: one card, two tabs (You own first); split bar (largest remainder, 100.0%); type tiles → their screens.
    - Tile facts: Investments ("+0.4% today"), Retirement ("401(k) · Est."), Cash and bank ("2 accounts"), Deposits ("Est. · 12 Nov"); Car loan ("22 payments left"), Visa card ("Due 22 Oct").
    - Empty types are dashed "None recorded" tiles (own: Property, Gold and silver, Bonds, Other; owe: Other money owed) → Add: choose type. Not a second add control.
    - DECISION-PENDING: CONTROL-ROW-SCOPE (the tabs) and ADD-CONTROL-SCOPE (the dashed tiles). If a card-level switch counts as a control row, You own and You owe become two stacked cards.
- **Not in net worth** (Expected): unvested shares (today's price, Est.), owed to you, dividends next 6 months (Est.).
- No "What changed this month" block; it is in About this number (4.7).

**What you owe (`X46Owe`)**

- Total $9,640; loans use the debt data colour (DESIGN 2.4). Payments a month $1,660 (20% of money in); interest and fees 2026 $630 (loan $470, fees $160 → Tax and year); 1 loan, 1 card.
- **Loans**: paid off 58% ($11,600 of $20,000); left $8,400 (22 EMIs of $420); 7% fixed; last EMI Aug 2028 (30th) → Loan detail.
- **Cards**: full $1,240 (due 22 Oct); minimum $40; paying account after payment (→ Account detail); limit used $1,240 of $6,000 (21%) → Card detail.
- **Other**: "Other money owed · None recorded"; ""None recorded" means nothing is entered."

**Account detail, checking (`X41AccountDetail`)**

- Balance $6,450; "Lowest expected before 1 Nov: $4,035 on 30 Oct."
- Last 30 days from recorded balances. A day without a recorded balance is not drawn as zero.
- Switches "Counts as cash you can use", "Include in net worth".
- Payments due from this account (5 · $2,415); Recent; last statement; interest earned this year.

**Account detail, retirement (`X41cRetirement`)**

- Total "Est." "since [last statement date]". Estimate chart: last statement as a solid point, rule estimate dashed to today; facts last statement, added since, growth (Est.); parts add up to the change.
- **Rule** (contribution, growth rate). Update value → `X41bUpdateValue`; the estimate restarts from the new value.
- Types: 401(k), IRA · Roth IRA, EPF, PPF, NPS, Superannuation, Workplace pension, Other pension. Values from statements or the user's rule; no pension portal connection. Data-model subtypes are open (SPEC-SYNC-001).

**Account detail, cash and bank (`X41dCashBank`)**: cash you can use; "Available until 1 Nov · $19,035 · $21,450 less $2,415 due before 1 Nov" → `X14ToUseBreakdown`; **Until your next income**: expected balance per cash account, lowest point marked; facts lowest expected (→ Cash flow), due before [date] (→ Calendar), next income; accounts → `X41AccountDetail`.

**Account detail, car (`X41eCar`)**: value Est. by depreciation rule; value and loan left on one scale to the last loan payment difference; Update value.

**Account detail, term deposit (`X41fDeposit`)**: value Est. from rate; term bar start to maturity; put in, interest so far (Est.), at maturity ("in [n] days"); Update value.

**Update a value (`X41bUpdateValue`)**, sheet ("Save value", Cancel): Estimated today $24,010 ("Est. · from your rule"); last real value $22,700 (31 Jul). New value and statement date restart the estimate with the rule ($500 a month plus 5% a year).

**Add, choose type (`X42AddAssetType`)**: Cash (Bank account, Cash); Investments (Broker account, Bonds, Gold and silver, Shares from work); Retirement (X41c types); Deposits (Term, Recurring); Things (Property, Vehicle); You owe (Credit card, Loan, Money borrowed); Other (Money lent, Other). Only the deposit form is designed. Data model for direct bonds, recurring deposits and pension subtypes is open (SPEC-SYNC-001).

**Forms for each type. Add deposit (`X42bAddDeposit`)**: Name, Amount, Rate per year, Interest added, Start date, Matures, Renews automatically; "Counts as cash you can use" off (locked until maturity). Value today $10,280 Est., interest so far +$280 Est., $10,312 at maturity 12 Nov ("The app updates the value every day from the rate."); "Save deposit". Other types use the same layout:

| TYPE | REQUIRED FIELDS | OPTIONAL FIELDS |
|---|---|---|
| Bank account | Name, balance today | Bank, currency, counts as cash (on), include in net worth (on) |
| Credit card | Name, limit, current balance | Statement day, due day, minimum rule, paying account, annual fee and date |
| Investments (broker account) | Account name | Holdings: ticker search, quantity, cost and date. Or import a CSV or screenshot |
| Shares from work | Employer, ticker, plan type | Vest schedule, shares per vest, purchase plan dates, tax method |
| Pension | Name, value today | Monthly contribution, employer part, rate, statement date |
| Deposit | Amount, rate, start, maturity | Interest frequency, renews automatically |
| Property | Name, value today | Ownership share, linked loan, purchase price and date |
| Gold and silver | Weight, unit, purity | Price source or manual price |
| Vehicle | Name, value today | Depreciation per year |
| Loan | Name, amount left, EMI, rate, rate type | Lender, end date, prepayment rule, paying account |
| Money lent / borrowed | Person, amount | Due date, note |

**Account detail, loan (`X47LoanDetail`)**

- Left $8,400: "22 EMIs of $420. Last one in Aug 2028." Paid off 58%; 7% fixed; interest paid $1,840; prepayment (user's rule).
- **Next payments** from the exact monthly schedule (13.7, 13.16): 30 Oct 2026 interest $49, principal $371, left $8,029; 30 Jan 2027 interest $42, principal $378, left $6,903.
- Paid from Checking; Full schedule → Calendar; Try an extra payment → Tools.

**Account detail, card (`X48CardDetail`)**

- Close and due dates come from each card's data (DESIGN-HTML-015; sample 12 Oct, 22 Oct).
- $1,240: "Full amount. Minimum $40. Due in 9 days."; paying account after payment → Account detail.
- Limit used 21% ($1,240 of $6,000, $4,760 left), new spending since the statement. Statement closes, interest and fees, annual fee, instalment plans ("None recorded").

**Shares from work (`X49VestTracker`)**

- Shares coming in 12 months at today's price ("Est.", 4.9; $197.47). Next: 15 Nov, vest, 20 shares, $3,949 Est.
- Unvested 160 ($31,595 Est.); tax withheld on vests this year; of net worth 17% in NVDA → holding.
- A past vest date creates an Inbox item to confirm shares received and shares sold for tax. Holding now: NVDA 158 shares, $31,200.

### 6.7 Investments

**Investments (`X43Investments`)**, from Wealth; Back and (i)

- **Hero**: value and period change. Period value line as background; dashed line = **cost basis**.
    - Chips **1D · 1M · 1Y · All** (default 1D; control row). 1D: market open to now (or close). All: all recorded history ("since Oct 2023").
    - Change = change in value − money put in. Percent = **time-weighted return** (4.5, 13.12), the only return measure here. Under the chips: "Change: value less money put in. Percent: time-weighted (TWR). Dashed line: cost basis."
- **Facts**: Unrealised (amount, % on cost), Realised (in [year]) → Gains and tax; Largest (share, holding) → holding.
- **Holdings** (look: DESIGN 6.7 HoldingsCard, 7.2 BubblePack, Treemap):
    - Group menu **Holdings · Sectors · Markets**. Views **Bubbles · List · Tree** (default Bubbles; 44 × 44 pt). Filter icon has a dot when not default.
    - Total line: value the filters keep ("[n] holdings", or "share of [total]" with a filter) and period gain. Period menu **Today · Since bought** sets the colour of every bubble and tile.
    - **Bubbles**: area = value now; **colour = gain for the period** (green up, red down, grey none; stronger for larger change); full spoken label on every bubble; minimum diameter 50 pt. Key: "Size = value", colour scale with both end values, "Colour = gain [period]".
    - **Tree**: same rules; sort does not apply. Open question TREE-TARGETS: small tiles can be under 44 pt; List is the full accessible path until decided.
    - **List**: asset-class badge (monogram fallback; optional audited public logo, 10.5); name and period gain "$ · %"; cash shows "no return". Sectors/Markets: one row per group; tap shows its holdings. Rows → Holding detail.
    - **"Filters and sort"**: Account, Asset type, Status (**Held now · Sold in [year]**); sort (Value now, Gain %, Gain, Invested), order, count (All, First 5). Filters apply to every grouping; shares are of the value shown; in gain sorts cash goes last. **Sold** lists each sale of the year with realised gain ("realised in 2026 · 2 sales"); List view only.
    - **Hidden amounts**: List view only; amounts masked in text and speech; percentages stay.
- **By currency**: value and share (largest remainder) → Allocation.
- **Regular investments**: one row per repeating investment (RecurringRule.kind = investment) and scheduled vest ("VTI · 25 Oct · $500"; "NVDA · 15 Nov · $3,949 Est."). Vest value at today's price has "Est.". No source account, totals or add button. Empty "None recorded". → Repeating detail or Shares from work.
- **Total gain since you started** (4.5): Price, Dividends, Currency; equals unrealised + realised + dividends; "Started [year]; value history in the app starts [month year]". Do not use the prototype title "Gain since first buy": banned word (16.3).
- Links Returns, Dividends ("[amount] in [year]"), Gains and tax.
- Open question ALL-BASIS: hero "All" gain (all history, incl. sales) and "Since bought" gain (unrealised, held now) use different bases.

**What the numbers mean (`X43jGlossary`)**, sheet: Invested $98,200; Unrealised +$31,600; Realised +$2,140 in 2026, +$6,880 all time; Total gain +$40,430 = $31,600 + $6,880 + $1,950 (each counted once); TWR +18.6% (1 year); XIRR +16.9% (1 year; under 1 year shows the period return, not a rate per year); CAGR = multi-year TWR as one rate per year; Missing = records absent, never 0%. Each screen names its measure. → `X43gReturns`.

**Holding detail (`X44HoldingDetail`)**: value and price line (no price chart in the v1 hero); invested, unrealised, realised, dividends, share of investments and of net worth; share sources (vests, purchase plan, bought); lots (date, source, shares, cost per share, gain; "All 9"); next vest; sector. History: later (not in v1).

**Allocation, by class (`X43cAllocationClass`); Allocation, by market (`X43bAllocationMarket`); Allocation, by sector (`X43dAllocationSector`)**

- Chips Class, Market, Sector, Currency (control row). Total $129,800. Donut and legend % by largest remainder.
- Sector covers single stocks only (Technology $42,400, Financials $2,600, Health care $2,400 of $47,400) unless "Include what is inside funds" is on (needs imported fund holdings).
- **Target mix** ("Not set"). With a target: target % and difference in amount per group (13.3, 13.15).

**Gains and tax (`X43eGains`)**

- Chips 2026, All time (control row). Unrealised +$31,600 = +32.2% on $98,200 invested. "Unrealised gain moves with prices. Realised gain is fixed at the time of a sale."
- **Unrealised, by holding** (11), highest first. Brokerage cash is not shown.
- **Sales in [year]**: AAPL part +$1,610; VXUS whole +$530; holding period when recorded.
- Cost method, lots, tax records (local table). CSV export is disabled (10.5).

**Dividends (`X43fDividends`)**: $410 in 2026; last 12 months $505; next 6 months $245 (Expected, Est.). 18-month calendar: solid received, dashed expected, "—" for none. By holding: yield on cost. "Expected dividends repeat last year's dates and amounts. They are estimates."

**Returns (`X43gReturns`)**

- XIRR (13.12) 1 year in hero; both measures shown here, each named. X43 shows only TWR.
- **Portfolio vs ACWI index** (TWR), difference in points. 5 years and All "Missing" (history starts Oct 2023).
- Later (not in v1): period control (1M, 1Y, 3Y, 5Y, All), money put in vs value chart, benchmark chooser.

**Investment insights (`X43hInsights`)** ("Calculated on this phone"): top movers (NVDA +1.1%, JPM −0.4%); largest holding (NVDA, 24%); currency split; **Currency effect** −$694 since you started (DESIGN-HTML-015); money added each month; cost basis and lots; holding periods; fees; corporate actions; target mix ("Not set"). Each row → its detail.

**Update positions (`X45UpdatePositions`)**: "Text read on this phone. Image not kept." **What changed** ("[n] of [m]"): only differences, each ticked: quantity change ("Was [n] shares") or new holding. Matching holdings are named, not listed. "Apply 2 changes". "Only differences are shown. Prices update separately."

**Investments, offline prices (`X89OfflinePrices`)**: banner "Prices from 2 days ago. You are offline. Values use the last prices." Value at last prices "Est."; Today "Missing" (never +$0); Last prices (date, time); Source "Public prices · Only symbols you turned on"; Next update "When online · Values stay Est. until then". → Investments.

### 6.8 Plan

**Plan, calendar (`X50Calendar`)**

- Sub-tabs and Tools in header. No hero number (the lowest balance is the Cash flow hero).
- **Month grid** (Monday first), first of month to about 30 days ahead (1 Oct–15 Nov). ●, ◆, ★ as on Home; at most 3, then "+N". Amounts only in spoken label, list and Day sheet. Days with events → `X51DaySheet` (targets ≥ 44 pt). Legend in words.
- "Checking lowest · 30 Oct · $4,035" → forecast.
- **Before next income** ($2,415 from Checking), then **From next income** (income Expected, renewals, vests Est.) to the grid's end.

**Plan, cash flow (`X50bCashFlow`)**: hero = lowest expected balance of the main paying account and its date. Step chart to the next income; event-day balances only. Table: each event with balance after. Payments before [next income]; note on card charges and accounts not shown. Later (not in v1): all accounts with their lowest balance.

**Calendar, a day (`X51DaySheet`)**: payments that day (→ their screens); facts count and total, balance before and after (Checking $6,405 after 20 Oct, $5,165 end of 22 Oct; → Cash flow); "Add a payment on 22 Oct". No Done button; close by swipe down, close control or tap outside.

**Plan, goals (`X52Goals`)**

- Hero: assigned to goals, total targets, amount to go. Goal vials: equal height = target; level = share reached.
- **Net worth target** (above goal cards, when one exists): "$187,900 of $1,000,000"; "$812,100 to go · counts net worth"; "By Dec 2040 · $4,777 a month" with "Est. · amount to go ÷ months left" (13.2 simple form, no return) → Financial independence in Tools.
    - The target **measures** net worth (or the part in "counts"). It **assigns no money** and is not in "Assigned to goals" or "Not assigned".
    - DECISION-PENDING: NW-TARGET-PACE (prototype row "At +$16,900 a year · 2074 · Est.", from the last 12 months' change, needs a wording and Est. rule).
    - Under every net worth number (Home, Wealth), once: "18.8% of $1,000,000 target · Dec 2040" with a bar → Goals.
- **Goals**: name, "of [target] · [date] · [account] [%]", assigned amount.
- **Allocation rule**: use the linked account's current value in the main currency, including cash in that account. Do not use cost basis or the combined Investments group when one account is linked. Show account, percentage, value date and source. A missing account value stays missing.
- **Not assigned** = what you own − amounts assigned. Assigning money does not change net worth. DECISION-PENDING NOT-ASSIGNED-DISPLAY: not shown in the v1 design.
- Empty: "To add a goal, tap Add."

**New goal (`X53NewGoal`)**

- Type chips **Money from accounts, Net worth target** (control row). Name, Target amount, By (optional).
- **Money from**: linked accounts, value today, % assigned; "Add an account".
- Result: amount today, "[%] of [target]. To reach it by [date]: $813 a month." Monthly = amount to go ÷ months left. Sample: Japan trip, Checking 30%, $1,935 of $6,000 (32%), by Mar 2027: $813 a month.
- Net worth target: **Counts** (Net worth; Investments and cash; Chosen accounts) replaces "Money from". No assignment.
- "Save goal".

**Plan, protect (`X55Protect`)**: premiums a year, next renewal, policy count, premium by policy; **Cover** ("[n] of 6 types"); unrecorded types "None recorded" with ""None recorded" means nothing is entered. It does not mean you have no cover."; **Policies** (health cover used as a meter); **Emergency sheet**.

**Policy detail (`X56PolicyDetail`)**: cover $50,000, used $1,200 (claims paid), left $48,800; premium $210 a month, next 28 Oct from Checking; claims (claimed and paid dates, amount); people covered, policy number, claim steps and phone (on this phone), nominee.

**Emergency sheet (`X57EmergencySheet`)**

- "It stays on this phone. It holds no passwords. It has no export or share control."
- Facts Sections ("[n] of 7"), Nominees, Passwords ("None · never stored").
- 7 sections: accounts, investments and pension, insurance policies, loans and cards, nominees, will and documents, people to contact; each "[n] entered" or "None recorded" → its screen.
- "Preview the sheet": on this phone only; nothing is sent; no export or share (10.5).

**Plan, tax and year (`X58Tax`)**: money in this year with out and kept; tax dates the user entered; tax-saving room against the user's limit; "For your tax return" totals (interest, dividends, rent, realised gains, tax withheld, tagged medical and donations); fees and interest paid. No Export action.

**Tools (`X59Tools`)**: "Calculators show results from the numbers you enter. They do not suggest what to do." Groups (section 13): **Invest and goals** (Monthly investing, Goal amount, Target mix, Financial independence, Withdrawals, Inflation); **Home and loans** (Home loan, Rent or own, Loans); **Cover and cash** (Life cover, Emergency fund, Currency).

**Home loan calculator (`X59bHomeLoanCalc`)**: layout for all calculators. Inputs Home price, Down payment (% and amount), Rate per year, Years. Result EMI, loan, total interest; loan left by year end. 13.7 design sample: $400,000, 20% down, 6.5%, 25 years → EMI $2,161, loan $320,000, interest $328,210. "Save these numbers" = local preset. Results come only from the user's numbers.

### 6.9 Monthly close and settings

**Monthly close (`X70MonthClose`)**, Plan chrome

- Step [n] of 5, time left. "You can stop and continue later. Each step can be skipped."
- Steps: Import statements (a missing one is named "missing"); Clear the Inbox; Update values; Check open items (reimbursements, transfers); Save [month] (snapshot and summary). Every step except the last has Skip. "Continue: [next step]".

**Month summary (`X71MonthSummary`)**, Plan chrome: kept $3,880, "47% of money in. August: 41%."; kept % for 6 months; net worth → Wealth; spending $4,320 of $5,200 → Spending; largest category Rent $1,800 → Category detail; fees and interest → Tax and year. "Save and finish" saves on this phone, then makes a recovery snapshot on this phone (14).

**Settings (`X80Settings`)** ("Everything is on this phone." "Encrypted. No account. No server.")

- **Capture**: Capture sources ("[n] on"), Categories and rules, Import layouts.
- **Money**: Main currency, Accounts, Month starts on, Number format.
- **Screens and widgets (WIDGETS-001)**: "Main number on Home" → `X13MainNumberSheet`; Home, Spending, Money in, Wealth, Investments, Calendar, Goals, Protect, Tax; each "[n] widgets" or "[n] shown" → edit mode; "Restore the default widgets".
- **Safety**: App lock, Recovery on this phone (→ `X83Backup`), Privacy and network ("Prices only").
- **App**: Features ("Simple mode"), Appearance, About and open source.
- No export, cloud backup or sync row (2, 10.5).

**Capture sources (`X81CaptureSources`)**: "Each one is off until you turn it on."

- **Automatic**: Payment notifications (Android only; chosen bank apps; full text not kept, 8.13); Apple Wallet accounts (verified FinanceKit; iPhone, where available; off in the sample, 8.14); Staging folder (app-owned, on this phone; PDF and CSV, 8.15); Repeating payments.
- **Prices** (network): "Price and instrument updates" ("Sends public symbol and asset IDs only. Never amounts, holdings or account names.", 10.5).
- **Status**: each source that is on, last run, new items.
- "Statements from mail apps": "No email connection. Share the file to Contour." → Import (8.12).

**Gmail bridge (`X82GmailBridge`)**: obsolete, unshipped; no route, setup action or feature switch. Removed from the design gallery (SCREEN-SET-001). History only: the removed gallery entry showed the guide "Statements from mail apps": "Contour does not connect to Gmail or any email account." Share the PDF or CSV from the mail app (no link opened); check it in the Inbox (read on this phone, file copy deleted). **Not used** (each "None"): email account access, cloud drive file, scripts in your account, email passwords. Use local attachment input (8.12).

**Private recovery (`X83Backup`)**, titled "Private recovery" (14)

- Last snapshot (date, time, size). "Encrypted. It stays on this phone."
- "Weekly snapshot" (runs when the phone allows; finishes after unlock); "Every week"; "Up to 8 snapshots". Snapshots list ("[n] of 8": date, time, "checked", size). A completed month close adds one.
- "Make a snapshot now" (primary). "Restore a snapshot" asks to confirm and replaces the data on this phone.
- **What recovery cannot do**: recover a lost, removed-app or reset phone. It is not in iCloud, Google Drive or phone-to-phone transfer.
- No folder, export, password-sharing or merge control.

**Categories and rules (`X84Rules`)**: "Rules come from your corrections. The app asks before it creates one." One "+" (Add a rule) in header. Control Categories / Rules. Rules by use ("When name has [text]", category, use count).

**Features (`X85Features`)**: "Turn on only what you need. Turning one off hides it and keeps its data." Switch "Simple mode". Advanced, each off by default: Returns, Compare with a benchmark, Joint accounts, Custom budget periods, Trips, projects, events, Money flow chart, Report builder, Simulations, Time machine, Family view (17.4).

**Privacy and network (`X86Privacy`)**

- "This app talks to [n] service." (only services turned on). "Only after you turned it on."
- **Network**: price service ("Sends public symbols only. Never amounts, holdings or account names." → Capture sources); "Turn off all network" ("Prices stop. Everything else works. Asks you to confirm.").
- **On this phone**: Database (encrypted, size), Speech recognition, Text recognition, Recovery snapshots.
- "Delete all data": filled neutral grey button (DESTRUCTIVE-ROLE, DESIGN-HTML-015). After confirm, remove records, snapshots, keys and cached prices from this phone.

### 6.10 System patterns

- **Toast with undo** after save, delete, confirm and import: 5 seconds.
- **Confirm dialogs** only for deleting data, restoring a backup and turning off all network.
- **Permission explainers** before each system permission (microphone, camera, notification access, photos).
- **Errors** follow 3.2: what happened, what the user can do, nothing lost.
- **Loading**: show cached values at once; mark values that are updating.
