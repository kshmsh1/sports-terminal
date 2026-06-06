import 'package:flutter/material.dart';

import '../data/pre_data_readiness_items.dart';
import '../models/registry_item.dart';
import 'terminal_primitives.dart';

class PreDataReadinessGatePanel extends StatelessWidget {
  const PreDataReadinessGatePanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final done = preDataReadinessItems.where((item) => item.status == 'Done').length;
    final inProgress = preDataReadinessItems.where((item) => item.status == 'In progress').length;
    final remaining = preDataReadinessItems.where((item) => item.status == 'Remaining').length;
    final notYet = preDataReadinessItems.where((item) => item.status == 'Not yet').length;
    final p0 = preDataReadinessItems.where((item) => item.priority == 'P0').length;
    final p0Remaining = preDataReadinessItems.where((item) => item.priority == 'P0' && item.status != 'Done').length;
    final completion = (done / preDataReadinessItems.length * 100).round();
    final items = compact ? preDataReadinessItems.take(12).toList() : preDataReadinessItems;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: Text('Pre-Data Readiness Gate', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          InfoPill(label: '$completion% complete'),
        ]),
        const SizedBox(height: 10),
        const Text('This is the stop-building-forever gate. Once the remaining P0 items are done, the app should be ready for the first real NBA data wave instead of more architecture-only work.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return GridView.count(crossAxisCount: isWide ? 6 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: isWide ? 1.55 : 1.15, children: [
            _Metric(label: 'Checklist', value: '${preDataReadinessItems.length}', detail: 'definition of done'),
            _Metric(label: 'Done', value: '$done', detail: 'shipped gates'),
            _Metric(label: 'In Progress', value: '$inProgress', detail: 'active gates'),
            _Metric(label: 'Remaining', value: '$remaining', detail: 'explicit work left'),
            _Metric(label: 'Not Yet', value: '$notYet', detail: 'first data unlock'),
            _Metric(label: 'P0 Left', value: '$p0Remaining', detail: '$p0 total P0'),
          ]);
        }),
      ])),
      const SizedBox(height: 18),
      _CategoryBoard(),
      const SizedBox(height: 18),
      _GateTable(items: items, total: preDataReadinessItems.length),
    ]);
  }
}

class _CategoryBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categories = <String, List<RegistryItem>>{};
    for (final item in preDataReadinessItems) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }
    final entries = categories.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Gate Categories', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [for (final entry in entries) _CategoryPill(category: entry.key, items: entry.value)]),
    ]));
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.items});
  final String category;
  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) {
    final done = items.where((item) => item.status == 'Done').length;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(999), border: Border.all(color: terminalBorder)), child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(category, style: const TextStyle(color: terminalTextSoft, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(width: 8),
      Text('$done/${items.length}', style: const TextStyle(color: terminalAccent, fontSize: 12, fontWeight: FontWeight.w900)),
    ]));
  }
}

class _GateTable extends StatelessWidget {
  const _GateTable({required this.items, required this.total});
  final List<RegistryItem> items;
  final int total;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Expanded(child: Text('Pre-Data Gate Checklist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), Text('${items.length}/$total shown', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [
        DataColumn(label: Text('Priority')),
        DataColumn(label: Text('Gate')),
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Description')),
        DataColumn(label: Text('Inputs')),
        DataColumn(label: Text('Next Step')),
      ],
      rows: [for (final item in items) DataRow(cells: [
        DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
        DataCell(SizedBox(width: 280, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
        DataCell(SizedBox(width: 180, child: Text(item.category))),
        DataCell(InfoPill(label: item.status)),
        DataCell(SizedBox(width: 560, child: Text(item.description))),
        DataCell(SizedBox(width: 420, child: Text(item.inputs))),
        DataCell(SizedBox(width: 520, child: Text(item.nextStep))),
      ])],
    )),
  ]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalTextMuted, fontSize: 12)),
    const SizedBox(height: 8),
    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
    const SizedBox(height: 6),
    Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalAccent, fontSize: 11, height: 1.15)),
  ]));
}
