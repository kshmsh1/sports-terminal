import 'package:flutter/material.dart';

import '../data/workflow_playbook_items.dart';
import '../widgets/terminal_primitives.dart';

class WorkflowPlaybookScreen extends StatefulWidget {
  const WorkflowPlaybookScreen({super.key});

  @override
  State<WorkflowPlaybookScreen> createState() => _WorkflowPlaybookScreenState();
}

class _WorkflowPlaybookScreenState extends State<WorkflowPlaybookScreen> {
  String query = '';
  String workspace = 'All';
  String status = 'All';
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    final workspaces = ['All', ...workflowPlaybookItems.map((item) => item.workspace).toSet().toList()..sort()];
    final statuses = ['All', ...workflowPlaybookItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = workflowPlaybookItems.where((item) {
      final q = query.trim().toLowerCase();
      return (workspace == 'All' || item.workspace == workspace) &&
          (status == 'All' || item.status == status) &&
          (q.isEmpty || item.name.toLowerCase().contains(q) || item.workspace.toLowerCase().contains(q) || item.trigger.toLowerCase().contains(q) || item.requiredData.toLowerCase().contains(q) || item.output.toLowerCase().contains(q) || item.steps.join(' ').toLowerCase().contains(q));
    }).toList();
    final selected = workflowPlaybookItems.where((item) => item.id == selectedId).firstOrNull ?? (filtered.isNotEmpty ? filtered.first : null);
    final ready = workflowPlaybookItems.where((item) => item.status.contains('Ready')).length;
    final future = workflowPlaybookItems.where((item) => item.status == 'Future').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Workflow Playbooks', subtitle: 'Operating playbooks for how users move from entity selection to data loading, source checks, comparison, reports, alerts, and future monitoring.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Playbooks', value: '${workflowPlaybookItems.length}', detail: 'Workflow map'),
          _Metric(label: 'Ready', value: '$ready', detail: 'Blueprinted'),
          _Metric(label: 'Future', value: '$future', detail: 'Persistence later'),
          _Metric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search workflow, steps, data, output...'))),
        _FilterDropdown(label: 'Workspace', value: workspace, values: workspaces, onChanged: (value) => setState(() => workspace = value)),
        _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1050;
        final table = _PlaybookTable(items: filtered, selectedId: selected?.id, onSelected: (item) => setState(() => selectedId = item.id));
        final detail = _PlaybookDetail(item: selected);
        if (!isWide) return Column(children: [table, const SizedBox(height: 14), detail]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: table), const SizedBox(width: 14), Expanded(flex: 2, child: detail)]);
      }),
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

class _PlaybookTable extends StatelessWidget {
  const _PlaybookTable({required this.items, required this.selectedId, required this.onSelected});
  final List<dynamic> items;
  final String? selectedId;
  final ValueChanged<dynamic> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Workflow Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} workflows', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Workflow')), DataColumn(label: Text('Workspace')), DataColumn(label: Text('Status')), DataColumn(label: Text('Trigger')), DataColumn(label: Text('Required Data')), DataColumn(label: Text('Output'))], rows: [for (final item in items) DataRow(selected: selectedId == item.id, onSelectChanged: (_) => onSelected(item), cells: [DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.workspace)), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 360, child: Text(item.trigger))), DataCell(SizedBox(width: 420, child: Text(item.requiredData))), DataCell(SizedBox(width: 420, child: Text(item.output)))])])),
  ]));
}

class _PlaybookDetail extends StatelessWidget {
  const _PlaybookDetail({required this.item});
  final dynamic item;
  @override
  Widget build(BuildContext context) {
    if (item == null) return const TerminalCard(child: Text('Select a workflow to inspect its steps.', style: TextStyle(color: terminalTextSoft)));
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: item.workspace), InfoPill(label: item.status)]),
      const SizedBox(height: 18),
      const Text('Steps', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      for (var i = 0; i < item.steps.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${i + 1}. ${item.steps[i]}', style: const TextStyle(color: terminalTextSoft, height: 1.35))),
      const SizedBox(height: 12),
      const Text('Required data', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(item.requiredData, style: const TextStyle(color: terminalTextSoft, height: 1.35)),
    ]));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
