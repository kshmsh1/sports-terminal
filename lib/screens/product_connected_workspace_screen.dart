import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/route_payload_controller.dart';
import '../models/app_session.dart';
import '../models/route_payload.dart';
import '../services/connected_workspace_service.dart';
import '../services/workbook_engine.dart';

const _workspaceDark = Color(0xFF202020);
const _workspaceRibbon = Color(0xFF252525);
const _workspaceGrid = Color(0xFFE1E5EA);
const _workspaceHeader = Color(0xFFF3F5F7);
const _workspaceGreen = Color(0xFF107C41);
const _workspaceText = Color(0xFF1F2933);
const _workspaceMuted = Color(0xFF667085);

class ProductConnectedWorkspaceScreen extends StatefulWidget {
  const ProductConnectedWorkspaceScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductConnectedWorkspaceScreen> createState() =>
      _ProductConnectedWorkspaceScreenState();
}

class _ProductConnectedWorkspaceScreenState
    extends State<ProductConnectedWorkspaceScreen> {
  final ConnectedWorkspaceService service = const ConnectedWorkspaceService();
  final TextEditingController editorController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final FocusNode gridFocus = FocusNode();

  ConnectedWorkbook? workbook;
  final List<ConnectedWorkbook> undoStack = [];
  final List<ConnectedWorkbook> redoStack = [];
  int selectedRow = 1;
  int selectedColumn = 1;
  int visibleRows = 40;
  int visibleColumns = 14;
  bool loading = true;
  bool saving = false;
  bool dirty = false;
  String status = 'Loading workbook...';

  String get selectedCell => workbookCellRef(selectedRow, selectedColumn);
  Map<String, String> get activeCells => workbook?.activeCells ?? const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    editorController.dispose();
    titleController.dispose();
    gridFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      status = 'Loading the latest workbook...';
    });
    final loaded = await service.load(widget.session);
    if (!mounted) return;
    setState(() {
      workbook = loaded;
      titleController.text = loaded.title;
      undoStack.clear();
      redoStack.clear();
      dirty = false;
      loading = false;
      status = loaded.remoteAvailable
          ? 'Shared workbook v${loaded.version} loaded.'
          : 'Local workbook loaded. Shared backend is offline.';
      _fitDimensions();
      _syncEditor();
    });
  }

  Future<void> _save() async {
    final current = workbook;
    if (current == null || saving) return;
    final titled = current.copyWith(
      title: titleController.text.trim().isEmpty
          ? 'Sports Terminal Workbook'
          : titleController.text.trim(),
    );
    setState(() {
      workbook = titled;
      saving = true;
      status = 'Saving workbook...';
    });
    final result = await service.save(
      session: widget.session,
      workbook: titled,
    );
    if (!mounted) return;
    setState(() {
      workbook = result.workbook;
      saving = false;
      dirty = !result.saved;
      status = result.saved
          ? 'Saved shared workbook v${result.workbook.version}.'
          : result.conflict
              ? 'Save conflict: another session has a newer version. Reload or inspect version history before saving again.'
              : result.remoteAvailable
                  ? 'Save rejected: ${result.error}'
                  : 'Saved locally. Shared backend is offline.';
    });
  }

  void _mutate(ConnectedWorkbook Function(ConnectedWorkbook current) change) {
    final current = workbook;
    if (current == null) return;
    undoStack.add(_snapshot(current));
    if (undoStack.length > 50) undoStack.removeAt(0);
    redoStack.clear();
    final next = change(current);
    setState(() {
      workbook = next;
      dirty = true;
      status = 'Unsaved changes.';
      _fitDimensions();
      _syncEditor();
    });
  }

  void _undo() {
    final current = workbook;
    if (current == null || undoStack.isEmpty) return;
    redoStack.add(_snapshot(current));
    setState(() {
      workbook = undoStack.removeLast();
      dirty = true;
      status = 'Undo applied. Save to publish the restored state.';
      _fitDimensions();
      _syncEditor();
    });
  }

  void _redo() {
    final current = workbook;
    if (current == null || redoStack.isEmpty) return;
    undoStack.add(_snapshot(current));
    setState(() {
      workbook = redoStack.removeLast();
      dirty = true;
      status = 'Redo applied.';
      _fitDimensions();
      _syncEditor();
    });
  }

  void _commitCell(String value) {
    _mutate((current) {
      final sheets = _copySheets(current.sheets);
      final cells = sheets[current.activeSheet] ?? <String, String>{};
      if (value.trim().isEmpty) {
        cells.remove(selectedCell);
      } else {
        cells[selectedCell] = value;
      }
      sheets[current.activeSheet] = cells;
      return current.copyWith(sheets: sheets);
    });
  }

  void _selectCell(int row, int column) {
    setState(() {
      selectedRow = row.clamp(1, visibleRows);
      selectedColumn = column.clamp(1, visibleColumns);
      _syncEditor();
    });
  }

  void _syncEditor() {
    editorController.text = activeCells[selectedCell] ?? '';
    editorController.selection = TextSelection.collapsed(
      offset: editorController.text.length,
    );
  }

  void _fitDimensions() {
    var maxRow = 1;
    var maxColumn = 1;
    for (final key in activeCells.keys) {
      final position = workbookCellPosition(key);
      if (position == null) continue;
      if (position.row > maxRow) maxRow = position.row;
      if (position.column > maxColumn) maxColumn = position.column;
    }
    visibleRows = (maxRow + 12).clamp(40, 300);
    visibleColumns = (maxColumn + 5).clamp(14, 52);
    selectedRow = selectedRow.clamp(1, visibleRows);
    selectedColumn = selectedColumn.clamp(1, visibleColumns);
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _selectCell(selectedRow - 1, selectedColumn);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _selectCell(selectedRow + 1, selectedColumn);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _selectCell(selectedRow, selectedColumn - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _selectCell(selectedRow, selectedColumn + 1);
    }
  }

  Future<void> _addSheet() async {
    final name = await _nameDialog(
      title: 'Add sheet',
      label: 'Sheet name',
      initial: 'Sheet ${(workbook?.sheets.length ?? 0) + 1}',
    );
    if (name == null || name.trim().isEmpty) return;
    final sanitized = _uniqueSheetName(name, workbook?.sheets.keys ?? const []);
    _mutate((current) {
      final sheets = _copySheets(current.sheets);
      sheets[sanitized] = {};
      return current.copyWith(activeSheet: sanitized, sheets: sheets);
    });
  }

  Future<void> _renameSheet() async {
    final current = workbook;
    if (current == null) return;
    final name = await _nameDialog(
      title: 'Rename sheet',
      label: 'New sheet name',
      initial: current.activeSheet,
    );
    if (name == null || name.trim().isEmpty) return;
    final sanitized = _uniqueSheetName(
      name,
      current.sheets.keys.where((item) => item != current.activeSheet),
    );
    if (sanitized == current.activeSheet) return;
    _mutate((value) {
      final sheets = <String, Map<String, String>>{};
      for (final entry in value.sheets.entries) {
        sheets[entry.key == value.activeSheet ? sanitized : entry.key] =
            Map<String, String>.from(entry.value);
      }
      return value.copyWith(activeSheet: sanitized, sheets: sheets);
    });
  }

  void _duplicateSheet() {
    final current = workbook;
    if (current == null) return;
    final name = _uniqueSheetName(
      '${current.activeSheet} Copy',
      current.sheets.keys,
    );
    _mutate((value) {
      final sheets = _copySheets(value.sheets);
      sheets[name] = Map<String, String>.from(
        value.sheets[value.activeSheet] ?? const {},
      );
      return value.copyWith(activeSheet: name, sheets: sheets);
    });
  }

  Future<void> _deleteSheet() async {
    final current = workbook;
    if (current == null || current.sheets.length <= 1) {
      _show('A workbook must contain at least one sheet.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${current.activeSheet}?'),
        content: const Text(
          'This removes the sheet from the current workbook. Undo remains available until you leave or reload.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete sheet'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _mutate((value) {
      final sheets = _copySheets(value.sheets)..remove(value.activeSheet);
      return value.copyWith(activeSheet: sheets.keys.first, sheets: sheets);
    });
  }

  void _insertRow() {
    _mutate((current) {
      final sheets = _copySheets(current.sheets);
      sheets[current.activeSheet] = workbookInsertRows(
        sheets[current.activeSheet] ?? const {},
        atRow: selectedRow,
      );
      return current.copyWith(sheets: sheets);
    });
  }

  void _deleteRow() {
    _mutate((current) {
      final sheets = _copySheets(current.sheets);
      sheets[current.activeSheet] = workbookDeleteRows(
        sheets[current.activeSheet] ?? const {},
        fromRow: selectedRow,
      );
      return current.copyWith(sheets: sheets);
    });
  }

  void _insertColumn() {
    _mutate((current) {
      final sheets = _copySheets(current.sheets);
      sheets[current.activeSheet] = workbookInsertColumns(
        sheets[current.activeSheet] ?? const {},
        atColumn: selectedColumn,
      );
      return current.copyWith(sheets: sheets);
    });
  }

  void _deleteColumn() {
    _mutate((current) {
      final sheets = _copySheets(current.sheets);
      sheets[current.activeSheet] = workbookDeleteColumns(
        sheets[current.activeSheet] ?? const {},
        fromColumn: selectedColumn,
      );
      return current.copyWith(sheets: sheets);
    });
  }

  Future<void> _pasteCsv() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text ?? '';
    if (text.trim().isEmpty) {
      _show('Clipboard does not contain CSV or tabular text.');
      return;
    }
    final parsed = text.contains('\t') && !text.contains(',')
        ? [for (final line in text.split(RegExp(r'\r?\n'))) line.split('\t')]
        : workbookParseCsv(text);
    final matrix = [for (final row in parsed) <Object?>[...row]];
    final result = workbookImportMatrix(
      matrix,
      startRow: selectedRow,
      startColumn: selectedColumn,
    );
    _mutate((current) {
      final sheets = _copySheets(current.sheets);
      final cells = sheets[current.activeSheet] ?? <String, String>{};
      cells.addAll(result.cells);
      sheets[current.activeSheet] = cells;
      return current.copyWith(sheets: sheets);
    });
    _show(
      'Imported ${result.rowsImported} rows × ${result.columnsImported} columns from the clipboard.',
    );
  }

  Future<void> _copyCsv() async {
    final text = workbookToCsv(
      activeCells,
      rowCount: _usedRows(activeCells),
      columnCount: _usedColumns(activeCells),
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _show('Active sheet copied as CSV.');
  }

  Future<void> _copyEvaluatedCsv() async {
    final text = workbookToCsv(
      activeCells,
      rowCount: _usedRows(activeCells),
      columnCount: _usedColumns(activeCells),
      evaluated: true,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _show('Evaluated active sheet copied as CSV.');
  }

  void _importRoute(RoutePayload? payload) {
    if (payload == null || payload.rows.isEmpty) {
      _show('No structured route package is active.');
      return;
    }
    final result = workbookImportRoutePayload(payload);
    final base = _uniqueSheetName(
      _cleanSheetName(payload.displayLabel),
      workbook?.sheets.keys ?? const [],
    );
    _mutate((current) {
      final sheets = _copySheets(current.sheets);
      sheets[base] = result.cells;
      return current.copyWith(activeSheet: base, sheets: sheets);
    });
    _show(
      'Imported ${payload.rowCount} routed rows into $base. Save to publish the workbook version.',
    );
  }

  Future<void> _history() async {
    final current = workbook;
    if (current == null) return;
    final versions = await service.versions(widget.session);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workbook version history'),
        content: SizedBox(
          width: 760,
          height: 520,
          child: versions.isEmpty
              ? const Center(child: Text('No shared versions are available.'))
              : ListView.separated(
                  itemCount: versions.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = versions[index];
                    final snapshot = item['snapshot'];
                    final sheetCount = snapshot is Map && snapshot['sheets'] is Map
                        ? (snapshot['sheets'] as Map).length
                        : 0;
                    return ListTile(
                      leading: CircleAvatar(child: Text('${item['version']}')),
                      title: Text('Version ${item['version']} · $sheetCount sheets'),
                      subtitle: Text(
                        '${item['actor_user_id']} · ${item['created_at']}',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: item['version'] == current.version
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                await _restoreVersion(
                                  (item['version'] as num).toInt(),
                                );
                              },
                        child: const Text('Restore'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreVersion(int version) async {
    final current = workbook;
    if (current == null) return;
    setState(() => status = 'Restoring version $version...');
    final result = await service.restore(
      session: widget.session,
      current: current,
      version: version,
    );
    if (!mounted) return;
    setState(() {
      workbook = result.workbook;
      titleController.text = result.workbook.title;
      dirty = !result.saved;
      undoStack.clear();
      redoStack.clear();
      status = result.saved
          ? 'Restored version $version as new version ${result.workbook.version}.'
          : result.conflict
              ? 'Restore conflict: reload the current shared workbook first.'
              : result.error;
      _fitDimensions();
      _syncEditor();
    });
  }

  Future<void> _sharing() async {
    if (!widget.session.role.canManageOrganization) {
      _show('Sharing controls are available to organization administrators.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _SharingDialog(
        session: widget.session,
        service: service,
      ),
    );
    await _loadPermissionsOnly();
  }

  Future<void> _loadPermissionsOnly() async {
    final current = workbook;
    if (current == null) return;
    final permissions = await service.permissions(widget.session);
    if (!mounted) return;
    setState(() {
      workbook = current.copyWith(permissions: permissions);
    });
  }

  Future<String?> _nameDialog({
    required String title,
    required String label,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || workbook == null) {
      return const _WorkspaceSurface(
        child: Text(
          'Loading connected sports workbook...',
          style: TextStyle(color: _workspaceMuted),
        ),
      );
    }
    final current = workbook!;
    final routePayload = RoutePayloadScope.maybeOf(context)?.activePayload;
    return KeyboardListener(
      focusNode: gridFocus,
      onKeyEvent: _handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkbookHero(
            workbook: current,
            dirty: dirty,
            status: status,
          ),
          const SizedBox(height: 14),
          _WorkbookToolbar(
            titleController: titleController,
            canUndo: undoStack.isNotEmpty,
            canRedo: redoStack.isNotEmpty,
            saving: saving,
            routeAvailable: routePayload?.hasStructuredRows == true,
            onUndo: _undo,
            onRedo: _redo,
            onSave: _save,
            onReload: _load,
            onHistory: _history,
            onSharing: _sharing,
            onAddSheet: _addSheet,
            onRenameSheet: _renameSheet,
            onDuplicateSheet: _duplicateSheet,
            onDeleteSheet: _deleteSheet,
            onInsertRow: _insertRow,
            onDeleteRow: _deleteRow,
            onInsertColumn: _insertColumn,
            onDeleteColumn: _deleteColumn,
            onPasteCsv: _pasteCsv,
            onCopyCsv: _copyCsv,
            onCopyEvaluatedCsv: _copyEvaluatedCsv,
            onImportRoute: () => _importRoute(routePayload),
          ),
          const SizedBox(height: 10),
          _FormulaBar(
            cell: selectedCell,
            controller: editorController,
            evaluated: workbookDisplayValue(selectedCell, activeCells),
            onSubmitted: _commitCell,
          ),
          const SizedBox(height: 10),
          _WorkspaceGrid(
            cells: activeCells,
            selectedRow: selectedRow,
            selectedColumn: selectedColumn,
            rows: visibleRows,
            columns: visibleColumns,
            onSelected: (row, column) {
              gridFocus.requestFocus();
              _selectCell(row, column);
            },
          ),
          const SizedBox(height: 10),
          _SheetTabs(
            workbook: current,
            onSelected: (sheet) {
              _mutate((value) => value.copyWith(activeSheet: sheet));
            },
            onAdd: _addSheet,
          ),
          const SizedBox(height: 10),
          _StatusBar(
            selectedCell: selectedCell,
            status: status,
            version: current.version,
            remote: current.remoteAvailable,
            sheetCount: current.sheets.length,
            permissionCount: current.permissions.length,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceGrid extends StatelessWidget {
  const _WorkspaceGrid({
    required this.cells,
    required this.selectedRow,
    required this.selectedColumn,
    required this.rows,
    required this.columns,
    required this.onSelected,
  });

  final Map<String, String> cells;
  final int selectedRow;
  final int selectedColumn;
  final int rows;
  final int columns;
  final void Function(int row, int column) onSelected;

  @override
  Widget build(BuildContext context) => Container(
        height: 610,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _workspaceGrid),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 52 + columns * 130,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 52,
                      height: 34,
                      child: ColoredBox(color: _workspaceHeader),
                    ),
                    for (var column = 1; column <= columns; column++)
                      _ColumnHeader(
                        column: column,
                        selected: column == selectedColumn,
                        onTap: () => onSelected(selectedRow, column),
                      ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var row = 1; row <= rows; row++)
                          Row(
                            children: [
                              _RowHeader(
                                row: row,
                                selected: row == selectedRow,
                                onTap: () => onSelected(row, selectedColumn),
                              ),
                              for (var column = 1;
                                  column <= columns;
                                  column++)
                                _GridCell(
                                  row: row,
                                  column: column,
                                  value: workbookDisplayValue(
                                    workbookCellRef(row, column),
                                    cells,
                                  ),
                                  selected: row == selectedRow &&
                                      column == selectedColumn,
                                  onTap: () => onSelected(row, column),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _WorkbookToolbar extends StatelessWidget {
  const _WorkbookToolbar({
    required this.titleController,
    required this.canUndo,
    required this.canRedo,
    required this.saving,
    required this.routeAvailable,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onReload,
    required this.onHistory,
    required this.onSharing,
    required this.onAddSheet,
    required this.onRenameSheet,
    required this.onDuplicateSheet,
    required this.onDeleteSheet,
    required this.onInsertRow,
    required this.onDeleteRow,
    required this.onInsertColumn,
    required this.onDeleteColumn,
    required this.onPasteCsv,
    required this.onCopyCsv,
    required this.onCopyEvaluatedCsv,
    required this.onImportRoute,
  });

  final TextEditingController titleController;
  final bool canUndo;
  final bool canRedo;
  final bool saving;
  final bool routeAvailable;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  final VoidCallback onReload;
  final VoidCallback onHistory;
  final VoidCallback onSharing;
  final VoidCallback onAddSheet;
  final VoidCallback onRenameSheet;
  final VoidCallback onDuplicateSheet;
  final VoidCallback onDeleteSheet;
  final VoidCallback onInsertRow;
  final VoidCallback onDeleteRow;
  final VoidCallback onInsertColumn;
  final VoidCallback onDeleteColumn;
  final VoidCallback onPasteCsv;
  final VoidCallback onCopyCsv;
  final VoidCallback onCopyEvaluatedCsv;
  final VoidCallback onImportRoute;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _workspaceRibbon,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Workbook title',
                  labelStyle: TextStyle(color: Colors.white70),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                ),
              ),
            ),
            _ToolbarButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              onPressed: canUndo ? onUndo : null,
            ),
            _ToolbarButton(
              icon: Icons.redo_rounded,
              label: 'Redo',
              onPressed: canRedo ? onRedo : null,
            ),
            _ToolbarButton(
              icon: saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              label: 'Save',
              onPressed: saving ? null : onSave,
            ),
            _ToolbarButton(
              icon: Icons.refresh_rounded,
              label: 'Reload',
              onPressed: onReload,
            ),
            _ToolbarMenu(
              icon: Icons.table_chart_rounded,
              label: 'Sheet',
              items: const {
                'add': 'Add sheet',
                'rename': 'Rename sheet',
                'duplicate': 'Duplicate sheet',
                'delete': 'Delete sheet',
              },
              onSelected: (value) {
                if (value == 'add') onAddSheet();
                if (value == 'rename') onRenameSheet();
                if (value == 'duplicate') onDuplicateSheet();
                if (value == 'delete') onDeleteSheet();
              },
            ),
            _ToolbarMenu(
              icon: Icons.view_week_outlined,
              label: 'Structure',
              items: const {
                'insert_row': 'Insert selected row',
                'delete_row': 'Delete selected row',
                'insert_column': 'Insert selected column',
                'delete_column': 'Delete selected column',
              },
              onSelected: (value) {
                if (value == 'insert_row') onInsertRow();
                if (value == 'delete_row') onDeleteRow();
                if (value == 'insert_column') onInsertColumn();
                if (value == 'delete_column') onDeleteColumn();
              },
            ),
            _ToolbarMenu(
              icon: Icons.file_open_rounded,
              label: 'Data',
              items: const {
                'paste_csv': 'Paste CSV / TSV',
                'copy_csv': 'Copy raw CSV',
                'copy_evaluated': 'Copy evaluated CSV',
                'route': 'Import active route package',
              },
              onSelected: (value) {
                if (value == 'paste_csv') onPasteCsv();
                if (value == 'copy_csv') onCopyCsv();
                if (value == 'copy_evaluated') onCopyEvaluatedCsv();
                if (value == 'route' && routeAvailable) onImportRoute();
              },
            ),
            _ToolbarButton(
              icon: Icons.history_rounded,
              label: 'Versions',
              onPressed: onHistory,
            ),
            _ToolbarButton(
              icon: Icons.group_outlined,
              label: 'Share',
              onPressed: onSharing,
            ),
          ],
        ),
      );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: onPressed == null ? Colors.white30 : Colors.white),
        label: Text(
          label,
          style: TextStyle(
            color: onPressed == null ? Colors.white30 : Colors.white,
          ),
        ),
      );
}

class _ToolbarMenu extends StatelessWidget {
  const _ToolbarMenu({
    required this.icon,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final entry in items.entries)
            PopupMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 7),
              Text(label, style: const TextStyle(color: Colors.white)),
              const Icon(Icons.arrow_drop_down, color: Colors.white70),
            ],
          ),
        ),
      );
}

class _FormulaBar extends StatelessWidget {
  const _FormulaBar({
    required this.cell,
    required this.controller,
    required this.evaluated,
    required this.onSubmitted,
  });

  final String cell;
  final TextEditingController controller;
  final String evaluated;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _workspaceGrid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                cell,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const VerticalDivider(),
            const Text('fx', style: TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Enter a value or formula such as =SUM(A1:A10)',
                ),
                onSubmitted: onSubmitted,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                evaluated,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _workspaceMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.row,
    required this.column,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int row;
  final int column;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 130,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF4EE) : Colors.white,
            border: Border(
              right: BorderSide(
                color: selected ? _workspaceGreen : _workspaceGrid,
                width: selected ? 2 : 1,
              ),
              bottom: BorderSide(
                color: selected ? _workspaceGreen : _workspaceGrid,
                width: selected ? 2 : 1,
              ),
              left: selected
                  ? const BorderSide(color: _workspaceGreen, width: 2)
                  : BorderSide.none,
              top: selected
                  ? const BorderSide(color: _workspaceGreen, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _workspaceText),
          ),
        ),
      );
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.column,
    required this.selected,
    required this.onTap,
  });

  final int column;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 130,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDDEFE4) : _workspaceHeader,
            border: const Border(
              right: BorderSide(color: _workspaceGrid),
              bottom: BorderSide(color: _workspaceGrid),
            ),
          ),
          child: Text(
            workbookColumnName(column),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? _workspaceGreen : _workspaceText,
            ),
          ),
        ),
      );
}

class _RowHeader extends StatelessWidget {
  const _RowHeader({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final int row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDDEFE4) : _workspaceHeader,
            border: const Border(
              right: BorderSide(color: _workspaceGrid),
              bottom: BorderSide(color: _workspaceGrid),
            ),
          ),
          child: Text(
            '$row',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? _workspaceGreen : _workspaceText,
            ),
          ),
        ),
      );
}

class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.workbook,
    required this.onSelected,
    required this.onAdd,
  });

  final ConnectedWorkbook workbook;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _workspaceGrid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final sheet in workbook.sheets.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(sheet),
                    selected: workbook.activeSheet == sheet,
                    selectedColor: const Color(0xFFDDEFE4),
                    onSelected: (_) => onSelected(sheet),
                  ),
                ),
              IconButton(
                tooltip: 'Add sheet',
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      );
}

class _WorkbookHero extends StatelessWidget {
  const _WorkbookHero({
    required this.workbook,
    required this.dirty,
    required this.status,
  });

  final ConnectedWorkbook workbook;
  final bool dirty;
  final String status;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _workspaceDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _workspaceGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.grid_on_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workbook.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    status,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            _WorkbookPill(
              workbook.remoteAvailable ? 'SHARED v${workbook.version}' : 'LOCAL',
              workbook.remoteAvailable ? _workspaceGreen : Colors.orange,
            ),
            if (dirty) ...[
              const SizedBox(width: 8),
              const _WorkbookPill('UNSAVED', Colors.orange),
            ],
          ],
        ),
      );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.selectedCell,
    required this.status,
    required this.version,
    required this.remote,
    required this.sheetCount,
    required this.permissionCount,
  });

  final String selectedCell;
  final String status;
  final int version;
  final bool remote;
  final int sheetCount;
  final int permissionCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _workspaceHeader,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _workspaceGrid),
        ),
        child: Wrap(
          spacing: 18,
          runSpacing: 5,
          children: [
            Text('Selected $selectedCell'),
            Text('$sheetCount sheets'),
            Text(remote ? 'Shared version $version' : 'Local mode'),
            Text('$permissionCount explicit permissions'),
            Text(status),
          ],
        ),
      );
}

class _SharingDialog extends StatefulWidget {
  const _SharingDialog({required this.session, required this.service});

  final AppSession session;
  final ConnectedWorkspaceService service;

  @override
  State<_SharingDialog> createState() => _SharingDialogState();
}

class _SharingDialogState extends State<_SharingDialog> {
  final TextEditingController userController = TextEditingController();
  late Future<List<Map<String, dynamic>>> future;
  String permission = 'viewer';

  @override
  void initState() {
    super.initState();
    future = widget.service.permissions(widget.session);
  }

  @override
  void dispose() {
    userController.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    final userId = userController.text.trim();
    if (userId.isEmpty) return;
    await widget.service.grantPermission(
      session: widget.session,
      userId: userId,
      permission: permission,
    );
    if (!mounted) return;
    userController.clear();
    setState(() => future = widget.service.permissions(widget.session));
  }

  Future<void> _remove(String userId) async {
    await widget.service.removePermission(
      session: widget.session,
      userId: userId,
    );
    if (!mounted) return;
    setState(() => future = widget.service.permissions(widget.session));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Organization workspace permissions'),
        content: SizedBox(
          width: 720,
          height: 520,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: userController,
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: permission,
                    items: const [
                      DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                      DropdownMenuItem(value: 'editor', child: Text('Editor')),
                      DropdownMenuItem(value: 'owner', child: Text('Owner')),
                    ],
                    onChanged: (value) => setState(() => permission = value ?? 'viewer'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: _grant, child: const Text('Grant')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: future,
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (rows.isEmpty) {
                      return const Center(
                        child: Text('No explicit permissions have been granted.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text(row['user_id']?.toString() ?? ''),
                          subtitle: Text(
                            '${row['permission']} · granted by ${row['granted_by_user_id']} · ${row['updated_at']}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove permission',
                            onPressed: () => _remove(row['user_id']?.toString() ?? ''),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
}

class _WorkspaceSurface extends StatelessWidget {
  const _WorkspaceSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _workspaceGrid),
        ),
        child: child,
      );
}

class _WorkbookPill extends StatelessWidget {
  const _WorkbookPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );
}

ConnectedWorkbook _snapshot(ConnectedWorkbook workbook) => ConnectedWorkbook(
      title: workbook.title,
      activeSheet: workbook.activeSheet,
      sheets: _copySheets(workbook.sheets),
      version: workbook.version,
      remoteAvailable: workbook.remoteAvailable,
      permissions: [for (final item in workbook.permissions) {...item}],
      updatedAt: workbook.updatedAt,
    );

Map<String, Map<String, String>> _copySheets(
  Map<String, Map<String, String>> sheets,
) => {
      for (final entry in sheets.entries)
        entry.key: Map<String, String>.from(entry.value),
    };

String _uniqueSheetName(String raw, Iterable<String> existing) {
  final values = existing.toSet();
  var base = _cleanSheetName(raw);
  if (!values.contains(base)) return base;
  var suffix = 2;
  final root = base.length > 27 ? base.substring(0, 27) : base;
  while (values.contains('$root $suffix')) {
    suffix++;
  }
  return '$root $suffix'.substring(0, ('$root $suffix').length.clamp(0, 31));
}

String _cleanSheetName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\\/:*?\[\]]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return 'Sheet';
  return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
}

int _usedRows(Map<String, String> cells) {
  var maximum = 1;
  for (final key in cells.keys) {
    final position = workbookCellPosition(key);
    if (position != null && position.row > maximum) maximum = position.row;
  }
  return maximum;
}

int _usedColumns(Map<String, String> cells) {
  var maximum = 1;
  for (final key in cells.keys) {
    final position = workbookCellPosition(key);
    if (position != null && position.column > maximum) {
      maximum = position.column;
    }
  }
  return maximum;
}
