# Contour — Screen reference (SCREENS.md)

16 October 2026. Split from DESIGN.md 14.4. Screen names, order and screen set match the built prototype (final UI and flow round, 16 October 2026).

## Purpose

- Screen reference for builders: template, section, blocks in order, labels and sample values to match.
- Visual reference: the built prototype contour-design.html (Obsidian dark and Light). The name in brackets (for example v_owe) is its view function.
- DESIGN.md owns components, tokens and charts. SPEC.md owns behaviour and number definitions. If this file disagrees with them, they win.
- All 90 screen ids use the Obsidian anatomy (DESIGN-HTML-014). They form 75 screen groups. The prototype grid shows the 75 groups in 75 cells on 25 pages. Reference-only screens (X10a–X10c, TypeA–TypeG) are not built.
- X10tHomeTrial is removed from the screen set. It is reference only and not built. Its Home cash-flow cards stay as Home library widgets. X82GmailBridge stays as history only (SCREEN-SET-001).
- **Screen groups (SCREEN-SET-001).** Some ids are a state or a type variant of one screen, not a separate screen. Build each group as one screen with one template. The prototype grid shows each group in one cell (75 cells) with a button per member.

| SCREEN | MEMBERS (STATE OR TYPE) |
|---|---|
| Home X10 | Normal X10; first run X03; first days of a month X11; amounts hidden X12 (states) |
| Add expense X20 | Typed X20; voice listening X24; voice filled X25 (states) |
| Inbox X60 | Items X60; empty X62 (states) |
| Account detail X41 | Checking X41; retirement X41c; cash and bank X41d; car X41e; term deposit X41f; loan X47; card X48 (types: one DetailScreen template, type sections) |
| Investments X43 | Normal X43; offline prices X89 (states) |
| Allocation X43c | By class X43c; by market X43b; by sector X43d (one route with a group argument) |

- **List names.** Each screen has one name: its list name in the prototype. The index, the entries below and the grid use the same names in the same order. Groups stay together, main id first. Many names use "section, view": for example "Spending, money out", "Plan, goals", "Account detail, loan".
- **List names name screens in the gallery**; sheet and dialog titles are the words in the app. Titles: X40b "About net worth"; X13 "Main number on Home"; X14 "How $19,035 adds up"; X21 "Category"; X22 "Details"; X38 "Filter"; X61 "Check this payment"; X41b "Update value"; X51 "Thursday, 22 October"; X43j "What the numbers mean"; X29 "Add"; X64 "This PDF is locked"; X39b "Delete this payment?"; X87 "Use your voice to add payments".
- Components in code come from DESIGN.md 5–7. "Section" is the route section (DESIGN.md 2.3).

## Rules for every screen

- **Header.** DetailScreen = DetailHeader with Back. Import, payslip, policy, Add and monthly-close flows use Close (X). Detail screens keep the tab bar (X15, X35, X39, X43h and X80–X86 included); forms, sheets and dialogs cover it. Flow steps have no tab bar: X23, X28, X33, X42, X45, X63, X65, X66, X67, X68, X88 (Index: "DetailScreen (flow step, no tab bar)").
- **One number.** At most one hero number. Settings-type screens use an 0Hero without a number: kicker, a short statement, one line.
- **Sheets and dialogs.** The screen behind is dimmed (overlay.scrim) and inert. A sheet has a grabber, a title and content; it closes by swipe down, the close button or a tap on the scrim. A dialog is a centred alert dialog: the title shows once and there is no grabber. Its title is its spoken name.
- **Buttons.** One primary action in action.primary.fill with text.onSection. Secondary: AppButton ghost or a text button. Delete: AppButton destructive (neutral grey, trash icon, explicit verb; DESTRUCTIVE-ROLE).
- **Colours.** Section colour on chrome only. Flow glyphs ● spending, ◆ investing, ★ money in. Categories data.category (colours may repeat). Debts data.debt. Gain/loss only for signed change. Glow only on chart end points.
- **Numbers.** Sample values follow SPEC Appendix A. Shares from Percent.split add to 100. Unknown = "Missing" or "None recorded", never 0. Estimates carry "Est."; future items "Expected".
- **Charts.** Spoken label with all values and "Show as table" (except preview charts, PREVIEW-CHART). Shape stays when amounts are hidden.
- **Hidden amounts (X12).** "$······" in text, spoken labels, tables, charts and amount inputs. Dates, counts and percentages stay.
- **Text size.** At 200%, rows wrap, values move under labels, grids stack. Targets 44 × 44 pt or more.
- **Older words.** Where an entry says "slab", read 0Hero + GlassCard(stage); superseded colour names map to DESIGN.md 2.3/2.4 roles (see DECISIONS.md, DESIGN-SYNC-001).

## Index

| ID | NAME | TEMPLATE | SECTION |
|---|---|---|---|
| X01 | Welcome | start screen | Home |
| X02 | App lock | start screen | Home |
| X10 | Home | TabRootScreen | Home |
| X03 | Home, first run | TabRootScreen | Home |
| X11 | Home, first days of a month | TabRootScreen | Home |
| X12 | Home, amounts hidden | TabRootScreen | Home |
| X40b | About this number | AppSheet | Home |
| X13 | Home, main number | AppSheet over Settings | Home |
| X14 | Home, available breakdown | AppSheet | Home |
| X15 | Search | DetailScreen | Section of the screen that opens it (Home or Spending) |
| X20 | Add expense | FormScreen | Spending |
| X24 | Add expense, voice, listening | FormScreen | Spending |
| X25 | Add expense, voice, filled | FormScreen | Spending |
| X21 | Choose a category | AppSheet | Spending |
| X22 | Date, account, currency | AppSheet | Spending |
| X23 | Split a payment | DetailScreen (flow step, no tab bar) | Spending |
| X26 | Add transfer | FormScreen | Spending |
| X26b | Transfer, two currencies | FormScreen | Spending |
| X27 | Scan QR receipt | FormScreen | Spending |
| X28 | Receipt, check fields | DetailScreen (flow step, no tab bar) | Spending |
| X87 | Microphone permission | AppDialog (centred) | Spending |
| X29 | Add, chooser | AppSheet | Section of the screen that opens it |
| X60 | Inbox | DetailScreen (DetailHeader(plain) with Back), keeps the tab bar | Home |
| X62 | Inbox, empty | DetailScreen (DetailHeader(plain) with Back), keeps the tab bar | Home |
| X61 | Inbox item, edit | AppSheet | Home |
| X63 | Import | DetailScreen (flow step, no tab bar) | Home |
| X64 | PDF password | AppDialog (centred) | Home |
| X65 | Import, preview | DetailScreen (flow step, no tab bar) | Home |
| X66 | Teach once | DetailScreen (flow step, no tab bar) | Home |
| X67 | CSV mapping | DetailScreen (flow step, no tab bar) | Home |
| X69 | Import a payslip | FormScreen | Home |
| X69b | Import a policy | FormScreen | Home |
| X68 | Import, done | DetailScreen (flow step, no tab bar) | Home |
| X88 | Import error | DetailScreen (flow step, no tab bar) | Home |
| X30 | Spending, money out | TabRootScreen | Spending |
| X30c | Spending, where it goes | DetailScreen | Spending |
| X31 | Spending, money in | DetailScreen | Spending |
| X32 | Spending, budget | DetailScreen | Spending |
| X33 | Edit limits | DetailScreen (flow step, no tab bar) | Spending |
| X34 | Spending, repeating | DetailScreen | Spending |
| X35 | Repeating payment | DetailScreen | Spending |
| X36 | Category detail | DetailScreen | Spending |
| X37 | All payments | TopBar screen | Spending |
| X38 | Filter payments | FilterSheet | Spending |
| X39 | Payment detail | DetailScreen | Spending |
| X39b | Delete payment | AppDialog (centred) | Spending |
| X40 | Wealth | TabRootScreen | Wealth |
| X46 | What you owe | DetailScreen | Wealth |
| X41 | Account detail, checking | DetailScreen | Wealth |
| X41c | Account detail, retirement | DetailScreen | Wealth |
| X41d | Account detail, cash and bank | DetailScreen | Wealth |
| X41e | Account detail, car | DetailScreen | Wealth |
| X41f | Account detail, term deposit | DetailScreen | Wealth |
| X47 | Account detail, loan | DetailScreen | Wealth |
| X48 | Account detail, card | DetailScreen | Wealth |
| X41b | Update a value | AppSheet | Wealth |
| X42 | Add, choose type | DetailScreen (flow step, no tab bar) | Wealth |
| X42b | Add deposit | FormScreen | Wealth |
| X49 | Shares from work | DetailScreen | Wealth |
| X43 | Investments | DetailScreen | Wealth |
| X89 | Investments, offline prices | DetailScreen | Wealth |
| X43j | What the numbers mean | AppSheet | Wealth |
| X44 | Holding detail | DetailScreen | Wealth |
| X43c | Allocation, by class | DetailScreen | Wealth |
| X43b | Allocation, by market | DetailScreen | Wealth |
| X43d | Allocation, by sector | DetailScreen | Wealth |
| X43e | Gains and tax | DetailScreen | Wealth |
| X43f | Dividends | DetailScreen | Wealth |
| X43g | Returns | DetailScreen | Wealth |
| X43h | Investment insights | DetailScreen | Wealth |
| X45 | Update positions | DetailScreen (flow step, no tab bar) | Wealth |
| X50 | Plan, calendar | TabRootScreen | Plan |
| X50b | Plan, cash flow | DetailScreen | Plan |
| X51 | Calendar, a day | AppSheet | Plan |
| X52 | Plan, goals | TabRootScreen | Plan |
| X53 | New goal | FormScreen | Plan |
| X55 | Plan, protect | TabRootScreen | Plan |
| X56 | Policy detail | DetailScreen | Plan |
| X57 | Emergency sheet | DetailScreen | Plan |
| X58 | Plan, tax and year | TabRootScreen | Plan |
| X59 | Tools | DetailScreen | Plan |
| X59b | Home loan calculator | DetailScreen | Plan |
| X70 | Monthly close | FormScreen | Plan |
| X71 | Month summary | FormScreen | Plan |
| X80 | Settings | DetailScreen | Home |
| X81 | Capture sources | DetailScreen | Home |
| X83 | Private recovery | DetailScreen | Home |
| X84 | Categories and rules | DetailScreen | Home |
| X85 | Features | DetailScreen | Home |
| X86 | Privacy and network | DetailScreen | Home |

## Start

**X01 Welcome** — start screen, no tab bar, no header · Home (v_welcome)

1. 0Hero without number: 64 pt BrandMark; kicker "CONTOUR"; title "Know your money in 3 seconds." (titleScreen); line "Enter almost nothing. Your financial records stay on your phone."
2. GlassCard (no title), three rows with a 40 pt icon tile (section colour 14%, 1 px edge), name, grey line: phone "Your data stays on this phone" / "No account. No sign-up. No servers."; eye "You choose what the app reads" / "Files you share, and sources you turn on."; shield "Encrypted backups you own" / "Recovery copies stay on this phone."
3. GlassCard "Your main currency" (meta "required"): SelectRow "US dollar (USD)", line "From your phone's region. You can change it later.", value "USD", chevron. Spoken "Your main currency: US dollar (USD). Change".
4. AppButton primary "Start". Caption "Everything else is optional. You can add accounts, import files, and turn on the app lock from Home." No amounts.

**X02 App lock** — start screen, no tab bar, no header · Home (v_lock)

1. Behind: a fixed generic Home silhouette, blurred 11 pt at 75% — kicker "NET WORTH", "$······", a neutral line shape, two empty card shapes. No real data or chart shape.
2. Centred: 76 pt BrandMark; "Locked" (titleScreen); line "Face ID starts when the app opens. Amounts stay hidden until you unlock." Face ID starts at once.
3. Bottom: AppButton primary "Unlock with Face ID"; AppButton ghost "Use passcode". No amounts, no hero, no data card.

## Home

**X10 Home** — TabRootScreen · Home (v_home)

1. ScreenHeader: "Today", 13 Oct 2026, USD (reader heading only); Hide amounts, Inbox (badge 12), Settings (sliders glyph) on the kicker line; the kicker keeps space for them. Same on X12, X03, X11. Under the title: a Search field (spoken "Search"); it opens X15.
2. 0Hero (number): kicker "NET WORTH" (no (i) button); $187,900 (a tap on the number opens X40b); side figure "+$16,900 · 12 months". Under it: target line "18.8% of $1,000,000 target · Dec 2040" with a 36 pt bar (opens Goals; 44 pt target; NW-TARGET), and a small AreaLineChart of the last 12 month ends with end dot (opens Wealth). Preview chart, no table. No period chips.
3. GlassCard "Quick look" (meta "today"), IconTileGrid(quickLook): Cash $21,450 "available now" (Cash and bank); Card bill $1,240 "Visa · 22 Oct" (next bill only; more cards "+N more · $X by [date]"); Investments $129,800 "+$550 today"; Subscriptions $28.98 "a month" (Repeating). Library tiles, hidden by default: Retirement $24,010 "401(k) · Est."; Deposits $10,280 "Est. · 12 Nov"; What you owe $9,640 "loan and card"; Next income $8,200 "Expected · 1 Nov". Edit: Quick look "Tiles".
4. GlassCard "Next 30 days" (meta "$2,415 due before 1 Nov"; opens Calendar): GlyphTimeline 13 Oct–12 Nov, name and amount per mark, legend in words. Preview chart, no table.
5. GlassCard "This month" (meta "October · day 13 of 31"): tiles Money in $8,200 "Salary · 1 Oct" (Money in) and Spent $3,940 "of $5,200 limit · 76%" with CapsuleMeter (variable), today tick 42%. Then SplitBar of income: Needs, Wants, Invested, In cash with amounts and shares. Tiles stack at 200%.
6. GlassCard "Repeating" (meta "$2,084 a month"; head opens Repeating): SelectRows, no icons: Netflix "18 Oct · monthly" $17.99, Phone "20 Oct · monthly" $45, Health "28 Oct · monthly" $210 (each X35); "All repeating payments" 7 (X34). Text only, no chart or data colour (HOME-REPEAT).
7. GlassCard "Goals progress" (meta "goals · debt paid"): House 66%, Emergency 50%, Car loan 58%, each with CapsuleMeter; row "Put into investments in 2026 $6,000".
8. Footer "Prices 4:00 pm · 9 of 9 accounts updated · snapshot 11 Oct" (last private recovery snapshot, X83). Hidden state: X12.

**X03 Home, first run** — TabRootScreen · Home (v_home_first)

1. ScreenHeader: "Today", "13 October 2026 · USD"; Hide amounts, Inbox (spoken "Inbox, 0 items"), Settings.
2. 0Hero (number): kicker "NET WORTH"; "—"; line "Add your main account to see this number."
3. GlassCard (wide) "Get started" (meta "0 of 5"): CapsuleMeter at 0 (spoken "Get started: 0 of 5 steps done."); five numbered rows with chevron: 1 Add your main account "Balance only, 20 seconds" (X42); 2 Share a bank statement "PDF or CSV from your bank app" (X63); 3 Add your first expense "Type, speak, or scan" (X20); 4 Turn on the app lock "Face ID or passcode" (X86); 5 Set up local recovery "Encrypted, on this phone" (X83). Caption "Each step is optional. Skip any step and come back later."
4. GlassCard (wide) "Next 30 days" (meta "none recorded"): caption "Payments show here when you add an account, a card or a repeating payment." No chart, tile or amount until a record exists.

**X11 Home, first days of a month** — TabRootScreen · Home (v_home_month). Day 2 Oct (SPEC Appendix A).

1. ScreenHeader: "Today", "2 October 2026 · USD"; Inbox spoken "Inbox, 4 to check".
2. 0Hero (number): kicker "KEPT · SEPTEMBER"; $3,880; line "September is not closed yet. Kept 47% of money in. In August: 41%." SplitBar of $8,200: Out $4,320 (52.7%, data.flow.spending), Kept $3,880 (47.3%, data.flow.moneyIn). FactRow: In $8,200 "Salary" (X31); Out $4,320 "spent" (X30); Kept $3,880 "47%" (X71). Table adds "Kept, August: Missing, 41%".
3. GlassCard: check-badge row "Close September" "5 steps, about 8 minutes" (X70). After Save and finish (X71): the hero line starts "September closed" and the row becomes "Make a private snapshot" (X83).
4. GlassCard: Net worth $182,410 "September close, 30 Sep" (X40).
5. GlassCard "Quick look" (meta "today"): Cash $26,190 "available now" (X41d).
6. GlassCard (wide) "Next 30 days" (meta "$3,330 due before 1 Nov"): "Payments before your next income" 8, "Cash $26,190 less $3,330 due: $22,860 available until 1 Nov" (X50).
7. Rest of Home as X10 with 2 Oct values: This month (meta "October · day 2 of 31"): Money in $8,200 "Salary · 1 Oct"; Spent $1,900 "of $5,200 limit · 37%" (tick 6%); Needs $1,900 23.2% · Wants $0 · Invested $0 · In cash $6,300 76.8%. Repeating ($2,084 a month): Spotify 9 Oct $10.99, Netflix 18 Oct $17.99, Phone 20 Oct $45, All repeating payments 7. Goals progress: House 66%, Emergency 50%, Car loan 56%; Put into investments in 2026 $5,500. Caption "In the first 7 days of a month, Home shows last month first." Footer "Prices 2 Oct, 4:00 pm · 9 of 9 accounts updated · snapshot 1 Oct".

**X12 Home, amounts hidden** — X10 structure. Hiding stays on across routes. "$······" (currency mark kept) in text, names, titles, open disclosures and tables; dates, counts, % stay. Charts keep shape and hide amount text (no blank zones). The crossed-eye button restores amounts.

**X40b About this number** — AppSheet over Home · Home (v_about). Opens from a tap on the Home hero number and on the Wealth hero number (no (i) button).

1. Head: kicker "NET WORTH · 13 OCT", title "About net worth".
2. FactRow: Period "13 Oct" (as of 4:00 pm); Currency "USD" (main currency); Coverage "9 of 9" (accounts).
3. $187,900 (numberHero.light); line "Net worth: what you own, $197,540, less what you owe, $9,640."
4. GlassCard (stage) "Change this month" (meta "+$5,490 · +3.0%"): centre-line bars with end amounts: You kept +$4,260 (money in less money out); Markets +$1,780 (price changes); Currency −$550 (exchange-rate effect); Values $0 (updated values, no bar length). Caption "From $182,410 on 30 Sep to $187,900 on 13 Oct. The parts add up to the change." Table: part, amount, basis, total. Spoken "Net worth change this month, 30 Sep to 13 Oct: +$5,490. You kept +$4,260; markets +$1,780; currency −$550. Values $0."
5. GlassCard "Parts" (meta "6"): Investments $129,800 "Prices today, 4:00 pm" Captured; Retirement $24,010 "Statement 31 Jul, then your rule" Est.; Cash and bank $21,450 "Statement 13 Oct, then captured" Imported; Car $12,000 "Your value, then depreciation" Est.; Deposits $10,280 "Interest rule, daily" Est.; Loans and cards −$9,640 "Statements 12 Oct" Imported.
6. Caption "Other currencies use today's rates: INR 84.00, TWD 32.00. "Est." values grow by your rule between real updates." AppButton primary "Done"; link "Open Wealth".

**X13 Home, main number** — AppSheet over Settings · Home (v_main_number). Opens from Settings > Screens and widgets > "Main number on Home".

1. Head: kicker "HOME · MAIN NUMBER", title "Main number on Home".
2. Radio group "Main number on Home", four options ≥ 64 pt (6 pt colour bar, name, grey line, value): Available until 1 Nov "Cash you can use less payments due before 1 Nov" $19,035; **Net worth** (selected, default) "What you own less what you owe" $187,900; Spent this month "Of your $5,200 limit" $3,940; Cash you can use now "All accounts marked as cash" $21,450. Selected: 2 pt edge in its colour, aria-checked true. At 200% the value moves under the name.
3. Caption "This number is the first thing you see on Home. Net worth is the default." AppButton primary "Use Net worth"; text button "Cancel".

**X14 Home, available breakdown** — AppSheet over Home · Home (v_to_use)

1. Head: kicker "AVAILABLE UNTIL 1 NOV", title "How $19,035 adds up". $19,035; line "Cash you can use, $21,450, less $2,415 due before 1 Nov."
2. SplitBar: Available $19,035 (88.7%, cash colour), Due $2,415 (11.3%, data.flow.spending).
3. GlassCard "Cash you can use" (meta "+$21,450"): Checking "First Bank" +$6,450; Savings "Harbor Bank" +$15,000 (each X41d).
4. GlassCard "Due before 1 Nov" (meta "−$2,415 · 5"), DateRow(due)s: 20 Oct ● Phone "Bill · from Checking" −$45; 22 Oct ● Visa card, full amount "Card bill · from Checking" −$1,240; 25 Oct ◆ Monthly investment "VTI · from Checking" −$500; 28 Oct ● Health insurance "Premium · from Checking" −$210; 30 Oct ● Car loan EMI "Loan · from Checking" −$420. Legend in words.
5. GlassCard: Available until 1 Nov $19,035 "$21,450 less $2,415". Table: item, date, amount.
6. Caption "Cash counts accounts you marked as cash you can use. Payments come from your repeating items and card statements. Netflix, $17.99 on 18 Oct, is a future card charge; it is not in this cash total." AppButton primary "Done"; link "Change which accounts count" (X41d).

**X15 Search** — DetailScreen "Search", sub-line "starbucks" · section of the screen that opens it (v_search). Opens from the Search field below the Home title and from the Spending header. Keeps the tab bar.

1. Kicker "SEARCH · 4 RESULTS". No hero number. Search field with focus (2 pt edge), "starbucks", spoken "Search".
2. ChipRow "Result types" (the control row): All (selected) · Payments · Merchants · Accounts · Notes.
3. GlassCard "Merchant" (meta "1"): Dining mark, Starbucks "Dining · 12 visits in 2026" $86.40 (X36).
4. GlassCard "Payments" (meta "3 latest"): Starbucks "Today · Visa card" −$6.40; "9 Oct · Visa card" −$5.90; "2 Oct · Visa card" −$6.10 (each X39). Caption "Search runs on this phone only."

## Add and capture

**X20 Add expense** — FormScreen, no tab bar · Spending (v_b_add)

1. Top bar: 44 pt Close left; four 44 pt source buttons right: Speak (X24), Scan QR (X27), Receipt photo (X28), Import a file (X63).
2. SegmentedControl "Type" (the control row): Expense (selected) · Income · Transfer.
3. Kicker "NEW EXPENSE · USD"; "$24" (numberHero.light) with small ".00"; spoken "Amount $24.00". Pills USD, Today, Visa card, each opens X22 (spoken "Currency: USD. Opens details"). A fourth pill "Split" (same pill style, a details action, not a category) opens X23.
4. AppField "Where or what? For example Starbucks".
5. ChipRow(choice) "Category": Dining (selected, 2 pt text.primary edge), Groceries, Transport, Shopping, Coffee, each with a 12 pt data.category dot; dashed last chip "All categories" (X21).
6. Keypad: 1–9, ".", 0, Delete (spoken "Delete"). AppButton primary "Save $24.00".

**X24 Add expense, voice, listening** — FormScreen (X20 header and type switch) · Spending (v_b_listen)

1. Top bar; SegmentedControl, Expense selected.
2. GlassCard (stage) (polite live region): header "Listening, on this phone", small dot, "Stop" button; transcript ""Spent 40 dollars on coffee today at Starbucks with my Visa"" in large text; static rounded sound bars (decorative, hidden from readers, no motion).
3. Caption "Speak naturally. The app fills the form below. Nothing is saved until you tap Save." Empty amount "$0.00" in text.secondary (spoken "Amount, not filled yet"); empty "Where or what?" field.

**X25 Add expense, voice, filled** — FormScreen · Spending (v_b_filled)

1. Top bar; Expense selected; kicker "VOICE · FORM FILLED".
2. GlassCard (stage) "You said" (meta "on this phone"): the transcript.
3. GlassCard "Form" (meta "4 filled · 1 to check"): five 52 pt rows. Filled (tint, check): Amount $40.00; Where Starbucks; Category ● Coffee; Date Today. Unsure (dashed): Paid with "Visa card (check)". Spoken "Amount: $40.00, filled from your voice"; "Paid with: Visa card, please check". Caption "Green: filled from your voice. Dashed: please check." Rows open X22.
4. Side by side: AppButton ghost "Speak again" with mic (X24); AppButton primary "Save $40.00".

**X21 Choose a category** — AppSheet "Category" over X20 · Spending (v_b_catsheet)

1. Title "Category" (spoken "Choose a category"); search field "Find a category".
2. 4-column grid of 16 tiles (≥ 80 pt), dot and name: Rent, Groceries, Dining (selected, 2 pt edge), Coffee, Transport, Shopping, Utilities, Subscriptions, Health, Fun, Travel, Education, Gifts, Family support, Insurance, Other. Colours from data.category (may repeat).
3. AppButton ghost "New category".

**X22 Date, account, currency** — AppSheet "Details" over X20 · Spending (v_b_details)

1. Title "Details" (spoken "Date, account, currency"). Date chips: Today (selected) · Yesterday · 2 days ago.
2. GlassCard "October 2026" (meta "Today 13 Oct"): month grid, Monday first, weekday letters. 13 Oct selected (filled). 14–31 Oct future: disabled, text.secondary. 44 pt day buttons with full names ("13 October, today").
3. GlassCard: Paid with "Visa card"; Currency "USD"; Tags "None". AppButton primary "Done".

**X23 Split a payment** — DetailScreen (flow step, no tab bar) "Split payment", sub-line "Whole Foods, 5 Oct" · Spending (v_b_split)

1. 0Hero (number): kicker "SPLIT PAYMENT · TOTAL"; $121.30; line "Whole Foods · 5 Oct · 3 parts". SplitBar: Groceries $84.12 (69.4%), Household $25.00 (20.6%), Gifts $12.18 (10.0%). Table total $121.30, 100.0%.
2. GlassCard "Parts" (meta "3"): per part a dot, name (X21), amount in a 44 pt box, remove X (spoken "Remove Groceries"); text button "Add a part".
3. GlassCard: Left to split $0.00 "All of $121.30 is in a part".
4. AppButton primary "Save split"; caption "Save is active when nothing is left to split." Inactive while an amount is left.

**X26 Add transfer** — FormScreen (X20, Transfer selected) · Spending (v_b_transfer)

1. Kicker "TRANSFER · 22 OCT"; $1,240.00.
2. GlassCard SelectRows with 44 pt badges: From "Checking" "$6,450"; To "Visa card" "owes $1,240"; Date "22 Oct".
3. Caption "A transfer moves money between your own accounts. It is not counted as spending." Keypad; AppButton primary "Save transfer".

**X26b Transfer, two currencies** — FormScreen, Close, "Transfer", sub-line "Between your own accounts" · Spending (v_b_fx)

1. Kicker "TRANSFER · TWO CURRENCIES"; Transfer selected.
2. GlassCard: From "Savings · USD" "$15,000"; To "Harbor Bank India · INR".
3. GlassCard "Amounts" (meta "USD to INR"), 2 × 2 fields: You send $2,000.00; They receive ₹165,402; Rate you got "83.20 per USD" (helper "Mid-market today: 83.45"); Fee $12.00 (helper "0.6% of what you send").
4. GlassCard (stage) kicker "WHAT THIS TRANSFER COSTS · USD": $18 (the hero); line "Fee $12.00, plus $5.96 from the rate difference. Saved as a fee, not as spending." SplitBar Fee $12.00 (66.8%), Rate difference $5.96 (33.2%). Table total $17.96.
5. GlassCard: Date "13 Oct"; Service "Your transfer app"; Note "Parents, October". AppButton primary "Save transfer".

**X27 Scan QR receipt** — FormScreen, Close, "Scan a QR receipt" · Spending (v_b_scan)

1. Kicker "SCAN A QR RECEIPT".
2. Camera area (black, radius 28, ≥ 440 pt high, spoken "Camera view"): 220 pt window, four corner marks, sample code; "Point at the QR code on the receipt"; with lock icon "Read on this phone. Nothing is sent."
3. AppButton ghost "No QR code? Take a photo" with camera icon (X28). No amounts.

**X28 Receipt, check fields** — DetailScreen (flow step, no tab bar) "Check the receipt", sub-line "Receipt photo" · Spending (v_b_receipt)

1. Kicker "RECEIPT · CHECK FIELDS".
2. GlassCard (stage) "Receipt" (meta "read on this phone"), monospace: WHOLE FOODS MARKET, Store 10231, 05/10/2026 18:42, Organic milk 4.29, Sourdough 6.50, Salad mix 5.99, ..., TOTAL 121.30. Read fields: tinted box, 1.5 px edge. Spoken "Receipt text. Read fields: Whole Foods Market, 05/10/2026, total 121.30." Caption "Blue boxes: what the app read. Tap another line to change a field."
3. GlassCard "Fields" (meta "4 read"): Where "Whole Foods Market"; Date "5 Oct 2026" (X22); Total $121.30; Category ● Groceries (X21).
4. GlassCard: ToggleRow "Keep the receipt image", "Stored encrypted on this phone" (on). AppButton primary "Save $121.30".

**X87 Microphone permission** — centred AppDialog (title once, no grabber) over X20 (amount $0) · Spending (v_b_mic)

1. 56 pt mic badge; title "Use your voice to add payments".
2. Icon lines: "The app listens only while the button is held or until you tap Stop."; "Speech is turned into text on this phone."; "No audio is saved or sent."
3. AppButton primary "Allow microphone"; text button "Not now".

**X29 Add, chooser** — AppSheet "Add" over the screen that opens it; its section is that screen's section. Sample: over Wealth (header "Wealth", hero "NET WORTH · 13 OCT $187,900" dimmed) · Wealth (v_b_chooser)

1. Title "Add" (spoken "Add, from Wealth").
2. Five rows ≥ 68 pt (44 pt badge, name, grey line, chevron); first row has a 2 pt section-colour edge: Something you own or owe "Account, investment, deposit, loan, card, asset" (X42); Expense "Amount first, 3 taps" (X20); Income "Salary, bonus, other money in" (X20); Transfer "Between your own accounts" (X26); Import a file "Statement, positions, receipt" (X63).
3. Caption "On Wealth, the first choice is something you own or owe. Long-press Add to speak."

## Inbox and import

**X60 Inbox** — DetailScreen, opened from Home, DetailHeader(plain) with Back, keeps the tab bar · Home (v_inbox)

1. Header "Inbox", sub-line "12 to check · on this phone".
2. 0Hero (number): kicker "INBOX · READY TO CONFIRM"; $412.36; line "8 ticked of 12. 3 need a decision. Unsure items are not ticked." SplitBar of sources (Notifications 6, Shared from mail app 5, Statement 1); source chips All 12 · Notifications 6 · Mail app 5 · Statement 1 (control row; DECISION-PENDING CONTROL-ROW-SCOPE).
3. GlassCard (stage) "Needs a decision" (meta "1 of 3"): "Is this a transfer between your own accounts?"; boxes "Checking · 12 Oct −$1,240" → "Visa card · 12 Oct +$1,240"; caption "A transfer is not counted as spending."; ghost buttons "Yes, a transfer", "No, 2 payments".
4. GlassCard "Ready to confirm" (meta "8 ticked"): rows with Checkbox, name, "Today · notification", amount, category pill ("Groceries ?" when unsure, not ticked). Caption "And 3 more. Tap a category to change it. Swipe left to delete; each row also has Delete in its sheet."
5. ConfirmBar "Confirm 8 ticked, $412.36", after the list, in the scroll flow.

**X62 Inbox, empty** — DetailScreen, opened from Home, DetailHeader(plain) with Back, keeps the tab bar · Home (v_inbox_empty)

1. Header "Inbox", sub-line "Nothing to check · on this phone".
2. 0Hero (number): kicker "INBOX · TO CHECK"; 0 (known zero); line "Nothing to check. Everything captured is confirmed."
3. GlassCard EmptyState: neutral grey check badge (no section or gain colour), "All clear", "New captures show here to check."
4. GlassCard "Last capture by source" (meta "4"), 40 pt data-colour icon tiles, each X81: Notifications "Today, 8:42 am"; Shared from mail app "Today, 7:00 am"; Statements "11 Oct"; Receipts and QR "5 Oct". No ConfirmBar.

**X61 Inbox item, edit** — AppSheet "Check this payment" over X60 · Home (v_b_inboxitem)

1. Source line: file badge, "PX MARKET 0231", "From First Bank statement, line 18".
2. GlassCard: Name "PX Market"; Amount $31.75; Date "10 Oct"; Category "Groceries ?" pill with line "Unsure" (X21); Account "Checking".
3. GlassCard: ToggleRow "Always use Groceries for PX Market", "Creates a rule for next time" (on).
4. Side by side: AppButton ghost "Delete" with trash; AppButton primary "Confirm".

**X63 Import** — DetailScreen (flow step, no tab bar) "Import", sub-line "Read on this phone" · Home (v_import_hub)

1. Kicker "IMPORT · READ ON THIS PHONE"; lead "Choose what to import. The app reads the file on this phone and sends drafts to the Inbox. You confirm each one." No hero number.
2. GlassCard "Import types" (meta "8"), tiles: Bank or card statement "PDF, CSV, Excel"; Broker positions "CSV or screenshot"; Payslip "Income, tax, pension, benefits"; Loan statement "Balance, interest, next EMI" (data.debt); Insurance policy "Cover, premium, renewal"; Receipt photo "Camera or photos"; QR receipt "Camera"; OFX, QIF, CAMT.053, MT940 "Bank formats".
3. GlassCard "Saved layouts" (meta "3"): First Bank, checking "PDF · used 4 times" (X66); Visa card statement "CSV · used 6 times" (X67); Harbor Securities "CSV · used 2 times" (X67).
4. GlassCard "History" (meta "2 files"): First Bank statement, Oct "13 Oct · 36 new · 7 already in app" 36; Visa card statement, Sep "2 Oct · 41 new" 41 (each X68; spoken "Import of 13 Oct: First Bank statement, Oct. 36 new, 7 already in app."). Caption "Open an import to undo it. Undo works until you confirm its items."
5. Caption "Tip: share a file from your bank app or Files directly to this app."

**X64 PDF password** — centred AppDialog (title once, no grabber) over Import (row "Harbor_Bank_Oct.pdf" dimmed) · Home (v_pdf_password)

1. 48 pt neutral lock badge; title "This PDF is locked"; body "Harbor Bank protects its statements with a password. Enter it once."
2. AppField "PDF password" (secure, empty), 44 pt eye button (spoken "Show password").
3. ToggleRow "Remember for Harbor Bank", "Stored in this phone's secure storage" (on).
4. AppButton primary "Open PDF"; text button "Cancel". The password goes to secure storage only; never in a log or error.

**X65 Import, preview** — DetailScreen (flow step, no tab bar), Close, "Import", sub-line "First Bank statement, October" · Home (v_import_preview)

1. 0Hero (number): kicker "IMPORT PREVIEW · FIRST BANK · OCTOBER"; 36; line "new payments to send to the Inbox." FactRow: Rows 43 "in the file"; Already in app 7 "not sent again"; New 36 "to the Inbox". Check line "Matched your saved layout "First Bank, checking"".
2. GlassCard "Preview" (meta "Date · details · amount"), static DateRows: 01 Oct ● RENT PAYMENT "Money out" −$1,800.00; 02 Oct ● ZARA 0231 −$39.90; 03 Oct ★ SALARY ACME INC "Money in" +$8,200.00; 04 Oct ● SHELL 4471 −$52.10; 05 Oct ● WHOLEFDS MKT −$121.30. Caption "And 38 more rows."
3. AppButton primary "Send 36 to the Inbox"; link "Wrong layout? Teach again" (X66); caption "The file copy is deleted after import."

**X66 Teach once** — DetailScreen (flow step, no tab bar) "Teach once", sub-line "New layout, Harbor Bank" · Home (v_teach_once)

1. Kicker "TEACH ONCE · HARBOR BANK"; lead "Tap the parts of one row. The app learns this layout and reads the next statement without asking."
2. GlassCard (stage) "Statement" (meta "page 1"), monospace "HARBOR BANK · STATEMENT OF ACCOUNT", columns Date, Details, Amount. Row 1: "01/10" solid box (done), "RENT PAYMENT" dashed box (tap now), "1,800.00 DR". Rows: 02/10 ZARA 0231 39.90 DR; 03/10 SALARY ACME INC 8,200.00 CR. Full spoken label.
3. GlassCard "Steps" (meta "1 of 3 done"): check "Date · 01/10"; current "2 · Details · Tap it now" (aria-current step); "3 · Amount · Next".
4. GlassCard "Sign words": "Money out is shown as" DR; "Money in is shown as" CR. AppButton primary "Continue".

**X67 CSV mapping** — DetailScreen (flow step, no tab bar) "Match the columns", sub-line "visa_sept.csv" · Home (v_csv_mapping)

1. Kicker "MATCH THE COLUMNS · VISA_SEPT.CSV"; lead "Tell the app what each column means. It remembers for the next file with the same columns."
2. GlassCard "Columns" (meta "5"), letter badges: A "Posting date" → Date; B "Description" → Details; C "Debit" → Money out; D "Credit" → Money in; E "Balance" → Ignore. Spoken "Column A, Posting date: Date".
3. GlassCard "Format": Date format "DD/MM/YYYY"; Decimal mark "Point (1,234.56)".
4. GlassCard "Preview" (meta "2 rows"): 2 Sep ● AMAZON MKTP −$42.99; 5 Sep ★ PAYMENT THANK YOU +$980.00. AppButton primary "Save layout and continue".

**X69 Import a payslip** — FormScreen, Close, "Payslip", sub-line "Acme Inc, October 2026" · Home (v_payslip)

1. 0Hero (number): kicker "NET PAY · ACME INC · OCTOBER 2026"; $8,200; line "Gross pay $10,400, less tax, pension and the share purchase plan."; check line "Net pay matches your 1 Oct salary deposit."
2. GlassCard (stage) "Gross pay" (meta "$10,400"): SplitBar Net pay $8,200 (79%), Tax withheld $1,476 (14%), Pension, you $520 (5%), Share purchase plan $204 (2%). Table.
3. GlassCard "One payslip fills 5 areas" (meta "5"): icon chips Income, Tax, Retirement, Investments, Benefits.
4. GlassCard "Fields" (meta "6"), "Goes to: ...": Gross pay $10,400 (Income); Tax withheld −$1,476 (Tax); Pension, you −$520 (Retirement); Share purchase plan −$204 (Investments); Meal allowance $0 (Benefits · card, $120); Net pay $8,200 "Matches the 1 Oct deposit".
5. AppButton primary "Add to these areas". Caption "Read on this phone. Tax withheld also appears in Plan > Tax for 2026."

**X69b Import a policy** — FormScreen, Close, "Insurance policy", sub-line "DriveWell_policy_2025.pdf" · Home (v_policy_import)

1. 0Hero (number): kicker "PREMIUM · DRIVEWELL · CAR"; $780; line "A year, paid 4 Nov. Renews 4 Nov 2026." Lead "The app read these fields on this phone. Tap any line to correct it."
2. GlassCard "Read from the document" (meta "8 fields"): Insurer DriveWell; Type "Car, full cover"; Covered "Car, plate 4KX-218"; Cover "Repair value and liability $500,000"; Excess you pay "$300 a claim"; Premium "$780 a year, paid 4 Nov"; Renews "4 Nov 2026"; Policy number "DW-88-10473".
3. GlassCard "It also adds" (meta "3"): Repeating payment "Every 4 Nov" $780; Renewal date in the calendar "4 Nov 2026"; Line in the emergency sheet "Car insurance · DriveWell".
4. AppButton primary "Save policy".

**X68 Import, done** — DetailScreen (flow step, no tab bar) "Import", sub-line "First Bank statement, October" · Home (v_import_done)

1. 0Hero (number): kicker "IMPORT · DONE · FIRST BANK · OCTOBER"; 36; line "sent to the Inbox. 29 are ready to confirm. 3 need a decision. 4 have no category." 52 pt check badge top right. SplitBar: Ready to confirm 29 (81%), Need a decision 3 (8%), No category 4 (11%). Table.
2. AppButton primary "Open the Inbox" (link to X60); AppButton ghost "Undo this import".
3. Caption "Undo removes every item from this file. You can undo until you confirm them."

**X88 Import error** — DetailScreen (flow step, no tab bar) "Import", sub-line "scan_0412.pdf" · Home (v_import_error)

1. Kicker "IMPORT · SCAN_0412.PDF".
2. GlassCard (state): 64 pt neutral warning-triangle badge (not the loss hue); "This file has no rows the app can read"; "scan_0412.pdf looks like a photo of a page."
3. AppButton primary "Read it as a photo (text recognition)"; AppButton ghost "Teach the layout" (X66); AppButton ghost "Choose another file". Caption "Nothing from this file was added."

## Spending

**X30 Spending, money out** — TabRootScreen · Spending (v_spend_out). No SegmentTabs and no sub-tab row (SPEND-TABS): Money in, Budget, Repeating, Where it goes, All payments and Edit limits are detail screens from rows. Search is in the header (X15).

1. 0Hero (period), PeriodChips 1W · 1M (default) · 6M · 1Y; kicker "SPENT" for every period (no "TOTAL"/"AVERAGE"). Per chip, number, range, PeriodBarChart, line:
   - 1W: $1,560 "this week", 7–13 Oct 2026 · October: $1,260 left of $5,200; "AVG $223"; "$223 a day on average this week."
   - 1M: $3,940 "of $5,200", 1–13 Oct 2026, daily bars, "AVG $303 · INCL. RENT"; "Same days in September: $4,005. October is $65 lower."
   - 6M: $21,080 "of $26,000", May–Sep 2026 · within the limit; "AVG $4,216"; "September was the highest month: $5,060."
   - 1Y: $48,060 "of $62,400", Oct 2025 – Sep 2026 · within the limit; "AVG $4,005"; "Every month was within its limit; the highest was September, $5,060."
2. GlassCard "By category" (meta "October"): needs/wants SplitBar (Needs $2,890 #FFB347, Wants $1,050 #F28FD0, with shares); 3-column RingMeter grid, largest first: icon, ring = share of limit (dashed for fixed bills), name, spent, "$X left" or "Paid". Each opens X36. Table: spent, limit, left, 12-month average.
3. GlassCard: Where it goes "October" (X30c); Budget "$1,260 left of $5,200" (X32); Repeating "$2,084 a month · 7 payments · 3 changes" (X34); Money in "$8,200 · October · avg $9,267 a month" (X31).
4. GlassCard: All payments "42 · October" (X37); Edit limits "$5,200 · 8 categories" (X33).

**X30c Spending, where it goes** — DetailScreen "Where it goes", sub-line "October" · Spending

1. 0Hero (number): kicker "WHERE IT GOES · OCTOBER"; $3,940; line "Of your $8,200 money in so far: spent 48%, kept 52%."
2. SegmentedControl (control row): "% of spending" / "% of money in".
3. GlassCard "Where it goes" (meta "this month vs average"): per category %, amount, a bar on one 0–50% scale, a white 12-month-average mark. Caption "Bar: share this month, on one 0–50% scale. White mark: 12-month average share. Transfers ... not counted."

**X31 Spending, money in** — DetailScreen "Money in", sub-line "October" · Spending (v_spend_in). The money-in colour stays a content colour.

1. 0Hero (period), PeriodChips 1M (default) · 6M · 1Y; PeriodBarChart in the money-in colour:
   - 1M: MONEY IN · TOTAL $8,200, 1–13 Oct 2026; "Salary on 1 Oct. Kept so far: $4,260, 52%." Then "Where money in went": SplitBar October vs 12-month average (Needs, Wants, Invested, In cash), incl. "Invested $0 0.0% · avg 8.6% · due 25 Oct". Caption "Kept is money in less money out, so it includes what you invested. Needs and wants follow your category tags."
   - 6M: $49,200, May–Oct 2026, "AVG $8,200"; "Salary only in each of these months."
   - 1Y: MONEY IN · TOTAL $111,200, Nov 2025 – Oct 2026, "AVG $9,267"; "Highest month: March, $16,400 with the bonus." "Where a month's money in goes" (meta "of $9,267"): Needs $3,005 32.4%, Wants $1,000 10.8%, Invested $800 8.6%, In cash $4,462 48.2%; table.
2. GlassCard: Next income $8,200 "Salary · 1 Nov · in 19 days" (Calendar).
3. GlassCard "Sources" (meta "12 months · $111,200"): Salary $98,400 88.5%; Bonus $6,000 5.4% · March; Rent received $5,800 5.2% · Jan–Mar; Interest & dividends $1,000 0.9%; Owed to you $2,640 "Expected · 2 items".

**X32 Spending, budget** — DetailScreen "Budget", with Back · Spending

1. 0Hero (number): kicker "LEFT OF OCTOBER LIMIT"; $1,260; line "$3,940 of $5,200 spent. Day 13 of 31."
2. GlassCard "Limits" (meta "most left first"): one RingMeter per category limit (Groceries ... Rent "Paid"). Caption "Each ring is one limit, filled to the share used. The white tick is today, 42% of the month. Dashed rings are fixed bills." Table; row Edit limits (X33).

**X33 Edit limits** — DetailScreen (flow step, no tab bar) "Monthly limits", sub-line "Spending", "Save" text action · Spending (v_edit_limits)

1. 0Hero (number): kicker "TOTAL LIMIT · EACH MONTH"; $5,200; line "The sum of 8 category limits." FactRow: Money in $8,200 "last month"; Categories 8 "with a limit"; Carry over Off "each month fresh".
2. GlassCard "Limit per category" (meta "8"): icon in data.category colour, name, "12-month average $X", limit in a 44 pt box button (spoken "Rent limit $1,800. Edit."): Rent $1,800 (avg $1,800); Groceries $1,200 (avg $700); Dining $600 (avg $520); Shopping $500 (avg $240); Transport $400 (avg $300); Utilities $300 (avg $205); Other $300 (avg $150); Subscriptions $100 (avg $90).
3. AppButton ghost "Add a category limit" with tag icon.
4. GlassCard: ToggleRow "Carry unspent money to next month", "Off: each month starts fresh" (off). Caption "Limits are your own numbers. The app shows how your spending compares with them."

**X34 Spending, repeating** — DetailScreen "Repeating", sub-line "October" · Spending (repeating_parts)

1. 0Hero (detail): kicker "REPEATING · EACH MONTH"; $2,084; side figures "a month", "$25,790 a year"; line "5 monthly · 1 yearly · 1 trial".
2. GlassCard (stage) "This month" (meta "October"): billing-day strip 1–31 Oct: track, brighter up to today, "TODAY" dot 13 Oct, one dot per payment (area follows amount; paid = text.secondary style, not opacity). Table: date, payment, amount, state. Rows: type icon, name, "Paid · 1 Oct · monthly" or "18 Oct · monthly", optional NeutralPill ("was $15.49", "trial ends"), amount: Rent $1,800, Spotify $10.99, Netflix $17.99, Phone $45, Cloud storage $9.99, Health $210, Car insurance $780 "4 Nov · yearly" with "was $720". Rows open X35.
3. No add button; adding uses the tab bar Add.

**X35 Repeating payment** — DetailScreen "Netflix", sub-line "Repeating payment", Edit right · Spending (v_repeating_detail)

1. 0Hero (number): kicker "NETFLIX · EVERY MONTH ON THE 18TH"; $17.99; line "From 18 Oct, Expected: up $2.50 from $15.49. $215.88 a year."
2. GlassCard (stage) "Last 6 payments" (meta "Apr–Sep"): six columns Apr–Sep $15.49, latest highlighted; October (expected) not drawn; amount above, month below. Table. Spoken "Netflix, last 6 payments, April to September: $15.49 each. Next payment 18 October, Expected, $17.99."
3. GlassCard: Paid with "Visa card" (X41); Category "Subscriptions" (X36); Next payment "18 Oct" "Expected · $17.99" (X50); Cancellation address "netflix.com/cancel" (monospace, "Kept as text on this phone", not a link).
4. GlassCard: ToggleRow "Add it to the Inbox to confirm", "Off: added automatically" (off). AppButton ghost "Stop repeating" with trash.

**X36 Category detail** — DetailScreen "Groceries", sub-line "October" · Spending

1. 0Hero: kicker "GROCERIES · OCTOBER"; $620; "$580 left of $1,200"; limit bar with today tick.
2. FactRow: Used 52%; Month gone 42%; 12-month avg $700.
3. GlassCard (stage) "Each month" (meta "Jan–Oct"): ten columns, lines "LIMIT $1,200" and "AVG $700"; table.
4. GlassCard "Where": SplitBar Whole Foods 52%, PX Market 28%, Others 20%.
5. GlassCard "Payments": four DateRows, newest first; row "All 14".

**X37 All payments** — TopBar "All payments" with a filter button · Spending

1. Search field. ChipRow: October, All accounts, All categories.
2. Day cards, title above with day total as meta: "Today · 13 Oct · −$21.40", "Yesterday · 12 Oct · −$64.40", "Saturday · 11 Oct · −$108.12"; each holds TransactionRows.
3. No toast at rest. After a delete (X39b) the payment leaves the list; the day total, the header count ("42" → "41") and the spoken sub-line change; the app AppToast "Payment deleted" has "Undo", which restores the row, the total and the count.

**X38 Filter payments** — FilterSheet "Filter" over X37 (header "All payments · October · 42 payments" dimmed) · Spending (v_filter_sheet)

1. Group "Period": This month (selected) · Last month · This year · Custom.
2. Group "Show": Money out (selected) · Money in · Transfers · No category.
3. Rows: Accounts "All 4"; Categories "All 16"; Tags "Any"; Amount "Any".
4. Text button "Clear"; AppButton primary "Show 42 payments".

**X39 Payment detail** — DetailScreen "Payment", sub-line "Whole Foods Market", More (...) right · Spending (v_payment_detail)

1. 0Hero (number): kicker "PAYMENT · 5 OCT 2026 · 6:42 PM"; −$121.30; line "Whole Foods Market. Visa card. From your receipt photo."
2. GlassCard: Category "Split into 3"; Account "Visa card" (X41); Tags "Household"; Note "Weekly shop".
3. GlassCard (stage) "Split" (meta "Edit" link): SplitBar Groceries $84.12 (69%), Household $25.00 (21%), Gifts $12.18 (10%). Table: category, amount, share.
4. GlassCard, ToggleRows (off): Reimbursable "Not counted as your spending until paid back"; Refund expected "Track money that is coming back to you".
5. GlassCard: Receipt image "Stored on this phone"; Similar payments "14 at Whole Foods" 14 (X37).
6. AppButton ghost "Delete payment" with trash (X39b).

**X39b Delete payment** — centred AppDialog (title once, no grabber) over X39 · Spending (v_delete_dialog)

1. 48 pt neutral trash badge; "Delete this payment?"; body "Whole Foods Market, $121.30 on 5 Oct. You can undo for 5 seconds after deleting."
2. AppButton destructive "Delete payment" with trash (dark #3A3C44 / #F4F4F6; Light #E4E5EA / #16171B). Text button "Keep it".

## Wealth

**X40 Wealth** — TabRootScreen · Wealth (v_wealth)

1. 0Hero (period): kicker "NET WORTH"; $187,900 (a tap on the number opens X40b); PeriodChips 1M · 1Y (default) · 5Y. Side figures: 1M +$6,600 / +3.6% (rolling 30 days, WEALTH-1M-BASIS); 1Y +$16,900 / +9.9%; 5Y "Missing" (history starts Oct 2025). Target line as X10. AreaLineChart(multi): net worth, investments, cash, one scale from $0, $50K steps; legend in words. Table: month ends of the three series. Open: net worth line uses the gain hue #3DF2B0 (needs a neutral token).
2. GlassCard You own / You owe: tabs with totals You own $197,540, You owe $9,640 (card-level control; DECISION-PENDING CONTROL-ROW-SCOPE). Per tab a SplitBar of types, then IconTileGrid(types):
   - You own: Investments $129,800 "+0.4% today"; Retirement $24,010 "401(k) · Est."; Cash & bank $21,450 "2 accounts"; Car $12,000 "Est."; Deposits $10,280 "Est. · 12 Nov". Empty ("None recorded", dashed, opens Add): Property, Gold and silver, Bonds, Other.
   - You owe: Car loan $8,400 "22 payments left"; Visa card $1,240 "Due 22 Oct"; empty: Other money owed. Row "What you owe" $9,640 (X46).
   - Table per tab: type, value, share, fact.
3. GlassCard "Not in net worth" (meta "Expected"): Unvested shares $31,595 "160 shares at today's price"; Owed to you $2,640; Dividends, next 6 months $245 "Est.".

**X46 What you owe** — DetailScreen "What you owe", sub-line "Loans and cards · USD" · Wealth (v_owe)

1. 0Hero (number): kicker "WHAT YOU OWE"; $9,640. SplitBar Car loan $8,400 (87.1%, data.debt), Visa card $1,240 (12.9%); table. FactRow: Payments a month $1,660 "20% of money in"; Interest and fees $630 "2026 · loan $470, fees $160" (X58); Items 2 "1 loan, 1 card".
2. GlassCard (stage) "Loans" (meta "1"): half-circle gauge 58% "PAID OFF", ends $0 and $20,000, end-point dot. Spoken "Car loan paid off: $11,600 of $20,000, 58%. Left $8,400." Table: paid off $11,600, left $8,400, borrowed $20,000. FactRow: Left $8,400 "22 EMIs of $420"; Rate 7% "fixed"; Last EMI Aug 2028 "30th each month". Row Car loan · City Auto Finance $420 "Next EMI 30 Oct" (X47).
3. GlassCard "Cards" (meta "1"): FactRow Full amount $1,240 "due 22 Oct"; Minimum $40 "due 22 Oct"; Checking after $5,165 "pays from Checking" (X41). Bar "Limit used · $1,240 of $6,000 · 21%". Row Visa card · First Bank $1,240 "Annual fee $95 on 2 Feb" (X48).
4. GlassCard "Other": one empty tile "Other money owed" "None recorded" (dashed, opens Add). Caption ""None recorded" means nothing is entered."

**X41 Account detail, checking** — DetailScreen "Checking", sub-line "First Bank · USD" · Wealth (v_account)

1. 0Hero (number): kicker "CHECKING · FIRST BANK"; $6,450; line "Lowest expected before 1 Nov: $4,035 on 30 Oct."
2. GlassCard (stage) "Last 30 days" (meta "14 Sep to today"): AreaLineChart, cash colour, $0–$13,000, lines $5K and $10K; x labels 14 SEP, 1 OCT, TODAY; end dot $6,450. Jump on 1 Oct = salary $8,200 less rent $1,800. Table: 18 dates and balances. Caption "Balances before today are sample data."
3. GlassCard, ToggleRows (on): Counts as cash you can use "Used for "Available until 1 Nov""; Include in net worth.
4. GlassCard "Payments due from this account" (meta "5 · $2,415"): 20 Oct ● Phone −$45; 22 Oct ● Visa card "Card, full amount" −$1,240; 25 Oct ◆ VTI "Regular investment" −$500; 28 Oct ● Health insurance −$210; 30 Oct ● Car loan "Loan, EMI" −$420.
5. GlassCard "Recent": 13 Oct ● Starbucks −$6.40; 1 Oct ★ Salary, Acme Inc +$8,200.00; 1 Oct ● Rent −$1,800.00; All payments (X37).
6. GlassCard: Last statement "13 Oct" (Imported); Interest earned $42 (in 2026).

**X41c Account detail, retirement** — DetailScreen "Retirement", sub-line "Workplace pension · USD" · Wealth (v_retirement)

1. 0Hero (detail): kicker "RETIREMENT · 1 ACCOUNT"; $24,010; side "Est.", "since 31 Jul".
2. GlassCard "Accounts" (meta "1"): 401(k) · Workplace $24,010 "Est. · last statement 31 Jul".
3. GlassCard (stage) "401(k) · Workplace" (meta "estimate"): AreaLineChart, dashed estimate from $22,700 (31 Jul, solid dot, "STATEMENT") to $24,010 today (end dot, "EST."). Caption "Solid dot: the last statement. Dashed: the estimate from your rule." FactRow: Last statement $22,700 (31 Jul); Added since +$1,000 (Aug, Sep · $500 a month); Growth +$310 (Est. · 5% a year).
4. GlassCard "Rule": Contribution $500 a month; Growth 5% a year; Update value "From a statement" (X41b).
5. GlassCard "Retirement types": tiles 401(k) "1 account", IRA · Roth IRA, EPF, PPF, NPS, Superannuation, Workplace pension, Other pension; recorded type has a 1 px section-colour edge. Caption: values come from statements or a rule; no pension portal connection.

**X41d Account detail, cash and bank** — DetailScreen "Cash and bank", sub-line "Cash you can use · USD" · Wealth (v_cashbank)

1. 0Hero (detail): kicker "CASH AND BANK"; $21,450; side "2", "accounts".
2. GlassCard: Available until 1 Nov $19,035 "$21,450 less $2,415 due before 1 Nov" (X14).
3. GlassCard (stage) "Until your next income" (meta "1 Nov"): AreaLineChart(multi): Checking $6,450 today → $4,035 on 30 Oct (end-point mark, "LOWEST $4,035") → $10,435 on 1 Nov ("+$8,200 · −$1,800 RENT"); Savings flat $15,000. Legend. FactRow: Lowest expected $4,035 (Checking · 30 Oct); Due before 1 Nov $2,415 (5 payments); Next income $8,200 (1 Nov).
4. GlassCard "Accounts" (meta "2"): Checking $6,450 "First Bank · pays your bills"; Savings $15,000 "Harbor Bank".

**X41e Account detail, car** — DetailScreen "Car", sub-line "Vehicle · USD" · Wealth (v_car)

1. 0Hero (detail): kicker "CAR"; $12,000; side "Est.", "−10% a year".
2. GlassCard (stage) "Value and loan" (meta "to Aug 2028"): AreaLineChart(multi): car value (Est., −10% a year) and loan left ($8,400 → $0 Aug 2028), one scale; gap now labelled $3,600. Legend. FactRow: Value $12,000 (Est. · −10% a year); Loan left $8,400 (22 payments of $420; X47); Difference $3,600 (value less loan).
3. GlassCard: Car loan $8,400 "City Auto Finance · 7% fixed"; Update value "From a valuation".

**X41f Account detail, term deposit** — DetailScreen "Term deposit", sub-line "Harbor Bank · USD" · Wealth (v_deposit)

1. 0Hero (detail): kicker "TERM DEPOSIT · HARBOR BANK"; $10,280; side "Est.", "4.1% a year".
2. GlassCard (stage) "Term" (meta "9 months"): term bar 12 Feb ($10,000) to 12 Nov ($10,312), filled to days passed (89%), mark "Today · $10,280 Est." in data.neutral.fill. FactRow: Put in $10,000 (12 Feb); Interest so far +$280 (Est. · 4.1%); At maturity $10,312 (12 Nov · in 30 days).
3. GlassCard: Rate 4.1% a year "Fixed"; Matures 12 Nov 2026 "In 30 days"; Update value "From a statement".

**X47 Account detail, loan** — DetailScreen "Car loan", sub-line "City Auto Finance · USD" · Wealth (v_loan)

1. 0Hero (number): kicker "LEFT TO PAY · CAR LOAN"; $8,400; line "22 EMIs of $420. Last one in Aug 2028."
2. GlassCard (stage): gauge as X46 (58%, $11,600 of $20,000); table. FactRow: Rate 7% "fixed"; Interest paid $1,840 "so far"; Prepayment "2% fee" "you entered".
3. GlassCard "Next payments" (meta "left after each"), DateRow(due) ● "EMI · $420", "Principal · interest · year", loan left (exact amortisation at 7%): 30 Oct $371, $49, $8,029; 30 Nov $373, $47, $7,656; 30 Dec $375, $45, $7,281; 30 Jan 2027 $378, $42, $6,903. Caption "The amount on the right is the loan left after that EMI." Table: date, EMI, principal, interest, left.
4. GlassCard: Paid from "Checking" "First Bank" (X41); Full schedule "22 EMIs" (X50); Try an extra payment "Calculator" (X59).

**X48 Account detail, card** — DetailScreen "Visa card", sub-line "First Bank · USD" · Wealth (v_card)

1. 0Hero (number): kicker "VISA CARD · DUE 22 OCT"; $1,240; line "Full amount. Minimum $40. Due in 9 days."
2. GlassCard: FactRow Full amount $1,240 "statement 12 Oct"; Minimum $40 "due 22 Oct"; Checking after $5,165 "pays from Checking" (X41).
3. GlassCard "Limit used" (meta "21%"): "$1,240 of $6,000", "New spending since the statement: $310", "$4,760 left", bar. Spoken "Limit used: $1,240 of $6,000, 21%. $4,760 left."
4. GlassCard: Statement closes "3 Nov"; Interest and fees $0 "In 2026"; Annual fee $95 "On 2 Feb"; Instalment plans "None recorded". Row "Pay this card" opens X26 (transfer to Visa card).
5. GlassCard "Recent": 12 Oct ● Uber "Transport" −$18.20; 5 Oct ● Whole Foods "Groceries" −$121.30; 18 Sep ● Netflix "Subscriptions" −$15.49; All payments (X37). Dates come from the card's data; figure dates are samples.

**X41b Update a value** — AppSheet "Update value", sub-line "Workplace pension · 401(k)", over X41c Retirement · Wealth (v_update_value)

1. FactRow: Estimated today $24,010 "Est. · from your rule"; Last real value $22,700 "31 Jul · statement".
2. AppField "New value from your statement" $24,180; AppField "Statement date" "30 Sep 2026".
3. Caption "The estimate restarts from this value: $500 a month plus 5% a year." AppButton primary "Save value"; text button "Cancel".

**X42 Add, choose type** — DetailScreen (flow step, no tab bar) "Add", sub-line "Something you own or owe" · Wealth

1. Kicker "ADD · CHOOSE A TYPE".
2. Seven GlassCards, count as meta: Cash 2, Investments 4, Retirement 8, Deposits 2, Things 2, You owe 3, Other 2. Tiles: name and hint (e.g. "Broker account · stocks, ETFs, funds").
3. Note "Each type has a value method: market price, interest, contributions, weight and price, or a value you enter."

**X42b Add deposit** — FormScreen (as DetailScreen) "New deposit", sub-line "Term deposit · USD" · Wealth (v_add_deposit)

1. Kicker "ADD · TERM DEPOSIT".
2. GlassCard "Deposit": Name "Harbor Bank term deposit"; Amount $10,000; 2 × 2: Rate per year 4.1%; Interest added "Monthly"; Start date "12 Feb 2026"; Matures "12 Nov 2026".
3. GlassCard, ToggleRows (off): Renews automatically; Counts as cash you can use "Off: locked until it matures".
4. GlassCard (stage) "Value today" (meta "Est."): FactRow Value today $10,280 "Est."; Interest so far +$280 "Est. · 4.1%"; At maturity $10,312 "12 Nov". Caption "The app updates the value every day from the rate." AppButton primary "Save deposit".

**X49 Shares from work** — DetailScreen "Shares from work", sub-line "NVDA · employer plan · USD" · Wealth (v_vest)

1. 0Hero (number): kicker "NEXT 12 MONTHS · EXPECTED"; "72 shares"; line "$14,218 Est. at today's price of $197.47."
2. GlassCard (stage) "Coming" (meta "72 shares"): stacked columns Nov–Oct: Vest (data.flow.investing) and Share purchase (second data colour); Nov 32 (20 + 12), Feb 20, May 20; count above. Legend in words. Table: date, event, shares, at today's price. DateRow(due)s ◆, each "Expected · at today's price" (X44): 15 Nov "Vest · 20 shares" $3,949 Est.; 30 Nov "Share purchase · 12 shares" $2,370 Est.; 15 Feb "Vest · 20 shares" $3,949 Est.; 15 May "Vest · 20 shares" $3,949 Est.
3. GlassCard: FactRow Unvested 160 "$31,595 Est."; Tax withheld $2,960 "on vests, 2026"; Of net worth 17% "in NVDA" (X44).
4. GlassCard: Confirm a vest "Inbox", line "When a vest date passes, it appears in the Inbox. You confirm the shares received and the shares sold for tax." (X60); NVDA $31,200 "158 shares held now" (X44).

## Investments

**X43 Investments** — DetailScreen from Wealth (keeps tab bar) · Wealth (v_invest)

1. 0Hero (period): kicker "INVESTMENTS"; $129,800; PeriodChips 1D (default) · 1M · 1Y · All. Side: 1D +$550 / +0.4%; 1M +$5,800 / +4.7%; 1Y +$18,800 / +18.6%; All +$29,600 / +39.8% (since Oct 2023). AreaLineChart (heroBackground) with dashed cost-basis line. Caption "Change: value less money put in. Percent: time-weighted (TWR). Dashed line: cost basis." FactRow: Unrealised +$31,600 (+32.2% on cost); Realised +$2,140 (in 2026); Largest 24.0% (NVDA).
2. HoldingsCard: group menu Holdings · Sectors · Markets; views Bubbles (default) · List · Tree; filter. Total $129,800, period gain with menu ("+$550 · +0.4% today ∨" or "since bought"). FilterSheet "Filters and sort": Account (All accounts, Brokerage, Employer shares), Asset type, Status (Held now · Sold in 2026), List: sort by, order, count. Sold forces the list, "realised in 2026 · 2 sales" (+$2,140). Card controls: DECISION-PENDING CONTROL-ROW-SCOPE.
3. GlassCard "By currency" (meta "in USD"): US dollar $107,600 · 82.9%; Indian rupee $12,600 · 9.7%; Taiwan dollar $9,600 · 7.4%; grey line lists holdings (e.g. "VTI, NVDA, BND, AAPL, GLD, JPM, JNJ, cash"). Each currency row opens Allocation grouped by currency.
4. GlassCard "Regular investments": VTI $500 "25 Oct"; NVDA $3,949 Est. "15 Nov" (DECISION-PENDING REGULAR-INVEST).
5. GlassCard "Total gain since you started" (meta "+$40,430"; SPEC words, SPEC-SYNC-001; the figure says "Gain since first buy"): FactRow Price +$39,174, Dividends +$1,950, Currency −$694; caption with unrealised +$31,600, realised +$6,880, dividends +$1,950; "Started 2019; value history in the app starts Oct 2023."
6. GlassCard: Returns "1M · 1Y · 3Y"; Dividends $410 "in 2026"; Gains and tax.
7. GlassCard rows: Allocation (X43c); Insights (X43h); Update positions (opens the file picker, then X45); Prices (price status; offline state X89).

**X89 Investments, offline prices** — DetailScreen "Investments", sub-line "Prices from 11 Oct · USD" · Wealth (v_offline)

1. StatusBanner (estimate): wifi-off icon tile; "**Prices from 2 days ago.** You are offline. Values use the last prices."
2. 0Hero (detail): kicker "INVESTMENTS · EST."; $128,940; side "Est.", "last prices"; line "Last prices: Sunday, 11 Oct, 4:00 pm."
3. GlassCard "Prices" (meta "offline"): FactRow Holdings 12 "valued at last prices"; Today **Missing** "no prices today"; Last prices 11 Oct "4:00 pm". Rows: Source "Public prices" "Only symbols you turned on"; Next update "When online" "Values stay Est. until then".
4. GlassCard: Holdings 12 "Values use the last prices" (X43). Today's change is "Missing", never +$0.

**X43j What the numbers mean** — AppSheet "What the numbers mean", sub-line "Investments · plain words" · Wealth (v_glossary)

1. GlassCard definition list (bold term with value, grey sentence, divider): Invested $98,200; Unrealised gain +$31,600; Realised gain "+$2,140 in 2026" (all time +$6,880); Total gain +$40,430 ($31,600 + $6,880 + $1,950, each counted once); Time-weighted return · TWR "+18.6% · 1 year"; Money-weighted return · XIRR "+16.9% · 1 year" (under 1 year: return for the period); CAGR "per year"; Missing "Records for the period are absent. A missing return is never shown as 0%."
2. Caption "Sample values from your investments. Each screen names the measure it shows."
3. GlassCard: Returns "XIRR · TWR" "Both measures, by period" (X43g). No primary button.

**X44 Holding detail** — DetailScreen "NVDA", sub-line "NVIDIA · Nasdaq · USD" · Wealth (v_holding)

1. 0Hero (number): kicker "NVDA · 158 SHARES"; $31,200; line "$197.47 a share. Today +1.1%. 1 year +54%."
2. PeriodChips (control row) 1D · 1W · 1M · YTD · 1Y (default) · All.
3. GlassCard (stage): price AreaLineChart with end dot, dashed average-cost line in the Wealth data colour (label right end, under the line), dots for received lots at their price. Table: month-end prices. Caption "Price is illustrative sample data. Gold line: your average cost. Dots: lots you received, at their price."
4. GlassCard "Position", two FactRows: Invested $21,900; Unrealised +$9,300 (+42.5%); Dividends $6; Of investments 24%; Of net worth 17%; Realised $0.
5. GlassCard "Where the shares came from" (meta "158 shares"): SplitBar Vests 61%, Purchase plan 32%, Bought 7%, labels below.
6. GlassCard "Lots" (meta "All 9"): DateRow(lot)s, e.g. 15 Aug "Vest · 20 shares" "at $178.20 · 2026" +$386.
7. GlassCard: Next vest 20 shares "15 Nov"; Sector Technology "Held in employer plan".

**X43c / X43b / X43d Allocation, by class / Allocation, by market / Allocation, by sector** — DetailScreen "Allocation", sub-line "Investments · $129,800" · Wealth (alloc_view)

1. ChipRow "Group by" (control row): Class · Market · Sector · Currency.
2. 0Hero (number): kicker, total, line "N groups. Largest: name, share."
3. Sector only: GlassCard ToggleRow "Include what is inside funds", "Off: single stocks only" (off).
4. GlassCard (stage) "By class / market / sector" (meta "share of value"): ring chart, clockwise from top, largest first, small gaps; total and group count in the centre; key with whole-percent shares. Table: group, value, share, holdings.
5. GlassCard "Groups": dot, name, "value · share", grey holdings line (each X44).
6. GlassCard: caption defining the grouping; Target mix "Not set" "When you set one, each group shows the difference in dollars".
7. Class ("INVESTMENTS · BY CLASS", $129,800, 6): Equity ETFs $48,200 37% (VTI $38,000 · 0050 $6,000 · Nifty 50 $4,200); Stocks $47,400 36% (NVDA, AAPL, TSMC, JPM, JNJ); Bonds $15,000 12% (BND); Mutual funds $8,400 6% (Flexi Cap Fund); Cash $6,000 5% (in brokerage); Gold $4,800 4% (GLD).
8. Market ("INVESTMENTS · BY MARKET", 4): US $101,600 78%; India $12,600 10%; Taiwan $9,600 7%; Cash $6,000 5% (no market).
9. Sector ("SINGLE STOCKS · BY SECTOR", $47,400, 3): Technology $42,400 89% (NVDA $31,200 · AAPL $7,600 · TSMC $3,600); Financials $2,600 6% (JPM); Health care $2,400 5% (JNJ). Caption: funds are not split into sectors unless the toggle is on and each fund's holdings are imported.

**X43e Gains and tax** — DetailScreen "Gains and tax", sub-line "Investments · USD" · Wealth (v_gains)

1. ChipRow "Period": 2026 (selected) · All time.
2. 0Hero (number): kicker "UNREALISED · TODAY"; +$31,600; line "+32.2% on $98,200 invested." FactRow: Realised +$2,140 "in 2026"; Dividends $410 "in 2026"; Fees $64 "in 2026". Caption "Unrealised gain moves with prices. Realised gain is fixed at the time of a sale. All time: realised +$6,880, dividends $1,950."
3. GlassCard (stage) "Unrealised, by holding" (meta "11 holdings"): GainBars, largest first: VTI +$11,000; NVDA +$9,300; Flexi Cap +$3,200; AAPL +$3,100; 0050 +$2,100; TSMC +$1,000; Nifty 50 +$800; JPM +$800; GLD +$700; JNJ +$200; BND −$600 (total +$31,600). Table: holding, invested, value, gain, gain %. Caption "Cash in brokerage, $6,000, has no gain and is not shown."
4. GlassCard "Sales in 2026" (meta "+$2,140"): AAPL +$1,610 "Sold 20 shares · 14 Mar 2026 · held 3 years"; VXUS +$530 "Sold 100 shares · 22 Jun 2026 · held 2 years".
5. GlassCard: Cost method "Average cost"; Lots and holding periods "24 lots" "18 held over 1 year"; Tax records, 2026 "Table" "Kept on this phone" (X58).

**X43f Dividends** — DetailScreen "Dividends", sub-line "Investments · USD" · Wealth (v_dividends)

1. 0Hero (number): kicker "DIVIDENDS · 2026"; $410; line "Received from 6 holdings. Last 12 months $505. Next 6 months $245 Expected, Est."
2. GlassCard (stage) "Dividend calendar" (meta "18 months"), three groups of six cells (month, amount or "—", bar by amount): Nov 2025–Apr 2026 received: —, $95, —, —, $92, $10; May–Oct 2026 received: —, —, $98, $40, —, $170; Nov 2026–Apr 2027 expected, Est. (dashed): —, $95, $45, —, $95, $10. Caption "Bar height: amount. Solid: received. Dashed: expected." Table: month, amount ("None"), status.
3. GlassCard "By holding" (meta "2026 · yield on cost"): VTI $180 (0.7%); BND $140 (0.9%); JPM $40 (2.2%); JNJ $30 (1.4%); AAPL $10 (0.2%); 0050 $10 (0.3%) (each X44).
4. Caption "Expected dividends repeat last year's dates and amounts. They are estimates."

**X43g Returns** — DetailScreen · Wealth (v_returns)

1. 0Hero (number): kicker "YOUR RETURN · 1 YEAR"; +16.9%; line "A year, XIRR. 1 month +4.1%. 3 years +11.2% a year."
2. GlassCard "Portfolio vs ACWI index" (meta "total, TWR"): LaneChart, wide portfolio lane and thin index lane, one scale 0–40%, exact values beside lanes, index label under its lane, gap per lane ("+0.8 pp", "+4.5 pp", "+8.1 pp"). Caption "Bright line: portfolio. Thin line: ACWI global stock index (sample). 5 years and All: Missing; history starts Oct 2023." Table (period, your money XIRR, portfolio TWR, index): 1 month +4.1% for the period / +4.7% / +3.9%; 1 year +16.9% per year / +18.6% / +14.1%; 3 years +11.2% per year / +39.8% / +31.7%; 5 years Missing.
3. GlassCard: What these numbers mean "XIRR · TWR · CAGR" (X43j). G04 stays open.

**X43h Investment insights** — DetailScreen "Investment insights", sub-line "Calculated on this phone" · Wealth (v_insights)

1. Kicker "INVESTMENTS · INSIGHTS". No hero number.
2. GlassCard "Today": Top movers "NVDA +1.1%" "JPM −0.4%"; Largest holding "NVDA" "24% of investments".
3. GlassCard "Currency you hold" (meta "3"): SplitBar USD $107,600 (83%), INR $12,600 (10%), TWD $9,600 (7%); table. Currency effect −$694 "since you started · on India and Taiwan holdings" (X43b).
4. GlassCard "Costs and history": Money added each month $500 "Regular investment into VTI, plus vests"; Cost basis and lots "24 lots" "Average cost"; Holding periods "18 lots" "Held over 1 year"; Fees $64 "In 2026"; Corporate actions "1 split" "In 2026"; Target mix vs now "Not set".

**X45 Update positions** — DetailScreen (flow step, no tab bar) "Update positions", sub-line "From a screenshot" · Wealth (v_update_positions)

1. Kicker "UPDATE POSITIONS · 2 CHANGES".
2. GlassCard: screenshot shape, "Screenshot from Harbor Securities", "Text read on this phone. Image not kept."
3. GlassCard "What changed" (meta "2 of 4"), ticked checkbox rows (spoken "Apply AAPL"): AAPL 42 shares "Was 32 shares" "+10 shares"; SCHD 40 shares "Not held now" "New holding". Caption "2 holdings match and are not shown: VTI 125 shares, BND 200 shares."
4. AppButton primary "Apply 2 changes". Caption "Only differences are shown. Prices update separately."

## Plan

**X50 Plan, calendar** — TabRootScreen · Plan (v_calendar)

1. ScreenHeader (tabs): SegmentTabs Calendar (selected) · Goals · Protect · Tax; Tools icon (X59).
2. No hero number, no kicker (the lowest balance is the X50b hero).
3. GlassCard (stage) "October" (meta "to 15 Nov"): SymbolCalendar 1 Oct–15 Nov; max 3 glyphs then "+N"; today 13 Oct outlined; past numbers text.secondary; cells ≥ 44 × 48 open X51. Legend. Row "Cash flow until 1 Nov · Checking lowest · 30 Oct · $4,035" (X50b).
4. GlassCard "Before next income" (meta "$2,415 from Checking"), DateRow(due)s: 18 Oct Netflix "Card charge · not from Checking" −$17.99; 20 Oct Phone "Bill" −$45; 22 Oct Visa card "Repayment" −$1,240; 25 Oct VTI "Regular investment" −$500; 28 Oct Health insurance "Premium" −$210; 30 Oct Car loan "EMI" −$420. Sub-head "From next income": 1 Nov Salary "Income · Expected" +$8,200; 4 Nov Car insurance "Renewal · was $720" −$780; 15 Nov NVDA "Vest · Est." +$3,949.

**X50b Plan, cash flow** — DetailScreen "Cash flow", sub-line "Checking · USD · until 1 Nov" · Plan

1. 0Hero (number): kicker "CHECKING · LOWEST EXPECTED"; $4,035; line "On 30 Oct, before income on 1 Nov."
2. GlassCard (stage): step chart, labels TODAY $6,450, VISA −$1,240, LOWEST $4,035 · 30 OCT, 1 NOV · $12,235 EXPECTED. Event-day balances only: $6,450 13 Oct, $6,405 20 Oct, $5,165 22 Oct, $4,665 25 Oct, $4,455 28 Oct, $4,035 30 Oct. No smoothing or invented daily values. Table: date, event, change, balance.
3. GlassCard "Payments before 1 Nov" (meta "5 · $2,415"): 20 Oct Phone "Bill" −$45; 22 Oct Visa card "Repayment" −$1,240; 25 Oct VTI "Regular investment" −$500; 28 Oct Health insurance "Premium" −$210; 30 Oct Car loan "EMI" −$420. Caption "Netflix on 18 Oct is a card charge, not from Checking. Savings is not in this chart."

**X51 Calendar, a day** — AppSheet over X50 · Plan (v_day)

1. Head: kicker "THURSDAY, 22 OCTOBER", title "Thursday, 22 October".
2. GlassCard: DateRow(due) 22 Oct ● Visa card, full amount "Card bill · from Checking" −$1,240 (X48). FactRow: Payments 1 "−$1,240"; Checking before $6,405 "after 20 Oct"; Checking after $5,165 "end of 22 Oct" (X50b).
3. Full-width text button "Add a payment on 22 Oct" (no plus icon). No "Done" button.

**X52 Plan, goals** — TabRootScreen · Plan (v_goals)

1. ScreenHeader (tabs): Goals selected.
2. 0Hero (number): kicker "ASSIGNED TO 3 GOALS"; $56,375; line "Of $96,000 in targets. $39,625 to go. Goals use money you already have."
3. GlassCard "Net worth target" (meta "not assigned money"; NW-TARGET): RingMeter 18.8%, "$187,900 of $1,000,000", "$812,100 to go · counts net worth"; rows By Dec 2040 "$4,777 a month" ("Est. · amount to go ÷ months left"); At +$16,900 a year "2074 · Est." ("last 12 months' change"; DECISION-PENDING NW-TARGET-PACE); Financial independence "Tools".
4. GlassCard (stage): three equal goalVials: House deposit 66% ($39,440 of $60,000, Dec 2028); Emergency fund 50% ($15,000 of $30,000, no date); Japan trip 32% ($1,935 of $6,000, Mar 2027). Caption "Each vial is one goal target. The level is the share reached." Table: goal, assigned, target, to go.
5. GlassCard "Goals": House deposit $39,440 "of $60,000 · Dec 2028 · Brokerage 40%"; Emergency fund $15,000 "of $30,000 · Savings 100%"; Japan trip $1,935 "of $6,000 · Mar 2027 · Checking 30%".

**X53 New goal** — FormScreen, Close, "New goal", sub-line "Plan · Goals" · Plan (v_e_newgoal)

1. Kicker "NEW GOAL"; ChipRow "Goal type": Money from accounts (selected) · Net worth target.
2. GlassCard "Goal": Name "Japan trip"; Target amount $6,000; "By (optional)" "Mar 2027".
3. GlassCard "Money from" (meta "assigned"): Checking "First Bank · $6,450 today", share "30%" in a box (spoken "Share assigned"); text button "Add an account".
4. 0Hero (number) (result): kicker "TODAY · JAPAN TRIP"; $1,935; line "32% of $6,000. To reach it by Mar 2027: $813 a month."; CapsuleMeter 32% (spoken "Japan trip: $1,935 of $6,000, 32%."). Caption "The monthly amount is a calculation from your target and date: amount to go ÷ months left."
5. GlassCard "Net worth target" (meta "the other type"): caption "For a net worth target, "Counts" replaces "Money from". The target measures; it assigns no money." Tiles: Net worth "what you own less what you owe" (selected edge); Investments and cash "part of what you own"; Chosen accounts "accounts you pick".
6. AppButton primary "Save goal".

**X55 Plan, protect** — TabRootScreen · Plan (v_protect)

1. ScreenHeader (tabs): Protect selected.
2. 0Hero (number): kicker "PREMIUMS A YEAR"; $3,940; line "Next renewal: car, 4 Nov, $780. 3 policies recorded."
3. GlassCard (stage): premium RingMeter by policy: Health $2,520, Car $780, Term life $640. Table.
4. GlassCard "Cover" (meta "3 of 6 types"): Health $50,000 "family of 4"; Car "Full cover" DriveWell; Term life $500,000 LifeFirst; Disability, Home, Travel "None recorded" (dashed). Caption ""None recorded" means nothing is entered. It does not mean you have no cover."
5. GlassCard "Policies": Health, family of 4 $50,000 cover, "Harbor Health · $210 a month · next 28 Oct", thin bar "Used this year: $1,200 of $50,000"; Car · DriveWell "Renews 4 Nov: $780 · last year $720", "Full cover"; Term life · LifeFirst $500,000 "$640 a year · next 3 Jan".
6. GlassCard "Emergency sheet" (meta "on this phone"): "Accounts, policies, loans, contacts" "Open" "Nominees: 7 of 9 entered · Will: not entered".

**X56 Policy detail** — DetailScreen "Health, family of 4", sub-line "Harbor Health · policy" · Plan (v_e_policy)

1. 0Hero (detail): kicker "HEALTH, FAMILY OF 4 · COVER"; $50,000; side "$48,800", "left".
2. GlassCard (stage) "Cover" (meta "this year"): bar "Used this year" "2 claims paid" $1,200 "of $50,000" (2.4%; minimum visible width). Spoken "Cover used this year: $1,200 of $50,000, 2.4%. Left: $48,800." FactRow: Premium $210 "a month"; Next 28 Oct "from Checking"; Renews 1 Jan "2027".
3. GlassCard "Claims" (meta "2026"), DateRow(due) ★: 9 Aug Clinic visit "Claimed 2 Aug · paid 9 Aug" +$800; 20 Sep Pharmacy "Claimed 14 Sep · paid 20 Sep" +$400. Table total +$1,200.
4. GlassCard "Policy", grey icon rows: People covered 4; Policy number "HH-2291-0045"; Claim steps and phone "Stored on this phone" "Open"; Nominee "Priya, spouse" "Edit".

**X57 Emergency sheet** — DetailScreen "Emergency sheet", sub-line "Plan · Protect" · Plan (v_e_emergency)

1. 0Hero without number: kicker "EMERGENCY SHEET · ON THIS PHONE"; "Everything your family needs, in one place."; line "It stays on this phone. It holds no passwords. It has no export or share control."
2. GlassCard: FactRow Sections "6 of 7" "with entries"; Nominees "7 of 9" "entered"; Passwords "None" "never stored".
3. GlassCard "Sections" (meta "6 of 7 with entries"): Accounts "4 entered" (X40); Investments and pension "4 entered" (X43); Insurance policies "3 entered" (X55); Loans and cards "2 entered" (X46, data.debt icon); Nominees "7 of 9 entered"; Will and documents "None recorded"; People to contact "2 entered".
4. AppButton primary "Preview the sheet". Caption "The preview shows account names, institutions, policy numbers and contacts. Read on this phone. Nothing is sent." No export, PDF or share control.

**X58 Plan, tax and year** — TabRootScreen · Plan (v_tax)

1. ScreenHeader (tabs): Tax selected; Tools icon.
2. 0Hero (number): kicker "MONEY IN · 2026 SO FAR"; $93,700; line "Out $47,300. Kept $46,400, 50% of money in." SplitBar Out $47,300 · 50% / Kept $46,400 · 50%.
3. GlassCard (stage) "Tax dates" (meta "you entered"): timeline from TODAY 13 OCT: ADVANCE TAX −$1,800 · 15 DEC · IN 63 DAYS; TAX RETURN FILING · 2026 · NO AMOUNT · 15 APR · IN 184 DAYS (one spoken label).
4. GlassCard "Tax-saving room" (meta "your limit"): Used "$4,000 of $6,500 you entered · 62%"; $2,500 "room left".
5. GlassCard "For your tax return" (meta "2026"), bars on one scale: Tax withheld from salary $14,760; Rent received $5,800; Realised gains $2,140; Medical and donations $1,950; Interest earned $590; Dividends $410. Caption "Bars share one scale. Totals come from your own records on this phone." Table; last row Fees and interest paid "Loan $470 · currency fees $112 · bank fees $48" $630. No export control.

**X59 Tools** — DetailScreen "Tools", sub-line "Plan" · Plan (v_e_tools)

1. 0Hero without number: kicker "TOOLS · 12 CALCULATORS"; "Calculators use your numbers."; line "Calculators show results from the numbers you enter. They do not suggest what to do."
2. Three GlassCards of icon rows (data-colour icon, name, grey line, chevron):
   - "Invest and goals" (6): Monthly investing "SIP with yearly step-up"; Goal amount "What a goal needs each month"; Target mix "Your mix next to your own target"; Financial independence "Number from your spending"; Withdrawals "How long your money lasts"; Inflation "What money is worth later".
   - "Home and loans" (3): Home loan "EMI and total interest" (X59b); Rent or own "Wealth in both cases"; Loans "Extra payment effect" (data.debt icon).
   - "Cover and cash" (3): Life cover "Cover from your income"; Emergency fund "Months your cash covers"; Currency "Amount after rate and fees".

**X59b Home loan calculator** — DetailScreen "Home loan", sub-line "Plan · Tools" · Plan (v_e_home_loan)

1. Kicker "HOME LOAN · CALCULATOR".
2. GlassCard "Your numbers", 2 × 2: Home price $400,000; Down payment "20% · $80,000"; Rate per year 6.5%; Years 25.
3. 0Hero (number): kicker "EMI EACH MONTH"; $2,161; line "Loan $320,000. Total interest $328,210 over 25 years." SplitBar of $648,210: Loan $320,000 (49.4%), Interest $328,210 (50.6%).
4. GlassCard (stage) "Loan left" (meta "25 years"): line of loan left at year ends, $0–$340,000, $100K steps, labels NOW, YEAR 10, YEAR 25, dot at start ($320,000). Spoken: $320,000 now, $289,799 after year 5, $248,036 after year 10, $190,286 after year 15, $110,429 after year 20, $0 after year 25. Table: year, loan paid, interest, loan left. Caption "Each year: the part of the EMI that pays the loan, the part that is interest, and the loan left."
5. AppButton primary "Save these numbers". Caption "Saved as a preset on this phone. Results come only from the numbers you enter."

## Monthly close and settings

**X70 Monthly close** — FormScreen, Close, "Close September", sub-line "Monthly close" · Plan (v_e_close)

1. 0Hero (number): kicker "CLOSE SEPTEMBER · STEP 2 OF 5"; "6 min"; line "Time left, about. You can stop and continue later. Each step can be skipped." 5-part strip: 1 done, 2 current (spoken "Step 2 of 5. Step 1 done.").
2. GlassCard "Steps" (meta "5"): ordered list, 34 pt circles (check when done, else number; current marked), 44 pt "Skip" on each open step except the last (Skip marks the step skipped in place; the list stays on this screen): 1 Import statements "3 of 4 accounts. Visa card: missing." (done); 2 Clear the Inbox "12 to check" (current); 3 Update values "Pension: last real value 31 Jul"; 4 Check open items "1 reimbursement, 0 transfers"; 5 Save September "Snapshot and summary" (no Skip). Readers hear "Done:", "Current step:" or "Next:" first.
3. AppButton primary "Continue: clear the inbox".

**X71 Month summary** — FormScreen, Close, "September summary", sub-line "Monthly close" · Plan (v_e_summary)

1. 0Hero (number): kicker "SEPTEMBER SUMMARY · YOU KEPT"; $3,880; line "47% of money in. August: 41%."
2. GlassCard (stage) "Kept, % of money in" (meta "6 months"): data.flow.moneyIn columns with % above: Apr 38%, May 44%, Jun 36%, Jul 42%, Aug 41%, Sep 47% (Sep solid, earlier lighter). Spoken label, table.
3. GlassCard "September": Net worth $182,410 "30 Sep · +$1,710 in September" (X40); Spending $4,320 "of $5,200 limit" (X30); Largest category $1,800 "Rent" (X36); Fees and interest $58 "paid in September" (X58).
4. AppButton primary "Save and finish". Caption "Saved on this phone. A recovery snapshot is made on this phone after you finish."

**X80 Settings** — DetailScreen, DetailHeader with Back, "Settings", sub-line "on this phone"; keeps the tab bar · Home (v_e_settings)

1. 0Hero without number: kicker "SETTINGS"; "Everything is on this phone."; line "Encrypted. No account. No server."
2. Five GlassCards, rows with grey icon tiles (name, value, chevron), in order:
   - "Capture": Capture sources "3 on" (X81); Categories and rules "16 categories" "24 rules" (X84); Import layouts "3 saved" (X63).
   - "Money": Main currency "USD"; Accounts "9" (X40); Month starts on "1st"; Number format "1,234.56".
   - "Screens and widgets" (meta "tab screens"): "Main number on Home" "Net worth" (X13); Home, Spending, Money in, Wealth, Investments, Calendar, Goals, Protect, Tax, each with its widget count, each opens edit mode (WIDGETS-001); last row "Restore the default widgets" (text.primary).
   - "Safety": App lock "Face ID"; Recovery on this phone "Last snapshot" "Sun 11 Oct" (X83); Privacy and network "Prices only" (X86).
   - "App": Features "Simple mode" (X85); Appearance "System"; About and open source "Version 1.0".
3. No export or sync control.

**X81 Capture sources** — DetailScreen "Capture sources", sub-line "Settings" · Home (v_e_capture)

1. 0Hero without number: kicker "CAPTURE SOURCES · 3 OF 4 ON"; "Each source runs on this phone."; line "Each one is off until you turn it on."
2. GlassCard "Automatic" (meta "on this phone"), ToggleRows with icons: Payment notifications (on) "Android only. Reads 3 bank apps you choose. Full text is not kept."; Apple Wallet accounts (off) "iPhone only, where FinanceKit is available"; Staging folder (on) "A folder that belongs to the app, on this phone. PDF and CSV."; Repeating payments (on) "Adds them on their dates".
3. GlassCard "Prices" (meta "network"): ToggleRow Price and instrument updates (on) "Sends public symbols only. Never amounts, holdings or account names."; Last update "Today, 4:00 pm".
4. GlassCard "Status" (meta "last run"): Notifications "Last read 8:42 am" "6 new" (X60); Staging folder "Last read when the app opened, 8:40 am" "None new"; Repeating payments "Spotify added on 9 Oct" (X34).
5. GlassCard: Statements from mail apps "No email connection. Share the file to Contour." (X63).

**X83 Private recovery** (id X83Backup) — DetailScreen "Private recovery", sub-line "Settings · Safety" · Home (v_e_backup)

1. 0Hero without number: kicker "RECOVERY · ON THIS PHONE"; "Last snapshot: Sunday, 11 Oct."; line "9:02 am. 2.4 MB. Encrypted. It stays on this phone."
2. GlassCard "Schedule": ToggleRow Weekly snapshot (on) "Runs when the phone allows; it finishes after you unlock."; How often "Every week"; Keep "Up to 8 snapshots".
3. GlassCard "Snapshots" (meta "8 of 8"): Sun 11 Oct "9:02 am · checked" 2.4 MB; Sun 4 Oct "9:01 am · checked" 2.4 MB; Sun 27 Sep "9:03 am · checked" 2.3 MB. Caption "And 5 more, back to 23 Aug. A completed month close adds one more."
4. AppButton primary "Make a snapshot now"; AppButton ghost "Restore a snapshot". Caption "Restore asks you to confirm. It replaces the data on this phone with the snapshot you choose."
5. GlassCard "What recovery cannot do": "A snapshot cannot recover a lost phone, a removed app or a reset phone. It is not in iCloud, Google Drive or a phone-to-phone transfer."

**X84 Categories and rules** — DetailScreen with Back and the tab bar, sub-line "Settings"; no header Add (the tab bar has the one Add); text action "Add a rule" at the end of the Rules card · Home (v_e_rules)

1. 0Hero without number: kicker "CATEGORIES AND RULES · 24 RULES"; "Rules come from your corrections."; line "The app asks before it creates one."
2. ChipRow "Show" (control row): Categories · Rules (selected).
3. GlassCard "Rules" (meta "most used"): category-colour icon, "When name has ...", "Category: ...", use count: Whole Foods → Groceries 12x; Uber → Transport 8x; Netflix → Subscriptions 6x; "salary acme" → Income, Salary 10x. Caption "And 20 more. The number is how many times a rule was used."

**X85 Features** — DetailScreen "Features", sub-line "Settings" · Home (v_e_features)

1. 0Hero without number: kicker "FEATURES · 0 OF 10 ON"; "Advanced features are off, so the app stays simple."; line "Turn on only what you need. Turning one off hides it and keeps its data."
2. GlassCard: ToggleRow Simple mode (on) "Shows only the essentials".
3. GlassCard "Advanced" (meta "each off"): ten ToggleRows (off) with one-line descriptions: Returns; Compare with a benchmark; Joint accounts; Custom budget periods; Trips, projects, events; Money flow chart; Report builder; Simulations "5,000 possible futures for withdrawals"; Time machine; Family view.

**X86 Privacy and network** — DetailScreen "Privacy and network", sub-line "Settings" · Home (v_e_privacy)

1. 0Hero without number: kicker "PRIVACY AND NETWORK"; "This app talks to 1 service."; line "Only after you turned it on."
2. GlassCard "Network" (meta "turned on"): Price service "Sends public symbols only. Never amounts, holdings or account names." (X81); ToggleRow Turn off all network (off) "Prices stop. Everything else works. Asks you to confirm."
3. GlassCard "On this phone": Database "Encrypted" 18 MB; Speech recognition "On this phone only"; Text recognition "On this phone only"; Recovery snapshots "On this phone only" (X83).
4. AppButton destructive "Delete all data". Caption "Asks you to confirm. Removes records, snapshots, keys and cached prices from this phone."

**X82 Statements from mail apps** — history only: removed from the gallery (SCREEN-SET-001). Not built. ARCH-001: no route. The rule "share the file from your mail app" stays in the X81 card and in X63.
