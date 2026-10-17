## Authority and readiness

- Owners: SPEC owns behaviour and numbers. SYSTEM_DESIGN owns storage, workers, privacy and recovery. DATABASE_DESIGN owns tables and write boundaries. DESIGN owns components. This guide does not override them.
- Gallery: the 3 portfolio previews apply PERF-001; the other 84 keep older content. Do not copy sample figures or HTML handlers into domain code.
- ARCH-001: no routes for email, exports, backup folders, device transfer or financial widgets. Only public market data uses the network.
- PF-01: blocks real-user iOS persistence and release until phone confinement is proven.

### Status words

- Defined: build it from the current SPEC.
- Correction gate (Gxx): fix the cited SPEC/DESIGN/schema text in a docs change first. Unrelated flows can proceed. A gate is prerequisite work, not a request for approval.
- Design gap (Cxx): no screen reference. Define reference and acceptance states first. Do not invent an X id.

## Correction gates

| Gate | Correction (detail in the reference) | Flows |
|---|---|---|
| G01 Account prerequisites | Basic bank, cash, card setup and opening balances move to the base phase; inclusive balance anchor. | F01, F03, F05, F06, F10 |
| G02 Identity and confirmation | Equal content is only a match candidate. One Expected occurrence with an unpaid remainder; confirm before actual. | F05–F07, F09, F13–F14 |
| G03 Investment events | Linked cash/security events, exact quotes. Observations never invent trade history. | F10–F13 |
| G04 Basic returns | XIRR/TWR move to v1 Phase 4; fix the TWR flow-timing error. | F11 |
| G05 Entry and action hierarchy | Search below Home title; Main number in Settings; Repeating Add opens a schedule form; Inbox decision before Confirm. | F02, F07, F09, F19 |
| G06 Undo access | Toast plus persistent history; undo whole event or batch. | All confirmed writes |
| G07 Local capture engines | Verified local engines only; no cloud fallback. | F04, F06, F12, F19 |
| G08 Provider capture | No email/Drive/IMAP; local attachments only. X82 has no route. | F19 |
| G09 Goals and expected values | Allocations max 100%; a future schedule is not a balance. | F14–F17 |
| G10 Month close | Closed only after Save and finish; immutable revisions. | F02, F18 |
| G11 Local recovery | Same-device encrypted generations; atomic replacement; no export or merge. | F20 |
| G12 Draft lifecycle | Encrypted drafts; Back keeps, Discard deletes, Save clears. No expiry. | F03–F06, F10, F15–F17 |
| G13 Transfer cost | Post the charged fee once; FX spread is a comparison only. | F05 |
| G14 Financial definitions | Net worth bridge, calculator formulas, dated fixtures. No residual. | F02, F08, F10, F17–F18 |

## Journey map

Open app → Welcome or unlock → Home

Share or import file → Parse and preview

- Parse and preview → Add or capture → Editable draft → Save confirmed record → Refresh affected views and offer Undo
- Parse and preview → Review Inbox → Save confirmed record → Refresh affected views and offer Undo
- Home → Spending
- Home → Wealth → Investments and Returns
- Home → Plan → Monthly close → Private recovery snapshot
- Home → Settings → Private recovery snapshot

### Flowchart nodes

- Open app
- Welcome or unlock
- Home
- Share or import file
- Parse and preview
- Add or capture
- Editable draft
- Review Inbox
- Spending
- Wealth
- Investments and Returns
- Plan
- Monthly close
- Settings
- Save confirmed record
- Refresh affected views and offer Undo
- Private recovery snapshot

## Shared rules

### Navigation

- Home, Spending, Wealth, Plan are tabs. Add opens a form or chooser, not a tab.
- Back restores period, filters, account, scroll and focus. Re-select a tab → its root.
- Sheets keep the parent route. Done copies edits to the parent draft; Cancel drops only the sheet edits.
- Add context follows SPEC 5.3 and the host route.
- Every entry (tab, link, deep link, notification, shortcut) checks release, feature, platform and permission. An unavailable target returns to its nearest parent.
- A deep link waits behind unlock. It never replays Save, Confirm or Delete. No amounts or content in URLs or logs.

### Drafts and saving

- Parsers make drafts only. No actual record before Save or Confirm.
- Manual, voice and receipt forms: Save commits directly. File import: Send to Inbox stages; Confirm commits.
- Save: block repeat taps → validate → one transaction with ChangeLog → clear draft. On failure, keep the draft and write nothing.
- Retry uses the same operation id. Undo reverses the whole event or batch.
- Audio is never saved. Transcripts clear on Save, Cancel, leave, background or lock.
- Missing required values are never filled with zero.

States every flow handles: first use, loading, Missing, Estimated/old quote, Expected, denied permission, offline, Hidden, Not available, deleted target, interrupted operation. Behaviour per state: reference, "States that every flow must handle".

## Journeys

Each line: main path · what commits · checks. Full steps and recovery: reference.

| Flow | Task | Release | Path · commit | Checks |
|---|---|---|---|---|
| F01 | Start and unlock | v1 P1; G01 | `X01Welcome` → currency → `X03HomeFirstRun`; later `X02Lock`. Commits settings and first account only. | A–C |
| F02 | Read Home, inspect a number | v1 P4 | `X10Home` → `X40bAboutNumber` / `X14ToUseBreakdown`; Hide → `X12HomeHidden`; `X15Search`. Preferences only. | A–C |
| F03 | Add or edit expense or income | v1 P2 | `X20AddExpense` → X21 / X22 / X23Split → Save. One transaction; Undo. | A–D |
| F04 | Voice, QR, receipt | Voice P2; QR P3 | `X87` → X24 / X25; `X27ScanQR`; `X28ReceiptReview`. Save per F03. No audio kept. | A–D |
| F05 | Transfers, card payments | v1 P2; FX v1.1 | `X26Transfer` / `X26bTransferFX`. Linked debit and credit; fee once (G13). | A–E |
| F06 | Import a file | v1 P3 | `X63` → X64 / X66 / X67 → `X65ImportPreview` → `X68ImportDone`. Stages drafts only. | A–D |
| F07 | Review the Inbox | v1 P2 | `X60Inbox` → X61 → Confirm. One batch transaction; limits 5,000 rows / 100,000 effects / 16 MiB. | A–D |
| F08 | Spending and payments | v1 P2 | X30–X39; filter X38; delete `X39bDeleteDialog`; limits X33. Soft delete; limits only. | A–F |
| F09 | Categories, rules, repeating | v1 P2 | `X84Rules`, X34 → X35. Rule or schedule only; no payment. | A–D |
| F10 | Accounts and balances | v1 P4; G01 | `X40` → X29 / X42 → C01; X41 → `X41bUpdateValue`. Account plus dated value. | A–E |
| F11 | Portfolio and returns | P4; G04 | `X43` → `X43g` / `X43j` / X44 / X43b–f, h. Read only. | A–F |
| F12 | Positions and history | P3 drafts | `X63` → `X45UpdatePositions` / F06. Observation only; never invent history. | A–E |
| F13 | Shares from work | v1 P4 | `X49VestTracker` → Inbox → Confirm. Vest, lot, tax once. | A–D |
| F14 | Calendar and forecast | v1 P4 | `X50` → X51 / `X50bCashFlow`. Future items stay Expected. | A–E |
| F15 | Goals | v1.1 | `X52` → `X53NewGoal`. Goal and links only; max 100%. | A–D |
| F16 | Documents and protection | v1.1; v1.2 | `X69Payslip`, `X69b` → X55 / X56 / X57. Linked records atomically; no export. | A–D |
| F17 | Tax and calculators | v1.2 | `X58Tax`, X59 → `X59bHomeLoanCalc`. Presets only; no account. | A–E |
| F18 | Monthly close | v1 P4 | `X70MonthClose` → 5 steps → `X71MonthSummary` → Save and finish → F20. | A–E |
| F19 | Settings and sources | base; v1.1 | `X80` → X81 / X84 / X85 / X86 / X83. Enabled state after setup only; prices off by default. | A–F |
| F20 | Same-device recovery | v1 P4 | `X83Backup` → snapshot or restore (C09). Atomic switch; never merge. | A–F |
| F21 | Privacy and deletion | v1 base | `X86Privacy` → network off / Delete all (confirm). Removes all data, snapshots and keys. | A–E |

## Components without screen references

C01 account or asset editor · C02 scheduled payment editor · C03 category or rule editor · C04 investment event editor · C05 policy and claim editors · C06 activity history and Undo · C07 selectors and metric tables · C08 tax, limit and calculator forms · C09 restore and destructive confirmation · C10 settings and permission forms · C11 draft lifecycle · C12 account and asset-group list. Entry, result and template for each: reference.

## Build order

1. Fix the gates the next feature needs. Never mix doc fixes and feature code.
2. Money, date, state types; repository transactions; record identity; ChangeLog.
3. Layout templates and state variants (Missing, Expected, old price, hidden, large text).
4. F01, F03, F07 with basic accounts; then capture, import, Spending, repeating.
5. Wealth and investment history before performance. Fixtures before XIRR, TWR or the net worth bridge.
6. Calendar, monthly close, recovery. Later Plan features after their gates pass.

Every task names its contract: flow and steps, screens, SPEC/DESIGN/gate refs, inputs, actions, read model, commit boundary, written records, success, failures, cancellation, checks. Example: reference, "A task must name its contract".

Acceptance families: navigation, draft and commit, financial correctness, recovery, interface, privacy, usability, release. Fxx-A ids are requirements, not tests already run.
