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
          (q.isEmpty ||
              item.id.toLowerCase().contains(q) ||
              item.title.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q) ||
              item.priority.toLowerCase().contains(q) ||
              item.status.toLowerCase().contains(q) ||
              item.description.toLowerCase().contains(q) ||
              item.inputs.toLowerCase().contains(q) ||
              item.nextStep.toLowerCase().contains(q));
    }).toList();

    final p0 = widget.items.where((item) => item.priority == 'P0').length;
    final p1 = widget.items.where((item) => item.priority == 'P1').length;
    final active = widget.items.where(_isActiveOrReady).length;
    final gated = widget.items.where(_isFutureOrGated).length;
    final categoryCounts = _countBy(widget.items.map((item) => item.category));
    final statusCounts = _countBy(widget.items.map((item) => item.status));
    final visibleP0 = filtered.where((item) => item.priority == 'P0').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title: widget.title, subtitle: widget.subtitle),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 6 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 1.75 : 1.45, children: [
          _Metric(label: 'Items', value: '${widget.items.length}', detail: 'Registry entries'),
          _Metric(label: 'Visible', value: '${filtered.length}', detail: 'After filters'),
          _Metric(label: 'P0', value: '$p0', detail: '$visibleP0 visible'),
          _Metric(label: 'P1', value: '$p1', detail: 'High priority'),
          _Metric(label: 'Active/Ready', value: '$active', detail: 'Operational signal'),
          _Metric(label: 'Future/Gated', value: '$gated', detail: 'Sequenced later'),
        ]);
      }),
      const SizedBox(height: 22),
      if (widget.leadTitle != null && widget.leadBody != null) ...[
        TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.leadTitle!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(widget.leadBody!, style: const TextStyle(color: terminalTextSoft, height: 1.45))])),
        const SizedBox(height: 22),
      ],
      _RegistrySignalBoard(categoryCounts: categoryCounts, statusCounts: statusCounts),
      const SizedBox(height: 22),
      _RegistryExecutionQueue(items: filtered),
      const SizedBox(height: 22),
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

bool _isActiveOrReady(RegistryItem item) {
  final status = item.status.toLowerCase();
  return status.contains('ready') || status.contains('active') || status.contains('connected') || status.contains('shipped') || status.contains('operational') || status.contains('in progress');
}

bool _isFutureOrGated(RegistryItem item) {
  final status = item.status.toLowerCase();
  return status.contains('future') || status.contains('gated') || status.contains('defer') || status.contains('later');
}

int _priorityWeight(String priority) {
  if (priority == 'P0') return 0;
  if (priority == 'P1') return 1;
  if (priority == 'P2') return 2;
  if (priority == 'P3') return 3;
  return 4;
}

Map<String, int> _countBy(Iterable<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts;
}

List<MapEntry<String, int>> _topEntries(Map<String, int> counts, {int limit = 8}) {
  final entries = counts.entries.toList();
  entries.sort((a, b) {
    final byCount = b.value.compareTo(a.value);
    if (byCount != 0) return byCount;
    return a.key.compareTo(b.key);
  });
  return entries.take(limit).toList();
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _RegistrySignalBoard extends StatelessWidget {
  const _RegistrySignalBoard({required this.categoryCounts, required this.statusCounts});
  final Map<String, int> categoryCounts;
  final Map<String, int> statusCounts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      return GridView.count(crossAxisCount: isWide ? 2 : 1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.4 : 1.55, children: [
        _SignalCard(title: 'Category Concentration', subtitle: 'Where this module is structurally heavy.', entries: _topEntries(categoryCounts)),
        _SignalCard(title: 'Status Distribution', subtitle: 'What is ready, planned, blocked, gated, or future.', entries: _topEntries(statusCounts)),
      ]);
    });
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.title, required this.subtitle, required this.entries});
  final String title;
  final String subtitle;
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    Text(subtitle, style: const TextStyle(color: terminalTextMuted, fontSize: 12, height: 1.35)),
    const SizedBox(height: 14),
    Wrap(spacing: 8, runSpacing: 8, children: [for (final entry in entries) _SignalPill(label: entry.key, count: entry.value)]),
  ]));
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(999), border: Border.all(color: terminalBorder)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: const TextStyle(color: terminalTextSoft, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(width: 8), Text('$count', style: const TextStyle(color: terminalAccent, fontSize: 12, fontWeight: FontWeight.w900))]));
}

class _RegistryExecutionQueue extends StatelessWidget {
  const _RegistryExecutionQueue({required this.items});
  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) {
    final queue = [...items];
    queue.sort((a, b) {
      final priority = _priorityWeight(a.priority).compareTo(_priorityWeight(b.priority));
      if (priority != 0) return priority;
      final readiness = _isActiveOrReady(b).toString().compareTo(_isActiveOrReady(a).toString());
      if (readiness != 0) return readiness;
      return a.title.compareTo(b.title);
    });
    final selected = queue.take(8).toList();

    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Execution Queue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Highest-priority items from the active filtered registry view.', style: TextStyle(color: terminalTextMuted, fontSize: 12))])), Text('${selected.length} shown', style: const TextStyle(color: terminalTextMuted))])),
      const Divider(height: 1, color: terminalBorder),
      if (selected.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('No execution items match the current filters.', style: TextStyle(color: terminalTextMuted))) else Padding(padding: const EdgeInsets.all(14), child: Column(children: [for (final item in selected) _QueueRow(item: item)])),
    ]));
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item});
  final RegistryItem item;

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: terminalBorder)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 52, child: Text(item.priority, style: const TextStyle(color: terminalAccent, fontSize: 14, fontWeight: FontWeight.w900))),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), const SizedBox(width: 10), InfoPill(label: item.status)]),
      const SizedBox(height: 8),
      Text(item.nextStep, style: const TextStyle(color: terminalTextSoft, height: 1.35)),
      const SizedBox(height: 8),
      Text('Inputs: ${item.inputs}', style: const TextStyle(color: terminalTextMuted, fontSize: 12, height: 1.35)),
    ])),
  ]));
}

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
