import '../models/route_payload.dart';

class SportsObjectRouter {
  const SportsObjectRouter();

  RoutePayload packageRows({
    required String datasetId,
    required String displayLabel,
    required String sourceObjectType,
    required List<Map<String, dynamic>> rows,
    required String targetRoute,
    String? packageId,
    String sourceSnapshot = 'Local Sports Terminal asset',
    String readinessState = 'Ready',
    String filterSummary = 'No filters',
    String rowKey = '',
    List<String> blockers = const [],
    Map<String, dynamic> metadata = const {},
    List<String> preferredColumns = const [],
    int maxRows = 250,
  }) {
    final normalizedRows = [
      for (final row in rows.take(maxRows)) _normalizeRow(row),
    ];
    final keys = _orderedKeys(normalizedRows, preferredColumns);
    final columns = [
      for (final key in keys)
        RoutePayloadColumn(
          key: key,
          label: _labelFor(key),
          dataType: _dataTypeFor(key, normalizedRows),
          unit: _unitFor(key),
        ),
    ];
    final selectedRows = <String>[];
    for (var index = 0; index < normalizedRows.length; index++) {
      final row = normalizedRows[index];
      final candidate = rowKey.isEmpty ? null : row[rowKey];
      selectedRows.add(candidate?.toString() ?? '${index + 1}');
    }

    return RoutePayload(
      sourceObjectType: sourceObjectType,
      sourceObjectId: packageId ?? datasetId,
      displayLabel: displayLabel,
      selectedColumns: keys,
      selectedRows: selectedRows,
      filterSummary: filterSummary,
      sourceSnapshot: sourceSnapshot,
      readinessState: readinessState,
      blockers: blockers,
      targetRoute: targetRoute,
      availableActions: immediateRouteTargets,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      columns: columns,
      rows: normalizedRows,
      metadata: {
        'datasetId': datasetId,
        'rowKey': rowKey,
        'untruncatedRowCount': rows.length,
        'packagedRowCount': normalizedRows.length,
        'truncated': rows.length > normalizedRows.length,
        ...metadata,
      },
    );
  }

  String toTsv(RoutePayload payload) {
    final keys = payload.columns.isNotEmpty
        ? [for (final column in payload.columns) column.key]
        : payload.selectedColumns;
    if (keys.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln(keys.map(_escapeTsv).join('\t'));
    for (final row in payload.rows) {
      buffer.writeln(
        keys.map((key) => _escapeTsv(_displayValue(row[key]))).join('\t'),
      );
    }
    return buffer.toString().trimRight();
  }

  String pythonVariableName(RoutePayload payload) {
    final raw = payload.metadata['datasetId']?.toString() ?? payload.sourceObjectId;
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) return 'sports_data';
    if (RegExp(r'^\d').hasMatch(normalized)) return 'data_$normalized';
    return normalized;
  }

  String generatedPython(RoutePayload payload) {
    final variable = pythonVariableName(payload);
    final escapedLabel = payload.displayLabel.replaceAll('"', '\\"');
    return '''# Sports Terminal structured package
# Source: $escapedLabel
# Rows: ${payload.rowCount} | Columns: ${payload.columnCount}

import pandas as pd

$variable = st.active_payload_dataframe()

# Inspect and rank the routed data
st.display($variable.head(25))
st.display($variable.describe(include="all"))

# Example export back to the workbook
st.export_to_workspace($variable, sheet="$escapedLabel")
''';
  }

  List<String> _orderedKeys(
    List<Map<String, dynamic>> rows,
    List<String> preferred,
  ) {
    final discovered = <String>{};
    for (final row in rows) {
      discovered.addAll(row.keys);
    }
    final result = <String>[];
    for (final key in preferred) {
      if (discovered.remove(key)) result.add(key);
    }
    final remainder = discovered.toList()..sort();
    result.addAll(remainder);
    return result;
  }

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> row) {
    return {
      for (final entry in row.entries)
        entry.key: _normalizeValue(entry.value),
    };
  }

  dynamic _normalizeValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Iterable) return value.map((item) => item.toString()).join(', ');
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }
    return value.toString();
  }

  String _dataTypeFor(String key, List<Map<String, dynamic>> rows) {
    final values = [
      for (final row in rows)
        if (row[key] != null) row[key],
    ];
    if (values.isEmpty) return 'text';
    if (values.every((value) => value is bool)) return 'boolean';
    if (values.every((value) => value is num)) {
      if (values.every((value) => value is int)) return 'integer';
      return 'number';
    }
    if (key.contains('date') || key.endsWith('_at')) return 'date';
    return 'text';
  }

  String _unitFor(String key) {
    final normalized = key.toLowerCase();
    if (normalized.contains('salary') ||
        normalized.contains('cap') ||
        normalized.contains('tax') ||
        normalized.contains('apron') ||
        normalized.contains('cash')) {
      return 'USD';
    }
    if (normalized.endsWith('_pct') ||
        normalized.contains('percentage') ||
        normalized == 'win_pct') {
      return 'ratio';
    }
    if (normalized.contains('minutes')) return 'minutes';
    if (normalized.contains('age')) return 'years';
    return '';
  }

  String _labelFor(String key) {
    final words = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .trim()
        .split(RegExp(r'\s+'));
    return words
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _escapeTsv(String value) {
    return value
        .replaceAll('\t', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');
  }

  String _displayValue(dynamic value) {
    if (value == null) return '';
    if (value is double) {
      return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
    }
    return value.toString();
  }
}
