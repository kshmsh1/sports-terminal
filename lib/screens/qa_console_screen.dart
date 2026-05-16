import 'package:flutter/material.dart';

import '../data/qa_check_items.dart';
import '../widgets/terminal_primitives.dart';

class QaConsoleScreen extends StatefulWidget {
  const QaConsoleScreen({super.key});

  @override
  State<QaConsoleScreen> createState() => _QaConsoleScreenState();
}

class _QaConsoleScreenState extends State<QaConsoleScreen> {
  String query = '';
  String area = 'All';
  String status = 'All';

  @override
  Widget build(BuildContext context) {
    final areas = ['All', ...qaCheckItems.map((item) => item.area).toSet().toList()..sort()];
    final statuses = ['All', ...qaCheckItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = qaCheckItems.where((item) {
      final q = query.trim().toLowerCase();
      return (area == 'All' || item.area == area) &&
          (status == 'All' || item.status == status) &&
          (q.isEmpty || item.check.toLowerCase().contains(q) || item.area.toLowerCase().contains(q) || item.risk.toLowerCase().contains(q) || item.acceptanceCriteria.toLowerCase().contains(q));
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'QA Console', subtitle: 'Quality-control console for data integrity, source lineage, asset registration, repository coverage, navigation, UX, and release smoke checks.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Checks', value: '${qaCheckItems.length}', detail: 'QA registry'),
          _Metric(label: 'Areas', value: '${areas.length - 1}', detail: 'Risk groups'),
          _Metric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
          const _Metric(label: 'Mode', value: 'Manual', detail: 'Automation later'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search checks, risk, criteria...'))),
        _FilterDropdown(label: 'Area', value: area, values: areas, onChanged: (value) => setState(() => area = value)),
        _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
      ])),
      const SizedBox(height: 22),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('QA Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} checks', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Area')), DataColumn(label: Text('Check')), DataColumn(label: Text('Status')), DataColumn(label: Text('Risk')), DataColumn(label: Text('Owner')), DataColumn(label: Text('Acceptance Criteria'))], rows: [for (final item in filtered) DataRow(cells: [DataCell(Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800))), DataCell(SizedBox(width: 280, child: Text(item.check))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 520, child: Text(item.risk))), DataCell(Text(item.owner)), DataCell(SizedBox(width: 620, child: Text(item.acceptanceCriteria)))])])),
      ])),
    ]);
  }
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(width: 230, child: DropdownButtonFormField<String>(value: value, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
