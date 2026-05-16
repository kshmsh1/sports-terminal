import 'package:flutter/material.dart';

import '../data/comparison_template_items.dart';
import '../models/comparison_template.dart';
import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../services/nba_asset_repository.dart';
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
  String selectedTemplateId = comparisonTemplateItems.first.id;
  String selectedEntityA = 'Auto';
  String selectedEntityB = 'Auto';

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
        final filtered = comparisonTemplateItems.where((item) {
          final q = query.trim().toLowerCase();
          return (type == 'All' || item.comparisonType == type) &&
              (status == 'All' || item.status == status) &&
              (q.isEmpty || item.name.toLowerCase().contains(q) || item.primaryEntities.toLowerCase().contains(q) || item.requiredDatasets.toLowerCase().contains(q) || item.output.toLowerCase().contains(q) || item.notes.toLowerCase().contains(q));
        }).toList();
        final selectedTemplate = _selectedTemplate(filtered);
        final selectedGate = _ComparisonGate.fromTemplate(selectedTemplate, payload);
        final schemaReady = comparisonTemplateItems.where((item) => item.status == 'Schema ready').length;
        final planned = comparisonTemplateItems.where((item) => item.status == 'Planned').length;
        final future = comparisonTemplateItems.where((item) => item.status == 'Future').length;
        final possibleNow = comparisonTemplateItems.where((item) => _ComparisonGate.fromTemplate(item, payload).readyCount > 0).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Compare', subtitle: 'Asset-aware comparison command center for players, teams, seasons, franchises, drafts, transactions, and development paths. This is now pointed toward the working NBA MVP rather than only template planning.'),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
              _Metric(label: 'Templates', value: '${comparisonTemplateItems.length}', detail: 'Comparison workflows'),
              _Metric(label: 'Schema Ready', value: '$schemaReady', detail: 'Join keys defined'),
              _Metric(label: 'Data-Aware', value: '$possibleNow', detail: 'At least one input row'),
              _Metric(label: 'Planned / Future', value: '$planned / $future', detail: 'MVP sequencing'),
            ]);
          }),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search comparison, entity, dataset...'))),
            _FilterDropdown(label: 'Type', value: type, values: types, onChanged: (value) => setState(() => type = value)),
            _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
            _FilterDropdown(label: 'Template', value: selectedTemplateId, values: comparisonTemplateItems.map((item) => item.id).toList(), display: (value) => comparisonTemplateItems.firstWhere((item) => item.id == value).name, onChanged: (value) => setState(() { selectedTemplateId = value; selectedEntityA = 'Auto'; selectedEntityB = 'Auto'; })),
          ])),
          const SizedBox(height: 22),
          _MvpCompareReadiness(payload: payload),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1050;
            final selectedCard = _SelectedComparisonCard(template: selectedTemplate, gate: selectedGate);
            final entityPicker = _ComparisonEntityPicker(template: selectedTemplate, payload: payload, selectedEntityA: selectedEntityA, selectedEntityB: selectedEntityB, onA: (value) => setState(() => selectedEntityA = value), onB: (value) => setState(() => selectedEntityB = value));
            if (!isWide) return Column(children: [selectedCard, const SizedBox(height: 14), entityPicker]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: selectedCard), const SizedBox(width: 14), Expanded(child: entityPicker)]);
          }),
          const SizedBox(height: 22),
          _ComparisonInputMatrix(payload: payload),
          const SizedBox(height: 22),
          _ComparisonBuildOrder(),
          const SizedBox(height: 22),
          _ComparisonTemplatesTable(filtered: filtered, gates: {for (final item in comparisonTemplateItems) item.id: _ComparisonGate.fromTemplate(item, payload)}, selectedTemplateId: selectedTemplate.id, onSelected: (template) => setState(() => selectedTemplateId = template.id)),
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
    if (raw.contains('player profiles')) inputs.add('Player profiles');
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
    if (raw.contains('g league')) inputs.add('G League assignments');
    return inputs;
  }

  static int _countForInput(String input, _ComparePayload payload) {
    switch (input) {
      case 'Player profiles':
        return payload.players.length;
      case 'Player season stats':
        return payload.playerStats.length;
      case 'Team season stats':
        return payload.teamStats.length;
      case 'Teams':
        return payload.teams.length;
      case 'Seasons':
        return payload.seasons.length;
      case 'Standings':
        return payload.standingsRows;
      case 'Playoffs':
        return payload.playoffRows;
      case 'Awards':
        return payload.awardRows;
      case 'Draft picks':
        return payload.draftRows;
      case 'Rosters':
        return payload.rosterRows;
      case 'Transactions':
        return payload.transactionRows;
      default:
        return 0;
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
  const _SelectedComparisonCard({required this.template, required this.gate});
  final ComparisonTemplate template;
  final _ComparisonGate gate;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))), const SizedBox(width: 10), InfoPill(label: gate.status)]),
    const SizedBox(height: 8),
    Text(template.output, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 16),
    _DetailLine(label: 'Type', value: template.comparisonType),
    _DetailLine(label: 'Template Status', value: template.status),
    _DetailLine(label: 'Primary Entities', value: template.primaryEntities),
    _DetailLine(label: 'Required Data', value: template.requiredDatasets),
    _DetailLine(label: 'Gate', value: '${gate.readyCount}/${gate.total} required inputs currently populated'),
    _DetailLine(label: 'Blockers', value: gate.blockers.isEmpty ? 'No blockers from currently mapped inputs.' : gate.blockers.join(', ')),
    _DetailLine(label: 'Notes', value: template.notes),
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
      const Text('These selectors are intentionally local and asset-aware. They will become true side-by-side compare controls once the underlying player, team, season, and stat assets are populated.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
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
    if (template.comparisonType == 'Player') {
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

class _ComparisonInputMatrix extends StatelessWidget {
  const _ComparisonInputMatrix({required this.payload});
  final _ComparePayload payload;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Comparison Input Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 34, columns: const [DataColumn(label: Text('Input Layer')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Status')), DataColumn(label: Text('Comparison Use')), DataColumn(label: Text('MVP Order'))], rows: [
      _row('Player profiles', payload.players.length, 'Player names, identity, profile detail, player compare slots', 'P0'),
      _row('Player season stats', payload.playerStats.length, 'Player-season side-by-side production comparisons', 'P0'),
      _row('Team season stats', payload.teamStats.length, 'Team-season record, scoring, efficiency comparisons', 'P1'),
      _row('Teams', payload.teams.length, 'Team selectors, team joins, franchise context', 'P0'),
      _row('Seasons', payload.seasons.length, 'Season selectors, era context, stat joins', 'P0'),
      _row('Standings', payload.standingsRows, 'Seed, record context, league rank, playoff qualification', 'P1'),
      _row('Playoffs', payload.playoffRows, 'Postseason path and series context', 'P2'),
      _row('Awards', payload.awardRows, 'Honors and voting context for player comparisons', 'P2'),
      _row('Draft picks', payload.draftRows, 'Draft-class comparisons and player development context', 'P2'),
      _row('Rosters', payload.rosterRows, 'Team context and player-team history', 'P2'),
      _row('Transactions', payload.transactionRows, 'Before/after team-building comparisons', 'P3'),
      _row('Games', payload.gameRows, 'Game-level and future matchup comparisons', 'P3'),
    ])),
  ]));
  DataRow _row(String layer, int count, String use, String order) => DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(layer, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text('$count')), DataCell(InfoPill(label: count == 0 ? 'Source pending' : 'Connected')), DataCell(SizedBox(width: 560, child: Text(use))), DataCell(Text(order))]);
}

class _ComparisonBuildOrder extends StatelessWidget {
  const _ComparisonBuildOrder();
  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Compare Build Order', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 10),
    Text('First, make Season League Context useful because teams and seasons are already connected. Second, activate Team Season vs Team Season after team season stats and standings are populated. Third, activate Player Season vs Player Season after player identity and traditional player stats are populated. Later, add career windows, draft classes, transactions, and G League development comparisons.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
  ]));
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
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Template')), DataColumn(label: Text('Type')), DataColumn(label: Text('Template Status')), DataColumn(label: Text('Data Gate')), DataColumn(label: Text('Ready')), DataColumn(label: Text('Required Datasets')), DataColumn(label: Text('Output')), DataColumn(label: Text('Notes'))], rows: [for (final item in filtered) DataRow(selected: selectedTemplateId == item.id, onSelectChanged: (_) => onSelected(item), cells: [DataCell(SizedBox(width: 290, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.comparisonType)), DataCell(InfoPill(label: item.status)), DataCell(InfoPill(label: gates[item.id]?.status ?? 'Not mapped')), DataCell(Text('${gates[item.id]?.readyCount ?? 0}/${gates[item.id]?.total ?? 0}')), DataCell(SizedBox(width: 430, child: Text(item.requiredDatasets))), DataCell(SizedBox(width: 620, child: Text(item.output))), DataCell(SizedBox(width: 520, child: Text(item.notes)))])])),
  ]));
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
