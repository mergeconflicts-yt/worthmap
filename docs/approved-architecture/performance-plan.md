# Contour performance and capacity plan

Version 1.6 · 16 October 2026 · ARCH-FINAL-001 technical baseline.

Use this plan to accept the local architecture in SYSTEM_DESIGN. Fast rendering must preserve financial accuracy, durable writes and the network policy. All timings below are targets until a real build is measured. Keep raw benchmark traces and synthetic fixtures local.

## 1 Workloads

Generate deterministic fake records with a fixed seed. Never benchmark with personal statements or send traces to a service. Record the seed, generator version, schema, calculation version and expected exact totals.

| TIER | PAYMENTS | PUBLIC QUOTE ROWS | ACCOUNTS | INSTRUMENTS | YEARS | PURPOSE |
|---|---|---|---|---|---|---|
| B baseline | 50,000 | 100,000 | 25 | 100 | 10 | Existing SPEC acceptance and everyday tasks |
| L large | 250,000 | 1,000,000 | 100 | 1,000 | 20 | Large local history and concurrent operations |
| S stress | 1,000,000 | 5,000,000 | 500 | 5,000 | 30 | Bounded memory, disk growth, cancellation and recovery |

Instrument counts do not mean every instrument has every daily quote. Seed sparse histories, inactive instruments and missing periods. These sizes are test fixtures, not app-enforced capacity limits. Larger tiers can be added after these pass.

Each tier contains multiple currency precisions (0, 2, 3 minor units), exact fractional quantities/quotes, splits, refunds, reimbursable records, partial settlements, transfers, lots, vests, dividends/reinvestments, archived and soft-deleted records, repeated source identities and incomplete return coverage. Include records with very large checked integer values and Unicode merchant names.

Keep investments and payments distinct in the generator. Add a separate 10-year return workload with 1,000 external flows and 100 instruments for the baseline query target. Use 10,000 and 100,000 flows as solver stress cases; they must remain cancellable and bounded but have separate timings. A million expenses is not a million investment flows.

Attachment packs: baseline 100 retained images, large 1,000, stress 5,000; encoded sizes 100 KiB–2 MiB with a few files at the admission limit. Measure retained disk bytes separately from database bytes. Run the largest pack only where free-space admission succeeds; refusal must leave active data intact.

## 2 Device and build matrix

The final baseline includes the following adversarial workloads. These are required tests, not measured results. EXECUTION_SAFETY owns their admission and cancellation contracts.

- **P18 Publication:** increase staged exact-series and pin counts while keeping the admitted coherent group fixed. Measure bounded validation pages separately from final publication. Final work stays within 128 keys/scopes, 512 effects and 256 KiB metadata; no point/pin scan occurs in the transaction. Delay foreground Save during validation. Inject late chunks, source/time changes and owner restart after validation.
- **P19 Import visibility:** prepare sparse private/published Inbox candidates up to S-tier size. Measure candidate-page work, Send preparation and final marker/count publication separately. Parse failure and preview Cancel change no visible count. Publish behind an existing cursor, accept/delete concurrently, withdraw a batch and retry a lost reply; no missing row, duplicate count or partial visible selection is allowed.
- **P20 Pattern and capture admission:** S04 proves bounded compile/match/ruleset work and cancellation for nested repetition, almost-matches, Unicode/repetition expansion and many rules. Unsupported patterns preserve input without false no-match results. Test delayed native callbacks across off→on, A→B→A configuration, lock, owner restart and restore; rejected callbacks cannot advance source cursors.
- **P21 Restore intent disposition:** DB-F restores snapshots before/after submission and receipt commit. Preparation is paged in staging; interruption leaves the old active vault unchanged. No receipt-less old command runs automatically; receipt/digest and recoverable structured input remain intact.
- **P22 Saved close:** prepare B/L/S close revisions with increasing retained allocation and evidence counts. Measure full preparation, peak plan bytes, writer duration, WAL/rollback reserve and foreground queue delay separately. Include all trigger/history/receipt effects in admission; test the exact 100,000-effect / 16 MiB boundary and refusal above it. Kill/cancel before, during and after commit; resolve one receipt and preserve either a complete close or the open review. Snapshot failure leaves the close complete. A required tier that exceeds admission blocks support until the reviewed paged-evidence extension in EXECUTION_SAFETY 7 exists. No measured capacity is claimed.
- Use physical iOS and Android devices. Record exact model, RAM, SoC, storage capacity/free space, OS version, refresh rate, power/thermal mode and target SDK.
- Include the lowest supported OS/device class (iOS 16 and Android API 26 where supported by the pinned Flutter/native stack), a current mid-range device and a 120 Hz device. If the toolchain no longer supports the stated minimum, resolve that platform contract before the build; do not silently omit it.
- Use release builds for startup, encryption, database and memory measurements; profile builds for Flutter build/raster traces. Re-run end-to-end timings on release. Debug-mode timings do not establish performance.
- Pin Flutter/Dart, Drift, the actual linked SQLCipher/SQLite build and compiler options. Use the production cipher configuration and durability settings. Plain SQLite benchmark results cannot stand in for the encrypted app.
- Baseline latency acceptance applies to the named mid-range devices. Minimum-class devices must meet responsive-input, bounded-memory, correctness and recovery gates; publish their measured latency and resolve unacceptable results before claiming platform support.
- Network is off for every local benchmark. Market tests use fixed synthetic responses separately, so network variability cannot hide local processing cost.

## 3 Measurement boundaries

| ID | OPERATION | TIMER STARTS AND ENDS | INITIAL ACCEPTANCE TARGET |
|---|---|---|---|
| P01 | Cold app start, B | Process launch → usable Home with current small snapshot; measure authentication wait separately | p95 <1.5 s; no heavy migration/rebuild hidden in the sample |
| P02 | First transaction page, B/L | Repository request → 100 rows available for display | p95 ≤100 ms B; ≤200 ms L |
| P03 | Local search, B/L | After debounce → first 50 results | p95 ≤150 ms B; ≤300 ms L; report debounce separately |
| P04 | Ordinary Save, B/L | Save tap → source and affected small totals durably committed; then one matching shared app state available | Commit p95 ≤150 ms B/≤300 ms L; tap-to-shared-view p95 ≤200 ms B/≤500 ms L, including queue and calculation time |
| P05 | CSV import staging, B | Open already local 5,000-row file → durable private staged drafts and preview result, including decode/map/dedupe/chunk writes | p95 <3 s; no ledger confirmation included |
| P06 | Confirm import, B | Confirm 5,000 ready simple payment rows → atomic receipt, with UI progress available | Initial p95 ≤2 s, measured separately from staging; no partial ledger commit |
| P07 | Ten-year return/forecast query, B | Request with current projections → exact result including any required solver work | p95 <300 ms; measure each metric and forecast separately |
| P08 | Chart period change, B/L | User selection → matching chart and labels with current exact series ready | p95 ≤200 ms B; ≤400 ms L |
| P09 | Scroll/gesture | 60-second fixed route and gestures while import/projection work runs | 60 Hz: p95 build and raster each <8 ms, p99 each <16.7 ms; missed frames <1% |
| P10 | Cancel obsolete visible work | Cancel/new scope → old work stops consuming its allocation, or native bounded call returns | p95 ≤100 ms for cooperative Dart jobs; separately report native bound |
| P11 | Rebuild after old trade, L/S | Backdated confirmed change → valid newly published affected projections | Measure completed work and progress; no borrowed 300 ms cache target |
| P12 | Full cold rebuild, B/L/S | Delete derived data → exact regenerated summaries and selected standard series | Publish time, peak memory and rows/s; no fixed pass time until S03 baseline is measured |
| P13 | Recovery/migration | Start local snapshot/restore or schema update → verified complete generation | Publish duration, peak disk and restart results; correctness at every interruption |
| P14 | Shared metrics and fan-out, B/L/S | One relevant edit/quote/clock change → all active app consumers observe the committed shared revision | 1, 10 and 100 consumers; one calculation per key/input tuple; no incompatible current values; ≤128 keys per Q16 batch; P04 for ordinary edits |
| P15 | Key and cache growth, B/L/S | 10,000 open/close/filter cycles with a stable synthetic clock, then changed-source cycles and cache cleanup | Identical requests create no new keys; no per-render persisted values/access writes; released generations/keys reclaimable; memory and cache budgets hold |
| P16 | Retained history and asset pressure | Evict every disposable result/cache, then reconstruct selected historical analyses offline and reload logos | Authored and pinned evidence unchanged; exact results or explicit Missing; shared logo bytes counted once; no image delays a number |

P17 — Phase 1 widget framework: run 1,000 show/hide/reorder/add cycles, two placements of one metric, nested Quick look edits and all-surface reset. Include different host hero periods, feature gates, unknown keys, empty/default surfaces, descendant/async faults, lock/restore and lost replies. The preference transaction creates zero metric calculations, financial invalidations or financial rows. Measure activation separately: warm current keys reuse existing results; an uncached/stale newly requested key admits one normal coalesced calculation regardless of placement count, with no unrelated invalidation. Hidden modules hold zero work leases; surviving placements retain shared results. Count provider/animation/timer/geometry resources after disposal and verify bounded memory against the warmed baseline. Measure Done→committed layout publication separately from financial P04; initial B-fixture target p95 ≤100 ms, with queue delay reported. This is a target, not an executed phone result. Include section moves, cross-section moves, multiple removed section keys and half/full reflow at text scales 1.0, the WIDGET-HALF-REFLOW threshold and 2.0 in the cycles, plus hiding one half of a pair; verify controller/focus/lease identity, not only equal numbers. Preview workload (SY4-1): open, scroll, expand and close Add widget with cold, warm, stale and missing resident caches, on Home and on X12 (amounts hidden). Query, calculation, normal-lease, refresh, timer, file/decode and gateway counters stay unchanged by previews; a miss shows "Not loaded yet"; at most 12 observations including one expanded preview and at most two off-viewport rows. Test resident eviction/publication, hide-amount changes, lock and epoch replacement; all observers and geometry return to their bounded baseline. Include section-title/half-row/resolver failures, Delete all during editing, and restore with older/newer base versions, removed sections and renamed keys. W-A–L and the recorded product/design prerequisites must pass before Phase 1 acceptance.

P07 has three separately labelled results: existing result-cache hit, fresh requested period from maintained segments/flows, and full source rebuild. The <300 ms target applies to the first two on the specified B fixture. Do not present a previous result as current to stop the timer. The full rebuild always gets its own measurement, even if it fails the intended user experience.

For 120 Hz, measure the 8.3 ms frame deadline explicitly. Initial target: p95 build and raster each <4 ms, p99 each <8.3 ms, missed frames <1% on the selected 120 Hz device. A 60 Hz trace does not establish 120 Hz performance. Reduce motion and text scale 2.0 each get a separate run.

Confirm admission is at most 5,000 selected source rows, 100,000 logical row effects and 16 MiB encoded plan. Reject any excess before mutation; retain the selection and require a smaller user-selected set, never auto-split. Include generated registry/history/search/operational row work and reserve internal index growth. P06 applies to simple ready payment rows; linked trades, payslips and lot reconciliation need their own confirmation workloads. Source matching, expensive validation and durable staging cannot be excluded from every timer. Show the user-visible end-to-end time in addition to stage timings.

## 4 Memory storage and query checks

| AREA | INITIAL BUDGET/CHECK |
|---|---|
| Dart result/geometry cache | 32 MiB shared LRU; no per-screen unbounded caches |
| List objects | ≤500 retained rows per active list; inactive providers dispose their pages |
| Parser bridge | ≤2 chunks, each ≤500 rows or 1 MiB |
| Ordinary derived patch | ≤512 row effects / 256 KiB across the complete affected metric closure, including dependency/evidence/pointer rows; larger work follows SHARED_STATE 3 |
| Cleanup slice | ≤32 candidates or 20 ms measured statement work, then yield; indexed reverse references, explicit native statement/fanout bounds |
| Queued commands | ≤32 or 8 MiB of arguments; large jobs carry staged identifiers |
| Peak process memory | Engineering target ≤256 MiB in B/L ordinary use; ≤384 MiB during one bounded native decode/import; report platform memory metric, not just Dart heap |
| Steady memory | A repeated route/import cycle returns within 10% of its warmed baseline after eviction/GC; no growth proportional to total history |
| SQLite cache | Start at a measured 16–32 MiB page-cache budget for the active connection; any added reader has an explicit extra budget |
| WAL | Observe normal checkpoints; initial soft threshold 32 MiB after a completed write. Pause background ingestion and release expired read snapshots if it cannot drain |
| Disk | Report source tables, indexes, ChangeLog, FTS, quotes, projections, staging, attachments and snapshots separately |
| Free-space reserve | Before copy operations reserve estimated output + journal/WAL headroom + max(64 MiB, 10% of planned new bytes); validate with actual device tests |

An admitted Confirm has an initial 10-second execution deadline and operation-scoped native cancellation on lock/background/cancel. Cooperative signal delivery targets 100 ms; blocked native I/O and rollback must resolve before vault-closed success or another command. Report foreground read/save queue latency during the exclusive Confirm separately from idle P02/P04. Test no late interrupt reaches the next operation.

The WAL threshold is a scheduling trigger, not a promise that a single large atomic transaction never exceeds 32 MiB. Never truncate required WAL pages or interrupt durability to enforce a cosmetic limit. A long Confirm must have adequate disk reservation before it begins.

Run EXPLAIN QUERY PLAN for each hot query at all tiers. Check index use and row counts, including mixed account scope, split categories, descending pagination and pending Inbox. Search/date-filtered pages must not scan the full transaction table. Bound sort work and result columns. A broad report may require scanning relevant records, but it runs as a cancellable worker job with progress.

## 5 Correctness under concurrent work

1. Edit an expense while its monthly aggregate is calculating. The old generation must fail publication; the next complete generation includes the edit once.
2. Change a historical trade while lot/gain/return jobs run. Invalidate affected future checkpoints; preserve unaffected earlier results.
3. Update a quote used by both portfolio and chart. Render compatible input versions or mark a prior snapshot updating; never a silent mixed current result.
4. Restore while a worker result is pending. The changed database epoch rejects that result and all old cursors.
5. Repeat the same Confirm after killing the app immediately after commit. The operation receipt returns one result with no second posting.
6. Cancel an import while a staging chunk is in flight. Staging cleanup respects the job state; no actual record appears.
7. Undo a dividend reinvestment with a later sale. Open dependency resolution; do not blindly restore old lots.
8. Rebuild all projections and compare them with incrementally maintained results using exact values, availability, coverage and source references.
9. Reduce a dense chart with gaps and many mandatory events. The exact table and metrics remain identical; switch representation explicitly when the point cap cannot preserve meaning.
10. Change main currency, refund basis or cost method. Cache keys and dependencies prevent a result computed with old settings from masquerading as current.

## 6 Failure and privacy matrix

| TEST | REQUIRED RESULT |
|---|---|
| No/wrong database key; missing cipher in release binary | Fail closed, preserve files, no plaintext creation or reset |
| Disk full during draft, Confirm, attachment publication or projection write | Active confirmed data remains valid; receipt determines commit outcome |
| Kill before/after every generation-pointer transition | Exactly one complete database/attachment generation selected on restart |
| Corrupt/missing retained attachment | Typed local state; no silent success or network repair |
| Oversized/decompression-bomb/macro/remote-reference input | Reject within bounds; no outside fetch or partial financial commit |
| Microphone/camera lock or denial | Stop capture, clear transient content, retain supported structured draft |
| Remote models/telemetry/native SDK traffic | Fail the dependency or release gate |
| Network off across every F01–F21 flow | Zero app-initiated network traffic |
| Market gateway enabled | Only allowlisted hosts/methods/fields; no synthetic canary values, merchant names, file text or private IDs |
| Redirect, malformed details URL, late response after disable | No redirected request; no active content; epoch rejects late persistence |
| OS backup and device transfer | Report observed inclusion and key accessibility separately. Any private ciphertext transfer fails the strict policy. A passing observation does not close PF-01 or prove universal OS exclusion |
| Recovery and delete-all | Snapshot remains on phone; no share route. Revoke/drain native extension leases before cleanup; paused old-epoch writers cannot recreate files/keys after Welcome. Interrupted deleting state resumes cleanup |

Use synthetic canaries only. Verify request serializers against controlled provider fixtures and instrumented test transports; inspect device traffic for native/network bypasses. Encrypted TLS captures alone do not prove which fields were sent. Combine serializer tests, controlled endpoint observation and native endpoint/connection tracing. Keep any test instrumentation out of production logging.

## 7 Run protocol and result record

- Seed and validate exact expected totals before timing. Record file/database sizes and indexes.
- Use at least 30 runs for ordinary operations, report median/p95 and maximum. For frame p99 use the long frame trace, not 30 events. For expensive recovery/rebuild tests report every run and at least three repetitions; do not claim a p95 from three samples.
- Separate cold process/connection, cold result cache and warm cache. State that OS page-cache eviction is not guaranteed merely by killing the app.
- Test foreground alone, foreground during import, rapid period changes, low storage, memory pressure and thermal throttling. Do not discard inconvenient runs without a stated test fault.
- Measure CPU time, wall time, Dart heap, native/process memory, database I/O/WAL, frame timings, energy/thermal state and output correctness.
- Baseline devices and immutable benchmark result files are named when available; none are invented in this design.

```
Benchmark ID and dataset seed:
App commit / schema / calculation version:
Device / OS / RAM / storage / refresh rate:
Flutter / Drift / SQLCipher build and flags:
Build mode / power and thermal state:
Cache and authentication conditions:
Operation boundary and repetitions:
Median / p95 / maximum / failure count:
Peak process memory / heap / WAL / disk change:
Frame and cancellation results:
Exact fixture comparison:
Privacy observations:
Result: pass, fail, or not measured
```

Additional review acceptance cases:

- Reject over-limit Confirm before mutation; cancel before/during/between SQL statements and at commit; resolve zero or all effects and a single receipt. Test lock, disk-full, process death and late interrupt reuse.
- Render two exact series with equal endpoints/extrema values but different extrema times; their bucket references and crosshair values must differ. Retain old generation through a source edit; table/chart keep the old exact revision until replacement publishes. Reject known buckets that bridge Missing points.
- Rebuild automatic lot allocations/gains/checkpoints after a backdated acquisition. Compare incremental and independent full rebuild; source facts and saved close copies remain unchanged. Dependent Undo cannot treat an evicted cache as no later disposal.
- Reconcile monthly 31st→30th, monthly→weekly, a moved paid occurrence, retry and interrupted generation. Stable identities/aliases retain one unpaid remainder; ambiguous mappings do not commit.
- Pause native capture before first write and before publication; delete all, crash/restart, then resume old capability. No old file/key/draft or callback reaches the new epoch. Time expiry alone cannot release a live writer lease.
- Snapshot while parsing, later delete temporary source, restore: retain completed staged rows and show sourceNeeded; no automatic resume. Same file/config restart cannot duplicate rows; mismatched parser/config enters its factual state.
- PF-01 is a platform capability gate, not a performance test. Apple does not promise universal exclusion. No real-user iOS persistence/release under the absolute policy before a compliant path or explicit policy revision; do not use purgeable storage to bypass the gate.

S01–S07 in the system design produce this evidence. A failed target triggers a query/index/profile investigation, smaller bounded work or a reviewed implementation change. It does not justify lossy financial math, skipped durability, unbounded memory or remote processing.
