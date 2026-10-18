# Contour database design

Version 1.7 · 16 October 2026 · ARCH-FINAL-001 technical baseline.

Use one encrypted SQLite database on the phone: Drift for typed access and migrations, a verified SQLCipher native build, one database owner that serialises writes. Store accepted financial records once, keep immutable evidence, and build versioned read models for charts and totals.

Every screen reads a shared metric by its meaning, scope, currency and period. Ordinary edits commit source records and affected small totals together. SHARED_STATE defines the key, dependency graph, atomic publication, history retention and public logo cache contracts for implementation.

This implementation contract has an executable reference schema, not a production Drift migration. No phone performance, encryption or crash-recovery test has passed; see VALIDATION.

Read AGENTS, SPEC 9, SYSTEM_DESIGN and the usage flows. SPEC owns financial meaning; this file refines SYSTEM_DESIGN's physical storage contracts. SCHEMA.sql defines the foundation tables; QUERY_CONTRACTS defines query shapes and indexes. Wealthfolio is out of scope.

## 1 Selected design

| AREA | SELECTION | REASON |
|---|---|---|
| Database | One SQLCipher vault through Drift | Linked records need one atomic commit |
| Write ownership | One owner isolate, one writer connection | Save, Confirm, Undo and publication have one order |
| Source of truth | Current authored records, immutable observations, event groups, ChangeLog | No replay on read; corrections and Undo traceable |
| Primary keys | UUID v7 text for authored records; compact integer/composite keys for large technical tables | No UUID and audit row per public price sample |
| Money | Signed 64-bit integer minor units plus currency | Exact; overflow fails explicitly |
| Quantities and quotes | Canonical decimal text, parsed into Decimal | Prices can exceed cash minor-unit precision |
| Reads | Keyset pages and bounded projections | No full-history read or return calculation on the UI isolate |
| Shared metrics | One canonical key, one current scalar generation, one central subscription store | No separate net-worth calculation or value copy per screen |
| Publication | Source and small affected values in one ordinary-edit transaction; one read revision after commit | All running-app views receive one compatible state automatically |
| Retained history | Original facts and revisions; daily quote/detail pins independent of disposable results | Clearing chart caches cannot remove required historical evidence |
| Search | FTS5 inside the encrypted vault | Private, complete, rebuildable |
| Recovery | Private encrypted generations plus a separate protected device-control manifest | Restore cannot roll back the registry protecting other snapshots and keys |
| Network | None from repositories or the database | Only the market gateway gets a typed public request |

No second ledger, cloud database, sync queue, event-stream service or separate analytics engine. SQLite indexes and local projections come first; an engine change needs measured evidence and an architecture decision.

## 2 Physical layout and connection ownership

```text
Private application storage, with required backup/transfer controls (platform gate applies)
  control/                 encrypted control manifest and install journal
  generations/<opaque-id>/ encrypted database and encrypted recovery metadata
  attachments/<opaque-id>  immutable authenticated encrypted files
  staging/<opaque-id>/     encrypted import, migration and recovery work
Device key store           device-only wrapping keys; never exported
```

- Paths hold opaque IDs only: no account names, symbols, amounts, original filenames or user text. Each generation's encrypted manifest records its attachment closure.
- Open through one factory: key before schema access; verify `cipher_version` and an authenticated read; fail closed on absent cipher or wrong key.
- Every connection: verified `foreign_keys=ON`, `recursive_triggers=ON`, WAL, `synchronous=FULL`, `temp_store=MEMORY`, bounded busy timeout. The build inventory records pinned SQLite, SQLCipher, FTS5, JSON and binding versions. Verify settings on every open, not only schema creation.
- STRICT application tables. They still allow some lossless coercion, so validate source types before binding; SQL cannot repair a value a parser already rounded. `SQLite STRICT`
- The owner serves all reads and writes first. A read-only connection needs device evidence, explicit invalidations, short snapshots, generation/epoch checks and `query_only=ON`.
- Never expose handles or generic SQL to features, parsers or the market transport.
- Release builds disable SQL trace, parameter logging, cipher logs and value-level profiling. Diagnostics hold event names, counts and safe error codes.
- Passive idle checkpoints. If long readers block WAL reclamation, stop background ingestion and end/retry the reader. Never delete live WAL files. `SQLite WAL`

Gates.

- The native cipher build is a release gate. The reference DDL uses standard SQLite; passing it proves nothing about encrypted WAL, temporary storage, platform key protection or production FTS.
- PF-01 (SYSTEM_DESIGN 12.2) applies: no personal-data persistence and no iOS release-readiness claim until a supported compliant path exists or the user explicitly approves a different policy. Keep authoritative data out of purgeable caches/tmp.

## 3 Identity and exact value codecs

| VALUE | STORAGE AND VALIDATION |
|---|---|
| Authored ID | Lowercase canonical UUID v7 text; repository codec validates format/version. UUID order is not financial chronology. |
| Technical ID | Local integer or composite key; never a stable identity outside its database generation. |
| Money | INTEGER in signed 64-bit range with explicit currency. Check range before binding and after arithmetic. |
| Decimal | TEXT without exponent, leading plus, redundant leading zeros, trailing fractional zeros, negative zero or embedded NUL. Max 76 stored digits and 38 fractional digits. Domain validation enforces per-field sign/range. |
| Currency | Validated code and pinned currency metadata; no inference from locale or symbol. |
| Calendar date | Valid YYYY-MM-DD text in the relevant account/product calendar, with actual month and leap-day rules. |
| Event time | INTEGER UTC milliseconds. Inject the clock; timestamps never resolve concurrent edits. |
| Revision | Positive monotonic integer per authored entity; expected revision checked on edit. |
| State | Explicit value/coverage state. Missing evidence is not zero or an empty observed position. |
| Payload | Versioned canonical JSON codec. Money minor units and decimals are strings with explicit currency/type metadata; IDs and dates are typed fields. |

- The Decimal bound is admission policy, not rounding. Reject excess precision; never round an imported price to cents to fit. Solver precision and guard digits follow SYSTEM_DESIGN 7.
- Never use SQL REAL, `total()`, floating AVG or decimal-text casts for financial arithmetic. Bounded integer SUM needs an explicit overflow path. For arbitrary sizes, page into checked integer/BigInt arithmetic per currency. Convert currency only under the applicable dated FX rule. `SQLite aggregates`
- Canonical command encoding has fixed field order and normalisation; hash those bytes for the payload digest. JSON validity does not validate money, dates or command types. Never pass a financial payload through a consumer that turns numeric strings into binary floats.
- EXECUTION_SAFETY 6 defines primary/unique-key conflict guards, explicit positive technical-ID allocation and the writer-wide ban on replacement. Protected rows use lookup then explicit INSERT/UPDATE, including deduplication. `db_state` survives for the vault lifetime.

## 4 Main relationships

Use the single complete database UML, generated from SCHEMA.sql. It contains each application table, its fields and foreign-key relationships. Account, holding, event and quote identities differ. A symbol alone is not an instrument identity: exchange, listing/currency, provider mapping and instrument type are part of resolution.

### 4.1 Authored records and immutable evidence

- Authored records have UUID v7, `created_at`, `updated_at`, `deleted_at` and `revision`. Confirmed mutations write ChangeLog. Soft-deleted rows keep identity and history. Unique source keys stay reserved after Undo or deletion.
- Immutable observations keep original value, effective date, source identity and evidence. A correction adds an observation and moves the selected pointer through a command; it never rewrites the original. This applies to balance anchors, position observations, manual quote/FX evidence and saved close inputs.
- An explicit anchor selection is authoritative. Its receipt/history keeps the selected IDs and account revision, so a rebuilt technical pointer restores that choice, never the latest observation by date.
- Insert triggers register authored rows and retained occurrence proposal identities in the entity registry for typed history and draft references; never use loose `entity_type + id` strings instead. A registry FK proves existence only; the command validator checks liveness, subtype and event/account.
- Settlement, transfer, lot, attachment and evidence links use typed FKs/bridge tables, never JSON alone. JSON holds versioned options, parser mappings, drafts and bounded results.

### 4.2 One canonical cash ledger

`Transaction` is the accepted account posting. `FinancialEvent` groups all effects of one economic event; it is never an extra amount in totals.

- A transfer groups its two principal postings and any actual fee posting through typed links; a loose matching hash is not enough.
- An investment event links cash, security movement, lot allocations and tax/fee evidence. Never add both the investment cash amount and its linked Transaction to account cash.
- A position observation records what was seen on a date. It creates no purchase, cost basis, external flow or realised gain.
- A payslip can reuse a matched salary posting; a vest can reuse a matched cash/tax effect. Typed links prevent a second accepted posting.
- A debt is an account with debt metadata. Debt payments reference canonical Transactions; metadata holds no second balance.

Lots.

- Acquisition lots and accepted disposals are authored. FIFO/average allocations, realised gains and position checkpoints are derived outputs of one calculation generation.
- A backdated trade commits facts/history/dirty state. The worker stages and publishes the affected allocation/gain/checkpoint set together. It never edits authored lots or writes user ChangeLog.
- During rebuild, prior complete results are Updating; absent results are Missing.
- Cost method is an authored setting. A specific-lot election needs its own authored choice contract before it ships.
- Saved closes copy the consumed automatic allocations into immutable `close_lot_allocations`, with results and source revision pins. Deleting a disposable generation leaves these, and authored events/lots, intact. EXECUTION_SAFETY 7 requires paged private preparation and an admitted all-or-none close command; never copy an unbounded evidence query inside the sole writer.
- Undo checks authoritative later disposal/event facts or a verified current derived result. An absent or stale allocation cache never proves that no dependent sale exists.

Order. `InvestmentTransaction` keeps optional `effective_at`, `order_sequence`, `order_scope` and `order_source`.

- Sequences compare only within their declared scope. Statement order, UUID, import row order and creation/fetch time do not establish economic order.
- Order-sensitive same-day calculations need complete comparable evidence, else an unavailable state under G03 / G04.
- Explicit order corrections are authored revisions and become pinned calculation inputs. Storage invents no flow-timing/FIFO rule.

Gates G01, G03, G13 and G14 still govern accounting definitions; tables do not settle missing finance rules.

### 4.3 Obligations, schedules and partial settlement

Identity.

- One canonical obligation is an amount expected on a date; statements, recurring occurrences and one-off inputs can alias it. Forecasts read it once. Generating an occurrence never creates an accepted payment.
- Occurrence identity is `(schedule_id, occurrence_key)`; the key names the nominal occurrence independent of rule edits. `schedule_revision` records the rule version of the current proposal. One-off obligations have their own stable identity.
- After allocation, key and schedule ID never change. Append-only `occurrence_locators` map (schedule, rule revision, generator version, nominal slot) to the stable occurrence. A slot holds the calendar/date/time/fold/ordinal fields its schedule needs; the generator codec is versioned. Re-generation reuses the mapping.

Rule edits.

- The command freezes an explicit reconciliation plan: each proposed slot maps to one existing occurrence or a new identity; each affected open occurrence is preserved, changed or cancelled with its obligation.
- Only unambiguous unchanged slots map automatically; amount/date similarity is never proof. Ambiguous changes stay in review before submission.
- Matched, confirmed or partially settled occurrences keep identity and allocations; no accepted occurrence or obligation is duplicated.
- Rule revision, locator map, occurrences, obligations and dirty state change atomically.
- Tests: month-end date changes, monthly-to-weekly, paid-date moves, retries, interrupted preparation.

Generation.

- `scheduled_occurrences` and `occurrence_locators` are retained operational Expected proposals with stable UUID/registry metadata. Automatic generation writes no ChangeLog or confirmation receipt.
- Generate only the requested finite forecast window, in pages of max 500 rows or 1 MiB per write. Captured schedule revisions must match at commit.
- The generator inserts or updates only undecided Expected proposals. It never creates obligations, settlements or postings, or touches a decided/matched/settled occurrence.

Decisions.

- Accept, edit, skip, match, cancel and reconciliation append immutable authored `occurrence_decisions` and select `current_occurrence_decisions`.
- A decision has typed occurrence, obligation and settlement references and exact amount/currency, date and account overrides. A replacement points to the prior decision; the repository checks currency, settlement ownership and the allowed transition.
- Decision, selected pointer, obligation/settlement graph, ChangeLog and dirty state commit together; receipt/history keeps the selection for pointer rebuild.
- Undo appends a compensating decision; it never deletes identity or reopens a suppressed proposal by dropping the pointer.

Retained projections.

- `projection_occurrence_inputs` freezes each consumed proposal's ID/revision, exact date/amount/currency/state, generator and snapshot-codec versions. It references the generation's pinned schedule after-image and, where selected, decision after-image.
- The writer verifies the pins belong to that occurrence, match the captured rule and selected pointer, and are complete. The schedule pin supplies account/category/rule metadata; the occurrence identity supplies schedule/key. A null decision pin means no selected decision at the captured revision.
- Snapshot undecided and decision-overlaid inputs; recheck dependencies at publication. Input rows seal with the generation and cascade only with whole-generation cleanup.
- Historical replay uses these frozen inputs and the original cutoff/time/method policy, never current proposals or pointers.

Forecast extraction merges unresolved Expected proposals with canonical obligations.

- Suppress by selected decision or typed obligation alias, never by amount/date similarity. Skipped/cancelled decisions stay suppressed without an obligation. Accepted/matched decisions use the obligation/settlement graph. An edited proposal uses its overlay exactly once.
- G02 owns financial recognition rules, not storage ownership.

Settlement.

- An accepted allocation references the obligation and actual Transaction, with exact positive minor units and currency.
- Unpaid = obligation − accepted allocations: 1,240 − 500 = 740. The statement alias adds no second 1,240.
- Reject an allocation beyond the remaining amount; a larger payment can keep an unallocated part. Never clamp the remainder to zero silently.
- Cross-currency settlement needs defined conversion evidence first.

## 5 Coverage of the product data model

The reference DDL sets shared persistence mechanisms and the main ledger/investment paths; it does not make every later table ready to ship. Add each later family in a small migration with the same identity, audit, codec and query contracts.

| SPEC FAMILY | PHYSICAL RULE AND OWNERSHIP |
|---|---|
| Settings and Person | Typed validated settings, versioned feature options, FK person links. Provider credentials and PDF passwords in secure storage. |
| Account, BalanceSnapshot, ValuationRule | Metadata; immutable balance observations and a selected anchor; versioned valuation parameters. No editable computed balance. |
| CardDetails, LoanDetails, CardStatement | One-to-one metadata on a canonical account; statements link to obligations/settlement; status derives from accepted allocations. |
| Transaction, Split, Line, TransferFx | Canonical postings; typed child rows; exact amounts. Transfer FX links actual sending/receiving postings and fee. |
| Category, CategoryRule, Tag, TransactionTag | FK-backed classification and priority rules. Rules propose; accepted changes write history. Reports count split contributions only. |
| RecurringRule, PriceChange, ExpectedIncome | Versioned rule, occurrence and obligation identity. Price changes keep observations. Expected income is not actual cash. |
| Budget, BudgetLimit, BudgetTemplate | Period/category identity with currency. Carry-forward is a versioned projection, not an editable balance. |
| Payslip | Normalised deductions/benefits; links to one event and the matched posting. No raw source text. |
| Security, FundHolding | Authored identity and overrides; compact public catalogue mapping. Dated constituents use exact weights and coverage. |
| Holding, Lot, InvestmentTransaction | Holding = account/security/method; quantity derives from movements/observations. Lots and allocations keep acquisition/disposal links. |
| RealisedGain | Versioned result per sale from typed lot allocations, not lotsUsed JSON. |
| PriceQuote and FxRate | Immutable precise observations; separate current selection. Quotes evictable only when unpinned. FX from manual/local input. |
| Benchmark, TargetMix | User selection and exact group targets. Benchmark history is public price data; comparisons are computed. |
| EquityGrant, VestSchedule, VestEvent | Grant and schedule authored; future vests Expected. Confirmation creates one linked investment event with typed effects. |
| InsurancePolicy, Claim | Metadata; covered/nominee bridges. Premiums link to obligations; payouts to actual postings. |
| Goal and GoalAllocation | Exact account allocation; active percentages sum under a transactional domain invariant. Goals create no assets. |
| TaxDate, TaxSavingLimit, ContributionLimit | Dated records, explicit currency/year, linked actual contributions. Future tax due is not a payment. |
| Debt and DebtPayment | Metadata over a canonical account, linked to canonical payments. No parallel debt ledger. |
| EmergencySheetEntry | Versioned local record with typed entity references. No secrets. |
| NetWorthSnapshot and MonthClose | Immutable numbered close revisions, exact results, coverage, pinned input/method versions. Corrections add a revision. |
| ImportBatch, MappingTemplate, ParserTemplate | Import progress, reusable mappings, versioned parser data. File hash aids identity; raw source removed after its lifecycle. |
| InboxItem and CaptureSource | Staged proposals, source identity, local adapter configuration. Only confirmation creates accepted records. |
| ChangeLog and CalculatorPreset | Immutable command-linked history; authored versioned tool inputs. Calculator outputs are derived. |
| LayoutSurface, LayoutSection, LayoutItem (WIDGETS-001, WIDGETS-007, HOME-QUICKLOOK) | A local display preference, not financial data: typed rows of keys, order and size, no JSON. Outside ChangeLog and dependency revisions; nothing is computed from it. Kept in recovery snapshots. See 5.1. |

### 5.1 Layout preferences (SPEC W7, W13; from Phase 1)

Three tables hold the person's saved layout: `layout_surfaces`, `layout_sections` and `layout_items`. They support SPEC W1–W13 from reference schema version 5. The first two-table form arrived in reference migration 002; `005_layout_sections.sql` adds sections, sizes and the base layout version. Production Drift translation/migrations remain required. Execute each migration in the framework's single transaction: translate the SQL body without nesting its reference BEGIN/COMMIT wrapper or using Python executescript. Native interruption/rollback tests remain DB-B. WIDGET_FRAMEWORK defines the registry, the bundled default layout file, the host and the module lifecycle.

| PERSISTED STATE | MEANING |
|---|---|
| No surface row | Inherit that surface's complete default layout (sections, items, sizes) from the default layout file of the installed release |
| Surface row, no item | Explicitly show no items; do not fall back to the default file. Zero sections, or sections with no items, both mean this. The writer and migration 005 write zero sections (DB4-4) |
| Surface row with sections and items | Custom layout; omitted keys are hidden. Do not append newly introduced default widgets or sections automatically |

| TABLE | COLUMNS AND KEYS |
|---|---|
| `layout_surfaces` | Surface key (primary key; the ten recognised keys), `catalogue_version`, `base_layout_version` INTEGER NOT NULL (≥ 1), update time |
| `layout_sections` | (`surface_key`, `position`) primary key; unique (`surface_key`, `section_key`); foreign key to the surface with cascade. `section_key` is 1–64 characters of A–Z a–z 0–9 . _ -, never a case variant of untitled: a default-file identifier, never user text or a title |
| `layout_items` | (`surface_key`, `section_key`, `position`) primary key; unique (`surface_key`, `item_key`); composite foreign key (`surface_key`, `section_key`) to `layout_sections` with cascade; size TEXT NOT NULL CHECK (size IN ('full','half')) |

- Section identity. Section keys come from the default layout file. `untitled` is a reserved key: valid on every surface, drawn with no title. Its case variants (Untitled, UNTITLED) are rejected by the table, the writer and the build check (DB4-7). A stored section that the installed file does not have is a retained section: it keeps its raw key, draws with no title, and its eligible children stay editable (SPEC W13). `tiles:quickLook` has only untitled and only full items (the tile host owns tile geometry); table checks enforce both. Titles are l10n strings looked up by key; rows never hold text.
- Item position scope: per section. Positions are consecutive from zero within each section. The writer writes them densely, and migration 005 renumbers legacy gaps in their old order (DB4-5). Readers sort by position and accept gaps from any other source. Reason: a section move rewrites only section rows; a widget move touches only its two sections; the dense-order rule stays local. A surface-wide position would renumber every item on each section move. A key still appears at most once per surface.
- Cross-surface safety. The composite foreign key includes `surface_key`, so an item cannot reference a section of another surface.
- Base layout version. The `layout_version` of the installed default file at the surface's last committed Done (last commit, not origin; DB4-8). The writer requires the installed version on every committed custom layout. Under the interim LAYOUT-UPGRADE rule it is also the "seen" mark for "New in this version" (WIDGET_FRAMEWORK 5). It is never compared for concurrency. Schema version, catalogue version, installed layout version and stored base version are four separate numbers.
- Sizes. A stored default placement takes its size from the default file; a new library or cross-surface addition takes the size from the file's add.widgets entry and its position from add.targets (WIDGET_FRAMEWORK 1). Descriptor size order has no meaning. In v1 an ordinary edit cannot change a size; a moved widget keeps its size. Only Default or a reviewed layout migration changes it. A stored size that the release no longer allows stays in the row and renders at the nearest allowed size (SY4-11).
- Limits per surface. At most 16 sections, 256 items and 64 KiB canonical descriptor bytes (sections, items, sizes and both versions). With identifier keys the count limits bound a descriptor to about 21 KB, so the byte limit never fails for keys the writer adds. It is still a live guard: retained keys from another version can hold any 64 Unicode characters and reach about 188 KB (DB4-6; test_byte_bound_and_exact_empty_preference_identity). Validate both independently. Tables do not enforce these counts, so an oversized preference from another version stays readable for detection and reset.

Do not duplicate widget definitions, names, titles, values, colours, periods or financial filters here. All nine screen surfaces plus `tiles:quickLook` exist as recognised keys. Home X03/X10/X11/X12 and Investments X43/X89 share their canonical surface keys (SCREEN-SET-001). Screen state is not persisted as a second layout.

Upgrade from version 4 and new releases

Migration 005 rebuilds only the preference tables in one transaction. Each existing surface row with items gets one untitled section at position 0, all its items in their old order (positions renumbered from zero) with size full, and `base_layout_version = 1`. An explicit empty surface keeps its row with no section: the one written form of explicit empty (DB4-4). Absent surfaces stay absent and so follow the installed file. Catalogue version, update time, `read_revision`, financial rows, receipts and audit do not change. The first shipped bundle is fixed at layout version 1. The flat/full conversion preserves the exact old custom order, including unknown keys; remapping each key to a new default section could reorder user choices. A full size that a widget does not allow renders at its nearest allowed size and keeps its row (SY4-11); the prototype's remapping is not a production migration contract. DECISIONS WIDGETS-007 records this choice (SY4-13). Production Drift runs the body of this script inside its own single migration transaction and must not nest the script's BEGIN IMMEDIATE; PRAGMA foreign_keys is set outside that transaction (DB4-10; test_migration_body_runs_in_one_caller_transaction_without_nested_begin). An error rolls back to version 4.

DECISION-PENDING: LAYOUT-UPGRADE. The following release rule and reference tests model SPEC W13's preferred option; they do not close the open product decision. Loading or rendering a new release changes no stored row. An untouched surface follows the new file at once. A customised surface keeps its sections, order and sizes. Add widget lists eligible bundled library entries whose introduced since version exceeds stored `base_layout_version` and which are not already stored on the surface, under "New in this version". This includes library-only and movable keys, after all release/feature/platform/financial gates. WIDGET_FRAMEWORK 5 defines "seen": Done stamps the installed version on every customised surface of the session, even if only the stamp changes; Cancel, rendering, opening Add widget and Undo do not. Thus the group clears after Done as W13 specifies, also after an unrelated reorder (recorded consequence; test_layout_upgrade_interim_rule_consequences). Inherited surfaces have no group. Removed item keys are skipped and retained. Retained sections keep their raw identity and draw eligible children with no title. Renamed keys use the file's rename list as a read-time alias (below). A stored `base_layout_version` greater than the installed file version is treated like a newer catalogue: render compatible keys; ordinary edits are read-only; Default stays available.

Read and preservation

Q18 returns the raw surface, including the absent/explicit-empty distinction, its sections, items and sizes, in one bounded snapshot. Read at most 17 sections and 257 items to detect an unsupported size. Limits: 16 sections, 256 stored keys and 64 KiB canonical bytes per surface, at most ten known surfaces, and 1 MiB per submitted command including baseline and candidate. Retain oversized content untouched and refuse an ordinary rewrite; never truncate it. Here readable means bounded header/unsupported-size detection for a read-only state and explicit reset, not rendering all rows or pretending the bounded prefix is a complete layout. The fixed hero and navigation remain available. Any future full oversized-layout viewer needs a separate paged contract; Q18 is not that viewer. Explicit Default/reset can remove the complete stored preference through its bounded reset path.

The raw list and the rendered list are different. Resolve against the registry only after the bounded read. A section with no shown item is not drawn. A retained section draws its eligible items with no title, at its stored position, using (surface_key, original section_key) as its identity; the title is a separate presentation lookup. Multiple retained sections never collapse to the reserved untitled key (test_probe_sy4_3_db4_3_unknown_sections_keep_raw_identity). Their known eligible children can move or hide. Skip unknown, unreleased, feature-disabled, wrong-kind or currently disallowed placement keys without deleting them. A known item with a stored size that the release no longer allows renders at the nearest allowed size; the row keeps its size and section, and an unrelated edit neither fails on it nor rewrites it. Known empty-state suppression also changes rendering only. A new request can add only a known eligible key with a valid movement policy; widget keys cannot enter the tile surface or vice versa. Existing opaque entries can pass through unchanged but cannot be forged as additions.

When editing an inherited surface, materialise its complete default layout (sections, items and sizes from the installed file) before eligibility filtering, so temporarily gated defaults remain represented. On a custom surface, ordinary edits keep opaque/dormant keys and their relative order. Traverse original slots: preserve each opaque slot, fill eligible slots sequentially from the edited eligible order, omit unused eligible slots, then append excess new eligible items. Example: stored [A,U1,B,U2,C], opaque U1,U2, edited visible [C,A] becomes [C,U1,A,U2]. Validate the parent before merging its items. Every section that contains a dormant item must remain in the candidate, even when its last visible item is hidden or moved. An omitted parent must not erase its opaque children. Retain unknown saved section identities, including empty ones; their title fallback does not freeze their known children. Section order can change as a whole. Within each retained section, known or unknown, apply the item-slot merge above. Dormant children retain their original section, size and relative order. An empty known section can be omitted only after all its eligible children are hidden/moved and no dormant child remains; there is no section-delete or rename control in v1. A widget moved between sections leaves its old section and fills or appends in its new one; it keeps its size. A new section must be a known file section or untitled. This rule operates on preference eligibility, not data-empty suppression: no-record widgets remain editable. The registry supplies eligible modules and l10n display names; the bundled file supplies library add sizes, introduction versions and insertion anchors. Rows contain none of those definitions.

Do not collapse a custom list into inheritance because it happens to equal today's defaults. Only explicit Default/reset chooses inheritance. Preference commands use validated explicit DELETE then INSERT, never INSERT OR REPLACE. A replacement of a section can cascade-delete its items even with valid FKs, so six `layout_*_no_replace` triggers abort any INSERT or UPDATE that would conflict with an existing layout row (DB4-10; test_probe_db4_10_replace_cannot_cascade_delete_items). For a newer unsupported catalogue version, render compatible known keys but keep normal edits read-only.

Catalogue renames (SY4-9). A rename is a read-time alias. The file retains cumulative flattened mappings from every supported historical key to its current key, including skipped-release and old-snapshot paths. A changed rename map requires an increased `catalogue_version`, independently of `layout_version`. Several historical aliases may share a target; the build checker does not reject that alone. The reader maps stored keys through the installed file's rename list when the stored `catalogue_version` is older; a release writes no row. The next Done of that surface writes the mapped keys and the installed catalogue version in the same atomic command, with the normal counters and read revision. Widget and tile keys use the same rule. A collision between two keys actually present on one saved surface keeps the raw rows, renders only compatible keys and makes ordinary edits read-only (renameCollision); Default stays available. An unknown codec is never decoded into a candidate (test_rename_is_read_time_alias_and_next_done_writes_it). Explicit reset can remove an unsupported preference. Layout catalogue migrations are separate from database schema migrations.

Editor and atomic commit

Cancel, Undo, drag, hide/add and nested tile edits operate only on a private candidate. No database write occurs until Done. Undo reverses one session action; Home Default is one action over `screen:home` plus `tiles:quickLook`. Home edit mode (entered from Home or Settings > Screens and widgets > Home) exposes the Tiles sheet. It edits the one global tile surface, so committed changes also reach moved Quick look copies. A Tiles entry on another host is not defined by SPEC W12 and is not added here. Cancelling the outer session discards its tile changes too. Default on another screen affects that screen only; Settings reset explicitly targets all ten surfaces.

A Done command carries an owner-issued session token, database epoch, catalogue/gate version, the installed bundle content digest and layout version, the original canonical descriptors, explicit defaultScopes and the complete final candidate patch for its touched surfaces. defaultScopes records which surfaces were reset in the retained editor history; it is part of the frozen payload and retry equality. Undo restores its prior set together with the candidate, including across repeated Default actions. Explicit empty has one written form: a surface row with no section (DB4-4). When a Done writes a surface whose sections hold no item and are all known, the writer stores zero sections; a retained empty section is kept. A raw unchanged Done is a no-op and does not rewrite an older stored form. After validation and normalisation, an output that already equals the current stored descriptor is also a no-op; repeated equivalent empty submissions cannot advance counters. Retries compare the same frozen candidate; read convergence accepts the candidate or its written form. A canonical descriptor includes absent/present mode, catalogue version, base layout version, and exact ordered sections and keys with sizes, including dormant entries; updated_at is excluded. The single writer validates every touched surface and movement/gate rule, reconstructs the prescribed opaque-preserving merge from the eligible edit order, and rejects a candidate that differs. For a surface in defaultScopes, use the complete compiled default list as the merge seed; otherwise use its original stored list or inherited default. Only the explicit reset intent permits discarding old opaque keys. It compares the frozen catalogue/gate version, installed layout version and bundle digest too. A changed bundle invalidates the editor even if a version number was reused. It rejects an edited stored size, an unknown new section, a duplicate section, a disallowed new size, an omitted parent with dormant children or more than 16 sections. A retained size that the release no longer allows passes unchanged and the widget stays editable. New additions must match the bundled add.widgets size and use an identifier key (DB4-7). No registry-order fallback is allowed. An ordinary request cannot omit or reorder dormant entries even if it bypasses the editor; only explicit Default/reset or a reviewed migration can discard them. It then replaces all touched rows in one transaction and advances `read_revision` once. A no-op changes neither rows nor read revision. A final inheritance target deletes its parent surface row; section and item rows cascade. A final custom target remains explicit, including when created by edits after Default. Success publishes only after commit. A fault on the second surface rolls back the first too.

This is a preference command, not the authored financial operation protocol in section 6. It writes no ChangeLog, operation intent/receipt, financial dependency revision, dirty range or authored commit sequence. The preference transaction does not create metric generations or recompute totals. After commit, newly active placements may request an uncached/stale shared metric through the normal coalesced read path; that is separate from the layout write and cannot invalidate unrelated values. All three layout tables are part of same-phone recovery snapshots; only committed preferences are restored. A snapshot from version 4 passes through migration 005 like any other version 4 database.

Concurrency and uncertain replies

Do not compare global `read_revision` or timestamps for edit conflicts: unrelated quote/financial publications are allowed during editing. At session open, the owner records canonical baseline descriptors and per-surface runtime edit counters under its fresh owner-instance identity. Every committed layout change/reset/migration advances affected counters, even if a reset removes the surface row. Validate these counters plus the baseline inside the serial writer admission before the transaction. A change A→B→A therefore still invalidates an older editor. Counters are bounded integers, never wrap and are not persisted financial history.

Only live owner-issued sessions can submit. The owner holds a bounded submitted/terminal result record until acknowledgment, rejecting duplicate submissions or returning their terminal result. Session state/counters update after SQL commit and before the next command is admitted. If the owner cannot establish that outcome, invalidate its sessions and reconcile committed preferences before further editing. A fresh owner instance, database replacement or process restart invalidates every old token; a durable replay queue is unnecessary for a preference.

A proven rollback keeps the private candidate for an explicit retry. On a lost response with unknown outcome, freeze the candidate and first resolve the live owner's result. If that result is lost, a read showing the complete candidate can establish convergence without writing. If current content differs, reload for review; **never automatically resubmit merely because the old baseline matches again.** That would overwrite a later reset after an A→B→A race. After process death, reload the committed layout and discard the old session; do not manufacture a new operation to replay it.

Use one active edit session in the initial app. Permit one submitted command at a time, with at most 1 MiB canonical input and a 1 MiB bounded inverse-operation Undo log. Do not retain full screen/result snapshots per edit. If further editing would exceed the bound, preserve the existing candidate/Undo log and keep Done/Cancel available; never evict earlier Undo actions silently. Lock/background disables input and transient work. The candidate can survive in memory behind unlock; no pending edit is added to a recovery snapshot.

The writer rejects a Home reset intent unless defaultScopes includes both `screen:home` and `tiles:quickLook`, with both final candidates, baselines and counters captured in the same session. Do not infer a Default action solely from a final inheritance target: Default → tile edit → Done can leave Home inherited and tiles custom; Default → Add can leave Home custom. Both are valid. Without reset intent, an inheritance target is valid only if the original baseline was already inherited. A tile-only edit while Home inherits needs no Home reset. This protects paired Default semantics without blocking later edits or requiring a persisted action log.

For oversized stored preferences, use a **reset-only owner-issued session**. Its fixed target set expands Home to include Quick look tiles. Capture the owner instance, database epoch, per-target runtime counters and bounded surface headers (presence, catalogue and base layout version); do not decode or hash all section and item rows. Under serial owner admission, validate this reset baseline and counters before deleting any target. Every layout mutation uses this owner, so counters detect changes to item rows even when headers stay the same. This is the explicit exception to an ordinary editor's complete canonical baseline. The frozen-submission, terminal-result and unknown-response rules above still apply. Without a retained terminal result, confirm convergence by reading absent target headers; otherwise reload for review without automatic replay.

Reset deletes only selected parent rows with indexed child lookup and a measured statement bound. Validate file space/native interruption before admission; all-surface reset remains one atomic command, not a partial reset presented as complete. Production tests must cover reset conflicts, Home/tile target expansion, lost replies, owner restart and replacement epoch, including an oversized preference. The reference helper tests only the admitted atomic mutation. There is no startup rewrite of every layout.

Scope limits of the reference schema.

- It does not mean all future tables or enum variants can ship now. Check the release phase and correction gate before a command. Never add a generic JSON entity table to avoid that work.
- Public quote tables store daily closes only. Spot/intraday needs a reviewed interval/observation-time migration and query contract. Never use `fetched_at` as market observation time or draw a daily-close series as intraday.
- A projection that consumes versioned public instrument details needs typed detail-input pins; quote-only pins keep no sector/classification evidence.
- The reference supplies `projection_detail_inputs`, `projection_entity_inputs`, exact series points, stable occurrence locators, active import input links and immutable close allocation copies. These are foundation mechanisms, not finished feature logic.

## 6 Atomic command protocol

An intent is a durable request. A receipt proves a committed result. Keep them separate.

1. Save the draft with its schema version. Before queueing, persist an operation ID and freeze the canonical payload, digest, payload version and expected entity revisions. Resolve the draft's operation through `operation_intents.draft_id`; one unresolved active intent per draft. Store immutable input in `operation_payloads` and ordered `operation_payload_chunks` (max 256 KiB each). Validate the full manifest/digest before submission. Persist the prepared plan in encrypted bounded staging, never only in memory.
2. The writer checks the receipt first. An identical retry returns the recorded result even if source revisions changed since. A reused ID with a different digest fails.
3. Prepare expensive validation outside the write transaction; record input dependency revisions. Large imports use a persisted prepared plan, not an in-memory array of ledger writes.
4. Start one write transaction. Recheck intent state, expected revisions, live references, source reservations and all cross-row invariants. Allocate the commit sequence.
5. Write every selected effect, source link, attachment reference, ChangeLog row, revision change, dirty interval and receipt. For an ordinary bounded edit, also publish the affected small metric set and its post-command input revisions in this transaction. Complete the draft/Inbox state and advance `read_revision` once. Large work uses the explicit updating path in SHARED_STATE 3.
6. Commit, then notify the central read store once. Publish a compatible immutable state map to all subscribers; no query or recalculation per widget. No UI success before commit. On a lost response, resolve the same operation ID through its receipt.
7. On failure, explicitly end or roll back the transaction before the writer returns to the queue. Inspect the receipt if the outcome is uncertain. Never catch a failed selected row and commit the earlier rows.

Constraint ABORT can stop a statement without rollback; a failed deferred-FK commit can leave a transaction open; FULL, IOERR, BUSY and INTERRUPT also need a resolved state. Use a tested transaction wrapper, not exception-type assumptions. `SQLite transactions, conflict handling`

Prepared command admission and cancellation

Execution rules: SYSTEM_DESIGN 6. Storage contract:

- General prepared-command bounds, checked before the writer: **100,000 logical row effects and 16 MiB encoded plan.** Batch confirmation also has a **5,000 selected source row** bound. Direct document review follows EXECUTION_SAFETY 2.1; saved close follows EXECUTION_SAFETY 7. Count registry, history, search-document and operational trigger effects; reserve index/FTS page and WAL growth separately. The 1-million-row parser bound is not a Confirm bound.
- Over limit: no accepted change, all drafts kept. Never split one confirmation into hidden partial commits.
- Deadline (initially 10 s), cancel, lock or background sets an operation-scoped native flag within 100 ms on the cooperative path. Check it at each bounded statement boundary and through the pinned binding's progress-handler/interrupt; never through the busy Dart mailbox.
- Drain statements and resolve rollback/receipt before releasing the token or admitting the next command; a late interrupt never cancels the next operation.
- Blocked OS I/O has no hard completion guarantee: mask immediately and stay closing/recovering until resolved. The deadline is a failure bound; P06's 2-second target still applies.
- Cancel and commit resolve through the same writer: proven rollback, or a committed receipt that offers Undo. A timeout is unknown until resolved. Editing a proven-uncommitted, stopped attempt allocates a new operation ID.

Database checks and command checks

| ENFORCED BY DATABASE CONSTRAINTS/TRIGGERS | ENFORCED BY DOMAIN VALIDATION INSIDE THE COMMAND BOUNDARY |
|---|---|
| Required columns, storage types, basic ranges, enum checks | Actual calendar validity, UUID version, full canonical financial payload codec |
| FK existence and unique source tuple | Referenced entity is live, correct subtype, same account/currency and permitted event role |
| Unique operation receipt and immutable submitted payload/history | Complete expected-revision set and receipt-first retry protocol |
| Row-local transfer and relationship restrictions | Principal/fee graph closure; split sums; no double counting of linked cash effects |
| Positive allocation and valid typed links | Allocation totals, remaining lot quantity/cost, goal percentage caps |
| Immutable observation rows and version identity | Which observation applies at the requested date under SPEC rules |
| Generation/input identity; current-pointer guards reject unpublished, stale captured inputs and wrong epoch | Complete dependency sets, correct small metric closure, interval coverage and atomic publication/read revision |

CHECK does not enforce cross-row sums and passes when its expression is NULL. Required values need NOT NULL; optional values need an explicit policy. A FK does not reject a soft-deleted target. Constraints are defence in depth, not the finance engine. `SQLite table constraints, foreign keys`

Source identity and Undo

- Uniqueness tuple: (namespace, account_scope, source_record_id), no NULL component. Sources without an account use an explicit namespace-local scope.
- Reserve identities during staging so overlapping imports cannot create two live proposals. File/row identity includes a stable identity-policy version; a parser upgrade maps existing identities instead of treating old rows as new.
- A content fingerprint is only a duplicate candidate; two real purchases can match on amount, date and merchant.
- A repeated known identity returns its staged, accepted or tombstoned result. Undo does not free it. Reaccepting an undone source needs an explicit new command linked to that identity.
- Undo is a compensating command for the whole event or selected batch. Validate current revisions and dependent allocations, settlements, closes and later edits. Never replay an old JSON row over a changed record. Keep source tombstones and receipt/history identity. G06 still requires the persistent history interface.
- Transfer event/principal/fee uniqueness applies to live links only; soft-deleted links stay as history, and a new match can reuse unlinked postings. The command enforces cross-role exclusivity: one posting cannot be another live transfer's fee or opposite principal.
- One-to-one child rows (`transfer_fx`, occurrence/card obligation aliases) follow their parent's stable identity and are revived/revised with it; a new parent gets a new child. Refund link pairs are revived/revised under their stable identity, never re-inserted. Source identities stay reserved throughout.

## 7 Queries and read models

QUERY_CONTRACTS holds the SQL, indexes and fallback paths. The query budget is part of the API contract, not a LIMIT on an unbounded scan.

- List cursors include scope/filter hash, ordering, last (date, id), relevant revision set and database epoch. Reject incompatible cursors. Max five 100-row pages per active list.
- Separate indexed shapes for one account, all accounts, category contributions and selected-account merges. Arbitrary combined filters use a bounded, cancellable scan/materialised path; no promise of constant-time arbitrary filters.
- Category totals use split contributions, never also the parent amount; an unsplit assignment is one contribution.
- Home, Wealth, Goals and other consumers resolve shared metric keys through one read repository. Q16 reads a bounded set of exact scalar values in one snapshot. Holding values feed shared totals; screens never multiply price by quantity. A header never scans all cash records and quotes.
- Price history reads ordered ranges in bounded pages. Keep immutable versions and a selected-current pointer. Never overwrite a quote a close or retained projection references.
- FTS documents use local integer keys mapped to authored identity. Maintain parsed live fields in the source transaction, including edits and soft deletes. Never index raw statements, transcripts or attachment bytes.
- FTS is a complete logical index, not an evictable cache; show Preparing/unavailable during a full rebuild. Search results and filter materialisations can expire independently.
- Index the actual filter plus ordering. Prefer partial indexes for live authored rows; add covering indexes only where measurements justify the write/storage cost. WITHOUT ROWID suits some composite-key technical tables, not all. `SQLite partial indexes, WITHOUT ROWID`

## 8 Projections, revision checks and evidence pins

General rules (time boundaries, stale jobs, chart reduction): SYSTEM_DESIGN 8 and 9. Physical rules:

- `metric_values` stores one typed scalar per generation. The canonical key excludes screen identity. Current keys use an explicit current-mode policy and stable as_of=0, not the render time. Method, scope and currency differences remain different keys. See SHARED_STATE 1.
- `db_state.read_revision` is separate from the authored commit sequence. Current-pointer moves and source/clock invalidation advance it atomically. One staging generation per key coalesces duplicate consumer work. Complete source dependencies are required even for a scalar that consumes other metrics.
- A job never clears a dirty interval outside its own range (an October job cannot clear an interval that begins in January). An edit during calculation, or a restore, makes the old job ineligible to publish. Timezone, midnight, due-date and freshness boundaries invalidate affected results without a ledger write.
- Each generation records kind, canonical scope, period, cutoff/as-of, currency, settings/method/basis, algorithm version, database epoch, captured dependency revisions and coverage. Unknown states travel with values.
- TWR, annualised TWR/CAGR, XIRR and non-annualised MWR have independent input coverage.
- A relevant change to account postings, instrument quotes, FX pairs, rules, settings or evidence increments its revision and writes/coalesces dirty date intervals in the same source transaction.
- The computation protocol uses half-open [start, end) intervals; convert inclusive date columns at the repository boundary.
1. Capture epoch, dependencies and the requested dirty interval/version.
2. Read inputs in bounded pages; verify revisions before and after extraction; retain needed immutable input versions.
3. Compute in the worker; write output and complete input pins in bounded pages to an unpublished generation. Freeze the complete staging set through the owner, then validate it in bounded pages outside the final transaction.
4. Use the owner-held certificate and bounded group/dependency/metadata limits in EXECUTION_SAFETY 1. The final transaction rechecks current inputs and certificate identity, moves the coherent pointer set and advances `read_revision` once; it performs no full-series/pin validation scan. Ordinary small edits retain their atomic source transaction (section 6).
5. Clear the single conservative dirty envelope per scope/kind only when the result covers all of it at its required revision; partial work leaves it dirty. Only a later interval-table migration may split residual ranges. Release old generations after readers.
- An October job cannot clear a dirty interval starting in January.
- Saved closes pin exact input/method versions and coverage. A retained projection pins the quote versions it needs. Independent `history_quote_pins` and `history_detail_pins` retain acquired historical evidence beyond all disposable generations. Releasing a projection removes only its own pins. Eviction never leaves dangling references; unavailable evidence remains Missing, never invented prices.
- `exact_series_points`: one sparse ordered series per generation with exact money/Decimal value, state, date, resolved same-day order and coverage. Tables and crosshair reads use it, never mutable transactions.
- For exact series, `projection_entity_inputs` pins relevant ChangeLog revisions with versioned complete after-images; `projection_detail_inputs` and quote pins keep selected public observations. Pin selected revisions only, not every revision per point.
- Each chart bucket references first, minimum, maximum and last point ordinals in the same generation; gap buckets carry explicit Missing endpoints. Before publication validate endpoint/extrema values and times, ordered membership, source counts and no interior Missing point in a known bucket. Composite FKs prove membership only.
- Allocation/gain/checkpoint outputs share the publication boundary. Published points and inputs are immutable; eviction removes a whole released generation after reader leases and visible pointers retire.

## 9 Storage budgets and retention

| CLASS | INITIAL POLICY |
|---|---|
| Authored financial records, receipts, source identities and history | No automatic expiry. Keep identity and dependent history through soft deletion/Undo. |
| Saved close revisions and their evidence | Keep all saved revisions and required immutable inputs unless a separately defined explicit deletion removes the dependency closure. |
| Structured drafts and pending Inbox work | No automatic expiry. Explicit Discard removes payload and unneeded temporary material. |
| Public quote/detail cache | 256 MiB for unpinned disposable rows. Evict least-used ranges/versions with no owner. Pinned evidence is measured separately. |
| Historical public evidence | Keep verified acquired daily quotes/corrections for confirmed investment history and retained benchmarks; keep required detail versions. Pins share the original rows and have no automatic expiry. See SHARED_STATE 4. |
| Public logo cache | 16 MiB initial unique encoded-file budget. `public_asset_cache` shares authenticated files through manifests; monogram on miss. Files still obey all attachment/recovery leases. |
| Disposable projections and temporary query materialisations | 128 MiB initial disk budget. Active readers, jobs and pointer transitions need safe retirement. |
| FTS index | Complete rebuildable corpus; measured separately. Never remove documents to meet the result-cache quota. |
| In-memory result and chart cache | 32 MiB total; SYSTEM_DESIGN defines page/message limits. |
| Attachments, active DB, WAL and retained recovery generations | Report actual bytes and reserve working space. No fixed promise independent of source size or history. |

Keeping history and avoiding duplicated source data are compatible; keeping unlimited history at constant size is not. Do not retain every repeated provider response or raw input file. Preserve structured facts, corrections and required evidence; keep original documents only through an explicit supported attachment choice. The detailed retention matrix and stable-key cleanup contract are in SHARED_STATE 4–5.

- Bounds are initial engineering values, not user-data limits. Pins can exceed a disposable budget; never delete authoritative data to meet it. Show a factual storage state and pause optional work. Estimate from measured pages, WAL and attachments, not CSV bytes.
- After Save/Discard, remove draft payload/reference/temporary attachment rows; keep the small intent-linked header.
- After import confirmation, clear accepted Inbox proposal payloads and staging links, then staged payload rows. Keep source-claim and batch identity headers.
- Remove frozen operation chunks only after a resolved committed/rejected/cancelled outcome; intent identity and receipt stay. Never remove the only copy of an unresolved command input. Explicit restore's restoredForReview cancellations are exempt from terminal cleanup until a recoverable new draft/input owner is durably established (EXECUTION_SAFETY 5); unsupported inputs remain retained.

Import inputs.

- Parsing and preview stay private. `import_batches.inbox_published` defaults to 0; explicit Send to Inbox prepares candidates in bounded pages, then publishes the marker and shared count atomically. `db_state.inbox_revision` invalidates membership/visibility cursors. Q13 applies eligibility after bounded candidate extraction. Withdrawal changes batch status, count and revisions together; accepted financial records require their own Undo. Full contract: EXECUTION_SAFETY 2.
- Data-supplied patterns use the bounded grammar/engine and work limits in EXECUTION_SAFETY 3. Future source tables require durable policy/configuration revisions; runtime callbacks additionally carry fresh capabilities (section 4).
- An active import has typed `import_job_inputs` links from its job to batch, encrypted staging source and immutable parse configuration (parser/template versions, mapping, locale/date/decimal rules, account assignment, source-identity codec).
- Lease the source before file creation/publication. Restart requires the same source digest and supported frozen configuration. A source published without metadata is an orphan, excluded from deletion while its native writer lease is live. Committed metadata never references partial bytes.
- The batch references its immutable parse configuration directly; this FK survives removal of a terminal job, so a restored incomplete batch can still verify its mapping and identity codec. The writer checks that batch parser metadata and each job configuration match it.
- Job input links are never changed in place. A newly selected source gets a new job/input link, and its digest must match the retained batch before it resumes. Keep the configuration until its batch and required structured drafts are discarded.
- Recovery snapshots keep staging/configuration and omit raw source bytes and staging keys. Restore marks incomplete batches sourceNeeded (or unsupportedParser), keeps completed staged rows/decisions/claims, and forbids automatic resume. The same local source needs digest/configuration verification and a new leased source/job; a different file or mapping is a new import. Completed batches need no raw source.

The 5-million-quote stress fixture may use a larger cache budget; record that setting in its result. A benchmark that silently evicts its fixture is invalid. PERFORMANCE_PLAN defines device tiers and latency/memory gates.

## 10 Attachments, recovery and migration

Attachment commit

Write, authenticate and flush encrypted bytes to a temporary file. Publish the immutable opaque file, then commit its reference with the financial command. A crash may leave an unreferenced file, never a committed reference to partial bytes. The cleaner considers active jobs, history and all generation leases before deletion.

Indexed cleanup and job ownership

The cleaner uses `local_jobs_generation`, `event_attachment_reverse`, `draft_attachment_reverse` and `close_attachment_reverse` for reverse FK lookups. Test plans on populated data; bounded candidate pages alone do not bound a repeated full child-table scan. `SQLite foreign-key indexes` Initial cleanup slice: at most 32 candidates or 20 ms of measured statement work, then yield to foreground commands. A native statement can exceed the cooperative slice; verify its bound/cancellation on the pinned encrypted build. A high-fanout object is retained or reclaimed through a separately admitted background plan, never an unbounded foreground cascade.

Active job, reader, history and recovery leases block deletion. For a terminal projection job, revoke its attempt and detach its generation reference before deleting that whole released generation. Do not detach import jobs or unknown workload kinds under a generic projection policy. All worker message writes use the attempt fence in SHARED_STATE 2. Cleanup cannot delete/reset `dependency_revisions`; identity/revision pairs remain valid for the database epoch.

Scalar evidence uses the authored-cutoff descriptor in SHARED_STATE 2 only after the registry proves complete audited replay. It has no chain of retained predecessor totals. Count the whole closure against the 512-row-effect / 256 KiB ordinary derived budget; larger explicit public/operational evidence takes the large-work path. Immutable full history stays retained; no history compaction is introduced.

Control data outside replaceable generations

- A small encrypted device-control manifest sits outside the financial database generations. It stores format version, opaque active/staged/retained generation IDs, install state, snapshot-job leases and referenced file/key-version IDs. No financial values or user text. Its device-only protection key is independent of database rekeying.
- The detailed manifest stays inside each generation. The control registry records the conservative file/key closure for cleanup, or a global cleanup lease while that closure is built.
- One recovery build at a time. Persist the lease before copying; an interrupted job keeps it until its staging generation is safely discarded. Losing the control manifest is a recovery state, never permission to delete unknown files/keys.
- Large closures use immutable encrypted lease manifests, streamed during cleanup, never one in-memory JSON of all attachment IDs. The active-generation pointer stays bounded.
- The control manifest uses a versioned authenticated format and atomic durable replacement. Startup reconciles leases against generation manifests before cleanup; an uncertain lease blocks deletion.
- Delete all records a durable deletion intent and resumes after interruption. Remove the control key last, after registered files and other keys. An interrupted wipe must never reopen partial records.
- A restored old database is never the only registry of newer snapshots. Retiring/rekeying one generation never retires keys another needs. Garbage collection uses the union of active, staged, retained and incomplete-job closures.

Delete all and capture writers.

1. Under a shared native cross-process lock, durably set lifecycle state deleting and rotate the opaque install epoch.
2. Reject new capture/network/job/write admission; revoke existing capabilities.
3. Drain main and extension writers. Every native writer takes an epoch-scoped lease before its first file/key write and rechecks it under the same lock before publication. Files stage in epoch-specific directories. Extensions get staging capability only, never the ledger key.
4. Live/unknown leases block completion; time expiry alone never proves process death. Reconcile terminated ownership.
5. Remove all old-epoch files/keys, then control protection last.

Restart resumes deletion. Welcome/new install state follows only this boundary; an old capability cannot create a new epoch or republish old content.

Snapshot and restore

Protocol: SYSTEM_DESIGN 13.1–13.2. Database rules:

- Back up a consistent snapshot with the verified encrypted mechanism; never copy only a live .db while committed data is in WAL.
- Reserve space; protect file/key versions before copying; verify DB and attachments; then mark the generation complete. Keep the last verified snapshot on failure.
- Validate restore staging separately for schema, SQLite integrity, FK integrity, cipher authentication and attachment authentication. `cipher_integrity_check` success returns no error rows; `integrity_check` expects ok. `SQLCipher API, SQLite integrity checks`
- After confirmation stop writers/readers/jobs and provider sessions, force market access off in restored settings, flush files and install journal, then atomically replace the pointer on the same volume.
- Before activation, complete bounded staged classification of intents under EXECUTION_SAFETY 5. Preserve receipts/digests; cancel receipt-less pending attempts for review and retain their inputs. Explicit restore never automatically replays a saved command. Normal crash recovery remains receipt-first.
- Use a fresh random runtime/database epoch, never a copied counter. Verify the generation before commands. Old worker replies, cursors and draft handles fail epoch checks.
- Pre-switch crash keeps the old generation; post-switch crash opens the new one. Verify file/directory durability per platform. Keep old generations and keys until the recovery boundary.
- Same-phone only: no recovery from device loss, uninstall or lost keys; no external backup, export, cloud sync or LAN transfer.

Migration contract

Database schema, draft schema, command payload, parser identity-policy and computation algorithm versions are separate. A migration never reinterprets an old receipt digest through a new codec.

Reference upgrade `002_shared_state.sql` has a frozen v1.1 schema fixture and forward/rollback tests. It adds shared values, removes only disposable generations, conservatively pins existing evidence and preserves import jobs and financial history. `003_review_guards.sql`, with a frozen v1.2 fixture, adds lifetime guards and reverse indexes. `004_full_review.sql`, with a frozen v1.3 fixture, adds identity/conflict guards, singleton retention and Inbox visibility/revision fields. It preserves already-existing Inbox batch visibility; new batches stay private. Paths 1→2→3→4, 2→3→4 and 3→4 must match fresh version 4, retain financial rows/evidence and roll back on failure. `005_layout_sections.sql`, with a frozen v1.4 fixture, adds layout sections, sizes and the base layout version (5.1). Paths 1→…→5, 2→…→5, 3→4→5 and 4→5 match fresh version 5, keep financial rows and each custom layout, and roll back on failure. These are reference migrations, not a released Drift database version.

1. Pin native libraries; save the Drift schema snapshot for every released version.
2. Test each supported upgrade path with fixtures holding accepted/undone events, receipts, source tombstones, immutable evidence, pending drafts, FTS, attachments and close pins.
3. For a rewrite, migrate a staging generation, rebuild disposable indexes, validate, then switch generations. Small in-place migrations need equivalent rollback tests.
4. Preserve authoritative values/IDs, original payload bytes/digests and history. If an old draft cannot migrate, keep its payload and show its unsupported state.
5. Reject a newer unsupported schema without resetting it. No destructive downgrade or empty replacement on open failure.
6. A formula change increments the algorithm version and invalidates derived results. Never recalculate an immutable saved close in place.

## 11 Verification and build order

Run the local reference check:

```text
python3 docs/approved-architecture/database/validate_schema.py
python3 docs/approved-architecture/database/validate_shared_state.py
```

VALIDATION separates executed checks from required future tests. Plain SQLite checks are not release acceptance for SQLCipher or domain commands.

| STEP | OWNER AND OUTPUT | ACCEPTANCE |
|---|---|---|
| DB-A | Data/native builder: pinned cipher factory, codecs, connection settings | Wrong key/no cipher fail closed; exact value round trips; encrypted WAL/temp/FTS and backup exclusions verified on devices |
| DB-B | Data builder: Drift translation of reference schema, migrations | DDL parity, FK/constraint cases, old-version data preservation, database owner and complete transaction rollback |
| DB-C | Domain/data builders: command protocol and ledger graph | Receipt-first retry, changed-payload rejection, cancel race, atomic batch, source identity and Undo dependency tests |
| DB-D | Data builder: query variants, FTS, compact price ingest | Representative plans and cold/warm device timings at B/L/S tiers; bounded work for residual filters |
| DB-E | Domain/data builders: metric registry, central read store, projections and return inputs | One calculation per key/input revision; atomic source and small totals; incremental equals independent full rebuild; stale worker/clock races; retained history survives cache eviction |
| DB-F | Native/data builders: generation recovery and key lifecycle | Crash/disk-full matrix at file publish, commit, backup, migration, pointer switch and cleanup boundaries |

Integrity cases: duplicate retry after lost response, altered payload under one ID, cancel/commit race, failure halfway through a selected confirmation, reimport after Undo, immutable anchor correction, partial and excessive settlement, Undo with dependent lots, edit/restore during projection, partial dirty-range acknowledgement, overflow/invalid Decimal, soft-deleted references, file/key leases. Add property tests comparing incremental projections with a full rebuild over generated event histories.

The storage contracts are specified for foundation implementation. Correction gates stay prerequisites for their commands. Production readiness needs the matching device, migration, domain, privacy and performance evidence; this reference does not resolve PF-01.
