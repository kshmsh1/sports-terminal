import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../widgets/terminal_primitives.dart';

class Nba2025MatchupsScreen extends StatefulWidget {
  const Nba2025MatchupsScreen({super.key});

  @override
  State<Nba2025MatchupsScreen> createState() => _Nba2025MatchupsScreenState();
}

class _Nba2025MatchupsScreenState extends State<Nba2025MatchupsScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      future: snapshotFuture,
      builder: (data) {
        final matchups = _buildMatchups(data.games);
        final visible = _filterMatchups(matchups, query);
        final totalGames = visible.fold<int>(0, (sum, row) => sum + row.games);
        final closest = visible.isEmpty ? null : [...visible]..sort((a, b) => a.averageMargin.compareTo(b.averageMargin));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Matchups',
            subtitle: 'Head-to-head matchup terminal generated from all loaded 2024-25 game rows. Search a team code to isolate every opponent pairing.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Matchups', '${matchups.length}', 'Unique team pairings'),
            _MetricSpec('Visible Matchups', '${visible.length}', query.trim().isEmpty ? 'Unfiltered' : 'Query filtered'),
            _MetricSpec('Visible Games', '$totalGames', 'Games in visible pairings'),
            _MetricSpec('Closest Pairing', closest == null ? '—' : '${closest.first.teamA}-${closest.first.teamB}', closest == null ? 'No rows' : '${closest.first.averageMargin.toStringAsFixed(1)} avg margin'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(onChanged: (value) => setState(() => query = value), hint: 'Search team code or matchup, e.g. OKC, BOS, NYK-LAL...'),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Head-to-Head Matchup Table',
            subtitle: 'Aggregated from generated games.json. Team A/B are alphabetical within each pairing, not home/away labels.',
            columns: const ['Team A', 'Team B', 'Games', 'A Wins', 'B Wins', 'A PPG', 'B PPG', 'Avg Margin', 'Last Game', 'Last Winner'],
            rows: [
              for (final row in visible.take(120))
                [
                  row.teamA,
                  row.teamB,
                  '${row.games}',
                  '${row.winsA}',
                  '${row.winsB}',
                  row.ppgA.toStringAsFixed(1),
                  row.ppgB.toStringAsFixed(1),
                  row.averageMargin.toStringAsFixed(1),
                  row.lastGameId,
                  row.lastWinner,
                ],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025GameDetailScreen extends StatefulWidget {
  const Nba2025GameDetailScreen({super.key});

  @override
  State<Nba2025GameDetailScreen> createState() => _Nba2025GameDetailScreenState();
}

class _Nba2025GameDetailScreenState extends State<Nba2025GameDetailScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      future: snapshotFuture,
      builder: (data) {
        final games = _filter(data.games, query, const ['game_id', 'game_date', 'away_team_id', 'home_team_id', 'winner_team_id']);
        final game = games.isEmpty ? (data.games.isEmpty ? null : data.games.first) : games.first;
        final gameId = _text(game?['game_id']);
        final teamRows = data.teamGameLogs.where((row) => _text(row['game_id']) == gameId).toList();
        final playerRows = data.playerGameLogsTop.where((row) => _text(row['game_id']) == gameId).toList();
        final margin = game == null ? 0 : (_num(game['home_score']) - _num(game['away_score'])).abs();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Game Detail',
            subtitle: 'Single-game command page generated from game rows, team-game logs, and available player-game logs. Search a game ID or team to switch context.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Selected Game', gameId, _text(game?['game_date'])),
            _MetricSpec('Score', game == null ? '—' : '${_text(game['away_team_id'])} ${_text(game['away_score'])} • ${_text(game['home_team_id'])} ${_text(game['home_score'])}', 'Winner: ${_text(game?['winner_team_id'])}'),
            _MetricSpec('Margin', margin.round().toString(), 'Absolute score differential'),
            _MetricSpec('Player Log Rows', '${playerRows.length}', 'From high-value game-log seed'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(onChanged: (value) => setState(() => query = value), hint: 'Search game id, date, team, winner...'),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Matching Games',
            subtitle: 'Search result set. The first row is used as the selected game above.',
            columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Winner', 'Source'],
            rows: [
              for (final row in games.take(40))
                [_text(row['game_date']), _text(row['game_id']), _text(row['away_team_id']), _text(row['away_score']), _text(row['home_team_id']), _text(row['home_score']), _text(row['winner_team_id']), _shortText(row['page_url'], 50)],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Selected Game Team Logs',
            subtitle: 'One row per team in the selected game, including quarter scoring and result.',
            columns: const ['Team', 'Opp', 'H/A', 'Result', 'PTS', 'Opp PTS', 'Margin', 'Q1', 'Q2', 'Q3', 'Q4'],
            rows: [
              for (final row in teamRows)
                [_text(row['team_id']), _text(row['opponent_team_id']), _isOne(row['is_home']) ? 'Home' : 'Away', _text(row['result']), _text(row['points']), _text(row['opponent_points']), _text(row['margin']), _text(row['q1']), _text(row['q2']), _text(row['q3']), _text(row['q4'])],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Selected Game Player Logs',
            subtitle: 'Rows appear when the selected game is represented in the compact high-value player-game seed.',
            columns: const ['Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', 'STL', 'BLK', '+/-', 'TS%', 'BPM'],
            rows: [
              for (final row in playerRows)
                [_text(row['player_label']), _text(row['team_id']), _text(row['opponent_team_id']), _text(row['mp_text']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['stl'], decimals: 0), _decimal(row['blk'], decimals: 0), _decimal(row['plus_minus'], decimals: 0), _decimal(row['ts_pct'], decimals: 3), _decimal(row['bpm'])],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025PlayerDetailScreen extends StatefulWidget {
  const Nba2025PlayerDetailScreen({super.key});

  @override
  State<Nba2025PlayerDetailScreen> createState() => _Nba2025PlayerDetailScreenState();
}

class _Nba2025PlayerDetailScreenState extends State<Nba2025PlayerDetailScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String query = 'Shai';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      future: snapshotFuture,
      builder: (data) {
        final matches = _filter(data.playerSeasonTotals, query, const ['player_label', 'player_id', 'team_ids']);
        final player = matches.isEmpty ? (data.playerSeasonTotals.isEmpty ? null : data.playerSeasonTotals.first) : matches.first;
        final playerId = _text(player?['player_id']);
        final playerName = _text(player?['player_label']);
        final gameLogs = data.playerGameLogsTop.where((row) => _text(row['player_id']) == playerId || _text(row['player_label']) == playerName).toList();
        final highs = <Map<String, dynamic>>[];
        for (final entry in data.playerGameHighs.entries) {
          for (final row in _asMapList(entry.value)) {
            if (_text(row['player_id']) == playerId || _text(row['player_label']) == playerName) {
              highs.add({'board': entry.key, ...row});
            }
          }
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Player Detail',
            subtitle: 'Single-player command page generated from active player summaries, leaderboard rows, and high-value game-log rows.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Selected Player', playerName, playerId),
            _MetricSpec('Teams', _text(player?['team_ids']), 'Loaded-season team IDs'),
            _MetricSpec('Production', '${_decimal(player?['points'], decimals: 0)} pts', '${_decimal(player?['rebounds'], decimals: 0)} reb / ${_decimal(player?['assists'], decimals: 0)} ast'),
            _MetricSpec('Rates', '${_decimal(player?['points_per_game'])} PPG', '${_decimal(player?['avg_ts_pct'], decimals: 3)} TS / ${_decimal(player?['avg_bpm'])} BPM'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(onChanged: (value) => setState(() => query = value), hint: 'Search player name, id, or team...'),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Matching Players',
            subtitle: 'Search results. The first row is used as the selected player above.',
            columns: const ['Player', 'Teams', 'GP', 'MIN', 'MPG', 'PTS', 'PPG', 'REB', 'AST', 'TS%', 'BPM'],
            rows: [
              for (final row in matches.take(40))
                [_text(row['player_label']), _text(row['team_ids']), _text(row['games']), _decimal(row['minutes'], decimals: 1), _decimal(row['minutes_per_game'], decimals: 1), _decimal(row['points'], decimals: 0), _decimal(row['points_per_game']), _decimal(row['rebounds'], decimals: 0), _decimal(row['assists'], decimals: 0), _decimal(row['avg_ts_pct'], decimals: 3), _decimal(row['avg_bpm'])],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Selected Player Top Game Logs',
            subtitle: 'Compact game-log rows for the selected player when present in player_game_logs_top.json.',
            columns: const ['Date', 'Game', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', 'STL', 'BLK', '+/-', 'TS%', 'BPM'],
            rows: [
              for (final row in gameLogs.take(80))
                [_text(row['game_date']), _text(row['game_id']), _text(row['team_id']), _text(row['opponent_team_id']), _text(row['mp_text']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['stl'], decimals: 0), _decimal(row['blk'], decimals: 0), _decimal(row['plus_minus'], decimals: 0), _decimal(row['ts_pct'], decimals: 3), _decimal(row['bpm'])],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Selected Player Single-Game High Board Appearances',
            subtitle: 'Where the selected player appears across generated game-high leaderboards.',
            columns: const ['Board', 'Date', 'Game', 'Team', 'Opp', 'PTS', 'REB', 'AST', 'STL', 'BLK', '+/-'],
            rows: [
              for (final row in highs.take(80))
                [_text(row['board']), _text(row['game_date']), _text(row['game_id']), _text(row['team_id']), _text(row['opponent_team_id']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['stl'], decimals: 0), _decimal(row['blk'], decimals: 0), _decimal(row['plus_minus'], decimals: 0)],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025TeamDetailScreen extends StatefulWidget {
  const Nba2025TeamDetailScreen({super.key});

  @override
  State<Nba2025TeamDetailScreen> createState() => _Nba2025TeamDetailScreenState();
}

class _Nba2025TeamDetailScreenState extends State<Nba2025TeamDetailScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String query = 'OKC';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      future: snapshotFuture,
      builder: (data) {
        final records = _filter(data.teamRecords, query, const ['team_id']);
        final record = records.isEmpty ? (data.teamRecords.isEmpty ? null : data.teamRecords.first) : records.first;
        final teamId = _text(record?['team_id']);
        final logs = data.teamGameLogs.where((row) => _text(row['team_id']) == teamId).toList();
        final players = data.playerSeasonTotals.where((row) => _text(row['team_ids']).split(',').map((item) => item.trim()).contains(teamId)).toList();
        final wins = _num(record?['wins']);
        final losses = _num(record?['losses']);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Team Detail',
            subtitle: 'Single-team command page generated from team records, team-game logs, and player loaded-season summaries.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Selected Team', teamId, 'First matching team record'),
            _MetricSpec('Record', '${wins.round()}-${losses.round()}', '${_text(record?['games'])} loaded games'),
            _MetricSpec('Net Rating Proxy', _decimal(record?['average_margin']), 'Average point margin'),
            _MetricSpec('Player Summaries', '${players.length}', 'Players attached by team_ids'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(onChanged: (value) => setState(() => query = value), hint: 'Search team code, e.g. OKC, BOS, NYK...'),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Matching Team Records',
            subtitle: 'Search results. The first row is used as the selected team above.',
            columns: const ['Team', 'Games', 'W', 'L', 'Home', 'Away', 'PPG', 'Opp PPG', 'Margin'],
            rows: [
              for (final row in records)
                [_text(row['team_id']), _text(row['games']), _text(row['wins']), _text(row['losses']), _text(row['home_games']), _text(row['away_games']), _decimal(row['points_per_game']), _decimal(row['opponent_points_per_game']), _decimal(row['average_margin'])],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Selected Team Player Summaries',
            subtitle: 'Players whose loaded-season team_ids include the selected team.',
            columns: const ['Player', 'Teams', 'GP', 'MPG', 'PTS', 'PPG', 'REB', 'AST', 'TS%', 'BPM'],
            rows: [
              for (final row in players.take(80))
                [_text(row['player_label']), _text(row['team_ids']), _text(row['games']), _decimal(row['minutes_per_game'], decimals: 1), _decimal(row['points'], decimals: 0), _decimal(row['points_per_game']), _decimal(row['rebounds'], decimals: 0), _decimal(row['assists'], decimals: 0), _decimal(row['avg_ts_pct'], decimals: 3), _decimal(row['avg_bpm'])],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Selected Team Game Logs',
            subtitle: 'All team-game rows for the selected team.',
            columns: const ['Date', 'Game', 'Opp', 'H/A', 'Result', 'PTS', 'Opp PTS', 'Margin', 'Q1', 'Q2', 'Q3', 'Q4'],
            rows: [
              for (final row in logs.take(100))
                [_text(row['game_date']), _text(row['game_id']), _text(row['opponent_team_id']), _isOne(row['is_home']) ? 'Home' : 'Away', _text(row['result']), _text(row['points']), _text(row['opponent_points']), _text(row['margin']), _text(row['q1']), _text(row['q2']), _text(row['q3']), _text(row['q4'])],
            ],
          ),
        ]);
      },
    );
  }
}

class _SeedFuture extends StatelessWidget {
  const _SeedFuture({required this.future, required this.builder});

  final Future<NbaTerminalSeedSnapshot> future;
  final Widget Function(NbaTerminalSeedSnapshot data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading generated NBA terminal assets...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Generated NBA seed assets are not available yet.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('${snapshot.error}', style: const TextStyle(color: terminalTextSoft, height: 1.4)),
              const SizedBox(height: 14),
              const Text('Run tools/run_nba_terminal_data_pipeline.py --season 2025 to rebuild, validate, and sync the JSON assets.', style: TextStyle(color: terminalAccent)),
            ]),
          );
        }
        return builder(snapshot.data!);
      },
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onChanged, required this.hint});

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        cursorColor: terminalAccent,
        decoration: _inputDecoration(hint),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricSpec> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900;
      return GridView.count(
        crossAxisCount: wide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: wide ? 1.9 : 1.35,
        children: [for (final metric in metrics) _MetricCard(label: metric.label, value: metric.value, detail: metric.detail)],
      );
    });
  }
}

class _MetricSpec {
  const _MetricSpec(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
        Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12), overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.title, required this.subtitle, required this.columns, required this.rows});

  final String title;
  final String subtitle;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: terminalTextMuted)),
              ]),
            ),
            const SizedBox(width: 12),
            InfoPill(label: '${rows.length} rows'),
          ]),
        ),
        const Divider(height: 1, color: terminalBorder),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.all(18), child: Text('No rows match the current context.', style: TextStyle(color: terminalTextSoft)))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columnSpacing: 28,
              columns: [for (final column in columns) DataColumn(label: Text(column))],
              rows: [
                for (final row in rows)
                  DataRow(cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 32 ? 280 : 110, child: Text(cell, overflow: TextOverflow.ellipsis)))]),
              ],
            ),
          ),
      ]),
    );
  }
}

class _MatchupRow {
  const _MatchupRow({
    required this.teamA,
    required this.teamB,
    required this.games,
    required this.winsA,
    required this.winsB,
    required this.pointsA,
    required this.pointsB,
    required this.lastGameId,
    required this.lastWinner,
  });

  final String teamA;
  final String teamB;
  final int games;
  final int winsA;
  final int winsB;
  final double pointsA;
  final double pointsB;
  final String lastGameId;
  final String lastWinner;

  double get ppgA => games == 0 ? 0 : pointsA / games;
  double get ppgB => games == 0 ? 0 : pointsB / games;
  double get averageMargin => games == 0 ? 0 : (pointsA - pointsB).abs() / games;
}

class _MutableMatchup {
  _MutableMatchup(this.teamA, this.teamB);
  final String teamA;
  final String teamB;
  int games = 0;
  int winsA = 0;
  int winsB = 0;
  double pointsA = 0;
  double pointsB = 0;
  String lastGameId = '—';
  String lastWinner = '—';

  _MatchupRow freeze() => _MatchupRow(teamA: teamA, teamB: teamB, games: games, winsA: winsA, winsB: winsB, pointsA: pointsA, pointsB: pointsB, lastGameId: lastGameId, lastWinner: lastWinner);
}

List<_MatchupRow> _buildMatchups(List<Map<String, dynamic>> games) {
  final builders = <String, _MutableMatchup>{};
  for (final game in games) {
    final away = _text(game['away_team_id']);
    final home = _text(game['home_team_id']);
    if (away == '—' || home == '—') continue;
    final ordered = [away, home]..sort();
    final teamA = ordered[0];
    final teamB = ordered[1];
    final key = '$teamA|$teamB';
    final row = builders.putIfAbsent(key, () => _MutableMatchup(teamA, teamB));
    final awayScore = _num(game['away_score']);
    final homeScore = _num(game['home_score']);
    final scoreA = away == teamA ? awayScore : homeScore;
    final scoreB = away == teamB ? awayScore : homeScore;
    row.games += 1;
    row.pointsA += scoreA;
    row.pointsB += scoreB;
    if (_text(game['winner_team_id']) == teamA) row.winsA += 1;
    if (_text(game['winner_team_id']) == teamB) row.winsB += 1;
    row.lastGameId = _text(game['game_id']);
    row.lastWinner = _text(game['winner_team_id']);
  }
  final rows = [for (final item in builders.values) item.freeze()];
  rows.sort((a, b) {
    final gameCompare = b.games.compareTo(a.games);
    if (gameCompare != 0) return gameCompare;
    return '${a.teamA}-${a.teamB}'.compareTo('${b.teamA}-${b.teamB}');
  });
  return rows;
}

List<_MatchupRow> _filterMatchups(List<_MatchupRow> rows, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((row) => '${row.teamA} ${row.teamB} ${row.teamA}-${row.teamB} ${row.teamB}-${row.teamA}'.toLowerCase().contains(q)).toList();
}

List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> rows, String query, List<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((row) => fields.map((field) => _text(row[field])).join(' ').toLowerCase().contains(q)).toList();
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) item.cast<String, dynamic>()];
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _isOne(Object? value) => value == 1 || value == true || value?.toString() == '1';

String _text(Object? value) => value?.toString() ?? '—';

String _shortText(Object? value, int maxLength) {
  final text = _text(value);
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}

String _decimal(Object? value, {int decimals = 3}) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (number == null) return '—';
  return decimals == 0 ? number.round().toString() : number.toStringAsFixed(decimals);
}

InputDecoration _inputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFF657386)),
    filled: true,
    fillColor: terminalPanelDark,
    isDense: true,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalAccent)),
  );
}
