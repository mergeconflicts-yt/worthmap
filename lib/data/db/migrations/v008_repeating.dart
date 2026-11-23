// P16 (SPEC 8.17, 8.9; DATABASE_DESIGN 4.3): schema version 8 adds the
// repeating-payment facts that version 5 does not carry.
//
//   * `schedules.auto_create` records the review path. Both values still
//     require a confirmation; the column only chooses where a due proposal
//     waits (Inbox or its own detail). It never creates a payment (8.17).
//   * `price_changes` records a different actual amount as a dated
//     observation ("was $15.49", 8.9). Editing an estimate never rewrites it.
//
// The occurrence, obligation, decision and settlement tables already exist in
// the reference body. This migration adds no financial rule.

const String migrationV8Sql = r'''
ALTER TABLE schedules ADD COLUMN auto_create INTEGER NOT NULL DEFAULT 0 CHECK (auto_create IN (0,1));

CREATE TABLE price_changes (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('price_changes') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  schedule_id TEXT NOT NULL REFERENCES schedules(id),
  date TEXT NOT NULL CHECK ((length(date) = 10 AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date BETWEEN '0001-01-01' AND '9999-12-31' AND date(date, '+0 days') IS date)),
  old_minor INTEGER NOT NULL CHECK (old_minor >= 0),
  new_minor INTEGER NOT NULL CHECK (new_minor >= 0),
  currency TEXT NOT NULL REFERENCES currencies(code),
  CHECK (old_minor <> new_minor),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE INDEX price_changes_schedule ON price_changes(schedule_id, date DESC) WHERE deleted_at IS NULL;

CREATE TRIGGER price_changes_identity AFTER INSERT ON price_changes BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'price_changes'); END;
CREATE TRIGGER price_changes_revision BEFORE UPDATE ON price_changes WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER price_changes_retain BEFORE DELETE ON price_changes BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;
CREATE TRIGGER guard_price_changes_insert BEFORE INSERT ON price_changes WHEN EXISTS (SELECT 1 FROM price_changes AS q WHERE (q.id = NEW.id)) BEGIN SELECT RAISE(ABORT, 'existing_protected_identity'); END;
CREATE TRIGGER guard_price_changes_update BEFORE UPDATE ON price_changes WHEN NEW.id IS NOT OLD.id OR EXISTS (SELECT 1 FROM price_changes AS q WHERE (q.id = NEW.id) AND NOT (q.id IS OLD.id)) BEGIN SELECT RAISE(ABORT, 'protected_identity_conflict'); END;
''';
