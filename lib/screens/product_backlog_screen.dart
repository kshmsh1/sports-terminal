import 'package:flutter/material.dart';

import '../data/backlog_items.dart';
import '../models/backlog_item.dart';
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
  String? selectedId;

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
    final selected = _selectedItem(filtered);
    final next = backlogItems.where((item) => item.status == 'Next').length;
    final planned = backlogItems.where((item) => item.status == 'Planned').length;
    final future = backlogItems.where((item) => item.status == 'Future').length;
    final p0 = backlogItems.where((item) => item.priority == 'P0').length;
    final p1 = backlogItems.where((item) => item.priority == 'P1').length;
    final p2 = backlogItems.where((item) => item.priority == 'P2').length;
    final p3 = backlogItems.where((item) => item.priority == 'P3').length;
    final areaCounts = <String, int>{};
    for (final item in backlogItems) {
      areaCounts[item.area] = (areaCounts[item.area] ?? 0) + 1;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Product Backlog', subtitle: 'End-platform implementation map across core product modules, workflows, operations, data ingestion, source governance, QA, charts, alerts, reports, saved views, and future G League development.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Items', value: '${backlogItems.length}', detail: 'Generated roadmap'),
          _Metric(label: 'Next / Planned', value: '$next / $planned', detail: 'Immediate and near-term'),
          _Metric(label: 'Future', value: '$future', detail: 'Later expansion'),
          _Metric(label: 'P0 / P1 / P2 / P3', value: '$p0 / $p1 / $p2 / $p3', detail: 'Priority stack'),
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
      LayoutBuilder(builder: (context, constraints) {
        final selectedPanel = _SelectedBacklogPanel(item: selected);
        final areaPanel = _AreaCoveragePanel(areaCounts: areaCounts);
        if (constraints.maxWidth < 1050) return Column(children: [selectedPanel, const SizedBox(height: 14), areaPanel]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: selectedPanel), const SizedBox(width: 14), Expanded(child: areaPanel)]);
      }),
      const SizedBox(height: 22),
      const _RoadmapPrinciplesPanel(),
      const SizedBox(height: 22),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Backlog Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} items', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Title')), DataColumn(label: Text('Area')), DataColumn(label: Text('Status')), DataColumn(label: Text('Why It Matters')), DataColumn(label: Text('Acceptance Criteria'))], rows: [for (final item in filtered) DataRow(selected: selected?.id == item.id, onSelectChanged: (_) => setState(() => selectedId = item.id), cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 330, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.area))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.whyItMatters))), DataCell(SizedBox(width: 720, child: Text(item.acceptanceCriteria)))])])),
      ])),
    ]);
  }

  BacklogItem? _selectedItem(List<BacklogItem> filtered) {
    for (final item in filtered) {
      if (item.id == selectedId) return item;
    }
    for (final item in backlogItems) {
      if (item.id == selectedId) return item;
    }
    if (filtered.isNotEmpty) return filtered.first;
    return backlogItems.isEmpty ? null : backlogItems.first;
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
  Widget build(BuildContext context) => SizedBox(width: 220, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _SelectedBacklogPanel extends StatelessWidget {
  const _SelectedBacklogPanel({required this.item});
  final BacklogItem? item;
  @override
  Widget build(BuildContext context) {
    if (item == null) return const TerminalCard(child: Text('Select a backlog item to inspect roadmap detail.', style: TextStyle(color: terminalTextSoft)));
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(item!.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))), const SizedBox(width: 10), InfoPill(label: item!.status)]),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: item!.area), InfoPill(label: item!.priority), InfoPill(label: item!.id)]),
      const SizedBox(height: 16),
      const Text('Why it matters', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(item!.whyItMatters, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
      const SizedBox(height: 16),
      const Text('Acceptance criteria', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(item!.acceptanceCriteria, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    ]));
  }
}

class _AreaCoveragePanel extends StatelessWidget {
  const _AreaCoveragePanel({required this.areaCounts});
  final Map<String, int> areaCounts;
  @override
  Widget build(BuildContext context) {
    final areas = areaCounts.keys.toList()..sort();
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Roadmap Area Coverage', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Text('This backlog is intentionally broad. It keeps the build pointed at a full NBA terminal across product surfaces, workflows, data operations, and future expansion rather than a single stats-only product.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [for (final area in areas) InfoPill(label: '$area ${areaCounts[area]}')]),
    ]));
  }
}

class _RoadmapPrinciplesPanel extends StatelessWidget {
  const _RoadmapPrinciplesPanel();
  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Backlog Principles', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 12),
    Text('The backlog is structured around an end platform: entity pages, event layers, recognition layers, performance layers, postseason context, workflow tools, saved workspaces, monitoring, source operations, QA, and future G League development. The product should keep getting more useful even before large datasets arrive, because every screen should handle empty assets, real assets, source metadata, and cross-module joins the same way.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
  ]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
