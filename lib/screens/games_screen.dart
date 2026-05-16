import 'package:flutter/material.dart';

import '../data/workspace_build_items.dart';
import '../widgets/terminal_primitives.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _WorkspaceScreen(
      title: 'Games',
      subtitle: 'Future game center for schedules, results, box scores, game logs, playoff series, and matchup-level historical analysis.',
      items: gameWorkspaceItems,
      leadTitle: 'Game Center Principle',
      leadBody: 'Games should eventually become the bridge between season-level summaries and granular player/team performance. We are keeping the schema ready now, but we should connect historical schedule and box-score data only when a reliable source path is selected.',
    );
  }
}

class RostersScreen extends StatelessWidget {
  const RostersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _WorkspaceScreen(
      title: 'Rosters',
      subtitle: 'Future roster workspace for team-season rosters, player active windows, two-way players, assignments, recalls, and lineup context.',
      items: rosterWorkspaceItems,
      leadTitle: 'Roster Graph Principle',
      leadBody: 'Rosters are the connective tissue between players, teams, seasons, transactions, games, and G League development paths. This page will eventually show who was actually attached to a team at a given point in time.',
    );
  }
}

class AwardsScreen extends StatelessWidget {
  const AwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _WorkspaceScreen(
      title: 'Awards',
      subtitle: 'Future awards and honors workspace for MVP, All-NBA, All-Star, defensive honors, rookie honors, voting shares, and historical recognition.',
      items: awardWorkspaceItems,
      leadTitle: 'Awards Context Principle',
      leadBody: 'Awards are high-value historical context that can make player and season pages feel rich before we solve every live feed. They also support comparisons across eras when paired with voting and statistical context.',
    );
  }
}

class DraftScreen extends StatelessWidget {
  const DraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _WorkspaceScreen(
      title: 'Draft',
      subtitle: 'Future draft workspace for draft picks, draft classes, prospect pathways, team draft history, and long-term development outcomes.',
      items: draftWorkspaceItems,
      leadTitle: 'Draft Intelligence Principle',
      leadBody: 'Draft history should eventually connect player identity, team-building, franchise eras, G League development, and prospect outcomes. This will become one of the key bridges between historical data and future scouting-style workflows.',
    );
  }
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _WorkspaceScreen(
      title: 'Transactions',
      subtitle: 'Future transaction workspace for trades, signings, waivers, assignments, recalls, contract events, and roster movement history.',
      items: transactionWorkspaceItems,
      leadTitle: 'Transaction Graph Principle',
      leadBody: 'Transactions are not just news items. They are relationship events that change rosters, team context, player timelines, contract status, draft assets, and G League movement. This page will eventually become the historical movement graph.',
    );
  }
}

class _WorkspaceScreen extends StatelessWidget {
  const _WorkspaceScreen({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.leadTitle,
    required this.leadBody,
  });

  final String title;
  final String subtitle;
  final List<WorkspaceBuildItem> items;
  final String leadTitle;
  final String leadBody;

  @override
  Widget build(BuildContext context) {
    final schemaReady = items.where((item) => item.status.contains('Schema')).length;
    final planned = items.where((item) => item.status == 'Planned').length;
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
                _WorkspaceMetric(label: 'Build Areas', value: '${items.length}', detail: 'Workspace map'),
                _WorkspaceMetric(label: 'Schema Ready', value: '$schemaReady', detail: 'Objects exist'),
                _WorkspaceMetric(label: 'Planned', value: '$planned', detail: 'Data needed'),
                _WorkspaceMetric(label: 'Future', value: '$future', detail: 'Later depth'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leadTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(leadBody, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text('$title Build Map', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
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
                    DataColumn(label: Text('Priority')),
                    DataColumn(label: Text('Area')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('First Data Need')),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 250, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 620, child: Text(item.description))),
                          DataCell(SizedBox(width: 480, child: Text(item.firstDataNeed))),
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

class _WorkspaceMetric extends StatelessWidget {
  const _WorkspaceMetric({required this.label, required this.value, required this.detail});

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
