import 'package:flutter/material.dart';

import '../models/route_payload.dart';
import 'terminal_primitives.dart';

class RoutePayloadConsumerPreview extends StatelessWidget {
  const RoutePayloadConsumerPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final samplePayload = const RoutePayload(
      sourceObjectType: 'Team',
      sourceObjectId: 'BOS',
      displayLabel: 'Boston Celtics',
      selectedColumns: ['teamId', 'city', 'name', 'abbreviation', 'conference', 'division', 'sourceState'],
      selectedRows: ['BOS'],
      filterSummary: 'source=Team Directory; selectedRow=BOS; rowCount=30',
      sourceSnapshot: 'Connected local reference asset: teams.json',
      readinessState: 'Connected reference',
      blockers: ['team stats pending', 'standings pending', 'rosters pending', 'games pending'],
      targetRoute: 'Workspace',
      availableActions: immediateRouteTargets,
    );

    final rows = <_ConsumerRow>[
      _ConsumerRow('Workspace Studio', 'Creates an active workspace input', 'selectedRows, selectedColumns, filterSummary, sourceSnapshot', 'Team Directory table with selected row and route actions'),
      _ConsumerRow('Compare', 'Pre-fills comparison slot A or B', 'sourceObjectType, sourceObjectId, displayLabel, blockers', 'Team vs Team or Season vs Season comparison shell'),
      _ConsumerRow('Reports', 'Chooses the report shell and populated identity section', 'displayLabel, sourceSnapshot, readinessState, blockers', 'Team Brief, Season Brief, Source Audit, Import Monitor'),
      _ConsumerRow('Saved Views', 'Creates a non-persistent saved table state', 'selectedColumns, filterSummary, selectedRows, sourceSnapshot', 'Saved view preview with filters and columns'),
      _ConsumerRow('Export Center', 'Creates a governed export manifest', 'selectedRows, selectedColumns, filterSummary, sourceSnapshot', 'CSV/table packet preview with download disabled'),
      _ConsumerRow('Alerts', 'Creates a monitor rule preview', 'sourceObjectType, selectedRows, blockers, readinessState', 'Watch row-count, field, source-state, and import movement'),
      _ConsumerRow('Dashboard', 'Creates a command-center card', 'displayLabel, readinessState, blockers, targetRoute', 'Pinned preview card with next action and blocker state'),
      _ConsumerRow('Search', 'Turns a result into an actionable route object', 'sourceObjectType, sourceObjectId, availableActions', 'Open, workspace, compare, report, save, export, alert, audit'),
      _ConsumerRow('Action Center', 'Creates a universal action ticket', 'sourceObjectId, targetRoute, readinessState, availableActions', 'Selected object plus action plus target consumer'),
      _ConsumerRow('Source Audit', 'Preserves trust and provenance context', 'sourceSnapshot, readinessState, blockers, selectedColumns', 'Source posture, lineage readiness, rights notes'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('RoutePayload Consumer Preview', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('This shows how one shared RoutePayload should be interpreted by each terminal consumer. The goal is to stop rebuilding state separately in every tab.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          InfoPill(label: samplePayload.sourceObjectType),
          InfoPill(label: samplePayload.sourceObjectId),
          InfoPill(label: samplePayload.targetRoute),
          InfoPill(label: samplePayload.readinessState),
          InfoPill(label: '${samplePayload.selectedColumns.length} columns'),
          InfoPill(label: '${samplePayload.availableActions.length} actions'),
        ]),
      ])),
      const SizedBox(height: 18),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('Consumer Interpretation Table', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          headingRowColor: WidgetStateProperty.all(terminalPanelDark),
          headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
          dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
          columnSpacing: 30,
          columns: const [
            DataColumn(label: Text('Consumer')),
            DataColumn(label: Text('Interpretation')),
            DataColumn(label: Text('Fields Used')),
            DataColumn(label: Text('Output Preview')),
          ],
          rows: [for (final row in rows) row.toDataRow()],
        )),
      ])),
    ]);
  }
}

class _ConsumerRow {
  const _ConsumerRow(this.consumer, this.interpretation, this.fields, this.output);
  final String consumer;
  final String interpretation;
  final String fields;
  final String output;

  DataRow toDataRow() => DataRow(cells: [
    DataCell(SizedBox(width: 220, child: Text(consumer, style: const TextStyle(fontWeight: FontWeight.w800)))),
    DataCell(SizedBox(width: 430, child: Text(interpretation))),
    DataCell(SizedBox(width: 520, child: Text(fields))),
    DataCell(SizedBox(width: 520, child: Text(output))),
  ]);
}
