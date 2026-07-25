import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/route_payload.dart';
import 'package:sports_terminal/services/workbook_engine.dart';

void main() {
  test('column names and cell references round trip beyond Z', () {
    expect(workbookColumnName(1), 'A');
    expect(workbookColumnName(26), 'Z');
    expect(workbookColumnName(27), 'AA');
    expect(workbookColumnName(52), 'AZ');
    expect(workbookColumnName(53), 'BA');
    expect(workbookColumnIndex('AZ'), 52);
    expect(workbookCellPosition('BC17')?.column, 55);
    expect(workbookCellPosition('BC17')?.row, 17);
  });

  test('formula engine evaluates ranges binary math and cycles', () {
    final cells = <String, String>{
      'A1': '10',
      'A2': '20',
      'A3': '=SUM(A1:A2)',
      'B1': '=AVERAGE(A1:A3)',
      'B2': '=A1*3',
      'C1': '=C2',
      'C2': '=C1',
    };
    expect(workbookDisplayValue('A3', cells), '30');
    expect(workbookDisplayValue('B1', cells), '20');
    expect(workbookDisplayValue('B2', cells), '30');
    expect(workbookDisplayValue('C1', cells), '#CYCLE!');
  });

  test('row and column structure operations preserve relative positions', () {
    const cells = <String, String>{
      'A1': 'header',
      'B2': 'value',
      'C4': 'tail',
    };
    final insertedRows = workbookInsertRows(cells, atRow: 2);
    expect(insertedRows['A1'], 'header');
    expect(insertedRows['B3'], 'value');
    expect(insertedRows['C5'], 'tail');

    final deletedRows = workbookDeleteRows(insertedRows, fromRow: 3);
    expect(deletedRows['B3'], isNull);
    expect(deletedRows['C4'], 'tail');

    final insertedColumns = workbookInsertColumns(cells, atColumn: 2);
    expect(insertedColumns['A1'], 'header');
    expect(insertedColumns['C2'], 'value');
    expect(insertedColumns['D4'], 'tail');

    final deletedColumns = workbookDeleteColumns(
      insertedColumns,
      fromColumn: 3,
    );
    expect(deletedColumns['C2'], isNull);
    expect(deletedColumns['C4'], 'tail');
  });

  test('CSV parser handles quoted commas quotes and newlines', () {
    const csv = 'Player,Note\n"Doe, Jane","Said ""hello"""\nA,"two\nlines"';
    final rows = workbookParseCsv(csv);
    expect(rows.length, 3);
    expect(rows[1][0], 'Doe, Jane');
    expect(rows[1][1], 'Said "hello"');
    expect(rows[2][1], 'two\nlines');

    final imported = workbookImportMatrix([
      for (final row in rows) <Object?>[...row],
    ]);
    final exported = workbookToCsv(
      imported.cells,
      rowCount: imported.rowsImported,
      columnCount: imported.columnsImported,
    );
    expect(exported, contains('"Doe, Jane"'));
    expect(exported, contains('"Said ""hello"""'));
  });

  test('route payload import preserves declared column order', () {
    const payload = RoutePayload(
      sourceObjectType: 'Player stats',
      sourceObjectId: 'players',
      displayLabel: 'Player ranking',
      selectedColumns: ['name', 'points'],
      selectedRows: ['all'],
      filterSummary: '2025-26',
      sourceSnapshot: 'test',
      readinessState: 'Ready',
      blockers: [],
      targetRoute: 'Workspace',
      availableActions: ['Workspace'],
      columns: [
        RoutePayloadColumn(key: 'name', label: 'Player'),
        RoutePayloadColumn(
          key: 'points',
          label: 'Points',
          dataType: 'number',
        ),
      ],
      rows: [
        {'name': 'A', 'points': 30},
        {'name': 'B', 'points': 28},
      ],
    );
    final imported = workbookImportRoutePayload(payload);
    expect(imported.cells['A1'], 'Player');
    expect(imported.cells['B1'], 'Points');
    expect(imported.cells['A2'], 'A');
    expect(imported.cells['B3'], '28');
  });
}
