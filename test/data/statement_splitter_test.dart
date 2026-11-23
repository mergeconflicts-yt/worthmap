import 'package:contour/data/db/db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits the generated reference DDL into complete statements', () {
    // The generated constant is verified indirectly here: the splitter keeps
    // trigger bodies intact (BEGIN ... END;) and emits one statement per
    // semicolon outside a trigger body. The vault tests execute the result
    // and assert the exact object counts (89 tables, 332 triggers).
    final statements = splitSqlStatements(r'''
CREATE TABLE a (x TEXT);
CREATE TRIGGER t AFTER INSERT ON a BEGIN SELECT RAISE(ABORT, 'x'); END;
CREATE TRIGGER t2 BEFORE UPDATE ON a WHEN 1 = 1
BEGIN
SELECT RAISE(ABORT, 'y');
END;
CREATE INDEX i ON a(x);
''');
    expect(statements, hasLength(4));
    expect(statements[0], 'CREATE TABLE a (x TEXT)');
    expect(statements[1], contains("RAISE(ABORT, 'x')"));
    expect(statements[2], contains("RAISE(ABORT, 'y')"));
    expect(statements[2], contains('BEGIN'));
    expect(statements[3], 'CREATE INDEX i ON a(x)');
  });

  test('an unbalanced BEGIN is treated as trigger-body context', () {
    // The generated schema contains no standalone transaction control (the
    // generator rejects it), so this input is out of contract; documented
    // behaviour: the splitter keeps it in one chunk rather than splitting a
    // trigger body early.
    final statements = splitSqlStatements('BEGIN;\nCREATE TABLE b (y);');
    expect(statements, hasLength(1));
  });
}
