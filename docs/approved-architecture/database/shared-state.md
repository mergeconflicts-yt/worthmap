# Shared values, updates and retained history

Version 1.3 · 16 October 2026 · ARCH-FINAL-001 · Unchanged shared-state contract, re-reviewed in the final baseline.

This refines `DATABASE_DESIGN` and `SYSTEM_DESIGN`. SPEC owns every financial definition. The reference schema and tests verify storage structure. They do not implement the calculation engine, command writer, reactive UI or encrypted device storage.

## 1 One value per meaning

All consumers of the same metric use one canonical key, one current persisted result and one immutable in-memory value. Screens, cards, charts, Quick look tiles and configurable in-app widgets cannot implement copies of a formula. The repository owns calculation and subscription. Native OS widgets, shortcuts and intent adapters receive no metric subscriptions, financial result DTOs, values, private entity IDs or snapshots. Their allowlisted generic launch actions wait behind unlock (SPEC 15). There is no financial OS timeline in this design.

Phase 1 widget placement, activation, failure and editor contracts are in WIDGET_FRAMEWORK. A widget registry selects presentation modules; it is not this metric registry. Stable placement identity never becomes a financial cache key. It also stays independent of section position and visual width. Add widget previews use the distinct resident-only observation capability in WIDGET_FRAMEWORK 3.1: no normal request acquisition, availability query, computation, file/decode or gateway work; no pin that prevents cache eviction. Missing resident data remains unavailable and later shared publications can update it. Preview leases are bounded, masked and revoked independently of normal placement leases. Layout/gate changes release only affected subscription leases; they do not invalidate financial metrics.

The bundled metric registry in `lib/domain/numbers/` defines:

- Stable metric ID, SPEC reference and method version.
- Output type, unit, allowed actual/expected basis and missing-state rules.
- Canonical scope and period parameters, time policy and currency policy.
- Dependencies, source extraction, exact calculation and supported incremental operation.

The registry is code with tests, not executable formula text stored in the database. This change creates no financial definition. Existing unresolved SPEC gates still block the corresponding calculator. A `return.xirr`, `return.twr` and `return.annualisedTwr` key are different metrics; they cannot share a scalar merely because all display percentages. A financial ratio is stored in its registry unit, not rounded display text.

### Identity and storage

Use the existing `projection_keys` identity:

`kind + canonical scope + period + as_of policy + currency + method_version + calculation policy.`

| FIELD | CONTRACT |
|---|---|
| kind | Registry metric ID, for example `metric.netWorth` or `metric.goalAssignedValue`. No screen or widget identifier. |
| Scope | Sorted unique entity IDs and typed filters; semantically identical selections have identical canonical bytes. Explicit all-accounts scope has its own membership revision. |
| Period | Valid half-open calendar range. A timeless key uses the registry's fixed sentinel range `0001-01-01` to `9999-12-31`; it does not mean historical coverage. Period-specific metrics use their real range. |
| Current versus historical | Current keys use `as_of=0` and an explicit `mode=current` policy. Fixed historical keys use an explicit `mode=fixed` policy and exact cutoff. The mode prevents a collision with a historical epoch-zero cutoff. |
| Time | Current policy includes the relevant calendar/timezone identity. Actual evaluation cutoff, calendar date and observed-through time are sealed in generation coverage. Never use the time of a render or request as a new current key. |
| Currency | Explicit reporting currency. No inferred conversion. For a unitless result this remains its valuation currency context; it is not a display suffix. |
| Policy | Only calculation-affecting settings, method, basis and selected evidence policy. No theme, page, chart width, sort-only preference or formatting precision. |
| Digests | Stable codec and hash version. Compare full canonical scope/policy bytes after a hash match. A collision is an explicit error; never return a different scope's value. |

`current_projections` selects a `projection_generations` row. `metric_values` stores exactly one typed scalar per scalar generation. Currency and method stay in the key; coverage and computation metadata stay in the generation. No total columns are added to accounts, holdings, goals or layouts. No separate Home or Wealth copy of net worth is stored.

Money uses integer minor units; ratios and quantities use canonical Decimal text; counts use nonnegative integers. Known zero is valid. Missing/none-recorded/unavailable has NULL numeric fields and a typed reason. Calculation availability, data freshness and actual/expected basis are separate dimensions. Error details never contain personal data.

Charts use existing exact series and reduced drawing buckets. They may contain a point equal to a headline total because a historical series is a different output shape. For the same scope, cutoff and method, that point consumes the shared valuation result; it does not run an independent valuation. Chart labels and tables read exact values. Saved closes retain intentional immutable snapshots, independent of disposable current results.

## 2 One dependency graph and one active calculation

Resolve requested registry keys into a directed acyclic graph. Reject cycles at registry validation. Process it in dependency order with one memoised result for each `(dbEpoch, canonicalKey, capturedDependencies)` tuple. A second consumer joins the same work; it does not enqueue another job. The partial unique index `projection_one_staging` admits one staging generation per key. The scheduler must retire superseded staging work before replacement and recover abandoned staging at startup. The attempt fence below applies even when a replacement reuses the same integer generation ID.

Store the union of each node's transitive **source** dependency versions in `projection_inputs`. A dependent net-worth value therefore remains invalidatable even if an intermediate asset-total cache is evicted. The registry also declares collection-membership scopes, so a newly added account, instrument, obligation or goal allocation invalidates an earlier "all" result. Record quote selection, local FX selection, settings and calendar/clock revisions when consumed. A dependency set with thousands of per-record members needs an aggregate scope revision with tested membership invalidation; do not make every read enumerate the ledger.

Dependency scope identities and revisions persist for the database epoch, including after every result for that scope is evicted. Revisions only increase through checked UPDATE. Delete/recreate and REPLACE are prohibited; cache cleanup cannot reset them. A whole-vault replacement uses a new epoch. The SQL guards enforce this for existing revision rows; the writer creates a scope and its first revision together. The insert guard also blocks REPLACE, whose implicit deletion can bypass delete triggers when recursive triggers are disabled. SQLite conflict handling

### Bounded scalar evidence

A scalar generation can use the versioned `coverage_json.evidence` descriptor `{ "mode": "authoredCutoff", "version": 1, "historyCodec": 1, "selectionCodec": 1 }`. Its authored input identity is `(db_epoch, source_commit_sequence)` plus its immutable key, method, evaluation time and coverage. Capture the post-command commit sequence for an ordinary edit. This references the original retained history; it does not copy all prior ChangeLog IDs or depend on earlier scalar generations.

- Replay selects the latest complete authored after-image at or before the cutoff, ordered by receipt commit sequence and ChangeLog ordinal. Include creates, corrections, soft deletes and collection membership. Never replay from today's mutable rows. Initial authored state must be audited too.
- Before accepting a command, the writer checks the next append against each affected entity's verified prior head: exact previous revision, one next complete versioned after-image, no existing row at that entity/revision, and the full current command mutation closure. This is inductive validation with bounded indexed seeks per changed entity, not a scan of its history on each Save. A fresh vault establishes the invariant from its first command. Migration/recovery/replay verifies historical chains in bounded worker pages before declaring them usable; unresolved or invalid history blocks cutoff-mode admission. No foreground command performs full-chain validation. Each authoritative selection change not already in an authored after-image is recorded in the immutable versioned operation receipt as typed old/new selection references. This includes balance anchors, local FX, occurrence decisions and calculation settings when consumed. The writer checks these identities against the committed selection. Generic receipt JSON alone does not prove completeness.
- The registry admits cutoff replay only for a source extractor whose complete input closure has this audit representation and a tested decoder. Missing history, an unsupported codec or an unaudited selection makes that calculation unavailable; it cannot silently substitute current state. Existing saved-close and exact-series contracts retain their explicit typed entity pins. They do not adopt this scalar exception.
- Public prices/details are not authored history. Each scalar still pins its exact selected observations through typed bridges. Operational occurrence snapshots retain the existing sealed fields and schedule/decision references. The cutoff never means "use the latest downloaded price". These explicit pins and frozen inputs survive until this generation is released.
- The ordinary path admits at most **512 derived row effects and 256 KiB of encoded derived values/evidence**, across the whole required metric closure, including generation metadata, dependency rows, explicit pins and pointer changes. Count inserts, updates and deletes; include scheduled retirement effects if done in that transaction. Source/audit writes retain their separate command bounds. Use aggregate dependency scopes with tested membership invalidation. Over-budget evidence, a missing baseline or an unsupported delta uses the large-work path before commit; never omit pins to fit.
- Reuse the exact numeric baseline for a validated delta, then retain only this new descriptor and the bounded non-authored evidence. No predecessor chain is required. Full replay pages the original history in a worker; it never runs on a current-value read. Cache compaction may delete every old scalar generation, but cannot delete or rewrite the referenced authored history or decoder semantics. History compaction is not supported by this design.

Acceptance must compare equal small edits over different history sizes, count all derived row effects/bytes and show constant foreground evidence cost for the same supported closure. Evict predecessor results, correct/delete original sources, change membership and selected quotes, restart and compact disposable caches, then replay the retained scalar at its captured cutoff against an independent full rebuild. The synthetic reference harness checks the storage pattern; the complete financial engine remains DB-E.

### Worker attempt fence

Every extraction, staging, progress, checkpoint, failure and completion message carries `(dbEpoch, localJobId, attemptNonce, generationId, canonicalKey)`. `localJobId` is an owner-issued UUID that is never reused; `attemptNonce` is a fresh unpredictable owner-issued lease nonce stored in `local_jobs.lease_owner`. Generation IDs are locators, not attempt identities. A projection job uses `kind=projection`.

The owner validates the whole tuple, running state, unexpired lease, staging status and captured dependencies in the same writer transaction as each accepted message. Private direct worker SQL writes are forbidden. Resume/restart rotates the nonce before admitting work. Pause/cancel revokes it before any replacement is created; terminal jobs cannot submit messages. A process restart revokes old leases before recovery. Lease time is an additional admission limit, never identity. Publication consumes the attempt and changes related pointers atomically. Reject a late chunk or completion without changing progress, rows or pointers, even if the replacement has the same generation ID, epoch and source revisions. Startup and whole-vault replacement also enforce the epoch check.

Tests delay an old chunk and completion across cancellation, ID reuse, pause/resume and restart. This is an owner/scheduler interface obligation, not a capability enforced by generation FKs. The reference harness exercises the predicate; production worker routing and transactional enforcement remain DB-E.

The final large-result publication additionally requires the owner-held freeze/validation certificate in EXECUTION_SAFETY 1. Complete validation runs in bounded pages before the final transaction. All staging children and metadata are frozen. Attempt/restart/mutation invalidates the certificate. The bounded coherent-group admission includes pointer trigger work; one short commit cannot hide a scan of all history or an unbounded number of keys.

"Calculate once" means reuse within one compatible input revision. Eviction, restart, a corrected source or a new method can require a rebuild. It does not mean keeping every calculated value forever. Screen subscription alone never changes financial dependencies or creates a fresh key.

## 3 Atomic updates and publication

`db_state.commit_sequence` orders confirmed authored commands. New `db_state.read_revision` orders committed visible-state publications, including validated quote changes, clock invalidation, layout changes and asset availability. It increases by one per such transaction. Private worker staging does not advance it. `db_epoch` changes after restore/replacement; revision comparisons always include it. Exhaustion fails explicitly, never wraps.

### Ordinary edit with a valid baseline

1. Resolve the command's affected dependency closure. Load current exact prerequisites and prepare bounded incremental results in the worker. Reuse each dependency once. The metric registry declares which operations have a proven incremental path.
2. The single writer starts a transaction and checks receipt first, expected entity revisions, dependencies, epoch, calendar context and command invariants. If preparation is stale, roll back and retry or take the large-work path. Do not hold a write lock during long computation.
3. Commit source changes, ChangeLog, dependency revisions, dirty historical ranges, the required small metric generation set, the cutoff descriptor and bounded explicit evidence, current pointers, receipt and `read_revision + 1` together. Stamp generated inputs with the **post-command** dependency revisions. No visible intermediate source-only state is allowed for this path.
4. Notify the central read store once, after commit. Read Q16 for the union of active metric subscriptions in a short snapshot. Replace one immutable state map and deliver it to subscribers. A Save result includes the committed epoch/read revision; the UI cannot acknowledge a newer view with an older local map.
5. Release old output generations after pointer replacement and reader leases. Schedule dirty history and off-screen expensive metrics separately.

The required small set is the affected closure of the app's current summary catalogue plus active lightweight metrics. It includes net worth and its shown components, current account/holding values, affected spending/income summaries and goal assigned values where their prerequisites are supported. The registry explicitly classifies expensive returns and historical rebuilds. It cannot classify a cheap shared total as background work merely because the writer omitted it. No process-wide all-accounts rebuild per one-symbol update.

The P04 target measures Save tap through committed small totals and the matching published app state. It includes queue delay, validation, commit and notification; it is not a zero-time guarantee. UI work remains off the financial computation path. Checked delta operations require tests against an independent full rebuild, especially for splits, refunds, transfers and missing evidence. A cache miss or unsupported edit never invents a delta.

### Large work and missing prerequisites

Imports, older investment corrections, return solvers, first rebuilds and unknown dependency closure can exceed the ordinary budget. Commit the accepted command, dirty scopes and read revision atomically. Then publish a snapshot that marks every affected old result Updating, with its prior date if usable, or unavailable when no compatible result exists. Do not show a new component with an old parent total as if both are current.

Run paged work at the existing priority/cancellation limits. Stage the related result set, verify full coverage and dependency revisions, then move its pointers and advance `read_revision` in one transaction. Notify all consumers automatically. An unrelated unaffected result may stay current with its previous generation. A failed or cancelled rebuild keeps the accepted source command and its receipt; its result remains explicitly unavailable/updating and can retry. Storage pressure never changes an accepted financial fact to make a cache fit.

### Reader and worker races

- Q16 returns epoch, publication revision, exact value and freshness. Widgets never compute freshness from a private timer or maintain their own metric copy.
- A returned snapshot older than the store's current epoch/revision is discarded. A delayed callback cannot replace a newer map. A late subscriber immediately reads the current map.
- Subscribe once per canonical key; multiple views share that subscription. On disposal release the consumer, then cancel work/leases when no reader needs them. OS suspension does not preserve a long SQLite read transaction.
- On restart, rebuild the central store from committed pointers. Never replay an uncommitted optimistic total. Receipt-first recovery handles a lost Save response. A proven rollback keeps the editable draft. An unknown outcome freezes submitted input and resolves the original operation ID. A proven commit followed by read-store/rebuild failure remains a successful accepted command: keep its receipt, retire its submitted draft and retry only reads/derived work. Never create a new financial operation to recover a notification.
- Midnight, timezone change, quote-age boundaries and resume advance the affected clock dependency before exposing current values. No authored history entry is created for passage of time.
- A table-wide Drift watch is not one query per widget. Use writer-issued scope invalidations and the central read store; raw Drift streams can rerun when watched tables change. Drift streams

## 4 Retain evidence; bound disposable results

| DATA | RETENTION AND PURPOSE |
|---|---|
| Accepted events, postings, original currency/quantity, fees, dates, source identities, authored observations and correction history | No automatic expiry. Keep evidence for later financial analysis and Undo. Soft deletion does not remove historical identity. |
| Local FX and manual quotes, lot/cost evidence, chosen classifications and saved closes | Retain original exact versions and source links. Never substitute a later price, FX rate or classification into an old saved result. |
| Verified daily quotes and corrections for instruments with confirmed investment history | Pin each acquired observation in `history_quote_pins`, independent of projection/close lifetime. When a holding is confirmed, promote already cached relevant history in the same command; page a large promotion under the large-work protocol. Future fetches pin in the ingest transaction. |
| Public details used by accepted instrument history or a retained calculation | Pin exact detail revisions in `history_detail_pins`. Keep new verified relevant revisions; unchanged bytes do not create a revision. `fetched_at` means observed by this app, not the date a classification became effective. |
| Selected public benchmarks | Retain acquired daily evidence when selected for persistent comparison. Selection is a local authored setting; it is not sent to the provider. No arbitrary catalogue-wide archive. |
| Public catalogue browsing, unused quotes/details | Disposable cache, 256 MiB initial budget. Evict only rows with no current selection, job, projection, close or retained-history owner. |
| Scalar generations, chart reductions and temporary filter results | Disposable, 128 MiB initial disk budget. Keep current useful values and active reader leases. Evict obsolete generations and unreferenced rarely used keys; no timestamp-per-render keys. |
| Original import files | Existing default remains: encrypted temporary input until parsing/resume no longer needs it. Keep structured facts and source provenance. Retain a document only through an explicit supported attachment choice. Blanket retention of every statement is not enabled. |
| Receipts and policy documents explicitly retained | Existing authenticated encrypted file store and reference/lease closure. Keep one immutable file per verified content identity where safe. |
| Audio, raw transcripts and temporary OCR material | Existing transient capture policy. Do not archive these merely for possible future analysis. |

Confirmed history includes archived or disposed holdings. Retention does not trigger ongoing fetches for every disposed instrument, enable market access, or send ownership to a provider. Fixed public history ranges remain the only allowed date requests. If history was never acquired, it remains unavailable offline. Retaining fields cannot recover information the source never contained.

A large promotion cannot leave history exposed to eviction between batches. The confirmation transaction marks its retained-history eligibility and reserves a durable job/retention lease before background pin work starts. The cleaner excludes all relevant series/details while that lease is unresolved. Restart resumes the promotion before releasing the lease. Eligibility is derived from confirmed authored history, including tombstones, not from the currently open screen. Small promotions complete their pins in the confirmation transaction.

`history_quote_pins` and `history_detail_pins` reference the existing observation rows; they do not copy prices or JSON. The reference guards prohibit mutation/deletion of these pins. No automatic TTL or quota can remove them. Delete all remains the existing whole-vault process. A future selective history purge requires an explicit user action and a dependency-closure design; this change does not implement one.

Identical provider content for the same semantic observation reuses its revision; a changed daily close appends a correction. Check canonical content, provider/series/date/basis and full bytes after a digest match. Store fetch status separately rather than appending unchanged quotes on each poll. Source transaction dedupe remains based on source identity: two real payments with identical text/amount/date remain two payments.

Daily history is the retained granularity supported by the current schema. Spot/intraday observations need their own interval/effective-time migration and retention budget before implementation. This contract does not retain an unlimited stream of ticks or imply that a daily close can supply an intraday chart.

Phone storage cannot be both constant-size and an unlimited historical archive. Measure authored data, retained public history, indexes, files, recovery generations and disposable caches separately. Pause optional ingestion before exhausting the reserved working space. Never prune financial history silently. Retained evidence and current useful results may exceed a cache budget; capacity admission and factual storage state handle that case.

Provider selection must permit the retained local history required here. If its licence does not permit that use, it cannot supply those historical inputs; do not resolve the conflict by silently expiring required evidence.

## 5 Public logos and local layouts

The user's permission covers public logos and needed public assets. The initial physical cache supports only inert raster logos; additional asset classes need typed descriptors, licence review and bounded decoders before use. The same opt-in gateway and off switch cover all public fetches. No separate image HTTP client, arbitrary returned URL, remote font, model download, user upload or telemetry is introduced.

`public_asset_cache` maps `(provider, public asset key, rendition)` to an existing `attachment_manifests` ID. It holds no financial value. The file store deduplicates by authenticated digest, MIME and size, then verifies content identity before reuse. Two public descriptors can share one immutable file. Serialise lookup/create through the owner and use the existing file publish protocol; a crash can leave a removable orphan, not a reference to partial bytes.

- Initial renditions: logo-64, logo-128 and logo-256. Initial cache budget: 16 MiB of unique encoded files; decoded images share the 32 MiB application result/geometry budget.
- Gateway admission: at most 1 MiB encoded raster data and 1,024 × 1,024 decoded pixels per source; reject animation, active/vector content and unsupported formats. Validate content bytes, pixel dimensions and decode work before storage; MIME alone is insufficient. Produce the requested bounded rendition locally.
- Database guards permit PNG, JPEG and WebP manifests within the encoded limit. Native decoder and pixel/animation checks remain implementation tests.
- Request descriptors contain only audited provider/public asset IDs and rendition enum. No account/institution names from private records, arbitrary URL, private path, cookie or per-install identifier. A manually named account uses the local monogram unless it has a supported public mapping.
- An absent/evicted image uses the existing monogram. It never delays a number. Revalidate at bounded provider-policy intervals, not per screen render. A changed file swaps the descriptor reference atomically and advances the read revision, with no financial ChangeLog or metric recalculation.
- Evict asset mappings before files. Delete bytes only when no current mapping, attachment reference, history, recovery generation or job lease retains them. Recovery can keep an old public file; count that separately instead of bypassing the lease.

`layout_surfaces`, `layout_sections` and `layout_items` exist in reference schema version 5. They persist keys, order and sizes only, from Phase 1 (sections and sizes: WIDGETS-007). One writer transaction replaces the complete touched-surface patch and advances the read revision once; the preference write creates no financial ChangeLog, receipt, dependency revision or recalculation. A newly activated placement may subsequently request an uncached/stale canonical metric through the normal coalesced calculation path; a warm current metric needs no extra calculation. No surface means defaults; a present empty surface means show none. Unknown/unreleased keys are skipped for rendering and retained in storage. A stored size that the release no longer allows renders at the nearest allowed size and stays in the row. Retained (removed) section keys stay distinct and untitled; their known eligible children remain editable. Renamed keys are a read-time alias written at the next Done. Parent omission cannot delete dormant children. Home Default includes the shared Quick look tile surface. Runtime owner counters plus canonical baseline checks, bounded editing and unknown-reply handling are specified in DATABASE_DESIGN 5.1. Moving a tile changes placement, not its metric key or value.

## 6 Migration and implementation acceptance

`002_shared_state.sql` upgrades the frozen v1.1 reference fixture. It adds the publication counter, typed scalars, history pins, asset references and layouts, plus publication guards. It first revokes/detaches retained projection jobs from discarded generations, cancelling nonterminal projection work for rebuild; terminal status stays terminal. Unrelated import jobs, frozen configuration, input links and source leases remain unchanged. Unexpected job kinds that retain a generation stop the migration for typed recovery. It then discards disposable old generations before enforcing one staging generation per key. It preserves authored IDs, amounts, audit, receipts, quotes, details and saved closes. Since the old version did not classify retained market history, it conservatively pins all existing quotes/details. It does not refetch or silently delete them.

`003_review_guards.sql` upgrades the frozen v1.2 fixture to reference version 3. It adds lifetime revision guards and four reverse cleanup indexes without deleting data. Both 1→2→3 and 2→3 paths have parity checks and injected-error rollback checks.

`004_full_review.sql` upgrades the frozen v1.3 fixture to version 4. It prevents protected-identity replacement and singleton reset, adds the one-way import publication marker and Inbox revision, and preserves visibility of existing candidate batches. New imports stay private until Send. Explicit restore separately retires receipt-less pending operations for review; it does not alter committed receipts or replay old commands (EXECUTION_SAFETY 5).

`005_layout_sections.sql` upgrades the frozen v1.4 fixture to version 5. It rebuilds only the layout preference tables: each existing custom surface with items gets one untitled section, full items in the old order (positions renumbered from zero) and base layout version 1; an explicit empty surface keeps its row with no section. It adds the `layout_*_no_replace` triggers. It changes no financial row, receipt, audit, shared value or read revision. Paths from versions 1–4 match fresh version 5; an injected error restores version 4.

The SQL is an executable reference, not a released app migration. The migration runner verifies source version, pauses readers/jobs, checks free space and guarantees rollback on any error. SQLite supports the added column through ALTER TABLE, but production Drift snapshots and encrypted interruption tests are separate gates. SQLite ALTER TABLE

| BUILD STEP | REQUIRED EVIDENCE |
|---|---|
| Typed registry and key codec | Same metric across screens resolves to one key; different currency/basis/method stays separate; stable live keys; deliberate hash-collision rejection; cycle detection. |
| Command writer and central store | Save publishes source plus required small totals atomically; rollback/lost response; stale worker rejection; delayed notifications; reattach/resume; no incompatible current parent/child values. |
| Incremental calculation | Exact equality with an independent full rebuild using SPEC fixtures and generated histories; missing inputs, all-member changes, rounding, overflow, splits, transfers and backdated edits. |
| Shared computation | Instrumented synthetic tests show one calculation per key/dependency tuple with multiple subscribers. Inactive subscriptions release leases. Cache eviction/restart rebuilds correctly. |
| Retained evidence | Drop all disposable generations and caches; old quotes/details/manual FX and saved closes remain; rebuild future analyses from retained evidence or show Missing. Corrected and unchanged provider responses are distinct cases. |
| Files and privacy | Native launch payloads contain only allowlisted generic routes, never metric DTOs/private IDs; native adapters cannot import the metric repository; launch waits behind unlock. Decode bounds, content dedupe, network-off races, no private request fields, file leases and crash cleanup; PF-01 remains unresolved. |
| Migration | Reference forward upgrade and injected-error rollback; production Drift fixture parity and process-kill/disk-full tests before acceptance. |
| Phone performance | P04 and added P14–P16 in PERFORMANCE_PLAN on encrypted B/L/S devices. No phone result is inferred from the SQLite reference tests. |
