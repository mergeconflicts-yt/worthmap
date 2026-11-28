// P4-02b (SPEC 9.2; DATABASE_DESIGN 4.1; DECISIONS P4-RULE-STORAGE):
// schema version 10 adds the value rule and the card and loan details.
//
// Each row is authored one-to-one metadata on a canonical account. The rule
// holds the method and its bounded JSON parameters. The real value stays the
// selected balance anchor, so metadata holds no second balance
// (DATABASE_DESIGN 4.2).

const String migrationV10Sql = r'''
CREATE TABLE valuation_rules (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('valuation_rules') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  account_id TEXT NOT NULL UNIQUE REFERENCES accounts(id),
  method TEXT NOT NULL CHECK (method IN ('marketPrice','interest','contribution','weightPrice','manual','depreciation','capitalAccount')),
  parameters_json TEXT NOT NULL CHECK (json_valid(parameters_json) AND length(CAST(parameters_json AS BLOB)) <= 4096),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE TRIGGER valuation_rules_identity AFTER INSERT ON valuation_rules BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'valuation_rules'); END;
CREATE TRIGGER valuation_rules_revision BEFORE UPDATE ON valuation_rules WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER valuation_rules_retain BEFORE DELETE ON valuation_rules BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;

CREATE TABLE card_details (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('card_details') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  account_id TEXT NOT NULL UNIQUE REFERENCES accounts(id),
  credit_limit_minor INTEGER NOT NULL CHECK (credit_limit_minor >= 0),
  statement_day INTEGER NOT NULL CHECK (statement_day BETWEEN 1 AND 31),
  due_day INTEGER NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  minimum_rule_json TEXT NOT NULL CHECK (json_valid(minimum_rule_json) AND length(CAST(minimum_rule_json AS BLOB)) <= 1024),
  paying_account_id TEXT REFERENCES accounts(id),
  annual_fee_minor INTEGER CHECK (annual_fee_minor IS NULL OR annual_fee_minor >= 0),
  annual_fee_date TEXT CHECK (annual_fee_date IS NULL OR (length(annual_fee_date) = 10 AND annual_fee_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND annual_fee_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(annual_fee_date, '+0 days') IS annual_fee_date)),
  CHECK ((annual_fee_minor IS NULL) = (annual_fee_date IS NULL)),
  CHECK (paying_account_id IS NULL OR paying_account_id <> account_id),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE TRIGGER card_details_identity AFTER INSERT ON card_details BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'card_details'); END;
CREATE TRIGGER card_details_revision BEFORE UPDATE ON card_details WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER card_details_retain BEFORE DELETE ON card_details BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;

CREATE TABLE loan_details (
  id TEXT PRIMARY KEY NOT NULL CHECK ( length(CAST(id AS BLOB)) = 36 AND instr(id,char(0)) = 0 AND substr(id,9,1) = '-' AND substr(id,14,1) = '-' AND substr(id,19,1) = '-' AND substr(id,24,1) = '-' AND substr(id,15,1) = '7' AND substr(id,20,1) IN ('8','9','a','b') AND length(replace(id,'-','')) = 32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*' ),
  entity_kind TEXT GENERATED ALWAYS AS ('loan_details') VIRTUAL,
  created_at INTEGER NOT NULL CHECK (created_at >= 0),
  updated_at INTEGER NOT NULL CHECK (updated_at >= 0),
  deleted_at INTEGER CHECK (deleted_at IS NULL OR deleted_at >= 0),
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
  account_id TEXT NOT NULL UNIQUE REFERENCES accounts(id),
  original_minor INTEGER NOT NULL CHECK (original_minor >= 0),
  rate_decimal TEXT NOT NULL CHECK (instr(rate_decimal, char(0)) = 0 AND typeof(rate_decimal) = 'text' AND length(rate_decimal) BETWEEN 1 AND 78 AND rate_decimal NOT GLOB '*[^0-9.-]*' AND length(replace(replace(rate_decimal,'-',''),'.','')) BETWEEN 1 AND 76 AND instr(substr(rate_decimal,2),'-') = 0 AND length(rate_decimal) - length(replace(rate_decimal,'.','')) <= 1 AND substr((CASE WHEN substr(rate_decimal,1,1) = '-' THEN substr(rate_decimal,2) ELSE rate_decimal END),1,1) BETWEEN '0' AND '9' AND substr(rate_decimal,-1) BETWEEN '0' AND '9' AND (CASE WHEN substr(rate_decimal,1,1) = '-' THEN substr(rate_decimal,2) ELSE rate_decimal END) NOT GLOB '0[0-9]*' AND rate_decimal <> '-0' AND (instr(rate_decimal,'.') = 0 OR (substr(rate_decimal,-1) < '0' AND length(rate_decimal) - instr(rate_decimal,'.') <= 38))),
  rate_type TEXT NOT NULL CHECK (rate_type IN ('fixed','floating')),
  next_reset_date TEXT CHECK (next_reset_date IS NULL OR (length(next_reset_date) = 10 AND next_reset_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND next_reset_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(next_reset_date, '+0 days') IS next_reset_date)),
  emi_minor INTEGER NOT NULL CHECK (emi_minor >= 0),
  emi_day INTEGER NOT NULL CHECK (emi_day BETWEEN 1 AND 31),
  end_date TEXT CHECK (end_date IS NULL OR (length(end_date) = 10 AND end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND end_date BETWEEN '0001-01-01' AND '9999-12-31' AND date(end_date, '+0 days') IS end_date)),
  prepayment_rule TEXT CHECK (prepayment_rule IS NULL OR length(prepayment_rule) <= 1024),
  paying_account_id TEXT REFERENCES accounts(id),
  linked_asset_id TEXT REFERENCES accounts(id),
  CHECK (paying_account_id IS NULL OR paying_account_id <> account_id),
  CHECK (linked_asset_id IS NULL OR linked_asset_id <> account_id),
  FOREIGN KEY (id, entity_kind) REFERENCES entity_registry(id, entity_kind) DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE TRIGGER loan_details_identity AFTER INSERT ON loan_details BEGIN INSERT INTO entity_registry(id, entity_kind) VALUES (NEW.id, 'loan_details'); END;
CREATE TRIGGER loan_details_revision BEFORE UPDATE ON loan_details WHEN NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.revision < OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'invalid_entity_revision'); END;
CREATE TRIGGER loan_details_retain BEFORE DELETE ON loan_details BEGIN SELECT RAISE(ABORT, 'authored_record_requires_soft_delete'); END;
''';
