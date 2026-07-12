import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/product_local_store.dart';

const _excelDark = Color(0xFF202020);
const _excelRibbon = Color(0xFF252525);
const _excelGrid = Color(0xFFE1E5EA);
const _excelHeader = Color(0xFFF3F5F7);
const _excelGreen = Color(0xFF107C41);
const _excelText = Color(0xFF1F2933);

class ExcelLikeWorkspaceScreen extends StatefulWidget {
  const ExcelLikeWorkspaceScreen({super.key});

  @override
  State<ExcelLikeWorkspaceScreen> createState() => _ExcelLikeWorkspaceScreenState();
}

class _ExcelLikeWorkspaceScreenState extends State<ExcelLikeWorkspaceScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  final TextEditingController editorController = TextEditingController();
  final TextEditingController formulaController = TextEditingController();
  final FocusNode gridFocus = FocusNode();
  Map<String, String> cells = _watchlistTemplate();
  int selectedRow = 1;
  int selectedColumn = 1;
  String sheet = 'Watchlist';
  bool loaded = false;

  String get selectedCell => '${_columnName(selectedColumn)}$selectedRow';

  @override
  void initState() {
    super.initState();
    _loadWorkbook();
  }

  @override
  void dispose() {
    editorController.dispose();
    formulaController.dispose();
    gridFocus.dispose();
    super.dispose();
  }

  Future<void> _loadWorkbook() async {
    final storedCells = await localStore.loadStringMap(ProductLocalStore.workbookCellsKey, fallback: _watchlistTemplate());
    final storedSheet = await localStore.loadString(ProductLocalStore.workbookSheetKey, fallback: 'Watchlist');
    if (!mounted) return;
    setState(() {
      cells = storedCells.isEmpty ? _watchlistTemplate() : storedCells;
      sheet = storedSheet.isEmpty ? 'Watchlist' : storedSheet;
      loaded = true;
      _syncControllers();
    });
  }

  Future<void> _persistWorkbook() async {
    await localStore.saveStringMap(ProductLocalStore.workbookCellsKey, cells);
    await localStore.saveString(ProductLocalStore.workbookSheetKey, sheet);
  }

  void _selectCell(int row, int column) {
    setState(() {
      selectedRow = row.clamp(1, 60);
      selectedColumn = column.clamp(1, 24);
      _syncControllers();
    });
  }

  void _syncControllers() {
    final raw = cells[selectedCell] ?? '';
    editorController.text = raw;
    editorController.selection = TextSelection.collapsed(offset: editorController.text.length);
    formulaController.text = raw;
    formulaController.selection = TextSelection.collapsed(offset: formulaController.text.length);
  }

  void _commitCell(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        cells.remove(selectedCell);
      } else {
        cells[selectedCell] = value;
      }
      _syncControllers();
    });
    _persistWorkbook();
  }

  void _loadTemplate(String name) {
    setState(() {
      sheet = name;
      if (name == 'Fantasy') {
        cells = _fantasyTemplate();
      } else if (name == 'Team Comps') {
        cells = _teamCompsTemplate();
      } else {
        cells = _watchlistTemplate();
      }
      selectedRow = 1;
      selectedColumn = 1;
      _syncControllers();
    });
    _persistWorkbook();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) _selectCell(selectedRow - 1, selectedColumn);
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) _selectCell(selectedRow + 1, selectedColumn);
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _selectCell(selectedRow, selectedColumn - 1);
    if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.tab) _selectCell(selectedRow, selectedColumn + 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD0D7DE))),
        child: const Text('Loading workbook...', style: TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w700)),
      );
    }

    return KeyboardListener(
      focusNode: gridFocus,
      onKeyEvent: _handleKey,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD0D7DE)),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 22, offset: Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _WorkbookTitleBar(sheet: sheet, selectedCell: selectedCell),
          _Ribbon(onTemplate: _loadTemplate),
          _FormulaBar(cell: selectedCell, controller: formulaController, onSubmitted: _commitCell),
          SizedBox(
            height: 620,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 2160,
                child: Column(children: [
                  _ColumnHeaders(columns: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        for (var row = 1; row <= 60; row++)
                          Row(children: [
                            _RowHeader(row),
                            for (var col = 1; col <= 24; col++)
                              _Cell(
                                row: row,
                                column: col,
                                rawValue: cells['${_columnName(col)}$row'] ?? '',
                                displayValue: _displayCell('${_columnName(col)}$row'),
                                selected: row == selectedRow && col == selectedColumn,
                                editorController: editorController,
                                onTap: () {
                                  gridFocus.requestFocus();
                                  _selectCell(row, col);
                                },
                                onSubmitted: _commitCell,
                              ),
                          ]),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          _SheetTabs(sheet: sheet, onSelected: _loadTemplate),
          _WorkspaceStatusBar(cell: selectedCell, saved: loaded),
        ]),
      ),
    );
  }

  String _displayCell(String cell) {
    final raw = cells[cell] ?? '';
    if (!raw.startsWith('=')) return raw;
    final value = _evaluateFormula(raw);
    if (value == null) return '#VALUE!';
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  double? _evaluateFormula(String raw) {
    final formula = raw.substring(1).trim().toUpperCase();
    final functionMatch = RegExp(r'^(SUM|AVG|AVERAGE|MIN|MAX)\(([^)]+)\)$').firstMatch(formula);
    if (functionMatch != null) {
      final function = functionMatch.group(1)!;
      final values = _rangeValues(functionMatch.group(2)!);
      if (values.isEmpty) return null;
      if (function == 'SUM') return values.fold<double>(0, (sum, value) => sum + value);
      if (function == 'AVG' || function == 'AVERAGE') return values.fold<double>(0, (sum, value) => sum + value) / values.length;
      if (function == 'MIN') return values.reduce((a, b) => a < b ? a : b);
      if (function == 'MAX') return values.reduce((a, b) => a > b ? a : b);
    }
    final referenced = cells[formula];
    if (referenced != null) return double.tryParse(referenced);
    return double.tryParse(formula);
  }

  List<double> _rangeValues(String range) {
    final parts = range.split(':').map((part) => part.trim().toUpperCase()).toList();
    final cellsToRead = <String>[];
    if (parts.length == 1) {
      cellsToRead.add(parts.first);
    } else if (parts.length == 2) {
      final start = _cellPosition(parts.first);
      final end = _cellPosition(parts.last);
      if (start != null && end != null) {
        final rowStart = start.row <= end.row ? start.row : end.row;
        final rowEnd = start.row <= end.row ? end.row : start.row;
        final colStart = start.column <= end.column ? start.column : end.column;
        final colEnd = start.column <= end.column ? end.column : start.column;
        for (var row = rowStart; row <= rowEnd; row++) {
          for (var col = colStart; col <= colEnd; col++) {
            cellsToRead.add('${_columnName(col)}$row');
          }
        }
      }
    }
    return [
      for (final cell in cellsToRead)
        if (double.tryParse(cells[cell] ?? '') != null) double.parse(cells[cell]!),
    ];
  }
}

class _CellPosition {
  const _CellPosition(this.row, this.column);
  final int row;
  final int column;
}

_CellPosition? _cellPosition(String cell) {
  final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(cell);
  if (match == null) return null;
  final letters = match.group(1)!;
  final row = int.tryParse(match.group(2)!);
  if (row == null) return null;
  var column = 0;
  for (final codeUnit in letters.codeUnits) {
    column = column * 26 + (codeUnit - 64);
  }
  return _CellPosition(row, column);
}

class _WorkbookTitleBar extends StatelessWidget {
  const _WorkbookTitleBar({required this.sheet, required this.selectedCell});
  final String sheet;
  final String selectedCell;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: _excelDark,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        const Text('AutoSave', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        const Icon(Icons.toggle_on, color: _excelGreen),
        const SizedBox(width: 14),
        const Icon(Icons.home_outlined, color: Colors.white70, size: 18),
        const SizedBox(width: 10),
        const Icon(Icons.save_outlined, color: Colors.white70, size: 18),
        const Spacer(),
        Text('$sheet — Sports Terminal Workbook', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const Spacer(),
        Container(
          width: 250,
          height: 28,
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF3A3A3A))),
          child: Row(children: [const SizedBox(width: 8), const Icon(Icons.search, color: Colors.white54, size: 16), const SizedBox(width: 6), Expanded(child: Text('Active cell $selectedCell', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)))]),
        ),
      ]),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.onTemplate});
  final ValueChanged<String> onTemplate;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _excelRibbon,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          _RibbonTab('Home', selected: true),
          _RibbonTab('Insert'),
          _RibbonTab('Formulas'),
          _RibbonTab('Data'),
          _RibbonTab('Review'),
          _RibbonTab('View'),
          _RibbonTab('Automate'),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const _RibbonButton(icon: Icons.content_paste, label: 'Paste'),
          const _RibbonButton(icon: Icons.cut, label: 'Cut'),
          const _RibbonButton(icon: Icons.copy, label: 'Copy'),
          const _RibbonDropdown(label: 'Aptos Narrow', width: 150),
          const _RibbonDropdown(label: '12', width: 58),
          const _RibbonButton(icon: Icons.format_bold, label: 'B'),
          const _RibbonButton(icon: Icons.format_italic, label: 'I'),
          const _RibbonButton(icon: Icons.format_underlined, label: 'U'),
          const _RibbonButton(icon: Icons.border_all, label: 'Borders'),
          const _RibbonButton(icon: Icons.format_color_fill, label: 'Fill'),
          const _RibbonButton(icon: Icons.format_align_left, label: 'Align'),
          const _RibbonButton(icon: Icons.wrap_text, label: 'Wrap'),
          const _RibbonButton(icon: Icons.merge_type, label: 'Merge'),
          const _RibbonButton(icon: Icons.table_chart, label: 'Format as Table'),
          const _RibbonButton(icon: Icons.functions, label: 'AutoSum'),
          _TemplateButton(label: 'Watchlist', onTap: () => onTemplate('Watchlist')),
          _TemplateButton(label: 'Fantasy', onTap: () => onTemplate('Fantasy')),
          _TemplateButton(label: 'Team Comps', onTap: () => onTemplate('Team Comps')),
        ]),
      ]),
    );
  }
}

class _RibbonTab extends StatelessWidget {
  const _RibbonTab(this.label, {this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: selected ? const BoxDecoration(border: Border(bottom: BorderSide(color: _excelGreen, width: 3))) : null,
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, fontSize: 12)),
      );
}

class _RibbonButton extends StatelessWidget {
  const _RibbonButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFF303030), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF3A3A3A))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white70, size: 16), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700))]),
      );
}

class _RibbonDropdown extends StatelessWidget {
  const _RibbonDropdown({required this.label, required this.width});
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF555555))),
        child: Row(children: [Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11))), const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16)]),
      );
}

class _TemplateButton extends StatelessWidget {
  const _TemplateButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: _excelGreen), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), child: Text(label));
}

class _FormulaBar extends StatelessWidget {
  const _FormulaBar({required this.cell, required this.controller, required this.onSubmitted});
  final String cell;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        Container(width: 68, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _excelGrid), borderRadius: BorderRadius.circular(4)), child: Text(cell, style: const TextStyle(fontWeight: FontWeight.w900, color: _excelText))),
        const SizedBox(width: 8),
        const Text('fx', style: TextStyle(color: Color(0xFF5B6572), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            onSubmitted: onSubmitted,
            decoration: const InputDecoration(isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderSide: BorderSide(color: _excelGrid))),
          ),
        ),
      ]),
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.columns});
  final int columns;

  @override
  Widget build(BuildContext context) => Row(children: [
        const SizedBox(width: 46, height: 28, child: DecoratedBox(decoration: BoxDecoration(color: _excelHeader, border: Border(right: BorderSide(color: _excelGrid), bottom: BorderSide(color: _excelGrid))))),
        for (var col = 1; col <= columns; col++)
          Container(width: 88, height: 28, alignment: Alignment.center, decoration: const BoxDecoration(color: _excelHeader, border: Border(right: BorderSide(color: _excelGrid), bottom: BorderSide(color: _excelGrid))), child: Text(_columnName(col), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475467), fontSize: 12))),
      ]);
}

class _RowHeader extends StatelessWidget {
  const _RowHeader(this.row);
  final int row;

  @override
  Widget build(BuildContext context) => Container(width: 46, height: 30, alignment: Alignment.center, decoration: const BoxDecoration(color: _excelHeader, border: Border(right: BorderSide(color: _excelGrid), bottom: BorderSide(color: _excelGrid))), child: Text('$row', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475467), fontSize: 12)));
}

class _Cell extends StatelessWidget {
  const _Cell({required this.row, required this.column, required this.rawValue, required this.displayValue, required this.selected, required this.editorController, required this.onTap, required this.onSubmitted});
  final int row;
  final int column;
  final String rawValue;
  final String displayValue;
  final bool selected;
  final TextEditingController editorController;
  final VoidCallback onTap;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 30,
        decoration: BoxDecoration(
          color: row == 1 || row == 2 ? const Color(0xFFF8FAFC) : Colors.white,
          border: Border(right: const BorderSide(color: _excelGrid), bottom: const BorderSide(color: _excelGrid), top: selected ? const BorderSide(color: _excelGreen, width: 2) : BorderSide.none, left: selected ? const BorderSide(color: _excelGreen, width: 2) : BorderSide.none),
        ),
        child: selected
            ? TextField(
                controller: editorController,
                autofocus: true,
                onSubmitted: onSubmitted,
                style: const TextStyle(color: _excelText, fontSize: 12),
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 6)),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(displayValue, overflow: TextOverflow.ellipsis, style: TextStyle(color: rawValue.startsWith('=') ? _excelGreen : _excelText, fontSize: 12, fontWeight: row == 1 || row == 2 ? FontWeight.w800 : FontWeight.w400)),
              ),
      ),
    );
  }
}

class _SheetTabs extends StatelessWidget {
  const _SheetTabs({required this.sheet, required this.onSelected});
  final String sheet;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        color: const Color(0xFFF3F4F6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          const Icon(Icons.chevron_left, color: Color(0xFF667085), size: 18),
          const Icon(Icons.chevron_right, color: Color(0xFF667085), size: 18),
          const SizedBox(width: 8),
          for (final item in const ['Watchlist', 'Fantasy', 'Team Comps']) ...[
            InkWell(
              onTap: () => onSelected(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(color: item == sheet ? Colors.white : Colors.transparent, border: Border(bottom: BorderSide(color: item == sheet ? _excelGreen : Colors.transparent, width: 3))),
                child: Text(item, style: TextStyle(color: item == sheet ? _excelGreen : const Color(0xFF475467), fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
          ],
          const SizedBox(width: 8),
          const Icon(Icons.add, color: Color(0xFF667085), size: 18),
        ]),
      );
}

class _WorkspaceStatusBar extends StatelessWidget {
  const _WorkspaceStatusBar({required this.cell, required this.saved});
  final String cell;
  final bool saved;

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        color: _excelDark,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Text('Ready', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 18),
          const Icon(Icons.accessibility_new, color: Colors.white70, size: 15),
          const SizedBox(width: 4),
          const Text('Accessibility: Good to go', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 18),
          Text(saved ? 'Autosaved locally' : 'Unsaved', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Text(cell, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 16),
          const Icon(Icons.table_chart, color: Colors.white70, size: 17),
          const SizedBox(width: 16),
          const Text('100%', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}

Map<String, String> _watchlistTemplate() => {
      'A1': 'Sports Terminal Workbook',
      'A2': 'Player',
      'B2': 'Team',
      'C2': 'PPG',
      'D2': 'RPG',
      'E2': 'APG',
      'F2': 'Notes',
      'A3': 'Shai Gilgeous-Alexander',
      'B3': 'OKC',
      'C3': '32.7',
      'D3': '5.0',
      'E3': '6.4',
      'F3': 'Fantasy anchor / MVP tier',
      'A4': 'Nikola Jokic',
      'B4': 'DEN',
      'C4': '29.6',
      'D4': '12.7',
      'E4': '10.2',
      'F4': 'Elite creator',
      'A5': 'Jayson Tatum',
      'B5': 'BOS',
      'C5': '26.8',
      'D5': '8.7',
      'E5': '6.0',
      'F5': 'Track injury context',
      'A7': 'Average PPG',
      'C7': '=AVG(C3:C5)',
    };

Map<String, String> _fantasyTemplate() => {
      'A1': 'Fantasy Watchlist',
      'A2': 'Player',
      'B2': 'Team',
      'C2': 'Role',
      'D2': 'Target',
      'E2': 'Reason',
      'A3': 'Shai Gilgeous-Alexander',
      'B3': 'OKC',
      'C3': 'Guard',
      'D3': 'Build around',
      'E3': 'High scoring floor',
      'A4': 'Nikola Jokic',
      'B4': 'DEN',
      'C4': 'Center',
      'D4': 'Premium',
      'E4': 'Triple-double engine',
    };

Map<String, String> _teamCompsTemplate() => {
      'A1': 'Team Comparison',
      'A2': 'Team',
      'B2': 'Record',
      'C2': 'PPG',
      'D2': 'Margin',
      'E2': 'Watch item',
      'A3': 'OKC',
      'B3': '68-17',
      'C3': '120.5',
      'D3': '12.9',
      'E3': 'Title profile',
      'A4': 'BOS',
      'B4': '61-35',
      'C4': '114.9',
      'D4': '8.2',
      'E4': 'Rotation changes',
      'A6': 'Average margin',
      'D6': '=AVG(D3:D4)',
    };

String _columnName(int index) {
  var n = index;
  var label = '';
  while (n > 0) {
    n--;
    label = String.fromCharCode(65 + (n % 26)) + label;
    n ~/= 26;
  }
  return label;
}
