import 'package:flutter/material.dart';

import '../data/action_surface_items.dart';
import '../data/saved_view_items.dart';
import '../data/saved_view_state_items.dart';
import '../widgets/active_route_payload_panel.dart';
import '../widgets/terminal_primitives.dart';

class SavedViewsScreen extends StatefulWidget {
  const SavedViewsScreen({super.key});

  @override
  State<SavedViewsScreen> createState() => _SavedViewsScreenState();
}

class _SavedViewsScreenState extends State<SavedViewsScreen> {
  String selectedWorkspace = 'All';
  String selectedStatus = 'All';
  String selectedStateCategory = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final workspaces = ['All', ...savedViewItems.map((item) => item.workspace).toSet().toList()..sort()];
    final statuses = ['All', ...savedViewItems.map((item) => item.status).toSet().toList()..sort()];
    final stateCategories = ['All', ...savedViewStateItems.map((item) => item.category).toSet().toList()..sort()];
    final filtered = savedViewItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesWorkspace = selectedWorkspace == 'All' || item.workspace == selectedWorkspace;
      final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
      final matchesQuery = normalized.isEmpty || item.name.toLowerCase().contains(normalized) || item.workspace.toLowerCase().contains(normalized) || item.description.toLowerCase().contains(normalized) || item.filters.toLowerCase().contains(normalized) || item.output.toLowerCase().contains(normalized);
      return matchesWorkspace && matchesStatus && matchesQuery;
    }).toList();
    final filteredStateItems = savedViewStateItems.where((item) => selectedStateCategory == 'All' || item.category == selectedStateCategory).toList();
    final planned = savedViewItems.where((item) => item.status == 'Planned').length;
    final future = savedViewItems.where((item) => item.status == 'Future').length;
    final p0State = savedViewStateItems.where((item) => item.priority == 'P0').length;
    final p1State = savedViewStateItems.where((item) => item.priority == 'P1').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Saved Views', subtitle: 'Workspace memory layer for repeatable filters, table state, formulas, joins, source snapshots, report inputs, dashboard pins, alerts, exports, fantasy boards, and community embeds.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _SavedViewMetric(label: 'Saved Views', value: '${savedViewItems.length}', detail: '$planned planned / $future future'),
          _SavedViewMetric(label: 'Workspaces', value: '${workspaces.length - 1}', detail: 'Covered areas'),
          _SavedViewMetric(label: 'State Fields', value: '${savedViewStateItems.length}', detail: '$p0State P0 / $p1State P1'),
          _SavedViewMetric(label: 'Actions', value: '${actionSurfaceItems.length}', detail: 'Action Center hooks'),
        ]);
      }),
      const SizedBox(height: 22),
      const ActiveRoutePayloadPanel(consumerName: 'Saved Views', description: 'Saved Views now read the active shared RoutePayload and can treat it as a non-persistent view-state preview with selected rows, selected columns, filters, source snapshot, blockers, and route intent.', compact: true),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search saved views, filters, outputs...'))),
        _FilterDropdown(label: 'Workspace', value: selectedWorkspace, values: workspaces, onChanged: (value) => setState(() => selectedWorkspace = value)),
        _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
        _FilterDropdown(label: 'State Category', value: selectedStateCategory, values: stateCategories, onChanged: (value) => setState(() => selectedStateCategory = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final left = const _SavedViewLifecyclePanel();
        final right = _SavedViewActionPanel(actionCount: actionSurfaceItems.length);
        if (constraints.maxWidth < 1050) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 22),
      _SavedViewLibraryTable(filtered: filtered),
      const SizedBox(height: 22),
      _SavedViewStateTable(items: filteredStateItems),
    ]);
  }
}

class _SavedViewLifecyclePanel extends StatelessWidget {
  const _SavedViewLifecyclePanel();

  @override
  Widget build(BuildContext context) {
    final steps = ['Create view', 'Pick dataset', 'Choose columns', 'Apply filters', 'Sort/select rows', 'Add formulas/joins', 'Snapshot sources', 'Route to action'];
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Saved View Lifecycle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Text('Saved Views should become the memory layer between Search, Workspace Studio, Action Center, Reports, Alerts, Dashboard, Fantasy Terminal, Community Hub, and Source Operations.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')]),
    ]));
  }
}

class _SavedViewActionPanel extends StatelessWidget {
  const _SavedViewActionPanel({required this.actionCount});
  final int actionCount;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Saved View Action Hooks', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    Text('Saved views should feed the action layer. A saved table can become a workspace, report section, dashboard pin, alert rule, export, fantasy board, community embed, or source-audit surface. Action Center currently defines $actionCount action hooks.', style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 16),
    const Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Workspace'), InfoPill(label: 'Compare'), InfoPill(label: 'Report'), InfoPill(label: 'Export'), InfoPill(label: 'Alert'), InfoPill(label: 'Dashboard'), InfoPill(label: 'Fantasy'), InfoPill(label: 'Community'), InfoPill(label: 'Source Audit')]),
  ]));
}

class _SavedViewLibraryTable extends StatelessWidget {
  const _SavedViewLibraryTable({required this.filtered});
  final List<dynamic> filtered;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Saved View Library', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} views', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('View')), DataColumn(label: Text('Workspace')), DataColumn(label: Text('Status')), DataColumn(label: Text('Filters')), DataColumn(label: Text('Output')), DataColumn(label: Text('Description'))], rows: [for (final item in filtered) DataRow(cells: [DataCell(SizedBox(width: 280, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.workspace)), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 440, child: Text(item.filters))), DataCell(SizedBox(width: 480, child: Text(item.output))), DataCell(SizedBox(width: 580, child: Text(item.description)))])])),
  ]));
}

class _SavedViewStateTable extends StatelessWidget {
  const _SavedViewStateTable({required this.items});
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Saved View State Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} fields', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Field')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 190, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 580, child: Text(item.description))), DataCell(SizedBox(width: 360, child: Text(item.inputs))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])])),
  ]));
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

class _SavedViewMetric extends StatelessWidget {
  const _SavedViewMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
