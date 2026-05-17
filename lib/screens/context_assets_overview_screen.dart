import 'package:flutter/material.dart';

import '../data/context_asset_command_stage_items.dart';
import '../data/context_asset_module_items.dart';
import '../widgets/terminal_primitives.dart';

class ContextAssetsOverviewScreen extends StatefulWidget {
  const ContextAssetsOverviewScreen({super.key});

  @override
  State<ContextAssetsOverviewScreen> createState() => _ContextAssetsOverviewScreenState();
}

class _ContextAssetsOverviewScreenState extends State<ContextAssetsOverviewScreen> {
  String selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...contextAssetCommandStageItems.map((item) => item.category).toSet().toList()..sort()];
    final filteredStages = contextAssetCommandStageItems.where((item) => selectedCategory == 'All' || item.category == selectedCategory).toList();
    final p0 = contextAssetCommandStageItems.where((item) => item.priority == 'P0').length;
    final planned = contextAssetCommandStageItems.where((item) => item.status == 'Planned').length;
    final future = contextAssetCommandStageItems.where((item) => item.status == 'Future').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Context Assets', subtitle: 'Shared command model for Games, Rosters, Awards, Draft, and Transactions. These modules are the connective layer between the core NBA entities, workspaces, reports, exports, alerts, fantasy, scouting, and future community surfaces.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Modules', value: '${contextAssetModuleItems.length}', detail: 'Context layer'),
          _Metric(label: 'Command Stages', value: '${contextAssetCommandStageItems.length}', detail: '$p0 P0 stages'),
          _Metric(label: 'Planned', value: '$planned', detail: 'Near-term workflow'),
          _Metric(label: 'Future', value: '$future', detail: 'Expansion layer'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        for (final category in categories)
          InkWell(borderRadius: BorderRadius.circular(999), onTap: () => setState(() => selectedCategory = category), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: selectedCategory == category ? const Color(0xFF1B2A3F) : terminalPanelDark, borderRadius: BorderRadius.circular(999), border: Border.all(color: selectedCategory == category ? terminalAccent : terminalBorder)), child: Text(category, style: TextStyle(color: selectedCategory == category ? Colors.white : terminalTextSoft, fontWeight: FontWeight.w800, fontSize: 12))))
      ])),
      const SizedBox(height: 22),
      const _ContextPrinciplePanel(),
      const SizedBox(height: 22),
      const _ContextModuleTable(),
      const SizedBox(height: 22),
      _ContextStageTable(items: filteredStages),
    ]);
  }
}

class _ContextPrinciplePanel extends StatelessWidget {
  const _ContextPrinciplePanel();
  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Context Asset Principle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 10),
    Text('Games, rosters, awards, draft, and transactions should not be isolated lookup pages. They should act as reusable evidence objects. A game powers trend charts and matchup reports. A roster row explains player-team history. An award row supports full race context. A draft row links scouting to long-term outcomes. A transaction row explains how team context changed.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 16),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Evidence objects'), InfoPill(label: 'Source snapshots'), InfoPill(label: 'Workspace routes'), InfoPill(label: 'Report blocks'), InfoPill(label: 'Future alerts')]),
  ]));
}

class _ContextModuleTable extends StatelessWidget {
  const _ContextModuleTable();
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Context Module Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Module')), DataColumn(label: Text('Record Type')), DataColumn(label: Text('Keys')), DataColumn(label: Text('First Use')), DataColumn(label: Text('Next Use')), DataColumn(label: Text('Blocker'))], rows: [for (final item in contextAssetModuleItems) DataRow(cells: [DataCell(SizedBox(width: 150, child: Text(item.module, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 240, child: Text(item.recordType))), DataCell(SizedBox(width: 340, child: Text(item.keys))), DataCell(SizedBox(width: 420, child: Text(item.firstUse))), DataCell(SizedBox(width: 460, child: Text(item.nextUse))), DataCell(SizedBox(width: 360, child: Text(item.blocker)))])])),
  ]));
}

class _ContextStageTable extends StatelessWidget {
  const _ContextStageTable({required this.items});
  final List items;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Context Asset Command Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 150, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 320, child: Text(item.inputs))), DataCell(SizedBox(width: 420, child: Text(item.nextStep)))])])),
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
