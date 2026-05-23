import 'package:flutter/material.dart';

import '../data/source_backed_nba_data_wave_items.dart';
import '../models/registry_item.dart';
import 'terminal_primitives.dart';

class SourceBackedDataWavePanel extends StatelessWidget {
  const SourceBackedDataWavePanel({super.key, this.maxRows});

  final int? maxRows;

  @override
  Widget build(BuildContext context) {
    final visibleItems = maxRows == null
        ? sourceBackedNbaDataWaveItems
        : sourceBackedNbaDataWaveItems.take(maxRows!).toList();
    final p0 = sourceBackedNbaDataWaveItems.where((item) => item.priority == 'P0').length;
    final next = sourceBackedNbaDataWaveItems.where((item) => item.status == 'Next').length;
    final inProgress = sourceBackedNbaDataWaveItems.where((item) => item.status == 'In progress').length;
    final planned = sourceBackedNbaDataWaveItems.where((item) => item.status == 'Planned').length;
    final gated = sourceBackedNbaDataWaveItems.where((item) => item.status.toLowerCase().contains('gated')).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Source-Backed NBA Data Wave Cockpit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('This is the execution bridge from route previews into real NBA analytics. The order matters: freeze the route layer, publish player identity, import traditional stats, add standings and playoff context, then ship MVP voting as the first signature award workflow.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return GridView.count(
            crossAxisCount: isWide ? 5 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 2.25 : 1.45,
            children: [
              _Metric(label: 'Wave Items', value: '${sourceBackedNbaDataWaveItems.length}', detail: 'full sequence'),
              _Metric(label: 'P0', value: '$p0', detail: 'critical path'),
              _Metric(label: 'In Progress', value: '$inProgress', detail: 'route layer'),
              _Metric(label: 'Next / Planned', value: '$next / $planned', detail: 'import wave'),
              _Metric(label: 'Gated', value: '$gated', detail: 'future layers'),
            ],
          );
        }),
      ])),
      const SizedBox(height: 18),
      _SequenceTable(),
      const SizedBox(height: 18),
      _ItemTable(items: visibleItems),
    ]);
  }
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

class _SequenceTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const rows = [
      ['0', 'Route Layer', 'selected Teams, Seasons, and operations rows route into every workflow consumer', 'shared route payload model'],
      ['1', 'Player Identity', 'stable playerId joins for stats, awards, rosters, draft, transactions, and reports', 'source choice, schema, aliases'],
      ['2', 'Traditional Stats', 'player and team stat tables become the first true analytical payloads', 'player identity and source snapshots'],
      ['3', 'Standings and Playoffs', 'records, seeds, postseason paths, and season/team context', 'team-season joins'],
      ['4', 'MVP Voting', 'first signature award race board and custom MVP workflow', 'stats plus standings context'],
      ['5', 'Games and Box Scores', 'game logs, trends, matchup context, and fantasy relevance', 'schedule and box-score source posture'],
      ['6', 'Rosters, Draft, Transactions', 'player-team graph, acquisition paths, and movement history', 'identity joins and source coverage'],
      ['7+', 'Advanced and Network Layers', 'advanced stats, tracking, fantasy, scouting, community, contracts', 'rights, persistence, moderation, backend'],
    ];
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.all(18), child: Text('Wave Sequence', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
      const Divider(height: 1, color: terminalBorder),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columnSpacing: 30,
        columns: const [DataColumn(label: Text('Wave')), DataColumn(label: Text('Focus')), DataColumn(label: Text('Unlock')), DataColumn(label: Text('Gate'))],
        rows: [for (final row in rows) DataRow(cells: [
          DataCell(SizedBox(width: 70, child: Text(row[0], style: const TextStyle(fontWeight: FontWeight.w900)))),
          DataCell(SizedBox(width: 230, child: Text(row[1], style: const TextStyle(fontWeight: FontWeight.w800)))),
          DataCell(SizedBox(width: 680, child: Text(row[2]))),
          DataCell(SizedBox(width: 420, child: Text(row[3]))),
        ])],
      )),
    ]));
  }
}

class _ItemTable extends StatelessWidget {
  const _ItemTable({required this.items});

  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Expanded(child: Text('Source-Backed Execution Items', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), Text('${items.length} shown', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [
        DataColumn(label: Text('Priority')),
        DataColumn(label: Text('Item')),
        DataColumn(label: Text('Wave')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Inputs')),
        DataColumn(label: Text('Next Step')),
      ],
      rows: [for (final item in items) DataRow(cells: [
        DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
        DataCell(SizedBox(width: 330, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
        DataCell(SizedBox(width: 240, child: Text(item.category))),
        DataCell(InfoPill(label: item.status)),
        DataCell(SizedBox(width: 520, child: Text(item.inputs))),
        DataCell(SizedBox(width: 620, child: Text(item.nextStep))),
      ])],
    )),
  ]));
}
