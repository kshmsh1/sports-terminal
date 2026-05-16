import 'package:flutter/material.dart';

import '../data/workspace_build_items.dart';
import '../widgets/terminal_primitives.dart';

class ContractsScreen extends StatelessWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WorkspaceScreen(
      title: 'Contracts',
      subtitle: 'Future salary, cap, contract, payroll, guarantee, option, and roster-construction intelligence workspace.',
      leadTitle: 'Financial Data Principle',
      leadBody: 'Contracts and cap data should be separated from official box-score data because source rights, definitions, and update cadence are different. This page is schema-ready, but production use requires a lawful source or licensed provider.',
      items: contractWorkspaceItems,
    );
  }
}

class MediaResearchScreen extends StatelessWidget {
  const MediaResearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WorkspaceScreen(
      title: 'Media & Research',
      subtitle: 'Future research workspace for source-linked articles, reports, internal notes, clips, documents, entity links, and narrative timelines.',
      leadTitle: 'Research Layer Principle',
      leadBody: 'Sports Terminal should eventually organize not only stats but also the evidence and narrative context around teams, players, games, transactions, and eras.',
      items: mediaWorkspaceItems,
    );
  }
}

class ScoutingScreen extends StatelessWidget {
  const ScoutingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WorkspaceScreen(
      title: 'Scouting',
      subtitle: 'Future scouting workspace for player profiles, team style, prospect evaluation, comparable-player workflows, and structured notes.',
      leadTitle: 'Scouting Workflow Principle',
      leadBody: 'Scouting should combine structured data, qualitative notes, source evidence, and repeatable templates while clearly labeling analysis separately from source data.',
      items: scoutingWorkspaceItems,
    );
  }
}

class _WorkspaceScreen extends StatelessWidget {
  const _WorkspaceScreen({required this.title, required this.subtitle, required this.leadTitle, required this.leadBody, required this.items});

  final String title;
  final String subtitle;
  final String leadTitle;
  final String leadBody;
  final List<WorkspaceBuildItem> items;

  @override
  Widget build(BuildContext context) {
    final schemaReady = items.where((item) => item.status.contains('Schema')).length;
    final future = items.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 2.0 : 1.5,
              children: [
                _Metric(label: 'Build Areas', value: '${items.length}', detail: 'Workspace map'),
                _Metric(label: 'Schema Ready', value: '$schemaReady', detail: 'Objects exist'),
                _Metric(label: 'Future', value: '$future', detail: 'Later depth'),
                const _Metric(label: 'Mode', value: 'Design', detail: 'Source pending'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(leadTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(leadBody, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Text('$title Build Map', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 30,
                columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Area')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('First Data Need'))],
                rows: [
                  for (final item in items)
                    DataRow(cells: [
                      DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(SizedBox(width: 260, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(InfoPill(label: item.status)),
                      DataCell(SizedBox(width: 640, child: Text(item.description))),
                      DataCell(SizedBox(width: 500, child: Text(item.firstDataNeed))),
                    ]),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
  }
}
