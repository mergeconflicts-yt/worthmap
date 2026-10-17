# Database query contracts

Version 1.2 · 15 October 2026 · DB-002 · Architecture for implementation.

This document defines bounded local reads for DATABASE_DESIGN and the reference schema. It supports SYSTEM_DESIGN sections 5–9 and the performance plan. SPEC owns financial meaning. A query must not invent a rule that is still behind a usage-flow correction gate.

The examples use the reference schema's names. All values are bound parameters. They are read contracts, not production Drift code. Successful reference checks establish schema/query compatibility only. They do not establish encrypted database speed, device capacity, cancellation latency or financial formula correctness.

## 1 Physical keys and index policy

| RECORD CLASS | SELECTED PHYSICAL KEY | REASON AND LIMIT |
|---|---|---|
| Authored records | UUID v7 TEXT NOT NULL public identity; ordinary SQLite rowid table initially | Keeps the SPEC identity contract. Secondary indexes can use a compact internal rowid. The UUID is a stable tie-breaker, not evidence of financial event order. |
| Public instruments and market series | Local INTEGER PRIMARY KEY | Avoid repeating long symbols/provider strings in millions of price rows. A series fixes instrument, provider, basis, interval and currency. |
| Immutable quote observations | INTEGER PRIMARY KEY; unique (series_id, date, revision) | A saved result can reference one exact observation. Provider corrections append a revision. |
| Current quote selection | Composite (series_id, date) | Direct range and predecessor lookup without grouping all historical revisions. |
| Search document | Local INTEGER PRIMARY KEY, mapped to one authored entity | FTS5 needs an integer document key. It is not an external or user-visible identifier. |
| Dependency and projection metadata | Integer keys and compact composite keys | Keep cache keys and source versions explicit without copying a whole account set into every row. |
| Small composite technical tables | WITHOUT ROWID only where the reference schema selects it | Useful for narrow natural keys. Do not apply it to all authored tables or large payload rows. |

A UUID text key in a WITHOUT ROWID table also appears in secondary-index keys. That tradeoff can increase the cost of a table with many secondary indexes. Measure both layouts before changing the selected authored layout. Compact composite tables can benefit from WITHOUT ROWID; this is an optimisation, not a financial rule. SQLite table layout

Use equality columns first, then the range/order columns. Keep only indexes that serve a named query or an integrity constraint. Do not put merchant text, notes or large JSON in covering indexes. A wider covering index is accepted only with measured read benefit, storage cost and write cost. Index-prefix reuse and the order of composite columns matter. SQLite query planning

The initial query families need live transaction indexes for date, account/date, kind/date and account/kind/date; exact source identity; candidate digest; candidate account/currency/amount/date; category contributions; pending Inbox; current quote series/date; and generation-local buckets. Partial live indexes require the query to include deleted_at IS NULL. Tombstones stay in authoritative storage but do not occupy the ordinary live browsing path.

Keep the foundation in one encrypted vault. Do not create a database per account, currency or year: that would make cross-scope reads, atomic event groups and recovery more complex. Compact public/technical keys and sparse projections address volume within this layout.

No index is added merely because a field exists. Foreign-key lookup indexes also serve bounded delete/Undo dependency checks. Their prefix can be shared with a query index where this produces the same access path.

## 2 Read envelope and pagination

Every repository read accepts a typed scope, date range, page/result budget and cancellation token. It returns exact values, coverage, input revision metadata and a cursor when applicable. It does not return an entire entity graph.

A list cursor contains:

```text
queryVersion, dbEpoch, canonicalFilterHash, dependencyVersions,
orderKind, lastDate, lastId
```

Technical series cursors substitute their documented key for lastDate/lastId. Dates are validated ISO local dates. All date ranges use [start, endExclusive) unless an explicit inclusive cutoff is named. Cursor content stays in local memory or encrypted navigation state. It never enters logs or a network request.

- Normal lists use 100 displayed rows per page and retain at most five pages. SQL usually reads 101 rows to establish whether another page exists.
- Search uses 50 displayed rows and 150 ms debounce. A superseding request cancels the prior request and rejects its late output.
- A first page has a separate SQL variant with no cursor clause. Do not write optional predicates such as :account IS NULL OR account_id = :account into every query.
- Deep pages use a strict tuple comparison, not OFFSET. A relevant edit, restore, filter change or order change invalidates the cursor. Refresh around the previous visible row; do not append pages from different revisions.
- A stable revision must produce every matching row once. A record that changes date between requests cannot be treated as if the old cursor were still valid.
- Read dependency revisions before and after each bounded extraction. Retry or return Updating if they changed. Do not keep a SQLite read transaction open for the time that a user scrolls.

SQLite describes tuple comparison for keyset scrolling. LIMIT bounds returned rows; it does not by itself bound scanned rows or sorting work. SQLite row values

### Q01 Account payments

```sql
-- Q01: account page after a cursor; bind limit=101 at most.
SELECT id, date, amount_minor, currency, merchant_name, category_id, kind
FROM transactions
WHERE account_id = :account_id
  AND deleted_at IS NULL
  AND date >= :start_date AND date < :end_date
  AND (date, id) < (:last_date, :last_id)
ORDER BY date DESC, id DESC
LIMIT :limit;
```

Use the account/date live index. The range and ordered page must not require a temporary sort or a scan across unrelated accounts. The first page removes only the tuple predicate. The all-account variant removes account_id and uses the date live index. A fixed kind variant uses the matching kind/date or account/kind/date index.

### Q02 Selected accounts and combined filters

For a small selected account set, get each account's bounded Q01 candidate page and merge by (date DESC, id DESC). For a large selected set, process accounts in bounded slices, retaining only the best 101 keys seen so far. Fetch full display columns only for the final page. This costs work proportional to the selected scopes and page size, not the total ledger. It must remain cancellable. Report its latency separately from a single-account page.

Do not assume WHERE account_id IN (...) ORDER BY date streams directly from an account-first index. A temporary sort can cover a large result. An alternative combined SQL plan needs measured evidence that intermediate rows remain bounded.

Filters on category, tag, amount, reimbursement status and merchant are named query variants. Start from the most selective supported indexed candidate stream, then test residual predicates. Fetch candidate chunks of at most 500 keys; yield after each chunk and keep only bounded results. When an uncommon combination needs many chunks, expose a cancellable local search state. Do not label an incomplete result as complete, freeze the database owner with a long statement, or silently ignore a filter. A new index is justified by a measured common query, not by every possible filter combination.

The SQLite/native binding must prove statement cancellation or an instruction-budget interrupt before enabling query variants with potentially large native work. Dart task cancellation alone does not stop a running native SQLite statement.

For candidate matching, start with at most 101 extracted rows per SQL statement and a 10 ms worker quantum between statements. Instrument SQLite progress at an initial interval of 1,000 VM instructions, with an initial 100,000-instruction or 20 ms statement work budget. These are tunable admission/cancellation settings that need device proof; callback timing does not guarantee interruption during every filesystem/native call. A budget failure returns an incomplete, resumable/cancellable candidate-search state, not a negative match. Resume after the last completely processed page; reduce the next chunk if needed. An interrupted page is retried from its prior cursor and never skipped. Repeated budget failure remains unresolved and can use explicit user matching. Install and remove the per-statement handler through the owner so it cannot interrupt a different queued command. The callback cannot read from or modify the same connection. Drain interrupted statements and remove the handler before the next queued command. No confirmed write is partly committed to meet this read budget. SQLite progress callbacks, interrupt lifecycle

## 3 Exact category totals and split payments

The parent transactions row remains the cash/account posting. Category attribution comes from its live splits when any exist; otherwise it comes from the parent category. Never join both and sum the parent amount again.

category_postings is a rebuildable, generation-scoped read model. It records the source transaction, source part identity, account, category, recognition date, currency, exact signed contribution and financial method version. A null category stays uncategorised. The builder applies the SPEC rules for refunds, reimbursable amounts, fees and income. It does not infer a formula from kind alone. Gates G13 / G14 apply to unresolved fee/refund attribution.

For a payment with two splits in the same category, both contribute to the total but the payment list shows one parent. Stream adjacent contribution rows, add them with checked integer/BigInt arithmetic and emit the parent only after the last part. A chunk that ends inside a parent retains only that parent's accumulator and continuation key. Do not use a whole-table DISTINCT to hide multiplication from an incorrect join.

Daily/monthly category buckets store exact per-currency totals and coverage. Month summaries read those buckets, not all source payments. A category edit invalidates the old and new category/date partitions. A refund recognition-date change invalidates both old and new dates. An unsplit-to-split edit replaces the full contribution set atomically or publishes a complete replacement generation; it never adds splits on top of a retained parent contribution.

SQL financial arithmetic is restricted to proven bounded integer operations. An integer SUM can overflow; total() and floating AVG cannot repair this. Prefer streaming source/bucket integers into a BigInt/Decimal accumulator and range-check the result before storing an INTEGER. No CAST(... AS REAL), decimal-text multiplication, SQL price-times-quantity, or summation across currencies. SQLite aggregate behaviour

A known empty, fully covered period can produce exact zero. An absent or incomplete input set carries Missing/partial coverage. COALESCE(SUM(...), 0) is not a coverage rule.

## 4 Source identity and candidate matching

### Q03 Exact source identity

```sql
-- Q03: all identity components are non-null and have a versioned namespace.
SELECT id, namespace, account_scope, source_record_id, identity_version
FROM source_identities
WHERE namespace = :namespace
  AND account_scope = :account_scope
  AND source_record_id = :source_record_id;
```

The unique source-identity key proves whether this same source row has already been handled. Resolve its disposition through source_claims and its typed source_event_links; these remain local indexed lookups. A soft-deleted or undone target does not release this identity. Re-import does not silently resurrect it.

A file-row identity includes a stable source-file identity and row ordinal in the original source, not the index of filtered or sorted parser output. Parser/template upgrades do not change that identity namespace. An identity-codec upgrade needs a migration or alias map that still recognises older source identities and tombstones. Identical payment text, amount and date can describe two actual payments. A candidate content digest is therefore an ordinary indexed lookup, never a uniqueness constraint on the ledger.

### Q04 Content candidates

```sql
-- Q04: digest matches are candidates, not automatic duplicate proof.
SELECT t.id, t.account_id, t.date, t.amount_minor, t.currency, t.kind, t.deleted_at
FROM transaction_candidate_keys AS k
JOIN transactions AS t ON t.id = k.transaction_id
WHERE k.content_digest = :content_digest
  AND k.transaction_id > :last_transaction_id
ORDER BY k.transaction_id
LIMIT :limit;
```

Q04 extracts at most 101 candidate keys and their one-to-one transaction rows, including tombstones. The resolver rejects deleted rows after extraction. Advance the candidate cursor over every examined key, including rejected rows. A SQL liveness predicate before LIMIT could otherwise scan an arbitrarily long run of tombstones to produce a small result. If there are more candidates, page the candidate list or leave the Inbox choice unresolved. Do not decide that a row is unique because only the first candidate page was inspected.

### Q05 Same-currency transfer candidates

```sql
-- Q05: one candidate account, exact opposite amount and inclusive 5-day window.
SELECT t.id, t.account_id, t.date, t.amount_minor, t.currency,
  EXISTS (
    SELECT 1 FROM transfer_links AS l
    WHERE l.sending_transaction_id = t.id AND l.deleted_at IS NULL
  ) AS has_sending_link,
  EXISTS (
    SELECT 1 FROM transfer_links AS l
    WHERE l.receiving_transaction_id = t.id AND l.deleted_at IS NULL
  ) AS has_receiving_link,
  EXISTS (
    SELECT 1 FROM transfer_links AS l
    WHERE l.fee_transaction_id = t.id AND l.deleted_at IS NULL
  ) AS has_fee_link
FROM transactions AS t
WHERE t.account_id = :other_account_id
  AND t.currency = :currency
  AND t.amount_minor = :opposite_minor
  AND t.date >= :window_start AND t.date <= :window_end
  AND t.deleted_at IS NULL
  AND (t.date, t.id) > (:last_date, :last_id)
ORDER BY t.date, t.id
LIMIT :limit;
```

Q05 extracts at most 101 live candidates from the partial live index. Each projected link check uses one unique principal/fee key. The resolver rejects already linked candidates after this bounded read, then advances (last_date, last_id) over all examined candidates. Keeping these exclusions in a WHERE anti-join before LIMIT could scan a large run of linked rows. Do not mistake a full rejected page for an empty candidate window. Derive candidate accounts locally. Use the account/currency/amount/date live index. Opposite-sign conversion is checked in the domain layer; negating the most negative 64-bit value must not overflow. For cross-currency candidates, query only the supported date/account window, then apply the permitted documented FX/tolerance rule with Decimal in the worker. Currency differences or a missing local FX observation cannot establish a match. Candidate work is paged and cancellable; ambiguous results stay in the Inbox.

For broker rows, the stable source identity is checked before event-graph matching. A position screenshot is a position observation; no dedupe query can turn it into a fabricated trade.

## 5 Local full-text search

search_documents maps one integer document ID to a transaction or account. search_fts is an external-content FTS5 index over permitted parsed fields. Merchant, note and account-name fields stay in the encrypted vault. Raw statements, transcripts, attachment bytes and credentials never enter this index.

The command writer updates the document and its FTS rows in the same transaction as the authored change. A deletion removes the searchable document. Account-name searches can return the account document without copying the name into every payment; if a payment document also contains a denormalised name, rename fan-out must be versioned and bounded before the new search revision publishes.

FTS5 external-content tables need explicit maintenance and initial population. Test insert, edit, delete, rollback and rebuild against their content table. SQLite FTS5 external content

### Q06 Search page

Extract at most 51 rows: 50 displayed results and one look-ahead sentinel. The sentinel only establishes a next page and is not displayed. Search keeps its own bound; it does not inherit the ordinary 101-row extraction limit.

```sql
-- Q06: stable local document order, not a financial or date order.
SELECT d.id, d.transaction_id, d.account_id, d.merchant, d.note, d.account_name
FROM search_fts
JOIN search_documents AS d ON d.id = search_fts.rowid
WHERE search_fts MATCH :match_expression
  AND search_fts.rowid > :last_document_id
ORDER BY search_fts.rowid
LIMIT :limit;
```

Bind an application-built FTS expression, not raw user syntax. Start with at most 256 Unicode characters and eight terms; escape each literal term and support only the documented phrase/prefix grammar. These are parser admission limits, not advice. The interface states a factual unsupported-query state when needed. Test punctuation, diacritics, emoji, mixed scripts and CJK tokenisation with the pinned tokenizer. Do not assume unicode61 provides meaningful word segmentation for every language.

The simple reference page uses document order to make pagination exact and avoid a global relevance sort. Search presentation can use a different documented order only after its query plan, cursor and work budget are tested. Date/account-filtered search and ranked top results are separate query variants; adding a SQL LIMIT does not prove that FTS examined only that many postings.

A tiny populated FTS fixture can make the planner start from search_documents and sort its small result. That can be valid bounded work; do not force join order solely to eliminate a one-row sort. At representative corpus sizes, verify a MATCH-driven plan or another demonstrably bounded path with no large temporary sort. An FTS virtual-table SCAN in an explain plan is not automatically a full ledger scan. Verify the MATCH constraint and document-ID range, measure native work and test common/rare/absent terms. A plain transaction-table scan or a %term% scan is not the default search path. A query that cannot finish within its instruction/time budget returns a cancellable search state; it cannot claim there are no matches.

Watch compact, scoped read models. Drift streams can rerun after table changes; do not watch an unrestricted source-table query from every chart. A writer-issued projection/scope invalidation avoids reloading all rows after an unrelated update. Drift query streams

## 6 Public quotes and manual observations

public_instruments contains public provider identity only. Local securities link to it; account IDs, holdings and quantities never become fields in a provider request. A market_series fixes public instrument, provider, currency, interval and adjustment basis. Quotes with different bases cannot be spliced into one return series without an explicit method.

Each downloaded observation in price_quotes is immutable and has exact decimal text. A provider correction inserts the next local revision and advances current_quotes. Equal content from a repeated fetch reuses the existing observation. A revision is a local content version, not a claim that the provider supplied a revision number. The command writer updates the current pointer, quote dependency revision and affected dirty range atomically.

### Q07 Latest or prior daily-close public quote

```sql
-- Q07: predecessor in one explicit series; one exact immutable observation.
SELECT q.id, q.date, q.revision, q.price_decimal, q.observed_at, q.fetched_at
FROM current_quotes AS c
JOIN price_quotes AS q ON q.id = c.quote_id
WHERE c.series_id = :series_id
  AND c.date <= :cutoff_date
ORDER BY c.date DESC
LIMIT 1;
```

Q07/Q08 apply to daily-close series. A latest/intraday series also needs its actual observation UTC instant and an appropriate instant cutoff; fetched_at is not the market observation time. Do not use the daily query to answer a historical intraday valuation.

A missing row is Missing. A null observation instant means unknown observation time; fetch time cannot repair it. Caller tests must include a newly fetched daily quote with no observation instant and assert unknown freshness rather than Fresh. A predecessor quote carries its observed date and freshness/basis state. Current market-price rules and FX carry-forward rules are separate; do not apply the FX rule to every quote by inference. Show the applicable stale/estimated state specified by the metric.

### Q08 Daily-close public history page

```sql
-- Q08: ascending history page from the selected current series.
SELECT q.id, q.date, q.revision, q.price_decimal, q.observed_at, q.fetched_at
FROM current_quotes AS c
JOIN price_quotes AS q ON q.id = c.quote_id
WHERE c.series_id = :series_id
  AND c.date >= :start_date AND c.date < :end_date
  AND c.date > :last_date
ORDER BY c.date
LIMIT :limit;
```

Use the composite current-quote key plus observation primary-key lookups. Do not GROUP BY date or compute MAX(revision) across millions of quotes on every chart request. A saved close/history result uses its pinned price_quotes.id references instead of Q07/Q08, so later corrections cannot change its evidence.

Manual quotes are authored records with UUID, revision, ChangeLog and Undo. They do not overwrite downloaded observations. A price resolver reads the applicable manual observation and the public-series candidate separately, then applies the explicit metric/source-selection policy. The result stores the chosen source ID, date and revision. Ambiguous source precedence remains a visible selection/gated product rule; SQL must not choose an arbitrary row by insertion time. Manual FX stays local and follows the same exact observation discipline.

The catalogue and cached price tables remain in the encrypted vault even though the input itself is public. This prevents a separate unprotected file from revealing the user's selected symbols or lookup history.

## 7 Projections and chart reads

### Key and input contract

A projection key includes kind, canonical scope, requested dates, explicit asOf, currency, method/basis, relevant settings and algorithm version. projection_generations holds one staged output set. projection_inputs records the exact dependency revision for every input scope. current_projections publishes one complete generation for that key.

A hash is an index aid, not identity proof: retain or verify the canonical descriptor before reusing a colliding key. Keys omit irrelevant settings but cannot omit refund recognition, cost method, reporting currency, calendar convention or selected account scope when they change the result.

For millions of source rows, never create a dense account x security x day table. Maintain sparse change points, requested standard ranges and recently used custom ranges. A chart receives preselected resolution buckets from its one generation; it does not fetch the full exact history and discard most points in the UI.

### Q09 Current projection generation

```sql
-- Q09: a pointer is current only when all stored input versions still match.
SELECT g.id, g.computed_at, g.coverage_json, g.source_commit_sequence
FROM current_projections AS c
JOIN projection_generations AS g ON g.id = c.generation_id
WHERE c.key_id = :key_id
  AND g.db_epoch = :db_epoch
  AND g.status = 'published'
  AND NOT EXISTS (
    SELECT 1
    FROM projection_inputs AS i
    LEFT JOIN dependency_revisions AS d ON d.scope_id = i.scope_id
    WHERE i.generation_id = g.id
      AND (d.scope_id IS NULL OR i.input_revision <> d.revision)
  );
```

The writer proves that the generation contains the complete required dependency set before publication. An empty or incomplete set cannot prove freshness. A missing current dependency-revision row is stale, not a matching revision. A missing result from Q09 starts or joins a rebuild and can show the prior complete generation as Updating. The repository also checks the key's explicit clock/as-of boundary; matching database revisions alone do not make a yesterday result current today.

### Q10 Exact summary bucket page

```sql
-- Q10: one validated generation and bucket; no source-history aggregation.
SELECT group_key, currency, amount_minor, value_state, known_count, missing_count
FROM summary_buckets
WHERE generation_id = :generation_id
  AND bucket_key = :bucket_key
  AND (group_key, currency) > (:last_group_key, :last_currency)
ORDER BY group_key, currency
LIMIT :limit;
```

The composite primary key supplies the ordered page. The complete generation defines whether all expected groups exist. The value state and missing count are part of the result; a partial sum does not become a complete total because it has an amount.

### Q11 Category contribution page

```sql
-- Q11: keyset cursor includes source part; bind at most 500 contributions.
SELECT transaction_id, part_key, date, account_id, amount_minor, currency, kind
FROM category_postings
WHERE generation_id = :generation_id
  AND category_id = :category_id
  AND date >= :start_date AND date < :end_date
  AND (date, transaction_id, part_key) < (:last_date, :last_transaction_id, :last_part_key)
ORDER BY date DESC, transaction_id DESC, part_key DESC
LIMIT :limit;
```

Use a separate category_id IS NULL variant for uncategorised records. Coalesce adjacent parts by transaction in the exact worker when displaying a payment list. The last fully consumed contribution key advances the cursor. A display page cannot split the same parent payment between two pages.

### Q12 Chart bucket page

```sql
-- Q12: resolution is selected before reading; no full-series UI transfer.
SELECT bucket_index, first_date, last_date, value_kind, currency,
  first_minor, low_minor, high_minor, last_minor,
  first_decimal, low_decimal, high_decimal, last_decimal, source_count,
  first_point_ordinal, low_point_ordinal, high_point_ordinal, last_point_ordinal,
  representation
FROM chart_buckets
WHERE generation_id = :generation_id
  AND level = :level
  AND bucket_index >= :first_bucket AND bucket_index <= :last_bucket
  AND bucket_index > :last_seen_bucket
ORDER BY bucket_index
LIMIT :limit;
```

The foundation stores one series per generation. A multi-series chart carries compatible generation IDs. The composite primary key serves the selected level and bucket window. Read at most 500 buckets per extraction chunk; the total visible geometry still obeys the point limit. The four ordinals reference exact points in this generation; extrema retain their actual dates, order and optional event instant. Render these points in time order, not always low then high. Equal extrema use the earliest qualifying ordinal. Gap buckets have Missing values and explicit gap points; a known bucket cannot span an interior gap. If required steps exceed the geometry cap, show a labelled envelope and keep the exact table available.

### Q13 Pending Inbox page

```sql
-- Q13: extract <=101 candidates before visibility checks; repository-only rows.
WITH candidates AS MATERIALIZED (
  SELECT id, source_identity_id, staged_row_id, received_at, suggestion_type, edit_revision
  FROM inbox_items
  WHERE decision = 'pending'
    AND (received_at, id) > (:last_received_at, :last_id)
  ORDER BY received_at, id
  LIMIT :limit
)
SELECT p.id, p.source_identity_id, p.received_at, p.suggestion_type, p.edit_revision,
  CASE WHEN c.status='staged' AND
    ((c.draft_id IS NOT NULL AND p.staged_row_id IS NULL) OR
    (c.batch_id IS NOT NULL AND b.inbox_published=1 AND b.status='review'
    AND (p.staged_row_id IS NULL OR
      (s.batch_id=c.batch_id AND s.source_identity_id=p.source_identity_id))))
    THEN 1 ELSE 0 END AS visible,
  d.inbox_revision
FROM candidates p
LEFT JOIN source_claims c ON c.source_identity_id=p.source_identity_id
LEFT JOIN staged_rows s ON s.id=p.staged_row_id
LEFT JOIN import_batches b ON b.id=c.batch_id
CROSS JOIN db_state d
ORDER BY p.received_at,p.id;
```

The repository admits at most 101 candidates per extraction and passes at most 100 eligible rows to a display page. Advance the cursor only over consumed candidates: a returned visible row or a rejected private row. If the display page is full, an unreturned visible look-ahead row is not consumed; keep the cursor before it so the next page rereads it. Never advance to candidate 101 after returning only the first 100. A sparse page is a continuation, never proof of an empty Inbox; yield/cancel between bounded extractions. Cursors include (db_epoch, inbox_revision) and restart after publication, withdrawal or a pending-membership change. Otherwise a cursor can skip newly published older rows. No private candidate identifiers or payloads leave the repository. Payload reads and Confirm recheck eligibility in the owner transaction. Direct draft claims require the separately authorised capture/manual path. File imports require explicit Send to Inbox; see EXECUTION_SAFETY 2.

Source-filtered Inbox is a separate bounded variant with measured source-identity joins; it cannot load every pending JSON payload to filter on the UI thread. Opening/reading this list does not confirm anything. The SQL result includes internal visibility metadata, not a display page. Sorting this materialised <=101-row candidate set is bounded.

### Q14 Exact series table page

```sql
-- Q14: read the exact result retained with the chart generation.
SELECT point_ordinal, date, same_day_order, effective_at, point_role,
  value_kind, value_state, amount_minor, value_decimal, currency, coverage_json
FROM exact_series_points
WHERE generation_id = :generation_id AND point_ordinal > :last_point_ordinal
ORDER BY point_ordinal
LIMIT :limit;
```

The exact series is sparse: retain every required observation, step and coverage boundary, with explicit gap points. A point ordinal is generation-local. It is not evidence for the economic order of source transactions. Page size is at most 100 visible rows plus one sentinel. The UI cannot read mutable current ledger values to fill an old table. A computation rerun uses the generation's complete ChangeLog after-image references, quote/detail pins, frozen operational proposal snapshots and versioned method/settings, with the same output order. projection_occurrence_inputs retains exact proposal values plus the schedule and selected-decision history references; it never substitutes current proposal rows or current selection pointers.

### Q15 Exact crosshair point

```sql
-- Q15: resolve a bucket point or a table row by the same exact generation key.
SELECT point_ordinal, date, same_day_order, effective_at, point_role,
  value_kind, value_state, amount_minor, value_decimal, currency, coverage_json
FROM exact_series_points
WHERE generation_id = :generation_id AND point_ordinal = :point_ordinal;
```

A missing key returns no point; it is never replaced by zero or a point from another generation. Hold the generation reader lease for chart, crosshair and table reads. Navigation by date uses the unique (generation_id, date, same_day_order) index in a separate bounded lookup. Interpolation is presentation geometry only; the tooltip identifies the retained observation.

### Publication and dirty ranges

1. Read dbEpoch, relevant dependency revisions and the time/calendar contract.
2. Extract indexed source pages. Check the same dependencies after extraction. Discard/retry if they changed.
3. Calculate exact output in resumable worker slices. Write bounded pages into a staging generation.
4. Drain accepted staging writes and freeze all output, dependencies and pins under an owner-controlled staging version. Validate complete input closure, exact-series ordering/coverage and every bucket in bounded worker/read pages. Release read snapshots between pages. The owner retains a validation certificate for this frozen attempt; any further staging or attempt change destroys it.
5. In a short writer transaction, validate the certificate and recheck its bounded dependency set, epoch, method/settings and clock boundary. Atomically publish the complete admitted pointer group with its already-staged immutable-input pins. No output/history/pin scan occurs here. Otherwise keep the prior pointer and schedule current work. EXECUTION_SAFETY 1 defines certificate identity, admission limits and invalidation.
6. Acknowledge only dirty dates and required versions covered by the new result. Preserve uncovered dates and newer invalidations. Delete abandoned staging later.

dirty_ranges coalesces overlapping intervals for the same scope and projection kind. The reference schema uses one conservative envelope per scope/kind. Partial publication leaves that envelope dirty. Clear it only when the generation covers the entire current envelope and its required revision still matches. Splitting/narrowing intervals requires a later interval-storage migration and separate coverage tests. required_revision advances monotonically. A short visible-period job cannot clear an earlier historical range. A backdated trade invalidates all later affected position/lot checkpoints; a payment category edit invalidates both old and new category/date buckets. A quote correction invalidates only dependent price periods and current summaries. Maintain dependency-to-projection lookup metadata or resolve affected registered scopes in a bounded worker; do not scan every cached payload.

Time is an input even when no row changes. Local midnight/month boundaries, foreground resume, timezone/calendar changes, next-income/due boundaries and quote freshness boundaries invalidate the corresponding current views. Use the injected clock and the next relevant boundary. Do not rewrite the full historical chart each second.

A read model can expose a previous complete result with its date and Updating state. It cannot call that result current after an input change. Cards, chart and exact table must reference compatible generations. A pending job from an earlier dbEpoch can never publish after restore. Every staging/progress/completion write also verifies the current job UUID and lease nonce in the writer transaction (SHARED_STATE 2). Cancel/restart revokes the attempt even if a replacement reuses the generation ID.

Outputs and input pins accept inserts only while staging. Published or obsolete generations cannot be unsealed, rewritten or partially pruned. Retire a published generation, release its current pointer and all reader leases, then delete that whole generation; child rows cascade together. A retained close has its own immutable exact outputs and input references, including copied lot allocations, so cache deletion cannot change its evidence.

### Chart and exact table contract

- Select a resolution with at most min(2 x logicalWidth, 1200) drawing points per series, up to four visible series. Select resolution before reading bucket rows.
- Return exact bucket endpoints/minima/maxima and coverage markers. Reduce geometry in the worker; convert bounded drawing coordinates only in the design chart layer.
- A bucket key includes generation and resolution; the foundation generation fixes the series. Range scans are indexed; crosshair queries resolve one exact point or explicitly labelled bucket by key.
- Exact table pages use generation plus stable time/sequence keys. They do not recompute a different financial series.
- Gaps remain gaps. If mandatory steps/events exceed the drawing budget, select an explicitly coarser representation or table.
- XIRR/TWR calculations read exact flows and valuation evidence. Reduced chart rows never become solver input.
- Retain an old generation while a visible reader owns it. A read handle has an explicit release/cancellation path; no indefinitely pinned off-screen stream.

## 8 Retention and storage bounds

DB-002 adds independent history_quote_pins and history_detail_pins. Acquired daily history for confirmed investment records and retained benchmarks survives disposal of every chart/scalar generation. SHARED_STATE 4 defines eligibility, promotion leases and original-file retention. These retained rows are outside the disposable public-input quota.

These are initial engineering settings. They are not user-data capacity limits or demonstrated device results.

| STORAGE OR WORK | INITIAL BOUND | ACTION AT THE BOUND |
|---|---|---|
| Application result and geometry memory | 32 MiB total | Evict least recently used inactive results. |
| SQLite page cache | Measured 16–32 MiB for the active connection | Any added reader needs a separate measured memory budget. |
| Unpinned downloaded public inputs | 256 MiB | Evict least recently used unpinned history/details; coalesce access-time writes. |
| Public raster logo files | 16 MiB unique encoded bytes | Evict descriptor mappings, then release files only when all reference/lease owners are gone; use monogram fallback. |
| Disposable projection generations and temporary search results | 128 MiB | Retain active/current useful results; evict inactive generations and rarely used custom ranges. |
| Native/worker result page | 500 candidate keys or the smaller established byte bound | Yield, check cancellation and continue from a key. |
| Normal list display state | 100 rows/page, at most five pages | Release off-screen pages. |
| WAL normal soft threshold | 32 MiB after completed writes | Release expired readers and pause background ingestion; never discard required WAL. |

The full FTS corpus is rebuildable but is not an LRU collection of documents. Track its disk cost separately. Removing arbitrary indexed records would create silent gaps in search. If the whole index must be removed, mark search unavailable/preparing until a complete compatible generation is rebuilt. Avoid a rebuild/eviction loop when free space is insufficient.

Authored records, supported drafts, source identities, operation receipts, Undo dependencies, saved close revisions, attachment evidence and their required input observations have no automatic TTL. Storage pressure can stop new work with a factual local state; it cannot delete these records to satisfy a cache target.

A published derived generation pins the immutable public observations needed to reproduce it while that generation is retained. A saved close has its own durable evidence references. The foundation supplies projection_quote_inputs, projection_entity_inputs and projection_detail_inputs for the complete immutable quote, authored after-image and public-detail input set. Saved closes retain their own corresponding evidence bridges, including close_detail_inputs. Operational recurring inputs use sealed projection_occurrence_inputs with exact proposal fields, original generator/codec versions and same-generation schedule/decision history references. Publication verifies the referenced entity types, identity, revision and captured selection. Exact-series and saved-close inputs must be pinned or frozen in that generation. Scalars may instead identify authored inputs through the complete versioned cutoff replay descriptor in SHARED_STATE 2, with immutable audit/selection closure and bounded explicit public/operational inputs; quote-only pins do not retain sector/classification or authored revision evidence. Dropping a disposable generation releases only its own pins. An observation is evictable only when no active generation, retained history, close or other durable reference requires it. A foreign-key reference check and the pin decision occur in the same writer transaction as eviction; a queued job cannot race it. Jobs reserve references during extraction/publication or retry if unpinned inputs were evicted before they acquired a stable reference.

Do not fetch again automatically just to hide eviction. With networking disabled, a missing required input is Missing and local/manual entry remains available. Pinned evidence is not forced under the 256 MiB cache quota. Its growth is measured separately and included in admission checks for import/recovery/migration.

The five-million-quote stress fixture can raise the cache quota explicitly to load that test. Report the quota, retained/pinned split, actual bytes and free-space reserve. Do not present a stress run with eviction disabled as evidence for default-cache behaviour. Also run eviction enabled and verify exact Missing/pinned-evidence behaviour.

Measure tables, secondary indexes, FTS, WAL, staging, quotes, projections, attachments and recovery generations separately. Do not assume a row-count capacity from a guessed average row size. No whole-history vacuum, index rebuild or statistics pass runs on the startup path.

Cleanup has indexed reverse lookup through local_jobs_generation and the three *_attachment_reverse indexes. Release only terminal projection-job references after attempt revocation and all other leases. Initial slices examine at most 32 candidates or 20 ms measured statement work, then yield; native statement limits and high-fanout deletion require the device plan. Dependency revision rows are lifetime metadata: UPDATE only, no DELETE or REPLACE reset. Missing-dependency read defence still applies to corrupt/legacy inputs.

## 9 Query acceptance and plan review

Run reference SQL checks first, then the same query families on the pinned encrypted SQLite build at all B/L/S workload tiers. Populate realistic selectivity, skew, tombstones, split density, null categories, date ties and repeated candidate hashes. An empty database can choose a different plan from a populated one.

| CONTRACT | REQUIRED ACCESS AND WORK | CORRECTNESS CASES |
|---|---|---|
| Q01 account/global/kind pages | Ordered live index seek; no unrelated account scan or large temporary sort | Deep page, equal dates, inserted/backdated/deleted row, revision reset. |
| Q02 selected accounts/combined filters | Bounded candidate streams and merge; explicit cancellable work | Sparse filters, 500 scopes, absent matches, stable result completeness. |
| Category lists/totals | Generation/category/date or affected-source range; exact worker sum | Same-category repeated splits, uncategorised, refunds, split replacement, overflow, multi-currency. |
| Q03 exact identity | Unique composite lookup | Reimport, undone target, two identical actual payments. |
| Q04/Q05 candidates | Bounded indexed extraction; residual rejection follows the page | Long tombstone/linked runs, cursor over rejected rows, dense duplicate-looking rows, cross-currency ambiguity, date-window edge, minimum integer. |
| Q06 FTS | MATCH virtual-table constraint and mapped-document primary key | Common/rare/missing term, Unicode, rollback, rename/delete, completed rebuild. |
| Q07/Q08 quotes | Current-series/date range and quote primary key | Multiple revisions, basis/currency separation, no observation, saved evidence unchanged. |
| Q09/Q10 current projection/summary read | Key/pointer lookup and one generation's bounded buckets | Stale inputs, period mismatch, incompatible card/chart generations. |
| Q11/Q12 category/chart/table/crosshair | Indexed generation/series/resolution/date or direct key | Gaps, negative values, dense steps, exact tooltip agreement. |
| Dirty range acknowledgement | Scope/kind/range key; bounded metadata | New invalidation during work, partial date coverage, restore epoch. |
| Q14/Q15 exact table/crosshair | Generation/point primary key; retained exact values | Same generation, correct extrema date, explicit gaps, no mutable-source substitution. |
| Q13 pending Inbox | Pending/source/order index; paged rows | Confirm/cancel race, untouched unticked rows, no ledger write during read. |

Use EXPLAIN QUERY PLAN to inspect intended access and temporary sorting, then measure statement work and latency. Do not fail all SCAN strings blindly: an FTS MATCH virtual scan or a bounded ordered index scan can be valid. Do reject a hot path that enumerates an entire transaction/quote table or sorts an unbounded candidate set. Explain output text can change across SQLite versions, so checks follow the pinned engine and query properties rather than a permanent string snapshot. SQLite explain plans

Run bounded statistics maintenance after a large import/schema change when idle; check the pinned SQLite build's PRAGMA optimize behaviour and budget it. Do not run unrestricted ANALYZE at every open. SQLite optimisation pragma

Record first/deep-page latency, visited rows or VM steps, temporary sorting, process memory, WAL growth and cancellation latency. PERFORMANCE_PLAN defines P01–P16, including the clarified P04 end-to-end shared-state boundary. New index/FTS choices need both read and write/storage measurements. Plain SQLite reference checks, warm projection hits and a small fixture cannot establish those device targets.

## 10 Implementation handoff

Implement a query family only after its table/columns exist, its product gates are resolved, its source fixtures have exact expected outputs and its plan meets the bounded-work contract. The reference DDL covers the database foundation; later feature modules add their typed tables through separate migrations. The logical projection/chart rules above remain required even where a feature-specific output table is not yet in that foundation.

Each query change names its Q-contract or logical family, source flow, schema/index change, cursor/dependency key, output cap, cancellation path, exact result fixtures and measured plan. A projection optimisation must pass a full rebuild comparison. A faster result with different coverage, rounding or provenance is a failed change.

## 11 Shared values and public assets (DB-002)

SHARED_STATE defines metric identity, writer publication, history retention and asset admission. Each screen subscribes to the same repository value for a canonical key. It does not run its own source-table query or compute its own total.

### Q16 Shared metric snapshot

The example requests two distinct keys. Generate a bound VALUES list for 1–128 unique keys, with no user SQL. Resolve the dependency graph once before the read; do not discover it recursively from widgets. One statement returns one consistent SQLite snapshot. If a larger subscription set needs multiple statements, use the same short read transaction and publish the combined immutable result only after all reads complete. Close the transaction before UI delivery. SQLite isolates readers from partial writes. SQLite transactions

```sql
-- Q16: shared values for two distinct canonical keys, one publication revision.
WITH wanted(key_id) AS (VALUES (:key_id), (:second_key_id))
SELECT w.key_id, s.db_epoch, s.read_revision, g.id AS generation_id,
  k.currency, m.value_kind, m.value_state, m.value_basis,
  m.amount_minor, m.value_decimal, m.count_value, m.reason_code,
  g.computed_at, g.coverage_json,
CASE WHEN g.id IS NULL OR m.generation_id IS NULL THEN 'unavailable'
  WHEN EXISTS (
    SELECT 1 FROM projection_inputs AS i
    LEFT JOIN dependency_revisions AS r ON r.scope_id = i.scope_id
    WHERE i.generation_id = g.id
      AND (r.scope_id IS NULL OR r.revision <> i.input_revision)
  ) THEN 'updating'
  ELSE 'current' END AS freshness
FROM wanted AS w
CROSS JOIN db_state AS s
LEFT JOIN projection_keys AS k ON k.id = w.key_id
LEFT JOIN current_projections AS c ON c.key_id = k.id
LEFT JOIN projection_generations AS g
  ON g.id = c.generation_id AND g.key_id = k.id
  AND g.status = 'published' AND g.db_epoch = s.db_epoch
LEFT JOIN metric_values AS m ON m.generation_id = g.id
WHERE s.singleton = 1;
```

current with value_state=missing is a completed calculation with missing evidence. unavailable means no compatible published result exists; it is never zero. An updating row may carry its previous complete value and date for that same key. It cannot feed a new total or be presented as current. A different database epoch returns no old financial value. Semantic dependency completeness and clock invalidation are writer obligations: the SQL can check only the dependencies recorded in projection_inputs.

The snapshot's read_revision is shared, but unchanged metrics can keep older generations. That is valid only when their captured dependencies still match. Related dirty metrics must either publish a compatible set or expose their updating state in this same snapshot. There is no table scan or financial arithmetic on this path; the work is proportional to requested keys and their declared input scopes. Unbounded dependency sets need compact aggregate scopes with tested invalidation.

### Q17 Public logo lookup

```sql
-- Q17: one public descriptor resolves to one immutable encrypted file.
SELECT a.attachment_id, f.object_name, f.media_type, f.plaintext_size,
  f.authenticated_digest, a.validated_at
FROM public_asset_cache AS a
JOIN attachment_manifests AS f ON f.id = a.attachment_id
WHERE a.provider_id = :provider_id
  AND a.asset_key = :asset_key AND a.rendition = :rendition;
```

Only the local file service receives the object name; features receive a bounded decoded image handle. A miss uses the design-system monogram. It does not cause a network request from the widget. The public gateway may enqueue an authorised download. A cache lookup never updates an access timestamp per render.

Q16 acceptance: two views of one key agree; stale/missing input scopes and restore epochs are detected; source and metric rollback are atomic; late subscribers read current state; metadata work stays bounded at 128 keys. Q17 acceptance: exact descriptor lookup, digest reuse, invalid media rejection, quota eviction and safe shared-file cleanup.

## 11 Phase 1 layout reads (SPEC W7, W13)

### Q18 Raw surface snapshot

```sql
-- Q18: one surface snapshot: default versus explicit-empty, sections, items, sizes.
WITH bounded_sections AS MATERIALIZED (
  SELECT surface_key, position, section_key
  FROM layout_sections
  WHERE surface_key = :surface_key
  ORDER BY position
  LIMIT 17
), bounded_items AS MATERIALIZED (
  SELECT surface_key, section_key, position, item_key, size
  FROM layout_items
  WHERE surface_key = :surface_key
  ORDER BY section_key, position
  LIMIT 257
), parts AS (
  SELECT surface_key, position AS section_position, section_key,
    NULL AS item_position, NULL AS item_key, NULL AS size
  FROM bounded_sections
  UNION ALL
  SELECT i.surface_key, s.position, i.section_key, i.position, i.item_key, i.size
  FROM bounded_items AS i
  LEFT JOIN bounded_sections AS s
    ON s.surface_key = i.surface_key AND s.section_key = i.section_key
)
SELECT d.db_epoch, d.read_revision, l.surface_key, l.catalogue_version,
  l.base_layout_version, p.section_position, p.section_key,
  p.item_position, p.item_key, p.size
FROM db_state AS d
LEFT JOIN layout_surfaces AS l ON l.surface_key = :surface_key
LEFT JOIN parts AS p ON p.surface_key = l.surface_key
WHERE d.singleton = 1
ORDER BY p.section_position, p.item_position;
```

One statement returns one bounded snapshot: the surface header, its sections in order and its items with section, position and size. A NULL stored surface means use the installed default layout file. A non-NULL surface with no section and no item rows means an explicitly empty custom layout (the written form, DB4-4); a section row with no item rows is a stored section with no shown widget (not drawn at rest, drawn in edit mode). Section rows carry NULL item columns. The reader groups items by section_key; order is section position, then item position.

Limits: at most 16 sections and 256 items per surface, and 64 KiB canonical descriptor bytes. The byte limit matters only for retained non-identifier keys from another version (DB4-6). The 17th section or the 257th item signals an unsupported oversized preference; the result has at most 274 part rows. Do not turn truncated results into a writable layout. Default/reset may explicitly remove the whole preference through the bounded writer path.

One owner read transaction obtains the touched surfaces (at most ten); no per-widget SQL is issued. Lookup uses the surface primary key, the (surface_key, position) section primary key and the (surface_key, section_key, position) item primary key. Both materialised pages are bounded before the join and final sort; the automatic index over at most 17 section rows is bounded work. An outer ordering buffer cannot grow with stored content or the financial ledger. Keep raw unknown/unreleased item and section keys in the descriptor; a section with no title keeps its raw key as identity. The registry derives a separate renderable list, including the read-time rename alias, without updating these tables.

Q18 supplies the display publication revision and base_layout_version, not the concurrency token for an edit. The owner captures per-surface runtime counters and baseline descriptors separately. Done replaces all touched surfaces atomically, with one read revision and no financial write. Reset retains owner counters despite deleting preference rows. Unknown-response retries cannot reapply a candidate against a baseline that reappears. Details, upgrade and catalogue migration rules: DATABASE_DESIGN 5.1.
