import 'package:flutter/material.dart';

import '../models/game_record.dart';
import '../models/playoff_series_record.dart';
import '../models/season.dart';
import '../models/standings_record.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_PostseasonPayload> payloadFuture = _loadPayload();
  String query = '';
  String conference = 'All';
  String season = 'All';
  String? selectedId;

  Future<_PostseasonPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadStandings(),
      repository.loadPlayoffSeries(),
      repository.loadTeams(),
      repository.loadSeasons(),
      repository.loadTeamSeasonStats(),
      repository.loadGames(),
    ]);
    return _PostseasonPayload(
      standings: results[0] as List<StandingsRecord>,
      playoffs: results[1] as List<PlayoffSeriesRecord>,
      teams: results[2] as List<Team>,
      seasons: results[3] as List<Season>,
      teamStats: results[4] as List<TeamSeasonStat>,
      games: results[5] as List<GameRecord>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PostseasonPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading standings command workspace...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load standings workspace.', style: TextStyle(color: terminalTextSoft)));
        }
        final payload = snapshot.data ?? const _PostseasonPayload.empty();
        final seasons = ['All', ...payload.seasons.map((item) => item.id)];
        final rows = payload.standings.where((row) {
          final q = query.trim().toLowerCase();
          final team = payload.teamsById[row.teamId];
          final seasonLabel = payload.seasonsById[row.seasonId]?.label;
          final searchable = [row.teamId, team?.name, team?.city, team?.abbreviation, row.seasonId, seasonLabel, row.conference, row.division, row.sourceId].whereType<String>().join(' ').toLowerCase();
          return (conference == 'All' || row.conference == conference) && (season == 'All' || row.seasonId == season) && (q.isEmpty || searchable.contains(q));
        }).toList();
        final selected = _selectedRow(rows, payload.standings);
        final readiness = _PostseasonReadiness.fromPayload(payload);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Standings', subtitle: 'Standings command workspace for records, seeds, team joins, season joins, playoff links, source status, and report-ready team-season context.'),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Standings Rows', '${payload.standings.length}', payload.standings.isEmpty ? 'Source pending' : 'Connected'),
            _MetricSpec('Visible Rows', '${rows.length}', 'Current filters'),
            _MetricSpec('Team Joins', '${readiness.standingTeamJoins}', 'Resolved team IDs'),
            _MetricSpec('Season Joins', '${readiness.standingSeasonJoins}', 'Resolved seasons'),
          ]),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search team, season, conference, source...'))),
            _FilterDropdown(label: 'Conference', value: conference, values: const ['All', 'East', 'West'], onChanged: (value) => setState(() => conference = value)),
            _FilterDropdown(label: 'Season', value: season, values: seasons, onChanged: (value) => setState(() => season = value)),
          ])),
          const SizedBox(height: 22),
          _ReadinessPanel(title: 'NBA MVP Standings Readiness', payload: payload, readiness: readiness),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final detail = _StandingDetailPanel(record: selected, payload: payload);
            final matrix = _PostseasonMatrix(payload: payload, readiness: readiness);
            if (constraints.maxWidth < 1050) return Column(children: [detail, const SizedBox(height: 14), matrix]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: detail), const SizedBox(width: 14), Expanded(child: matrix)]);
          }),
          const SizedBox(height: 22),
          const _BuildOrderPanel(title: 'Standings Build Order', body: 'First, import historical standings with teamId, seasonId, conference, seed, wins, losses, and win percentage. Second, attach team-season stats. Third, connect playoff qualification and series outcomes. Later, connect games, reports, compare workflows, and data-health alerts.'),
          const SizedBox(height: 22),
          rows.isEmpty ? const _EmptyPanel(title: 'Standings Source Pending', body: 'The standings asset is connected but empty or filtered out. No fake records are shown.') : _StandingsTable(records: rows, payload: payload, selectedId: selected?.id, onSelected: (row) => setState(() => selectedId = row.id)),
        ]);
      },
    );
  }

  StandingsRecord? _selectedRow(List<StandingsRecord> rows, List<StandingsRecord> all) {
    for (final row in rows) {
      if (row.id == selectedId) return row;
    }
    if (rows.isNotEmpty) return rows.first;
    return all.isEmpty ? null : all.first;
  }
}

class PlayoffsScreen extends StatefulWidget {
  const PlayoffsScreen({super.key});

  @override
  State<PlayoffsScreen> createState() => _PlayoffsScreenState();
}

class _PlayoffsScreenState extends State<PlayoffsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_PostseasonPayload> payloadFuture = _loadPayload();
  String query = '';
  String round = 'All';
  String season = 'All';
  String? selectedId;

  Future<_PostseasonPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadStandings(),
      repository.loadPlayoffSeries(),
      repository.loadTeams(),
      repository.loadSeasons(),
      repository.loadTeamSeasonStats(),
      repository.loadGames(),
    ]);
    return _PostseasonPayload(
      standings: results[0] as List<StandingsRecord>,
      playoffs: results[1] as List<PlayoffSeriesRecord>,
      teams: results[2] as List<Team>,
      seasons: results[3] as List<Season>,
      teamStats: results[4] as List<TeamSeasonStat>,
      games: results[5] as List<GameRecord>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PostseasonPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading playoff command workspace...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load playoff workspace.', style: const TextStyle(color: terminalTextSoft)));
        }
        final payload = snapshot.data ?? const _PostseasonPayload.empty();
        final rounds = ['All', ...payload.playoffs.map((item) => item.round ?? 'Unknown').toSet().toList()..sort()];
        final seasons = ['All', ...payload.seasons.map((item) => item.id)];
        final rows = payload.playoffs.where((row) {
          final q = query.trim().toLowerCase();
          final winner = row.winningTeamId == null ? null : payload.teamsById[row.winningTeamId!];
          final loser = row.losingTeamId == null ? null : payload.teamsById[row.losingTeamId!];
          final seasonLabel = payload.seasonsById[row.seasonId]?.label;
          final searchable = [row.seriesName, row.round, row.seasonId, seasonLabel, row.winningTeamId, winner?.name, winner?.abbreviation, row.losingTeamId, loser?.name, loser?.abbreviation, row.sourceId].whereType<String>().join(' ').toLowerCase();
          return (round == 'All' || (row.round ?? 'Unknown') == round) && (season == 'All' || row.seasonId == season) && (q.isEmpty || searchable.contains(q));
        }).toList();
        final selected = _selectedRow(rows, payload.playoffs);
        final readiness = _PostseasonReadiness.fromPayload(payload);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Playoffs', subtitle: 'Playoff command workspace for series, rounds, seeds, winners, losers, standings context, games, team joins, and postseason report hooks.'),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Series Rows', '${payload.playoffs.length}', payload.playoffs.isEmpty ? 'Source pending' : 'Connected'),
            _MetricSpec('Visible Rows', '${rows.length}', 'Current filters'),
            _MetricSpec('Team Joins', '${readiness.playoffTeamJoins}', 'Winner/loser IDs'),
            _MetricSpec('Season Joins', '${readiness.playoffSeasonJoins}', 'Resolved seasons'),
          ]),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search series, round, season, team...'))),
            _FilterDropdown(label: 'Round', value: round, values: rounds, onChanged: (value) => setState(() => round = value)),
            _FilterDropdown(label: 'Season', value: season, values: seasons, onChanged: (value) => setState(() => season = value)),
          ])),
          const SizedBox(height: 22),
          _ReadinessPanel(title: 'NBA MVP Playoff Readiness', payload: payload, readiness: readiness),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final detail = _PlayoffDetailPanel(record: selected, payload: payload);
            final matrix = _PostseasonMatrix(payload: payload, readiness: readiness);
            if (constraints.maxWidth < 1050) return Column(children: [detail, const SizedBox(height: 14), matrix]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: detail), const SizedBox(width: 14), Expanded(child: matrix)]);
          }),
          const SizedBox(height: 22),
          const _BuildOrderPanel(title: 'Playoffs Build Order', body: 'First, import series-level playoff records because they are compact and immediately useful. Second, validate seeds against standings. Third, attach game-level results. Later, add bracket views, team paths, generated reports, and comparison workflows.'),
          const SizedBox(height: 22),
          rows.isEmpty ? const _EmptyPanel(title: 'Playoff Series Source Pending', body: 'The playoff series asset is connected but empty or filtered out. No fake records are shown.') : _PlayoffTable(records: rows, payload: payload, selectedId: selected?.id, onSelected: (row) => setState(() => selectedId = row.id)),
        ]);
      },
    );
  }

  PlayoffSeriesRecord? _selectedRow(List<PlayoffSeriesRecord> rows, List<PlayoffSeriesRecord> all) {
    for (final row in rows) {
      if (row.id == selectedId) return row;
    }
    if (rows.isNotEmpty) return rows.first;
    return all.isEmpty ? null : all.first;
  }
}

class _PostseasonPayload {
  const _PostseasonPayload({required this.standings, required this.playoffs, required this.teams, required this.seasons, required this.teamStats, required this.games});
  const _PostseasonPayload.empty() : standings = const [], playoffs = const [], teams = const [], seasons = const [], teamStats = const [], games = const [];
  final List<StandingsRecord> standings;
  final List<PlayoffSeriesRecord> playoffs;
  final List<Team> teams;
  final List<Season> seasons;
  final List<TeamSeasonStat> teamStats;
  final List<GameRecord> games;
  Map<String, Team> get teamsById => {for (final team in teams) team.id: team};
  Map<String, Season> get seasonsById => {for (final season in seasons) season.id: season};
}

class _PostseasonReadiness {
  const _PostseasonReadiness({required this.standingTeamJoins, required this.standingSeasonJoins, required this.playoffTeamJoins, required this.playoffSeasonJoins, required this.sourcedStandings, required this.sourcedPlayoffs});
  factory _PostseasonReadiness.fromPayload(_PostseasonPayload payload) => _PostseasonReadiness(
        standingTeamJoins: payload.standings.where((row) => payload.teamsById.containsKey(row.teamId)).length,
        standingSeasonJoins: payload.standings.where((row) => payload.seasonsById.containsKey(row.seasonId)).length,
        playoffTeamJoins: payload.playoffs.where((row) => (row.winningTeamId == null || payload.teamsById.containsKey(row.winningTeamId)) && (row.losingTeamId == null || payload.teamsById.containsKey(row.losingTeamId))).length,
        playoffSeasonJoins: payload.playoffs.where((row) => payload.seasonsById.containsKey(row.seasonId)).length,
        sourcedStandings: payload.standings.where((row) => (row.sourceId ?? '').isNotEmpty).length,
        sourcedPlayoffs: payload.playoffs.where((row) => (row.sourceId ?? '').isNotEmpty).length,
      );
  final int standingTeamJoins;
  final int standingSeasonJoins;
  final int playoffTeamJoins;
  final int playoffSeasonJoins;
  final int sourcedStandings;
  final int sourcedPlayoffs;
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(width: 230, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
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
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [for (final metric in metrics) _Metric(label: metric.label, value: metric.value, detail: metric.detail)]);
      });
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.title, required this.payload, required this.readiness});
  final String title;
  final _PostseasonPayload payload;
  final _PostseasonReadiness readiness;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('The postseason layer is an MVP bridge between Teams, Seasons, Stats, Compare, and Reports. It becomes valuable when standings and playoff rows join cleanly to teams, seasons, team stats, games, and source metadata.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${payload.standings.length} standings'), InfoPill(label: '${payload.playoffs.length} playoff series'), InfoPill(label: '${payload.teamStats.length} team stats'), InfoPill(label: '${payload.teams.length} teams'), InfoPill(label: '${payload.seasons.length} seasons'), InfoPill(label: '${payload.games.length} games')]),
      ]));
}

class _StandingDetailPanel extends StatelessWidget {
  const _StandingDetailPanel({required this.record, required this.payload});
  final StandingsRecord? record;
  final _PostseasonPayload payload;
  @override
  Widget build(BuildContext context) {
    if (record == null) return const TerminalCard(child: Text('Select a standings row to inspect record, seed, team, season, playoff, game, and source context.', style: TextStyle(color: terminalTextSoft, height: 1.45)));
    final teamStats = payload.teamStats.where((row) => row.teamId == record!.teamId && row.seasonId == record!.seasonId).length;
    final playoffRows = payload.playoffs.where((row) => row.seasonId == record!.seasonId && (row.winningTeamId == record!.teamId || row.losingTeamId == record!.teamId)).length;
    final gameRows = payload.games.where((row) => row.seasonId == record!.seasonId && (row.homeTeamId == record!.teamId || row.awayTeamId == record!.teamId)).length;
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(_teamName(payload, record!.teamId), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))), InfoPill(label: record!.conference ?? 'Conference pending')]),
      const SizedBox(height: 8),
      Text('${payload.seasonsById[record!.seasonId]?.label ?? record!.seasonId} • ${record!.division ?? 'Division pending'} • Seed ${record!.seed?.toString() ?? '—'}', style: const TextStyle(color: terminalTextSoft, height: 1.4)),
      const SizedBox(height: 16),
      _DetailLine(label: 'W / L / Win %', value: '${record!.wins ?? '—'} / ${record!.losses ?? '—'} / ${record!.winPercentage?.toStringAsFixed(3) ?? '—'}'),
      _DetailLine(label: 'Games Back', value: record!.gamesBack?.toStringAsFixed(1) ?? '—'),
      _DetailLine(label: 'Source', value: record!.sourceId ?? 'Source pending'),
      _DetailLine(label: 'asOf', value: record!.asOf ?? '—'),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [InfoPill(label: '$teamStats team stat rows'), InfoPill(label: '$playoffRows playoff rows'), InfoPill(label: '$gameRows games')]),
    ]));
  }
}

class _PlayoffDetailPanel extends StatelessWidget {
  const _PlayoffDetailPanel({required this.record, required this.payload});
  final PlayoffSeriesRecord? record;
  final _PostseasonPayload payload;
  @override
  Widget build(BuildContext context) {
    if (record == null) return const TerminalCard(child: Text('Select a playoff series to inspect round, matchup, result, seeds, standings links, game links, and source context.', style: TextStyle(color: terminalTextSoft, height: 1.45)));
    final relatedGames = payload.games.where((game) => game.seasonId == record!.seasonId && (game.homeTeamId == record!.winningTeamId || game.awayTeamId == record!.winningTeamId || game.homeTeamId == record!.losingTeamId || game.awayTeamId == record!.losingTeamId)).length;
    final standingsLinks = payload.standings.where((row) => row.seasonId == record!.seasonId && (row.teamId == record!.winningTeamId || row.teamId == record!.losingTeamId)).length;
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(record!.seriesName ?? 'Series name pending', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))), InfoPill(label: record!.round ?? 'Round pending')]),
      const SizedBox(height: 8),
      Text('${payload.seasonsById[record!.seasonId]?.label ?? record!.seasonId} • ${_teamName(payload, record!.winningTeamId)} over ${_teamName(payload, record!.losingTeamId)}', style: const TextStyle(color: terminalTextSoft, height: 1.4)),
      const SizedBox(height: 16),
      _DetailLine(label: 'Result', value: '${record!.winnerWins ?? '—'}-${record!.loserWins ?? '—'} across ${record!.gamesPlayed ?? '—'} games'),
      _DetailLine(label: 'Seeds', value: '${record!.winningSeed ?? '—'} / ${record!.losingSeed ?? '—'}'),
      _DetailLine(label: 'Source', value: record!.sourceId ?? 'Source pending'),
      _DetailLine(label: 'asOf', value: record!.asOf ?? '—'),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [InfoPill(label: '$standingsLinks standings links'), InfoPill(label: '$relatedGames related games')]),
    ]));
  }
}

class _PostseasonMatrix extends StatelessWidget {
  const _PostseasonMatrix({required this.payload, required this.readiness});
  final _PostseasonPayload payload;
  final _PostseasonReadiness readiness;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('Postseason Input Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 24, columns: const [DataColumn(label: Text('Layer')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Status')), DataColumn(label: Text('Use'))], rows: [
          _row('Standings', payload.standings.length, 'Seed and record context'),
          _row('Playoff series', payload.playoffs.length, 'Postseason paths'),
          _row('Team directory', payload.teams.length, 'Team joins'),
          _row('Season catalog', payload.seasons.length, 'Season joins'),
          _row('Team stats', payload.teamStats.length, 'Performance context'),
          _row('Games', payload.games.length, 'Schedule and series detail'),
          _row('Standings sources', readiness.sourcedStandings, 'Source metadata'),
          _row('Playoff sources', readiness.sourcedPlayoffs, 'Source metadata'),
        ])),
      ]));
  DataRow _row(String layer, int count, String use) => DataRow(cells: [DataCell(SizedBox(width: 180, child: Text(layer, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text('$count')), DataCell(InfoPill(label: count == 0 ? 'Source pending' : 'Connected')), DataCell(SizedBox(width: 360, child: Text(use)))]);
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.records, required this.payload, required this.selectedId, required this.onSelected});
  final List<StandingsRecord> records;
  final _PostseasonPayload payload;
  final String? selectedId;
  final ValueChanged<StandingsRecord> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: const [DataColumn(label: Text('Seed')), DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Conf.')), DataColumn(label: Text('Division')), DataColumn(label: Text('W')), DataColumn(label: Text('L')), DataColumn(label: Text('Win %')), DataColumn(label: Text('GB')), DataColumn(label: Text('Source')), DataColumn(label: Text('asOf'))], rows: [for (final record in records) DataRow(selected: selectedId == record.id, onSelectChanged: (_) => onSelected(record), cells: [DataCell(Text(record.seed?.toString() ?? '—')), DataCell(SizedBox(width: 190, child: Text(_teamName(payload, record.teamId), style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(payload.seasonsById[record.seasonId]?.label ?? record.seasonId)), DataCell(Text(record.conference ?? '—')), DataCell(Text(record.division ?? '—')), DataCell(Text(record.wins?.toString() ?? '—')), DataCell(Text(record.losses?.toString() ?? '—')), DataCell(Text(record.winPercentage?.toStringAsFixed(3) ?? '—')), DataCell(Text(record.gamesBack?.toStringAsFixed(1) ?? '—')), DataCell(Text(record.sourceId ?? '—')), DataCell(Text(record.asOf ?? '—'))])])));
}

class _PlayoffTable extends StatelessWidget {
  const _PlayoffTable({required this.records, required this.payload, required this.selectedId, required this.onSelected});
  final List<PlayoffSeriesRecord> records;
  final _PostseasonPayload payload;
  final String? selectedId;
  final ValueChanged<PlayoffSeriesRecord> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: const [DataColumn(label: Text('Season')), DataColumn(label: Text('Round')), DataColumn(label: Text('Series')), DataColumn(label: Text('Winner')), DataColumn(label: Text('Loser')), DataColumn(label: Text('Seeds')), DataColumn(label: Text('Games')), DataColumn(label: Text('Result')), DataColumn(label: Text('Source')), DataColumn(label: Text('asOf'))], rows: [for (final record in records) DataRow(selected: selectedId == record.id, onSelectChanged: (_) => onSelected(record), cells: [DataCell(Text(payload.seasonsById[record.seasonId]?.label ?? record.seasonId)), DataCell(Text(record.round ?? '—')), DataCell(SizedBox(width: 220, child: Text(record.seriesName ?? '—', style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(_teamName(payload, record.winningTeamId)))), DataCell(SizedBox(width: 180, child: Text(_teamName(payload, record.losingTeamId)))), DataCell(Text('${record.winningSeed ?? '—'} / ${record.losingSeed ?? '—'}')), DataCell(Text(record.gamesPlayed?.toString() ?? '—')), DataCell(Text('${record.winnerWins ?? '—'}-${record.loserWins ?? '—'}')), DataCell(Text(record.sourceId ?? '—')), DataCell(Text(record.asOf ?? '—'))])])));
}

class _BuildOrderPanel extends StatelessWidget {
  const _BuildOrderPanel({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(body, style: const TextStyle(color: terminalTextSoft, height: 1.45))]));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(body, style: const TextStyle(color: terminalTextSoft, height: 1.45))]));
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}

String _teamName(_PostseasonPayload payload, String? teamId) {
  if (teamId == null) return '—';
  final team = payload.teamsById[teamId];
  return team == null ? teamId : '${team.city} ${team.name}';
}
