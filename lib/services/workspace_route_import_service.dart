import '../models/route_payload.dart';
import 'product_local_store.dart';

class WorkspaceImportResult {
  const WorkspaceImportResult({
    required this.sheetName,
    required this.cells,
    required this.rowsImported,
    required this.columnsImported,
    required this.rowsOmitted,
    required this.columnsOmitted,
  });

  final String sheetName;
  final Map<String, String> cells;
  final int rowsImported;
  final int columnsImported;
  final int rowsOmitted;
  final int columnsOmitted;

  bool get truncated => rowsOmitted > 0 || columnsOmitted > 0;

  String get summary {
    final base = '$rowsImported rows × $columnsImported columns imported into $sheetName';
    if (!truncated) return base;
    return '$base; omitted $rowsOmitted rows and $columnsOmitted columns beyond the current workbook grid.';
  }
}

class WorkspaceRouteImportService {
  const WorkspaceRouteImportService({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<WorkspaceImportResult> importPayload(RoutePayload payload) async {
    final result = buildImport(payload);
    await _store.saveStringMap(ProductLocalStore.workbookCellsKey, result.cells);
    await _store.saveString(ProductLocalStore.workbookSheetKey, result.sheetName);
    await _store.saveStringMap(
      ProductLocalStore.workspaceImportMetadataKey,
      {
        'displayLabel': payload.displayLabel,
        'sourceObjectType': payload.sourceObjectType,
        'sourceObjectId': payload.sourceObjectId,
        'sourceSnapshot': payload.sourceSnapshot,
        'targetRoute': payload.targetRoute,
        'createdAtIso': payload.createdAtIso,
        'rowsImported': '${result.rowsImported}',
        'columnsImported': '${result.columnsImported}',
        'rowsOmitted': '${result.rowsOmitted}',
        'columnsOmitted': '${result.columnsOmitted}',
      },
    );
    return result;
  }

  WorkspaceImportResult buildImport(RoutePayload payload) {
    const maxColumns = 24;
    const maxDataRows = 57;
    final columns = payload.columns.isNotEmpty
        ? payload.columns
        : [
            for (final key in payload.selectedColumns)
              RoutePayloadColumn(key: key, label: key),
          ];
    final importedColumns = columns.take(maxColumns).toList();
    final importedRows = payload.rows.take(maxDataRows).toList();
    final cells = <String, String>{};

    cells['A1'] = payload.displayLabel;
    if (importedColumns.length > 1) {
      cells['B1'] = payload.sourceSnapshot;
    }
    for (var index = 0; index < importedColumns.length; index++) {
      final column = importedColumns[index];
      cells['${_columnName(index + 1)}2'] = column.label;
    }
    for (var rowIndex = 0; rowIndex < importedRows.length; rowIndex++) {
      final row = importedRows[rowIndex];
      for (var columnIndex = 0;
          columnIndex < importedColumns.length;
          columnIndex++) {
        final column = importedColumns[columnIndex];
        final value = row[column.key];
        cells['${_columnName(columnIndex + 1)}${rowIndex + 3}'] =
            _cellValue(value);
      }
    }

    return WorkspaceImportResult(
      sheetName: _sheetName(payload.displayLabel),
      cells: cells,
      rowsImported: importedRows.length,
      columnsImported: importedColumns.length,
      rowsOmitted: payload.rows.length - importedRows.length,
      columnsOmitted: columns.length - importedColumns.length,
    );
  }

  String _cellValue(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    if (value is num) return value.toString();
    return value.toString().replaceAll('\n', ' ').replaceAll('\r', ' ');
  }

  String _sheetName(String label) {
    final cleaned = label
        .replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'Routed Data';
    return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31).trim();
  }

  String _columnName(int column) {
    var value = column;
    var name = '';
    while (value > 0) {
      value--;
      name = String.fromCharCode(65 + value % 26) + name;
      value ~/= 26;
    }
    return name;
  }
}
