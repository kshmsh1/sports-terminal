import 'package:flutter/material.dart';

import '../data/action_surface_items.dart';
import '../data/player_command_stage_items.dart';
import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/registry_item.dart';
import '../models/roster_entry.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../models/transaction_record.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_PlayerPayload> payloadFuture = _loadPayload();
  String query = '';
  String selectedStatus = 'All';
  String selectedProfileView = 'Identity';
  String selectedMetricPackage = 'Fundamental';
  String selectedActionRoute = 'Compare';
  String selectedStageCategory = 'All';
  String? selectedPlayerId;

  Future<_PlayerPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadPlayerProfiles(),
      repository.loadPlayerSeasonStats(),
      repository.loadTeams(),
      repository.loadSeasons(),
      repository.loadRosters(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadTransactions(),
    ]);

    return _PlayerPayload(
      players: results[0] as List<PlayerProfile>,
      stats: results[1] as List<PlayerSeasonStat>,
      teams: results[2] as List<Team>,
      seasons: results[3] as List<Season>,
      rosters: results[4] as List<RosterEntry>,
      awards: results[5] as List<AwardRecord>,
      draftPicks: results[6] as List<DraftPick>,
      transactions: results[7] as List<TransactionRecord>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayerPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading player command workspace...', style: TextStyle(color: terminalTextSoft)));
        }

        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load player command workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final payload = snapshot.data ?? const _PlayerPayload(players: [], stats: [], teams: [], seasons: [], rosters: [], awards: [], draftPicks: [], transactions: []);
        final filteredPlayers = payload.players.where((player) {
          final normalized = query.trim().toLowerCase();
          final matchesStatus = selectedStatus == 'All' ||
              (selectedStatus == 'Active' && player.isActive == true) ||
              (selectedStatus == 'Inactive' && player.isActive == false) ||
              (selectedStatus == 'Unknown' && player.isActive == null);
          final matchesQuery = normalized.isEmpty ||
              player.id.toLowerCase().contains(normalized) ||
              player.displayName.toLowerCase().contains(normalized) ||
              (player.position ?? '').toLowerCase().contains(normalized) ||
              (player.primaryTeamAbbreviation ?? '').toLowerCase().contains(normalized) ||
              (player.college ?? '').toLowerCase().contains(normalized) ||
              (player.birthCountry ?? '').toLowerCase().contains(normalized);
          return matchesStatus && matchesQuery;
        }).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

        final selectedPlayer = _resolveSelectedPlayer(filteredPlayers, payload.players);
        final selectedSummary = selectedPlayer == null ? null : _PlayerSummary.fromPayload(selectedPlayer, payload);
        final activeCount = payload.players.where((player) => player.isActive == true).length;
        final inactiveCount = payload.players.where((player) => player.isActive == false).length;
        final unknownCount = payload.players.where((player) => player.isActive == null).length;
        final stageCategories = ['All', ...playerCommandStageItems.map((item) => item.category).toSet().toList()..sort()];
        final filteredStages = playerCommandStageItems.where((item) => selectedStageCategory == 'All' || item.category == selectedStageCategory).toList();
        final p0Stages = playerCommandStageItems.where((item) => item.priority == 'P0').length;
        final plannedStages = playerCommandStageItems.where((item) => item.status == 'Planned').length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Players', subtitle: 'Player command workspace for identity, stat packages, player detail, rosters, awards, draft links, transactions, action routes, source coverage, and future fantasy/scouting workflows. Real records only; source-pending assets stay blank.'),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
              _Metric(label: 'Player Profiles', value: '${payload.players.length}', detail: payload.players.isEmpty ? 'Source pending' : 'Real records'),
              _Metric(label: 'Season Stat Rows', value: '${payload.stats.length}', detail: 'Traditional + advanced schema'),
              _Metric(label: 'Active / Inactive', value: '$activeCount / $inactiveCount', detail: '$unknownCount unknown'),
              _Metric(label: 'Command Stages', value: '${playerCommandStageItems.length}', detail: '$p0Stages P0 / $plannedStages planned'),
            ]);
          }),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search player, ID, team, college, country...'))),
            _FilterDropdown(label: 'Status', value: selectedStatus, values: const ['All', 'Active', 'Inactive', 'Unknown'], onChanged: (value) => setState(() => selectedStatus = value)),
            _FilterDropdown(label: 'Profile View', value: selectedProfileView, values: _profileViews.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedProfileView = value)),
            _FilterDropdown(label: 'Metric Package', value: selectedMetricPackage, values: _playerMetricPackages.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedMetricPackage = value)),
            _FilterDropdown(label: 'Action Route', value: selectedActionRoute, values: _playerActionRoutes.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedActionRoute = value)),
            _FilterDropdown(label: 'Stage Category', value: selectedStageCategory, values: stageCategories, onChanged: (value) => setState(() => selectedStageCategory = value)),
          ])),
          const SizedBox(height: 22),
          _PlayerCommandTicket(profileView: _profileViews.firstWhere((item) => item.name == selectedProfileView), metricPackage: _playerMetricPackages.firstWhere((item) => item.name == selectedMetricPackage), actionRoute: _playerActionRoutes.firstWhere((item) => item.name == selectedActionRoute), summary: selectedSummary, payload: payload),
          const SizedBox(height: 22),
          if (payload.players.isEmpty) ...[
            _PendingPlayersPanel(payload: payload),
            const SizedBox(height: 22),
          ] else ...[
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1050;
              final table = _PlayersTable(players: filteredPlayers, selectedPlayerId: selectedPlayer?.id, onSelected: (player) => setState(() => selectedPlayerId = player.id), summaries: {for (final player in payload.players) player.id: _PlayerSummary.fromPayload(player, payload)});
              final detail = _SelectedPlayerPanel(summary: selectedSummary, metricPackage: selectedMetricPackage, actionRoute: selectedActionRoute);
              if (!isWide) return Column(children: [table, const SizedBox(height: 14), detail]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: table), const SizedBox(width: 14), Expanded(flex: 2, child: detail)]);
            }),
            const SizedBox(height: 22),
          ],
          _PlayerViewModeMatrix(),
          const SizedBox(height: 22),
          _PlayerMetricPackageMatrix(),
          const SizedBox(height: 22),
          _PlayerActionRouteMatrix(),
          const SizedBox(height: 22),
          _PlayerAttachmentMap(payload: payload),
          const SizedBox(height: 22),
          _StatsReadinessTable(stats: payload.stats),
          const SizedBox(height: 22),
          _PlayerCommandStageTable(items: filteredStages),
        ]);
      },
    );
  }

  PlayerProfile? _resolveSelectedPlayer(List<PlayerProfile> filtered, List<PlayerProfile> all) {
    for (final player in filtered) { if (player.id == selectedPlayerId) return player; }
    for (final player in all) { if (player.id == selectedPlayerId) return player; }
    if (filtered.isNotEmpty) return filtered.first;
    if (all.isNotEmpty) return all.first;
    return null;
  }
}

class _PlayerPayload { const _PlayerPayload({required this.players, required this.stats, required this.teams, required this.seasons, required this.rosters, required this.awards, required this.draftPicks, required this.transactions}); final List<PlayerProfile> players; final List<PlayerSeasonStat> stats; final List<Team> teams; final List<Season> seasons; final List<RosterEntry> rosters; final List<AwardRecord> awards; final List<DraftPick> draftPicks; final List<TransactionRecord> transactions; }
class _PlayerProfileView { const _PlayerProfileView(this.name, this.status, this.description); final String name; final String status; final String description; }
class _PlayerMetricPackage { const _PlayerMetricPackage(this.name, this.status, this.fields, this.use); final String name; final String status; final String fields; final String use; }
class _PlayerActionRoute { const _PlayerActionRoute(this.name, this.status, this.target, this.use); final String name; final String status; final String target; final String use; }

const _profileViews = <_PlayerProfileView>[
  _PlayerProfileView('Identity', 'First', 'Player bio, active flag, position, team, birth country, college, draft, source, and as-of date.'),
  _PlayerProfileView('Season Stats', 'Planned', 'Regular-season and playoff stat rows by season, team, and metric package.'),
  _PlayerProfileView('Game Logs', 'Future', 'Game-by-game production, rolling windows, opponent context, fantasy impact, and chart-ready rows.'),
  _PlayerProfileView('Awards', 'Planned', 'Award winners, runners-up, finalists, voting rank, voting points, vote share, and season context.'),
  _PlayerProfileView('Roster History', 'Planned', 'Roster windows, team context, position, jersey, two-way status, assignments, recalls, and eligibility later.'),
  _PlayerProfileView('Draft and Development', 'Future', 'Draft slot, team, school, country, G League pathway, player outcome, and development timeline.'),
  _PlayerProfileView('Transactions', 'Future', 'Trades, signings, waivers, assignments, recalls, contract events, and movement timelines.'),
  _PlayerProfileView('Fantasy and Scouting', 'Future', 'Fantasy value, scoring fit, roster decision context, scouting packets, media references, and qualitative notes.'),
];
const _playerMetricPackages = <_PlayerMetricPackage>[
  _PlayerMetricPackage('Fundamental', 'First', 'GP, MPG, PPG, RPG, APG, SPG, BPG, TPG, PF', 'Core player tables, compare, reports, fantasy, and award filters.'),
  _PlayerMetricPackage('Shooting', 'Planned', 'FG%, 3P%, FT%, eFG%, TS%, FTA later, C&S later, shot profile later', 'Efficiency analysis and trend views.'),
  _PlayerMetricPackage('Advanced Ratings', 'Planned', 'USG%, ORtg, DRtg, Net, BPM, VORP, WS, PER, EPM/DARKO/LEBRON later if licensed', 'Player value, ranking models, and source-aware advanced analysis.'),
  _PlayerMetricPackage('Playmaking', 'Planned', 'AST, TOV, AST/TOV, potential assists later, drives later, P&R creation later', 'Role analysis and guard/creator comparisons.'),
  _PlayerMetricPackage('Defense', 'Future', 'STL, BLK, PF, DFG%, deflections, charges drawn, offensive fouls drawn, contests later', 'Defensive context, award cases, and scouting work.'),
  _PlayerMetricPackage('Context', 'Planned', 'Team record, seed, roster window, playoff result, award rank, draft slot, source health', 'Adds environment to raw production.'),
  _PlayerMetricPackage('Fantasy', 'Future', 'Scoring value, games remaining, schedule density, role, matchup, category fit', 'Fantasy roster, waiver, trade, and matchup decisions.'),
  _PlayerMetricPackage('Source Audit', 'Planned', 'Source, as-of date, missing fields, lineage, rights posture, validation state', 'Trust and governance workflows.'),
];
const _playerActionRoutes = <_PlayerActionRoute>[
  _PlayerActionRoute('Compare', 'Planned', 'Compare', 'Send selected player rows into player season, award case, peak/prime, or fantasy comparison.'),
  _PlayerActionRoute('Workspace', 'Planned', 'Workspace Studio', 'Send player rows, metric packages, award rows, and source status into custom tables.'),
  _PlayerActionRoute('Report', 'Planned', 'Reports', 'Generate player season profile, award case, career window, or scouting packet shell.'),
  _PlayerActionRoute('Save View', 'Planned', 'Saved Views', 'Persist player filters, selected metrics, season windows, source snapshots, and output intent.'),
  _PlayerActionRoute('Alert', 'Future', 'Alerts', 'Monitor stat thresholds, award movement, roster changes, source changes, and fantasy flags.'),
  _PlayerActionRoute('Export', 'Planned', 'Export Center', 'Export player report, table, saved view, or source audit with missing-data flags.'),
  _PlayerActionRoute('Fantasy', 'Future', 'Fantasy Terminal', 'Send player into roster, waiver, trade, matchup, and watchlist workflows.'),
  _PlayerActionRoute('Scouting', 'Future', 'Scouting', 'Send player into scouting packets, media notes, game observations, and draft context.'),
  _PlayerActionRoute('Audit Source', 'Planned', 'Source Operations', 'Inspect player profile and stat provenance, source freshness, and rights posture.'),
];

class _PlayerSummary { const _PlayerSummary({required this.player, required this.statRows, required this.rosterRows, required this.awardRows, required this.draftRows, required this.transactionRows, required this.bestPpg, required this.latestSeasonId, required this.bestTs, required this.bestNetRating}); factory _PlayerSummary.fromPayload(PlayerProfile player, _PlayerPayload payload) { final statRows = payload.stats.where((item) => item.playerId == player.id).toList(); statRows.sort((a, b) => b.seasonId.compareTo(a.seasonId)); final ppgValues = statRows.map((item) => item.pointsPerGame).whereType<double>().toList()..sort((a, b) => b.compareTo(a)); final tsValues = statRows.map((item) => item.trueShootingPercentage).whereType<double>().toList()..sort((a, b) => b.compareTo(a)); final netValues = statRows.map((item) => item.netRating).whereType<double>().toList()..sort((a, b) => b.compareTo(a)); return _PlayerSummary(player: player, statRows: statRows.length, rosterRows: payload.rosters.where((item) => item.playerId == player.id).length, awardRows: payload.awards.where((item) => item.playerId == player.id).length, draftRows: payload.draftPicks.where((item) => item.playerId == player.id || item.playerName == player.displayName).length, transactionRows: payload.transactions.where((item) => item.playerId == player.id || item.playerName == player.displayName).length, bestPpg: ppgValues.isEmpty ? null : ppgValues.first, latestSeasonId: statRows.isEmpty ? null : statRows.first.seasonId, bestTs: tsValues.isEmpty ? null : tsValues.first, bestNetRating: netValues.isEmpty ? null : netValues.first); }
  final PlayerProfile player; final int statRows; final int rosterRows; final int awardRows; final int draftRows; final int transactionRows; final double? bestPpg; final String? latestSeasonId; final double? bestTs; final double? bestNetRating; int get connectedSections => [statRows, rosterRows, awardRows, draftRows, transactionRows].where((count) => count > 0).length; }

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));
class _FilterDropdown extends StatelessWidget { const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged}); final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; @override Widget build(BuildContext context) => SizedBox(width: 235, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); }

class _PlayerCommandTicket extends StatelessWidget { const _PlayerCommandTicket({required this.profileView, required this.metricPackage, required this.actionRoute, required this.summary, required this.payload}); final _PlayerProfileView profileView; final _PlayerMetricPackage metricPackage; final _PlayerActionRoute actionRoute; final _PlayerSummary? summary; final _PlayerPayload payload; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Player Command Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), const Text('This is the player-page operating model: pick a profile view, choose a metric package, bind an action route, check source readiness, and preserve missing-data honesty.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: profileView.status), InfoPill(label: metricPackage.status), InfoPill(label: actionRoute.status), InfoPill(label: payload.players.isEmpty ? 'Identity pending' : 'Identity connected'), InfoPill(label: '${actionSurfaceItems.length} action hooks')]), const SizedBox(height: 14), _DetailLine(label: 'Selected Player', value: summary?.player.displayName ?? 'No selected player yet'), _DetailLine(label: 'Profile View', value: '${profileView.name}: ${profileView.description}'), _DetailLine(label: 'Metric Package', value: '${metricPackage.name}: ${metricPackage.fields}'), _DetailLine(label: 'Action Route', value: '${actionRoute.name} → ${actionRoute.target}. ${actionRoute.use}'), _DetailLine(label: 'Readiness', value: payload.players.isEmpty ? 'Player identity is the blocker. No fake player records should be displayed.' : '${summary?.connectedSections ?? 0}/5 selected-player attachment sections connected.') ])); }

class _PendingPlayersPanel extends StatelessWidget { const _PendingPlayersPanel({required this.payload}); final _PlayerPayload payload; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Player Identity Source Pending', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), const Text('No fake players are displayed. The player profile asset is connected, but currently empty. Once a lawful official-source-preferred player identity export is selected, this screen will immediately support searchable player profiles, selected-player detail, linked stat rows, roster history, awards, draft context, transactions, report hooks, workspace routing, compare routing, and source audits.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 18), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${payload.teams.length} teams ready'), InfoPill(label: '${payload.seasons.length} seasons ready'), InfoPill(label: '${payload.stats.length} stat rows'), InfoPill(label: '${payload.rosters.length} roster rows'), InfoPill(label: '${payload.awards.length} award rows'), InfoPill(label: '${payload.draftPicks.length} draft rows'), InfoPill(label: '${payload.transactions.length} transaction rows')]) ])); }
class _SelectedPlayerPanel extends StatelessWidget { const _SelectedPlayerPanel({required this.summary, required this.metricPackage, required this.actionRoute}); final _PlayerSummary? summary; final String metricPackage; final String actionRoute; @override Widget build(BuildContext context) { if (summary == null) return const TerminalCard(child: Text('Select a player to inspect profile coverage.', style: TextStyle(color: terminalTextSoft))); final player = summary!.player; return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(player.displayName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))), InfoPill(label: player.isActive == true ? 'Active' : player.isActive == false ? 'Inactive' : 'Unknown')]), const SizedBox(height: 10), Text('${player.position ?? 'Position pending'} • ${player.primaryTeamAbbreviation ?? 'Team pending'} • ${player.birthCountry ?? 'Country pending'}', style: const TextStyle(color: terminalTextSoft, height: 1.4)), const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: [InfoPill(label: '${summary!.connectedSections}/5 sections connected'), InfoPill(label: player.sourceId ?? 'Source pending'), InfoPill(label: metricPackage), InfoPill(label: actionRoute), if (player.asOf != null) InfoPill(label: 'asOf ${player.asOf}')]), const SizedBox(height: 18), _DetailLine(label: 'Internal ID', value: player.id), _DetailLine(label: 'Height / Weight', value: '${player.height ?? '—'} / ${player.weightPounds == null ? '—' : '${player.weightPounds} lbs'}'), _DetailLine(label: 'Birth Date', value: player.birthDate ?? '—'), _DetailLine(label: 'College', value: player.college ?? '—'), _DetailLine(label: 'Draft', value: player.draftYear == null ? '—' : '${player.draftYear} / R${player.draftRound ?? '-'} / P${player.draftPick ?? '-'}'), _DetailLine(label: 'NBA Debut', value: player.nbaDebutYear?.toString() ?? '—'), const SizedBox(height: 16), LayoutBuilder(builder: (context, constraints) { final isWide = constraints.maxWidth > 420; return GridView.count(crossAxisCount: isWide ? 2 : 1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: isWide ? 2.2 : 3.4, children: [_MiniBadge(label: 'Stats', value: '${summary!.statRows}', detail: summary!.latestSeasonId ?? 'Source pending'), _MiniBadge(label: 'Best PPG', value: summary!.bestPpg?.toStringAsFixed(1) ?? '—', detail: 'Traditional stats'), _MiniBadge(label: 'Best TS%', value: _pct(summary!.bestTs), detail: 'Efficiency'), _MiniBadge(label: 'Best Net', value: summary!.bestNetRating?.toStringAsFixed(1) ?? '—', detail: 'Advanced'), _MiniBadge(label: 'Rosters', value: '${summary!.rosterRows}', detail: 'Team-season rows'), _MiniBadge(label: 'Awards', value: '${summary!.awardRows}', detail: 'Recognition rows'), _MiniBadge(label: 'Draft', value: '${summary!.draftRows}', detail: 'Draft links'), _MiniBadge(label: 'Moves', value: '${summary!.transactionRows}', detail: 'Transactions')]); })])); } }
String _pct(double? value) => value == null ? '—' : value <= 1 ? '${(value * 100).toStringAsFixed(1)}%' : '${value.toStringAsFixed(1)}%';
class _DetailLine extends StatelessWidget { const _DetailLine({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))])); }
class _MiniBadge extends StatelessWidget { const _MiniBadge({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: terminalBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w700)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), Text(detail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalAccent, fontSize: 11))])); } }

class _PlayersTable extends StatelessWidget { const _PlayersTable({required this.players, required this.selectedPlayerId, required this.onSelected, required this.summaries}); final List<PlayerProfile> players; final String? selectedPlayerId; final ValueChanged<PlayerProfile> onSelected; final Map<String, _PlayerSummary> summaries; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Player Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${players.length} players', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: const [DataColumn(label: Text('Player')), DataColumn(label: Text('Position')), DataColumn(label: Text('Team')), DataColumn(label: Text('Linked')), DataColumn(label: Text('Stats')), DataColumn(label: Text('Best PPG')), DataColumn(label: Text('Best TS%')), DataColumn(label: Text('Awards')), DataColumn(label: Text('College')), DataColumn(label: Text('Country')), DataColumn(label: Text('Draft')), DataColumn(label: Text('Status')), DataColumn(label: Text('Source'))], rows: [for (final player in players) DataRow(selected: selectedPlayerId == player.id, onSelectChanged: (_) => onSelected(player), cells: [DataCell(SizedBox(width: 220, child: Text(player.displayName, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(player.position ?? '—')), DataCell(Text(player.primaryTeamAbbreviation ?? '—')), DataCell(InfoPill(label: '${summaries[player.id]?.connectedSections ?? 0}/5')), DataCell(Text('${summaries[player.id]?.statRows ?? 0}')), DataCell(Text(summaries[player.id]?.bestPpg?.toStringAsFixed(1) ?? '—')), DataCell(Text(_pct(summaries[player.id]?.bestTs))), DataCell(Text('${summaries[player.id]?.awardRows ?? 0}')), DataCell(SizedBox(width: 180, child: Text(player.college ?? '—'))), DataCell(Text(player.birthCountry ?? '—')), DataCell(Text(player.draftYear == null ? '—' : '${player.draftYear} / R${player.draftRound ?? '-'} / P${player.draftPick ?? '-'}')), DataCell(InfoPill(label: player.isActive == true ? 'Active' : player.isActive == false ? 'Inactive' : 'Unknown')), DataCell(Text(player.sourceId ?? '—'))])]))])); }

class _PlayerViewModeMatrix extends StatelessWidget { @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Player Profile View Modes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('View')), DataColumn(label: Text('Status')), DataColumn(label: Text('Use'))], rows: [for (final item in _profileViews) DataRow(cells: [DataCell(SizedBox(width: 240, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 850, child: Text(item.description)))])]))])); }
class _PlayerMetricPackageMatrix extends StatelessWidget { @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Player Metric Package Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Package')), DataColumn(label: Text('Status')), DataColumn(label: Text('Fields')), DataColumn(label: Text('Use'))], rows: [for (final item in _playerMetricPackages) DataRow(cells: [DataCell(SizedBox(width: 210, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.fields))), DataCell(SizedBox(width: 540, child: Text(item.use)))])]))])); }
class _PlayerActionRouteMatrix extends StatelessWidget { @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Player Action Route Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Action')), DataColumn(label: Text('Status')), DataColumn(label: Text('Target')), DataColumn(label: Text('Use'))], rows: [for (final item in _playerActionRoutes) DataRow(cells: [DataCell(SizedBox(width: 190, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 210, child: Text(item.target))), DataCell(SizedBox(width: 760, child: Text(item.use)))])]))])); }

class _PlayerAttachmentMap extends StatelessWidget { const _PlayerAttachmentMap({required this.payload}); final _PlayerPayload payload; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Player Data Attachment Map', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Layer')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Join Key')), DataColumn(label: Text('Status')), DataColumn(label: Text('MVP Use'))], rows: [_attachmentRow('Player Profiles', payload.players.length, 'playerId', payload.players.isEmpty ? 'Source pending' : 'Connected', 'Identity, detail pages, search, reports'), _attachmentRow('Player Season Stats', payload.stats.length, 'playerId + seasonId', payload.stats.isEmpty ? 'Source pending' : 'Connected', 'Stats, comparisons, rankings, reports'), _attachmentRow('Rosters', payload.rosters.length, 'playerId + teamId + seasonId', payload.rosters.isEmpty ? 'Source pending' : 'Connected', 'Team context, role, contract status'), _attachmentRow('Awards', payload.awards.length, 'playerId + seasonId', payload.awards.isEmpty ? 'Source pending' : 'Connected', 'Recognition, award races, voting context'), _attachmentRow('Draft Picks', payload.draftPicks.length, 'playerId or playerName', payload.draftPicks.isEmpty ? 'Source pending' : 'Connected', 'Draft class and development analysis'), _attachmentRow('Transactions', payload.transactions.length, 'playerId or playerName', payload.transactions.isEmpty ? 'Source pending' : 'Connected', 'Movement timeline and team-building context')])]))); DataRow _attachmentRow(String layer, int rows, String joinKey, String status, String use) => DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(layer, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text('$rows')), DataCell(SizedBox(width: 240, child: Text(joinKey))), DataCell(InfoPill(label: status)), DataCell(SizedBox(width: 560, child: Text(use)))]); }
class _StatsReadinessTable extends StatelessWidget { const _StatsReadinessTable({required this.stats}); final List<PlayerSeasonStat> stats; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Player Season Stats Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${stats.length} rows', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columns: const [DataColumn(label: Text('Player')), DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Type')), DataColumn(label: Text('GP')), DataColumn(label: Text('MPG')), DataColumn(label: Text('PPG')), DataColumn(label: Text('RPG')), DataColumn(label: Text('APG')), DataColumn(label: Text('SPG')), DataColumn(label: Text('BPG')), DataColumn(label: Text('TPG')), DataColumn(label: Text('PF')), DataColumn(label: Text('FG%')), DataColumn(label: Text('3P%')), DataColumn(label: Text('FT%')), DataColumn(label: Text('eFG%')), DataColumn(label: Text('TS%')), DataColumn(label: Text('USG%')), DataColumn(label: Text('ORtg')), DataColumn(label: Text('DRtg')), DataColumn(label: Text('Net')), DataColumn(label: Text('Source'))], rows: stats.isEmpty ? const [DataRow(cells: [DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('Pending source'))])] : [for (final stat in stats) DataRow(cells: [DataCell(Text(stat.playerId)), DataCell(Text(stat.teamId ?? '—')), DataCell(Text(stat.seasonId)), DataCell(Text(stat.seasonType ?? '—')), DataCell(Text(stat.gamesPlayed?.toString() ?? '—')), DataCell(Text(stat.minutesPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.pointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.reboundsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.assistsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.stealsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.blocksPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.turnoversPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.personalFoulsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(_pct(stat.fieldGoalPercentage))), DataCell(Text(_pct(stat.threePointPercentage))), DataCell(Text(_pct(stat.freeThrowPercentage))), DataCell(Text(_pct(stat.effectiveFieldGoalPercentage))), DataCell(Text(_pct(stat.trueShootingPercentage))), DataCell(Text(_pct(stat.usagePercentage))), DataCell(Text(stat.offensiveRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.defensiveRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.netRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.sourceId ?? '—'))])]))])); }
class _PlayerCommandStageTable extends StatelessWidget { const _PlayerCommandStageTable({required this.items}); final List<RegistryItem> items; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Player Command Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 360, child: Text(item.inputs))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])]))])); }
class _Metric extends StatelessWidget { const _Metric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
