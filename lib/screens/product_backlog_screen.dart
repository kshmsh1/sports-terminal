import 'package:flutter/material.dart';

import '../data/backlog_items.dart';
import '../widgets/terminal_primitives.dart';

class ProductBacklogScreen extends StatefulWidget {
  const ProductBacklogScreen({super.key});

  @override
  State<ProductBacklogScreen> createState() => _ProductBacklogScreenState();
}

class _ProductBacklogScreenState extends State<ProductBacklogScreen> {
  String query = '';
  String area = 'All';
  String priority = 'All';
  String status = 'All';

  @override
  Widget build(BuildContext context) {
    final areas = ['All', ...backlogItems.map((item) => item.area).toSet().toList()..sort()];
    final priorities = ['All', ...backlogItems.map((item) => item.priority).toSet().toList()..sort()];
    final statuses = ['All', ...backlogItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = backlogItems.where((item) {
      final q = query.trim().toLowerCase();
      return (area == 'All' || item.area == area) &&
          (priority == 'All' || item.priority == priority) &&
          (status == 'All' || item.status == status) &&
          (q.isEmpty || item.title.toLowerCase().contains(q) || item.area.toLowerCase().contains(q) || item.whyItMatters.toLowerCase().contains(q) || item.acceptanceCriteria.toLowerCase().contains(q));
    }).toList();
    final next = backlogItems.where((item) => item.status == 'Next').length;
    final planned = backlogItems.where((item) => item.status == 'Planned').length;
    final future = backlogItems.where((item) => item.status == 'Future').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Product Backlog', subtitle: 'Prioritized implementation backlog for navigation, source ingestion, core product depth, reports, saved views, alerts, and G League expansion.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Items', value: '${backlogItems.length}', detail: 'Backlog scope'),
          _Metric(label: 'Next', value: '$next', detail: 'Immediate'),
          _Metric(label: 'Planned', value: '$planned', detail: 'Near-term'),
          _Metric(label: 'Future', value: '$future', detail: 'Later'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search backlog, criteria, rationale...'))),
        _FilterDropdown(label: 'Area', value: area, values: areas, onChanged: (value) => setState(() => area = value)),
        _FilterDropdown(label: 'Priority', value: priority, values: priorities, onChanged: (value) => setState(() => priority = value)),
        _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
      ])),
      const SizedBox(height: 22),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Backlog Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} items', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Title')), DataColumn(label: Text('Area')), DataColumn(label: Text('Status')), DataColumn(label: Text('Why It Matters')), DataColumn(label: Text('Acceptance Criteria'))], rows: [for (final item in filtered) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 300, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.area)), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 520, child: Text(item.whyItMatters))), DataCell(SizedBox(width: 620, child: Text(item.acceptanceCriteria)))])])),
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
  Widget build(BuildContext context) => SizedBox(width: 220, child: DropdownButtonFormField<String>(value: value, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
