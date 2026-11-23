// T07 (DATABASE_DESIGN 5.1, DB4-10): statement splitting for the translated
// reference DDL.
//
// The reference schema keeps `BEGIN ... END;` inside trigger bodies, so a
// plain `;` split would break them. This splitter only terminates a statement
// on a `;` that sits outside a trigger body. The migration tests execute the
// whole generated constant and assert the exact table and trigger counts
// (89 tables, 332 triggers), which proves the split kept every statement.
library;

/// Splits a SQL script into single statements.
///
/// Assumption, verified by the generated schema tests: quoted strings in the
/// reference DDL never contain the words BEGIN or END and never contain a
/// stray semicolon. A violation would surface immediately as a syntax error
/// or a wrong object count in the migration tests.
List<String> splitSqlStatements(String sql) {
  final statements = <String>[];
  final buffer = StringBuffer();
  var triggerDepth = 0;

  for (final match in RegExp(r'[A-Za-z]+|[^A-Za-z]+').allMatches(sql)) {
    final token = match.group(0)!;
    if (token.startsWith(RegExp(r'[A-Za-z]'))) {
      final upper = token.toUpperCase();
      if (upper == 'BEGIN') {
        triggerDepth++;
      } else if (upper == 'END' && triggerDepth > 0) {
        triggerDepth--;
      }
      buffer.write(token);
    } else {
      for (var i = 0; i < token.length; i++) {
        final ch = token[i];
        if (ch == ';' && triggerDepth == 0) {
          final statement = buffer.toString().trim();
          buffer.clear();
          if (statement.isNotEmpty) {
            statements.add(statement);
          }
        } else {
          buffer.write(ch);
        }
      }
    }
  }

  final rest = buffer.toString().trim();
  if (rest.isNotEmpty) {
    statements.add(rest);
  }
  return statements;
}
