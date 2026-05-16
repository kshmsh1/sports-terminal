import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_StatsPayload> payloadFuture = _loadPayload();
  String query = '';
  String table = 'All';
  String season = 'All';
  String minGames = 'All';
  String statFamily = 'All';
  String viewMode = 'Per Game';
  String? selectedPlayerStatId;
  String? selectedTeamStatId;

  Future<_StatsPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadPlayerSeasonStats(),
      repository.loadTeamSeasonStats(),
      repository.loadPlayerProfiles(),
      repository.loadTeams(),
      repository.loadSeasons(),
    ]);
    return _StatsPayload(playerStats: results[0] as List<PlayerSeasonStat>, teamStats: results[1] as List<TeamSeasonStat>, players: results[2] as List<PlayerProfile>, teams: results[3] as List<Team>, seasons: results[4] as List<Season>);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StatsPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const TerminalCard(child: Text('Loading statistics command workspace...', style: TextStyle(color: terminalTextSoft)));
        if (snapshot.hasError) return TerminalCard(child: Text('Unable to load statistics command workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        final payload = snapshot.data ?? const _StatsPayload(playerStats: [], teamStats: [], players: [], teams: [], seasons: []);
        final normalized = query.trim().toLowerCase();
        final playerRows = payload.playerStats.where((row) => _matchesPlayer(row, payload, normalized)).toList();
        final teamRows = payload.teamStats.where((row) => _matchesTeam(row, payload, normalized)).toList();
        final showPlayers = table == 'All' || table == 'Player season stats';
        final showTeams = table == 'All' || table == 'Team season stats';
        final visiblePlayerRows = showPlayers ? playerRows : <PlayerSeasonStat>[];
        final visibleTeamRows = showTeams ? teamRows : <TeamSeasonStat>[];
        final coverage = _StatsCoverage.fromPayload(payload);
        final selectedDetail = _SelectedStatDetail.resolve(visiblePlayerRows, visibleTeamRows, selectedPlayerStatId, selectedTeamStatId, payload);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Stats', subtitle: 'Statistics command workspace for player and team season tables, stat families, rate view modes, regular season/playoff splits, advanced efficiency fields, and source-aware empty states.'),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [_MetricSpec('Player Stat Rows', '${payload.playerStats.length}', payload.playerStats.isEmpty ? 'Source pending' : 'Loaded'), _MetricSpec('Team Stat Rows', '${payload.teamStats.length}', payload.teamStats.isEmpty ? 'Source pending' : 'Loaded'), _MetricSpec('Visible Rows', '${visiblePlayerRows.length + visibleTeamRows.length}', 'After filters'), _MetricSpec('View Mode', viewMode, statFamily)]),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 350, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search player, team, season, source...'))),
            _FilterDropdown(label: 'Table', value: table, values: const ['All', 'Player season stats', 'Team season stats'], onChanged: (value) => setState(() => table = value)),
            _FilterDropdown(label: 'Season', value: season, values: ['All', ...payload.seasons.map((item) => item.id)], onChanged: (value) => setState(() => season = value)),
            _FilterDropdown(label: 'Min GP', value: minGames, values: const ['All', '1+', '20+', '41+', '65+'], onChanged: (value) => setState(() => minGames = value)),
            _FilterDropdown(label: 'Family', value: statFamily, values: const ['All', 'Traditional', 'Efficiency', 'Advanced', 'Defense'], onChanged: (value) => setState(() => statFamily = value)),
            _FilterDropdown(label: 'View', value: viewMode, values: const ['Per Game', 'Per 36', 'Per 48', 'Per 100', 'Totals'], onChanged: (value) => setState(() => viewMode = value)),
          ])),
          const SizedBox(height: 22),
          _StatsReadinessPanel(payload: payload, coverage: coverage),
          const SizedBox(height: 22),
          _StatFamilyPanel(statFamily: statFamily, viewMode: viewMode),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final detail = _SelectedStatPanel(detail: selectedDetail);
            final deps = _DependencyPanel(payload: payload, coverage: coverage);
            if (constraints.maxWidth < 1050) return Column(children: [detail, const SizedBox(height: 14), deps]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: detail), const SizedBox(width: 14), Expanded(child: deps)]);
          }),
          const SizedBox(height: 22),
          const _ChartPlanningPanel(),
          const SizedBox(height: 22),
          if (showPlayers) _PlayerStatsTable(records: visiblePlayerRows, payload: payload, selectedId: selectedPlayerStatId, family: statFamily, onSelected: (row) => setState(() { selectedPlayerStatId = row.id; selectedTeamStatId = null; })),
          if (showPlayers && showTeams) const SizedBox(height: 22),
          if (showTeams) _TeamStatsTable(records: visibleTeamRows, payload: payload, selectedId: selectedTeamStatId, family: statFamily, onSelected: (row) => setState(() { selectedTeamStatId = row.id; selectedPlayerStatId = null; })),
        ]);
      },
    );
  }

  bool _matchesPlayer(PlayerSeasonStat row, _StatsPayload payload, String normalized) {
    if (season != 'All' && row.seasonId != season) return false;
    final min = _minimumGames(minGames);
    if (min != null && (row.gamesPlayed ?? 0) < min) return false;
    if (normalized.isEmpty) return true;
    final player = payload.playersById[row.playerId];
    final team = row.teamId == null ? null : payload.teamsById[row.teamId!];
    final seasonLabel = payload.seasonsById[row.seasonId]?.label;
    return [row.playerId, player?.displayName, player?.position, row.teamId, team?.name, team?.abbreviation, row.seasonId, seasonLabel, row.seasonType, row.sourceId].whereType<String>().join(' ').toLowerCase().contains(normalized);
  }

  bool _matchesTeam(TeamSeasonStat row, _StatsPayload payload, String normalized) {
    if (season != 'All' && row.seasonId != season) return false;
    if (normalized.isEmpty) return true;
    final team = payload.teamsById[row.teamId];
    final seasonLabel = payload.seasonsById[row.seasonId]?.label;
    return [row.teamId, team?.name, team?.abbreviation, team?.city, row.seasonId, seasonLabel, row.seasonType, row.sourceId].whereType<String>().join(' ').toLowerCase().contains(normalized);
  }

  int? _minimumGames(String value) {
    if (value == '1+') return 1;
    if (value == '20+') return 20;
    if (value == '41+') return 41;
    if (value == '65+') return 65;
    return null;
  }
}

class _StatsPayload {
  const _StatsPayload({required this.playerStats, required this.teamStats, required this.players, required this.teams, required this.seasons});
  final List<PlayerSeasonStat> playerStats;
  final List<TeamSeasonStat> teamStats;
  final List<PlayerProfile> players;
  final List<Team> teams;
  final List<Season> seasons;
  Map<String, PlayerProfile> get playersById => {for (final item in players) item.id: item};
  Map<String, Team> get teamsById => {for (final item in teams) item.id: item};
  Map<String, Season> get seasonsById => {for (final item in seasons) item.id: item};
}

class _StatsCoverage {
  const _StatsCoverage({required this.playerJoins, required this.playerSeasonJoins, required this.teamJoins, required this.teamSeasonJoins, required this.rowsWithSource});
  factory _StatsCoverage.fromPayload(_StatsPayload payload) => _StatsCoverage(playerJoins: payload.playerStats.where((row) => payload.playersById.containsKey(row.playerId)).length, playerSeasonJoins: payload.playerStats.where((row) => payload.seasonsById.containsKey(row.seasonId)).length, teamJoins: payload.teamStats.where((row) => payload.teamsById.containsKey(row.teamId)).length, teamSeasonJoins: payload.teamStats.where((row) => payload.seasonsById.containsKey(row.seasonId)).length, rowsWithSource: [...payload.playerStats.map((row) => row.sourceId), ...payload.teamStats.map((row) => row.sourceId)].whereType<String>().where((value) => value.isNotEmpty).length);
  final int playerJoins;
  final int playerSeasonJoins;
  final int teamJoins;
  final int teamSeasonJoins;
  final int rowsWithSource;
  int get joinedRows => playerJoins + playerSeasonJoins + teamJoins + teamSeasonJoins;
}

class _SelectedStatDetail {
  const _SelectedStatDetail.player(this.playerRow, this.payload) : teamRow = null;
  const _SelectedStatDetail.team(this.teamRow, this.payload) : playerRow = null;
  static _SelectedStatDetail? resolve(List<PlayerSeasonStat> playerRows, List<TeamSeasonStat> teamRows, String? playerId, String? teamId, _StatsPayload payload) {
    for (final row in playerRows) { if (row.id == playerId) return _SelectedStatDetail.player(row, payload); }
    for (final row in teamRows) { if (row.id == teamId) return _SelectedStatDetail.team(row, payload); }
    if (playerRows.isNotEmpty) return _SelectedStatDetail.player(playerRows.first, payload);
    if (teamRows.isNotEmpty) return _SelectedStatDetail.team(teamRows.first, payload);
    return null;
  }
  final PlayerSeasonStat? playerRow;
  final TeamSeasonStat? teamRow;
  final _StatsPayload payload;
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(width: 220, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _StatsReadinessPanel extends StatelessWidget {
  const _StatsReadinessPanel({required this.payload, required this.coverage});
  final _StatsPayload payload;
  final _StatsCoverage coverage;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Stats MVP Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), const Text('Stats is being shaped around source-backed tables, stat families, regular season/playoff splits, rate view modes, chart readiness, and clean joins. Advanced and tracking metrics stay source-pending until the right data path exists.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 18), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${payload.players.length} players'), InfoPill(label: '${payload.teams.length} teams'), InfoPill(label: '${payload.seasons.length} seasons'), InfoPill(label: '${payload.playerStats.length} player stat rows'), InfoPill(label: '${payload.teamStats.length} team stat rows'), InfoPill(label: '${coverage.rowsWithSource} sourced rows')])]));
}

class _StatFamilyPanel extends StatelessWidget {
  const _StatFamilyPanel({required this.statFamily, required this.viewMode});
  final String statFamily;
  final String viewMode;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Stat Family + View Mode Layer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text('Current family: $statFamily. Current view: $viewMode. The table can now be organized around traditional box, efficiency, advanced, and defensive families rather than one giant metric dump.', style: const TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 16), const Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Regular season'), InfoPill(label: 'Playoffs'), InfoPill(label: 'Per game'), InfoPill(label: 'Per 36'), InfoPill(label: 'Per 48'), InfoPill(label: 'Per 100'), InfoPill(label: 'Totals')])]));
}

class _SelectedStatPanel extends StatelessWidget {
  const _SelectedStatPanel({required this.detail});
  final _SelectedStatDetail? detail;
  @override
  Widget build(BuildContext context) {
    if (detail == null) return const TerminalCard(child: Text('Select a stat row to inspect joined identity, season, source, and metric detail. Stat assets are currently source-pending.', style: TextStyle(color: terminalTextSoft, height: 1.45)));
    final playerRow = detail!.playerRow;
    final teamRow = detail!.teamRow;
    final payload = detail!.payload;
    final title = playerRow != null ? payload.playersById[playerRow.playerId]?.displayName ?? playerRow.playerId : payload.teamsById[teamRow!.teamId]?.name ?? teamRow.teamId;
    final subtitle = playerRow != null ? '${payload.seasonsById[playerRow.seasonId]?.label ?? playerRow.seasonId} • ${playerRow.teamId ?? 'Team pending'}' : '${payload.seasonsById[teamRow!.seasonId]?.label ?? teamRow.seasonId} • Team season stat';
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(subtitle, style: const TextStyle(color: terminalTextSoft, height: 1.4)), const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: [InfoPill(label: playerRow == null ? 'Team stat' : 'Player stat'), InfoPill(label: (playerRow?.sourceId ?? teamRow?.sourceId) ?? 'Source pending')]), const SizedBox(height: 16), if (playerRow != null) ...[_DetailLine(label: 'Core', value: '${_fmt(playerRow.pointsPerGame)} PTS / ${_fmt(playerRow.reboundsPerGame)} REB / ${_fmt(playerRow.assistsPerGame)} AST'), _DetailLine(label: 'Defense', value: '${_fmt(playerRow.stealsPerGame)} STL / ${_fmt(playerRow.blocksPerGame)} BLK / ${_fmt(playerRow.personalFoulsPerGame)} PF'), _DetailLine(label: 'Efficiency', value: '${_pct(playerRow.trueShootingPercentage)} TS / ${_pct(playerRow.effectiveFieldGoalPercentage)} eFG / ${_pct(playerRow.usagePercentage)} USG'), _DetailLine(label: 'Ratings', value: '${_fmt(playerRow.offensiveRating)} ORtg / ${_fmt(playerRow.defensiveRating)} DRtg / ${_fmt(playerRow.netRating)} Net')], if (teamRow != null) ...[_DetailLine(label: 'Record', value: '${teamRow.wins ?? '—'} / ${teamRow.losses ?? '—'} / ${teamRow.winPercentage?.toStringAsFixed(3) ?? '—'}'), _DetailLine(label: 'Core', value: '${_fmt(teamRow.pointsPerGame)} PPG / ${_fmt(teamRow.opponentPointsPerGame)} Opp PPG / ${_fmt(teamRow.personalFoulsPerGame)} PF'), _DetailLine(label: 'Efficiency', value: '${_pct(teamRow.trueShootingPercentage)} TS / ${_pct(teamRow.effectiveFieldGoalPercentage)} eFG / ${_fmt(teamRow.pace)} Pace'), _DetailLine(label: 'Ratings', value: '${_fmt(teamRow.offensiveRating)} ORtg / ${_fmt(teamRow.defensiveRating)} DRtg / ${_fmt(teamRow.netRating)} Net')]]));
  }
}

class _DependencyPanel extends StatelessWidget {
  const _DependencyPanel({required this.payload, required this.coverage});
  final _StatsPayload payload;
  final _StatsCoverage coverage;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Stats Dependency Map', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columns: const [DataColumn(label: Text('Dependency')), DataColumn(label: Text('Ready')), DataColumn(label: Text('Use'))], rows: [_row('Player profiles', payload.players.length, 'Names and player joins'), _row('Team directory', payload.teams.length, 'Team labels and team joins'), _row('Season directory', payload.seasons.length, 'Season labels'), _row('Player joins', coverage.playerJoins, 'playerId validation'), _row('Team joins', coverage.teamJoins, 'teamId validation'), _row('Source IDs', coverage.rowsWithSource, 'Provenance')])]));
  DataRow _row(String label, int count, String use) => DataRow(cells: [DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.w800))), DataCell(Text('$count')), DataCell(SizedBox(width: 260, child: Text(use)))]);
}

class _ChartPlanningPanel extends StatelessWidget {
  const _ChartPlanningPanel();
  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Future Stat Trend Charts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 10), Text('Once real rows exist, this screen should support finance-style trend charts by player, team, metric, season range, game range, regular season, playoffs, and interval. The chart layer should read from normalized local assets rather than live requests.', style: TextStyle(color: terminalTextSoft, height: 1.45))]));
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))]));
}

class _PlayerStatsTable extends StatelessWidget {
  const _PlayerStatsTable({required this.records, required this.payload, required this.selectedId, required this.family, required this.onSelected});
  final List<PlayerSeasonStat> records;
  final _StatsPayload payload;
  final String? selectedId;
  final String family;
  final ValueChanged<PlayerSeasonStat> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text('Player Season Stats • $family', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), records.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Text('Player season stats source pending. No fake stat rows are displayed.', style: TextStyle(color: terminalTextSoft))) : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: const [DataColumn(label: Text('Player')), DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Type')), DataColumn(label: Text('GP')), DataColumn(label: Text('MPG')), DataColumn(label: Text('PPG')), DataColumn(label: Text('RPG')), DataColumn(label: Text('APG')), DataColumn(label: Text('STL')), DataColumn(label: Text('BLK')), DataColumn(label: Text('TOV')), DataColumn(label: Text('PF')), DataColumn(label: Text('FG%')), DataColumn(label: Text('3P%')), DataColumn(label: Text('FT%')), DataColumn(label: Text('eFG%')), DataColumn(label: Text('TS%')), DataColumn(label: Text('USG%')), DataColumn(label: Text('ORtg')), DataColumn(label: Text('DRtg')), DataColumn(label: Text('Net')), DataColumn(label: Text('Source'))], rows: [for (final row in records) DataRow(selected: selectedId == row.id, onSelectChanged: (_) => onSelected(row), cells: [DataCell(SizedBox(width: 210, child: Text(payload.playersById[row.playerId]?.displayName ?? row.playerId, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(row.teamId == null ? '—' : payload.teamsById[row.teamId!]?.abbreviation ?? row.teamId!)), DataCell(Text(payload.seasonsById[row.seasonId]?.label ?? row.seasonId)), DataCell(Text(row.seasonType ?? '—')), DataCell(Text(row.gamesPlayed?.toString() ?? '—')), DataCell(Text(_fmt(row.minutesPerGame))), DataCell(Text(_fmt(row.pointsPerGame))), DataCell(Text(_fmt(row.reboundsPerGame))), DataCell(Text(_fmt(row.assistsPerGame))), DataCell(Text(_fmt(row.stealsPerGame))), DataCell(Text(_fmt(row.blocksPerGame))), DataCell(Text(_fmt(row.turnoversPerGame))), DataCell(Text(_fmt(row.personalFoulsPerGame))), DataCell(Text(_pct(row.fieldGoalPercentage))), DataCell(Text(_pct(row.threePointPercentage))), DataCell(Text(_pct(row.freeThrowPercentage))), DataCell(Text(_pct(row.effectiveFieldGoalPercentage))), DataCell(Text(_pct(row.trueShootingPercentage))), DataCell(Text(_pct(row.usagePercentage))), DataCell(Text(_fmt(row.offensiveRating))), DataCell(Text(_fmt(row.defensiveRating))), DataCell(Text(_fmt(row.netRating))), DataCell(Text(row.sourceId ?? '—'))])]))]));
}

class _TeamStatsTable extends StatelessWidget {
  const _TeamStatsTable({required this.records, required this.payload, required this.selectedId, required this.family, required this.onSelected});
  final List<TeamSeasonStat> records;
  final _StatsPayload payload;
  final String? selectedId;
  final String family;
  final ValueChanged<TeamSeasonStat> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text('Team Season Stats • $family', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), records.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Text('Team season stats source pending. No fake stat rows are displayed.', style: TextStyle(color: terminalTextSoft))) : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: const [DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Type')), DataColumn(label: Text('W')), DataColumn(label: Text('L')), DataColumn(label: Text('Win %')), DataColumn(label: Text('PPG')), DataColumn(label: Text('Opp PPG')), DataColumn(label: Text('Pace')), DataColumn(label: Text('ORtg')), DataColumn(label: Text('DRtg')), DataColumn(label: Text('Net')), DataColumn(label: Text('PF')), DataColumn(label: Text('FG%')), DataColumn(label: Text('3P%')), DataColumn(label: Text('FT%')), DataColumn(label: Text('eFG%')), DataColumn(label: Text('TS%')), DataColumn(label: Text('REB')), DataColumn(label: Text('AST')), DataColumn(label: Text('STL')), DataColumn(label: Text('BLK')), DataColumn(label: Text('TOV')), DataColumn(label: Text('Source'))], rows: [for (final row in records) DataRow(selected: selectedId == row.id, onSelectChanged: (_) => onSelected(row), cells: [DataCell(SizedBox(width: 190, child: Text(payload.teamsById[row.teamId] == null ? row.teamId : '${payload.teamsById[row.teamId]!.city} ${payload.teamsById[row.teamId]!.name}', style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(payload.seasonsById[row.seasonId]?.label ?? row.seasonId)), DataCell(Text(row.seasonType ?? '—')), DataCell(Text(row.wins?.toString() ?? '—')), DataCell(Text(row.losses?.toString() ?? '—')), DataCell(Text(row.winPercentage?.toStringAsFixed(3) ?? '—')), DataCell(Text(_fmt(row.pointsPerGame))), DataCell(Text(_fmt(row.opponentPointsPerGame))), DataCell(Text(_fmt(row.pace))), DataCell(Text(_fmt(row.offensiveRating))), DataCell(Text(_fmt(row.defensiveRating))), DataCell(Text(_fmt(row.netRating))), DataCell(Text(_fmt(row.personalFoulsPerGame))), DataCell(Text(_pct(row.fieldGoalPercentage))), DataCell(Text(_pct(row.threePointPercentage))), DataCell(Text(_pct(row.freeThrowPercentage))), DataCell(Text(_pct(row.effectiveFieldGoalPercentage))), DataCell(Text(_pct(row.trueShootingPercentage))), DataCell(Text(_fmt(row.reboundsPerGame))), DataCell(Text(_fmt(row.assistsPerGame))), DataCell(Text(_fmt(row.stealsPerGame))), DataCell(Text(_fmt(row.blocksPerGame))), DataCell(Text(_fmt(row.turnoversPerGame))), DataCell(Text(row.sourceId ?? '—'))])]))]));
}

class _MetricSpec {
  const _MetricSpec(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<_MetricSpec> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) { final isWide = constraints.maxWidth > 900; return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [for (final metric in metrics) _Metric(label: metric.label, value: metric.value, detail: metric.detail)]); });
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}

String _fmt(double? value) => value == null ? '—' : value.toStringAsFixed(1);
String _pct(double? value) => value == null ? '—' : value.toStringAsFixed(3);
