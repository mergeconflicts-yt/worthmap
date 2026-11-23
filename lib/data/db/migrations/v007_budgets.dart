// P15 (SPEC 9.3; DATABASE_DESIGN 5, 8): schema version 7 adds the budget
// family: `budgets`, `budget_limits` and `budget_templates`.
//
// Small migration per family. A budget is one local budget month with its
// currency and boundaries. A limit is the authored amount for one category
// in that budget; a template keeps the same amount for the next month
// ("each month fresh", SCREENS X33). Each row carries the reference identity,
// audit, revision and retain guards, and the insert trigger that registers it
// for typed history (AGENTS 6.5).
//
// No financial rule lives here. A limit of zero is not a limit (SPEC 4.4);
// the writer removes it instead of storing it. Limits never post money.

const String migrationV7Sql = r'''
CREATE TABLE budgets (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('budgets') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  month TEXT NOT NULL CHECK (length(month) = 7 AND month GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]' AND month BETWEEN '0001-01' AND '9999-12' AND date(month || '-01') IS month || '-01'),
  period_type TEXT NOT NULL CHECK (period_type IN ('monthly')),
  name TEXT CHECK (name IS NULL OR length(name) BETWEEN 1 AND 64),
  currency TEXT NOT NULL REFERENCES currencies(code),
  start_date TEXT NOT NULL CHECK ((length(start_date) = 10 AND start_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND start_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(start_date, '+0 days') IS start_date)),
  end_date TEXT NOT NULL CHECK ((length(end_date) = 10 AND end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND end_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(end_date, '+0 days') IS end_date)),
  CHECK (end_date >= start_date),
  CHECK (start_date >= month || '-01' AND start_date <= date(month || '-01', '+1 month', '-1 day')),
  CHECK (end_date <= date(start_date, '+31 days')),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE budget_limits (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('budget_limits') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  budget_id TEXT NOT NULL REFERENCES budgets(id),
  category_id TEXT NOT NULL REFERENCES categories(id),
  limit_minor INTEGER NOT NULL CHECK (limit_minor >= 0),
  currency TEXT NOT NULL REFERENCES currencies(code),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE budget_templates (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('budget_templates') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  category_id TEXT NOT NULL REFERENCES categories(id),
  limit_minor INTEGER NOT NULL CHECK (limit_minor >= 0),
  currency TEXT NOT NULL REFERENCES currencies(code),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE UNIQUE INDEX budgets_month_live ON budgets(month) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX budget_limits_pair_live ON budget_limits(budget_id, category_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX budget_templates_category_live ON budget_templates(category_id) WHERE deleted_at IS NULL;
CREATE INDEX budget_limits_category ON budget_limits(category_id) WHERE deleted_at IS NULL;
-- P15: a refund recognised in its purchase month reads the original date.
CREATE INDEX refund_links_original ON refund_links(original_transaction_id) WHERE deleted_at IS NULL;

CREATE TRIGGER budgets_identity AFTER INSERT ON budgets BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'budgets'); END;
CREATE TRIGGER budgets_revision BEFORE UPDATE ON budgets WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER budgets_retain BEFORE DELETE ON budgets BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;

CREATE TRIGGER budget_limits_identity AFTER INSERT ON budget_limits BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'budget_limits'); END;
CREATE TRIGGER budget_limits_revision BEFORE UPDATE ON budget_limits WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER budget_limits_retain BEFORE DELETE ON budget_limits BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;

CREATE TRIGGER budget_templates_identity AFTER INSERT ON budget_templates BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'budget_templates'); END;
CREATE TRIGGER budget_templates_revision BEFORE UPDATE ON budget_templates WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER budget_templates_retain BEFORE DELETE ON budget_templates BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;

CREATE TRIGGER guard_budgets_insert BEFORE INSERT ON budgets WHEN EXISTS (SELECT 1 FROM budgets AS q WHERE (q.id = NEW.id)) BEGIN SELECT RAISE(ABORT, 'existing_protected_identity'); END;
CREATE TRIGGER guard_budgets_update BEFORE UPDATE ON budgets WHEN NEW.id IS NOT OLD.id OR EXISTS (SELECT 1 FROM budgets AS q WHERE (q.id = NEW.id) AND NOT (q.id IS OLD.id)) BEGIN SELECT RAISE(ABORT, 'protected_identity_conflict'); END;
CREATE TRIGGER guard_budget_limits_insert BEFORE INSERT ON budget_limits WHEN EXISTS (SELECT 1 FROM budget_limits AS q WHERE (q.id = NEW.id)) BEGIN SELECT RAISE(ABORT, 'existing_protected_identity'); END;
CREATE TRIGGER guard_budget_limits_update BEFORE UPDATE ON budget_limits WHEN NEW.id IS NOT OLD.id OR EXISTS (SELECT 1 FROM budget_limits AS q WHERE (q.id = NEW.id) AND NOT (q.id IS OLD.id)) BEGIN SELECT RAISE(ABORT, 'protected_identity_conflict'); END;
CREATE TRIGGER guard_budget_templates_insert BEFORE INSERT ON budget_templates WHEN EXISTS (SELECT 1 FROM budget_templates AS q WHERE (q.id = NEW.id)) BEGIN SELECT RAISE(ABORT, 'existing_protected_identity'); END;
CREATE TRIGGER guard_budget_templates_update BEFORE UPDATE ON budget_templates WHEN NEW.id IS NOT OLD.id OR EXISTS (SELECT 1 FROM budget_templates AS q WHERE (q.id = NEW.id) AND NOT (q.id IS OLD.id)) BEGIN SELECT RAISE(ABORT, 'protected_identity_conflict'); END;
''';
