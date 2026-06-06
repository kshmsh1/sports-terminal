import 'package:flutter/material.dart';

import '../data/coverage_items.dart';
import '../data/import_job_plans.dart';
import '../data/source_registry_entries.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import 'immediate_release_panel.dart';
import 'terminal_primitives.dart';

class FirstReleasePayloadPreview extends StatelessWidget {
  const FirstReleasePayloadPreview({
    super.key,
    this.title = 'First Release Payload Preview',
    this.subtitle = 'Actual connected Teams and Seasons plus operational registries routed into the first workflow surfaces before player/stat imports.',
    this.rowLimit = 10,
    this.showImmediatePanel = true,
    this.panelTarget,
  });

  final String title;
  final String subtitle;
  final int rowLimit;
  final bool showImmediatePanel;
  final String? panelTarget;

  @override
  Widget build(BuildContext context) {
    const repository = NbaAssetRepository();
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([repository.loadTeams(), repository.loadSeasons()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading first-release payload preview...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return TerminalCard(child: Text('Unable to load first-release payload preview: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }
        final teams = snapshot.data![0] as List<Team>;
        final seasons = snapshot.data![1] as List<Season>;
        final visibleTeams = teams.take(rowLimit).toList();
        final visibleSeasons = seasons.take(rowLimit).toList();
        final connectedSources = sourceRegistryEntries.where((item) => item.status == 'Connected').length;
        final connectedEmptySources = sourceRegistryEntries.where((item) => item.status == 'Connected empty').length;
        final targetSources = sourceRegistryEntries.where((item) => item.status == 'Target').length;
        final startedImports = importJobPlans.where((item) => item.status.contains('Started')).length;
        final nextImports = importJobPlans.where((item) => item.status == 'Next' || item.status == 'Next implementation').length;
        final connectedCoverage = coverageItems.where((item) => item.status == 'Connected').length;
        final sourcePendingCoverage = coverageItems.where((item) => item.status.toLowerCase().contains('pending')).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(subtitle, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isWide ? 1.75 : 1.2,
                children: [
                  _Metric(label: 'Team Rows', value: '${teams.length}', detail: 'Connected reference payload'),
                  _Metric(label: 'Season Rows', value: '${seasons.length}', detail: 'Connected time-spine payload'),
                  _Metric(label: 'Sources', value: '${sourceRegistryEntries.length}', detail: '$connectedSources connected / $targetSources targets'),
                  _Metric(label: 'Imports', value: '${importJobPlans.length}', detail: '$startedImports started / $nextImports next'),
                  _Metric(label: 'Coverage Rows', value: '${coverageItems.length}', detail: '$connectedCoverage connected / $sourcePendingCoverage pending'),
                  _Metric(label: 'Connected Empty', value: '$connectedEmptySources', detail: 'Honest source-pending shells'),
                  const _Metric(label: 'Route Model', value: '8', detail: 'Workspace, compare, reports, views, export, alerts, dashboard, audit'),
                  const _Metric(label: 'Data Policy', value: 'No fake', detail: 'Blank when unknown'),
                ],
              );
            }),
          ])),
          const SizedBox(height: 18),
          _RouteActivationTable(teamCount: teams.length, seasonCount: seasons.length),
          const SizedBox(height: 18),
          _TeamPayloadTable(teams: visibleTeams, totalRows: teams.length),
          const SizedBox(height: 18),
          _SeasonPayloadTable(seasons: visibleSeasons, totalRows: seasons.length),
          const SizedBox(height: 18),
          _OperationsPayloadTable(connectedSources: connectedSources, targetSources: targetSources, startedImports: startedImports, nextImports: nextImports, connectedCoverage: connectedCoverage, sourcePendingCoverage: sourcePendingCoverage),
          if (showImmediatePanel) ...[
            const SizedBox(height: 18),
            ImmediateReleasePanel(target: panelTarget, title: panelTarget == null ? 'Immediate Route Contract Board' : '$panelTarget Route Contract Board', subtitle: 'The route contracts below are the visible bridge from connected rows into Workspace Studio, Compare, Reports, Saved Views, Export Center, Alerts, Dashboard, Search, Action Center, and Source Audit.'),
          ],
        ]);
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: terminalPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: terminalBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalTextMuted, fontSize: 11)),
      const SizedBox(height: 6),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
      const Spacer(),
      Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalAccent, fontSize: 10)),
    ]),
  );
}

class _RouteActivationTable extends StatelessWidget {
  const _RouteActivationTable({required this.teamCount, required this.seasonCount});
  final int teamCount;
  final int seasonCount;

  @override
  Widget build(BuildContext context) {
    final rows = <_RouteRow>[
      _RouteRow('Team Directory', '$teamCount rows', 'teamId, city, name, abbreviation, conference, division', 'Workspace, Compare, Reports, Saved Views, Export, Alerts, Dashboard, Source Audit', 'Ready now'),
      _RouteRow('Season Catalog', '$seasonCount rows', 'seasonId, label, startYear, endYear, league', 'Workspace, Compare, Reports, Saved Views, Export, Alerts, Dashboard, Source Audit', 'Ready now'),
      _RouteRow('Source Registry', '${sourceRegistryEntries.length} rows', 'sourceId, domain, type, status, rights posture, cadence', 'Workspace, Compare, Reports, Export, Alerts, Dashboard, Lineage, QA', 'Ready now'),
      _RouteRow('Import Jobs', '${importJobPlans.length} rows', 'jobId, domain, status, input, output, validation', 'Workspace, Compare, Reports, Export, Alerts, Dashboard, QA', 'Ready now'),
      _RouteRow('Data Coverage', '${coverageItems.length} rows', 'dataset, domain, rows, status, priority, next step', 'Workspace, Reports, Export, Dashboard, QA, Product Backlog', 'Ready now'),
      const _RouteRow('Player Identity', '0 real rows', 'playerId, displayName, aliases, source metadata', 'Players, Stats, Awards, Draft, Rosters, Reports, Compare', 'Next data wave'),
      const _RouteRow('Traditional Stats', '0 real rows', 'player/team season stats, PF, shooting, season type, source state', 'Stats, Workspace, Compare, Reports, Awards, Export, Alerts', 'After identity'),
      const _RouteRow('MVP Voting', '0 real rows', 'rank, points, first-place votes, vote share, player/team/season joins', 'Awards, Reports, Compare, Custom MVP Workspace', 'After stats/context'),
    ];
    return _TableShell(title: 'Route Activation Matrix', child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Payload')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Columns')), DataColumn(label: Text('Routes')), DataColumn(label: Text('State'))],
      rows: [for (final row in rows) row.toDataRow()],
    ));
  }
}

class _TeamPayloadTable extends StatelessWidget {
  const _TeamPayloadTable({required this.teams, required this.totalRows});
  final List<Team> teams;
  final int totalRows;

  @override
  Widget build(BuildContext context) => _TableShell(title: 'Team Directory Payload Preview', trailing: '$totalRows connected rows', child: DataTable(
    headingRowColor: WidgetStateProperty.all(terminalPanelDark),
    headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
    dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
    columnSpacing: 30,
    columns: const [DataColumn(label: Text('teamId')), DataColumn(label: Text('Team')), DataColumn(label: Text('Conference')), DataColumn(label: Text('Division')), DataColumn(label: Text('Source')), DataColumn(label: Text('Route Actions'))],
    rows: [for (final team in teams) DataRow(cells: [
      DataCell(Text(team.id, style: const TextStyle(fontWeight: FontWeight.w800))),
      DataCell(SizedBox(width: 240, child: Text('${team.city} ${team.name} (${team.abbreviation})'))),
      DataCell(Text(team.conference)),
      DataCell(SizedBox(width: 180, child: Text(team.division))),
      const DataCell(InfoPill(label: 'Connected reference')),
      DataCell(_RoutePills()),
    ])],
  ));
}

class _SeasonPayloadTable extends StatelessWidget {
  const _SeasonPayloadTable({required this.seasons, required this.totalRows});
  final List<Season> seasons;
  final int totalRows;

  @override
  Widget build(BuildContext context) => _TableShell(title: 'Season Catalog Payload Preview', trailing: '$totalRows connected rows', child: DataTable(
    headingRowColor: WidgetStateProperty.all(terminalPanelDark),
    headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
    dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
    columnSpacing: 30,
    columns: const [DataColumn(label: Text('seasonId')), DataColumn(label: Text('Label')), DataColumn(label: Text('Years')), DataColumn(label: Text('League')), DataColumn(label: Text('Source')), DataColumn(label: Text('Route Actions'))],
    rows: [for (final season in seasons) DataRow(cells: [
      DataCell(Text(season.id, style: const TextStyle(fontWeight: FontWeight.w800))),
      DataCell(SizedBox(width: 150, child: Text(season.label))),
      DataCell(Text('${season.startYear}-${season.endYear}')),
      DataCell(Text(season.league)),
      const DataCell(InfoPill(label: 'Connected reference')),
      DataCell(_RoutePills()),
    ])],
  ));
}

class _OperationsPayloadTable extends StatelessWidget {
  const _OperationsPayloadTable({required this.connectedSources, required this.targetSources, required this.startedImports, required this.nextImports, required this.connectedCoverage, required this.sourcePendingCoverage});
  final int connectedSources;
  final int targetSources;
  final int startedImports;
  final int nextImports;
  final int connectedCoverage;
  final int sourcePendingCoverage;

  @override
  Widget build(BuildContext context) {
    final rows = <_OperationsRow>[
      _OperationsRow('Source Registry', '${sourceRegistryEntries.length}', '$connectedSources connected / $targetSources target', 'Source Audit, Workspace, Report, Export, Alert, Dashboard'),
      _OperationsRow('Import Jobs', '${importJobPlans.length}', '$startedImports started / $nextImports next', 'Import Monitor, Workspace, Report, Export, QA, Dashboard'),
      _OperationsRow('Data Coverage', '${coverageItems.length}', '$connectedCoverage connected / $sourcePendingCoverage source-pending', 'Coverage Report, Workspace, Export, QA, Dashboard'),
      const _OperationsRow('QA Readiness', 'Registry-backed', 'Release gate ready', 'QA Report, Export, Alert, Dashboard'),
      const _OperationsRow('Product Backlog', 'Generated rows', 'MVP lanes active', 'Backlog Report, Saved View, Export, Dashboard'),
      const _OperationsRow('NBA MVP Completion', 'Ship-state rows', 'Endgame tracker active', 'Executive Report, Export, Dashboard'),
    ];
    return _TableShell(title: 'Operations Payload Preview', child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Operational Payload')), DataColumn(label: Text('Rows')), DataColumn(label: Text('State')), DataColumn(label: Text('Routes'))],
      rows: [for (final row in rows) row.toDataRow()],
    ));
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
      if (trailing != null) InfoPill(label: trailing!),
    ])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
  ]));
}

class _RoutePills extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 620, child: Wrap(spacing: 8, runSpacing: 8, children: [
    InfoPill(label: 'Open'),
    InfoPill(label: 'Workspace'),
    InfoPill(label: 'Compare'),
    InfoPill(label: 'Report'),
    InfoPill(label: 'Saved View'),
    InfoPill(label: 'Export'),
    InfoPill(label: 'Alert'),
    InfoPill(label: 'Audit'),
  ]));
}

class _RouteRow {
  const _RouteRow(this.payload, this.rows, this.columns, this.routes, this.state);
  final String payload;
  final String rows;
  final String columns;
  final String routes;
  final String state;
  DataRow toDataRow() => DataRow(cells: [
    DataCell(SizedBox(width: 200, child: Text(payload, style: const TextStyle(fontWeight: FontWeight.w800)))),
    DataCell(SizedBox(width: 120, child: Text(rows))),
    DataCell(SizedBox(width: 430, child: Text(columns))),
    DataCell(SizedBox(width: 640, child: Text(routes))),
    DataCell(InfoPill(label: state)),
  ]);
}

class _OperationsRow {
  const _OperationsRow(this.payload, this.rows, this.state, this.routes);
  final String payload;
  final String rows;
  final String state;
  final String routes;
  DataRow toDataRow() => DataRow(cells: [
    DataCell(SizedBox(width: 230, child: Text(payload, style: const TextStyle(fontWeight: FontWeight.w800)))),
    DataCell(SizedBox(width: 130, child: Text(rows))),
    DataCell(SizedBox(width: 300, child: Text(state))),
    DataCell(SizedBox(width: 640, child: Text(routes))),
  ]);
}
