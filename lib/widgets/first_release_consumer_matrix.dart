import 'package:flutter/material.dart';

import 'terminal_primitives.dart';

class FirstReleaseConsumerMatrix extends StatelessWidget {
  const FirstReleaseConsumerMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('First-Release Consumer Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('This table defines how the selected Team, Season, or Operations payload should be consumed by the main workflow tabs.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
          ]),
        ),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columnSpacing: 30,
            columns: const [
              DataColumn(label: Text('Consumer')),
              DataColumn(label: Text('Consumes')),
              DataColumn(label: Text('Working Preview Now')),
              DataColumn(label: Text('Next Unlock')),
            ],
            rows: const [
              DataRow(cells: [DataCell(Text('Workspace Studio')), DataCell(Text('selected row, columns, source snapshot')), DataCell(Text('team, season, source, import, coverage workspaces')), DataCell(Text('promote selected payload into screen state'))]),
              DataRow(cells: [DataCell(Text('Compare')), DataCell(Text('two selected objects and blockers')), DataCell(Text('Team vs Team, Season vs Season, Source vs Source')), DataCell(Text('pre-fill comparison slots from row actions'))]),
              DataRow(cells: [DataCell(Text('Reports')), DataCell(Text('selected object and report shell')), DataCell(Text('Team Brief, Season Brief, Source Audit, Coverage Report')), DataCell(Text('generate a populated preview card'))]),
              DataRow(cells: [DataCell(Text('Saved Views')), DataCell(Text('filters, columns, rows, source snapshot')), DataCell(Text('non-persistent table-state previews')), DataCell(Text('store local table state'))]),
              DataRow(cells: [DataCell(Text('Export Center')), DataCell(Text('manifest, rows, columns, source notes')), DataCell(Text('Team, Season, Operations export previews')), DataCell(Text('bind selected payload to export template'))]),
              DataRow(cells: [DataCell(Text('Alerts')), DataCell(Text('watched rows and trigger preview')), DataCell(Text('team, season, source, import monitors')), DataCell(Text('connect saved view preview to monitor rule'))]),
              DataRow(cells: [DataCell(Text('Dashboard')), DataCell(Text('status card and next action')), DataCell(Text('connected data and release cards')), DataCell(Text('pin selected workflow output'))]),
              DataRow(cells: [DataCell(Text('Search')), DataCell(Text('result, actions, target route')), DataCell(Text('team, season, source, import result families')), DataCell(Text('result row creates route payload'))]),
              DataRow(cells: [DataCell(Text('Action Center')), DataCell(Text('object, action, target, readiness')), DataCell(Text('universal action payload preview')), DataCell(Text('action ticket consumes selected object'))]),
            ],
          ),
        ),
      ]),
    );
  }
}
