import 'package:flutter/material.dart';

import '../models/registry_item.dart';
import '../widgets/terminal_primitives.dart';

class RegistryScreenFactory extends StatefulWidget {
  const RegistryScreenFactory({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.searchHint,
    this.leadTitle,
    this.leadBody,
  });

  final String title;
  final String subtitle;
  final List<RegistryItem> items;
  final String searchHint;
  final String? leadTitle;
  final String? leadBody;

  @override
  State<RegistryScreenFactory> createState() => _RegistryScreenFactoryState();
}

class _RegistryScreenFactoryState extends State<RegistryScreenFactory> {
  String query = '';
  String category = 'All';
  String priority = 'All';
  String status = 'All';

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...widget.items.map((item) => item.category).toSet().toList()..sort()];
    final priorities = ['All', ...widget.items.map((item) => item.priority).toSet().toList()..sort()];
    final statuses = ['All', ...widget.items.map((item) => item.status).toSet().toList()..sort()];
    final filtered = widget.items.where((item) {
      final q = query.trim().toLowerCase();
      return (category == 'All' || item.category == category) &&
          (priority == 'All' || item.priority == priority) &&
          (status == 'All' || item.status == status) &&
          (q.isEmpty || item.title.toLowerCase().contains(q) || item.category.toLowerCase().contains(q) || item.description.toLowerCase().contains(q) || item.inputs.toLowerCase().contains(q) || item.nextStep.toLowerCase().contains(q));
    }).toList();

    final p0 = widget.items.where((item) => item.priority == 'P0').length;
    final p1 = widget.items.where((item) => item.priority == 'P1').length;
    final future = widget.items.where((item) => item.status.toLowerCase().contains('future')).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title: widget.title, subtitle: widget.subtitle),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Items', value: '${widget.items.length}', detail: 'Registry entries'),
          _Metric(label: 'P0', value: '$p0', detail: 'Critical'),
          _Metric(label: 'P1', value: '$p1', detail: 'High priority'),
          _Metric(label: 'Future', value: '$future', detail: 'Later'),
        ]);
      }),
      const SizedBox(height: 22),
      if (widget.leadTitle != null && widget.leadBody != null) ...[
        TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.leadTitle!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(widget.leadBody!, style: const TextStyle(color: terminalTextSoft, height: 1.45))])),
        const SizedBox(height: 22),
      ],
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration(widget.searchHint))),
        _FilterDropdown(label: 'Category', value: category, values: categories, onChanged: (value) => setState(() => category = value)),
        _FilterDropdown(label: 'Priority', value: priority, values: priorities, onChanged: (value) => setState(() => priority = value)),
        _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
      ])),
      const SizedBox(height: 22),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text('${widget.title} Registry', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} items', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Title')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in filtered) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 280, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 170, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 430, child: Text(item.inputs))), DataCell(SizedBox(width: 500, child: Text(item.nextStep)))])])),
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
