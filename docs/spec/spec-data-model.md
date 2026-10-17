# Contour — SPEC reference: Data model (SPEC_DATA_MODEL.md)

- Part of the SPEC reference. Same authority and section numbers as `SPEC.md` and `SPEC_REFERENCE.md`: "SPEC n.n" resolves here for these sections.
- Version 1.1.3 — 16 October 2026. Text moved unchanged from SPEC_REFERENCE.md.

## 9. Data model

- Authored tables: `id` (UUID v7 text), `createdAt`, `updatedAt` (UTC), `deletedAt` (soft delete).
- Projections, indexes, market caches and staging follow DATABASE_DESIGN and SYSTEM_DESIGN keys and retention. Their maintenance writes no ChangeLog; confirmed user changes always do.
- The reference schema covers the shared foundation. Later families need their own migrations first.
- Money fields end in Minor, with currency beside them. Value records carry source (imported, captured, manual, computed) and, where relevant, sourceRef (file hash, message id, notification id).

### 9.1 Settings and people

- Settings: mainCurrency, locale, numberFormat (standard, indian), weekStart, monthStartDay (1–28), lockTimeout, theme (system, light, dark), hideAmounts, homeMainNumber (available, netWorth, spent, cash), priceUpdates (off, manual, onOpen, daily), priceProviderId, keepReceiptImages, blockScreenshots (Android), refundMonth (refundDate, purchaseDate), carryUnspent, defaultBenchmarkId, networkOff, features (JSON switches).
- Person: name, relation (self, partner, child, parent, other). For dependants, nominees, policy members, spending tags, family view (v2).

### 9.2 Accounts, assets and values

- Account: name, type (bank, cash, wallet, card, brokerage, equityPlan, pension, deposit, property, vehicle, preciousMetal, privateFund, privateShares, insuranceCashValue, collectible, loan, payLater, moneyLent, moneyBorrowed, taxDue, other), currency, institution, isLiability, isLiquid, includeInNetWorth, ownershipPercent (default 100), minimumBalanceMinor (nullable, user), overdraftLimitMinor (nullable), archived, colour, personId (nullable).
- BalanceSnapshot: accountId, date, balanceMinor, currency, source, sourceRef.
- ValuationRule: accountId, method, parameters (JSON), lastRealValueMinor, lastRealValueDate. A new real value restarts the projection.
  - marketPrice.
  - interest: principal, annual rate, compounding (simple, monthly, quarterly, yearly), start, maturity, renewsAutomatically. At maturity: "Matured", no growth.
  - contribution: last balance, monthly contribution, employer part, annual rate, contribution day.
  - weightPrice: weight, unit (g, oz), purity, metal symbol or manual unit price.
  - manual: value, date, optional reminder interval.
  - depreciation: purchase value, date, yearly rate.
  - capitalAccount: commitment, called, distributions, latest reported value.
- CardDetails: accountId, creditLimitMinor, statementDay, dueDay, minimumRule (JSON), payingAccountId, annualFeeMinor, annualFeeDate.
- LoanDetails: accountId, originalMinor, rate, rateType (fixed, floating), nextResetDate, emiMinor, emiDay, endDate, prepaymentRule (text), payingAccountId, linkedAssetId (nullable).
- CardStatement: accountId, closeDate, dueDate, fullAmountMinor, minimumMinor, status (open, paid, partlyPaid), sourceRef.

### 9.3 Payments, income and budget

- Transaction: accountId, date, amountMinor (negative = out), currency, merchantRaw, merchantName, note, categoryId (nullable), kind (expense, income, transfer, refund, fee, loanIn, saleProceeds), transferPairId, refundOfId, isReimbursable, reimbursementStatus (none, expected, received), source, sourceRef, importBatchId, dedupeHash, isEstimated.
- TransactionSplit: transactionId, categoryId, amountMinor, note; splits sum to the amount.
- TransactionLine (receipt items): transactionId, description, quantity, amountMinor.
- TransferFx: transactionId (sender), sentMinor, sentCurrency, receivedMinor, receivedCurrency, rate, midRate, feeMinor, service. Fee is also a fee transaction.
- Category: name, parentId, kind (expense, income), colour, icon, sortOrder, archived, isEssential (user tag).
- CategoryRule: matchType (merchantEquals, merchantContains, regex, amountRange), pattern, categoryId, priority, createdFrom (user, learned, default), hitCount.
- Tag, TransactionTag.
- RecurringRule: name, kind (bill, subscription, income, investment, premium, emi, transfer), amountMinor, currency, categoryId, accountId, schedule (RRULE), startDate, endDate, autoCreate, isAutopay (user), trialEndDate, renewalDate, cancelUrl (inert text; never launched, copied or shared), lastAmountMinor, lastGeneratedDate.
- PriceChange: recurringRuleId, date, oldMinor, newMinor.
- Budget: month (YYYY-MM), periodType (monthly; v2 weekly, custom), name, startDate, endDate. BudgetLimit: budgetId, categoryId, limitMinor. BudgetTemplate: categoryId, limitMinor.
- Payslip: date, employer, grossMinor, netMinor, taxWithheldMinor, pensionMinor, sharePlanMinor, otherDeductions (JSON), benefits (JSON), currency, matchedTransactionId, sourceRef.
- ExpectedIncome: source, amountMinor, currency, expectedDate (nullable), isEstimated (from recurring income or payslips).

### 9.4 Investments

- Security: symbol, exchange, market (listing country), name, type (stock, etf, fund, bond, gold, crypto, cash, other), assetClass (stocks, equityEtfs, mutualFunds, bonds, gold, cash, other), currency, sector, industry, isin, userTags.
- FundHolding (optional, "Include what is inside funds"): securityId, constituentName, sector, country, weight.
- Holding: accountId, securityId, quantity (Decimal), costMethod (average, fifo).
- Lot: holdingId, acquiredDate, quantity, costMinor (incl. fees, taxes), fxRateAtPurchase, source (buy, vest, espp, transfer, other), grantId.
- InvestmentTransaction: accountId, securityId, date, type (buy, sell, dividend, interest, drip, dividendInKind, split, transferIn, transferOut, vest, esppPurchase, fee, returnOfCapital, stakingReward), quantity (Decimal), priceDecimal (exact quote precision), amountMinor, feeMinor, taxMinor, currency, fxRate, source, importBatchId, dedupeHash; optional order evidence effectiveAt, orderSequence, orderScope, orderSource.
  - Unknown same-day order blocks order-sensitive results (G03 / G04).
  - Cash effects link through one FinancialEvent to canonical Transactions; the investment amount is not a second cash posting.
- RealisedGain (computed, versioned per sale): investmentTransactionId, costMinor, proceedsMinor, gainMinor, holdingPeriodDays. Derived generation-scoped LotAllocation rows give lots, quantity and cost used. Acquisition/disposal facts and cost-method choices stay authored. Saved closes copy needed allocation outputs. lotsUsed is not a source of truth.
- PriceQuote: security/market-series identity, date, priceDecimal (exact text), currency, source/provider, basis, interval, revision, observedAt (nullable), fetchedAt. Precision is independent of currency minor units. Corrections append immutable observations; current pointers and evidence pins are separate. Foundation DDL: daily closes only; spot/intraday needs a reviewed extension.
- FxRate: base, quote, date, rate (Decimal), source; manual or local only (10.5).
- Benchmark: securityId, name, isDefault.
- TargetMix: grouping (assetClass, market, sector, currency), targets (JSON group → %).

### 9.5 Shares from work

- EquityGrant: employer, securityId, type (rsu, espp, option, other), grantDate, totalShares, accountId.
- VestSchedule: grantId, schedule (RRULE), sharesPerEvent, firstDate, lastDate, taxWithholdingMethod (sellToCover, netShares, none, unknown).
- VestEvent: grantId, date, sharesExpected, sharesReceived, sharesSoldForTax, taxWithheldMinor, status (upcoming, toConfirm, confirmed, skipped). Upcoming = "Expected".

### 9.6 Protection, plans and records

- InsurancePolicy: type (health, life, disability, home, vehicle, travel, liability, other), insurer, policyNumber, coverMinor, excessMinor, premiumMinor, premiumSchedule (RRULE), renewalDate, startDate, coveredPersonIds, coveredAssetId, nomineePersonIds, cashValueMinor (nullable), claimSteps, contactPhone, sourceRef.
- Claim: policyId, date, description, claimedMinor, paidMinor, paidDate, status (open, paid, rejected).
- Goal: name, targetMinor, currency, targetDate (nullable), type (general, emergencyFund, netWorthTarget), sortOrder, counts (netWorthTarget only: netWorth, investmentsAndCash, chosenAccounts), countedAccountIds (chosenAccounts only). A netWorthTarget measures the chosen value: no GoalAllocation, assigns no money, never in "Assigned to goals" or "Not assigned".
- GoalAllocation: goalId, accountId, percent.
- TaxDate: name, date, amountMinor (nullable), kind (filing, payment), taxYear, country.
- TaxSavingLimit: taxYear, limitMinor, note (user). Contributions count from tagged transactions.
- Debt: direction (lent, borrowed), personId or counterparty text, principalMinor, currency, startDate, dueDate, status (open, settled). DebtPayment: debtId, date, amountMinor, transactionId.
- EmergencySheetEntry: section, title, details (JSON), linkedEntityId. Never stores passwords.
- ContributionLimit (v1.2): accountId, year, limitMinor.

### 9.7 Snapshots, imports, Inbox and history

- NetWorthSnapshot: date, totalAssetsMinor, totalLiabilitiesMinor, currency, breakdown (JSON by type, currency, account), attribution (JSON: kept, markets, currency, values). "Save and finish" saves an immutable close revision (sequence, prior revision, cutoff, method version, source revisions, coverage) and pins its evidence. A correction adds a revision; never overwrite. Unsaved month-end views stay projections.
- ImportBatch: source, fileName, fileHash, importedAt, rowCount, acceptedCount, rejectedCount, templateId, status (review, done, undone).
- ImportMappingTemplate: name, source (csv, excel), headerSignature, columnMap (JSON), dateFormat, decimalSeparator, amountSign, accountId.
- ParserTemplate: name, institution, sourceType (pdf, csv, email, notification), kind (statement, payslip, loanStatement, policy, broker), fingerprint, rules (JSON), version, origin (builtIn, user, importedFile). Data, never code.
- InboxItem: source, sourceRef, receivedAt, proposedEntity (JSON), matchedEntityId, suggestionType (new, merge, transfer, refund, recurring, categoryChange, vestConfirm, payslipMismatch), confidence, isTicked (default true only at high confidence), decision (pending, accepted, deleted, edited), decidedAt.
- CaptureSource: type (notifications, financeKit, localFolder), enabled, settings (JSON), lastRunAt, lastRunResult.
- MonthClose: month, startedAt, completedAt, steps (JSON).
- ChangeLog: entityType, entityId, field, oldValue, newValue, deviceId, timestamp, batchId. For undo and local activity; not an upload or sync queue.
- CalculatorPreset: toolId, name, inputs (JSON).
- PDF passwords and optional market-provider credentials: secure storage only. No email credentials exist.

### 9.8 Computed views and local projections

- Cash flow, available money, attribution, allocations, calendars and returns are derived, not facts.
- Rebuildable projections and checkpoints live in the encrypted database. Each result carries source revision, algorithm version, scope, dates, currency, coverage. Never show an old result as current after a relevant edit.
- Confirmed records and source observations are authoritative. Derived storage can be rebuilt without changing history. Month-close revisions are records, not caches.
- Write dirty ranges and dependency revisions atomically with the change. Publish only if captured revisions are still current (DATABASE_DESIGN, SYSTEM_DESIGN).

### 9.9 Database lifecycle and supporting records

DATABASE_DESIGN owns constraints, checks, query limits, retention, migration and recovery. It does not replace open finance definitions in gates G01–G14.

- Recurring occurrences (DATABASE_DESIGN 4.3): proposals and locators are operational rows. A user accept, edit, skip, match or cancel appends an authored decision and selects an auditable pointer, in the same transaction as any obligation or settlement. Generation never posts actuals or changes a decided occurrence. Scheduled occurrences are stable across rule edits. Expected is not actual. One canonical obligation with typed settlement allocations prevents double subtraction across statement and rule aliases.
- One Confirm (DATABASE_DESIGN 6): ≤ 5,000 source rows, 100,000 row effects, 16 MiB plan. Over the limit: drafts stay, nothing is written, the user picks a smaller set. Never split silently into partial commits.
- FinancialEvent groups one command's cash, investment, lot and settlement effects. Transaction is the one canonical cash posting.
- OperationIntent (with bounded immutable input chunks) records a command; OperationReceipt proves commit. Retries reuse identity and digest; a changed command gets a new ID after the old outcome resolves.
- SourceIdentity: unique by non-null namespace, source-account scope and row identity. A content hash is only a candidate. Undo and delete keep source identity.
- Balance and position observations keep original evidence; corrections append; selected pointers keep provenance.
- CloseRevision and immutable input references keep saved history. DependencyRevision, conservative dirty envelopes and staged/published generations govern derived results.
- Draft versions, import staging and source claims survive interruption. Save or Discard removes payloads only after the outcome is known.
