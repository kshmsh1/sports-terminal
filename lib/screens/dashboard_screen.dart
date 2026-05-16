import 'package:flutter/material.dart';

import '../data/alert_rule_items.dart';
import '../data/coverage_items.dart';
import '../data/import_job_plans.dart';
import '../data/report_library_items.dart';
import '../data/saved_view_items.dart';
import '../data/source_registry_entries.dart';
import '../widgets/terminal_primitives.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectedDatasets = coverageItems.where((item) => item.status == 'Connected').length;
    final pendingDatasets = coverageItems.where((item) => item.status.toLowerCase().contains('pending')).length;
    final knownRows = coverageItems.fold<int>(0, (sum, item) => sum + item.recordCount);
    final connectedSources = sourceRegistryEntries.where((item) => item.status == 'Connected').length;
    final targetSources = sourceRegistryEntries.where((item) => item.status == 'Target').length;
    final startedJobs = importJobPlans.where((item) => item.status.contains('Started')).length;
    final workflowCount = reportLibraryItems.length + savedViewItems.length + alertRuleItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'NBA Command Center',
          subtitle: 'Historical-first operating system for NBA entities, events, performance, postseason context, recognition, movement, reports, saved views, alerts, sources, and data operations.',
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 1.8 : 1.45,
              children: [
                _MetricCard(label: 'Coverage Datasets', value: '${coverageItems.length}', detail: '$connectedDatasets connected / $pendingDatasets pending'),
                _MetricCard(label: 'Known Records', value: '$knownRows', detail: 'Real rows only'),
                _MetricCard(label: 'Source Registry', value: '${sourceRegistryEntries.length}', detail: '$connectedSources connected / $targetSources targets'),
                _MetricCard(label: 'Import Jobs', value: '${importJobPlans.length}', detail: '$startedJobs started loaders'),
                _MetricCard(label: 'Workflow Items', value: '$workflowCount', detail: 'Reports + views + alerts'),
                _MetricCard(label: 'Reports', value: '${reportLibraryItems.length}', detail: 'Reusable terminal templates'),
                _MetricCard(label: 'Saved Views', value: '${savedViewItems.length}', detail: 'Workspace presets'),
                const _MetricCard(label: 'Data Policy', value: 'Real', detail: 'No fake sports records'),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _MvpCockpitPanel(),
        const SizedBox(height: 24),
        const _CoreModuleMatrix(),
        const SizedBox(height: 24),
        _CoveragePanel(items: coverageItems),
        const SizedBox(height: 24),
        _OperationsPanel(connectedSources: connectedSources, targetSources: targetSources, startedJobs: startedJobs),
        const SizedBox(height: 24),
        const _BuildSequencePanel(),
        const SizedBox(height: 24),
        const _TerminalPanel(
          title: 'Current Product Direction',
          lines: [
            '1. Build NBA first and treat every future sport as an extension of the same operating model.',
            '2. Use stable local JSON assets now, then replace or augment them with approved source imports later.',
            '3. Keep missing values blank. Never convert unknown statistics into fake zeros.',
            '4. Separate source data, user analysis, reports, saved views, alerts, and Build Lab governance.',
            '5. Keep broadening the terminal across players, teams, seasons, games, rosters, awards, draft, transactions, contracts, stats, standings, playoffs, compare, reports, media, scouting, and operations.',
          ],
        ),
        const SizedBox(height: 24),
        const _TerminalPanel(
          title: 'Near-Term Build Priority',
          lines: [
            '1. Convert more core product surfaces into selected-detail workspaces with joins into adjacent modules.',
            '2. Make Dashboard, Search, Product Backlog, Data Coverage, Data Health, QA, and Source Registry act like operating controls rather than static planning pages.',
            '3. Begin the player identity source path before importing player stats, award races, rosters, draft links, or transactions.',
            '4. Keep Stats important but not dominant: the terminal also needs games, rosters, awards, draft, transactions, contracts, scouting, media, saved views, alerts, and reports.',
            '5. Preserve the end-platform shape: source-backed data, joined entities, reusable workflows, trust controls, and future sport expansion.',
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail});

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

class _MvpCockpitPanel extends StatelessWidget {
  const _MvpCockpitPanel();

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MVP Cockpit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('The first working platform should feel like a complete local NBA terminal before live feeds exist. The user should be able to search across the system, inspect source-aware entities, understand missing data, compare records, generate report shells, save workspaces, and trust every blank value.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: const [
          InfoPill(label: 'NBA first'),
          InfoPill(label: 'Historical first'),
          InfoPill(label: 'Local assets'),
          InfoPill(label: 'No fake records'),
          InfoPill(label: 'Source metadata'),
          InfoPill(label: 'Workflow ready'),
          InfoPill(label: 'G League later'),
        ]),
      ]),
    );
  }
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: const TextStyle(color: terminalTextSoft, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class _CoreModuleMatrix extends StatelessWidget {
  const _CoreModuleMatrix();

  @override
  Widget build(BuildContext context) {
    final rows = <_ModuleRow>[
      const _ModuleRow('Search', 'Command layer', 'Asset-aware', 'Route to entities, reports, datasets, saved views, and source operations.'),
      const _ModuleRow('Players', 'Identity hub', 'Source pending', 'Load player identity and activate player detail, roster, award, draft, and transaction joins.'),
      const _ModuleRow('Teams', 'Franchise hub', 'Reference ready', 'Attach team-season stats, standings, rosters, games, transactions, and franchise history.'),
      const _ModuleRow('Seasons', 'Time spine', 'Reference ready', 'Attach standings, awards, playoffs, leaders, league context, draft class, and era notes.'),
      const _ModuleRow('Games', 'Event layer', 'Asset-backed', 'Add schedules, results, box scores, matchup context, game logs, and chart inputs.'),
      const _ModuleRow('Rosters', 'Player-team graph', 'Asset-backed', 'Add roster windows, contract type, two-way status, assignments, recalls, and game eligibility.'),
      const _ModuleRow('Awards', 'Recognition layer', 'Race-ready model', 'Add winners, runners-up, finalists, first-place votes, points, shares, and season boards.'),
      const _ModuleRow('Draft', 'Talent pipeline', 'Asset-backed', 'Connect picks to player identity, outcomes, development pathways, awards, and team history.'),
      const _ModuleRow('Transactions', 'Movement graph', 'Asset-backed', 'Build movement timelines, roster effects, trade trees, contract events, and team-building reports.'),
      const _ModuleRow('Contracts', 'Front office layer', 'Planned', 'Add salary, guarantees, options, extensions, cap context, and transaction linkage.'),
      const _ModuleRow('Stats', 'Analytical engine', 'Schema expanding', 'Add regular/playoff splits, view modes, stat families, advanced fields, and trend charts.'),
      const _ModuleRow('Standings', 'Record context', 'Asset-aware', 'Add seeds, win/loss context, conference/division rank, team stat joins, and playoff qualification.'),
      const _ModuleRow('Playoffs', 'Postseason path', 'Asset-aware', 'Add series detail, bracket paths, seeds, game links, team history, and reports.'),
      const _ModuleRow('Compare', 'Decision workspace', 'Asset-aware', 'Activate side-by-side player, team, season, draft, award, transaction, and franchise comparisons.'),
      const _ModuleRow('Reports', 'Output layer', 'Builder shell', 'Generate player, team, season, draft, award, transaction, and source-backed reports.'),
      const _ModuleRow('Saved Views', 'Workspace memory', 'Template ready', 'Persist repeated filters, tables, charts, comparisons, and report states.'),
      const _ModuleRow('Alerts', 'Monitoring layer', 'Template ready', 'Evaluate saved-view changes, stat thresholds, import failures, roster changes, and data-health events.'),
      const _ModuleRow('Source Ops', 'Trust layer', 'Build Lab', 'Track sources, imports, lineage, policy, QA, data health, and validation output.'),
    ];
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('Core Module Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columnSpacing: 30,
            columns: const [DataColumn(label: Text('Module')), DataColumn(label: Text('Role')), DataColumn(label: Text('MVP State')), DataColumn(label: Text('Next Capability'))],
            rows: [for (final row in rows) row.toDataRow()],
          ),
        ),
      ]),
    );
  }
}

class _ModuleRow {
  const _ModuleRow(this.module, this.role, this.state, this.nextCapability);
  final String module;
  final String role;
  final String state;
  final String nextCapability;

  DataRow toDataRow() => DataRow(cells: [
        DataCell(SizedBox(width: 160, child: Text(module, style: const TextStyle(fontWeight: FontWeight.w800)))),
        DataCell(SizedBox(width: 210, child: Text(role))),
        DataCell(InfoPill(label: state)),
        DataCell(SizedBox(width: 640, child: Text(nextCapability))),
      ]);
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Data Coverage Snapshot', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
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
                DataColumn(label: Text('Dataset')),
                DataColumn(label: Text('Domain')),
                DataColumn(label: Text('Rows')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Next Step')),
              ],
              rows: [
                for (final item in items)
                  DataRow(cells: [
                    DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                    DataCell(SizedBox(width: 220, child: Text(item.dataset, style: const TextStyle(fontWeight: FontWeight.w800)))),
                    DataCell(Text(item.domain)),
                    DataCell(Text('${item.recordCount}')),
                    DataCell(InfoPill(label: item.status)),
                    DataCell(SizedBox(width: 520, child: Text(item.nextStep))),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({required this.connectedSources, required this.targetSources, required this.startedJobs});

  final int connectedSources;
  final int targetSources;
  final int startedJobs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(
          crossAxisCount: isWide ? 3 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: isWide ? 2.2 : 2.8,
          children: [
            _MetricCard(label: 'Connected Sources', value: '$connectedSources', detail: 'Reference layers live'),
            _MetricCard(label: 'Target Sources', value: '$targetSources', detail: 'Near-term source work'),
            _MetricCard(label: 'Started Jobs', value: '$startedJobs', detail: 'Repository loaders ready'),
          ],
        );
      },
    );
  }
}

class _BuildSequencePanel extends StatelessWidget {
  const _BuildSequencePanel();

  @override
  Widget build(BuildContext context) {
    final rows = <_BuildRow>[
      const _BuildRow('1', 'Reference foundation', 'Teams, seasons, source registry, data policy, search, and navigation behave consistently.'),
      const _BuildRow('2', 'Entity activation', 'Players, teams, seasons, games, rosters, awards, draft, and transactions each have selected-detail workflows.'),
      const _BuildRow('3', 'Statistical core', 'Player/team regular season and playoff stats support families, view modes, source metadata, and clean joins.'),
      const _BuildRow('4', 'Context graph', 'Standings, playoffs, award races, draft outcomes, roster windows, and movement history connect to entities.'),
      const _BuildRow('5', 'Workflow layer', 'Compare, reports, saved views, alerts, exports, and QA checks operate from the same local data model.'),
      const _BuildRow('6', 'Ingestion layer', 'Approved import scripts create raw snapshots, normalized assets, validation output, and lineage records.'),
      const _BuildRow('7', 'Expansion layer', 'G League and other sports reuse the same entity, event, stat, source, workflow, and governance architecture.'),
    ];
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('End-Platform Build Sequence', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columnSpacing: 34,
            columns: const [DataColumn(label: Text('Phase')), DataColumn(label: Text('Objective')), DataColumn(label: Text('Exit Condition'))],
            rows: [for (final row in rows) row.toDataRow()],
          ),
        ),
      ]),
    );
  }
}

class _BuildRow {
  const _BuildRow(this.phase, this.objective, this.exitCondition);
  final String phase;
  final String objective;
  final String exitCondition;

  DataRow toDataRow() => DataRow(cells: [
        DataCell(Text(phase, style: const TextStyle(fontWeight: FontWeight.w900))),
        DataCell(SizedBox(width: 320, child: Text(objective, style: const TextStyle(fontWeight: FontWeight.w800)))),
        DataCell(SizedBox(width: 680, child: Text(exitCondition))),
      ]);
}
