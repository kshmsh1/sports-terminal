import 'package:flutter/material.dart';

import '../data/coverage_items.dart';
import '../data/import_job_plans.dart';
import '../data/source_registry_entries.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import 'terminal_primitives.dart';

class FirstReleaseRouteOutputs extends StatelessWidget {
  const FirstReleaseRouteOutputs({super.key});

  @override
  Widget build(BuildContext context) {
    const repository = NbaAssetRepository();
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([repository.loadTeams(), repository.loadSeasons()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading concrete route output previews...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return TerminalCard(child: Text('Unable to load route output previews: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }
        final teams = snapshot.data![0] as List<Team>;
        final seasons = snapshot.data![1] as List<Season>;
        final firstTeam = teams.isEmpty ? null : teams.first;
        final secondTeam = teams.length > 1 ? teams[1] : firstTeam;
        final firstSeason = seasons.isEmpty ? null : seasons.first;
        final secondSeason = seasons.length > 1 ? seasons[1] : firstSeason;
        final connectedSources = sourceRegistryEntries.where((item) => item.status == 'Connected').length;
        final connectedEmptySources = sourceRegistryEntries.where((item) => item.status == 'Connected empty').length;
        final targetSources = sourceRegistryEntries.where((item) => item.status == 'Target').length;
        final startedImports = importJobPlans.where((item) => item.status.contains('Started')).length;
        final nextImports = importJobPlans.where((item) => item.status.toLowerCase().contains('next')).length;
        final connectedCoverage = coverageItems.where((item) => item.status == 'Connected').length;
        final pendingCoverage = coverageItems.where((item) => item.status.toLowerCase().contains('pending')).length;

        final outputs = <_OutputRow>[
          _OutputRow('Workspace', 'Team Directory Workspace', '${teams.length} rows', _teamWorkspace(firstTeam), 'Open, compare, report, save view, export, alert, audit'),
          _OutputRow('Workspace', 'Season Catalog Workspace', '${seasons.length} rows', _seasonWorkspace(firstSeason), 'Open, compare, report, save view, export, alert, audit'),
          _OutputRow('Workspace', 'Source Audit Workspace', '${sourceRegistryEntries.length} rows', '$connectedSources connected sources, $connectedEmptySources connected-empty sources, $targetSources target sources', 'Source audit, lineage, import monitor, export, alert'),
          _OutputRow('Workspace', 'Import Monitor Workspace', '${importJobPlans.length} rows', '$startedImports started loaders, $nextImports next jobs, source review and lineage stages visible', 'QA, source audit, report, export, dashboard'),
          _OutputRow('Compare', 'Team vs Team', '2 slots', _teamCompare(firstTeam, secondTeam), 'Report, workspace result table, export preview, saved comparison'),
          _OutputRow('Compare', 'Season vs Season', '2 slots', _seasonCompare(firstSeason, secondSeason), 'Report, workspace result table, export preview, saved comparison'),
          _OutputRow('Compare', 'Source vs Source', '2 slots', 'Compare connected assets, target sources, connected-empty shells, source-needed rows, and rights-gated layers', 'Source audit report, export preview, alert preview'),
          _OutputRow('Compare', 'Import Job vs Import Job', '2 slots', 'Compare source review, player identity, traditional stats, standings, playoffs, MVP voting, QA, and workflow-readiness jobs', 'Import monitor report, QA readiness, export preview'),
          _OutputRow('Reports', 'Team Brief', '1 entity', _teamReport(firstTeam), 'Identity section populated; stats, standings, roster, games, transactions marked source-pending'),
          _OutputRow('Reports', 'Season Brief', '1 entity', _seasonReport(firstSeason), 'Identity section populated; standings, playoffs, awards, games, draft marked source-pending'),
          _OutputRow('Reports', 'Source Audit Report', '${sourceRegistryEntries.length} rows', '$connectedSources connected, $connectedEmptySources connected-empty, $targetSources target sources, source-needed and gated layers visible', 'Exportable source posture and acquisition blocker report'),
          _OutputRow('Reports', 'Data Coverage Report', '${coverageItems.length} rows', '$connectedCoverage connected coverage rows, $pendingCoverage source-pending coverage rows, no fake data policy preserved', 'Exportable MVP data coverage report'),
          _OutputRow('Saved Views', 'Team Directory Saved View', '${teams.length} rows', 'Filters: conference, division, search, source status. Columns: teamId, city, name, abbreviation, conference, division.', 'Non-persistent preview; persistence later'),
          _OutputRow('Saved Views', 'Season Catalog Saved View', '${seasons.length} rows', 'Filters: league, year range, search, source status. Columns: seasonId, label, startYear, endYear, league.', 'Non-persistent preview; persistence later'),
          _OutputRow('Export', 'Team Directory Export Manifest', '${teams.length} rows', 'Selected columns: teamId, city, name, abbreviation, conference, division, source state. Output: CSV/table preview.', 'Download disabled until file generation exists'),
          _OutputRow('Export', 'Season Catalog Export Manifest', '${seasons.length} rows', 'Selected columns: seasonId, label, startYear, endYear, league, source state. Output: CSV/table preview.', 'Download disabled until file generation exists'),
          _OutputRow('Export', 'Operations Export Manifest', '${sourceRegistryEntries.length + importJobPlans.length + coverageItems.length} rows', 'Source registry, import jobs, coverage, QA, product backlog, and MVP completion payloads.', 'Governed operations packet preview'),
          _OutputRow('Alerts', 'Team Directory Alert Preview', '${teams.length} watched rows', 'Watch row-count changes, team identity changes, conference/division changes, and source-state changes.', 'Preview only; no background notifications'),
          _OutputRow('Alerts', 'Season Catalog Alert Preview', '${seasons.length} watched rows', 'Watch row-count changes, season label/year/league changes, and source-state changes.', 'Preview only; no background notifications'),
          _OutputRow('Alerts', 'Source Status Alert Preview', '${sourceRegistryEntries.length} watched rows', 'Watch connected, connected-empty, target, candidate, source-needed, and gated status transitions.', 'Preview only; no background notifications'),
          _OutputRow('Dashboard', 'Immediate Release Cards', '8 cards', 'Team rows, season rows, sources, imports, coverage, immediate views, immediate actions, and QA readiness.', 'Pinned preview; persistence later'),
          _OutputRow('Search', 'Route Result Preview', '5 result families', 'Teams, Seasons, Sources, Import Jobs, Data Coverage, and QA rows expose open, workspace, compare, report, export, alert, and audit actions.', 'Route actions visible before full navigation payload handoff'),
          _OutputRow('Action Center', 'Universal Action Payload', '8 actions', 'Open, add to workspace, compare, generate report, save view, export, create alert, and audit source.', 'Shared route contract for connected and future entities'),
        ];

        return TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Concrete Route Output Previews', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 10),
                Text('These rows show the actual first payload outputs the terminal can preview now from connected Teams, connected Seasons, and operational registries. This is the bridge from passive screens into workflow objects.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
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
                  DataColumn(label: Text('Target')),
                  DataColumn(label: Text('Output Preview')),
                  DataColumn(label: Text('Payload Size')),
                  DataColumn(label: Text('Preview Contents')),
                  DataColumn(label: Text('Route State')),
                ],
                rows: [for (final output in outputs) output.toDataRow()],
              ),
            ),
          ]),
        );
      },
    );
  }

  String _teamWorkspace(Team? team) {
    if (team == null) return 'No team rows loaded';
    return 'First selected team payload: ${team.city} ${team.name} (${team.abbreviation}), ${team.conference}, ${team.division}, source state connected reference';
  }

  String _seasonWorkspace(Season? season) {
    if (season == null) return 'No season rows loaded';
    return 'First selected season payload: ${season.label}, ${season.startYear}-${season.endYear}, ${season.league}, source state connected reference';
  }

  String _teamCompare(Team? a, Team? b) {
    if (a == null || b == null) return 'No team comparison rows loaded';
    return '${a.city} ${a.name} vs ${b.city} ${b.name}; compare city, abbreviation, conference, division, source state, future blockers';
  }

  String _seasonCompare(Season? a, Season? b) {
    if (a == null || b == null) return 'No season comparison rows loaded';
    return '${a.label} vs ${b.label}; compare start year, end year, league, source state, standings/stat/award blockers';
  }

  String _teamReport(Team? team) {
    if (team == null) return 'No team report row loaded';
    return '${team.city} ${team.name} report shell with identity populated and stats/context sections blocked honestly';
  }

  String _seasonReport(Season? season) {
    if (season == null) return 'No season report row loaded';
    return '${season.label} report shell with season identity populated and standings/playoffs/awards sections blocked honestly';
  }
}

class _OutputRow {
  const _OutputRow(this.target, this.output, this.size, this.contents, this.state);
  final String target;
  final String output;
  final String size;
  final String contents;
  final String state;

  DataRow toDataRow() => DataRow(cells: [
    DataCell(SizedBox(width: 140, child: Text(target, style: const TextStyle(fontWeight: FontWeight.w900)))),
    DataCell(SizedBox(width: 280, child: Text(output, style: const TextStyle(fontWeight: FontWeight.w800)))),
    DataCell(SizedBox(width: 160, child: Text(size))),
    DataCell(SizedBox(width: 720, child: Text(contents))),
    DataCell(SizedBox(width: 420, child: Text(state))),
  ]);
}
