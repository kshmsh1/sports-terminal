class WorkspaceDataResult {
  const WorkspaceDataResult({
    required this.columns,
    required this.rows,
    required this.dataset,
  });

  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final String dataset;
}

class WorkspaceDataService {
  const WorkspaceDataService();

  WorkspaceDataResult run({
    required String statement,
    required Map<String, List<Map<String, Object?>>> datasets,
  }) {
    final normalized = statement.trim().replaceAll(RegExp(r'\s+'), ' ');
    final pattern = RegExp(
      r'''^select\s+(.+?)\s+from\s+([a-zA-Z0-9_]+)(?:\s+where\s+([a-zA-Z0-9_]+)\s*=\s*['"]?([^'"]+?)['"]?)?(?:\s+order\s+by\s+([a-zA-Z0-9_]+)(?:\s+(asc|desc))?)?(?:\s+limit\s+(\d+))?\s*;?$''',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(normalized);
    if (match == null) {
      throw const FormatException(
        'Use SELECT columns FROM dataset with optional WHERE, ORDER BY, and LIMIT clauses.',
      );
    }

    final columnExpression = match.group(1)!.trim();
    final datasetName = match.group(2)!.toLowerCase();
    final sourceRows = datasets[datasetName];
    if (sourceRows == null) {
      throw FormatException('Unknown internal dataset: $datasetName');
    }

    final availableColumns = sourceRows.isEmpty
        ? <String>[]
        : (sourceRows.expand((row) => row.keys).toSet().toList()..sort());
    final selectedColumns = columnExpression == '*'
        ? availableColumns
        : columnExpression
            .split(',')
            .map((column) => column.trim())
            .where((column) => column.isNotEmpty)
            .toList(growable: false);

    for (final column in selectedColumns) {
      if (!availableColumns.contains(column)) {
        throw FormatException('Unknown column "$column" for $datasetName.');
      }
    }

    final whereField = match.group(3);
    final whereValue = match.group(4)?.trim();
    final orderField = match.group(5);
    final orderDirection = match.group(6)?.toLowerCase() ?? 'asc';
    final limit = int.tryParse(match.group(7) ?? '') ?? 100;

    var rows = sourceRows.where((row) {
      if (whereField == null) return true;
      if (!row.containsKey(whereField)) {
        throw FormatException('Unknown filter column "$whereField".');
      }
      return '${row[whereField]}'.toLowerCase() == whereValue!.toLowerCase();
    }).toList(growable: true);

    if (orderField != null) {
      if (!availableColumns.contains(orderField)) {
        throw FormatException('Unknown sort column "$orderField".');
      }
      rows.sort((a, b) {
        final result = _compare(a[orderField], b[orderField]);
        return orderDirection == 'desc' ? -result : result;
      });
    }

    rows = rows.take(limit.clamp(1, 1000)).toList(growable: false);
    return WorkspaceDataResult(
      columns: selectedColumns,
      dataset: datasetName,
      rows: [
        for (final row in rows)
          {for (final column in selectedColumns) column: row[column]},
      ],
    );
  }

  int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    if (a is num && b is num) return a.compareTo(b);
    return '$a'.toLowerCase().compareTo('$b'.toLowerCase());
  }
}
