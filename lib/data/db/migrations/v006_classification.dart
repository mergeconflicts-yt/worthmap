// P12 (DATABASE_DESIGN 4.1, 5; SPEC 9.3): schema version 6 adds the
// classification family: `category_rules`, `tags` and `transaction_tags`.
//
// Small migration per family (DATABASE_DESIGN 5): authored tables carry the
// reference identity, audit and revision guards, plus the insert trigger that
// registers the row for typed history. `transaction_tags` is a bridge keyed by
// its two foreign keys, like `event_attachments`; it is not an authored entity
// and writes no ChangeLog row of its own.
//
// Reference version 5 body: SCHEMA.sql. This migration runs once, in one
// transaction, and never rewrites an existing row.

const String migrationV6Sql = r'''
CREATE TABLE category_rules (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('category_rules') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  match_type TEXT NOT NULL CHECK (match_type IN ('merchantEquals','merchantContains','regex','amountRange')),
  pattern TEXT NOT NULL CHECK (length(pattern) BETWEEN 1 AND 512),
  category_id TEXT NOT NULL REFERENCES categories(id),
  priority INTEGER NOT NULL DEFAULT 0,
  created_from TEXT NOT NULL CHECK (created_from IN ('user','learned','default')),
  hit_count INTEGER NOT NULL DEFAULT 0 CHECK (hit_count >= 0),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE tags (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('tags') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 64),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE transaction_tags (
  transaction_id TEXT NOT NULL REFERENCES transactions(id),
  tag_id TEXT NOT NULL REFERENCES tags(id),
  PRIMARY KEY (transaction_id, tag_id)
) STRICT, WITHOUT ROWID;

CREATE UNIQUE INDEX tags_name_live ON tags(name) WHERE deleted_at IS NULL;
CREATE INDEX category_rules_priority ON category_rules(priority DESC, id) WHERE deleted_at IS NULL;
CREATE INDEX category_rules_category ON category_rules(category_id) WHERE deleted_at IS NULL;
CREATE INDEX transaction_tags_tag ON transaction_tags(tag_id);

CREATE TRIGGER category_rules_identity AFTER INSERT ON category_rules BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'category_rules'); END;
CREATE TRIGGER category_rules_revision BEFORE UPDATE ON category_rules WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER category_rules_retain BEFORE DELETE ON category_rules BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;
CREATE TRIGGER tags_identity AFTER INSERT ON tags BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'tags'); END;
CREATE TRIGGER tags_revision BEFORE UPDATE ON tags WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER tags_retain BEFORE DELETE ON tags BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;

CREATE TRIGGER guard_category_rules_insert BEFORE INSERT ON category_rules WHEN EXISTS (SELECT 1 FROM category_rules AS q WHERE (q.id = NEW.id)) BEGIN SELECT RAISE(ABORT, 'existing_protected_identity'); END;
CREATE TRIGGER guard_category_rules_update BEFORE UPDATE ON category_rules WHEN NEW.id IS NOT OLD.id OR EXISTS (SELECT 1 FROM category_rules AS q WHERE (q.id = NEW.id) AND NOT (q.id IS OLD.id)) BEGIN SELECT RAISE(ABORT, 'protected_identity_conflict'); END;
CREATE TRIGGER guard_tags_insert BEFORE INSERT ON tags WHEN EXISTS (SELECT 1 FROM tags AS q WHERE (q.id = NEW.id)) BEGIN SELECT RAISE(ABORT, 'existing_protected_identity'); END;
CREATE TRIGGER guard_tags_update BEFORE UPDATE ON tags WHEN NEW.id IS NOT OLD.id OR EXISTS (SELECT 1 FROM tags AS q WHERE (q.id = NEW.id) AND NOT (q.id IS OLD.id)) BEGIN SELECT RAISE(ABORT, 'protected_identity_conflict'); END;
CREATE TRIGGER guard_transaction_tags_insert BEFORE INSERT ON transaction_tags WHEN EXISTS (SELECT 1 FROM transaction_tags AS q WHERE (q.transaction_id = NEW.transaction_id AND q.tag_id = NEW.tag_id)) BEGIN SELECT RAISE(ABORT, 'existing_protected_identity'); END;
''';
