import 'package:flutter/material.dart';

import '../data/comparison_builder_stage_items.dart';
import '../data/comparison_output_route_items.dart';
import '../data/comparison_scorecard_items.dart';
import '../data/comparison_template_items.dart';
import '../models/comparison_template.dart';
import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/registry_item.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/active_route_payload_panel.dart';
import '../widgets/terminal_primitives.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_ComparePayload> payloadFuture = _loadPayload();
  String query = '';
  String type = 'All';
  String status = 'All';
  String stageCategory = 'All';
  String selectedTemplateId = comparisonTemplateItems.first.id;
  String selectedEntityA = 'Auto';
  String selectedEntityB = 'Auto';
  String selectedMetricPackage = 'Fundamental';
  String selectedRoute = 'Workspace';
  String selectedScorecard = 'Identity';

  Future<_ComparePayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadPlayerProfiles(),
      repository.loadPlayerSeasonStats(),
      repository.loadTeamSeasonStats(),
      repository.loadTeams(),
      repository.loadSeasons(),
      repository.loadStandings(),
      repository.loadPlayoffSeries(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadRosters(),
      repository.loadTransactions(),
      repository.loadGames(),
    ]);
    return _ComparePayload(
      players: results[0] as List<PlayerProfile>,
      playerStats: results[1] as List<PlayerSeasonStat>,
      teamStats: results[2] as List<TeamSeasonStat>,
      teams: results[3] as List<Team>,
      seasons: results[4] as List<Season>,
      standingsRows: (results[5] as List).length,
      playoffRows: (results[6] as List).length,
      awardRows: (results[7] as List).length,
      draftRows: (results[8] as List).length,
      rosterRows: (results[9] as List).length,
      transactionRows: (results[10] as List).length,
      gameRows: (results[11] as List).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ComparePayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        final payload = snapshot.data ?? const _ComparePayload(players: [], playerStats: [], teamStats: [], teams: [], seasons: [], standingsRows: 0, playoffRows: 0, awardRows: 0, draftRows: 0, rosterRows: 0, transactionRows: 0, gameRows: 0);
        final types = ['All', ...comparisonTemplateItems.map((item) => item.comparisonType).toSet().toList()..sort()];
        final statuses = ['All', ...comparisonTemplateItems.map((item) => item.status).toSet().toList()..sort()];
        final stageCategories = ['All', ...comparisonBuilderStageItems.map((item) => item.category).toSet().toList()..sort()];
        final filtered = comparisonTemplateItems.where((item) {
          final q = query.trim().toLowerCase();
          return (type == 'All' || item.comparisonType == type) &&
              (status == 'All' || item.status == status) &&
              (q.isEmpty || item.name.toLowerCase().contains(q) || item.primaryEntities.toLowerCase().contains(q) || item.requiredDatasets.toLowerCase().contains(q) || item.output.toLowerCase().contains(q) || item.notes.toLowerCase().contains(q));
        }).toList();
        final filteredStages = comparisonBuilderStageItems.where((item) => stageCategory == 'All' || item.category == stageCategory).toList();
        final selectedTemplate = _selectedTemplate(filtered);
        final selectedGate = _ComparisonGate.fromTemplate(selectedTemplate, payload);
        final selectedMetric = _metricPackages.firstWhere((item) => item.name == selectedMetricPackage);
        final selectedOutputRoute = comparisonOutputRouteItems.firstWhere((item) => item.route == selectedRoute);
        final selectedScorecardItem = comparisonScorecardItems.firstWhere((item) => item.block == selectedScorecard);
        final schemaReady = comparisonTemplateItems.where((item) => item.status == 'Schema ready').length;
        final planned = comparisonTemplateItems.where((item) => item.status == 'Planned').length;
        final future = comparisonTemplateItems.where((item) => item.status == 'Future').length;
        final possibleNow = comparisonTemplateItems.where((item) => _ComparisonGate.fromTemplate(item, payload).readyCount > 0).length;
        final p0Stages = comparisonBuilderStageItems.where((item) => item.priority == 'P0').length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Compare', subtitle: 'Asset-aware comparison command center for players, teams, seasons, franchises, games, drafts, transactions, saved views, fantasy workflows, scouting profiles, and development paths.'),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
              _Metric(label: 'Templates', value: '${comparisonTemplateItems.length}', detail: '$schemaReady schema ready'),
              _Metric(label: 'Output Routes', value: '${comparisonOutputRouteItems.length}', detail: selectedRoute),
              _Metric(label: 'Scorecards', value: '${comparisonScorecardItems.length}', detail: selectedScorecard),
              _Metric(label: 'Data-Aware', value: '$possibleNow', detail: '$planned planned / $future future'),
            ]);
          }),
          const SizedBox(height: 22),
          const ActiveRoutePayloadPanel(consumerName: 'Compare', description: 'Compare now reads the active shared RoutePayload as a comparison slot seed. Publish a Team, Season, or Operations object from the route engine and retarget it to Compare to preserve selected rows, source snapshot, blockers, readiness, and output route intent.', compact: true),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search comparison, entity, dataset...'))),
            _FilterDropdown(label: 'Type', value: type, values: types, onChanged: (value) => setState(() => type = value)),
            _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
            _FilterDropdown(label: 'Stage Category', value: stageCategory, values: stageCategories, onChanged: (value) => setState(() => stageCategory = value)),
            _FilterDropdown(label: 'Metric Package', value: selectedMetricPackage, values: _metricPackages.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedMetricPackage = value)),
            _FilterDropdown(label: 'Output Route', value: selectedRoute, values: comparisonOutputRouteItems.map((item) => item.route).toList(), onChanged: (value) => setState(() => selectedRoute = value)),
            _FilterDropdown(label: 'Scorecard', value: selectedScorecard, values: comparisonScorecardItems.map((item) => item.block).toList(), onChanged: (value) => setState(() => selectedScorecard = value)),
            _FilterDropdown(label: 'Template', value: selectedTemplateId, values: comparisonTemplateItems.map((item) => item.id).toList(), display: (value) => comparisonTemplateItems.firstWhere((item) => item.id == value).name, onChanged: (value) => setState(() { selectedTemplateId = value; selectedEntityA = 'Auto'; selectedEntityB = 'Auto'; })),
          ])),
          const SizedBox(height: 22),
          _MvpCompareReadiness(payload: payload),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final selectedCard = _SelectedComparisonCard(template: selectedTemplate, gate: selectedGate, metricPackage: selectedMetric, route: selectedOutputRoute, scorecard: selectedScorecardItem);
            final entityPicker = _ComparisonEntityPicker(template: selectedTemplate, payload: payload, selectedEntityA: selectedEntityA, selectedEntityB: selectedEntityB, onA: (value) => setState(() => selectedEntityA = value), onB: (value) => setState(() => selectedEntityB = value));
            if (constraints.maxWidth < 1050) return Column(children: [selectedCard, const SizedBox(height: 14), entityPicker]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: selectedCard), const SizedBox(width: 14), Expanded(child: entityPicker)]);
          }),
          const SizedBox(height: 22),
          const _ComparePipelinePanel(),
          const SizedBox(height: 22),
          const _MetricPackageMatrix(),
          const SizedBox(height: 22),
          const _ComparisonOutputRouteMatrix(),
          const SizedBox(height: 22),
          const _ComparisonScorecardMatrix(),
          const SizedBox(height: 22),
          _ComparisonInputMatrix(payload: payload),
          const SizedBox(height: 22),
          _ComparisonTemplatesTable(filtered: filtered, gates: {for (final item in comparisonTemplateItems) item.id: _ComparisonGate.fromTemplate(item, payload)}, selectedTemplateId: selectedTemplate.id, onSelected: (template) => setState(() => selectedTemplateId = template.id)),
          const SizedBox(height: 22),
          _ComparisonBuilderStageTable(items: filteredStages),
        ]);
      },
    );
  }

  ComparisonTemplate _selectedTemplate(List<ComparisonTemplate> filtered) {
    for (final item in comparisonTemplateItems) {
      if (item.id == selectedTemplateId) return item;
    }
    if (filtered.isNotEmpty) return filtered.first;
    return comparisonTemplateItems.first;
  }
}

class _MetricPackage {
  const _MetricPackage(this.name, this.status, this.fields, this.use);
  final String name;
  final String status;
  final String fields;
  final String use;
}

const _metricPackages = <_MetricPackage>[
  _MetricPackage('Fundamental', 'First', 'GP, MPG, PTS, REB, AST, STL, BLK, TOV, PF, shooting splits', 'Basic player/team comparison and report tables.'),
  _MetricPackage('Efficiency', 'Planned', 'TS%, eFG%, FTr, 3PAr, AST/TOV, points per possession later', 'Efficiency boards, award cases, team profile comparisons.'),
  _MetricPackage('Advanced', 'Planned', 'USG%, ORtg, DRtg, Net, BPM, VORP, win shares, PER, LEBRON/EPM/DARKO later if licensed', 'High-level analytical comparisons with source flags.'),
  _MetricPackage('Context', 'Planned', 'Team record, seed, pace, playoff result, roster window, award rank, draft slot', 'Adds environment to player/team comparisons.'),
  _MetricPackage('Fantasy', 'Future', 'Scoring value, games remaining, schedule density, role, matchup, category fit', 'Fantasy roster, waiver, trade, and matchup workflows.'),
  _MetricPackage('Source Audit', 'Planned', 'Source type, as-of, lineage, missing fields, rights posture, validation status', 'Trust and governance comparisons.'),
];

class _ComparePayload {
  const _ComparePayload({required this.players, required this.playerStats, required this.teamStats, required this.teams, required this.seasons, required this.standingsRows, required this.playoffRows, required this.awardRows, required this.draftRows, required this.rosterRows, required this.transactionRows, required this.gameRows});
  final List<PlayerProfile> players;
  final List<PlayerSeasonStat> playerStats;
  final List<TeamSeasonStat> teamStats;
  final List<Team> teams;
  final List<Season> seasons;
  final int standingsRows;
  final int playoffRows;
  final int awardRows;
  final int draftRows;
  final int rosterRows;
  final int transactionRows;
  final int gameRows;
}

class _ComparisonGate {
  const _ComparisonGate({required this.required, required this.readyCount, required this.blockers});
  factory _ComparisonGate.fromTemplate(ComparisonTemplate template, _ComparePayload payload) {
    final required = _requiredInputs(template);
    final blockers = <String>[];
    var ready = 0;
    for (final input in required) {
      final count = _countForInput(input, payload);
      if (count > 0) {
        ready += 1;
      } else {
        blockers.add(input);
      }
    }
    return _ComparisonGate(required: required, readyCount: ready, blockers: blockers);
  }
  final List<String> required;
  final int readyCount;
  final List<String> blockers;
  int get total => required.length;
  String get status => total == 0 ? 'Not mapped' : readyCount == total ? 'Ready' : readyCount == 0 ? 'Source pending' : 'Partial';
  static List<String> _requiredInputs(ComparisonTemplate template) {
    final raw = template.requiredDatasets.toLowerCase();
    final inputs = <String>[];
    if (raw.contains('player profile')) inputs.add('Player profiles');
    if (raw.contains('player season stats')) inputs.add('Player season stats');
    if (raw.contains('team season stats')) inputs.add('Team season stats');
    if (raw.contains('teams')) inputs.add('Teams');
    if (raw.contains('seasons')) inputs.add('Seasons');
    if (raw.contains('standings')) inputs.add('Standings');
    if (raw.contains('playoffs')) inputs.add('Playoffs');
    if (raw.contains('awards')) inputs.add('Awards');
    if (raw.contains('draft')) inputs.add('Draft picks');
    if (raw.contains('rosters')) inputs.add('Rosters');
    if (raw.contains('transactions')) inputs.add('Transactions');
    if (raw.contains('games')) inputs.add('Games');
    if (raw.contains('saved views')) inputs.add('Saved views');
    return inputs;
  }
  static int _countForInput(String input, _ComparePayload payload) {
    switch (input) {
      case 'Player profiles': return payload.players.length;
      case 'Player season stats': return payload.playerStats.length;
      case 'Team season stats': return payload.teamStats.length;
      case 'Teams': return payload.teams.length;
      case 'Seasons': return payload.seasons.length;
      case 'Standings': return payload.standingsRows;
      case 'Playoffs': return payload.playoffRows;
      case 'Awards': return payload.awardRows;
      case 'Draft picks': return payload.draftRows;
      case 'Rosters': return payload.rosterRows;
      case 'Transactions': return payload.transactionRows;
      case 'Games': return payload.gameRows;
      case 'Saved views': return 1;
      default: return 0;
    }
  }
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged, this.display});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final String Function(String value)? display;

  @override
  Widget build(BuildContext context) => SizedBox(width: label == 'Template' ? 320 : 230, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(display == null ? item : display!(item), overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _MvpCompareReadiness extends StatelessWidget {
  const _MvpCompareReadiness({required this.payload});
  final _ComparePayload payload;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('NBA MVP Compare Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    const Text('Compare becomes useful after the first real loop is complete: player identity, traditional player stats, team season stats, teams, seasons, source metadata, and controlled null handling. Until then, comparison workflows remain honest and source-pending.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 18),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${payload.players.length} players'), InfoPill(label: '${payload.playerStats.length} player stats'), InfoPill(label: '${payload.teamStats.length} team stats'), InfoPill(label: '${payload.teams.length} teams'), InfoPill(label: '${payload.seasons.length} seasons'), InfoPill(label: '${payload.standingsRows} standings')]),
  ]));
}

class _SelectedComparisonCard extends StatelessWidget {
  const _SelectedComparisonCard({required this.template, required this.gate, required this.metricPackage, required this.route, required this.scorecard});
  final ComparisonTemplate template;
  final _ComparisonGate gate;
  final _MetricPackage metricPackage;
  final ComparisonOutputRouteItem route;
  final ComparisonScorecardItem scorecard;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))), const SizedBox(width: 10), InfoPill(label: gate.status)]),
    const SizedBox(height: 8),
    Text(template.output, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 16),
    _DetailLine(label: 'Type', value: template.comparisonType),
    _DetailLine(label: 'Template Status', value: template.status),
    _DetailLine(label: 'Metric Package', value: '${metricPackage.name}: ${metricPackage.fields}'),
    _DetailLine(label: 'Output Route', value: '${route.route} → ${route.target}. ${route.use}'),
    _DetailLine(label: 'Scorecard', value: '${scorecard.block}: ${scorecard.fields}'),
    _DetailLine(label: 'Primary Entities', value: template.primaryEntities),
    _DetailLine(label: 'Required Data', value: template.requiredDatasets),
    _DetailLine(label: 'Gate', value: '${gate.readyCount}/${gate.total} required inputs currently populated'),
    _DetailLine(label: 'Blockers', value: gate.blockers.isEmpty ? 'No blockers from currently mapped inputs.' : gate.blockers.join(', ')),
  ]));
}

class _ComparisonEntityPicker extends StatelessWidget {
  const _ComparisonEntityPicker({required this.template, required this.payload, required this.selectedEntityA, required this.selectedEntityB, required this.onA, required this.onB});
  final ComparisonTemplate template;
  final _ComparePayload payload;
  final String selectedEntityA;
  final String selectedEntityB;
  final ValueChanged<String> onA;
  final ValueChanged<String> onB;

  @override
  Widget build(BuildContext context) {
    final options = _options();
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Comparison Entity Slots', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('These selectors are local and asset-aware. The active RoutePayload above is now the shared seed for future slot binding.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      const SizedBox(height: 16),
      _FilterDropdown(label: 'Entity A', value: selectedEntityA, values: options, onChanged: onA),
      const SizedBox(height: 12),
      _FilterDropdown(label: 'Entity B', value: selectedEntityB, values: options, onChanged: onB),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [InfoPill(label: '${payload.players.length} player options'), InfoPill(label: '${payload.teams.length} team options'), InfoPill(label: '${payload.seasons.length} season options')]),
    ]));
  }

  List<String> _options() {
    final options = <String>['Auto'];
    if (template.comparisonType == 'Player' || template.comparisonType == 'Awards' || template.comparisonType == 'Fantasy' || template.comparisonType == 'Scouting') {
      options.addAll(payload.players.take(60).map((item) => item.displayName));
      if (payload.players.isEmpty) options.add('Player profiles source pending');
    } else if (template.comparisonType == 'Team' || template.comparisonType == 'Franchise') {
      options.addAll(payload.teams.map((item) => '${item.city} ${item.name}'));
    } else if (template.comparisonType == 'Season') {
      options.addAll(payload.seasons.take(60).map((item) => item.label));
    } else {
      options.addAll(['Source-pending entity set', 'Use template requirements']);
    }
    return options;
  }
}

class _ComparePipelinePanel extends StatelessWidget {
  const _ComparePipelinePanel();
  @override
  Widget build(BuildContext context) {
    final steps = ['Select template', 'Bind active payload', 'Choose metric package', 'Check data gate', 'Select scorecard', 'Choose output route', 'Apply source snapshot', 'Save/export/report'];
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Compare Builder Pipeline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')])]));
  }
}

class _MetricPackageMatrix extends StatelessWidget { const _MetricPackageMatrix(); @override Widget build(BuildContext context) => _SimpleMatrix(title: 'Metric Package Matrix', columns: const ['Package', 'Status', 'Fields', 'Use'], rows: [for (final item in _metricPackages) [item.name, item.status, item.fields, item.use]]); }
class _ComparisonOutputRouteMatrix extends StatelessWidget { const _ComparisonOutputRouteMatrix(); @override Widget build(BuildContext context) => _SimpleMatrix(title: 'Comparison Output Route Matrix', columns: const ['Route', 'Status', 'Target', 'Use'], rows: [for (final item in comparisonOutputRouteItems) [item.route, item.status, item.target, item.use]]); }
class _ComparisonScorecardMatrix extends StatelessWidget { const _ComparisonScorecardMatrix(); @override Widget build(BuildContext context) => _SimpleMatrix(title: 'Comparison Scorecard Matrix', columns: const ['Block', 'Status', 'Fields', 'Purpose'], rows: [for (final item in comparisonScorecardItems) [item.block, item.status, item.fields, item.purpose]]); }

class _ComparisonInputMatrix extends StatelessWidget {
  const _ComparisonInputMatrix({required this.payload});
  final _ComparePayload payload;
  @override
  Widget build(BuildContext context) => _SimpleMatrix(title: 'Comparison Input Matrix', columns: const ['Input Layer', 'Rows', 'Status', 'Comparison Use'], rows: [
    ['Player profiles', '${payload.players.length}', payload.players.isEmpty ? 'Source pending' : 'Connected', 'Player names, identity, profile detail, player compare slots'],
    ['Player season stats', '${payload.playerStats.length}', payload.playerStats.isEmpty ? 'Source pending' : 'Connected', 'Player-season side-by-side production comparisons'],
    ['Team season stats', '${payload.teamStats.length}', payload.teamStats.isEmpty ? 'Source pending' : 'Connected', 'Team-season record, scoring, efficiency comparisons'],
    ['Teams', '${payload.teams.length}', payload.teams.isEmpty ? 'Source pending' : 'Connected', 'Reference team comparison and joins'],
    ['Seasons', '${payload.seasons.length}', payload.seasons.isEmpty ? 'Source pending' : 'Connected', 'Season and era comparison slots'],
    ['Standings', '${payload.standingsRows}', payload.standingsRows == 0 ? 'Source pending' : 'Connected', 'Record, seed, and team-context comparison'],
    ['Awards', '${payload.awardRows}', payload.awardRows == 0 ? 'Source pending' : 'Connected', 'Award race and recognition context'],
  ]);
}

class _ComparisonTemplatesTable extends StatelessWidget {
  const _ComparisonTemplatesTable({required this.filtered, required this.gates, required this.selectedTemplateId, required this.onSelected});
  final List<ComparisonTemplate> filtered;
  final Map<String, _ComparisonGate> gates;
  final String selectedTemplateId;
  final ValueChanged<ComparisonTemplate> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Comparison Templates', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} templates', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Template')), DataColumn(label: Text('Type')), DataColumn(label: Text('Status')), DataColumn(label: Text('Data Gate')), DataColumn(label: Text('Primary Entities')), DataColumn(label: Text('Required Data')), DataColumn(label: Text('Output'))], rows: [for (final item in filtered) DataRow(selected: item.id == selectedTemplateId, onSelectChanged: (_) => onSelected(item), cells: [DataCell(SizedBox(width: 280, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.comparisonType)), DataCell(InfoPill(label: item.status)), DataCell(InfoPill(label: gates[item.id]?.status ?? 'Not mapped')), DataCell(SizedBox(width: 300, child: Text(item.primaryEntities))), DataCell(SizedBox(width: 460, child: Text(item.requiredDatasets))), DataCell(SizedBox(width: 620, child: Text(item.output)))])])),
  ]));
}

class _ComparisonBuilderStageTable extends StatelessWidget {
  const _ComparisonBuilderStageTable({required this.items});
  final List<RegistryItem> items;
  @override
  Widget build(BuildContext context) => _SimpleMatrix(title: 'Comparison Builder Stage Model', columns: const ['Priority', 'Stage', 'Category', 'Status', 'Next Step'], rows: [for (final item in items) [item.priority, item.title, item.category, item.status, item.nextStep]]);
}

class _SimpleMatrix extends StatelessWidget {
  const _SimpleMatrix({required this.title, required this.columns, required this.rows});
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${rows.length} rows', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: [for (final column in columns) DataColumn(label: Text(column))], rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 32 ? 520 : 180, child: Text(cell)))])])),
  ]));
}

class _DetailLine extends StatelessWidget { const _DetailLine({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))])); }
class _Metric extends StatelessWidget { const _Metric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
