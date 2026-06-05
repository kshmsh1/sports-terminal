import 'package:flutter/material.dart';

import '../data/action_surface_items.dart';
import '../data/action_workflow_items.dart';
import '../data/community_product_items.dart';
import '../data/fantasy_product_items.dart';
import '../data/platform_endgame_items.dart';
import '../data/search_command_stage_items.dart';
import '../data/search_index_items.dart';
import '../data/search_route_intent_items.dart';
import '../data/workspace_studio_items.dart';
import '../models/player_profile.dart';
import '../models/registry_item.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/search_route_payload_producer_panel.dart';
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
  String routeIntent = 'All';
  String stageCategory = 'All';

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
        final stageCategories = ['All', ...searchCommandStageItems.map((item) => item.category).toSet().toList()..sort()];
        final selectedRoute = routeIntent == 'All' ? null : searchRouteIntentItems.firstWhere((item) => item.intent == routeIntent);
        final normalizedQuery = query.trim().toLowerCase();
        final results = items.where((item) {
          final text = '${item.title} ${item.category} ${item.target} ${item.status} ${item.description}'.toLowerCase();
          final routeMatch = selectedRoute == null || item.target == selectedRoute.target || item.description.toLowerCase().contains(selectedRoute.intent.toLowerCase()) || item.description.toLowerCase().contains(selectedRoute.target.toLowerCase());
          return (normalizedQuery.isEmpty || text.contains(normalizedQuery)) && (category == 'All' || item.category == category) && (status == 'All' || item.status == status) && routeMatch;
        }).toList();
        final filteredStages = searchCommandStageItems.where((item) => stageCategory == 'All' || item.category == stageCategory).toList();
        final connectedAssetCount = payload == null ? 0 : payload.connectedAssetCount;
        final workflowItems = items.where((item) => ['Action Center', 'Workspace Studio', 'Compare', 'Reports', 'Saved Views', 'Alerts', 'Export Center', 'Fantasy Terminal', 'Community Hub'].contains(item.target)).length;
        final sourcePendingItems = items.where((item) => item.status.toLowerCase().contains('source pending')).length;
        final p0Stages = searchCommandStageItems.where((item) => item.priority == 'P0').length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Search', subtitle: 'Command search across NBA entities, route intents, workspaces, data operations, source status, and Build Lab surfaces. Search now begins producing shared RoutePayload objects from connected Team and Season results.'),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 420, child: TextField(autofocus: false, onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search teams, seasons, actions, routes, workspaces...'))),
            _FilterDropdown(label: 'Category', value: category, values: categories, onChanged: (value) => setState(() => category = value)),
            _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
            _FilterDropdown(label: 'Route Intent', value: routeIntent, values: ['All', ...searchRouteIntentItems.map((item) => item.intent)], onChanged: (value) => setState(() => routeIntent = value)),
            _FilterDropdown(label: 'Stage', value: stageCategory, values: stageCategories, onChanged: (value) => setState(() => stageCategory = value)),
          ])),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Indexed Items', '${items.length}', 'Static + asset-backed'),
            _MetricSpec('Results', '${results.length}', normalizedQuery.isEmpty ? 'Current filters' : 'Query filtered'),
            _MetricSpec('Connected Assets', '$connectedAssetCount', 'Rows loaded now'),
            _MetricSpec('Command Stages', '${searchCommandStageItems.length}', '$p0Stages P0 stages'),
          ]),
          const SizedBox(height: 22),
          const SearchRoutePayloadProducerPanel(compact: true),
          const SizedBox(height: 22),
          _CommandPalettePanel(totalItems: items.length, workflowItems: workflowItems, sourcePendingItems: sourcePendingItems, selectedRoute: selectedRoute),
          const SizedBox(height: 22),
          _SearchRouteIntentTable(selected: routeIntent),
          const SizedBox(height: 22),
          _MvpSearchReadiness(payload: payload),
          const SizedBox(height: 22),
          _SearchStageTable(items: filteredStages),
          const SizedBox(height: 22),
          _SearchResults(results: results),
        ]);
      },
    );
  }

  List<SearchIndexItem> _buildItems(_SearchPayload? payload) {
    final dynamicItems = <SearchIndexItem>[];
    dynamicItems.addAll(_registryToSearchItems(category: 'Action', target: 'Action Center', items: actionSurfaceItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Action Route', target: 'Action Center', items: actionWorkflowItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Platform Endgame', target: 'Platform Endgame', items: platformEndgameItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Workspace Studio', target: 'Workspace Studio', items: workspaceStudioItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Fantasy Terminal', target: 'Fantasy Terminal', items: fantasyProductItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Community Hub', target: 'Community Hub', items: communityProductItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Search Stage', target: 'Search', items: searchCommandStageItems));
    for (final item in searchRouteIntentItems) {
      dynamicItems.add(SearchIndexItem(title: item.intent, category: 'Route Intent', target: item.target, status: item.status, description: '${item.inputObjects} → ${item.output}'));
    }
    if (payload != null) {
      dynamicItems.addAll([
        SearchIndexItem(title: 'Asset-backed NBA team directory', category: 'Data Asset', target: 'Teams', status: '${payload.teams.length} rows', description: 'Current NBA team records loaded from local JSON and available for joins.'),
        SearchIndexItem(title: 'Asset-backed season catalog', category: 'Data Asset', target: 'Seasons', status: '${payload.seasons.length} rows', description: 'Historical BAA/NBA season records loaded from local JSON and available for season joins.'),
        SearchIndexItem(title: 'Player profiles asset', category: 'MVP Data Gap', target: 'Players', status: payload.players.isEmpty ? 'Source pending' : '${payload.players.length} rows', description: 'Player identity records needed before player stats, awards, rosters, draft links, and transactions become useful.'),
        SearchIndexItem(title: 'Player season stats asset', category: 'MVP Data Gap', target: 'Stats', status: payload.playerStatRows == 0 ? 'Source pending' : '${payload.playerStatRows} rows', description: 'Player-season rows needed for Stats, Compare, Reports, trend charts, and player detail pages.'),
        SearchIndexItem(title: 'Team season stats asset', category: 'MVP Data Gap', target: 'Stats', status: payload.teamStatRows == 0 ? 'Source pending' : '${payload.teamStatRows} rows', description: 'Team-season rows needed for team pages, season pages, reports, standings context, and comparisons.'),
        SearchIndexItem(title: 'Standings asset', category: 'MVP Data Gap', target: 'Standings', status: payload.standingsRows == 0 ? 'Source pending' : '${payload.standingsRows} rows', description: 'Historical standings rows needed for season context, seeds, team-season analysis, and playoff qualification.'),
        SearchIndexItem(title: 'Playoff series asset', category: 'MVP Data Gap', target: 'Playoffs', status: payload.playoffRows == 0 ? 'Source pending' : '${payload.playoffRows} rows', description: 'Historical playoff series rows needed for season command pages and postseason reports.'),
        SearchIndexItem(title: 'Games asset', category: 'MVP Data Gap', target: 'Games', status: payload.gameRows == 0 ? 'Source pending' : '${payload.gameRows} rows', description: 'Game schedule, result, matchup, and future box-score rows needed for game detail pages and charts.'),
        SearchIndexItem(title: 'Awards and award races asset', category: 'MVP Data Gap', target: 'Awards', status: payload.awardRows == 0 ? 'Source pending' : '${payload.awardRows} rows', description: 'Award rows should include winners, runners-up, finalists, vote rank, vote points, vote share, and season context.'),
        SearchIndexItem(title: 'Draft picks asset', category: 'MVP Data Gap', target: 'Draft', status: payload.draftRows == 0 ? 'Source pending' : '${payload.draftRows} rows', description: 'Draft records needed for player development context, draft-class pages, and franchise-building analysis.'),
        SearchIndexItem(title: 'Roster asset', category: 'MVP Data Gap', target: 'Rosters', status: payload.rosterRows == 0 ? 'Source pending' : '${payload.rosterRows} rows', description: 'Roster rows needed for team-season context, player-team history, role analysis, and game eligibility.'),
        SearchIndexItem(title: 'Transactions asset', category: 'MVP Data Gap', target: 'Transactions', status: payload.transactionRows == 0 ? 'Source pending' : '${payload.transactionRows} rows', description: 'Movement records needed for player timelines, team-building context, trade trees, roster windows, and transaction reports.'),
      ]);
      for (final team in payload.teams) {
        dynamicItems.add(SearchIndexItem(title: '${team.city} ${team.name}', category: 'Team', target: 'Teams', status: 'Reference data connected', description: '${team.abbreviation} • ${team.conference} • ${team.division}'));
      }
      for (final season in payload.seasons.take(40)) {
        dynamicItems.add(SearchIndexItem(title: season.label, category: 'Season', target: 'Seasons', status: 'Reference data connected', description: '${season.league} season covering ${season.startYear}-${season.endYear}.'));
      }
      for (final player in payload.players.take(75)) {
        dynamicItems.add(SearchIndexItem(title: player.displayName, category: 'Player', target: 'Players', status: player.isActive == true ? 'Active' : player.isActive == false ? 'Inactive' : 'Unknown', description: '${player.position ?? 'Position pending'} • ${player.primaryTeamAbbreviation ?? 'Team pending'} • ${player.sourceId ?? 'Source pending'}'));
      }
    }
    return [...terminalSearchItems, ...dynamicItems];
  }

  List<SearchIndexItem> _registryToSearchItems({required String category, required String target, required List<RegistryItem> items}) => [for (final item in items) SearchIndexItem(title: item.title, category: category, target: target, status: item.status, description: '${item.description} Next: ${item.nextStep}')];
}

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

class _MetricSpec { const _MetricSpec(this.label, this.value, this.detail); final String label; final String value; final String detail; }
class _MetricGrid extends StatelessWidget { const _MetricGrid({required this.metrics}); final List<_MetricSpec> metrics; @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) { final isWide = constraints.maxWidth > 900; return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.45, children: [for (final metric in metrics) _Metric(label: metric.label, value: metric.value, detail: metric.detail)]); }); }
class _Metric extends StatelessWidget { const _Metric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }

class _CommandPalettePanel extends StatelessWidget {
  const _CommandPalettePanel({required this.totalItems, required this.workflowItems, required this.sourcePendingItems, required this.selectedRoute});
  final int totalItems;
  final int workflowItems;
  final int sourcePendingItems;
  final SearchRouteIntentItem? selectedRoute;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Command Palette Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    Text(selectedRoute == null ? 'Search indexes $totalItems objects and can now publish connected Team/Season rows as shared RoutePayload objects.' : '${selectedRoute!.intent} routes ${selectedRoute!.inputObjects} into ${selectedRoute!.target}: ${selectedRoute!.output}', style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 14),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '$workflowItems workflow results'), InfoPill(label: '$sourcePendingItems source-pending results'), const InfoPill(label: 'Team payload producer'), const InfoPill(label: 'Season payload producer')]),
  ]));
}

class _SearchRouteIntentTable extends StatelessWidget { const _SearchRouteIntentTable({required this.selected}); final String selected; @override Widget build(BuildContext context) => _SimpleSearchTable(title: 'Search Route Intents', columns: const ['Intent', 'Status', 'Target', 'Input Objects', 'Output'], rows: [for (final item in searchRouteIntentItems) [item.intent, item.status, item.target, item.inputObjects, item.output]], selectedFirstColumn: selected); }
class _MvpSearchReadiness extends StatelessWidget { const _MvpSearchReadiness({required this.payload}); final _SearchPayload? payload; @override Widget build(BuildContext context) { final p = payload; return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('NBA Search Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), const Text('Search is useful before data ingestion because it exposes connected references, source-pending gaps, workflow commands, and now shared route payload production.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${p?.teams.length ?? 0} teams'), InfoPill(label: '${p?.seasons.length ?? 0} seasons'), InfoPill(label: '${p?.players.length ?? 0} players'), InfoPill(label: '${p?.playerStatRows ?? 0} player stats'), InfoPill(label: '${p?.teamStatRows ?? 0} team stats')]) ])); } }
class _SearchStageTable extends StatelessWidget { const _SearchStageTable({required this.items}); final List<RegistryItem> items; @override Widget build(BuildContext context) => _SimpleSearchTable(title: 'Search Command Stage Model', columns: const ['Priority', 'Stage', 'Category', 'Status', 'Next Step'], rows: [for (final item in items) [item.priority, item.title, item.category, item.status, item.nextStep]]); }
class _SearchResults extends StatelessWidget { const _SearchResults({required this.results}); final List<SearchIndexItem> results; @override Widget build(BuildContext context) => _SimpleSearchTable(title: 'Search Results', columns: const ['Result', 'Category', 'Target', 'Status', 'Description'], rows: [for (final item in results) [item.title, item.category, item.target, item.status, item.description]]); }

class _SimpleSearchTable extends StatelessWidget {
  const _SimpleSearchTable({required this.title, required this.columns, required this.rows, this.selectedFirstColumn});
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final String? selectedFirstColumn;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${rows.length} rows', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: [for (final column in columns) DataColumn(label: Text(column))], rows: [for (final row in rows) DataRow(selected: selectedFirstColumn != null && row.isNotEmpty && row.first == selectedFirstColumn, cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 36 ? 560 : 180, child: Text(cell)))])])),
  ]));
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));
class _FilterDropdown extends StatelessWidget { const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged}); final String label; final String value; final Iterable<String> values; final ValueChanged<String> onChanged; @override Widget build(BuildContext context) { final items = values.toList(); return SizedBox(width: label == 'Route Intent' ? 270 : 230, child: DropdownButtonFormField<String>(value: items.contains(value) ? value : items.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); } }
