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
    return _StatsPayload(
      playerStats: results[0] as List<PlayerSeasonStat>,
      teamStats: results[1] as List<TeamSeasonStat>,
      players: results[2] as List<PlayerProfile>,
      teams: results[3] as List<Team>,
      seasons: results[4] as List<Season>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StatsPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading statistics command workspace...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load statistics command workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

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
          const SectionHeader(title: 'Stats', subtitle: 'Statistics command workspace for player-season and team-season tables, joined names, filters, readiness checks, and strict blank-versus-zero handling.'),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
              _Metric(label: 'Player Stat Rows', value: '${payload.playerStats.length}', detail: payload.playerStats.isEmpty ? 'Source pending' : 'Loaded'),
              _Metric(label: 'Team Stat Rows', value: '${payload.teamStats.length}', detail: payload.teamStats.isEmpty ? 'Source pending' : 'Loaded'),
              _Metric(label: 'Visible Rows', value: '${visiblePlayerRows.length + visibleTeamRows.length}', detail: 'After filters'),
              _Metric(label: 'Join Checks', value: '${coverage.joinedRows}', detail: 'Resolved entity links'),
            ]);
          }),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 350, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search player, team, season, source...'))),
            _FilterDropdown(label: 'Table', value: table, values: const ['All', 'Player season stats', 'Team season stats'], onChanged: (value) => setState(() => table = value)),
            _FilterDropdown(label: 'Season', value: season, values: ['All', ...payload.seasons.map((item) => item.id)], onChanged: (value) => setState(() => season = value)),
            _FilterDropdown(label: 'Min GP', value: minGames, values: const ['All', '1+', '20+', '41+', '65+'], onChanged: (value) => setState(() => minGames = value)),
          ])),
          const SizedBox(height: 22),
          _StatsReadinessPanel(payload: payload, coverage: coverage),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1050;
            final detail = _SelectedStatPanel(detail: selectedDetail);
            final deps = _DependencyPanel(payload: payload, coverage: coverage);
            if (!isWide) return Column(children: [detail, const SizedBox(height: 14), deps]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: detail), const SizedBox(width: 14), Expanded(child: deps)]);
          }),
          const SizedBox(height: 22),
          const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Stat Package Build Order', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text('The NBA MVP should build traditional box score stats first, then team season context, then efficiency metrics, then availability, awards, and development context. This keeps the product useful without mixing core sourced numbers with later derived metrics too early.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
          ])),
          const SizedBox(height: 22),
          if (showPlayers) _PlayerStatsTable(records: visiblePlayerRows, payload: payload, selectedId: selectedPlayerStatId, onSelected: (row) => setState(() { selectedPlayerStatId = row.id; selectedTeamStatId = null; })),
          if (showPlayers && showTeams) const SizedBox(height: 22),
          if (showTeams) _TeamStatsTable(records: visibleTeamRows, payload: payload, selectedId: selectedTeamStatId, onSelected: (row) => setState(() { selectedTeamStatId = row.id; selectedPlayerStatId = null; })),
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
  const _StatsCoverage({required this.playerJoins, required this.playerSeasonJoins, required this.teamJoins, required this.teamSeasonJoins, required this.rowsWithSource, required this.rowsWithAsOf});
  factory _StatsCoverage.fromPayload(_StatsPayload payload) => _StatsCoverage(
        playerJoins: payload.playerStats.where((row) => payload.playersById.containsKey(row.playerId)).length,
        playerSeasonJoins: payload.playerStats.where((row) => payload.seasonsById.containsKey(row.seasonId)).length,
        teamJoins: payload.teamStats.where((row) => payload.teamsById.containsKey(row.teamId)).length,
        teamSeasonJoins: payload.teamStats.where((row) => payload.seasonsById.containsKey(row.seasonId)).length,
        rowsWithSource: [...payload.playerStats.map((row) => row.sourceId), ...payload.teamStats.map((row) => row.sourceId)].whereType<String>().where((value) => value.isNotEmpty).length,
        rowsWithAsOf: [...payload.playerStats.map((row) => row.asOf), ...payload.teamStats.map((row) => row.asOf)].whereType<String>().where((value) => value.isNotEmpty).length,
      );
  final int playerJoins;
  final int playerSeasonJoins;
  final int teamJoins;
  final int teamSeasonJoins;
  final int rowsWithSource;
  final int rowsWithAsOf;
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
  Widget build(BuildContext context) => SizedBox(width: 220, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : 'All', dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _StatsReadinessPanel extends StatelessWidget {
  const _StatsReadinessPanel({required this.payload, required this.coverage});
  final _StatsPayload payload;
  final _StatsCoverage coverage;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Stats MVP Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    const Text('Stats becomes a working core module when player identity, player season stats, team season stats, team joins, season joins, source IDs, and blank-versus-zero display rules are all connected.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 18),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${payload.players.length} players'), InfoPill(label: '${payload.teams.length} teams'), InfoPill(label: '${payload.seasons.length} seasons'), InfoPill(label: '${payload.playerStats.length} player stat rows'), InfoPill(label: '${payload.teamStats.length} team stat rows'), InfoPill(label: '${coverage.rowsWithSource} sourced rows')]),
  ]));
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
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: terminalTextSoft, height: 1.4)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [InfoPill(label: playerRow == null ? 'Team stat' : 'Player stat'), InfoPill(label: (playerRow?.sourceId ?? teamRow?.sourceId) ?? 'Source pending')]),
      const SizedBox(height: 16),
      if (playerRow != null) ...[_DetailLine(label: 'GP / MPG', value: '${playerRow.gamesPlayed?.toString() ?? '—'} / ${playerRow.minutesPerGame?.toStringAsFixed(1) ?? '—'}'), _DetailLine(label: 'PTS / REB / AST', value: '${playerRow.pointsPerGame?.toStringAsFixed(1) ?? '—'} / ${playerRow.reboundsPerGame?.toStringAsFixed(1) ?? '—'} / ${playerRow.assistsPerGame?.toStringAsFixed(1) ?? '—'}'), _DetailLine(label: 'STL / BLK / TOV', value: '${playerRow.stealsPerGame?.toStringAsFixed(1) ?? '—'} / ${playerRow.blocksPerGame?.toStringAsFixed(1) ?? '—'} / ${playerRow.turnoversPerGame?.toStringAsFixed(1) ?? '—'}')],
      if (teamRow != null) ...[_DetailLine(label: 'W / L / Win %', value: '${teamRow.wins?.toString() ?? '—'} / ${teamRow.losses?.toString() ?? '—'} / ${teamRow.winPercentage?.toStringAsFixed(3) ?? '—'}'), _DetailLine(label: 'PPG / Opp PPG', value: '${teamRow.pointsPerGame?.toStringAsFixed(1) ?? '—'} / ${teamRow.opponentPointsPerGame?.toStringAsFixed(1) ?? '—'}'), _DetailLine(label: 'ORtg / DRtg / Net', value: '${teamRow.offensiveRating?.toStringAsFixed(1) ?? '—'} / ${teamRow.defensiveRating?.toStringAsFixed(1) ?? '—'} / ${teamRow.netRating?.toStringAsFixed(1) ?? '—'}')],
    ]));
  }
}

class _DependencyPanel extends StatelessWidget {
  const _DependencyPanel({required this.payload, required this.coverage});
  final _StatsPayload payload;
  final _StatsCoverage coverage;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Stats Dependency Map', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columns: const [DataColumn(label: Text('Dependency')), DataColumn(label: Text('Ready')), DataColumn(label: Text('Use'))], rows: [_row('Player profiles', payload.players.length, 'Names and player joins'), _row('Team directory', payload.teams.length, 'Team labels and team joins'), _row('Season directory', payload.seasons.length, 'Season labels'), _row('Player joins', coverage.playerJoins, 'playerId validation'), _row('Team joins', coverage.teamJoins, 'teamId validation'), _row('Source IDs', coverage.rowsWithSource, 'Provenance')]),
  ]));
  DataRow _row(String label, int count, String use) => DataRow(cells: [DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.w800))), DataCell(Text('$count')), DataCell(SizedBox(width: 260, child: Text(use)))]);
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))]));
}

class _PlayerStatsTable extends StatelessWidget {
  const _PlayerStatsTable({required this.records, required this.payload, required this.selectedId, required this.onSelected});
  final List<PlayerSeasonStat> records;
  final _StatsPayload payload;
  final String? selectedId;
  final ValueChanged<PlayerSeasonStat> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Player Season Stats', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    records.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Text('Player season stats source pending. No fake stat rows are displayed.', style: TextStyle(color: terminalTextSoft))) : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: const [DataColumn(label: Text('Player')), DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Type')), DataColumn(label: Text('GP')), DataColumn(label: Text('MPG')), DataColumn(label: Text('PPG')), DataColumn(label: Text('RPG')), DataColumn(label: Text('APG')), DataColumn(label: Text('STL')), DataColumn(label: Text('BLK')), DataColumn(label: Text('TOV')), DataColumn(label: Text('Source'))], rows: [for (final row in records) DataRow(selected: selectedId == row.id, onSelectChanged: (_) => onSelected(row), cells: [DataCell(SizedBox(width: 210, child: Text(payload.playersById[row.playerId]?.displayName ?? row.playerId, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(row.teamId == null ? '—' : payload.teamsById[row.teamId!]?.abbreviation ?? row.teamId!)), DataCell(Text(payload.seasonsById[row.seasonId]?.label ?? row.seasonId)), DataCell(Text(row.seasonType ?? '—')), DataCell(Text(row.gamesPlayed?.toString() ?? '—')), DataCell(Text(row.minutesPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.pointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.reboundsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.assistsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.stealsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.blocksPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.turnoversPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.sourceId ?? '—'))])])),
  ]));
}

class _TeamStatsTable extends StatelessWidget {
  const _TeamStatsTable({required this.records, required this.payload, required this.selectedId, required this.onSelected});
  final List<TeamSeasonStat> records;
  final _StatsPayload payload;
  final String? selectedId;
  final ValueChanged<TeamSeasonStat> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Team Season Stats', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    records.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Text('Team season stats source pending. No fake stat rows are displayed.', style: TextStyle(color: terminalTextSoft))) : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: const [DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Type')), DataColumn(label: Text('W')), DataColumn(label: Text('L')), DataColumn(label: Text('Win %')), DataColumn(label: Text('PPG')), DataColumn(label: Text('Opp PPG')), DataColumn(label: Text('Pace')), DataColumn(label: Text('ORtg')), DataColumn(label: Text('DRtg')), DataColumn(label: Text('Net')), DataColumn(label: Text('Source'))], rows: [for (final row in records) DataRow(selected: selectedId == row.id, onSelectChanged: (_) => onSelected(row), cells: [DataCell(SizedBox(width: 190, child: Text(payload.teamsById[row.teamId] == null ? row.teamId : '${payload.teamsById[row.teamId]!.city} ${payload.teamsById[row.teamId]!.name}', style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(payload.seasonsById[row.seasonId]?.label ?? row.seasonId)), DataCell(Text(row.seasonType ?? '—')), DataCell(Text(row.wins?.toString() ?? '—')), DataCell(Text(row.losses?.toString() ?? '—')), DataCell(Text(row.winPercentage?.toStringAsFixed(3) ?? '—')), DataCell(Text(row.pointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.opponentPointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.pace?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.offensiveRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.defensiveRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.netRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.sourceId ?? '—'))])])),
  ]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
