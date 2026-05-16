import 'package:flutter/material.dart';

import '../data/search_index_items.dart';
import '../models/player_profile.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_SearchPayload> payloadFuture = _loadPayload();
  String query = '';
  String category = 'All';
  String status = 'All';

  Future<_SearchPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadTeams(),
      repository.loadSeasons(),
      repository.loadPlayerProfiles(),
      repository.loadPlayerSeasonStats(),
      repository.loadTeamSeasonStats(),
      repository.loadStandings(),
      repository.loadPlayoffSeries(),
      repository.loadGames(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadRosters(),
      repository.loadTransactions(),
    ]);
    return _SearchPayload(
      teams: results[0] as List<Team>,
      seasons: results[1] as List<Season>,
      players: results[2] as List<PlayerProfile>,
      playerStatRows: (results[3] as List).length,
      teamStatRows: (results[4] as List).length,
      standingsRows: (results[5] as List).length,
      playoffRows: (results[6] as List).length,
      gameRows: (results[7] as List).length,
      awardRows: (results[8] as List).length,
      draftRows: (results[9] as List).length,
      rosterRows: (results[10] as List).length,
      transactionRows: (results[11] as List).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SearchPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        final payload = snapshot.data;
        final items = _buildItems(payload);
        final categories = ['All', ...items.map((item) => item.category).toSet().toList()..sort()];
        final statuses = ['All', ...items.map((item) => item.status).toSet().toList()..sort()];
        final normalizedQuery = query.trim().toLowerCase();
        final results = items.where((item) {
          final matchesQuery = normalizedQuery.isEmpty ||
              item.title.toLowerCase().contains(normalizedQuery) ||
              item.category.toLowerCase().contains(normalizedQuery) ||
              item.target.toLowerCase().contains(normalizedQuery) ||
              item.description.toLowerCase().contains(normalizedQuery) ||
              item.status.toLowerCase().contains(normalizedQuery);
          return matchesQuery && (category == 'All' || item.category == category) && (status == 'All' || item.status == status);
        }).toList();

        final coreItems = items.where((item) => item.category.contains('Core')).length;
        final mvpItems = items.where((item) => item.category.contains('MVP')).length;
        final dataItems = items.where((item) => item.category.contains('Data') || item.category.contains('Team') || item.category.contains('Season') || item.category.contains('Player')).length;
        final connectedAssetCount = payload == null ? 0 : payload.connectedAssetCount;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Search', subtitle: 'Command search across core NBA workspaces, entity modules, workflow tools, MVP gates, source-pending datasets, governance layers, and Build Lab surfaces.'),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 420, child: TextField(autofocus: false, onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search teams, seasons, players, stats, reports, sources...'))),
            _FilterDropdown(label: 'Category', value: category, values: categories, onChanged: (value) => setState(() => category = value)),
            _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
          ])),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
              _SearchMetric(label: 'Indexed Items', value: '${items.length}', detail: 'Static + asset-backed'),
              _SearchMetric(label: 'Results', value: '${results.length}', detail: normalizedQuery.isEmpty ? 'Current filters' : 'Query filtered'),
              _SearchMetric(label: 'Connected Assets', value: '$connectedAssetCount', detail: 'Rows loaded now'),
              _SearchMetric(label: 'Core/Data Items', value: '${coreItems + dataItems + mvpItems}', detail: 'NBA MVP focus'),
            ]);
          }),
          const SizedBox(height: 22),
          _MvpSearchReadiness(payload: payload),
          const SizedBox(height: 22),
          _TerminalCommandCoveragePanel(payload: payload),
          const SizedBox(height: 22),
          _SearchResults(results: results),
        ]);
      },
    );
  }

  List<SearchIndexItem> _buildItems(_SearchPayload? payload) {
    final dynamicItems = <SearchIndexItem>[];
    dynamicItems.addAll(_broadCommandIndexItems);
    if (payload != null) {
      dynamicItems.add(SearchIndexItem(title: 'Asset-backed NBA team directory', category: 'Data Asset', target: 'Teams', status: '${payload.teams.length} rows', description: 'Current NBA team records loaded from local JSON and available for joins.'));
      dynamicItems.add(SearchIndexItem(title: 'Asset-backed season catalog', category: 'Data Asset', target: 'Seasons', status: '${payload.seasons.length} rows', description: 'Historical BAA/NBA season records loaded from local JSON and available for season joins.'));
      dynamicItems.add(SearchIndexItem(title: 'Player profiles asset', category: 'MVP Data Gap', target: 'Players', status: payload.players.isEmpty ? 'Source pending' : '${payload.players.length} rows', description: 'Player identity records needed before player stats, awards, rosters, draft links, and transactions become useful.'));
      dynamicItems.add(SearchIndexItem(title: 'Player season stats asset', category: 'MVP Data Gap', target: 'Stats', status: payload.playerStatRows == 0 ? 'Source pending' : '${payload.playerStatRows} rows', description: 'Player-season rows needed for Stats, Compare, Reports, trend charts, and player detail pages.'));
      dynamicItems.add(SearchIndexItem(title: 'Team season stats asset', category: 'MVP Data Gap', target: 'Stats', status: payload.teamStatRows == 0 ? 'Source pending' : '${payload.teamStatRows} rows', description: 'Team-season rows needed for team pages, season pages, reports, standings context, and comparisons.'));
      dynamicItems.add(SearchIndexItem(title: 'Standings asset', category: 'MVP Data Gap', target: 'Standings', status: payload.standingsRows == 0 ? 'Source pending' : '${payload.standingsRows} rows', description: 'Historical standings rows needed for season context, seeds, team-season analysis, and playoff qualification.'));
      dynamicItems.add(SearchIndexItem(title: 'Playoff series asset', category: 'MVP Data Gap', target: 'Playoffs', status: payload.playoffRows == 0 ? 'Source pending' : '${payload.playoffRows} rows', description: 'Historical playoff series rows needed for season command pages, franchise context, and postseason reports.'));
      dynamicItems.add(SearchIndexItem(title: 'Games asset', category: 'MVP Data Gap', target: 'Games', status: payload.gameRows == 0 ? 'Source pending' : '${payload.gameRows} rows', description: 'Game schedule, result, matchup, and future box-score rows needed for game detail pages and charts.'));
      dynamicItems.add(SearchIndexItem(title: 'Awards and award races asset', category: 'MVP Data Gap', target: 'Awards', status: payload.awardRows == 0 ? 'Source pending' : '${payload.awardRows} rows', description: 'Award rows should include winners, runners-up, finalists, vote rank, vote points, vote share, and season context.'));
      dynamicItems.add(SearchIndexItem(title: 'Draft picks asset', category: 'MVP Data Gap', target: 'Draft', status: payload.draftRows == 0 ? 'Source pending' : '${payload.draftRows} rows', description: 'Draft records needed for player development context, draft-class pages, and franchise-building analysis.'));
      dynamicItems.add(SearchIndexItem(title: 'Roster asset', category: 'MVP Data Gap', target: 'Rosters', status: payload.rosterRows == 0 ? 'Source pending' : '${payload.rosterRows} rows', description: 'Roster rows needed for team-season context, player-team history, role analysis, and game eligibility.'));
      dynamicItems.add(SearchIndexItem(title: 'Transactions asset', category: 'MVP Data Gap', target: 'Transactions', status: payload.transactionRows == 0 ? 'Source pending' : '${payload.transactionRows} rows', description: 'Movement records needed for player timelines, team-building context, trade trees, roster windows, and transaction reports.'));
      for (final team in payload.teams) {
        dynamicItems.add(SearchIndexItem(title: '${team.city} ${team.name}', category: 'Team', target: 'Teams', status: 'Reference data connected', description: '${team.abbreviation} • ${team.conference} • ${team.division}'));
      }
      for (final season in payload.seasons.take(20)) {
        dynamicItems.add(SearchIndexItem(title: season.label, category: 'Season', target: 'Seasons', status: 'Reference data connected', description: '${season.league} season covering ${season.startYear}-${season.endYear}.'));
      }
      for (final player in payload.players.take(50)) {
        dynamicItems.add(SearchIndexItem(title: player.displayName, category: 'Player', target: 'Players', status: player.isActive == true ? 'Active' : player.isActive == false ? 'Inactive' : 'Unknown', description: '${player.position ?? 'Position pending'} • ${player.primaryTeamAbbreviation ?? 'Team pending'} • ${player.sourceId ?? 'Source pending'}'));
      }
    }
    return [...terminalSearchItems, ...dynamicItems];
  }
}

const _broadCommandIndexItems = <SearchIndexItem>[
  SearchIndexItem(title: 'Game command center', category: 'Core Workspace', target: 'Games', status: 'Asset-backed', description: 'Schedule, result, matchup, box-score hooks, playoff game context, and future trend chart source rows.'),
  SearchIndexItem(title: 'Roster command center', category: 'Core Workspace', target: 'Rosters', status: 'Asset-backed', description: 'Team-season roster windows, player-team history, two-way status, assignments, recalls, and game eligibility.'),
  SearchIndexItem(title: 'Award race command center', category: 'Core Workspace', target: 'Awards', status: 'Race-ready model', description: 'Winners, runners-up, finalists, vote rank, first-place votes, voting points, vote share, and season/player context.'),
  SearchIndexItem(title: 'Draft command center', category: 'Core Workspace', target: 'Draft', status: 'Asset-backed', description: 'Draft classes, picks, teams, schools, countries, player identity joins, outcomes, and development paths.'),
  SearchIndexItem(title: 'Transaction command center', category: 'Core Workspace', target: 'Transactions', status: 'Asset-backed', description: 'Player movement, team-building, roster effects, trade trees, contract context, and timeline reports.'),
  SearchIndexItem(title: 'Contracts workspace', category: 'Core Workspace', target: 'Contracts', status: 'Planned', description: 'Salary, guarantees, options, extensions, cap context, contract events, and transaction linkage.'),
  SearchIndexItem(title: 'Media and research workspace', category: 'Core Workspace', target: 'Media & Research', status: 'Planned', description: 'Source-backed notes, citations, article references, video links, scouting context, and report support.'),
  SearchIndexItem(title: 'Scouting workspace', category: 'Core Workspace', target: 'Scouting', status: 'Planned', description: 'Qualitative player evaluation, role notes, strengths, weaknesses, development observations, and source-backed scouting packets.'),
  SearchIndexItem(title: 'Saved views workflow', category: 'Workflow', target: 'Saved Views', status: 'Template ready', description: 'User workspace presets for repeated player, team, season, stat, report, and source views.'),
  SearchIndexItem(title: 'Alerts workflow', category: 'Workflow', target: 'Alerts', status: 'Template ready', description: 'Future monitoring layer for source changes, stat thresholds, import failures, roster changes, and saved-view events.'),
  SearchIndexItem(title: 'Export center workflow', category: 'Workflow', target: 'Export Center', status: 'Planned', description: 'Downloadable reports, CSV tables, copied snippets, workspace exports, and research packets.'),
  SearchIndexItem(title: 'Quality and QA workflow', category: 'Operations', target: 'QA Console', status: 'Planned', description: 'Validation checks for IDs, joins, row counts, missing fields, source metadata, and schema changes.'),
  SearchIndexItem(title: 'Data health workflow', category: 'Operations', target: 'Data Health', status: 'Planned', description: 'Operational monitoring for source freshness, populated rows, join coverage, and validation failures.'),
  SearchIndexItem(title: 'Import jobs workflow', category: 'Operations', target: 'Import Jobs', status: 'Planned', description: 'Manual batch imports from approved source paths into raw snapshots, normalized assets, and lineage records.'),
  SearchIndexItem(title: 'Source registry workflow', category: 'Operations', target: 'Source Registry', status: 'Planned', description: 'Official, public, licensed, internal, and future third-party source tracking with rights and provenance context.'),
];

class _SearchPayload {
  const _SearchPayload({required this.teams, required this.seasons, required this.players, required this.playerStatRows, required this.teamStatRows, required this.standingsRows, required this.playoffRows, required this.gameRows, required this.awardRows, required this.draftRows, required this.rosterRows, required this.transactionRows});
  final List<Team> teams;
  final List<Season> seasons;
  final List<PlayerProfile> players;
  final int playerStatRows;
  final int teamStatRows;
  final int standingsRows;
  final int playoffRows;
  final int gameRows;
  final int awardRows;
  final int draftRows;
  final int rosterRows;
  final int transactionRows;
  int get connectedAssetCount => teams.length + seasons.length + players.length + playerStatRows + teamStatRows + standingsRows + playoffRows + gameRows + awardRows + draftRows + rosterRows + transactionRows;
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(width: 240, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : 'All', dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _MvpSearchReadiness extends StatelessWidget {
  const _MvpSearchReadiness({required this.payload});
  final _SearchPayload? payload;
  @override
  Widget build(BuildContext context) {
    if (payload == null) return const TerminalCard(child: Text('Loading asset-backed search readiness...', style: TextStyle(color: terminalTextSoft)));
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('NBA MVP Search Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('Search is becoming the command layer for the NBA MVP. The end state is one place to find players, teams, seasons, games, rosters, award races, draft classes, transactions, stats, reports, comparisons, datasets, sources, saved views, and operations surfaces.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${payload!.teams.length} teams'), InfoPill(label: '${payload!.seasons.length} seasons'), InfoPill(label: '${payload!.players.length} players'), InfoPill(label: '${payload!.playerStatRows} player stat rows'), InfoPill(label: '${payload!.teamStatRows} team stat rows'), InfoPill(label: '${payload!.gameRows} games'), InfoPill(label: '${payload!.awardRows} awards'), InfoPill(label: '${payload!.transactionRows} transactions')]),
    ]));
  }
}

class _TerminalCommandCoveragePanel extends StatelessWidget {
  const _TerminalCommandCoveragePanel({required this.payload});
  final _SearchPayload? payload;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _CommandCoverageRow('Entity Layer', 'Players, Teams, Seasons', payload == null ? 'Loading' : '${payload!.players.length + payload!.teams.length + payload!.seasons.length} rows', 'Identity, directory search, selected-detail pages, report headers'),
      _CommandCoverageRow('Event Layer', 'Games, Rosters, Transactions', payload == null ? 'Loading' : '${payload!.gameRows + payload!.rosterRows + payload!.transactionRows} rows', 'Schedules, eligibility, movement, roster context, timelines'),
      _CommandCoverageRow('Recognition Layer', 'Awards, Award Races, Draft', payload == null ? 'Loading' : '${payload!.awardRows + payload!.draftRows} rows', 'Award boards, voting context, draft classes, development paths'),
      _CommandCoverageRow('Performance Layer', 'Player Stats, Team Stats', payload == null ? 'Loading' : '${payload!.playerStatRows + payload!.teamStatRows} rows', 'Stats, comparisons, rankings, charts, reports'),
      _CommandCoverageRow('Postseason Layer', 'Standings, Playoffs', payload == null ? 'Loading' : '${payload!.standingsRows + payload!.playoffRows} rows', 'Seeds, records, playoff paths, season context'),
      const _CommandCoverageRow('Workflow Layer', 'Compare, Reports, Saved Views, Alerts', 'Shell ready', 'Decision workflows, reusable output, monitoring, user workspaces'),
      const _CommandCoverageRow('Operations Layer', 'Sources, Imports, QA, Data Health', 'Build Lab', 'Lineage, validation, rights posture, data quality, import readiness'),
    ];
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.all(18), child: Text('Terminal Command Coverage', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
      const Divider(height: 1, color: terminalBorder),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 34, columns: const [DataColumn(label: Text('Layer')), DataColumn(label: Text('Modules')), DataColumn(label: Text('Current State')), DataColumn(label: Text('Terminal Use'))], rows: [for (final row in rows) DataRow(cells: [DataCell(SizedBox(width: 180, child: Text(row.layer, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 320, child: Text(row.modules))), DataCell(InfoPill(label: row.state)), DataCell(SizedBox(width: 620, child: Text(row.use)))])])),
    ]));
  }
}

class _CommandCoverageRow {
  const _CommandCoverageRow(this.layer, this.modules, this.state, this.use);
  final String layer;
  final String modules;
  final String state;
  final String use;
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results});
  final List<SearchIndexItem> results;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Search Results', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${results.length} results', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Title')), DataColumn(label: Text('Category')), DataColumn(label: Text('Target')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description'))], rows: [for (final item in results) DataRow(cells: [DataCell(SizedBox(width: 280, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 160, child: Text(item.category))), DataCell(Text(item.target)), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 700, child: Text(item.description)))])])),
  ]));
}

class _SearchMetric extends StatelessWidget {
  const _SearchMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
