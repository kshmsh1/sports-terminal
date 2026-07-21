import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/route_payload.dart';
import 'package:sports_terminal/services/workspace_route_import_service.dart';

void main() {
  const service = WorkspaceRouteImportService();

  test('builds workbook cells from structured payload rows', () {
    const payload = RoutePayload(
      sourceObjectType: 'PlayerStatTable',
      sourceObjectId: 'leaders',
      displayLabel: 'Scoring Board',
      selectedColumns: ['player', 'ppg'],
      selectedRows: ['p1', 'p2'],
      filterSummary: 'top scorers',
      sourceSnapshot: 'fixture',
      readinessState: 'Ready',
      blockers: [],
      targetRoute: 'Workspace',
      availableActions: ['Workspace'],
      columns: [
        RoutePayloadColumn(key: 'player', label: 'Player'),
        RoutePayloadColumn(key: 'ppg', label: 'PPG', dataType: 'number'),
      ],
      rows: [
        {'player': 'Alpha', 'ppg': 28.2},
        {'player': 'Beta', 'ppg': 24.0},
      ],
    );

    final result = service.buildImport(payload);

    expect(result.sheetName, 'Scoring Board');
    expect(result.cells['A1'], 'Scoring Board');
    expect(result.cells['A2'], 'Player');
    expect(result.cells['B2'], 'PPG');
    expect(result.cells['A3'], 'Alpha');
    expect(result.cells['B4'], '24.0');
    expect(result.rowsImported, 2);
    expect(result.columnsImported, 2);
    expect(result.truncated, isFalse);
  });

  test('reports workbook row and column truncation', () {
    final columns = [
      for (var index = 0; index < 30; index++)
        RoutePayloadColumn(key: 'c$index', label: 'Column $index'),
    ];
    final rows = [
      for (var row = 0; row < 70; row++)
        {for (var column = 0; column < 30; column++) 'c$column': row * 100 + column},
    ];
    final payload = RoutePayload(
      sourceObjectType: 'LargeTable',
      sourceObjectId: 'large',
      displayLabel: 'Large Import',
      selectedColumns: [for (final column in columns) column.key],
      selectedRows: [for (var index = 0; index < rows.length; index++) '$index'],
      filterSummary: 'none',
      sourceSnapshot: 'fixture',
      readinessState: 'Ready',
      blockers: const [],
      targetRoute: 'Workspace',
      availableActions: const ['Workspace'],
      columns: columns,
      rows: rows,
    );

    final result = service.buildImport(payload);

    expect(result.rowsImported, 57);
    expect(result.columnsImported, 24);
    expect(result.rowsOmitted, 13);
    expect(result.columnsOmitted, 6);
    expect(result.truncated, isTrue);
  });
}
