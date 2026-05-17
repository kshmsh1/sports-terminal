import 'package:flutter/material.dart';

import '../data/action_execution_stage_items.dart';
import '../data/action_surface_items.dart';
import '../data/action_workflow_items.dart';
import '../data/community_product_items.dart';
import '../data/context_asset_command_stage_items.dart';
import '../data/context_asset_module_items.dart';
import '../data/fantasy_product_items.dart';
import '../data/platform_endgame_items.dart';
import '../data/search_command_stage_items.dart';
import '../data/search_index_items.dart';
import '../data/search_route_intent_items.dart';
import '../data/stats_metric_family_items.dart';
import '../data/workspace_studio_items.dart';
import '../models/player_profile.dart';
import '../models/registry_item.dart';
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
        final normalizedQuery = query.trim().toLowerCase();
        final selectedRoute = routeIntent == 'All' ? null : searchRouteIntentItems.firstWhere((item) => item.intent == routeIntent);
        final results = items.where((item) {
          final text = '${item.title} ${item.category} ${item.target} ${item.description} ${item.status}'.toLowerCase();
          final routeMatch = selectedRoute == null || item.target == selectedRoute.target || item.description.toLowerCase().contains(selectedRoute.intent.toLowerCase()) || item.description.toLowerCase().contains(selectedRoute.target.toLowerCase());
          return (normalizedQuery.isEmpty || text.contains(normalizedQuery)) && (category == 'All' || item.category == category) && (status == 'All' || item.status == status) && routeMatch;
        }).toList();
        final filteredStages = searchCommandStageItems.where((item) => stageCategory == 'All' || item.category == stageCategory).toList();
        final connectedAssetCount = payload == null ? 0 : payload.connectedAssetCount;
        final workflowItems = items.where((item) => ['Action Center', 'Workspace Studio', 'Compare', 'Reports', 'Saved Views', 'Alerts', 'Export Center', 'Fantasy Terminal', 'Community Hub'].contains(item.target)).length;
        final sourcePendingItems = items.where((item) => item.status.toLowerCase().contains('source pending')).length;
        final p0Stages = searchCommandStageItems.where((item) => item.priority == 'P0').length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Search', subtitle: 'Command search across NBA entities, stats, workflows, route intents, workspaces, fantasy, community, data operations, source status, and Build Lab surfaces.'),
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
          _CommandPalettePanel(totalItems: items.length, workflowItems: workflowItems, sourcePendingItems: sourcePendingItems, selectedRoute: selectedRoute),
          const SizedBox(height: 22),
          _SearchRouteIntentTable(selected: routeIntent),
          const SizedBox(height: 22),
          _MvpSearchReadiness(payload: payload),
          const SizedBox(height: 22),
          _TerminalCommandCoveragePanel(payload: payload),
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
    dynamicItems.addAll(_broadCommandIndexItems);
    dynamicItems.addAll(_registryToSearchItems(category: 'Action', target: 'Action Center', items: actionSurfaceItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Action Route', target: 'Action Center', items: actionWorkflowItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Execution Stage', target: 'Action Center', items: actionExecutionStageItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Platform Endgame', target: 'Platform Endgame', items: platformEndgameItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Workspace Studio', target: 'Workspace Studio', items: workspaceStudioItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Fantasy Terminal', target: 'Fantasy Terminal', items: fantasyProductItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Community Hub', target: 'Community Hub', items: communityProductItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Context Stage', target: 'Context Assets', items: contextAssetCommandStageItems));
    dynamicItems.addAll(_registryToSearchItems(category: 'Search Stage', target: 'Search', items: searchCommandStageItems));
    for (final item in statsMetricFamilyItems) {
      dynamicItems.add(SearchIndexItem(title: '${item.family} metric family', category: 'Metric Family', target: 'Stats', status: item.status, description: '${item.firstUse} Player fields: ${item.playerFields}. Team fields: ${item.teamFields}.'));
    }
    for (final item in contextAssetModuleItems) {
      dynamicItems.add(SearchIndexItem(title: '${item.module} context asset', category: 'Context Asset', target: 'Context Assets', status: 'Module registry', description: '${item.recordType}. Keys: ${item.keys}. Blocker: ${item.blocker}'));
    }
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
        SearchIndexItem(title: 'Playoff series asset', category: 'MVP Data Gap', target: 'Playoffs', status: payload.playoffRows == 0 ? 'Source pending' : '${payload.playoffRows} rows', description: 'Historical playoff series rows needed for season command pages, franchise context, and postseason reports.'),
        SearchIndexItem(title: 'Games asset', category: 'MVP Data Gap', target: 'Games', status: payload.gameRows == 0 ? 'Source pending' : '${payload.gameRows} rows', description: 'Game schedule, result, matchup, and future box-score rows needed for game detail pages and charts.'),
        SearchIndexItem(title: 'Awards and award races asset', category: 'MVP Data Gap', target: 'Awards', status: payload.awardRows == 0 ? 'Source pending' : '${payload.awardRows} rows', description: 'Award rows should include winners, runners-up, finalists, vote rank, vote points, vote share, and season context.'),
        SearchIndexItem(title: 'Draft picks asset', category: 'MVP Data Gap', target: 'Draft', status: payload.draftRows == 0 ? 'Source pending' : '${payload.draftRows} rows', description: 'Draft records needed for player development context, draft-class pages, and franchise-building analysis.'),
        SearchIndexItem(title: 'Roster asset', category: 'MVP Data Gap', target: 'Rosters', status: payload.rosterRows == 0 ? 'Source pending' : '${payload.rosterRows} rows', description: 'Roster rows needed for team-season context, player-team history, role analysis, and game eligibility.'),
        SearchIndexItem(title: 'Transactions asset', category: 'MVP Data Gap', target: 'Transactions', status: payload.transactionRows == 0 ? 'Source pending' : '${payload.transactionRows} rows', description: 'Movement records needed for player timelines, team-building context, trade trees, roster windows, and transaction reports.'),
      ]);
      for (final team in payload.teams) {
        dynamicItems.add(SearchIndexItem(title: '${team.city} ${team.name}', category: 'Team', target: 'Teams', status: 'Reference data connected', description: '${team.abbreviation} • ${team.conference} • ${team.division}'));
      }
      for (final season in payload.seasons.take(30)) {
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

const _broadCommandIndexItems = <SearchIndexItem>[
  SearchIndexItem(title: 'Action Center', category: 'Core Workspace', target: 'Action Center', status: 'Route cockpit', description: 'Universal action layer for workspace, compare, report, save view, source audit, alerts, export, fantasy, scouting, and community routing.'),
  SearchIndexItem(title: 'Workspace Studio', category: 'Core Workspace', target: 'Workspace Studio', status: 'Builder cockpit', description: 'Excel-like surface for datasets, columns, formulas, joins, charts, scenarios, exports, saved views, and report inputs.'),
  SearchIndexItem(title: 'Stats command workspace', category: 'Core Workspace', target: 'Stats', status: 'Quant cockpit', description: 'Metric families, stat tables, rate modes, season types, routes, source audits, and future leaderboards.'),
  SearchIndexItem(title: 'Context Assets', category: 'Core Workspace', target: 'Context Assets', status: 'Context layer', description: 'Shared model for games, rosters, awards, draft, and transactions as reusable evidence objects.'),
  SearchIndexItem(title: 'Fantasy Terminal', category: 'Core Workspace', target: 'Fantasy Terminal', status: 'Product cockpit', description: 'Fantasy layer for manual leagues, scoring rules, roster decisions, waivers, trades, matchup labs, projections, and alerts.'),
  SearchIndexItem(title: 'Community Hub', category: 'Core Workspace', target: 'Community Hub', status: 'Publishing cockpit', description: 'Data-native community surface for entity-linked discussions, posts, private rooms, moderation, creator workspaces, and embedded terminal objects.'),
  SearchIndexItem(title: 'Platform Endgame', category: 'Build Lab', target: 'Platform Endgame', status: 'North star', description: 'Three-layer architecture covering Core Terminal, Workspace Studio, and Network layer.'),
  SearchIndexItem(title: 'Quality and QA workflow', category: 'Operations', target: 'QA Console', status: 'Planned', description: 'Validation checks for IDs, joins, row counts, missing fields, source metadata, and schema changes.'),
  SearchIndexItem(title: 'Data health workflow', category: 'Operations', target: 'Data Health', status: 'Planned', description: 'Operational monitoring for source freshness, populated rows, join coverage, and validation failures.'),
  SearchIndexItem(title: 'Import jobs workflow', category: 'Operations', target: 'Import Jobs', status: 'Planned', description: 'Manual batch imports from approved source paths into raw snapshots, normalized assets, and lineage records.'),
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
class _FilterDropdown extends StatelessWidget { const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged}); final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; @override Widget build(BuildContext context) => SizedBox(width: 240, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : 'All', dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); }

class _CommandPalettePanel extends StatelessWidget { const _CommandPalettePanel({required this.totalItems, required this.workflowItems, required this.sourcePendingItems, required this.selectedRoute}); final int totalItems; final int workflowItems; final int sourcePendingItems; final SearchRouteIntentItem? selectedRoute; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Command Palette Direction', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), const Text('Search should evolve into a command palette, not only a lookup box. It should find data objects, explain source blockers, route actions, open workspaces, generate reports, launch fantasy workflows, and surface community objects.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '$totalItems indexed'), InfoPill(label: '$workflowItems workflow items'), InfoPill(label: '$sourcePendingItems source-pending'), InfoPill(label: selectedRoute?.intent ?? 'All route intents')]), if (selectedRoute != null) ...[const SizedBox(height: 14), _SmallLine(label: 'Selected Route', value: '${selectedRoute!.target}: ${selectedRoute!.inputObjects} → ${selectedRoute!.output}')]])); }
class _SearchRouteIntentTable extends StatelessWidget { const _SearchRouteIntentTable({required this.selected}); final String selected; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Search Route Intent Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Intent')), DataColumn(label: Text('Status')), DataColumn(label: Text('Target')), DataColumn(label: Text('Input Objects')), DataColumn(label: Text('Output'))], rows: [for (final item in searchRouteIntentItems) DataRow(selected: selected == item.intent, cells: [DataCell(SizedBox(width: 190, child: Text(item.intent, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 190, child: Text(item.target))), DataCell(SizedBox(width: 500, child: Text(item.inputObjects))), DataCell(SizedBox(width: 600, child: Text(item.output)))])]))])); }
class _MvpSearchReadiness extends StatelessWidget { const _MvpSearchReadiness({required this.payload}); final _SearchPayload? payload; @override Widget build(BuildContext context) { if (payload == null) return const TerminalCard(child: Text('Loading asset-backed search readiness...', style: TextStyle(color: terminalTextSoft))); return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('NBA MVP Search Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), const Text('Search is becoming the command layer for the NBA MVP. The end state is one place to find players, teams, seasons, games, rosters, award races, draft classes, transactions, stats, reports, comparisons, datasets, sources, saved views, actions, routes, workspaces, fantasy workflows, and operations surfaces.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 18), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${payload!.teams.length} teams'), InfoPill(label: '${payload!.seasons.length} seasons'), InfoPill(label: '${payload!.players.length} players'), InfoPill(label: '${payload!.playerStatRows} player stat rows'), InfoPill(label: '${payload!.teamStatRows} team stat rows'), InfoPill(label: '${payload!.gameRows} games'), InfoPill(label: '${payload!.awardRows} awards'), InfoPill(label: '${payload!.transactionRows} transactions')]) ])); } }
class _TerminalCommandCoveragePanel extends StatelessWidget { const _TerminalCommandCoveragePanel({required this.payload}); final _SearchPayload? payload; @override Widget build(BuildContext context) { final rows = [_CommandCoverageRow('Entity Layer', 'Players, Teams, Seasons', payload == null ? 'Loading' : '${payload!.players.length + payload!.teams.length + payload!.seasons.length} rows', 'Identity, directory search, selected-detail pages, report headers'), _CommandCoverageRow('Event Layer', 'Games, Rosters, Transactions', payload == null ? 'Loading' : '${payload!.gameRows + payload!.rosterRows + payload!.transactionRows} rows', 'Schedules, eligibility, movement, roster context, timelines'), _CommandCoverageRow('Recognition Layer', 'Awards, Award Races, Draft', payload == null ? 'Loading' : '${payload!.awardRows + payload!.draftRows} rows', 'Award boards, voting context, draft classes, development paths'), _CommandCoverageRow('Performance Layer', 'Player Stats, Team Stats', payload == null ? 'Loading' : '${payload!.playerStatRows + payload!.teamStatRows} rows', 'Stats, comparisons, rankings, charts, reports'), const _CommandCoverageRow('Action Layer', 'Action Center, Routes, Execution Stages', 'Route cockpit', 'Moves objects from lookup into workspace, compare, report, export, alerts, and source audit'), const _CommandCoverageRow('Workspace Layer', 'Workspace Studio, Saved Views, Export Center', 'Builder cockpit', 'Excel-like tables, formulas, joins, charts, scenarios, snapshots, and outputs'), const _CommandCoverageRow('Network Layer', 'Fantasy Terminal, Community Hub', 'Product cockpit', 'Fantasy workflows, entity-linked publishing, private rooms, creator spaces')]; return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Terminal Command Coverage', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 34, columns: const [DataColumn(label: Text('Layer')), DataColumn(label: Text('Modules')), DataColumn(label: Text('Current State')), DataColumn(label: Text('Terminal Use'))], rows: [for (final row in rows) DataRow(cells: [DataCell(SizedBox(width: 180, child: Text(row.layer, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 340, child: Text(row.modules))), DataCell(InfoPill(label: row.state)), DataCell(SizedBox(width: 680, child: Text(row.use)))])]))])); } }
class _SearchStageTable extends StatelessWidget { const _SearchStageTable({required this.items}); final List<RegistryItem> items; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Search Command Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 230, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 160, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 320, child: Text(item.inputs))), DataCell(SizedBox(width: 420, child: Text(item.nextStep)))])]))])); }
class _SearchResults extends StatelessWidget { const _SearchResults({required this.results}); final List<SearchIndexItem> results; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Search Results', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${results.length} results', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Title')), DataColumn(label: Text('Category')), DataColumn(label: Text('Target')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description'))], rows: [for (final item in results) DataRow(cells: [DataCell(SizedBox(width: 280, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(SizedBox(width: 160, child: Text(item.target))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 780, child: Text(item.description)))])]))])); }
class _SmallLine extends StatelessWidget { const _SmallLine({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800, fontSize: 12))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.35)))]); }
class _CommandCoverageRow { const _CommandCoverageRow(this.layer, this.modules, this.state, this.use); final String layer; final String modules; final String state; final String use; }
class _MetricSpec { const _MetricSpec(this.label, this.value, this.detail); final String label; final String value; final String detail; }
class _MetricGrid extends StatelessWidget { const _MetricGrid({required this.metrics}); final List<_MetricSpec> metrics; @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) { final isWide = constraints.maxWidth > 900; return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [for (final metric in metrics) _SearchMetric(label: metric.label, value: metric.value, detail: metric.detail)]); }); }
class _SearchMetric extends StatelessWidget { const _SearchMetric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
