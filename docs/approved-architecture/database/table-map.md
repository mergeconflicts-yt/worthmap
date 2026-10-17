# Table Map

Source: `convert-to-md/table-map/` screenshots, Pages 1-30 of 30.
Transcribed 2026-10-16. Each table lists Column, Data type, Constraints. Table constraints follow each table.

## 1 accounts

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('accounts') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| name | TEXT | NOT NULL CHECK (length(name) BETWEEN 1 AND 256) |
| type | TEXT | NOT NULL ▶ CHECK constraint |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| institution | TEXT | CHECK (institution IS NULL OR length(institution) <= 256) |
| is_liability | INTEGER | NOT NULL CHECK (is_liability IN (0,1)) |
| is_liquid | INTEGER | NOT NULL CHECK (is_liquid IN (0,1)) |
| include_in_net_worth | INTEGER | NOT NULL CHECK (include_in_net_worth IN (0,1)) |
| ownership_percent_decimal | TEXT | NOT NULL DEFAULT '100' ▶ CHECK constraint |
| minimum_balance_minor | INTEGER | NULL allowed |
| overdraft_limit_minor | INTEGER | CHECK (overdraft_limit_minor IS NULL OR overdraft_limit_minor >= 0) |
| archived | INTEGER | NOT NULL DEFAULT 0 CHECK (archived IN (0,1)) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- UNIQUE (id, currency)
- STRICT
- ▶ Trigger constraints (4)

## 2 attachment_manifests

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL |
| object_name | TEXT | NOT NULL UNIQUE CHECK (length(CAST(object_name AS BLOB)) BETWEEN 16 AND 128 AND instr(object_name,char(0)) = 0 AND object_name NOT GLOB '*[^a-zA-Z0-9_-]*') |
| media_type | TEXT | NOT NULL |
| plaintext_size | INTEGER | NOT NULL CHECK (plaintext_size >= 0) |
| ciphertext_size | INTEGER | NOT NULL CHECK (ciphertext_size >= 0) |
| authenticated_digest | BLOB | NOT NULL CHECK (length(authenticated_digest) = 32) |
| encryption_format_version | INTEGER | NOT NULL CHECK (encryption_format_version >= 1) |
| file_key_reference | TEXT | NOT NULL |
| wrapping_key_version | INTEGER | NOT NULL CHECK (wrapping_key_version >= 1) |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |

- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (3)

## 3 balance_anchors

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('balance_anchors') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| account_id | TEXT | NOT NULL |
| date | TEXT | NOT NULL CHECK (length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date) |
| balance_minor | INTEGER | NOT NULL |
| currency | TEXT | NOT NULL |
| source | TEXT | NOT NULL CHECK (source IN ('imported','captured','manual')) |
| source_identity_id | INTEGER | REFERENCES source_identities(id) |
| inclusive | INTEGER | NOT NULL DEFAULT 1 CHECK (inclusive = 1) |
| supersedes_anchor_id | TEXT | REFERENCES balance_anchors(id) |

- CHECK (supersedes_anchor_id IS NULL OR supersedes_anchor_id <> id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- FOREIGN KEY (account_id,currency) REFERENCES accounts(id,currency)
- UNIQUE (account_id,id)
- STRICT
- ▶ Trigger constraints (6)

## 4 card_statement_obligations

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('card_statement_obligations') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| statement_id | TEXT | NOT NULL UNIQUE REFERENCES card_statements(id) |
| obligation_id | TEXT | NOT NULL REFERENCES obligations(id) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 5 card_statements

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('card_statements') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| account_id | TEXT | NOT NULL |
| close_date | TEXT | NOT NULL CHECK (length(close_date) = 10 AND close_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND close_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(close_date, '+0 days') IS close_date) |
| due_date | TEXT | NOT NULL CHECK (length(due_date) = 10 AND due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND due_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(due_date, '+0 days') IS due_date) |
| full_amount_minor | INTEGER | NOT NULL CHECK (full_amount_minor >= 0) |
| minimum_minor | INTEGER | NOT NULL CHECK (minimum_minor >= 0 AND minimum_minor <= full_amount_minor) |
| currency | TEXT | NOT NULL |
| source_identity_id | INTEGER | REFERENCES source_identities(id) |
| supersedes_statement_id | TEXT | REFERENCES card_statements(id) |

- CHECK (supersedes_statement_id IS NULL OR supersedes_statement_id <> id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- FOREIGN KEY (account_id,currency) REFERENCES accounts(id,currency)
- STRICT
- ▶ Trigger constraints (5)

## 6 categories

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('categories') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| name | TEXT | NOT NULL CHECK (length(name) BETWEEN 1 AND 128) |
| parent_id | TEXT | REFERENCES categories(id) |
| kind | TEXT | NOT NULL CHECK (kind IN ('expense','income')) |
| sort_order | INTEGER | NOT NULL DEFAULT 0 |
| archived | INTEGER | NOT NULL DEFAULT 0 CHECK (archived IN (0,1)) |

- CHECK (parent_id IS NULL OR parent_id <> id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 7 category_postings

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| transaction_id | TEXT | NOT NULL REFERENCES transactions(id) |
| part_key | TEXT | NOT NULL |
| account_id | TEXT | NOT NULL REFERENCES accounts(id) |
| category_id | TEXT | REFERENCES categories(id) |
| date | TEXT | NOT NULL CHECK (length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date) |
| kind | TEXT | NOT NULL |
| amount_minor | INTEGER | NOT NULL |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| recognition_policy | TEXT | NOT NULL |

- PRIMARY KEY (generation_id,transaction_id,part_key)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 8 change_log

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| operation_id | TEXT | NOT NULL REFERENCES operation_receipts(operation_id) DEFERRABLE INITIALLY DEFERRED |
| ordinal | INTEGER | NOT NULL CHECK (ordinal >= 0) |
| entity_id | TEXT | NOT NULL REFERENCES entity_registry(id) |
| from_revision | INTEGER | CHECK (from_revision IS NULL OR from_revision >= 1) |
| to_revision | INTEGER | NOT NULL CHECK (to_revision >= 1) |
| change_kind | TEXT | NOT NULL CHECK (change_kind IN ('create','edit','softDelete','restore','compensate')) |
| before_json | TEXT | CHECK (before_json IS NULL OR json_valid(before_json)) |
| after_json | TEXT | NOT NULL CHECK (json_valid(after_json)) |
| schema_version | INTEGER | NOT NULL CHECK (schema_version >= 1) |
| timestamp | INTEGER | NOT NULL CHECK (timestamp >= 0) |

- UNIQUE (operation_id,ordinal)
- CHECK ((from_revision IS NULL AND to_revision = 1) OR (from_revision IS NOT NULL AND to_revision = from_revision + 1))
- STRICT
- ▶ Trigger constraints (4)

## 9 chart_buckets

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| first_point_ordinal | INTEGER | NOT NULL |
| low_point_ordinal | INTEGER | NULL allowed |
| high_point_ordinal | INTEGER | NULL allowed |
| last_point_ordinal | INTEGER | NOT NULL |
| representation | TEXT | NOT NULL DEFAULT 'envelope' CHECK (representation IN ('envelope','step','gap')) |
| level | INTEGER | NOT NULL CHECK (level >= 0) |
| bucket_index | INTEGER | NOT NULL CHECK (bucket_index >= 0) |
| first_date | TEXT | NOT NULL CHECK (length(first_date) = 10 AND date(first_date, '+0 days') IS first_date) |
| last_date | TEXT | NOT NULL CHECK (length(last_date) = 10 AND date(last_date, '+0 days') IS last_date) |
| first_minor | INTEGER | NULL allowed |
| low_minor | INTEGER | NULL allowed |
| high_minor | INTEGER | NULL allowed |
| last_minor | INTEGER | NULL allowed |
| currency | TEXT | REFERENCES currencies(code) |
| first_decimal | TEXT | ▶ CHECK constraint |
| low_decimal | TEXT | ▶ CHECK constraint |
| high_decimal | TEXT | ▶ CHECK constraint |
| last_decimal | TEXT | ▶ CHECK constraint |
| value_kind | TEXT | NOT NULL CHECK (value_kind IN ('money','decimal','missing')) |
| source_count | INTEGER | NOT NULL CHECK (source_count >= 0) |

- PRIMARY KEY (generation_id,level,bucket_index)
- FOREIGN KEY (generation_id,first_point_ordinal) REFERENCES exact_series_points(generation_id,point_ordinal)
- FOREIGN KEY (generation_id,low_point_ordinal) REFERENCES exact_series_points(generation_id,point_ordinal)
- FOREIGN KEY (generation_id,high_point_ordinal) REFERENCES exact_series_points(generation_id,point_ordinal)
- FOREIGN KEY (generation_id,last_point_ordinal) REFERENCES exact_series_points(generation_id,point_ordinal)
- CHECK (last_point_ordinal >= first_point_ordinal)
- CHECK (last_date >= first_date)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 10 close_attachments

| Column | Data type | Constraints |
|---|---|---|
| close_revision_id | TEXT | NOT NULL REFERENCES close_revisions(id) |
| attachment_id | TEXT | NOT NULL REFERENCES attachment_manifests(id) |

- PRIMARY KEY (close_revision_id,attachment_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 11 close_detail_inputs

| Column | Data type | Constraints |
|---|---|---|
| close_revision_id | TEXT | NOT NULL REFERENCES close_revisions(id) |
| instrument_id | INTEGER | NOT NULL |
| detail_revision | INTEGER | NOT NULL |

- PRIMARY KEY (close_revision_id,instrument_id,detail_revision)
- FOREIGN KEY (instrument_id,detail_revision) REFERENCES public_instrument_details(instrument_id,revision)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 12 close_entity_inputs

| Column | Data type | Constraints |
|---|---|---|
| close_revision_id | TEXT | NOT NULL REFERENCES close_revisions(id) |
| change_log_id | INTEGER | NOT NULL REFERENCES change_log(id) |

- PRIMARY KEY (close_revision_id,change_log_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 13 close_lot_allocations

| Column | Data type | Constraints |
|---|---|---|
| close_revision_id | TEXT | NOT NULL REFERENCES close_revisions(id) |
| disposal_event_id | TEXT | NOT NULL REFERENCES investment_transactions(id) |
| lot_id | TEXT | NOT NULL REFERENCES lots(id) |
| quantity_decimal | TEXT | NOT NULL ▶ CHECK constraint |
| cost_minor | INTEGER | NULL allowed |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| cost_state | TEXT | NOT NULL CHECK (cost_state IN ('known','missing')) |
| method_version | INTEGER | NOT NULL CHECK (method_version >= 1) |

- PRIMARY KEY (close_revision_id,disposal_event_id,lot_id)
- CHECK ((cost_state='missing' AND cost_minor IS NULL) OR (cost_state='known' AND cost_minor IS NOT NULL))
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 14 close_quote_inputs

| Column | Data type | Constraints |
|---|---|---|
| close_revision_id | TEXT | NOT NULL REFERENCES close_revisions(id) |
| quote_id | INTEGER | NOT NULL REFERENCES price_quotes(id) |

- PRIMARY KEY (close_revision_id,quote_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 15 close_revisions

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL |
| close_id | TEXT | NOT NULL REFERENCES month_closes(id) |
| sequence | INTEGER | NOT NULL CHECK (sequence >= 1) |
| previous_revision_id | TEXT | NULL allowed |
| cutoff_date | TEXT | NOT NULL CHECK (length(cutoff_date) = 10 AND cutoff_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND cutoff_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(cutoff_date, '+0 days') IS cutoff_date) |
| saved_at | INTEGER | NOT NULL CHECK (saved_at >= 0) |
| source_commit_sequence | INTEGER | NOT NULL CHECK (source_commit_sequence >= 0) |
| method_version | INTEGER | NOT NULL CHECK (method_version >= 1) |
| operation_id | TEXT | NOT NULL REFERENCES operation_receipts(operation_id) DEFERRABLE INITIALLY DEFERRED |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| total_assets_minor | INTEGER | NULL allowed |
| total_liabilities_minor | INTEGER | NULL allowed |
| value_state | TEXT | NOT NULL CHECK (value_state IN ('known','estimated','missing')) |
| coverage_json | TEXT | NOT NULL CHECK (json_valid(coverage_json)) |
| result_json | TEXT | NOT NULL CHECK (json_valid(result_json)) |

- UNIQUE (close_id,sequence)
- UNIQUE (close_id,id)
- FOREIGN KEY (close_id,previous_revision_id) REFERENCES close_revisions(close_id,id)
- CHECK ((sequence = 1 AND previous_revision_id IS NULL) OR (sequence > 1 AND previous_revision_id IS NOT NULL))
- CHECK (previous_revision_id IS NULL OR previous_revision_id <> id)
- CHECK ((value_state = 'missing' AND total_assets_minor IS NULL AND total_liabilities_minor IS NULL) OR (value_state IN ('known','estimated') AND total_assets_minor IS NOT NULL AND total_liabilities_minor IS NOT NULL))
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 16 currencies

| Column | Data type | Constraints |
|---|---|---|
| code | TEXT | PRIMARY KEY NOT NULL CHECK (length(CAST(code AS BLOB)) = 3 AND instr(code,char(0)) = 0 AND code NOT GLOB '*[^A-Z]*') |
| minor_digits | INTEGER | NOT NULL CHECK (minor_digits BETWEEN 0 AND 6) |

- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (3)

## 17 current_balance_anchors

| Column | Data type | Constraints |
|---|---|---|
| account_id | TEXT | PRIMARY KEY NOT NULL REFERENCES accounts(id) |
| anchor_id | TEXT | NOT NULL |
| selected_operation_id | TEXT | NOT NULL REFERENCES operation_receipts(operation_id) DEFERRABLE INITIALLY DEFERRED |

- FOREIGN KEY (account_id,anchor_id) REFERENCES balance_anchors(account_id,id)
- STRICT, WITHOUT ROWID

## 18 current_occurrence_decisions

| Column | Data type | Constraints |
|---|---|---|
| occurrence_id | TEXT | PRIMARY KEY NOT NULL REFERENCES scheduled_occurrences(id) |
| decision_id | TEXT | NOT NULL |
| selected_operation_id | TEXT | NOT NULL REFERENCES operation_receipts(operation_id) DEFERRABLE INITIALLY DEFERRED |

- FOREIGN KEY (occurrence_id,decision_id) REFERENCES occurrence_decisions(occurrence_id,id)
- STRICT, WITHOUT ROWID

## 19 current_projections

| Column | Data type | Constraints |
|---|---|---|
| key_id | INTEGER | PRIMARY KEY REFERENCES projection_keys(id) |
| generation_id | INTEGER | NOT NULL UNIQUE |

- FOREIGN KEY (generation_id,key_id) REFERENCES projection_generations(id,key_id)
- STRICT
- ▶ Trigger constraints (2)

## 20 current_quotes

| Column | Data type | Constraints |
|---|---|---|
| series_id | INTEGER | NOT NULL |
| date | TEXT | NOT NULL |
| quote_id | INTEGER | NOT NULL UNIQUE |

- PRIMARY KEY (series_id,date)
- FOREIGN KEY (quote_id,series_id,date) REFERENCES price_quotes(id,series_id,date)
- STRICT, WITHOUT ROWID

## 21 db_state

| Column | Data type | Constraints |
|---|---|---|
| singleton | INTEGER | PRIMARY KEY CHECK (singleton = 1) |
| db_epoch | TEXT | NOT NULL CHECK (length(db_epoch) > 0) |
| commit_sequence | INTEGER | NOT NULL CHECK (commit_sequence >= 0) |
| schema_version | INTEGER | NOT NULL CHECK (schema_version >= 1) |
| network_policy_epoch | INTEGER | NOT NULL CHECK (network_policy_epoch >= 0) |
| network_enabled | INTEGER | NOT NULL DEFAULT 0 CHECK (network_enabled IN (0,1)) |
| read_revision | INTEGER | NOT NULL DEFAULT 0 CHECK (read_revision >= 0) |
| inbox_revision | INTEGER | NOT NULL DEFAULT 0 CHECK (inbox_revision >= 0) |

- STRICT
- ▶ Trigger constraints (5)

## 22 dependency_revisions

| Column | Data type | Constraints |
|---|---|---|
| scope_id | INTEGER | PRIMARY KEY REFERENCES dependency_scopes(id) |
| revision | INTEGER | NOT NULL CHECK (revision >= 0) |

- STRICT
- ▶ Trigger constraints (5)

## 23 dependency_scopes

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| kind | TEXT | NOT NULL CHECK (kind IN ('account','security','fxPair','schedule','source','settings','clock')) |
| scope_key | TEXT | NOT NULL CHECK (length(scope_key) > 0) |

- UNIQUE (kind,scope_key)
- STRICT
- ▶ Trigger constraints (3)

## 24 dirty_ranges

| Column | Data type | Constraints |
|---|---|---|
| scope_id | INTEGER | NOT NULL REFERENCES dependency_scopes(id) |
| projection_kind | TEXT | NOT NULL |
| start_date | TEXT | NOT NULL CHECK (length(start_date) = 10 AND start_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND start_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(start_date, '+0 days') IS start_date) |
| end_date | TEXT | CHECK (end_date IS NULL OR (length(end_date) = 10 AND end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND end_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(end_date, '+0 days') IS end_date)) |
| required_revision | INTEGER | NOT NULL CHECK (required_revision >= 1) |

- PRIMARY KEY (scope_id,projection_kind)
- CHECK (end_date IS NULL OR end_date >= start_date)
- STRICT, WITHOUT ROWID

## 25 draft_attachments

| Column | Data type | Constraints |
|---|---|---|
| draft_id | TEXT | NOT NULL REFERENCES draft_headers(id) |
| attachment_id | TEXT | NOT NULL REFERENCES attachment_manifests(id) |

- PRIMARY KEY (draft_id,attachment_id)
- STRICT, WITHOUT ROWID

## 26 draft_headers

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL |
| form_type | TEXT | NOT NULL |
| schema_version | INTEGER | NOT NULL CHECK (schema_version >= 1) |
| db_epoch | TEXT | NOT NULL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| edit_revision | INTEGER | NOT NULL CHECK (edit_revision >= 1) |
| status | TEXT | NOT NULL CHECK (status IN ('editing','submitted','committed','discarded','unsupported')) |
| committed_operation_id | TEXT | REFERENCES operation_receipts(operation_id) |

- CHECK ((status = 'committed' AND committed_operation_id IS NOT NULL) OR (status <> 'committed' AND committed_operation_id IS NULL))
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (2)

## 27 draft_payloads

| Column | Data type | Constraints |
|---|---|---|
| draft_id | TEXT | PRIMARY KEY NOT NULL REFERENCES draft_headers(id) |
| payload_json | TEXT | NOT NULL CHECK (json_valid(payload_json) AND length(CAST(payload_json AS BLOB)) <= 262144) |

- STRICT, WITHOUT ROWID

## 28 draft_references

| Column | Data type | Constraints |
|---|---|---|
| draft_id | TEXT | NOT NULL REFERENCES draft_headers(id) |
| entity_id | TEXT | NOT NULL REFERENCES entity_registry(id) |
| expected_revision | INTEGER | NOT NULL CHECK (expected_revision >= 1) |

- PRIMARY KEY (draft_id,entity_id)
- STRICT, WITHOUT ROWID

## 29 entity_registry

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL |
| entity_kind | TEXT | NOT NULL CHECK (length(entity_kind) > 0) |

- UNIQUE (id, entity_kind)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 30 event_attachments

| Column | Data type | Constraints |
|---|---|---|
| event_id | TEXT | NOT NULL REFERENCES financial_events(id) |
| attachment_id | TEXT | NOT NULL REFERENCES attachment_manifests(id) |
| operation_id | TEXT | NOT NULL REFERENCES operation_receipts(operation_id) DEFERRABLE INITIALLY DEFERRED |

- PRIMARY KEY (event_id,attachment_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 31 exact_series_points

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| point_ordinal | INTEGER | NOT NULL CHECK (point_ordinal >= 0) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| same_day_order | INTEGER | NOT NULL CHECK (same_day_order >= 0) |
| effective_at | INTEGER | CHECK (effective_at IS NULL OR effective_at >= 0) |
| point_role | TEXT | NOT NULL CHECK (point_role IN ('observation','valuation','step','gap')) |
| value_kind | TEXT | NOT NULL CHECK (value_kind IN ('money','decimal','missing')) |
| value_state | TEXT | NOT NULL CHECK (value_state IN ('known','estimated','missing')) |
| amount_minor | INTEGER | NULL allowed |
| value_decimal | TEXT | ▶ CHECK constraint |
| currency | TEXT | REFERENCES currencies(code) |
| coverage_json | TEXT | NOT NULL CHECK (json_valid(coverage_json) AND length(CAST(coverage_json AS BLOB)) <= 4096) |

- PRIMARY KEY (generation_id,point_ordinal)
- UNIQUE (generation_id,date,same_day_order)
- ▶ CHECK constraint
- CHECK (point_role <> 'gap' OR value_kind = 'missing')
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (8)

## 32 financial_events

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('financial_events') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| event_type | TEXT | NOT NULL CHECK (event_type IN ('payment','income','transfer','refund','investment','vest','payslip','settlement','adjustment','fee')) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| operation_id | TEXT | NOT NULL REFERENCES operation_receipts(operation_id) DEFERRABLE INITIALLY DEFERRED |
| supersedes_event_id | TEXT | REFERENCES financial_events(id) |

- CHECK (supersedes_event_id IS NULL OR supersedes_event_id <> id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 33 fx_observations

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('fx_observations') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| base_currency | TEXT | NOT NULL REFERENCES currencies(code) |
| quote_currency | TEXT | NOT NULL REFERENCES currencies(code) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| rate_decimal | TEXT | NOT NULL ▶ CHECK constraint |
| source | TEXT | NOT NULL CHECK (source IN ('manual','imported')) |
| source_identity_id | INTEGER | REFERENCES source_identities(id) |
| supersedes_fx_id | TEXT | REFERENCES fx_observations(id) |

- CHECK (base_currency <> quote_currency)
- CHECK (supersedes_fx_id IS NULL OR supersedes_fx_id <> id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (8)

## 34 history_detail_pins

| Column | Data type | Constraints |
|---|---|---|
| instrument_id | INTEGER | NOT NULL |
| detail_revision | INTEGER | NOT NULL |
| retained_at | INTEGER | NOT NULL CHECK (retained_at >= 0) |

- PRIMARY KEY (instrument_id,detail_revision)
- FOREIGN KEY (instrument_id,detail_revision) REFERENCES public_instrument_details(instrument_id,revision)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 35 history_quote_pins

| Column | Data type | Constraints |
|---|---|---|
| quote_id | INTEGER | PRIMARY KEY REFERENCES price_quotes(id) |
| retained_at | INTEGER | NOT NULL CHECK (retained_at >= 0) |

- STRICT
- ▶ Trigger constraints (4)

## 36 holdings

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('holdings') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| account_id | TEXT | NOT NULL REFERENCES accounts(id) |
| security_id | TEXT | NOT NULL REFERENCES securities(id) |
| cost_method | TEXT | NOT NULL CHECK (cost_method IN ('average','fifo')) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- CREATE UNIQUE INDEX holding_live ON holdings(account_id,security_id) WHERE deleted_at IS NULL
- ▶ Trigger constraints (4)

## 37 import_batches

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL |
| parse_config_id | TEXT | NOT NULL REFERENCES import_parse_configs(id) |
| source | TEXT | NOT NULL CHECK (source IN ('localFile','localShare','localFolder','financeKit','notification')) |
| file_digest | BLOB | CHECK (file_digest IS NULL OR length(file_digest) = 32) |
| parser_id | TEXT | NOT NULL |
| parser_version | INTEGER | NOT NULL CHECK (parser_version >= 1) |
| template_version | INTEGER | NULL allowed |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| status | TEXT | NOT NULL CHECK (status IN ('parsing','review','done','discarded','failed','sourceNeeded','unsupportedParser')) |
| row_count | INTEGER | NOT NULL DEFAULT 0 CHECK (row_count >= 0) |
| parsed_cursor | TEXT | NULL allowed |
| safe_error_code | TEXT | NULL allowed |
| payload_schema_version | INTEGER | NOT NULL CHECK (payload_schema_version >= 1) |
| inbox_published | INTEGER | NOT NULL DEFAULT 0 CHECK (inbox_published IN (0,1)) |

- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 38 import_job_inputs

| Column | Data type | Constraints |
|---|---|---|
| job_id | TEXT | PRIMARY KEY NOT NULL REFERENCES local_jobs(id) |
| batch_id | TEXT | NOT NULL REFERENCES import_batches(id) |
| source_id | TEXT | NOT NULL REFERENCES import_sources(id) |
| parse_config_id | TEXT | NOT NULL REFERENCES import_parse_configs(id) |

- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (3)

## 39 import_parse_configs

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL |
| parser_id | TEXT | NOT NULL |
| parser_version | INTEGER | NOT NULL CHECK (parser_version >= 1) |
| identity_version | INTEGER | NOT NULL CHECK (identity_version >= 1) |
| config_version | INTEGER | NOT NULL CHECK (config_version >= 1) |
| config_json | TEXT | NOT NULL CHECK (json_valid(config_json) AND length(CAST(config_json AS BLOB)) <= 262144) |
| content_digest | BLOB | NOT NULL CHECK (length(content_digest)=32) |

- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (3)

## 40 import_sources

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL |
| object_name | TEXT | NOT NULL UNIQUE CHECK (length(CAST(object_name AS BLOB)) BETWEEN 16 AND 128 AND instr(object_name,char(0))=0 AND object_name NOT GLOB '*[^a-zA-Z0-9_-]*') |
| file_digest | BLOB | NOT NULL CHECK (length(file_digest)=32) |
| byte_count | INTEGER | NOT NULL CHECK (byte_count >= 0) |
| staging_key_reference | TEXT | NOT NULL |
| install_epoch | TEXT | NOT NULL |
| state | TEXT | NOT NULL CHECK (state IN ('available','released','missing')) |

- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (3)

## 41 inbox_items

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| source_identity_id | INTEGER | NOT NULL UNIQUE REFERENCES source_identities(id) |
| staged_row_id | INTEGER | REFERENCES staged_rows(id) |
| received_at | INTEGER | NOT NULL CHECK (received_at >= 0) |
| suggestion_type | TEXT | NOT NULL CHECK (suggestion_type IN ('new','merge','transfer','refund','recurring','categoryChange','vestConfirm','payslipMismatch')) |
| payload_schema_version | INTEGER | NOT NULL CHECK (payload_schema_version >= 1) |
| proposed_json | TEXT | CHECK (proposed_json IS NULL OR (json_valid(proposed_json) AND length(CAST(proposed_json AS BLOB)) <= 262144)) |
| decision | TEXT | NOT NULL CHECK (decision IN ('pending','accepted','deleted')) |
| edit_revision | INTEGER | NOT NULL CHECK (edit_revision >= 1) |
| decided_at | INTEGER | NULL allowed |
| operation_id | TEXT | REFERENCES operation_receipts(operation_id) |

- ▶ CHECK constraint
- STRICT
- ▶ Trigger constraints (2)

## 42 investment_transactions

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('investment_transactions') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| event_id | TEXT | NOT NULL REFERENCES financial_events(id) |
| holding_id | TEXT | NOT NULL REFERENCES holdings(id) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| type | TEXT | NOT NULL CHECK (type IN ('buy','sell','dividend','interest','drip','dividendKind','split','transferIn','transferOut','vest','respPurchase','fee','returnOfCapital','stakingReward')) |
| effective_at | INTEGER | CHECK (effective_at IS NULL OR effective_at >= 0) |
| order_sequence | INTEGER | CHECK (order_sequence IS NULL OR order_sequence >= 0) |
| order_scope | TEXT | CHECK (order_scope IS NULL OR length(CAST(order_scope AS BLOB)) BETWEEN 1 AND 256) |
| order_source | TEXT | NOT NULL DEFAULT 'unknown' CHECK (order_source IN ('unknown','sourceSequence','effectiveInstant','userConfirmed')) |
| quantity_decimal | TEXT | ▶ CHECK constraint |
| price_decimal | TEXT | ▶ CHECK constraint |
| amount_minor | INTEGER | NULL allowed |
| fee_minor | INTEGER | CHECK (fee_minor IS NULL OR fee_minor >= 0) |
| tax_minor | INTEGER | CHECK (tax_minor IS NULL OR tax_minor >= 0) |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| source | TEXT | NOT NULL CHECK (source IN ('manual','imported','captured')) |

- CHECK ((order_sequence IS NULL) = (order_scope IS NULL))
- ▶ CHECK constraint
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 43 layout_items

| Column | Data type | Constraints |
|---|---|---|
| surface_key | TEXT | NOT NULL |
| section_key | TEXT | NOT NULL |
| position | INTEGER | NOT NULL CHECK (position >= 0) |
| item_key | TEXT | NOT NULL CHECK (length(item_key) BETWEEN 1 AND 64 AND instr(item_key,char(0))=0) |
| size | TEXT | NOT NULL CHECK (size IN ('full','half')) |

- PRIMARY KEY (surface_key,section_key,position)
- UNIQUE (surface_key,item_key)
- FOREIGN KEY (surface_key,section_key) REFERENCES layout_sections(surface_key,section_key) ON DELETE CASCADE
- CHECK (surface_key <> 'tiles:quickLook' OR size = 'full')
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (2)

## 44 layout_sections

| Column | Data type | Constraints |
|---|---|---|
| surface_key | TEXT | NOT NULL REFERENCES layout_surfaces(surface_key) ON DELETE CASCADE |
| position | INTEGER | NOT NULL CHECK (position >= 0) |
| section_key | TEXT | NOT NULL CHECK (length(section_key) BETWEEN 1 AND 64 AND instr(section_key,char(0))=0 AND section_key NOT GLOB '*[^A-Za-z0-9._-]*' AND (section_key = 'untitled' OR lower(section_key) <> 'untitled')) |

- PRIMARY KEY (surface_key,position)
- UNIQUE (surface_key,section_key)
- CHECK (surface_key <> 'tiles:quickLook' OR section_key = 'untitled')
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (2)

## 45 layout_surfaces

| Column | Data type | Constraints |
|---|---|---|
| surface_key | TEXT | PRIMARY KEY NOT NULL CHECK (surface_key IN ('screen:home','screen:spending','screen:moneyIn','screen:wealth','screen:investments','screen:calendar','screen:goals','screen:protect','screen:tax','tiles:quickLook')) |
| catalogue_version | INTEGER | NOT NULL CHECK (catalogue_version >= 1) |
| base_layout_version | INTEGER | NOT NULL CHECK (base_layout_version >= 1) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |

- STRICT
- ▶ Trigger constraints (2)

## 46 local_jobs

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL |
| kind | TEXT | NOT NULL |
| db_epoch | TEXT | NOT NULL |
| priority | INTEGER | NOT NULL CHECK (priority BETWEEN 0 AND 4) |
| state | TEXT | NOT NULL CHECK (state IN ('queued','running','paused','complete','failed','cancelled')) |
| lease_owner | TEXT | NULL allowed |
| lease_until | INTEGER | NULL allowed |
| generation_id | INTEGER | REFERENCES projection_generations(id) |
| progress_count | INTEGER | NOT NULL DEFAULT 0 CHECK (progress_count >= 0) |
| safe_error_code | TEXT | NULL allowed |

- CHECK ((lease_owner IS NULL) = (lease_until IS NULL))
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (2)

## 47 lot_allocations

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| disposal_event_id | TEXT | NOT NULL REFERENCES investment_transactions(id) |
| lot_id | TEXT | NOT NULL REFERENCES lots(id) |
| quantity_decimal | TEXT | NOT NULL ▶ CHECK constraint |
| cost_minor | INTEGER | NULL allowed |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| cost_state | TEXT | NOT NULL CHECK (cost_state IN ('known','missing')) |
| method_version | INTEGER | NOT NULL CHECK (method_version >= 1) |

- PRIMARY KEY (generation_id,disposal_event_id,lot_id)
- CHECK ((cost_state = 'missing' AND cost_minor IS NULL) OR (cost_state = 'known' AND cost_minor IS NOT NULL))
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 48 lots

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('lots') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| holding_id | TEXT | NOT NULL REFERENCES holdings(id) |
| acquisition_event_id | TEXT | NOT NULL REFERENCES investment_transactions(id) |
| acquired_date | TEXT | NOT NULL ▶ CHECK constraint |
| quantity_decimal | TEXT | NOT NULL ▶ CHECK constraint |
| cost_minor | INTEGER | NULL allowed |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| cost_state | TEXT | NOT NULL CHECK (cost_state IN ('known','missing')) |
| purchase_fx_id | TEXT | REFERENCES fx_observations(id) |
| supersedes_lot_id | TEXT | REFERENCES lots(id) |

- CHECK ((cost_state = 'missing' AND cost_minor IS NULL) OR (cost_state = 'known' AND cost_minor IS NOT NULL))
- CHECK (supersedes_lot_id IS NULL OR supersedes_lot_id <> id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (5)

## 49 manual_quotes

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('manual_quotes') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| security_id | TEXT | NOT NULL REFERENCES securities(id) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| price_decimal | TEXT | NOT NULL ▶ CHECK constraint |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| basis | TEXT | NOT NULL CHECK (basis IN ('unadjusted','splitAdjusted','totalReturn')) |
| source | TEXT | NOT NULL CHECK (source IN ('manual','imported')) |
| source_identity_id | INTEGER | REFERENCES source_identities(id) |
| supersedes_quote_id | TEXT | REFERENCES manual_quotes(id) |

- CHECK (supersedes_quote_id IS NULL OR supersedes_quote_id <> id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (8)

## 50 market_providers

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| namespace | TEXT | NOT NULL UNIQUE CHECK (length(namespace) BETWEEN 1 AND 128) |
| adapter_version | INTEGER | NOT NULL CHECK (adapter_version >= 1) |

- STRICT
- ▶ Trigger constraints (3)

## 51 market_series

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| instrument_id | INTEGER | NOT NULL |
| provider_id | INTEGER | NOT NULL |
| basis | TEXT | NOT NULL CHECK (basis IN ('unadjusted','splitAdjusted','totalReturn')) |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| interval | TEXT | NOT NULL CHECK (interval = 'daily') |

- FOREIGN KEY (instrument_id,provider_id) REFERENCES public_instruments(id,provider_id)
- UNIQUE (instrument_id,provider_id,basis,currency,interval)
- STRICT
- ▶ Trigger constraints (3)

## 52 metric_values

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | PRIMARY KEY REFERENCES projection_generations(id) ON DELETE CASCADE |
| value_kind | TEXT | NOT NULL CHECK (value_kind IN ('money','decimal','count')) |
| value_state | TEXT | NOT NULL CHECK (value_state IN ('known','estimated','missing','noneRecorded','notAvailable')) |
| value_basis | TEXT | NOT NULL DEFAULT 'actual' CHECK (value_basis IN ('actual','expected')) |
| amount_minor | INTEGER | NULL allowed |
| value_decimal | TEXT | ▶ CHECK constraint |
| count_value | INTEGER | CHECK (count_value IS NULL OR count_value >= 0) |
| reason_code | TEXT | CHECK (reason_code IS NULL OR reason_code IN ('insufficientInputs','undefinedResult','unsupportedOrder','noRecords')) |

- ▶ CHECK constraint
- STRICT
- ▶ Trigger constraints (5)

## 53 month_closes

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('month_closes') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| month | TEXT | NOT NULL UNIQUE CHECK (length(month) = 7 AND month GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]' AND substr(month,6,2) BETWEEN '01' AND '12') |
| started_at | INTEGER | NOT NULL CHECK (started_at >= 0) |
| steps_json | TEXT | NOT NULL CHECK (json_valid(steps_json)) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 54 obligations

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('obligations') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| account_id | TEXT | REFERENCES accounts(id) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| direction | TEXT | NOT NULL CHECK (direction IN ('in','out')) |
| amount_minor | INTEGER | CHECK (amount_minor IS NULL OR amount_minor >= 0) |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| amount_state | TEXT | NOT NULL CHECK (amount_state IN ('known','estimated','missing')) |
| status | TEXT | NOT NULL CHECK (status IN ('open','settled','cancelled')) |

- CHECK ((amount_state = 'missing' AND amount_minor IS NULL) OR (amount_state IN ('known','estimated') AND amount_minor IS NOT NULL))
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- UNIQUE (id,currency)
- STRICT
- ▶ Trigger constraints (4)

## 55 occurrence_decisions

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('occurrence_decisions') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| occurrence_id | TEXT | NOT NULL REFERENCES scheduled_occurrences(id) |
| operation_id | TEXT | NOT NULL REFERENCES operation_receipts(operation_id) DEFERRABLE INITIALLY DEFERRED |
| decision_type | TEXT | NOT NULL CHECK (decision_type IN ('accepted','edited','skipped','matched','cancelled')) |
| account_id | TEXT | REFERENCES accounts(id) |
| effective_date | TEXT | ▶ CHECK constraint |
| amount_minor | INTEGER | CHECK (amount_minor IS NULL OR amount_minor >= 0) |
| currency | TEXT | REFERENCES currencies(code) |
| amount_state | TEXT | NOT NULL CHECK (amount_state IN ('unchanged','known','estimated','missing')) |
| obligation_id | TEXT | REFERENCES obligations(id) |
| settlement_allocation_id | TEXT | REFERENCES settlement_allocations(id) |
| supersedes_decision_id | TEXT | NULL allowed |

- ▶ CHECK constraint
- CHECK (settlement_allocation_id IS NULL OR obligation_id IS NOT NULL)
- FOREIGN KEY (id,entity_kind) REFERENCES entity_registry(id,entity_kind) DEFERRABLE INITIALLY DEFERRED
- FOREIGN KEY (occurrence_id,supersedes_decision_id) REFERENCES occurrence_decisions(occurrence_id,id)
- UNIQUE (occurrence_id,id)
- STRICT
- ▶ Trigger constraints (4)

## 56 occurrence_locators

| Column | Data type | Constraints |
|---|---|---|
| schedule_id | TEXT | NOT NULL REFERENCES schedules(id) |
| rule_revision | INTEGER | NOT NULL CHECK (rule_revision >= 1) |
| generator_version | INTEGER | NOT NULL CHECK (generator_version >= 1) |
| nominal_slot | TEXT | NOT NULL CHECK (length(CAST(nominal_slot AS BLOB)) BETWEEN 1 AND 256 AND instr(nominal_slot,char(0)) = 0) |
| occurrence_id | TEXT | NOT NULL |

- FOREIGN KEY (schedule_id,occurrence_id) REFERENCES scheduled_occurrences(schedule_id,id)
- UNIQUE (schedule_id,rule_revision,generator_version,occurrence_id)
- PRIMARY KEY (schedule_id,rule_revision,generator_version,nominal_slot)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 57 occurrence_obligations

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('occurrence_obligations') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| occurrence_id | TEXT | NOT NULL UNIQUE REFERENCES scheduled_occurrences(id) |
| obligation_id | TEXT | NOT NULL REFERENCES obligations(id) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 58 operation_intents

| Column | Data type | Constraints |
|---|---|---|
| operation_id | TEXT | PRIMARY KEY NOT NULL |
| command_type | TEXT | NOT NULL CHECK (length(command_type) > 0) |
| payload_digest | BLOB | NOT NULL CHECK (length(payload_digest) = 32) |
| payload_version | INTEGER | NOT NULL CHECK (payload_version >= 1) |
| draft_id | TEXT | NULL allowed |
| submitted_at | INTEGER | NOT NULL CHECK (submitted_at >= 0) |
| state | TEXT | NOT NULL CHECK (state IN ('submitted','running','committed','rejected','cancelled')) |
| state_version | INTEGER | NOT NULL DEFAULT 1 CHECK (state_version >= 1) |
| safe_error_code | TEXT | NULL allowed |

- FOREIGN KEY (draft_id) REFERENCES draft_headers(id)
- STRICT, WITHOUT ROWID
- CREATE UNIQUE INDEX operation_draft_active ON operation_intents(draft_id) WHERE draft_id IS NOT NULL AND state IN ('submitted','running')
- ▶ Trigger constraints (4)

## 59 operation_payload_chunks

| Column | Data type | Constraints |
|---|---|---|
| operation_id | TEXT | NOT NULL REFERENCES operation_payloads(operation_id) |
| chunk_index | INTEGER | NOT NULL CHECK (chunk_index >= 0) |
| payload_json | TEXT | NOT NULL CHECK (json_valid(payload_json) AND length(CAST(payload_json AS BLOB)) BETWEEN 1 AND 262144) |
| content_digest | BLOB | NOT NULL CHECK (length(content_digest) = 32) |

- PRIMARY KEY (operation_id,chunk_index)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 60 operation_payloads

| Column | Data type | Constraints |
|---|---|---|
| operation_id | TEXT | PRIMARY KEY NOT NULL REFERENCES operation_intents(operation_id) |
| codec_version | INTEGER | NOT NULL CHECK (codec_version >= 1) |
| chunk_count | INTEGER | NOT NULL CHECK (chunk_count >= 1) |
| total_bytes | INTEGER | NOT NULL CHECK (total_bytes >= 1) |
| manifest_digest | BLOB | NOT NULL CHECK (length(manifest_digest) = 32) |

- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 61 operation_receipts

| Column | Data type | Constraints |
|---|---|---|
| operation_id | TEXT | PRIMARY KEY NOT NULL REFERENCES operation_intents(operation_id) |
| commit_sequence | INTEGER | NOT NULL UNIQUE CHECK (commit_sequence > 0) |
| committed_at | INTEGER | NOT NULL CHECK (committed_at >= 0) |
| result_version | INTEGER | NOT NULL CHECK (result_version >= 1) |
| result_json | TEXT | NOT NULL CHECK (json_valid(result_json) AND length(CAST(result_json AS BLOB)) <= 65536) |
| compensates_operation_id | TEXT | REFERENCES operation_receipts(operation_id) |

- CHECK (compensates_operation_id IS NULL OR compensates_operation_id <> operation_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 62 position_observations

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('position_observations') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| holding_id | TEXT | NOT NULL REFERENCES holdings(id) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| quantity_decimal | TEXT | NOT NULL ▶ CHECK constraint |
| value_minor | INTEGER | NULL allowed |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| value_state | TEXT | NOT NULL CHECK (value_state IN ('known','estimated','missing')) |
| source | TEXT | NOT NULL CHECK (source IN ('manual','imported','captured')) |
| source_identity_id | INTEGER | REFERENCES source_identities(id) |
| supersedes_observation_id | TEXT | REFERENCES position_observations(id) |

- CHECK ((value_state = 'missing' AND value_minor IS NULL) OR (value_state IN ('known','estimated') AND value_minor IS NOT NULL))
- CHECK (supersedes_observation_id IS NULL OR supersedes_observation_id <> id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (5)

## 63 price_quotes

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| series_id | INTEGER | NOT NULL REFERENCES market_series(id) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| revision | INTEGER | NOT NULL CHECK (revision >= 1) |
| price_decimal | TEXT | NOT NULL ▶ CHECK constraint |
| observed_at | INTEGER | CHECK (observed_at IS NULL OR observed_at >= 0) |
| fetched_at | INTEGER | NOT NULL CHECK (fetched_at >= 0) |
| content_digest | BLOB | NOT NULL CHECK (length(content_digest) = 32) |

- UNIQUE (series_id,date,revision)
- UNIQUE (id,series_id,date)
- STRICT
- ▶ Trigger constraints (3)

## 64 projection_detail_inputs

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| instrument_id | INTEGER | NOT NULL |
| detail_revision | INTEGER | NOT NULL |

- PRIMARY KEY (generation_id,instrument_id,detail_revision)
- FOREIGN KEY (instrument_id,detail_revision) REFERENCES public_instrument_details(instrument_id,revision)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 65 projection_entity_inputs

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| change_log_id | INTEGER | NOT NULL REFERENCES change_log(id) |

- PRIMARY KEY (generation_id,change_log_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 66 projection_generations

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| key_id | INTEGER | NOT NULL REFERENCES projection_keys(id) |
| db_epoch | TEXT | NOT NULL |
| status | TEXT | NOT NULL CHECK (status IN ('staging','published','obsolete','failed')) |
| computed_at | INTEGER | NOT NULL CHECK (computed_at >= 0) |
| source_commit_sequence | INTEGER | NOT NULL CHECK (source_commit_sequence >= 0) |
| coverage_json | TEXT | NOT NULL CHECK (json_valid(coverage_json)) |
| output_row_count | INTEGER | NOT NULL DEFAULT 0 CHECK (output_row_count >= 0) |

- UNIQUE (id,key_id)
- STRICT
- CREATE UNIQUE INDEX projection_one_staging ON projection_generations(key_id) WHERE status='staging'
- ▶ Trigger constraints (4)

## 67 projection_inputs

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| scope_id | INTEGER | NOT NULL REFERENCES dependency_scopes(id) |
| input_revision | INTEGER | NOT NULL CHECK (input_revision >= 0) |

- PRIMARY KEY (generation_id,scope_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 68 projection_keys

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| kind | TEXT | NOT NULL |
| scope_hash | BLOB | NOT NULL CHECK (length(scope_hash)=32) |
| scope_json | TEXT | NOT NULL CHECK (json_valid(scope_json) AND length(CAST(scope_json AS BLOB)) <= 65536) |
| period_start | TEXT | NOT NULL CHECK ((length(period_start) = 10 AND period_start GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND period_start BETWEEN '0001-01-01' AND '9999-12-31' AND date(period_start, '+0 days') IS period_start)) |
| period_end | TEXT | NOT NULL CHECK ((length(period_end) = 10 AND period_end GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND period_end BETWEEN '0001-01-01' AND '9999-12-31' AND date(period_end, '+0 days') IS period_end)) |
| as_of | INTEGER | NOT NULL CHECK (as_of >= 0) |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| method_version | INTEGER | NOT NULL CHECK (method_version >= 1) |
| policy_digest | BLOB | NOT NULL CHECK (length(policy_digest)=32) |
| policy_json | TEXT | NOT NULL CHECK (json_valid(policy_json) AND length(CAST(policy_json AS BLOB)) <= 65536) |

- CHECK (period_end >= period_start)
- UNIQUE (kind,scope_hash,period_start,period_end,currency,method_version,policy_digest)
- STRICT
- ▶ Trigger constraints (3)

## 69 projection_occurrence_inputs

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| occurrence_id | TEXT | NOT NULL REFERENCES scheduled_occurrences(id) |
| proposal_revision | INTEGER | NOT NULL CHECK (proposal_revision >= 1) |
| schedule_change_log_id | INTEGER | NOT NULL |
| selected_decision_change_log_id | INTEGER | NULL allowed |
| generator_version | INTEGER | NOT NULL CHECK (generator_version >= 1) |
| snapshot_codec_version | INTEGER | NOT NULL CHECK (snapshot_codec_version >= 1) |
| date | TEXT | NOT NULL CHECK (length(date)=10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date,'+0 days') IS date) |
| amount_minor | INTEGER | NULL allowed |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| amount_state | TEXT | NOT NULL CHECK (amount_state IN ('known','estimated','missing')) |

- PRIMARY KEY (generation_id,occurrence_id)
- FOREIGN KEY (generation_id,schedule_change_log_id) REFERENCES projection_entity_inputs(generation_id,change_log_id)
- FOREIGN KEY (generation_id,selected_decision_change_log_id) REFERENCES projection_entity_inputs(generation_id,change_log_id)
- CHECK ((amount_state='missing' AND amount_minor IS NULL) OR (amount_state IN ('known','estimated') AND amount_minor IS NOT NULL))
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 70 projection_quote_inputs

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| quote_id | INTEGER | NOT NULL REFERENCES price_quotes(id) |

- PRIMARY KEY (generation_id,quote_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 71 public_asset_cache

| Column | Data type | Constraints |
|---|---|---|
| provider_id | INTEGER | NOT NULL REFERENCES market_providers(id) |
| asset_key | TEXT | NOT NULL CHECK (length(CAST(asset_key AS BLOB)) BETWEEN 1 AND 192 AND instr(asset_key,char(0))=0) |
| rendition | TEXT | NOT NULL CHECK (rendition IN ('logo-64','logo-128','logo-256')) |
| attachment_id | TEXT | NOT NULL REFERENCES attachment_manifests(id) |
| validated_at | INTEGER | NOT NULL CHECK (validated_at >= 0) |

- PRIMARY KEY (provider_id,asset_key,rendition)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (2)

## 72 public_instrument_details

| Column | Data type | Constraints |
|---|---|---|
| instrument_id | INTEGER | NOT NULL REFERENCES public_instruments(id) |
| revision | INTEGER | NOT NULL CHECK (revision >= 1) |
| fetched_at | INTEGER | NOT NULL CHECK (fetched_at >= 0) |
| details_json | TEXT | NOT NULL CHECK (json_valid(details_json) AND length(CAST(details_json AS BLOB)) <= 65536) |
| content_digest | BLOB | NOT NULL CHECK (length(content_digest) = 32) |

- PRIMARY KEY (instrument_id,revision)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (3)

## 73 public_instruments

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| provider_id | INTEGER | NOT NULL REFERENCES market_providers(id) |
| provider_instrument_key | TEXT | NOT NULL CHECK (length(provider_instrument_key) BETWEEN 1 AND 256) |
| exchange | TEXT | NOT NULL CHECK (length(exchange) BETWEEN 1 AND 64) |
| symbol | TEXT | NOT NULL CHECK (length(symbol) BETWEEN 1 AND 128) |

- UNIQUE (provider_id,provider_instrument_key)
- UNIQUE (id,provider_id)
- STRICT
- ▶ Trigger constraints (3)

## 74 refund_links

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('refund_links') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| refund_transaction_id | TEXT | NOT NULL REFERENCES transactions(id) |
| original_transaction_id | TEXT | NOT NULL REFERENCES transactions(id) |
| amount_minor | INTEGER | NOT NULL CHECK (amount_minor > 0) |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |

- CHECK (refund_transaction_id <> original_transaction_id)
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- UNIQUE (refund_transaction_id,original_transaction_id)
- STRICT
- ▶ Trigger constraints (4)

## 75 scheduled_occurrences

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('scheduled_occurrences') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| schedule_id | TEXT | NOT NULL REFERENCES schedules(id) |
| schedule_revision | INTEGER | NOT NULL CHECK (schedule_revision >= 1) |
| occurrence_key | TEXT | NOT NULL CHECK (length(occurrence_key) BETWEEN 1 AND 128) |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| amount_minor | INTEGER | NULL allowed |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| amount_state | TEXT | NOT NULL CHECK (amount_state IN ('known','estimated','missing')) |
| status | TEXT | NOT NULL CHECK (status = 'expected') |

- CHECK ((amount_state = 'missing' AND amount_minor IS NULL) OR (amount_state IN ('known','estimated') AND amount_minor IS NOT NULL))
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- UNIQUE (schedule_id,occurrence_key)
- UNIQUE (schedule_id,id)
- STRICT
- ▶ Trigger constraints (6)

## 76 schedules

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('schedules') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| name | TEXT | NOT NULL CHECK (length(name) BETWEEN 1 AND 256) |
| kind | TEXT | NOT NULL CHECK (kind IN ('bill','subscription','income','investment','premium','emi','transfer','vest','tax','dividend','oneOff')) |
| account_id | TEXT | REFERENCES accounts(id) |
| amount_minor | INTEGER | NULL allowed |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| amount_state | TEXT | NOT NULL CHECK (amount_state IN ('known','estimated','missing')) |
| start_date | TEXT | NOT NULL CHECK ((length(start_date) = 10 AND start_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND start_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(start_date, '+0 days') IS start_date)) |
| end_date | TEXT | CHECK (end_date IS NULL OR (length(end_date) = 10 AND end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND end_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(end_date, '+0 days') IS end_date)) |
| rrule | TEXT | CHECK (rrule IS NULL OR length(rrule) <= 4096) |
| is_one_off | INTEGER | NOT NULL CHECK (is_one_off IN (0,1)) |

- CHECK (end_date IS NULL OR end_date >= start_date)
- CHECK ((is_one_off = 1 AND rrule IS NULL) OR (is_one_off = 0 AND rrule IS NOT NULL))
- CHECK ((amount_state = 'missing' AND amount_minor IS NULL) OR (amount_state IN ('known','estimated') AND amount_minor IS NOT NULL))
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 77 search_documents

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| transaction_id | TEXT | REFERENCES transactions(id) |
| account_id | TEXT | REFERENCES accounts(id) |
| merchant | TEXT | NOT NULL DEFAULT '' |
| note | TEXT | NOT NULL DEFAULT '' |
| account_name | TEXT | NOT NULL DEFAULT '' |

- CHECK ((transaction_id IS NOT NULL) + (account_id IS NOT NULL) = 1)
- STRICT
- CREATE UNIQUE INDEX search_account ON search_documents(account_id) WHERE account_id IS NOT NULL
- CREATE UNIQUE INDEX search_transaction ON search_documents(transaction_id) WHERE transaction_id IS NOT NULL

## 78 search_fts

| Column | Data type | Constraints |
|---|---|---|
| merchant | Not declared | — |
| note | Not declared | — |
| account_name | Not declared | — |

- FTS5 VIRTUAL TABLE
- content='search_documents'
- content_rowid='id'
- tokenize='unicode61 remove_diacritics 2'

## 79 securities

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('securities') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| symbol | TEXT | NOT NULL CHECK (length(symbol) BETWEEN 1 AND 128) |
| exchange | TEXT | NOT NULL CHECK (length(exchange) BETWEEN 1 AND 64) |
| name | TEXT | NOT NULL CHECK (length(name) BETWEEN 1 AND 256) |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| type | TEXT | NOT NULL CHECK (type IN ('stock','etf','fund','bond','gold','crypto','cash','other')) |
| asset_class | TEXT | NOT NULL CHECK (asset_class IN ('stocks','equityEtfs','mutualFunds','bonds','gold','cash','other')) |
| public_instrument_id | INTEGER | REFERENCES public_instruments(id) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 80 settlement_allocations

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('settlement_allocations') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| obligation_id | TEXT | NOT NULL |
| transaction_id | TEXT | NOT NULL |
| amount_minor | INTEGER | NOT NULL CHECK (amount_minor > 0) |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- FOREIGN KEY (obligation_id,currency) REFERENCES obligations(id,currency)
- FOREIGN KEY (transaction_id,currency) REFERENCES transactions(id,currency)
- STRICT
- CREATE UNIQUE INDEX settlement_pair_live ON settlement_allocations(obligation_id,transaction_id) WHERE deleted_at IS NULL
- ▶ Trigger constraints (4)

## 81 source_claims

| Column | Data type | Constraints |
|---|---|---|
| source_identity_id | INTEGER | PRIMARY KEY REFERENCES source_identities(id) |
| batch_id | TEXT | REFERENCES import_batches(id) |
| draft_id | TEXT | REFERENCES draft_headers(id) |
| status | TEXT | NOT NULL CHECK (status IN ('staged','accepted','discarded','undone')) |
| decided_operation_id | TEXT | REFERENCES operation_receipts(operation_id) |

- CHECK ((batch_id IS NOT NULL) + (draft_id IS NOT NULL) = 1)
- CHECK ((status IN ('accepted','undone') AND decided_operation_id IS NOT NULL) OR status IN ('staged','discarded'))
- STRICT
- ▶ Trigger constraints (2)

## 82 source_event_links

| Column | Data type | Constraints |
|---|---|---|
| source_identity_id | INTEGER | NOT NULL REFERENCES source_identities(id) |
| event_id | TEXT | NOT NULL REFERENCES financial_events(id) |
| operation_id | TEXT | NOT NULL REFERENCES operation_receipts(operation_id) DEFERRABLE INITIALLY DEFERRED |

- PRIMARY KEY (source_identity_id,event_id)
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (4)

## 83 source_identities

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| namespace | TEXT | NOT NULL CHECK (length(namespace) BETWEEN 1 AND 128) |
| account_scope | TEXT | NOT NULL CHECK (length(account_scope) BETWEEN 1 AND 256) |
| source_record_id | TEXT | NOT NULL CHECK (length(source_record_id) BETWEEN 1 AND 1024) |
| identity_version | INTEGER | NOT NULL CHECK (identity_version >= 1) |
| first_seen_at | INTEGER | NOT NULL CHECK (first_seen_at >= 0) |

- UNIQUE (namespace,account_scope,source_record_id)
- STRICT
- ▶ Trigger constraints (4)

## 84 staged_rows

| Column | Data type | Constraints |
|---|---|---|
| id | INTEGER | PRIMARY KEY |
| batch_id | TEXT | NOT NULL REFERENCES import_batches(id) |
| row_ordinal | INTEGER | NOT NULL CHECK (row_ordinal >= 0) |
| source_identity_id | INTEGER | NOT NULL REFERENCES source_identities(id) |
| payload_json | TEXT | NOT NULL CHECK (json_valid(payload_json) AND length(CAST(payload_json AS BLOB)) <= 262144) |
| payload_schema_version | INTEGER | NOT NULL CHECK (payload_schema_version >= 1) |

- UNIQUE (batch_id,row_ordinal)
- UNIQUE (batch_id,source_identity_id)
- STRICT
- ▶ Trigger constraints (2)

## 85 summary_buckets

| Column | Data type | Constraints |
|---|---|---|
| generation_id | INTEGER | NOT NULL REFERENCES projection_generations(id) ON DELETE CASCADE |
| bucket_key | TEXT | NOT NULL |
| group_key | TEXT | NOT NULL |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| amount_minor | INTEGER | NULL allowed |
| value_state | TEXT | NOT NULL CHECK (value_state IN ('known','estimated','missing')) |
| known_count | INTEGER | NOT NULL CHECK (known_count >= 0) |
| missing_count | INTEGER | NOT NULL CHECK (missing_count >= 0) |

- PRIMARY KEY (generation_id,bucket_key,group_key,currency)
- CHECK ((value_state = 'missing' AND amount_minor IS NULL) OR (value_state IN ('known','estimated') AND amount_minor IS NOT NULL))
- STRICT, WITHOUT ROWID
- ▶ Trigger constraints (5)

## 86 transaction_candidate_keys

| Column | Data type | Constraints |
|---|---|---|
| transaction_id | TEXT | PRIMARY KEY NOT NULL REFERENCES transactions(id) |
| content_digest | BLOB | NOT NULL CHECK (length(content_digest) = 32) |
| normalization_version | INTEGER | NOT NULL CHECK (normalization_version >= 1) |

- STRICT, WITHOUT ROWID

## 87 transaction_splits

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('transaction_splits') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| transaction_id | TEXT | NOT NULL REFERENCES transactions(id) |
| category_id | TEXT | REFERENCES categories(id) |
| amount_minor | INTEGER | NOT NULL |
| currency | TEXT | NOT NULL |
| note | TEXT | CHECK (note IS NULL OR length(note) <= 16384) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- FOREIGN KEY (transaction_id,currency) REFERENCES transactions(id, currency)
- STRICT
- ▶ Trigger constraints (4)

## 88 transactions

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('transactions') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| event_id | TEXT | NOT NULL REFERENCES financial_events(id) |
| account_id | TEXT | NOT NULL |
| date | TEXT | NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)) |
| amount_minor | INTEGER | NOT NULL |
| currency | TEXT | NOT NULL REFERENCES currencies(code) |
| kind | TEXT | NOT NULL CHECK (kind IN ('expense','income','transfer','refund','fee','loanIn','saleProceeds')) |
| merchant_name | TEXT | CHECK (merchant_name IS NULL OR length(merchant_name) <= 512) |
| note | TEXT | CHECK (note IS NULL OR length(note) <= 16384) |
| category_id | TEXT | REFERENCES categories(id) |
| source | TEXT | NOT NULL CHECK (source IN ('imported','captured','manual','computed')) |
| is_estimated | INTEGER | NOT NULL DEFAULT 0 CHECK (is_estimated IN (0,1)) |

- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- FOREIGN KEY (account_id, currency) REFERENCES accounts(id, currency)
- UNIQUE (id, currency)
- STRICT
- ▶ Trigger constraints (4)

## 89 transfer_fx

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('transfer_fx') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| transfer_link_id | TEXT | NOT NULL UNIQUE REFERENCES transfer_links(id) |
| executed_rate_decimal | TEXT | NOT NULL ▶ CHECK constraint |
| comparison_rate_decimal | TEXT | ▶ CHECK constraint |
| comparison_rate_date | TEXT | ▶ CHECK constraint |
| service | TEXT | CHECK (service IS NULL OR length(service) <= 256) |

- CHECK ((comparison_rate_decimal IS NULL) = (comparison_rate_date IS NULL))
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- ▶ Trigger constraints (4)

## 90 transfer_links

| Column | Data type | Constraints |
|---|---|---|
| id | TEXT | PRIMARY KEY NOT NULL ▶ CHECK constraint |
| entity_kind | TEXT | GENERATED ALWAYS AS ('transfer_links') VIRTUAL |
| created_at | INTEGER | NOT NULL CHECK (created_at >= 0) |
| updated_at | INTEGER | NOT NULL CHECK (updated_at >= 0) |
| deleted_at | INTEGER | CHECK (deleted_at IS NULL OR deleted_at >= 0) |
| revision | INTEGER | NOT NULL DEFAULT 1 CHECK (revision >= 1) |
| event_id | TEXT | NOT NULL REFERENCES financial_events(id) |
| sending_transaction_id | TEXT | NOT NULL REFERENCES transactions(id) |
| receiving_transaction_id | TEXT | NOT NULL REFERENCES transactions(id) |
| fee_transaction_id | TEXT | REFERENCES transactions(id) |

- CHECK (sending_transaction_id <> receiving_transaction_id)
- CHECK (fee_transaction_id IS NULL OR (fee_transaction_id <> sending_transaction_id AND fee_transaction_id <> receiving_transaction_id))
- FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
- STRICT
- CREATE UNIQUE INDEX transfer_event_live ON transfer_links(event_id) WHERE deleted_at IS NULL
- CREATE UNIQUE INDEX transfer_fee_live ON transfer_links(fee_transaction_id) WHERE deleted_at IS NULL AND fee_transaction_id IS NOT NULL
- CREATE UNIQUE INDEX transfer_receiving_live ON transfer_links(receiving_transaction_id) WHERE deleted_at IS NULL
- CREATE UNIQUE INDEX transfer_sending_live ON transfer_links(sending_transaction_id) WHERE deleted_at IS NULL
- ▶ Trigger constraints (4)
