import 'package:flutter/material.dart';

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
  final Map<String, String> cells = {
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
  };
  final formulaController = TextEditingController();
  int selectedRow = 1;
  int selectedColumn = 1;
  String sheet = 'Watchlist';

  String get selectedCell => '${_columnName(selectedColumn)}$selectedRow';

  @override
  void dispose() {
    formulaController.dispose();
    super.dispose();
  }

  void _selectCell(int row, int column) {
    setState(() {
      selectedRow = row;
      selectedColumn = column;
      formulaController.text = cells[selectedCell] ?? '';
      formulaController.selection = TextSelection.collapsed(offset: formulaController.text.length);
    });
  }

  void _commitFormula(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        cells.remove(selectedCell);
      } else {
        cells[selectedCell] = value;
      }
    });
  }

  void _loadTemplate(String name) {
    setState(() {
      sheet = name;
      cells.clear();
      if (name == 'Fantasy') {
        cells.addAll({
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
        });
      } else if (name == 'Team Comps') {
        cells.addAll({
          'A1': 'Team Comparison',
          'A2': 'Team',
          'B2': 'Record',
          'C2': 'PPG',
          'D2': 'Margin',
          'E2': 'Watch item',
          'A3': 'OKC',
          'B3': '68-17',
          'C3': '120.5',
          'D3': '+12.9',
          'E3': 'Title profile',
          'A4': 'BOS',
          'B4': '61-35',
          'C4': '114.9',
          'D4': '+8.2',
          'E4': 'Rotation changes',
        });
      } else {
        cells.addAll({
          'A1': 'Sports Terminal Workbook',
          'A2': 'Player',
          'B2': 'Team',
          'C2': 'PPG',
          'D2': 'RPG',
          'E2': 'APG',
          'F2': 'Notes',
        });
      }
      selectedRow = 1;
      selectedColumn = 1;
      formulaController.text = cells[selectedCell] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    formulaController.text = cells[selectedCell] ?? '';
    formulaController.selection = TextSelection.collapsed(offset: formulaController.text.length);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D7DE)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _WorkbookTitleBar(sheet: sheet),
        _Ribbon(onTemplate: _loadTemplate),
        _FormulaBar(cell: selectedCell, controller: formulaController, onSubmitted: _commitFormula),
        SizedBox(
          height: 620,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1660,
              child: Column(children: [
                _ColumnHeaders(columns: 18),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(children: [
                      for (var row = 1; row <= 44; row++)
                        Row(children: [
                          _RowHeader(row),
                          for (var col = 1; col <= 18; col++)
                            _Cell(
                              row: row,
                              column: col,
                              value: cells['${_columnName(col)}$row'] ?? '',
                              selected: row == selectedRow && col == selectedColumn,
                              onTap: () => _selectCell(row, col),
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
        const _WorkspaceStatusBar(),
      ]),
    );
  }
}

class _WorkbookTitleBar extends StatelessWidget {
  const _WorkbookTitleBar({required this.sheet});
  final String sheet;

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
          child: const Row(children: [SizedBox(width: 8), Icon(Icons.search, color: Colors.white54, size: 16), SizedBox(width: 6), Text('Search workbook', style: TextStyle(color: Colors.white54, fontSize: 12))]),
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
          _RibbonButton(icon: Icons.content_paste, label: 'Paste'),
          _RibbonButton(icon: Icons.cut, label: 'Cut'),
          _RibbonButton(icon: Icons.copy, label: 'Copy'),
          _RibbonDropdown(label: 'Aptos Narrow', width: 150),
          _RibbonDropdown(label: '12', width: 58),
          _RibbonButton(icon: Icons.format_bold, label: 'B'),
          _RibbonButton(icon: Icons.format_italic, label: 'I'),
          _RibbonButton(icon: Icons.format_underlined, label: 'U'),
          _RibbonButton(icon: Icons.border_all, label: 'Borders'),
          _RibbonButton(icon: Icons.format_color_fill, label: 'Fill'),
          _RibbonButton(icon: Icons.format_align_left, label: 'Align'),
          _RibbonButton(icon: Icons.wrap_text, label: 'Wrap'),
          _RibbonButton(icon: Icons.merge_type, label: 'Merge'),
          _RibbonButton(icon: Icons.table_chart, label: 'Format as Table'),
          _RibbonButton(icon: Icons.functions, label: 'AutoSum'),
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
  Widget build(BuildContext context) => Container(width: 46, height: 28, alignment: Alignment.center, decoration: const BoxDecoration(color: _excelHeader, border: Border(right: BorderSide(color: _excelGrid), bottom: BorderSide(color: _excelGrid))), child: Text('$row', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475467), fontSize: 12)));
}

class _Cell extends StatelessWidget {
  const _Cell({required this.row, required this.column, required this.value, required this.selected, required this.onTap});
  final int row;
  final int column;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 88,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: row == 1 || row == 2 ? const Color(0xFFF8FAFC) : Colors.white,
            border: Border(right: const BorderSide(color: _excelGrid), bottom: const BorderSide(color: _excelGrid), top: selected ? const BorderSide(color: _excelGreen, width: 2) : BorderSide.none, left: selected ? const BorderSide(color: _excelGreen, width: 2) : BorderSide.none),
          ),
          child: Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(color: _excelText, fontSize: 12, fontWeight: row == 1 || row == 2 ? FontWeight.w800 : FontWeight.w400)),
        ),
      );
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
  const _WorkspaceStatusBar();

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        color: _excelDark,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: const Row(children: [
          Text('Ready', style: TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(width: 18),
          Icon(Icons.accessibility_new, color: Colors.white70, size: 15),
          SizedBox(width: 4),
          Text('Accessibility: Good to go', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Spacer(),
          Icon(Icons.table_chart, color: Colors.white70, size: 17),
          SizedBox(width: 16),
          Text('100%', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}

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
