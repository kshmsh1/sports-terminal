import 'package:flutter/material.dart';

import '../data/coverage_items.dart';
import '../data/import_job_plans.dart';
import '../data/source_registry_entries.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import 'terminal_primitives.dart';

class FirstReleaseRouteEngine extends StatefulWidget {
  const FirstReleaseRouteEngine({super.key, this.compact = false});

  final bool compact;

  @override
  State<FirstReleaseRouteEngine> createState() => _FirstReleaseRouteEngineState();
}

class _FirstReleaseRouteEngineState extends State<FirstReleaseRouteEngine> {
  final _repository = const NbaAssetRepository();
  late final Future<_RouteEnginePayload> _future = _load();
  String _source = 'Teams';
  String _route = 'Workspace';
  int _teamIndex = 0;
  int _seasonIndex = 0;
  int _operationsIndex = 0;

  Future<_RouteEnginePayload> _load() async {
    final results = await Future.wait<Object>([_repository.loadTeams(), _repository.loadSeasons()]);
    return _RouteEnginePayload(teams: results[0] as List<Team>, seasons: results[1] as List<Season>);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RouteEnginePayload>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading interactive route engine...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return TerminalCard(child: Text('Unable to load route engine: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }
        final payload = snapshot.data!;
        final selection = _selection(payload);
        final outputs = _outputsFor(selection);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Interactive First-Release Route Engine', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
              InfoPill(label: selection.state),
            ]),
            const SizedBox(height: 10),
            const Text('Select a live Team row, live Season row, or operations payload, then choose the route. The panel below generates the first working object that should flow into Workspace Studio, Compare, Reports, Saved Views, Export Center, Alerts, Dashboard, Search, Action Center, and Source Audit.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final source in _sources)
                ChoiceChip(
                  label: Text(source),
                  selected: _source == source,
                  onSelected: (_) => setState(() => _source = source),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final route in _routes)
                ChoiceChip(
                  label: Text(route),
                  selected: _route == route,
                  onSelected: (_) => setState(() => _route = route),
                ),
            ]),
          ])),
          const SizedBox(height: 18),
          if (!widget.compact) _SelectionTable(source: _source, payload: payload, selectedTeamIndex: _teamIndex, selectedSeasonIndex: _seasonIndex, selectedOperationsIndex: _operationsIndex, onTeam: (index) => setState(() => _teamIndex = index), onSeason: (index) => setState(() => _seasonIndex = index), onOperations: (index) => setState(() => _operationsIndex = index)),
          if (!widget.compact) const SizedBox(height: 18),
          _RouteOutputCard(selection: selection, route: _route, outputs: outputs),
          const SizedBox(height: 18),
          _RouteStateTable(selection: selection, outputs: outputs),
        ]);
      },
    );
  }

  _RouteSelection _selection(_RouteEnginePayload payload) {
    if (_source == 'Teams') {
      final safeIndex = payload.teams.isEmpty ? 0 : _teamIndex.clamp(0, payload.teams.length - 1);
      final team = payload.teams.isEmpty ? null : payload.teams[safeIndex];
      return _RouteSelection(source: 'Team Directory', objectId: team?.id ?? 'team-source-pending', label: team == null ? 'No team loaded' : '${team.city} ${team.name}', detail: team == null ? 'Team directory unavailable' : '${team.abbreviation} · ${team.conference} · ${team.division}', rowCount: payload.teams.length, state: 'Connected reference', fields: team == null ? const [] : ['teamId=${team.id}', 'city=${team.city}', 'name=${team.name}', 'abbr=${team.abbreviation}', 'conference=${team.conference}', 'division=${team.division}'], blockers: 'Stats, standings, rosters, games, transactions, franchise history still source-pending.');
    }
    if (_source == 'Seasons') {
      final safeIndex = payload.seasons.isEmpty ? 0 : _seasonIndex.clamp(0, payload.seasons.length - 1);
      final season = payload.seasons.isEmpty ? null : payload.seasons[safeIndex];
      return _RouteSelection(source: 'Season Catalog', objectId: season?.id ?? 'season-source-pending', label: season == null ? 'No season loaded' : season.label, detail: season == null ? 'Season catalog unavailable' : '${season.startYear}-${season.endYear} · ${season.league}', rowCount: payload.seasons.length, state: 'Connected reference', fields: season == null ? const [] : ['seasonId=${season.id}', 'label=${season.label}', 'startYear=${season.startYear}', 'endYear=${season.endYear}', 'league=${season.league}'], blockers: 'Standings, playoffs, awards, games, draft, league averages, and era context still source-pending.');
    }
    final operations = _operationsRows[_operationsIndex.clamp(0, _operationsRows.length - 1)];
    return _RouteSelection(source: 'Operations', objectId: operations.id, label: operations.title, detail: operations.detail, rowCount: operations.rows, state: operations.state, fields: operations.fields, blockers: operations.blockers);
  }

  List<_RouteOutput> _outputsFor(_RouteSelection selection) => [
    _RouteOutput('Workspace', '${selection.source} Workspace', '${selection.rowCount} rows available', 'Columns: ${selection.fields.join(', ')}', 'Table payload with selectedRowKeys, filters, source snapshot, route actions, and blocker labels.'),
    _RouteOutput('Compare', '${selection.source} Compare', selection.source == 'Teams' || selection.source == 'Seasons' ? 'Two-slot comparison ready' : 'Operational comparison ready', 'Compare identity fields, source state, row counts, priorities, and blockers.', 'Output table can route into Workspace, Reports, Export, Saved Views, and Alerts.'),
    _RouteOutput('Reports', '${selection.source} Report Shell', 'Previewable now', 'Populated identity/operations section plus blocked sports-data sections.', 'Report shell keeps missing data visible instead of inventing values.'),
    _RouteOutput('Saved View', '${selection.source} Saved View Preview', 'Non-persistent', 'Filters, selected columns, selected row, source snapshot, and route actions.', 'Preview only until local persistence is implemented.'),
    _RouteOutput('Export', '${selection.source} Export Manifest', 'Preview manifest', 'Row count, selected columns, filters, source notes, missing-data flags, and output format.', 'Download disabled until file generation exists.'),
    _RouteOutput('Alerts', '${selection.source} Alert Preview', 'Monitorable rule preview', 'Watch row-count changes, source-state changes, selected field changes, and import movement.', 'Preview only; no background notifications yet.'),
    _RouteOutput('Dashboard', '${selection.source} Dashboard Card', 'Pin preview', 'Payload count, selected object, status, blockers, and next action.', 'Pinning persistence comes later.'),
    _RouteOutput('Search', '${selection.source} Search Result Route', 'Command result', 'Open, workspace, compare, report, save view, export, alert, audit source.', 'Search route handoff comes after shared payload model is global.'),
    _RouteOutput('Action Center', '${selection.source} Universal Action', 'Route contract active', 'Selected object + action + target + readiness + source snapshot.', 'Central action payload shared across immediate and future entities.'),
  ];
}

class _RouteOutputCard extends StatelessWidget {
  const _RouteOutputCard({required this.selection, required this.route, required this.outputs});
  final _RouteSelection selection;
  final String route;
  final List<_RouteOutput> outputs;

  @override
  Widget build(BuildContext context) {
    final output = outputs.firstWhere((item) => item.target == route, orElse: () => outputs.first);
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text('${output.title}: ${selection.label}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        InfoPill(label: selection.state),
      ]),
      const SizedBox(height: 10),
      Text(selection.detail, style: const TextStyle(color: terminalTextSoft, height: 1.35)),
      const SizedBox(height: 14),
      _DetailLine(label: 'Selected ID', value: selection.objectId),
      _DetailLine(label: 'Source', value: selection.source),
      _DetailLine(label: 'Route', value: route),
      _DetailLine(label: 'Payload Size', value: output.size),
      _DetailLine(label: 'Preview Fields', value: output.fields),
      _DetailLine(label: 'Route Output', value: output.routeState),
      _DetailLine(label: 'Current Blockers', value: selection.blockers),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final field in selection.fields) InfoPill(label: field)]),
    ]));
  }
}

class _RouteStateTable extends StatelessWidget {
  const _RouteStateTable({required this.selection, required this.outputs});
  final _RouteSelection selection;
  final List<_RouteOutput> outputs;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Generated Route Outputs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Target')), DataColumn(label: Text('Output Object')), DataColumn(label: Text('Payload')), DataColumn(label: Text('Fields')), DataColumn(label: Text('State'))],
      rows: [for (final output in outputs) DataRow(cells: [
        DataCell(SizedBox(width: 150, child: Text(output.target, style: const TextStyle(fontWeight: FontWeight.w900)))),
        DataCell(SizedBox(width: 300, child: Text(output.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
        DataCell(SizedBox(width: 180, child: Text(output.size))),
        DataCell(SizedBox(width: 560, child: Text(output.fields))),
        DataCell(SizedBox(width: 560, child: Text(output.routeState))),
      ])],
    )),
  ]));
}

class _SelectionTable extends StatelessWidget {
  const _SelectionTable({required this.source, required this.payload, required this.selectedTeamIndex, required this.selectedSeasonIndex, required this.selectedOperationsIndex, required this.onTeam, required this.onSeason, required this.onOperations});
  final String source;
  final _RouteEnginePayload payload;
  final int selectedTeamIndex;
  final int selectedSeasonIndex;
  final int selectedOperationsIndex;
  final ValueChanged<int> onTeam;
  final ValueChanged<int> onSeason;
  final ValueChanged<int> onOperations;

  @override
  Widget build(BuildContext context) {
    if (source == 'Teams') return _teamTable();
    if (source == 'Seasons') return _seasonTable();
    return _operationsTable();
  }

  Widget _teamTable() => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Expanded(child: Text('Selectable Team Payload Rows', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), InfoPill(label: '${payload.teams.length} rows')])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columns: const [DataColumn(label: Text('teamId')), DataColumn(label: Text('Team')), DataColumn(label: Text('Conference')), DataColumn(label: Text('Division')), DataColumn(label: Text('Source')), DataColumn(label: Text('Routes'))],
      rows: [for (var i = 0; i < payload.teams.take(12).length; i++) DataRow(selected: i == selectedTeamIndex, onSelectChanged: (_) => onTeam(i), cells: [
        DataCell(Text(payload.teams[i].id, style: const TextStyle(fontWeight: FontWeight.w800))),
        DataCell(SizedBox(width: 230, child: Text('${payload.teams[i].city} ${payload.teams[i].name} (${payload.teams[i].abbreviation})'))),
        DataCell(Text(payload.teams[i].conference)),
        DataCell(SizedBox(width: 180, child: Text(payload.teams[i].division))),
        const DataCell(InfoPill(label: 'Connected')),
        const DataCell(_RoutePillSet()),
      ])],
    )),
  ]));

  Widget _seasonTable() => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Expanded(child: Text('Selectable Season Payload Rows', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), InfoPill(label: '${payload.seasons.length} rows')])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columns: const [DataColumn(label: Text('seasonId')), DataColumn(label: Text('Label')), DataColumn(label: Text('Years')), DataColumn(label: Text('League')), DataColumn(label: Text('Source')), DataColumn(label: Text('Routes'))],
      rows: [for (var i = 0; i < payload.seasons.take(12).length; i++) DataRow(selected: i == selectedSeasonIndex, onSelectChanged: (_) => onSeason(i), cells: [
        DataCell(Text(payload.seasons[i].id, style: const TextStyle(fontWeight: FontWeight.w800))),
        DataCell(SizedBox(width: 140, child: Text(payload.seasons[i].label))),
        DataCell(Text('${payload.seasons[i].startYear}-${payload.seasons[i].endYear}')),
        DataCell(Text(payload.seasons[i].league)),
        const DataCell(InfoPill(label: 'Connected')),
        const DataCell(_RoutePillSet()),
      ])],
    )),
  ]));

  Widget _operationsTable() => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Selectable Operations Payload Rows', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columns: const [DataColumn(label: Text('Payload')), DataColumn(label: Text('Rows')), DataColumn(label: Text('State')), DataColumn(label: Text('Fields')), DataColumn(label: Text('Routes'))],
      rows: [for (var i = 0; i < _operationsRows.length; i++) DataRow(selected: i == selectedOperationsIndex, onSelectChanged: (_) => onOperations(i), cells: [
        DataCell(SizedBox(width: 230, child: Text(_operationsRows[i].title, style: const TextStyle(fontWeight: FontWeight.w800)))),
        DataCell(Text('${_operationsRows[i].rows}')),
        DataCell(InfoPill(label: _operationsRows[i].state)),
        DataCell(SizedBox(width: 520, child: Text(_operationsRows[i].fields.join(', ')))),
        const DataCell(_RoutePillSet()),
      ])],
    )),
  ]));
}

class _RoutePillSet extends StatelessWidget {
  const _RoutePillSet();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 570, child: Wrap(spacing: 8, runSpacing: 8, children: [
    InfoPill(label: 'Workspace'),
    InfoPill(label: 'Compare'),
    InfoPill(label: 'Report'),
    InfoPill(label: 'Saved View'),
    InfoPill(label: 'Export'),
    InfoPill(label: 'Alert'),
    InfoPill(label: 'Dashboard'),
    InfoPill(label: 'Audit'),
  ]));
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 130, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))),
    Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3))),
  ]));
}

class _RouteEnginePayload {
  const _RouteEnginePayload({required this.teams, required this.seasons});
  final List<Team> teams;
  final List<Season> seasons;
}

class _RouteSelection {
  const _RouteSelection({required this.source, required this.objectId, required this.label, required this.detail, required this.rowCount, required this.state, required this.fields, required this.blockers});
  final String source;
  final String objectId;
  final String label;
  final String detail;
  final int rowCount;
  final String state;
  final List<String> fields;
  final String blockers;
}

class _RouteOutput {
  const _RouteOutput(this.target, this.title, this.size, this.fields, this.routeState);
  final String target;
  final String title;
  final String size;
  final String fields;
  final String routeState;
}

class _OperationsPayload {
  const _OperationsPayload(this.id, this.title, this.rows, this.state, this.detail, this.fields, this.blockers);
  final String id;
  final String title;
  final int rows;
  final String state;
  final String detail;
  final List<String> fields;
  final String blockers;
}

final _operationsRows = <_OperationsPayload>[
  _OperationsPayload('source-registry', 'Source Registry', sourceRegistryEntries.length, 'Connected operations', 'Acquisition control board for source posture, rights posture, source types, refresh cadence, targets, candidates, and gated layers.', const ['sourceId', 'domain', 'sourceType', 'status', 'rightsPosture', 'refreshCadence'], 'Needs source decisions for player identity, traditional stats, standings, playoffs, awards, games, and transactions.'),
  _OperationsPayload('import-jobs', 'Import Jobs', importJobPlans.length, 'Connected operations', 'Two-track plan for immediate workflow activation and first source-backed NBA data import wave.', const ['jobId', 'domain', 'status', 'input', 'output', 'validation'], 'Needs real import scripts, raw snapshots, lineage manifests, and validation runs.'),
  _OperationsPayload('data-coverage', 'Data Coverage', coverageItems.length, 'Connected operations', 'Coverage board for connected, connected-empty, source-pending, next, planned, source-needed, and future datasets.', const ['dataset', 'domain', 'recordCount', 'status', 'priority', 'nextStep'], 'Needs source-backed rows for players, stats, standings, playoffs, awards, games, rosters, draft, and transactions.'),
  const _OperationsPayload('qa-readiness', 'QA Readiness', 1, 'Release gate ready', 'Release gate for Chrome launch, source-pending behavior, row counts, joins, route payloads, and export/report integrity.', ['checkId', 'area', 'priority', 'status', 'risk', 'nextAction'], 'Needs analyzer/smoke-test automation and route handoff tests.'),
  const _OperationsPayload('product-backlog', 'Product Backlog', 1, 'Execution lanes active', 'Backlog board for Immediate, Stats Release, Context, Gated, and Future lanes.', ['module', 'stage', 'priority', 'status', 'releaseLane', 'acceptanceCriteria'], 'Needs continued status updates as actual route payloads become working features.'),
  const _OperationsPayload('nba-mvp-completion', 'NBA MVP Completion', 1, 'Ship tracker active', 'Endgame tracker for shipped foundations, immediate workflow release, first stats release, and local MVP exit criteria.', ['category', 'priority', 'status', 'description', 'nextStep'], 'Needs first source-backed player identity and traditional stat imports after route payloads are stable.'),
];

const _sources = ['Teams', 'Seasons', 'Operations'];
const _routes = ['Workspace', 'Compare', 'Reports', 'Saved View', 'Export', 'Alerts', 'Dashboard', 'Search', 'Action Center'];
