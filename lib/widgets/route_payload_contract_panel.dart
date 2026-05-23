import 'package:flutter/material.dart';

import '../data/coverage_items.dart';
import '../data/import_job_plans.dart';
import '../data/source_registry_entries.dart';
import '../models/route_payload.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import 'terminal_primitives.dart';

class RoutePayloadContractPanel extends StatelessWidget {
  const RoutePayloadContractPanel({super.key});

  @override
  Widget build(BuildContext context) {
    const repository = NbaAssetRepository();
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([repository.loadTeams(), repository.loadSeasons()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading route payload contracts...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return TerminalCard(child: Text('Unable to load route payload contracts: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }
        final teams = snapshot.data![0] as List<Team>;
        final seasons = snapshot.data![1] as List<Season>;
        final payloads = <RoutePayload>[
          if (teams.isNotEmpty) ..._teamPayloads(teams.first, teams.length),
          if (seasons.isNotEmpty) ..._seasonPayloads(seasons.first, seasons.length),
          ..._operationsPayloads(),
        ];

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Shared Route Payload Contract', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('These are concrete RoutePayload objects generated from connected Teams, connected Seasons, and operations registries. This is the contract that should move across Workspace Studio, Compare, Reports, Saved Views, Export Center, Alerts, Dashboard, Search, Action Center, and Source Audit.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              InfoPill(label: '${payloads.length} payload objects'),
              InfoPill(label: '${teams.length} team rows'),
              InfoPill(label: '${seasons.length} season rows'),
              InfoPill(label: '${sourceRegistryEntries.length} source rows'),
              InfoPill(label: '${importJobPlans.length} import jobs'),
              InfoPill(label: '${coverageItems.length} coverage rows'),
            ]),
          ])),
          const SizedBox(height: 18),
          _PayloadTable(payloads: payloads),
          const SizedBox(height: 18),
          const _TargetTable(),
        ]);
      },
    );
  }

  List<RoutePayload> _teamPayloads(Team team, int rowCount) => [
        RoutePayload(
          sourceObjectType: 'Team',
          sourceObjectId: team.id,
          displayLabel: '${team.city} ${team.name}',
          selectedColumns: const ['teamId', 'city', 'name', 'abbreviation', 'conference', 'division', 'sourceState'],
          selectedRows: [team.id],
          filterSummary: 'rowCount=$rowCount; source=teams.json; selectedRow=${team.id}',
          sourceSnapshot: 'Connected local reference asset: teams.json',
          readinessState: 'Connected reference',
          blockers: const ['team stats pending', 'standings pending', 'rosters pending', 'games pending', 'transactions pending'],
          targetRoute: 'Workspace',
          availableActions: immediateRouteTargets,
        ),
        RoutePayload(
          sourceObjectType: 'Team',
          sourceObjectId: team.id,
          displayLabel: '${team.city} ${team.name}',
          selectedColumns: const ['teamId', 'city', 'name', 'abbreviation', 'conference', 'division', 'sourceState'],
          selectedRows: [team.id],
          filterSummary: 'compareSlot=A; compareMode=Team vs Team',
          sourceSnapshot: 'Connected local reference asset: teams.json',
          readinessState: 'Compare ready for identity fields',
          blockers: const ['team-season stat comparison pending', 'roster comparison pending', 'game comparison pending'],
          targetRoute: 'Compare',
          availableActions: immediateRouteTargets,
        ),
      ];

  List<RoutePayload> _seasonPayloads(Season season, int rowCount) => [
        RoutePayload(
          sourceObjectType: 'Season',
          sourceObjectId: season.id,
          displayLabel: season.label,
          selectedColumns: const ['seasonId', 'label', 'startYear', 'endYear', 'league', 'sourceState'],
          selectedRows: [season.id],
          filterSummary: 'rowCount=$rowCount; source=seasons.json; selectedRow=${season.id}',
          sourceSnapshot: 'Connected local reference asset: seasons.json',
          readinessState: 'Connected reference',
          blockers: const ['standings pending', 'playoffs pending', 'awards pending', 'games pending', 'league averages pending'],
          targetRoute: 'Workspace',
          availableActions: immediateRouteTargets,
        ),
        RoutePayload(
          sourceObjectType: 'Season',
          sourceObjectId: season.id,
          displayLabel: season.label,
          selectedColumns: const ['seasonId', 'label', 'startYear', 'endYear', 'league', 'sourceState'],
          selectedRows: [season.id],
          filterSummary: 'compareSlot=A; compareMode=Season vs Season',
          sourceSnapshot: 'Connected local reference asset: seasons.json',
          readinessState: 'Compare ready for identity fields',
          blockers: const ['standings comparison pending', 'playoff comparison pending', 'award comparison pending'],
          targetRoute: 'Compare',
          availableActions: immediateRouteTargets,
        ),
      ];

  List<RoutePayload> _operationsPayloads() => [
        RoutePayload(
          sourceObjectType: 'Operations',
          sourceObjectId: 'source-registry',
          displayLabel: 'Source Registry',
          selectedColumns: const ['sourceId', 'domain', 'sourceType', 'status', 'rightsPosture', 'refreshCadence'],
          selectedRows: const ['source-registry'],
          filterSummary: 'rows=${sourceRegistryEntries.length}; connected/target/source-needed/gated states visible',
          sourceSnapshot: 'Connected operations registry',
          readinessState: 'Source audit ready',
          blockers: const ['field-level lineage pending', 'source decisions pending', 'rights review pending'],
          targetRoute: 'Source Audit',
          availableActions: immediateRouteTargets,
        ),
        RoutePayload(
          sourceObjectType: 'Operations',
          sourceObjectId: 'import-jobs',
          displayLabel: 'Import Jobs',
          selectedColumns: const ['jobId', 'domain', 'status', 'input', 'output', 'validation'],
          selectedRows: const ['import-jobs'],
          filterSummary: 'rows=${importJobPlans.length}; immediate workflow and source-backed data waves visible',
          sourceSnapshot: 'Connected operations registry',
          readinessState: 'Import monitor ready',
          blockers: const ['runtime scripts pending', 'raw snapshots pending', 'validation output pending'],
          targetRoute: 'Reports',
          availableActions: immediateRouteTargets,
        ),
        RoutePayload(
          sourceObjectType: 'Operations',
          sourceObjectId: 'data-coverage',
          displayLabel: 'Data Coverage',
          selectedColumns: const ['dataset', 'domain', 'recordCount', 'status', 'priority', 'nextStep'],
          selectedRows: const ['data-coverage'],
          filterSummary: 'rows=${coverageItems.length}; connected and source-pending data areas visible',
          sourceSnapshot: 'Connected coverage registry',
          readinessState: 'Coverage report ready',
          blockers: const ['player rows pending', 'stats rows pending', 'standings rows pending', 'MVP voting pending'],
          targetRoute: 'Dashboard',
          availableActions: immediateRouteTargets,
        ),
      ];
}

class _PayloadTable extends StatelessWidget {
  const _PayloadTable({required this.payloads});
  final List<RoutePayload> payloads;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Expanded(child: Text('Generated RoutePayload Objects', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), Text('${payloads.length} objects', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          headingRowColor: WidgetStateProperty.all(terminalPanelDark),
          headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
          dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
          columnSpacing: 30,
          columns: const [
            DataColumn(label: Text('Target Route')),
            DataColumn(label: Text('Object Type')),
            DataColumn(label: Text('Object ID')),
            DataColumn(label: Text('Display Label')),
            DataColumn(label: Text('Columns')),
            DataColumn(label: Text('Rows')),
            DataColumn(label: Text('Filter State')),
            DataColumn(label: Text('Readiness')),
            DataColumn(label: Text('Blockers')),
          ],
          rows: [for (final payload in payloads) DataRow(cells: [
            DataCell(InfoPill(label: payload.targetRoute)),
            DataCell(SizedBox(width: 160, child: Text(payload.sourceObjectType, style: const TextStyle(fontWeight: FontWeight.w800)))),
            DataCell(SizedBox(width: 180, child: Text(payload.sourceObjectId))),
            DataCell(SizedBox(width: 260, child: Text(payload.displayLabel, style: const TextStyle(fontWeight: FontWeight.w800)))),
            DataCell(SizedBox(width: 520, child: Text(payload.selectedColumnsLabel))),
            DataCell(SizedBox(width: 180, child: Text(payload.selectedRowsLabel))),
            DataCell(SizedBox(width: 440, child: Text(payload.filterSummary))),
            DataCell(SizedBox(width: 280, child: Text(payload.readinessState))),
            DataCell(SizedBox(width: 520, child: Text(payload.blockersLabel))),
          ])],
        )),
      ]));
}

class _TargetTable extends StatelessWidget {
  const _TargetTable();

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('Immediate Route Targets', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const Divider(height: 1, color: terminalBorder),
        Padding(padding: const EdgeInsets.all(18), child: Wrap(spacing: 10, runSpacing: 10, children: [for (final target in immediateRouteTargets) InfoPill(label: target)])),
      ]));
}
