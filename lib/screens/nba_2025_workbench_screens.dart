import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../widgets/terminal_primitives.dart';

class Nba2025PlayersScreen extends StatefulWidget {
  const Nba2025PlayersScreen({super.key});

  @override
  State<Nba2025PlayersScreen> createState() => _Nba2025PlayersScreenState();
}

class _Nba2025PlayersScreenState extends State<Nba2025PlayersScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      future: snapshotFuture,
      builder: (data) {
        final rows = _filter(data.playerSeasonTotals, query, const ['player_label', 'team_ids', 'player_id']);
        final totalPoints = _sum(rows, 'points');
        final totalAssists = _sum(rows, 'assists');
        final totalRebounds = _sum(rows, 'rebounds');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Players',
            subtitle: 'Generated player terminal from the completed 2024-25 warehouse: identities, loaded-season summaries, leaderboards, and high-value game-log rows.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Player Identities', '${data.players.length}', 'Warehouse player rows'),
            _MetricSpec('Active Summaries', '${data.playerSeasonTotals.length}', 'Players with game stats'),
            _MetricSpec('Visible Players', '${rows.length}', query.trim().isEmpty ? 'Unfiltered' : 'Query filtered'),
            _MetricSpec('Visible Production', '${totalPoints.round()} pts', '${totalRebounds.round()} reb / ${totalAssists.round()} ast'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(onChanged: (value) => setState(() => query = value), hint: 'Search player, player id, or team...'),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Loaded-Season Player Table',
            subtitle: 'One row per active player summary from materialized player_game_stats. Sorted by total points in the generated seed.',
            columns: const ['Player', 'Teams', 'GP', 'MIN', 'MPG', 'PTS', 'PPG', 'REB', 'AST', 'STL', 'BLK', 'TS%', 'BPM'],
            rows: [
              for (final row in rows.take(80))
                [
                  _text(row['player_label']),
                  _shortText(row['team_ids'], 16),
                  _text(row['games']),
                  _decimal(row['minutes'], decimals: 1),
                  _decimal(row['minutes_per_game'], decimals: 1),
                  _decimal(row['points'], decimals: 0),
                  _decimal(row['points_per_game']),
                  _decimal(row['rebounds'], decimals: 0),
                  _decimal(row['assists'], decimals: 0),
                  _decimal(row['steals'], decimals: 0),
                  _decimal(row['blocks'], decimals: 0),
                  _decimal(row['avg_ts_pct'], decimals: 3),
                  _decimal(row['avg_bpm']),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Top Player Game Logs',
            subtitle: 'High-value player-game rows available immediately for player pages and game detail pages.',
            columns: const ['Date', 'Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', 'STL', 'BLK', '+/-', 'TS%', 'BPM'],
            rows: [
              for (final row in _filter(data.playerGameLogsTop, query, const ['player_label', 'team_id', 'opponent_team_id', 'game_id']).take(80))
                [
                  _text(row['game_date']),
                  _text(row['player_label']),
                  _text(row['team_id']),
                  _text(row['opponent_team_id']),
                  _text(row['mp_text']),
                  _decimal(row['pts'], decimals: 0),
                  _decimal(row['trb'], decimals: 0),
                  _decimal(row['ast'], decimals: 0),
                  _decimal(row['stl'], decimals: 0),
                  _decimal(row['blk'], decimals: 0),
                  _decimal(row['plus_minus'], decimals: 0),
                  _decimal(row['ts_pct'], decimals: 3),
                  _decimal(row['bpm']),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025TeamsScreen extends StatefulWidget {
  const Nba2025TeamsScreen({super.key});

  @override
  State<Nba2025TeamsScreen> createState() => _Nba2025TeamsScreenState();
}

class _Nba2025TeamsScreenState extends State<Nba2025TeamsScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      future: snapshotFuture,
      builder: (data) {
        final records = _filter(data.teamRecords, query, const ['team_id']);
        final logs = _filter(data.teamGameLogs, query, const ['team_id', 'opponent_team_id', 'game_id', 'game_date', 'result']);
        final wins = _sum(records, 'wins');
        final losses = _sum(records, 'losses');
        final avgMargin = records.isEmpty ? 0 : records.fold<double>(0, (sum, row) => sum + _num(row['average_margin'])) / records.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Teams',
            subtitle: 'Generated team terminal from the completed 2024-25 warehouse: team records, margins, home/away game logs, and period scoring.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Teams', '${data.teams.length}', 'NBA team identities'),
            _MetricSpec('Team Games', '${data.teamGameLogs.length}', 'One row per team-game'),
            _MetricSpec('Visible W-L', '${wins.round()}-${losses.round()}', 'Across visible team rows'),
            _MetricSpec('Avg Margin', avgMargin.toStringAsFixed(2), 'Visible team average'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(onChanged: (value) => setState(() => query = value), hint: 'Search team, opponent, game id, result...'),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Team Records',
            subtitle: 'All loaded games in the warehouse, including postseason games.',
            columns: const ['Team', 'Games', 'W', 'L', 'Home', 'Away', 'PTS', 'Opp PTS', 'PPG', 'Opp PPG', 'Margin'],
            rows: [
              for (final row in records)
                [
                  _text(row['team_id']),
                  _text(row['games']),
                  _text(row['wins']),
                  _text(row['losses']),
                  _text(row['home_games']),
                  _text(row['away_games']),
                  _decimal(row['points'], decimals: 0),
                  _decimal(row['opponent_points'], decimals: 0),
                  _decimal(row['points_per_game']),
                  _decimal(row['opponent_points_per_game']),
                  _decimal(row['average_margin']),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Team Game Logs',
            subtitle: 'Game-level team rows with opponent, result, margin, and quarter scoring.',
            columns: const ['Date', 'Game', 'Team', 'Opp', 'H/A', 'Result', 'PTS', 'Opp PTS', 'Margin', 'Q1', 'Q2', 'Q3', 'Q4'],
            rows: [
              for (final row in logs.take(100))
                [
                  _text(row['game_date']),
                  _text(row['game_id']),
                  _text(row['team_id']),
                  _text(row['opponent_team_id']),
                  _isOne(row['is_home']) ? 'Home' : 'Away',
                  _text(row['result']),
                  _text(row['points']),
                  _text(row['opponent_points']),
                  _text(row['margin']),
                  _text(row['q1']),
                  _text(row['q2']),
                  _text(row['q3']),
                  _text(row['q4']),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025GamesScreen extends StatefulWidget {
  const Nba2025GamesScreen({super.key});

  @override
  State<Nba2025GamesScreen> createState() => _Nba2025GamesScreenState();
}

class _Nba2025GamesScreenState extends State<Nba2025GamesScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      future: snapshotFuture,
      builder: (data) {
        final rows = _filter(data.games, query, const ['game_id', 'game_date', 'away_team_id', 'home_team_id', 'winner_team_id', 'loser_team_id']);
        final closeGames = rows.where((row) => (_num(row['home_score']) - _num(row['away_score'])).abs() <= 5).length;
        final blowouts = rows.where((row) => (_num(row['home_score']) - _num(row['away_score'])).abs() >= 20).length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Games',
            subtitle: 'Generated game terminal from line scores: schedule/result rows, winners, margins, source URLs, and direct joins to team and player game logs.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Games', '${data.games.length}', 'Regular season + playoffs'),
            _MetricSpec('Visible Games', '${rows.length}', query.trim().isEmpty ? 'Unfiltered' : 'Query filtered'),
            _MetricSpec('Close Games', '$closeGames', 'Visible margin ≤ 5'),
            _MetricSpec('20+ Margins', '$blowouts', 'Visible blowouts'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(onChanged: (value) => setState(() => query = value), hint: 'Search game id, date, team, winner...'),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Game Results',
            subtitle: 'One row per loaded game with scores and winner/loser labels.',
            columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Margin', 'Winner', 'Source'],
            rows: [
              for (final row in rows.take(120))
                [
                  _text(row['game_date']),
                  _text(row['game_id']),
                  _text(row['away_team_id']),
                  _text(row['away_score']),
                  _text(row['home_team_id']),
                  _text(row['home_score']),
                  (_num(row['home_score']) - _num(row['away_score'])).abs().round().toString(),
                  _text(row['winner_team_id']),
                  _shortText(row['page_url'], 44),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Top Scoring Games by Player',
            subtitle: 'Fast path from a game row into player-level game-log context.',
            columns: const ['Date', 'Game', 'Player', 'Team', 'Opp', 'PTS', 'REB', 'AST', '+/-'],
            rows: [
              for (final row in _filter(data.playerGameLogsTop, query, const ['game_id', 'game_date', 'player_label', 'team_id', 'opponent_team_id']).take(80))
                [
                  _text(row['game_date']),
                  _text(row['game_id']),
                  _text(row['player_label']),
                  _text(row['team_id']),
                  _text(row['opponent_team_id']),
                  _decimal(row['pts'], decimals: 0),
                  _decimal(row['trb'], decimals: 0),
                  _decimal(row['ast'], decimals: 0),
                  _decimal(row['plus_minus'], decimals: 0),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025LeadersScreen extends StatefulWidget {
  const Nba2025LeadersScreen({super.key});

  @override
  State<Nba2025LeadersScreen> createState() => _Nba2025LeadersScreenState();
}

class _Nba2025LeadersScreenState extends State<Nba2025LeadersScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String leaderboard = 'points_per_game';
  String gameHigh = 'points';
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      future: snapshotFuture,
      builder: (data) {
        final leaderRows = _filter(_asMapList(data.playerLeaders[leaderboard]), query, const ['player_label', 'player_id']);
        final highRows = _filter(_asMapList(data.playerGameHighs[gameHigh]), query, const ['player_label', 'player_id', 'team_id', 'opponent_team_id', 'game_id']);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Leaders',
            subtitle: 'Generated leaderboard terminal for loaded-season player totals, per-game boards, BPM, and single-game highs.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Leaderboards', '${data.playerLeaders.length}', 'Generated stat boards'),
            _MetricSpec('Game High Boards', '${data.playerGameHighs.length}', 'Single-game stat boards'),
            _MetricSpec('Visible Leaders', '${leaderRows.length}', leaderboard),
            _MetricSpec('Visible Highs', '${highRows.length}', gameHigh),
          ]),
          const SizedBox(height: 22),
          _LeaderControls(
            queryChanged: (value) => setState(() => query = value),
            leaderboard: leaderboard,
            leaderboardKeys: data.playerLeaders.keys.toList()..sort(),
            leaderboardChanged: (value) => setState(() => leaderboard = value),
            gameHigh: gameHigh,
            gameHighKeys: data.playerGameHighs.keys.toList()..sort(),
            gameHighChanged: (value) => setState(() => gameHigh = value),
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Player Leaderboard: ${_titleize(leaderboard)}',
            subtitle: 'Top rows from player_leaders.json, recalculated from player_game_stats during seed export.',
            columns: const ['Player', 'GP', 'PTS', 'PPG', 'REB', 'RPG', 'AST', 'APG', 'STL/G', 'BLK/G', 'FG%', '3P%', 'FT%', 'BPM'],
            rows: [
              for (final row in leaderRows.take(100))
                [
                  _text(row['player_label']),
                  _text(row['games']),
                  _decimal(row['points'], decimals: 0),
                  _decimal(row['points_per_game']),
                  _decimal(row['rebounds'], decimals: 0),
                  _decimal(row['rebounds_per_game']),
                  _decimal(row['assists'], decimals: 0),
                  _decimal(row['assists_per_game']),
                  _decimal(row['steals_per_game']),
                  _decimal(row['blocks_per_game']),
                  _decimal(row['fg_pct'], decimals: 3),
                  _decimal(row['fg3_pct'], decimals: 3),
                  _decimal(row['ft_pct'], decimals: 3),
                  _decimal(row['avg_bpm']),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _DataPanel(
            title: 'Single-Game Highs: ${_titleize(gameHigh)}',
            subtitle: 'Top rows from player_game_highs.json with game/date/team context.',
            columns: const ['Date', 'Game', 'Player', 'Team', 'Opp', 'PTS', 'REB', 'AST', 'STL', 'BLK', '+/-', 'MIN'],
            rows: [
              for (final row in highRows.take(100))
                [
                  _text(row['game_date']),
                  _text(row['game_id']),
                  _text(row['player_label']),
                  _text(row['team_id']),
                  _text(row['opponent_team_id']),
                  _decimal(row['pts'], decimals: 0),
                  _decimal(row['trb'], decimals: 0),
                  _decimal(row['ast'], decimals: 0),
                  _decimal(row['stl'], decimals: 0),
                  _decimal(row['blk'], decimals: 0),
                  _decimal(row['plus_minus'], decimals: 0),
                  _text(row['mp_text']),
                ],
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

class _LeaderControls extends StatelessWidget {
  const _LeaderControls({
    required this.queryChanged,
    required this.leaderboard,
    required this.leaderboardKeys,
    required this.leaderboardChanged,
    required this.gameHigh,
    required this.gameHighKeys,
    required this.gameHighChanged,
  });

  final ValueChanged<String> queryChanged;
  final String leaderboard;
  final List<String> leaderboardKeys;
  final ValueChanged<String> leaderboardChanged;
  final String gameHigh;
  final List<String> gameHighKeys;
  final ValueChanged<String> gameHighChanged;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final searchWidth = compact ? constraints.maxWidth : 360.0;
        final fieldWidth = compact ? constraints.maxWidth : 240.0;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: searchWidth,
            child: TextField(
              onChanged: queryChanged,
              style: const TextStyle(color: Colors.white),
              cursorColor: terminalAccent,
              decoration: _inputDecoration('Search player, team, game id...'),
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: DropdownButtonFormField<String>(
              initialValue: leaderboard,
              dropdownColor: terminalPanelDark,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Leaderboard'),
              items: [
                for (final key in leaderboardKeys) DropdownMenuItem(value: key, child: Text(_titleize(key))),
              ],
              onChanged: (value) {
                if (value != null) leaderboardChanged(value);
              },
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: DropdownButtonFormField<String>(
              initialValue: gameHigh,
              dropdownColor: terminalPanelDark,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Game highs'),
              items: [
                for (final key in gameHighKeys) DropdownMenuItem(value: key, child: Text(_titleize(key))),
              ],
              onChanged: (value) {
                if (value != null) gameHighChanged(value);
              },
            ),
          ),
        ]);
      }),
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
        children: [
          for (final metric in metrics) _MetricCard(label: metric.label, value: metric.value, detail: metric.detail),
        ],
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
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
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
          const Padding(padding: EdgeInsets.all(18), child: Text('No rows match the current filters.', style: TextStyle(color: terminalTextSoft)))
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
                  DataRow(cells: [
                    for (final cell in row)
                      DataCell(SizedBox(width: cell.length > 32 ? 280 : 110, child: Text(cell, overflow: TextOverflow.ellipsis))),
                  ]),
              ],
            ),
          ),
      ]),
    );
  }
}

List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> rows, String query, List<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((row) {
    final text = fields.map((field) => _text(row[field])).join(' ').toLowerCase();
    return text.contains(q);
  }).toList();
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) item.cast<String, dynamic>()];
}

double _sum(List<Map<String, dynamic>> rows, String key) => rows.fold<double>(0, (sum, row) => sum + _num(row[key]));

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

String _titleize(String value) => value.split('_').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');

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
