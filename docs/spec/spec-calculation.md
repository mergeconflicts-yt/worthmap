# Contour — SPEC reference: Calculators, formulas and sample data (SPEC_CALCULATIONS.md)

- Part of the SPEC reference. Same authority and section numbers as `SPEC.md` and `SPEC_REFERENCE.md`: "SPEC n.n" resolves here for these sections.
- Version 1.1.3 — 16 October 2026. Text moved unchanged from SPEC_REFERENCE.md.

## 13. Calculators and formulas

- Pure Dart functions in `domain/calculators/`, with unit tests. Test inputs in brackets.
- Screen: inputs card, large result number, one chart or split bar, details list or table, "Save these numbers".
- State results only as output of the user's inputs.

### 13.1 Monthly investing (SIP and lump sum)

- Year y (0-based): m = monthly × (1 + stepUp)^y. Each month: balance = balance × (1 + annualReturn/12) + m.
- Test: [monthly 70,000; lump 0; 10 years; 10%; step-up 5%] → value 17,332,732, invested 10,565,430, last monthly amount 108,593.

### 13.2 Goal amount

- futureCost = cost × (1 + inflation)^years. need = max(0, futureCost − saved × (1 + r)^years). monthly = need × (r/12) / ((1 + r/12)^(12·years) − 1). lumpToday = need / (1 + r)^years.
- Test: [cost 5,000,000; 15 years; inflation 8%; return 10%; saved 0] → futureCost 15,860,846, monthly 38,268, lumpToday 3,796,960.
- Goals screen (simple form, no return): monthly = (target − current) ÷ months until the date. Test: [6,000; 1,935; 5 months] → 813.
- Net worth target (same simple form, "Est. amount to go ÷ months left"): [1,000,000; 187,900; 170 months to Dec 2040] → 4,777. Share reached = current ÷ target → 18.8%.

### 13.3 Target mix

- Per group: current share, target share, difference in main currency = (current − target) × total.
- Show the difference only. Never show it as buy or sell.

### 13.4 Financial independence

- living = monthlySpending × 12 / withdrawalRate. dependants = monthly × 12 × years + reserve. subtotal = living + one-time costs (user lines). total = subtotal × (1 + margin).
- Test: [monthly 100,000; rate 3.33%; house 20,000,000; education 12,500,000; weddings 5,000,000; medical 5,000,000; dependant 30,000 × 12 × 15 + 2,000,000; margin 10%] → 94,529,640 (±1).

### 13.5 Withdrawals

- Each year: balance −= spending × (1 + inflation)^y; then balance × (1 + return). Stop at age 100 or when balance ≤ 0. Chart in today's money.
- Test: [36,000,000; 1,200,000; age 50; return 9%; inflation 6%] → lasts to 100.

### 13.6 Inflation

- future = amount × (1 + i)^years. presentValue = amount / (1 + i)^years.
- Test: [1,000,000; 17 years; 6%] → 2,692,773, presentValue 371,364.

### 13.7 Home loan

- EMI = P × r × (1+r)^n / ((1+r)^n − 1), r = annualRate/12. Monthly schedule, optional extra payment.
- Test: [price 20,000,000; down 20%; 8.5%; 20 years] → EMI 138,852, total interest 17,324,480 (±240). Extra 10,000 a month → 204 months, interest difference 3,106,408 (±500).
- Design sample: [price 400,000; down 20%; 6.5%; 25 years] → EMI 2,161, total interest 328,210 (±50).

### 13.8 Rent or own

- Monthly simulation. Owner pays EMI (until paid) + upkeep (% of house value per year / 12). Renter pays rent (grows yearly).
- Renter starts with the down payment and purchase costs invested. Each month the lower-cost side invests the difference.
- Owner wealth = house value − loan balance + owner investments. Renter wealth = renter investments.
- Show both values and the difference. Never say which is better.

### 13.9 Life cover

- presentValue = yearlySpending × (1 − (1 + realReturn)^−years) / realReturn (× years if realReturn is 0). result = presentValue + goals + loans − investments − existingCover, minimum 0.
- Test: [1,200,000; 20 years; 2%; goals 17,500,000; others 0] → 37,121,733 (±1,000).

### 13.10 Emergency fund

- monthsCovered = fund / monthlyExpenses. amountForChosenMonths = monthlyExpenses × months. difference = amountForChosenMonths − fund.
- Test: [70,000; 9 months; 400,000] → 5.71 months, 630,000, difference 230,000.

### 13.11 Currency

- converted = amount / rate(from→USD) × rate(USD→to) × (1 − fee).
- Test: [100,000 TWD; 32 TWD/USD; 96 INR/USD; fee 0.5%] → 298,500 INR, 3,109.38 USD.
- Transfer cost (X26b): received = (sent − fee) × rate. rateCost = (sent − fee) × (midRate − rate) / midRate. Test: [2,000 USD; fee 12; rate 83.20; mid 83.45] → received 165,402 INR, rate cost 5.96 USD, total cost 17.96 USD (shown $18).

### 13.12 Returns and benchmarks

- Time-weighted (TWR): split the period at every external cash flow. Sub-period r = endValue / (startValue + flow) − 1 (flow at start of day), the same as (endValue − startValue − flow) / (startValue + flow). TWR = Π(1 + r) − 1. Per year only for periods over 1 year: (1 + TWR)^(365/days) − 1.
- Test (FIN-3-01): start 100, flow +100 at the start of the day, end 220 → r = 10%. The old `/ startValue` form gave 20%.
- Money-weighted (XIRR): dated cash flows (deposits negative, withdrawals positive, end value positive). Newton–Raphson, then bisection. No solution → "Not available".
- Dividends and interest count as return. Fees and taxes reduce return.
- Benchmark: indexed to 100 at period start, same scale as the holdings' TWR index.
- Test: a fixture with known flows and values gives TWR and XIRR within 0.01 points of a reference calculation. More PERF-001 cases: docs/DECISIONS.md.

### 13.13 Cost basis and realised gains

- Average cost (default) or FIFO per account. Buy fees and taxes add to cost. Sell fees reduce proceeds. Splits change quantity and per-share cost, not total cost. Return of capital reduces cost.
- Realised gain per sale = proceeds − fees − cost of shares sold (by the method). Holding period from lot dates.
- Currency effect per lot in another currency = value at today's rate − value at purchase-date rate, price held constant.

### 13.14 Withdrawals: simulations, stress tests, sensitivity (v2)

- 5,000 seeded runs; yearly returns from a normal distribution of log returns. Output, numbers only: 10th, 50th, 90th percentile by age (today's money); share of runs in which money lasts.
- Stress tests: −30% and −50% in year one; five years of 0% real return; inflation +2 points for 10 years.
- Sensitivity table: return −2 to +2 points × spending −20% to +20%. Each cell = age money lasts to.
- 5,000 runs under 1 second on a mid-range phone (background isolate).

### 13.15 Target mix: amount per group

- Inputs: user's target mix; amount of new money (negative for money taken out).
- Output per group: the amount that brings the mix closest to target using only that money. Give money first to the largest gaps below target. Split any rest by target shares.
- Title "Amount to reach your target mix". Never use buy, sell or invest.

### 13.16 Loans and debts

- Extra payment: monthly schedule with the extra amount. Show months saved and interest difference.
- Debts: remaining = principal − Σ payments. Interest only if the user enters a rate.

## Appendix A — Sample data set

Used in all designs, golden tests and "Sample data" mode. Every section 6 total must come from this set. Main currency USD. Today: Tuesday 13 October 2026. Next income: 1 November 2026.

### Accounts and assets

| ITEM | VALUE | NOTES |
|---|---|---|
| Checking (First Bank) | $6,450 | cash you can use |
| Savings (Harbor Bank) | $15,000 | cash you can use |
| Investments | $129,800 | 12 holdings, see below |
| Workplace pension | $24,010 Est. | last real value $22,700 on 31 Jul; $500 a month, 5% a year |
| Term deposit (Harbor Bank) | $10,280 Est. | $10,000 at 4.1%, 12 Feb to 12 Nov 2026, $10,312 at maturity |
| Car | $12,000 Est. | depreciation 10% a year |
| What you own | $197,540 |  |
| Car loan (City Auto Finance) | $8,400 | $20,000 original, 7% fixed, EMI $420 on the 30th, 22 EMIs left, last Aug 2028, interest paid $1,840 |
| Visa card | $1,240 | statement 12 Oct, due 22 Oct, minimum $40, limit $6,000 |
| What you owe | $9,640 |  |
| Net worth | $187,900 | +$5,490 this month (kept +$4,260, markets +$1,780, currency −$550); +$16,900 in 12 months |

October attribution example (NUM-001): 30 Sep close to 13 Oct cut-off. Opening $182,410; closing $187,900. Parts: $4,260 + $1,780 − $550 + $0 = $5,490, 3.0% of opening (one decimal).

- Values $0 is set explicitly for this synthetic case, not inferred from absent valuation history. Valuation fixtures supply dated changes; include a nonzero Values part and recalculate opening or closing totals.
- Do not use the superseded September closing $184,480.

Expected, not in net worth: 160 unvested shares ($31,595 at $197.47); owed to you $2,640 (work reimbursement $640, rent deposit $2,000); dividends expected next 6 months $245.

### Cash payments due before 1 Nov (all from Checking):

| PAYMENT | AMOUNT | DATE |
|---|---|---|
| Phone | $45 | 20 Oct |
| Visa card full | $1,240 | 22 Oct |
| Monthly investment into VTI | $500 | 25 Oct |
| Health insurance | $210 | 28 Oct |
| Car loan EMI | $420 | 30 Oct |
| Total | $2,415 |  |

- Cash you can use $21,450. Available until 1 Nov: $19,035.
- Checking forecast: $6,405, $5,165, $4,665, $4,455, $4,035 (lowest, 30 Oct); then $10,435 after salary $8,200 and rent $1,800 on 1 Nov.
- Savings stays $15,000. Total cash before income = $4,035 + $15,000 = $19,035.

Card charge before 1 Nov: Netflix $17.99 on 18 Oct (Visa; price up from $15.49). Shows in the calendar; becomes spending when charged. After the 12 Oct statement close: not in the $1,240 due 22 Oct; its statement payment is outside this forecast. Do not subtract it again from available money.

October so far: money in $8,200 (salary, 1 Oct); spent $3,940 of $5,200; kept $4,260 (52%); 42% of the month gone; same day in September $4,005.

Needs, wants and kept parts: Appendix A sample tags (set by the sample user) on the category tag isEssential: Rent, Groceries, Utilities, Transport are needs; other categories are wants. These tags are sample data, not app defaults (N-10).

| PART | OCTOBER | % OF MONEY IN | 12-MONTH AVERAGE (MONEY IN $9,267) |
|---|---|---|---|
| Needs | $2,890 | 35.2% | $3,005 |
| Wants | $1,050 | 12.8% | $1,000 |
| Invested | $0 (VTI $500 due 25 Oct) | 0.0% | $800 |
| In cash | $4,260 | 52.0% | $4,462 |
| Spent = needs + wants | $2,890 + $1,050 = $3,940 |  | $4,005 (43.2%) |
| Kept = invested + in cash | $0 + $4,260 = $4,260 |  | $5,262 (56.8%) |

- Of October spent: needs 73.4%, wants 26.6%.

| CATEGORY | SPENT | LIMIT | 12-MONTH AVERAGE |
|---|---|---|---|
| Rent | $1,800 | $1,800 | $1,800 |
| Groceries | $620 | $1,200 | $700 |
| Dining | $410 | $600 | $520 |
| Shopping | $380 | $500 | $240 |
| Transport | $260 | $400 | $300 |
| Utilities | $210 | $300 | $205 |
| Other | $170 | $300 | $150 |
| Subscriptions | $90 | $100 | $90 |

Income, last 12 months: $111,200 (salary $98,400, rent from flat $5,800, bonus $6,000 in March, interest and dividends $1,000). 2026 so far: money in $93,700, out $47,300, kept $46,400.

### Investments summary

| MEASURE | VALUE |
|---|---|
| Value | $129,800 |
| Invested | $98,200 |
| Unrealised | +$31,600 |
| Realised 2026 | +$2,140 (see Sales in 2026) |
| Realised all time | +$6,880 |
| Dividends | 2026 $410; all time $1,950 |
| Total gain | +$40,430 = price +$39,174 + dividends +$1,950 + currency −$694 |
| Today | +$550 |
| 1 year | +18.6% time-weighted, +16.9% money-weighted, benchmark +14.1% |

| HOLDING | MARKET | CLASS | VALUE | INVESTED | TODAY |
|---|---|---|---|---|---|
| VTI | US | Equity ETFs | $38,000 | $27,000 | +$96 |
| NVDA (158 shares, from work) | US | Stocks, Technology | $31,200 | $21,900 | +$343 |
| BND | US | Bonds | $15,000 | $15,600 | +$15 |
| Flexi Cap Fund | India | Mutual funds | $8,400 | $5,200 | +$17 |
| AAPL | US | Stocks, Technology | $7,600 | $4,500 | +$30 |
| 0050 | Taiwan | Equity ETFs | $6,000 | $3,900 | +$30 |
| Cash in brokerage | — | Cash | $6,000 | $6,000 | $0 |
| GLD | US | Gold | $4,800 | $4,100 | −$14 |
| Nifty 50 ETF | India | Equity ETFs | $4,200 | $3,400 | +$13 |
| TSMC | Taiwan | Stocks, Technology | $3,600 | $2,600 | +$25 |
| JPM | US | Stocks, Financials | $2,600 | $1,800 | −$10 |
| JNJ | US | Stocks, Health care | $2,400 | $2,200 | +$5 |

Investment account membership (current values at the same cut-off):

| ACCOUNT | TYPE | HOLDINGS | CURRENT VALUE | COST BASIS |
|---|---|---|---|---|
| Brokerage (Harbor Securities) | brokerage | All rows above except NVDA, including the $6,000 cash row | $98,600 | $76,300 |
| Employer share account | equityPlan | The 158 vested NVDA shares only | $31,200 | $21,900 |
| Investments group | Computed total, not another account | The two accounts above | $129,800 | $98,200 |

- Each holding is in exactly one account. The 160 unvested shares stay Expected, outside both accounts.
- Do not add the employer share account again to what you own (it is in Investments).
- Brokerage cash counts once, in its account. It is not cash you can use.

Splits (largest remainder):

- By class: Equity ETFs 37%, Stocks 36%, Bonds 12%, Mutual funds 6%, Cash 5%, Gold 4%.
- By market: US 78%, India 10%, Taiwan 7%, Cash 5%.
- By currency: USD 83%, INR 10%, TWD 7%.

Instrument details (sample rates at cut-off: INR 84.00 per USD, TWD 32.00 per USD; value = quantity × price ÷ rate):

| HOLDING | INSTRUMENT NAME | QUANTITY | PRICE | VALUE (USD) |
|---|---|---|---|---|
| VTI | Vanguard Total Stock Market ETF | 125 shares | $304.00 | $38,000 |
| NVDA | NVIDIA Corporation | 158 shares | $197.47 | $31,200 (exact: $31,200.26; shown to whole dollars) |
| BND | Vanguard Total Bond Market ETF | 200 shares | $75.00 | $15,000 |
| Flexi Cap Fund | Flexi Cap Fund, direct | 8,820 units | ₹80.00 | $8,400 |
| AAPL | Apple Inc. | 32 shares | $237.50 | $7,600 |
| 0050 | Taiwan 50 ETF | 1,000 shares | NT$192.00 | $6,000 |
| Cash in brokerage | Cash in brokerage | — | — | $6,000 |
| GLD | SPDR Gold Shares | 16 shares | $300.00 | $4,800 |
| Nifty 50 ETF | Nifty 50 ETF | 1,260 units | ₹280.00 | $4,200 |
| TSMC | Taiwan Semiconductor | 100 shares | NT$1,152.00 | $3,600 |
| JPM | JPMorgan Chase & Co. | 10 shares | $260.00 | $2,600 |
| JNJ | Johnson & Johnson | 15 shares | $160.00 | $2,400 |

Sales in 2026 (realised +$2,140): AAPL, part of the holding, +$1,610; VXUS (Vanguard Total International Stock ETF), whole holding, +$530. No other sale details in this sample.

By currency (in USD): US dollar $107,600 (82.9%), Indian rupee $12,600 (9.7%), Taiwan dollar $9,600 (7.4%).

Regular investments and vests: $500 into VTI on the 25th monthly (next 25 Oct, Expected). Next vest: 20 of the 160 unvested NVDA on 15 Nov, Expected; $3,949 Est. at today's $197.47. Put into investments in 2026: $6,000.

Dividends by month (Nov 2025 to Oct 2026): 0, 95, 0, 0, 92, 10, 0, 0, 98, 40, 0, 170. Expected Nov 2026 to Apr 2027: 0, 95, 45, 0, 95, 10.

Protection:

| TYPE | DETAILS |
|---|---|
| Health | family of 4, Harbor Health, $50,000 cover, $210 a month, used $1,200 |
| Car | DriveWell, renews 4 Nov, $780, last year $720 |
| Term life | LifeFirst, $500,000, $640 a year on 3 Jan |
| Disability, home, travel | None recorded |

- Premiums a year $3,940.

Goals:

| GOAL | REACHED OF TARGET | FUNDING | DATE / MONTHLY |
|---|---|---|---|
| House deposit | $39,440 of $60,000 | 40% of the Brokerage account's current $98,600 | by Dec 2028 |
| Emergency fund | $15,000 of $30,000 | Savings 100% | — |
| Japan trip | $1,935 of $6,000 | Checking 30% | by Mar 2027, $813 a month |

- Assigned: $39,440 + $15,000 + $1,935 = $56,375. Not assigned: $197,540 − $56,375 = $141,165.
- House goal excludes the Employer share account. Goal allocations are views of existing assets, not added assets.
- Net worth target: $1,000,000 by Dec 2040, counts net worth; $187,900 reached (18.8%), $812,100 to go, $4,777 a month Est. (170 months). Assigns no money; not in Assigned.

Tax (user entered): advance tax $1,800 on 15 Dec; filing on 15 Apr; tax-saving room $4,000 of $6,500; interest earned $590; tax withheld from salary $14,760; tagged medical and donations $1,950; fees and interest paid in 2026 $630 (loan interest $470, currency fees $112, bank fees $48).

Payslip (October): gross $10,400, tax −$1,476, pension −$520, share purchase plan −$204, net $8,200.

Transfer sample: 13.11 transfer test, from Savings to an INR account ($2,000, fee $12, rate 83.20, mid 83.45, received ₹165,402, cost $18).

Month start sample (X11HomeMonthStart, 2 Oct): September closed: money in $8,200, money out $4,320, kept $3,880 (47%; August 41%). Net worth on 30 Sep $182,410. Cash you can use $26,190; 8 payments due before 1 Nov $3,330; available until 1 Nov $22,860.
