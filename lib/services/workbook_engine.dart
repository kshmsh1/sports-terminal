import 'dart:convert';

import '../models/route_payload.dart';

class WorkbookCellPosition {
  const WorkbookCellPosition({required this.row, required this.column});

  final int row;
  final int column;
}

class WorkbookImportResult {
  const WorkbookImportResult({
    required this.cells,
    required this.rowsImported,
    required this.columnsImported,
    required this.truncatedRows,
    required this.truncatedColumns,
  });

  final Map<String, String> cells;
  final int rowsImported;
  final int columnsImported;
  final int truncatedRows;
  final int truncatedColumns;
}

String workbookColumnName(int column) {
  if (column < 1) return 'A';
  var value = column;
  final buffer = StringBuffer();
  while (value > 0) {
    final remainder = (value - 1) % 26;
    buffer.writeCharCode(65 + remainder);
    value = (value - 1) ~/ 26;
  }
  return buffer.toString().split('').reversed.join();
}

int workbookColumnIndex(String letters) {
  var column = 0;
  for (final codeUnit in letters.toUpperCase().codeUnits) {
    if (codeUnit < 65 || codeUnit > 90) return 0;
    column = column * 26 + (codeUnit - 64);
  }
  return column;
}

WorkbookCellPosition? workbookCellPosition(String cell) {
  final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(cell.trim().toUpperCase());
  if (match == null) return null;
  final row = int.tryParse(match.group(2)!);
  final column = workbookColumnIndex(match.group(1)!);
  if (row == null || row < 1 || column < 1) return null;
  return WorkbookCellPosition(row: row, column: column);
}

String workbookCellRef(int row, int column) =>
    '${workbookColumnName(column)}$row';

Map<String, String> workbookInsertRows(
  Map<String, String> cells, {
  required int atRow,
  int count = 1,
  int maxRows = 5000,
}) {
  final output = <String, String>{};
  for (final entry in cells.entries) {
    final position = workbookCellPosition(entry.key);
    if (position == null) continue;
    final shifted = position.row >= atRow ? position.row + count : position.row;
    if (shifted <= maxRows) {
      output[workbookCellRef(shifted, position.column)] = entry.value;
    }
  }
  return output;
}

Map<String, String> workbookDeleteRows(
  Map<String, String> cells, {
  required int fromRow,
  int count = 1,
}) {
  final lastDeleted = fromRow + count - 1;
  final output = <String, String>{};
  for (final entry in cells.entries) {
    final position = workbookCellPosition(entry.key);
    if (position == null) continue;
    if (position.row >= fromRow && position.row <= lastDeleted) continue;
    final shifted = position.row > lastDeleted
        ? position.row - count
        : position.row;
    output[workbookCellRef(shifted, position.column)] = entry.value;
  }
  return output;
}

Map<String, String> workbookInsertColumns(
  Map<String, String> cells, {
  required int atColumn,
  int count = 1,
  int maxColumns = 702,
}) {
  final output = <String, String>{};
  for (final entry in cells.entries) {
    final position = workbookCellPosition(entry.key);
    if (position == null) continue;
    final shifted = position.column >= atColumn
        ? position.column + count
        : position.column;
    if (shifted <= maxColumns) {
      output[workbookCellRef(position.row, shifted)] = entry.value;
    }
  }
  return output;
}

Map<String, String> workbookDeleteColumns(
  Map<String, String> cells, {
  required int fromColumn,
  int count = 1,
}) {
  final lastDeleted = fromColumn + count - 1;
  final output = <String, String>{};
  for (final entry in cells.entries) {
    final position = workbookCellPosition(entry.key);
    if (position == null) continue;
    if (position.column >= fromColumn &&
        position.column <= lastDeleted) {
      continue;
    }
    final shifted = position.column > lastDeleted
        ? position.column - count
        : position.column;
    output[workbookCellRef(position.row, shifted)] = entry.value;
  }
  return output;
}

Object? workbookEvaluateCell(
  String cell,
  Map<String, String> cells, {
  Set<String>? visiting,
}) {
  final normalized = cell.trim().toUpperCase();
  final raw = cells[normalized] ?? '';
  if (!raw.startsWith('=')) return _primitive(raw);
  final stack = visiting ?? <String>{};
  if (!stack.add(normalized)) return '#CYCLE!';
  final result = workbookEvaluateFormula(
    raw.substring(1),
    cells,
    visiting: stack,
  );
  stack.remove(normalized);
  return result;
}

Object? workbookEvaluateFormula(
  String formula,
  Map<String, String> cells, {
  Set<String>? visiting,
}) {
  final expression = formula.trim().toUpperCase();
  if (expression.isEmpty) return '';
  final function = RegExp(
    r'^(SUM|AVERAGE|AVG|MIN|MAX|COUNT)\(([^)]*)\)$',
  ).firstMatch(expression);
  if (function != null) {
    final values = _formulaValues(
      function.group(2) ?? '',
      cells,
      visiting: visiting,
    );
    final numeric = <double>[
      for (final value in values)
        if (_number(value) != null) _number(value)!,
    ];
    return switch (function.group(1)) {
      'SUM' => numeric.fold<double>(0, (sum, value) => sum + value),
      'AVERAGE' || 'AVG' => numeric.isEmpty
          ? '#DIV/0!'
          : numeric.fold<double>(0, (sum, value) => sum + value) /
              numeric.length,
      'MIN' => numeric.isEmpty
          ? '#VALUE!'
          : numeric.reduce((a, b) => a < b ? a : b),
      'MAX' => numeric.isEmpty
          ? '#VALUE!'
          : numeric.reduce((a, b) => a > b ? a : b),
      'COUNT' => numeric.length,
      _ => '#VALUE!',
    };
  }

  final binary = RegExp(
    r'^([A-Z]+\d+|-?\d+(?:\.\d+)?)\s*([+\-*/])\s*([A-Z]+\d+|-?\d+(?:\.\d+)?)$',
  ).firstMatch(expression);
  if (binary != null) {
    final left = _operand(binary.group(1)!, cells, visiting: visiting);
    final right = _operand(binary.group(3)!, cells, visiting: visiting);
    if (left == null || right == null) return '#VALUE!';
    return switch (binary.group(2)) {
      '+' => left + right,
      '-' => left - right,
      '*' => left * right,
      '/' => right == 0 ? '#DIV/0!' : left / right,
      _ => '#VALUE!',
    };
  }

  final directPosition = workbookCellPosition(expression);
  if (directPosition != null) {
    return workbookEvaluateCell(expression, cells, visiting: visiting);
  }
  return _primitive(expression);
}

String workbookDisplayValue(String cell, Map<String, String> cells) {
  final value = workbookEvaluateCell(cell, cells);
  if (value is double) {
    if (value.isNaN || value.isInfinite) return '#VALUE!';
    return value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return value?.toString() ?? '';
}

List<List<String>> workbookParseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    if (character == '"') {
      if (quoted && index + 1 < text.length && text[index + 1] == '"') {
        cell.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
      continue;
    }
    if (!quoted && character == ',') {
      row.add(cell.toString());
      cell.clear();
      continue;
    }
    if (!quoted && (character == '\n' || character == '\r')) {
      if (character == '\r' && index + 1 < text.length && text[index + 1] == '\n') {
        index++;
      }
      row.add(cell.toString());
      cell.clear();
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
      row = <String>[];
      continue;
    }
    cell.write(character);
  }
  row.add(cell.toString());
  if (row.any((value) => value.isNotEmpty)) rows.add(row);
  return rows;
}

WorkbookImportResult workbookImportMatrix(
  List<List<Object?>> matrix, {
  int startRow = 1,
  int startColumn = 1,
  int maxRows = 5000,
  int maxColumns = 702,
}) {
  final output = <String, String>{};
  var importedRows = 0;
  var importedColumns = 0;
  var truncatedRows = 0;
  var truncatedColumns = 0;
  for (var rowIndex = 0; rowIndex < matrix.length; rowIndex++) {
    final targetRow = startRow + rowIndex;
    if (targetRow > maxRows) {
      truncatedRows++;
      continue;
    }
    importedRows++;
    final row = matrix[rowIndex];
    var rowColumns = 0;
    for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
      final targetColumn = startColumn + columnIndex;
      if (targetColumn > maxColumns) {
        truncatedColumns++;
        continue;
      }
      rowColumns++;
      final value = row[columnIndex];
      if (value != null && value.toString().isNotEmpty) {
        output[workbookCellRef(targetRow, targetColumn)] = value.toString();
      }
    }
    if (rowColumns > importedColumns) importedColumns = rowColumns;
  }
  return WorkbookImportResult(
    cells: output,
    rowsImported: importedRows,
    columnsImported: importedColumns,
    truncatedRows: truncatedRows,
    truncatedColumns: truncatedColumns,
  );
}

WorkbookImportResult workbookImportRoutePayload(
  RoutePayload payload, {
  int maxRows = 5000,
  int maxColumns = 702,
}) {
  final columns = payload.columns.isNotEmpty
      ? payload.columns
      : <RoutePayloadColumn>[
          for (final key in payload.rows.expand((row) => row.keys).toSet())
            RoutePayloadColumn(key: key, label: key),
        ];
  final matrix = <List<Object?>>[
    [for (final column in columns) column.label],
    for (final row in payload.rows)
      [for (final column in columns) row[column.key]],
  ];
  return workbookImportMatrix(
    matrix,
    maxRows: maxRows,
    maxColumns: maxColumns,
  );
}

String workbookToCsv(
  Map<String, String> cells, {
  required int rowCount,
  required int columnCount,
  bool evaluated = false,
}) {
  final lines = <String>[];
  for (var row = 1; row <= rowCount; row++) {
    final values = <String>[];
    for (var column = 1; column <= columnCount; column++) {
      final ref = workbookCellRef(row, column);
      final value = evaluated ? workbookDisplayValue(ref, cells) : cells[ref] ?? '';
      values.add(_csvEscape(value));
    }
    lines.add(values.join(','));
  }
  return lines.join('\n');
}

Map<String, String> workbookDecodeJsonCells(String encoded) {
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
  } catch (_) {
    return {};
  }
  return {};
}

List<Object?> _formulaValues(
  String arguments,
  Map<String, String> cells, {
  Set<String>? visiting,
}) {
  final output = <Object?>[];
  for (final argument in arguments.split(',')) {
    final part = argument.trim();
    if (part.isEmpty) continue;
    final range = part.split(':');
    if (range.length == 2) {
      final start = workbookCellPosition(range.first);
      final end = workbookCellPosition(range.last);
      if (start == null || end == null) continue;
      final firstRow = start.row < end.row ? start.row : end.row;
      final lastRow = start.row > end.row ? start.row : end.row;
      final firstColumn = start.column < end.column ? start.column : end.column;
      final lastColumn = start.column > end.column ? start.column : end.column;
      for (var row = firstRow; row <= lastRow; row++) {
        for (var column = firstColumn; column <= lastColumn; column++) {
          output.add(
            workbookEvaluateCell(
              workbookCellRef(row, column),
              cells,
              visiting: visiting,
            ),
          );
        }
      }
    } else {
      final position = workbookCellPosition(part);
      output.add(
        position == null
            ? _primitive(part)
            : workbookEvaluateCell(part, cells, visiting: visiting),
      );
    }
  }
  return output;
}

double? _operand(
  String value,
  Map<String, String> cells, {
  Set<String>? visiting,
}) {
  final position = workbookCellPosition(value);
  return _number(
    position == null
        ? value
        : workbookEvaluateCell(value, cells, visiting: visiting),
  );
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

Object? _primitive(String value) {
  final trimmed = value.trim();
  final number = double.tryParse(trimmed);
  if (number != null) return number;
  if (trimmed.toUpperCase() == 'TRUE') return true;
  if (trimmed.toUpperCase() == 'FALSE') return false;
  return value;
}

String _csvEscape(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}
