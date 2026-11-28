// P4-HOME-SPLIT (SPEC 4.4, 9.3; C03): schema version 9 adds the user's
// category tag that separates Needs from Wants.
//
// `is_essential` is the user's own label, never a judgement: 1 = a need,
// 0 = a want, NULL = not tagged yet. SPEC 4.4 defines Needs and Wants from
// this tag. The migration adds no financial rule and no default.

const String migrationV9Sql = r'''
ALTER TABLE categories ADD COLUMN is_essential INTEGER CHECK (is_essential IS NULL OR is_essential IN (0,1));
''';
