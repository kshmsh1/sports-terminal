import 'package:flutter/material.dart';

import 'first_release_route_engine.dart';
import 'first_release_route_outputs.dart';
import 'terminal_primitives.dart';

class FirstReleaseWorkflowObjects extends StatelessWidget {
  const FirstReleaseWorkflowObjects({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('First-Release Workflow Objects', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 10),
        Text('This panel consolidates the first working objects: selected Teams, selected Seasons, operations payloads, generated route outputs, report shells, saved-view previews, export manifests, alert previews, dashboard cards, search route objects, and Action Center payloads.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
        SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          InfoPill(label: 'Team rows selectable'),
          InfoPill(label: 'Season rows selectable'),
          InfoPill(label: 'Operations selectable'),
          InfoPill(label: 'Workspace output'),
          InfoPill(label: 'Compare output'),
          InfoPill(label: 'Report shell'),
          InfoPill(label: 'Saved view preview'),
          InfoPill(label: 'Export manifest'),
          InfoPill(label: 'Alert preview'),
          InfoPill(label: 'Dashboard card'),
          InfoPill(label: 'Search route'),
          InfoPill(label: 'Action payload'),
        ]),
      ])),
      SizedBox(height: 18),
      _WorkflowObjectMilestones(),
      SizedBox(height: 18),
      FirstReleaseRouteEngine(),
      SizedBox(height: 18),
      FirstReleaseRouteOutputs(),
    ]);
  }
}

class _WorkflowObjectMilestones extends StatelessWidget {
  const _WorkflowObjectMilestones();

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: EdgeInsets.all(18), child: Text('Object-Level Release Milestones', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStatePropertyAll(terminalPanelDark),
      headingTextStyle: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: [
        DataColumn(label: Text('Milestone')),
        DataColumn(label: Text('Working Object')),
        DataColumn(label: Text('Current State')),
        DataColumn(label: Text('Next Unlock')),
      ],
      rows: [
        DataRow(cells: [DataCell(Text('1')), DataCell(Text('Selectable reference rows')), DataCell(Text('Teams and Seasons are connected')), DataCell(Text('Promote selected payload state into target tabs'))]),
        DataRow(cells: [DataCell(Text('2')), DataCell(Text('Operations payloads')), DataCell(Text('Sources, imports, coverage, QA, backlog, and completion are visible')), DataCell(Text('Use these as command-center objects'))]),
        DataRow(cells: [DataCell(Text('3')), DataCell(Text('Generated route outputs')), DataCell(Text('Route engine produces Workspace, Compare, Report, Export, Alert, Search, and Action outputs')), DataCell(Text('Add global tab-to-tab navigation state'))]),
        DataRow(cells: [DataCell(Text('4')), DataCell(Text('Workflow consumers')), DataCell(Text('Core MVP screen and Dashboard consume the route layer')), DataCell(Text('Embed same object layer into Workspace, Compare, Reports, Saved Views, Export, Alerts, Search, and Action Center'))]),
        DataRow(cells: [DataCell(Text('5')), DataCell(Text('First sports-data unlock')), DataCell(Text('Player/stat data still source-pending')), DataCell(Text('Import player identity, traditional stats, standings, playoffs, and MVP voting'))]),
      ],
    )),
  ]));
}
