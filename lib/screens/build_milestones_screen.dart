import 'package:flutter/material.dart';

import '../data/build_milestone_items.dart';
import '../widgets/terminal_primitives.dart';

class BuildMilestonesScreen extends StatelessWidget {
  const BuildMilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final next = buildMilestoneItems.where((item) => item.status == 'Next').length;
    final inProgress = buildMilestoneItems.where((item) => item.status == 'In progress').length;
    final planned = buildMilestoneItems.where((item) => item.status == 'Planned').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Build Milestones',
          subtitle: 'A clearer product roadmap so the early architecture work does not turn into a permanent pile of disconnected tabs.',
        ),
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
                _MilestoneMetric(label: 'Milestones', value: '${buildMilestoneItems.length}', detail: 'Current roadmap'),
                _MilestoneMetric(label: 'In Progress', value: '$inProgress', detail: 'Foundation build'),
                _MilestoneMetric(label: 'Next', value: '$next', detail: 'Player identity'),
                _MilestoneMetric(label: 'Planned', value: '$planned', detail: 'Historical data layers'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Navigation Note',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'The large sidebar is temporary while we are designing the product architecture. As the app matures, many architecture, policy, schema, and roadmap pages should move into an Admin / Build Lab section, while the main user navigation stays focused on actual workflows like Dashboard, Players, Teams, Seasons, Games, Search, Reports, and Compare.',
                style: TextStyle(color: terminalTextSoft, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Milestone Roadmap',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
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
                    DataColumn(label: Text('Phase')),
                    DataColumn(label: Text('Milestone')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Success Criteria')),
                  ],
                  rows: [
                    for (final item in buildMilestoneItems)
                      DataRow(
                        cells: [
                          DataCell(Text(item.phase, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 260, child: Text(item.milestone, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 560, child: Text(item.description))),
                          DataCell(SizedBox(width: 620, child: Text(item.successCriteria))),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneMetric extends StatelessWidget {
  const _MilestoneMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
        ],
      ),
    );
  }
}
