import 'package:flutter/material.dart';

import '../data/glossary_items.dart';
import '../widgets/terminal_primitives.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String query = '';
  String domain = 'All';

  @override
  Widget build(BuildContext context) {
    final domains = ['All', ...glossaryItems.map((item) => item.domain).toSet().toList()..sort()];
    final filtered = glossaryItems.where((item) {
      final q = query.trim().toLowerCase();
      return (domain == 'All' || item.domain == domain) &&
          (q.isEmpty || item.term.toLowerCase().contains(q) || item.domain.toLowerCase().contains(q) || item.definition.toLowerCase().contains(q) || item.terminalUse.toLowerCase().contains(q));
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Glossary', subtitle: 'Shared vocabulary for data model, source governance, workflows, reports, Build Lab, and core terminal concepts.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Terms', value: '${glossaryItems.length}', detail: 'Shared language'),
          _Metric(label: 'Domains', value: '${domains.length - 1}', detail: 'Concept groups'),
          _Metric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
          const _Metric(label: 'Mode', value: 'Living', detail: 'Update over time'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search term, definition, use...'))),
        _FilterDropdown(label: 'Domain', value: domain, values: domains, onChanged: (value) => setState(() => domain = value)),
      ])),
      const SizedBox(height: 22),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Glossary Terms', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} terms', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Term')), DataColumn(label: Text('Domain')), DataColumn(label: Text('Status')), DataColumn(label: Text('Definition')), DataColumn(label: Text('Terminal Use'))], rows: [for (final item in filtered) DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(item.term, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.domain)), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.definition))), DataCell(SizedBox(width: 560, child: Text(item.terminalUse)))])])),
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
