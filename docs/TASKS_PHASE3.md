# Contour — Phase 3 Tasks (One-tap imports)

Version: 2026-11-23. Status: **PDF-only slice implemented**; other formats and
capture sources are deferred. See "Delivery status" below and DECISIONS
`P3-PDF-SUBSET`. Scope: v1 Phase 3 only (SPEC 17). Authority order: AGENTS.md, SPEC.md + docs/spec/, SYSTEM_DESIGN in
`docs/approved-architecture/SYSTEM_DESIGN.md`, DATABASE_DESIGN in
`docs/approved-architecture/DATABASE_DESIGN.md`, EXECUTION_SAFETY,
DESIGN.md + docs/design/, docs/screens/SCREENS.md, docs/flow.md +
docs/flows/USAGE_FLOWS_REFERENCE.md. Do not inspect wealthfolio/. PF-01 stays in
force. Use synthetic fixtures only. Do not invent financial or privacy rules.

## Phase 3 scope

SPEC 17, "v1 Phase 3 — One-tap imports":

- Share into the app; CSV and Excel with mapping; OFX, QIF, CAMT.053, MT940;
  PDF with passwords and Teach once; QR receipts; receipt photo; holdings
  screenshot; cross-source merge; batch undo (X27, X28, X63–X68, X88, X45).
- Accept when: fixture files import with expected rows; a second import of the
  same file is detected; a taught PDF template imports the next month with no
  questions; no network calls during imports.

## Delivery status (2026-11-23)

PDF only, per the owner decision recorded in DECISIONS `P3-PDF-SUBSET`.

- Built and tested:
  - P3-01 (partial): layout fingerprint, column bands, save after a usable
    preview and a template version.
  - P3-05 (partial): balance rows are detected and kept out of staging; they do
    not write an anchor (`P3-BALANCE-ROWS`).
  - P3-06 (partial): withdrawal of a whole batch until one row is decided.
  - P3-07 to P3-08, P3-13 to P3-15: PDF reader, text and line extraction,
    statement values, dates, signs and fingerprints. No CSV, Excel or other
    bank formats.
  - P3-16 to P3-19: staging, publication, history, withdrawal and template
    storage over the reference import tables. No schema change.
  - P3-20: the PDF password vault over `SecureStorageApi`, keyed by a SHA-256
    hash of the file name, with the X64 "Remember for this layout" toggle.
    Tests: `test/features/import/import_password_test.dart` (8, including a
    fully RC4-encrypted statement).
  - P3-25, P3-26 and P3-28 units: X63 hub, X64 password, X65 preview, X66 Teach
    once, X68 done and X88 error, their widget tests and 16 goldens. Entries:
    X03 Get started step 2 and X80 Capture > Import layouts.
- Deferred with no route, tile or switch:
  - P3-02, P3-21, P3-22 (file picker and share intake), P3-03, P3-31 (broker
    and position imports), P3-04, P3-23, P3-24, P3-30 (OCR, QR and receipt
    photo), P3-09 to P3-12 (OFX, QIF, CAMT.053, MT940), P3-27 (CSV mapping),
    P3-29 (Inbox producer handover), P3-32 (full phase acceptance).
- Open planning gaps:
  `P3-BALANCE-ROWS`, `P3-TEMPLATE-TABLE`, `P3-INTAKE-BINDING`,
  `P3-CATEGORY-SUGGESTION`, `P3-HISTORY-OPEN`.

## Start state (Phase 2 accepted 2026-11-23)

- Accepted: `docs/PHASE2_ACCEPTANCE.md`; DECISIONS `CLOSED-PHASE2-ACCEPTANCE`.
  P01–P29 are built and reviewed. Two evidence items are accepted exceptions
  (3.1 input target, `P24-ENGINE-EVIDENCE`).
- Present and reusable: `lib/domain/importers/quick_add_parser.dart` (deterministic
  text parsing, per-field confidence); `lib/data/repositories/inbox.dart`
  (`ConfirmInboxBatch`, Q13 page, 5,000 / 100,000 / 16 MiB preflight, batch
  Undo); `lib/data/repositories/payments.dart`, `transfers.dart`, `drafts.dart`;
  `lib/data/db/command_repository.dart` (receipt-first, draft-aware);
  `lib/data/repositories/accounts.dart` (anchors, Missing); the X60–X62 Inbox
  screens; X20–X26 capture forms; `lib/design` charts, forms, overlays and
  feedback components; `HiddenAmountsController`; the app shell and tab bar.
- Present in schema version 8 but without typed reads or writers:
  `import_sources`, `import_parse_configs`, `import_batches`, `import_job_inputs`,
  `staged_rows`, `source_identities`, `source_claims`, `inbox_items`,
  `attachments`, `local_jobs`. Phase 3 adds typed classes and repositories over
  these tables, not a new import model.
- Absent and needed in this phase: `lib/domain/importers/` (CSV, Excel, OFX,
  QIF, CAMT.053, MT940, PDF tables, dedupe, merchant normalisation); import
  repositories; parser-template storage; share intake; PDF text extraction and
  OCR; QR decode; the X27, X28, X45, X63–X68 and X88 screens.
- Unchanged and not closed by Phase 2: `PF-01`, DB-A, DB-B,
  `T07-CIPHER-BUILD`, T08/T11 native bindings, `P21-UNWIRED-GATEWAY`. Release
  start still mounts the unavailable gateways; only the debug demo runs.

## Correction gates this phase needs

A gate is prerequisite documentation work, not user approval. Land the
documentation change in its own pull request before dependent feature code
(USAGE_FLOWS "Implementation handoff" step 1; AGENTS 9).

| Gate | Blocks in Phase 3 | Status | Task |
|---|---|---|---|
| `G01` Account prerequisites | Statement balance rows, opening and closing observations (F06 step 4) | Closed 2026-11-22; the statement-row sub-rule is missing | P3-05 |
| `G03` Investment events | Broker CSV, holdings screenshot (X45), F12 position parsing | **Open** | P3-03 |
| `G07` Local capture engines | PDF text, OCR, QR and barcode decode | Closed for voice 2026-11-22; no engine record for PDF/OCR/QR | P3-04 |
| `G08` Provider capture | Share intake, no mail connector (X82 has no route) | Closed 2026-11-22; the intake bound (bytes, types) is missing | P3-02 |
| `G15` Import template and mapping | CSV mapping (X67), Teach once (X66), saved layouts (X63) | **New, open** | P3-01 |
| `G16` Import staging and withdrawal | Preview to Inbox, "Undo this import", batch scope | **New, open** | P3-06 |

`G02`, `G05`, `G06` and `G12` stay closed and are used here as written. `G09`,
`G10`, `G11` stay with Phases 4 and v1.1.

## Planning gaps recorded in DECISIONS

These are decisions the sources do not settle. They go to
`docs/DECISIONS.md` "Open questions" with the preferred option when their task
starts:

- `P3-EXCEL-ENGINE` — SPEC 8.6 names XLS and XLSX. No package is in
  `pubspec.yaml`. A pure-Dart reader or a bundled engine needs the AGENTS 6.8
  check (licence, release date, no network).
- `P3-ANDROID-OCR` — `CLOSED-G07-LOCAL-ENGINES` excludes ML Kit. Android needs
  an audited bundled OCR engine or the receipt-photo path is absent on Android.
- `P3-PDF-TEXT` — no PDF text-extraction engine is selected. The choice decides
  the `ParserTemplate` fingerprint input.
- `P3-MERCHANT-SIMILARITY` — SPEC 8.9 gives "merchant similarity ≥ 0.8" with no
  algorithm. A token or edit-distance rule must be named and tested.
- `P3-CAMT-VARIANTS` — CAMT.053 and MT940 have bank and country variants. The
  supported subset must be named, and an unsupported file must reach X88.
- `P3-QR-PAYLOAD` — X27 says "Scan a QR receipt" without a payload contract.
  Options: a receipt URL that never resolves, structured fields, or both.
- `P3-POSITION-CONFIRM` — SYSTEM_DESIGN 10 sends holdings observations to a
  direct confirmation, while F06 sends statements to the Inbox. X45 must state
  one path and its written records.
- `P3-SHARE-BOUNDS` — SPEC 8.8 says "bounded local bytes" with no bound. The
  native intake needs a byte and type limit, and an over-limit path.
- `P3-INBOX-PRODUCER` — Phase 2 shipped the Inbox with a synthetic producer.
  The import path closes this gap; P3-29 owns the closure.

## Contract every task and pull request must name

Shape from docs/flow.md and USAGE_FLOWS "A task must name its contract":

```
Flow and steps · Screens and templates · References (SPEC / DESIGN / gate)
Inputs · User actions · Read model · Commit boundary · Written records
Success · Failures · Cancellation · Checks
```

## Task order

Documents first: P3-01 to P3-06. Then domain: P3-07 to P3-15. Then data:
P3-16 to P3-20. Then platform: P3-21 to P3-24. Then screens: P3-25 to P3-31.
Acceptance: P3-32.

| Wave | Tasks | Notes |
|---|---|---|
| 0 Documents | P3-01 to P3-06 | One gate per pull request. No feature code. |
| 1 Domain | P3-07 to P3-15 | Pure Dart, tests first. Each parser needs four fixtures (AGENTS 6.6). |
| 2 Data | P3-16 to P3-20 | Needs the domain files it reads. One schema pull request in flight. |
| 3 Platform | P3-21 to P3-24 | Native intake and engines behind ports. One platform per pull request. |
| 4 Screens | P3-25 to P3-31 | Each screen needs its data task, its components and its gate. |

Screens can run beside domain and data only when their read model exists.
Platform tasks run beside data after their gate closes.

## Shared-file ownership (one current owner)

- `pubspec.yaml`, `analysis_options.yaml`: a dependency needs its own pull
  request with licence, release date and network statement (AGENTS 6.8),
  recorded in `docs/DECISIONS.md`. P3-EXCEL-ENGINE, P3-PDF-TEXT and
  P3-ANDROID-OCR each need one.
- `lib/design/tokens/tokens.json`: design-system builder only. A new token is a
  separate design pull request.
- `lib/app/router.dart`: each screen task adds only its own `AppRoute` entry and
  child route.
- `lib/data/db/schema/*` and migrations: data builder only. Only one schema pull
  request in flight; the migration takes the next free `kCurrentSchemaVersion`
  at merge time.
- `test/fixtures/imports/`: P3-07 owns the fixture set. Other tasks read it.
- `lib/l10n/app_en.arb`: each task adds only its own strings. No hard-coded
  user text.
- `docs/DECISIONS.md`: append-only entries, written by the task that makes the
  decision.

---

### P3-01 — Import template and mapping definitions (G15)

- Objective: settle the saved-layout contract: template identity and
  fingerprint, mapping fields per format, when a layout may be saved, its
  version and its migration, and the "Saved layouts" read model on X63.
  Refs: SPEC 8.6; flows F06 steps 3–4; SCREENS X63, X65, X66, X67;
  SYSTEM_DESIGN 10 (`import_parse_configs`); DATABASE_DESIGN 5.
- Depends on: none. Blocks P3-08, P3-17, P3-27, P3-28.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md`
  (8.6), `docs/spec/spec-data-model.md` (cross-reference only),
  `docs/screens/SCREENS.md` (X63, X65, X66, X67 only),
  `docs/flows/USAGE_FLOWS_REFERENCE.md` (F06 only), `docs/DECISIONS.md` only.
- Acceptance: one normative paragraph names the fingerprint input per format
  (header signature for CSV/Excel, table geometry and word anchors for PDF), the
  mapping fields (date, details, amount, sign, balance column, decimal mark,
  date order), the save-only-after-usable-preview rule, template versioning and
  the unsupported-template state after a parser change. No new financial rule.
- Evidence: diff plus the gate entry closed. Reviewer: product and finance +
  privacy and security.
- Status: planned.

### P3-02 — Share intake contract (G08 extension)

- Objective: settle the share and file intake: accepted types, byte and count
  bound, file-protection window, staging object rules, the no-database-key rule,
  rejection paths and the retry path for unavailable content. Refs: SPEC 8.8,
  10.5; flows F06 step 1, F19 steps 3–4; SYSTEM_DESIGN 10;
  EXECUTION_SAFETY 2.
- Depends on: none. Blocks P3-21, P3-22.
- Owner: Planner with native builder review. Files allowed: `SPEC.md`,
  `docs/spec/SPEC_REFERENCE.md` (8.8), `docs/flows/USAGE_FLOWS_REFERENCE.md`
  (F06 step 1 only), `docs/approved-architecture/execution-safety.md`
  (cross-reference only), `docs/DECISIONS.md` only.
- Acceptance: the text gives one byte bound and one type list for iOS and
  Android, the protection class, the staging key lifetime, the over-limit
  message, and a statement that no URL is resolved and no cloud download starts.
  F06 checks A and D map to sentences.
- Evidence: diff plus the gate entry closed. Reviewer: privacy and security.
- Status: planned.

### P3-03 — Investment import decisions (G03)

- Objective: settle the subset of G03 that broker CSV and holdings
  observations need: what a parsed trade draft may contain, how a position
  observation stays separate from trade history, and which cash-basis rules
  apply. Refs: flows F12, F06 step 3; SPEC 8.6–8.7; USAGE_FLOWS G03;
  SYSTEM_DESIGN 12.2.
- Depends on: none. Blocks P3-31 and the broker CSV path.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md`
  (8.6, 8.7), `docs/spec/spec-calculation.md` (cross-reference only),
  `docs/flows/USAGE_FLOWS_REFERENCE.md` (F12 only), `docs/DECISIONS.md` only.
- Acceptance: the text states that a position observation never creates a trade,
  names the broker CSV fields and their mapping to the draft, and gives the
  confirm path for X45. It names the acceptance cases F12-D and F12-E. It does
  not define returns or tax.
- Evidence: diff plus the gate entry closed. Reviewer: product and finance.
- Status: planned.

### P3-04 — Import engine records (G07 extension)

- Objective: extend `CLOSED-G07-LOCAL-ENGINES` to PDF text extraction, OCR and
  QR decode: named engines per platform, availability checks, the unavailable
  path, and the evidence required for each engine. Refs: SPEC 8.6–8.8, 8.19,
  10.5; flows F06, F19; SYSTEM_DESIGN 10.
- Depends on: none. Blocks P3-23, P3-24, P3-30.
- Owner: Planner with native builder review. Files allowed: `SPEC.md`,
  `docs/spec/SPEC_REFERENCE.md` (8.6–8.8, 8.19), `docs/flows/USAGE_FLOWS_REFERENCE.md`
  (F06, F12, F19 entries only), `docs/DECISIONS.md` only.
- Acceptance: each engine has a name, version, availability check, traffic
  statement and a fallback. Android has a decision or an explicit "absent"
  state (P3-ANDROID-OCR). No engine with a network path is listed.
- Evidence: diff plus the gate entry closed. Reviewer: privacy and security.
- Status: planned.

### P3-05 — Statement rows and balance observations (G01 sub-rule)

- Objective: state how a statement's opening and closing balance rows become
  anchor observations, how they stay apart from transaction rows, and the
  re-import rule once an anchor covers the period. Refs: flows F06 step 4;
  SPEC 8.6, 4.3; DECISIONS `CLOSED-G01-ACCOUNT-PREREQUISITES`.
- Depends on: none. Blocks P3-18.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md`
  (8.6), `docs/spec/spec-data-model.md` (cross-reference only),
  `docs/flows/USAGE_FLOWS_REFERENCE.md` (F06 step 4 only),
  `docs/DECISIONS.md` only.
- Acceptance: one paragraph names the row kinds, the inclusive date rule, the
  correction path with `supersedes_anchor_id`, and the "already covered" case.
  It repeats that a missing balance is Missing, never zero.
- Evidence: diff plus the sub-rule closed in DECISIONS. Reviewer: product and
  finance.
- Status: planned.

### P3-06 — Import withdrawal and batch scope (G16)

- Objective: settle "Undo this import": what it removes, its boundary at
  confirmation, its relation to SPEC 8.18 Undo, and the states of X68 and the
  history rows. Refs: SCREENS X63, X68; flows F06 steps 5–6, F07 step 5;
  SPEC 8.18; SYSTEM_DESIGN 10; EXECUTION_SAFETY 2.
- Depends on: none. Blocks P3-19, P3-29.
- Owner: Planner. Files allowed: `SPEC.md`, `docs/spec/SPEC_REFERENCE.md`
  (8.6, 8.18), `docs/screens/SCREENS.md` (X63, X68 only),
  `docs/flows/USAGE_FLOWS_REFERENCE.md` (F06 only), `docs/DECISIONS.md` only.
- Acceptance: the text gives the withdrawal scope (staged items only), the
  refusal after one item is confirmed, the change to counts and revisions, and
  the difference from a confirmed-batch Undo. It names F06-C and F07-D.
- Evidence: diff plus the gate entry closed. Reviewer: product and finance +
  privacy and security.
- Status: planned.

### P3-07 — Tabular reader and locale detection

- Objective: `lib/domain/importers/tabular/`: read CSV and Excel into cells;
  detect delimiter, encoding (UTF-8, UTF-16, Windows-1252), header row, date
  format and decimal mark. Refs: SPEC 8.6.
- Depends on: P3-01 for the mapping shape. Blocks P3-08, P3-27.
- Owner: Domain builder. Files allowed: `lib/domain/importers/tabular/*`,
  `test/domain/importers/tabular/*`, `test/fixtures/imports/*` (owner).
- Contract: bytes in, cells, header row and detected locale out; no write.
- Acceptance: the four AGENTS 6.6 fixtures exist per format (normal, second
  import, broken, other locale). A Windows-1252 file with comma decimals and a
  day-first date parses to the same values as its UTF-8 twin. A broken file
  returns a typed error and no rows. No `double` for a money value; no
  `DateTime.now()`; no network; no file write.
- Evidence: failing-then-passing test log, coverage, format log. Reviewer:
  product and finance.
- Status: planned.

### P3-08 — Header signature and column mapping

- Objective: build the stable header signature and the mapping application:
  chosen date, details, amount, sign and balance columns, date order and decimal
  mark, plus the unmapped-column report. Refs: SPEC 8.6; P3-01.
- Depends on: P3-01, P3-07. Blocks P3-17, P3-27.
- Owner: Domain builder. Files allowed: `lib/domain/importers/tabular/mapping.dart`,
  `test/domain/importers/tabular/mapping_test.dart`.
- Contract: header cells in, signature and mapping out; no write.
- Acceptance: the same headers in another order give one signature; a renamed
  column gives another; a mapping with no amount column is invalid; every
  mapped row keeps its source column for X67 display. Tests first.
- Evidence: test log, coverage. Reviewer: product and finance.
- Status: planned.

### P3-09 — OFX and QFX parser

- Objective: `lib/domain/importers/ofx.dart`: statement and transaction rows,
  currency, account identifier, balance rows. Refs: SPEC 8.6.
- Depends on: P3-07 (shared draft type). Blocks P3-16.
- Owner: Domain builder. Files allowed: `lib/domain/importers/ofx.dart`,
  `test/domain/importers/ofx_test.dart`, fixtures.
- Contract: bytes in, draft rows and confidence out; no write.
- Acceptance: the four fixtures pass; a second parse of the same file gives the
  same source identities; a truncated file returns a typed error and no rows; a
  balance row is marked as a balance, not a payment. Tests first.
- Evidence: test log with per-fixture rows, coverage. Reviewer: product and
  finance.
- Status: planned.

### P3-10 — QIF parser

- Objective: `lib/domain/importers/qif.dart`: QIF records, split lines,
  category and memo fields, sign rules. Refs: SPEC 8.6.
- Depends on: P3-07. Blocks P3-16.
- Owner: Domain builder. Files allowed: `lib/domain/importers/qif.dart`,
  `test/domain/importers/qif_test.dart`, fixtures.
- Contract: text in, draft rows out; no write.
- Acceptance: the four fixtures pass; a split record returns its parts and
  their sum equals the parent; an unknown record type is reported, not dropped
  silently. Tests first.
- Evidence: test log, coverage. Reviewer: product and finance.
- Status: planned.

### P3-11 — CAMT.053 parser

- Objective: `lib/domain/importers/camt053.dart`: XML statement entries,
  amounts with currency, booking and value dates, balance elements. Refs:
  SPEC 8.6; P3-CAMT-VARIANTS.
- Depends on: P3-07. Blocks P3-16.
- Owner: Domain builder. Files allowed: `lib/domain/importers/camt053.dart`,
  `test/domain/importers/camt053_test.dart`, fixtures.
- Contract: XML bytes in, draft rows out; no write.
- Acceptance: the supported subset is named in the doc comment; the four
  fixtures pass; a variant outside the subset returns `unsupportedParser` and
  no rows; the parser never fetches a schema or DTD. Tests first.
- Evidence: test log, coverage. Reviewer: product and finance + privacy and
  security.
- Status: planned.

### P3-12 — MT940 parser

- Objective: `lib/domain/importers/mt940.dart`: statement lines, amount and
  currency, value date, description continuation, opening and closing balance
  tags. Refs: SPEC 8.6.
- Depends on: P3-07. Blocks P3-16.
- Owner: Domain builder. Files allowed: `lib/domain/importers/mt940.dart`,
  `test/domain/importers/mt940_test.dart`, fixtures.
- Contract: text in, draft rows out; no write.
- Acceptance: the four fixtures pass; multi-line `:86:` descriptions join
  correctly; the 60F/62F balance tags become balance rows, not payments; a
  malformed line returns a typed error. Tests first.
- Evidence: test log, coverage. Reviewer: product and finance.
- Status: planned.

### P3-13 — Dedupe and merchant normalisation

- Objective: `lib/domain/importers/dedupe.dart`: the SPEC 8.9 hash, the near
  duplicate rule, merchant normalisation and the clean-name output. Refs:
  SPEC 8.9; flows F06 step 6, F07 step 2.
- Depends on: none. Blocks P3-16, P3-29.
- Owner: Domain builder. Files allowed: `lib/domain/importers/dedupe.dart`,
  `test/domain/importers/dedupe_test.dart`.
- Contract: candidate rows in, identity, duplicate class and merchant name out;
  no write.
- Acceptance: the hash is SHA-256 over the five named fields in a fixed order
  and case; equal content alone is a candidate, never a duplicate; the 0.8
  similarity rule is implemented by the named algorithm (P3-MERCHANT-
  SIMILARITY) and tested at the boundary; "WHOLEFDS MKT 10231" normalises to a
  clean name; the same input gives the same identity after a restart. Tests
  first; 100% line coverage.
- Evidence: test log, coverage. Reviewer: product and finance.
- Status: planned.

### P3-14 — PDF table template engine

- Objective: `lib/domain/importers/pdf_templates.dart`: match a table layout by
  fingerprint, apply a saved template to rows, and build a template from one
  taught row (date, details, amount, sign words). Refs: SPEC 8.6; P3-01.
- Depends on: P3-01. Blocks P3-17, P3-28.
- Owner: Domain builder. Files allowed: `lib/domain/importers/pdf_templates.dart`,
  `test/domain/importers/pdf_templates_test.dart`, fixtures.
- Contract: text cells and a template in, draft rows or a match result out; no
  write; no file read.
- Acceptance: the next month of the same layout imports with no questions (the
  SPEC 17 accept item); a different layout does not match; a taught template
  previews before it is saved; an ambiguous cell returns low confidence, not a
  guess. Tests first.
- Evidence: test log with the two-month fixture pair, coverage. Reviewer:
  product and finance.
- Status: planned.

### P3-15 — Statement sign, amount and date words

- Objective: `lib/domain/importers/statement_values.dart`: parse amounts with
  thousands separators and sign words ("DR", "CR", parentheses, trailing
  minus), dates in the named orders, and the row kind. Refs: SPEC 8.6, 4.3.
- Depends on: none. Blocks P3-07, P3-14.
- Owner: Domain builder. Files allowed:
  `lib/domain/importers/statement_values.dart`,
  `test/domain/importers/statement_values_test.dart`.
- Contract: text in, money, date and kind out; no write.
- Acceptance: each supported form has a case; an unknown sign word returns
  Missing confidence and no value; an ambiguous date (01/02/2026) follows the
  detected order and reports the choice; money uses `Money` and `Decimal` only.
  Tests first; 100% line coverage.
- Evidence: test log, coverage. Reviewer: product and finance.
- Status: planned.

### P3-16 — Import batch staging repository

- Objective: typed Drift classes and a repository over `import_sources`,
  `import_parse_configs`, `import_batches`, `staged_rows`, `source_identities`
  and `source_claims`: create a batch, prepare rows in bounded pages, publish
  the Inbox marker and count atomically, and resume by digest. Refs:
  DATABASE_DESIGN 5, 9; SYSTEM_DESIGN 10; EXECUTION_SAFETY 2; query contract
  Q13 (extended in P17).
- Depends on: P3-01, P3-06, P3-09, P3-10, P3-11, P3-12, P3-13. Blocks P3-25,
  P3-26, P3-29.
- Owner: Data builder. Files allowed: `lib/data/db/schema/*`,
  `lib/data/db/migrations/*`, `lib/data/repositories/imports.dart`,
  `test/data/migration_009_test.dart`, `test/data/import_repository_test.dart`.
- Contract: commit boundary `StageImport`; written records source identity,
  batch, parse config, staged rows, publication marker, ChangeLog where
  authored.
- Acceptance: a fresh create and an upgrade from version 8 match; a repeated
  run creates one staged row per source identity; an interrupted publish leaves
  the marker at zero and no visible Inbox row; a resumed batch with a different
  digest is a new import; a row over the 256 KiB payload bound is rejected;
  staging changes no payment and no total (F06-B). Tests with frozen fixtures.
- Evidence: migration and repository logs, `flutter analyze`. Reviewer: privacy
  and security + product and finance.
- Status: planned.

### P3-17 — Saved layout repository

- Objective: store and read templates: create, version, list for X63, pick the
  best match, and retire a template. Refs: P3-01; SYSTEM_DESIGN 10
  (`import_parse_configs`); SPEC 10.5 (no export).
- Depends on: P3-01, P3-08, P3-14. Blocks P3-27, P3-28.
- Owner: Data builder. Files allowed: `lib/data/repositories/import_templates.dart`,
  `test/data/import_template_repository_test.dart`.
- Contract: commit boundary `SaveTemplate`; written records parse config,
  ChangeLog.
- Acceptance: a template saves only with a usable preview; a new parser version
  marks the template unsupported instead of applying it; the list returns name,
  format and use count for X63; no export or share path exists; the config stays
  inside the encrypted vault. Tests with two versions.
- Evidence: test log. Reviewer: privacy and security + product and finance.
- Status: planned.

### P3-18 — Statement balance observations

- Objective: write opening and closing balance rows as anchor observations
  through the P14 path; report the "already covered" case. Refs: P3-05;
  DECISIONS `CLOSED-G01-ACCOUNT-PREREQUISITES`.
- Depends on: P3-05, P3-16. Blocks P3-25.
- Owner: Data builder. Files allowed: `lib/data/repositories/import_balances.dart`,
  `test/data/import_balance_test.dart`.
- Contract: commit boundary `RecordStatementBalance`; written records anchor
  observation, selected pointer, ChangeLog.
- Acceptance: the balance row creates one anchor and no payment; a re-import
  over a covering anchor reports "already covered" and writes nothing; a
  correction supersedes; the inclusive date rule holds at the boundary. Tests
  on Appendix A accounts.
- Evidence: test log. Reviewer: product and finance.
- Status: planned.

### P3-19 — Import history and withdrawal

- Objective: the X63 history read model and "Undo this import": withdraw staged
  rows before any confirmation, and report the refusal after it. Refs: P3-06;
  SCREENS X63, X68.
- Depends on: P3-06, P3-16. Blocks P3-29.
- Owner: Data builder. Files allowed: `lib/data/repositories/import_history.dart`,
  `test/data/import_withdrawal_test.dart`.
- Contract: commit boundary `WithdrawImport`; written records batch state,
  claim state, counts, revisions, ChangeLog.
- Acceptance: withdrawal removes every staged row of the batch and changes no
  accepted payment; after one confirmed item the call returns the refusal and
  changes nothing; counts and cursor revisions move in one transaction; a
  repeated withdrawal is idempotent (F06-C).
- Evidence: test log including the refusal case. Reviewer: product and finance +
  privacy and security.
- Status: planned.

### P3-20 — PDF password and staging-key adapter

- Objective: store a PDF password in secure storage only, keyed by source
  digest; open a staging object by key; delete the temporary copy after parse.
  Refs: SPEC 8.6, 10.5; flows F06 step 2; SYSTEM_DESIGN 10.
- Depends on: P3-02. Blocks P3-26.
- Owner: Data builder with native builder review. Files allowed:
  `lib/data/repositories/import_secrets.dart`, `test/data/import_secrets_test.dart`.
- Contract: no financial write; secure-storage writes only.
- Acceptance: a wrong password keeps the retry state and writes no record; the
  password never appears in a log, error or crash field; the copy is deleted
  after parse; the key is not valid after an install epoch change. Tests with a
  fake store.
- Evidence: test log plus a privacy scan. Reviewer: privacy and security.
- Status: planned.

### P3-21 — iOS share extension

- Objective: accept a shared file into protected staging and hand it to the app
  after unlock, with no database or ledger key. Refs: SPEC 8.8; P3-02; F06
  step 1.
- Depends on: P3-02. Blocks P3-25.
- Owner: Native builder. Files allowed: `native/ios/*share*`, `ios/` share
  target files, `test/app/share_intake_test.dart`.
- Contract: file bytes in, staging key out; no financial write.
- Acceptance: the accepted types stage; an over-limit file shows the bound
  message and stages nothing; a remote URL is rejected with no fetch; the
  extension works while the app is locked and writes no ledger row (F19-D).
- Evidence: simulator log, the intake bound record. Reviewer: privacy and
  security.
- Status: planned.

### P3-22 — Android share intent

- Objective: accept `ACTION_SEND` and `ACTION_VIEW` file content into protected
  staging, with the same bounds as iOS. Refs: SPEC 8.8; P3-02.
- Depends on: P3-02. Blocks P3-25.
- Owner: Native builder. Files allowed: `native/android/*share*`, `android/`
  manifest and receiver files, `test/app/share_intake_test.dart`.
- Contract: file bytes in, staging key out; no financial write.
- Acceptance: the same cases as P3-21; no storage or SMS permission is
  requested; a content URI is read once and never re-fetched.
- Evidence: emulator log. Reviewer: privacy and security.
- Status: planned.

### P3-23 — PDF text and OCR engine

- Objective: extract text and table cells from a local PDF, and read a receipt
  photo, behind one port with one implementation per platform. Refs: P3-04;
  SPEC 8.6–8.7.
- Depends on: P3-04. Blocks P3-26, P3-30.
- Owner: Native builder. Files allowed: `lib/data/capture/pdf.dart`,
  `lib/data/capture/ocr.dart`, `native/*pdf*`, `native/*ocr*`,
  `test/app/pdf_port_test.dart`.
- Contract: local bytes or image in, text cells out; nothing leaves the device.
- Acceptance: the engine record exists with name, version, availability check
  and traffic statement; a device without the engine returns the unavailable
  path and no request; a scanned PDF returns low text confidence, not empty
  rows; the airplane-mode run passes the F06 fixtures.
- Evidence: airplane-mode log, engine record, dependency entry. Reviewer:
  privacy and security.
- Status: planned.

### P3-24 — QR decode

- Objective: decode a QR receipt locally and return its fields. Refs: SPEC 8.8;
  P3-QR-PAYLOAD; SCREENS X27.
- Depends on: P3-04. Blocks P3-30.
- Owner: Native builder. Files allowed: `lib/data/capture/qr.dart`,
  `native/*qr*`, `test/app/qr_port_test.dart`.
- Contract: camera frames in, payload fields out; no network; no image saved.
- Acceptance: a synthetic receipt QR fills amount, date and merchant; an
  unknown payload shows "Not a receipt code" and keeps the form; the camera
  permission explainer follows X87 order; no frame is stored.
- Evidence: simulator log and fixture payloads. Reviewer: privacy and security.
- Status: planned.

### P3-25 — Import hub, preview and error (X63, X65, X88)

- Objective: the import entry, source choice, preview with facts, Send to Inbox,
  history and error screens. Refs: SCREENS X63, X65, X88; flows F06 steps 1,
  3–6.
- Depends on: P3-16, P3-18, P3-21, P3-22, P3-27. Blocks P3-29.
- Owner: Feature builder. Files allowed: `lib/features/import/*` (hub,
  preview, error), `lib/l10n` additions, `test/golden/*`, route entries.
- Contract: flow F06; inputs a staged key, a parsed batch; actions choose
  source, Send to Inbox, open history, retry, choose another file; read model
  row counts and matches; commit boundary `StageImport` publication and
  `WithdrawImport`; success opens X68; failures keep the batch in review;
  cancellation writes nothing.
- Acceptance: the preview states Rows, Already in app and New and matches the
  batch exactly; Send publishes one marker and the Inbox count; X88 says
  "Nothing from this file was added" and that is true; no raw content appears
  in an error string; goldens dark/light at 1.0 and 2.0.
- Evidence: widget tests, goldens, l10n diff. Reviewer: product and finance +
  design and accessibility.
- Status: planned.

### P3-26 — PDF password and Teach once (X64, X66)

- Objective: the password dialog, the retry path, and the tap-to-teach editor
  that builds, previews and saves a template. Refs: SCREENS X64, X66; flows F06
  steps 2–3; P3-01.
- Depends on: P3-14, P3-17, P3-20, P3-23. Blocks P3-29.
- Owner: Feature builder. Files allowed: `lib/features/import/*` (password,
  teach), `lib/l10n` additions, `test/golden/*`, route entries.
- Contract: inputs a source digest and tap positions; actions unlock, tap
  fields, preview, save layout; read model template draft; commit boundary
  `SaveTemplate`; success returns to X65 with a match; cancellation writes
  nothing.
- Acceptance: a wrong password keeps retry and writes no record; a template
  saves only after a usable preview; the next month imports with no questions;
  the file name and layout name render exactly as X63/X64 samples show; goldens
  at 1.0 and 2.0.
- Evidence: widget tests, the two-month fixture pair, goldens. Reviewer: product
  and finance + design and accessibility.
- Status: planned.

### P3-27 — CSV mapping (X67)

- Objective: the mapping editor: detect the header, propose a mapping, let the
  user change date, details, amount, sign and balance columns, preview the
  result, and save the layout. Refs: SCREENS X67; flows F06 step 3; P3-08.
- Depends on: P3-08, P3-17, P3-25. Blocks P3-29.
- Owner: Feature builder. Files allowed: `lib/features/import/*` (csv mapping),
  `lib/l10n` additions, `test/golden/*`, one route.
- Contract: inputs header cells and sample rows; actions change a mapping,
  preview, save; read model proposed mapping and row preview; commit boundary
  `SaveTemplate`; failure keeps the mapping; cancellation writes nothing.
- Acceptance: an unmapped amount column blocks Preview with a reason; a changed
  mapping updates the preview only on Preview; the saved layout appears in X63;
  a decimal-comma file previews with the right values; goldens at 1.0 and 2.0.
- Evidence: widget tests, goldens. Reviewer: product and finance + design and
  accessibility.
- Status: planned.

### P3-28 — Import done and history undo (X68)

- Objective: the done screen with the count split, Open the Inbox, and "Undo
  this import" with its refusal state. Refs: SCREENS X68, X63 *History*; flows
  F06 steps 5–6; P3-19.
- Depends on: P3-19, P3-25. Blocks P3-29.
- Owner: Feature builder. Files allowed: `lib/features/import/*` (done),
  `lib/l10n` additions, `test/golden/*`, one route.
- Contract: inputs a batch; actions open Inbox, undo this import; read model
  ready / need a decision / no category counts and the undo state; commit
  boundary `WithdrawImport`; success refreshes X63 history; the refusal explains
  why and changes nothing.
- Acceptance: the three counts equal the Inbox rows exactly; undo removes every
  staged item of the batch once; after one confirmation the action is absent or
  refused with the reason; goldens at 1.0 and 2.0.
- Evidence: widget tests, goldens. Reviewer: product and finance + design and
  accessibility.
- Status: planned.

### P3-29 — Inbox producer handover

- Objective: replace the synthetic Phase 2 producer with the import path: a
  confirmed `StageImport` publication feeds X60 with source channel, category
  and account, and the debug producer leaves the release composition. Refs:
  `P2-INBOX-PRODUCER`; flows F07 steps 1–2; P3-16.
- Depends on: P3-16, P3-25, P3-26, P3-27, P3-28. Blocks P3-32.
- Owner: Feature builder with data builder review. Files allowed:
  `lib/features/inbox/*`, `lib/app/demo/*` (producer removal),
  `lib/data/repositories/inbox.dart` (read extension only),
  `test/features/inbox/*`, `test/app/demo_composition_test.dart`.
- Contract: read model only on the Inbox side; the write boundary stays
  `ConfirmInboxBatch`.
- Acceptance: an imported file appears in X60 with its source label and exact
  totals; closing `P2-INBOX-PRODUCER` is recorded in DECISIONS; the demo
  producer is absent from the release composition and the demo test still
  passes; a 20-item batch confirms in under 60 seconds with imported data.
- Evidence: widget test, timing log, DECISIONS entry. Reviewer: product and
  finance + privacy and security.
- Status: planned.

### P3-30 — QR and receipt capture (X27, X28)

- Objective: scan a QR receipt and check a receipt photo against parsed fields,
  then Save through the existing payment path. Refs: SCREENS X27, X28; SPEC
  8.6–8.8; flows F04 index; P3-23, P3-24.
- Depends on: P3-23, P3-24, P3-25. Blocks P3-32.
- Owner: Feature builder. Files allowed: `lib/features/add/*` (QR, receipt),
  `lib/l10n` additions, `test/golden/*`, route entries.
- Contract: inputs a payload or image; actions scan, take a photo, check fields,
  Save; read model draft with per-field confidence; commit boundary
  `SavePayment`; success per F03 with Undo; failure keeps the draft; nothing is
  written before Save (F04-C).
- Acceptance: a receipt photo fills amount, date and merchant with confidence
  marks; "No QR code? Take a photo" opens X28; an unreadable photo keeps typed
  entry; no image or frame is stored; goldens at 1.0 and 2.0.
- Evidence: widget tests, goldens, engine record from P3-23/P3-24. Reviewer:
  privacy and security + design and accessibility.
- Status: planned.

### P3-31 — Holdings screenshot (X45)

- Objective: read positions from a screenshot and show only the differences
  against the current holdings. Refs: SCREENS X45; SPEC 8.7; flows F12;
  P3-03; P3-POSITION-CONFIRM.
- Depends on: P3-03, P3-23. Blocks P3-32.
- Owner: Feature builder. Files allowed: `lib/features/spending/*` or
  `lib/features/investments/*` (X45), `lib/l10n` additions, `test/golden/*`,
  one route.
- Contract: inputs an image and the current positions; actions confirm a row,
  reject a row, Save; read model differences with source date; commit boundary
  per P3-03; failure keeps the observation; cancellation writes nothing.
- Acceptance: only differences are listed; a confirmed row creates an
  observation and no trade; a rejected row writes nothing; Matching an
  unavailable security stays with the Wealth model (Phase 4) and the screen
  states that; goldens at 1.0 and 2.0.
- Evidence: widget tests, goldens, F12-D/E. Reviewer: product and finance +
  design and accessibility.
- Status: planned.

### P3-32 — Phase 3 acceptance

- Objective: run the SPEC 17 Phase 3 acceptance and write the report. Refs:
  SPEC 17; AGENTS 7; `docs/PHASE2_ACCEPTANCE.md` as the shape.
- Depends on: P3-25 to P3-31. Blocks Phase 4 planning.
- Owner: Feature builder with all reviewers. Files allowed:
  `docs/PHASE3_ACCEPTANCE.md`, `integration_test/phase3_*.dart`,
  `docs/TASKS_PHASE3.md` (status only), `docs/DECISIONS.md` only.
- Acceptance: the three SPEC 17 accept items pass with evidence; F06-A to F06-D
  and F19-A to F19-F pass; the nine voice sentences stay out of scope; all
  AGENTS 4 commands pass; the airplane-mode import run passes; the input target
  is either measured on a device or stated as not met.
- Evidence: the report with command logs and the device or simulator note.
  Reviewer: product and finance + design and accessibility + privacy and
  security.
- Status: planned.

## Phase 3 exit criteria

- SPEC 17 Phase 3 "Accept when" items pass with evidence: fixture files import
  with the expected rows; a second import of the same file is detected; a taught
  PDF template imports the next month with no questions; no network call happens
  during an import.
- AGENTS 7 definition of done for every task, as in Phase 2.
- No gate in the table stays open for a shipped feature. G03 may stay open and
  then P3-31 does not ship.
- `P2-INBOX-PRODUCER` is closed by P3-29.
- Device gates keep their status and are not closed by this phase.

## Not in Phase 3

- Payslip, loan statement and policy imports (X69, X69b): v1.1.
- Local capture sources (X81): Android notifications, FinanceKit, app-owned
  staging folder, widgets, shortcuts: v1.1.
- Email or Gmail connector (X82): never.
- Search (X15), Home final (X10–X14), Wealth and account details (X40–X49):
  Phase 4. X45 ships here only for the position observation path.
- Calendar, cash flow, month close, recovery (X50–X51, X70–X71, X83): Phase 4.
- Cross-currency transfer (X26b), goals, protect, tax, tools: v1.1 and v1.2.
- Any new network path, export, sync, analytics or remote processing: out of
  scope for every phase.
