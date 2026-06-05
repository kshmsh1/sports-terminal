import 'package:flutter/material.dart';

import '../data/import_acceptance_gate_items.dart';
import '../data/player_identity_schema_gate_items.dart';
import '../models/registry_item.dart';
import 'terminal_primitives.dart';

class PlayerIdentityPreIngestionPanel extends StatelessWidget {
  const PlayerIdentityPreIngestionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final requiredSchema = playerIdentitySchemaGateItems.where((item) => item.priority == 'P0').length;
    final requiredImport = importAcceptanceGateItems.where((item) => item.priority == 'P0').length;
    final requiredTotal = requiredSchema + requiredImport;
    final schemaReady = playerIdentitySchemaGateItems.where((item) => item.status.toLowerCase().contains('required')).length;
    final importReady = importAcceptanceGateItems.where((item) => item.status == 'Required').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Player Identity Pre-Ingestion Gate', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('Player identity is the first real data unlock. This panel defines the schema and import acceptance gates that must be satisfied before player rows become the join spine for stats, awards, rosters, draft, transactions, reports, and search.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: isWide ? 2.25 : 1.45, children: [
            _Metric(label: 'Schema Gates', value: '${playerIdentitySchemaGateItems.length}', detail: '$requiredSchema P0'),
            _Metric(label: 'Import Gates', value: '${importAcceptanceGateItems.length}', detail: '$requiredImport P0'),
            _Metric(label: 'Required', value: '$requiredTotal', detail: 'pre-ingestion checks'),
            _Metric(label: 'Specified', value: '${schemaReady + importReady}', detail: 'contract rows'),
          ]);
        }),
      ])),
      const SizedBox(height: 18),
      _GateTable(title: 'Player Identity Schema Gates', items: playerIdentitySchemaGateItems),
      const SizedBox(height: 18),
      _GateTable(title: 'Import Acceptance Gates', items: importAcceptanceGateItems),
    ]);
  }
}

class _GateTable extends StatelessWidget {
  const _GateTable({required this.title, required this.items});
  final String title;
  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), Text('${items.length} gates', style: const TextStyle(color: terminalTextMuted))])),
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
        DataColumn(label: Text('Next Step')),
      ],
      rows: [for (final item in items) DataRow(cells: [
        DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
        DataCell(SizedBox(width: 290, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
        DataCell(SizedBox(width: 180, child: Text(item.category))),
        DataCell(InfoPill(label: item.status)),
        DataCell(SizedBox(width: 620, child: Text(item.description))),
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
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
    Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
  ]));
}
