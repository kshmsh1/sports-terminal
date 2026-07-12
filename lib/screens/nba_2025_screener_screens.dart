import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../widgets/terminal_primitives.dart';

class Nba2025TeamPowerScreen extends StatefulWidget {
  const Nba2025TeamPowerScreen({super.key});

  @override
  State<Nba2025TeamPowerScreen> createState() => _Nba2025TeamPowerScreenState();
}

class _Nba2025TeamPowerScreenState extends State<Nba2025TeamPowerScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final rows = _filter(data.teamRecords, query, const ['team_id']);
      final ranked = [for (final row in rows) _teamPowerRow(row)]..sort((a, b) => b.rating.compareTo(a.rating));
      final top = ranked.isEmpty ? null : ranked.first;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Team Power Board',
          subtitle: 'Terminal-style power ranking built from generated team records: win rate, point margin, scoring differential, and loaded-game volume.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Teams', '${ranked.length}', query.trim().isEmpty ? 'All loaded teams' : 'Query filtered'),
          _MetricSpec('Top Team', top?.teamId ?? '—', top == null ? 'No rows' : '${top.rating.toStringAsFixed(2)} rating'),
          _MetricSpec('Best Margin', top == null ? '—' : top.margin.toStringAsFixed(2), 'Average point margin'),
          _MetricSpec('Avg Win Rate', ranked.isEmpty ? '—' : _avg(ranked.map((row) => row.winRate)).toStringAsFixed(3), 'Visible teams'),
        ]),
        const SizedBox(height: 22),
        _SearchBox(value: query, hint: 'Search team code...', onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Power Ranking Table',
          subtitle: 'Rating = average margin + 12 × win rate + small game-volume stabilizer. This is an internal sorting heuristic, not a betting model.',
          columns: const ['Rank', 'Team', 'Rating', 'Games', 'W', 'L', 'Win%', 'PPG', 'Opp PPG', 'Margin'],
          rows: [
            for (var i = 0; i < ranked.length; i++)
              ['${i + 1}', ranked[i].teamId, ranked[i].rating.toStringAsFixed(2), '${ranked[i].games.round()}', '${ranked[i].wins.round()}', '${ranked[i].losses.round()}', ranked[i].winRate.toStringAsFixed(3), ranked[i].ppg.toStringAsFixed(1), ranked[i].oppPpg.toStringAsFixed(1), ranked[i].margin.toStringAsFixed(2)],
          ],
        ),
      ]);
    });
  }
}

class Nba2025PlayerScreenerScreen extends StatefulWidget {
  const Nba2025PlayerScreenerScreen({super.key});

  @override
  State<Nba2025PlayerScreenerScreen> createState() => _Nba2025PlayerScreenerScreenState();
}

class _Nba2025PlayerScreenerScreenState extends State<Nba2025PlayerScreenerScreen> {
  String query = '';
  String minGames = '30';
  String minPpg = '10';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final gamesGate = _num(minGames);
      final ppgGate = _num(minPpg);
      final base = _filter(data.playerSeasonTotals, query, const ['player_label', 'player_id', 'team_ids']);
      final rows = base.where((row) => _num(row['games']) >= gamesGate && _num(row['points_per_game']) >= ppgGate).toList()
        ..sort((a, b) => _num(b['points_per_game']).compareTo(_num(a['points_per_game'])));
      final avgPpg = rows.isEmpty ? 0 : _avg(rows.map((row) => _num(row['points_per_game'])));
      final avgBpm = rows.isEmpty ? 0 : _avg(rows.map((row) => _num(row['avg_bpm'])));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Player Screener',
          subtitle: 'Player filter terminal for active summaries. Screen by name/team plus minimum games and scoring threshold.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Matching Players', '${rows.length}', '${base.length} before thresholds'),
          _MetricSpec('Avg PPG', avgPpg.toStringAsFixed(1), 'Visible player set'),
          _MetricSpec('Avg BPM', avgBpm.toStringAsFixed(2), 'Visible player set'),
          _MetricSpec('Thresholds', '${gamesGate.round()} GP / ${ppgGate.toStringAsFixed(1)} PPG', 'Editable gates'),
        ]),
        const SizedBox(height: 22),
        _TripleSearchBox(
          firstValue: query,
          firstHint: 'Search player/team...',
          firstChanged: (value) => setState(() => query = value),
          secondValue: minGames,
          secondHint: 'Min games',
          secondChanged: (value) => setState(() => minGames = value),
          thirdValue: minPpg,
          thirdHint: 'Min PPG',
          thirdChanged: (value) => setState(() => minPpg = value),
        ),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Player Screen Results',
          subtitle: 'Sorted by points per game after threshold filters.',
          columns: const ['Player', 'Teams', 'GP', 'MPG', 'PTS', 'PPG', 'REB', 'AST', 'STL', 'BLK', 'TS%', 'BPM'],
          rows: [
            for (final row in rows.take(120))
              [_text(row['player_label']), _text(row['team_ids']), _text(row['games']), _decimal(row['minutes_per_game'], decimals: 1), _decimal(row['points'], decimals: 0), _decimal(row['points_per_game']), _decimal(row['rebounds'], decimals: 0), _decimal(row['assists'], decimals: 0), _decimal(row['steals'], decimals: 0), _decimal(row['blocks'], decimals: 0), _decimal(row['avg_ts_pct'], decimals: 3), _decimal(row['avg_bpm'])],
          ],
        ),
      ]);
    });
  }
}

class Nba2025GameScreenerScreen extends StatefulWidget {
  const Nba2025GameScreenerScreen({super.key});

  @override
  State<Nba2025GameScreenerScreen> createState() => _Nba2025GameScreenerScreenState();
}

class _Nba2025GameScreenerScreenState extends State<Nba2025GameScreenerScreen> {
  String query = '';
  String maxCloseMargin = '5';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final games = _filter(data.games, query, const ['game_id', 'game_date', 'away_team_id', 'home_team_id', 'winner_team_id', 'loser_team_id']);
      final enriched = [for (final game in games) _gameScreenRow(game)]..sort((a, b) => a.margin.compareTo(b.margin));
      final closeLimit = _num(maxCloseMargin);
      final closeGames = enriched.where((row) => row.margin <= closeLimit).toList();
      final biggestMargins = [...enriched]..sort((a, b) => b.margin.compareTo(a.margin));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Game Screener',
          subtitle: 'Game-result terminal for close games, blowouts, team/date searches, and quick game lookup.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Matching Games', '${enriched.length}', query.trim().isEmpty ? 'All loaded games' : 'Query filtered'),
          _MetricSpec('Close Games', '${closeGames.length}', 'Margin ≤ ${closeLimit.round()}'),
          _MetricSpec('Biggest Margin', biggestMargins.isEmpty ? '—' : '${biggestMargins.first.margin.round()}', biggestMargins.isEmpty ? 'No games' : biggestMargins.first.gameId),
          _MetricSpec('Avg Margin', enriched.isEmpty ? '—' : _avg(enriched.map((row) => row.margin)).toStringAsFixed(1), 'Visible games'),
        ]),
        const SizedBox(height: 22),
        _DoubleSearchBox(
          firstValue: query,
          firstHint: 'Search game, team, date...',
          firstChanged: (value) => setState(() => query = value),
          secondValue: maxCloseMargin,
          secondHint: 'Close margin max',
          secondChanged: (value) => setState(() => maxCloseMargin = value),
        ),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Closest Matching Games',
          subtitle: 'Sorted from closest to largest margin.',
          columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Margin', 'Winner'],
          rows: [for (final row in enriched.take(80)) [row.date, row.gameId, row.away, row.awayScore, row.home, row.homeScore, row.margin.round().toString(), row.winner]],
        ),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Biggest Matching Margins',
          subtitle: 'Sorted from largest margin downward.',
          columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Margin', 'Winner'],
          rows: [for (final row in biggestMargins.take(80)) [row.date, row.gameId, row.away, row.awayScore, row.home, row.homeScore, row.margin.round().toString(), row.winner]],
        ),
      ]);
    });
  }
}

class Nba2025DailyTapeScreen extends StatefulWidget {
  const Nba2025DailyTapeScreen({super.key});

  @override
  State<Nba2025DailyTapeScreen> createState() => _Nba2025DailyTapeScreenState();
}

class _Nba2025DailyTapeScreenState extends State<Nba2025DailyTapeScreen> {
  String dateQuery = '2024-10-22';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final games = _filter(data.games, dateQuery, const ['game_date', 'game_id', 'away_team_id', 'home_team_id']);
      final ids = games.map((row) => _text(row['game_id'])).toSet();
      final teamRows = data.teamGameLogs.where((row) => ids.contains(_text(row['game_id']))).toList();
      final playerRows = data.playerGameLogsTop.where((row) => ids.contains(_text(row['game_id']))).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Daily Tape',
          subtitle: 'Date/game terminal that groups game results, team-game rows, and available player-game logs for a selected day or game ID.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Games', '${games.length}', dateQuery.trim().isEmpty ? 'All games' : 'Matching query'),
          _MetricSpec('Team Rows', '${teamRows.length}', 'Rows attached to matching games'),
          _MetricSpec('Player Rows', '${playerRows.length}', 'Compact game logs attached'),
          _MetricSpec('Game IDs', '${ids.length}', 'Unique matching games'),
        ]),
        const SizedBox(height: 22),
        _SearchBox(value: dateQuery, hint: 'Search date or game id, e.g. 2024-10-22 or 202410220BOS...', onChanged: (value) => setState(() => dateQuery = value)),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Games on Tape',
          subtitle: 'Matching game rows.',
          columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Winner'],
          rows: [for (final row in games.take(80)) [_text(row['game_date']), _text(row['game_id']), _text(row['away_team_id']), _text(row['away_score']), _text(row['home_team_id']), _text(row['home_score']), _text(row['winner_team_id'])]],
        ),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Attached Team Logs',
          subtitle: 'Team-game rows for the matching game set.',
          columns: const ['Date', 'Game', 'Team', 'Opp', 'H/A', 'Result', 'PTS', 'Opp PTS', 'Margin'],
          rows: [for (final row in teamRows.take(120)) [_text(row['game_date']), _text(row['game_id']), _text(row['team_id']), _text(row['opponent_team_id']), _isOne(row['is_home']) ? 'Home' : 'Away', _text(row['result']), _text(row['points']), _text(row['opponent_points']), _text(row['margin'])]],
        ),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Attached Player Logs',
          subtitle: 'Compact high-value player-game rows attached to matching games.',
          columns: const ['Date', 'Game', 'Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', 'BPM'],
          rows: [for (final row in playerRows.take(120)) [_text(row['game_date']), _text(row['game_id']), _text(row['player_label']), _text(row['team_id']), _text(row['opponent_team_id']), _text(row['mp_text']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['bpm'])]],
        ),
      ]);
    });
  }
}

class Nba2025LeaderboardMatrixScreen extends StatefulWidget {
  const Nba2025LeaderboardMatrixScreen({super.key});

  @override
  State<Nba2025LeaderboardMatrixScreen> createState() => _Nba2025LeaderboardMatrixScreenState();
}

class _Nba2025LeaderboardMatrixScreenState extends State<Nba2025LeaderboardMatrixScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final boards = <_LeaderboardBoard>[];
      for (final entry in data.playerLeaders.entries) {
        final rows = _filter(_asMapList(entry.value), query, const ['player_label', 'player_id']);
        boards.add(_LeaderboardBoard(entry.key, rows));
      }
      boards.sort((a, b) => a.name.compareTo(b.name));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Leaderboard Matrix',
          subtitle: 'All generated player leaderboard boards in one matrix view, with each board showing the top matching rows.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Boards', '${boards.length}', 'player_leaders.json keys'),
          _MetricSpec('Visible Rows', '${boards.fold<int>(0, (sum, board) => sum + board.rows.length)}', 'Across all boards'),
          _MetricSpec('Game High Boards', '${data.playerGameHighs.length}', 'Available in Leaders tab'),
          _MetricSpec('Query', query.trim().isEmpty ? 'All' : query, 'Current filter'),
        ]),
        const SizedBox(height: 22),
        _SearchBox(value: query, hint: 'Search player across all leaderboard boards...', onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 22),
        for (final board in boards) ...[
          _TablePanel(
            title: _titleize(board.name),
            subtitle: 'Top matching rows from ${board.name}.',
            columns: const ['Player', 'GP', 'PTS', 'PPG', 'REB/G', 'AST/G', 'STL/G', 'BLK/G', 'BPM'],
            rows: [
              for (final row in board.rows.take(10))
                [_text(row['player_label']), _text(row['games']), _decimal(row['points'], decimals: 0), _decimal(row['points_per_game']), _decimal(row['rebounds_per_game']), _decimal(row['assists_per_game']), _decimal(row['steals_per_game']), _decimal(row['blocks_per_game']), _decimal(row['avg_bpm'])],
            ],
          ),
          const SizedBox(height: 18),
        ],
      ]);
    });
  }
}

class Nba2025SourceMapScreen extends StatelessWidget {
  const Nba2025SourceMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final files = data.dataDictionary['files'];
      final fileRows = <List<String>>[];
      if (files is Map) {
        for (final entry in files.entries) {
          final name = entry.key.toString();
          fileRows.add([name, _rowCountForFile(data, name), entry.value.toString()]);
        }
      }
      final copied = data.assetManifest?['copiedFiles'];
      final copiedRows = copied is List ? [for (final file in copied) [file.toString(), _rowCountForFile(data, file.toString())]] : <List<String>>[];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Source Map',
          subtitle: 'Generated file map for the static JSON layer: each seed file, purpose, row count, and Flutter asset-sync coverage.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Dictionary Files', '${fileRows.length}', 'data_dictionary.json'),
          _MetricSpec('Copied Files', '${copiedRows.length}', 'asset_manifest.json'),
          _MetricSpec('Validation', data.validationStatus.toUpperCase(), 'Seed finalizer'),
          _MetricSpec('Generated', data.warehouseGeneratedAt.length >= 10 ? data.warehouseGeneratedAt.substring(0, 10) : data.warehouseGeneratedAt, 'Warehouse build date'),
        ]),
        const SizedBox(height: 22),
        _TablePanel(title: 'Generated File Dictionary', subtitle: 'Purpose and row-count map for product-facing seed files.', columns: const ['File', 'Rows / Count', 'Purpose'], rows: fileRows),
        const SizedBox(height: 22),
        _TablePanel(title: 'Flutter Asset Mirror', subtitle: 'Files copied into assets/data/nba/terminal_seed/nba_2025.', columns: const ['File', 'Rows / Count'], rows: copiedRows),
      ]);
    });
  }
}

class _SeedFuture extends StatelessWidget {
  const _SeedFuture({required this.builder});
  final Widget Function(NbaTerminalSeedSnapshot data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const TerminalCard(child: Text('Loading NBA 2025 generated assets...', style: TextStyle(color: terminalTextSoft)));
        if (snapshot.hasError) return TerminalCard(child: Text('Unable to load NBA 2025 generated assets: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        return builder(snapshot.data!);
      },
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.value, required this.hint, required this.onChanged});
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TerminalCard(
        child: TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          cursorColor: terminalAccent,
          decoration: _inputDecoration(hint),
        ),
      );
}

class _DoubleSearchBox extends StatelessWidget {
  const _DoubleSearchBox({required this.firstValue, required this.firstHint, required this.firstChanged, required this.secondValue, required this.secondHint, required this.secondChanged});
  final String firstValue;
  final String firstHint;
  final ValueChanged<String> firstChanged;
  final String secondValue;
  final String secondHint;
  final ValueChanged<String> secondChanged;

  @override
  Widget build(BuildContext context) => TerminalCard(
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 360, child: TextField(controller: TextEditingController(text: firstValue), onChanged: firstChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration(firstHint))),
          SizedBox(width: 180, child: TextField(controller: TextEditingController(text: secondValue), onChanged: secondChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration(secondHint))),
        ]),
      );
}

class _TripleSearchBox extends StatelessWidget {
  const _TripleSearchBox({required this.firstValue, required this.firstHint, required this.firstChanged, required this.secondValue, required this.secondHint, required this.secondChanged, required this.thirdValue, required this.thirdHint, required this.thirdChanged});
  final String firstValue;
  final String firstHint;
  final ValueChanged<String> firstChanged;
  final String secondValue;
  final String secondHint;
  final ValueChanged<String> secondChanged;
  final String thirdValue;
  final String thirdHint;
  final ValueChanged<String> thirdChanged;

  @override
  Widget build(BuildContext context) => TerminalCard(
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 360, child: TextField(controller: TextEditingController(text: firstValue), onChanged: firstChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration(firstHint))),
          SizedBox(width: 160, child: TextField(controller: TextEditingController(text: secondValue), onChanged: secondChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration(secondHint))),
          SizedBox(width: 160, child: TextField(controller: TextEditingController(text: thirdValue), onChanged: thirdChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration(thirdHint))),
        ]),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<_MetricSpec> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        return GridView.count(
          crossAxisCount: wide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: wide ? 1.9 : 1.35,
          children: [for (final metric in metrics) _MetricCard(metric: metric)],
        );
      });
}

class _MetricSpec {
  const _MetricSpec(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _MetricSpec metric;

  @override
  Widget build(BuildContext context) => TerminalCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(metric.label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
          Text(metric.value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
          Text(metric.detail, style: const TextStyle(color: terminalAccent, fontSize: 12), overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _TablePanel extends StatelessWidget {
  const _TablePanel({required this.title, required this.subtitle, required this.columns, required this.rows});
  final String title;
  final String subtitle;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: terminalTextMuted))])),
              const SizedBox(width: 12),
              InfoPill(label: '${rows.length} rows'),
            ]),
          ),
          const Divider(height: 1, color: terminalBorder),
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.all(18), child: Text('No rows match this context.', style: TextStyle(color: terminalTextSoft)))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 28,
                columns: [for (final column in columns) DataColumn(label: Text(column))],
                rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 32 ? 280 : 110, child: Text(cell, overflow: TextOverflow.ellipsis)))]),],
              ),
            ),
        ]),
      );
}

class _TeamPowerRow {
  const _TeamPowerRow({required this.teamId, required this.games, required this.wins, required this.losses, required this.ppg, required this.oppPpg, required this.margin, required this.rating});
  final String teamId;
  final double games;
  final double wins;
  final double losses;
  final double ppg;
  final double oppPpg;
  final double margin;
  final double rating;
  double get winRate => games == 0 ? 0 : wins / games;
}

class _GameScreenRow {
  const _GameScreenRow({required this.date, required this.gameId, required this.away, required this.awayScore, required this.home, required this.homeScore, required this.winner, required this.margin});
  final String date;
  final String gameId;
  final String away;
  final String awayScore;
  final String home;
  final String homeScore;
  final String winner;
  final double margin;
}

class _LeaderboardBoard {
  const _LeaderboardBoard(this.name, this.rows);
  final String name;
  final List<Map<String, dynamic>> rows;
}

_TeamPowerRow _teamPowerRow(Map<String, dynamic> row) {
  final games = _num(row['games']);
  final wins = _num(row['wins']);
  final margin = _num(row['average_margin']);
  final winRate = games == 0 ? 0 : wins / games;
  final rating = margin + (winRate * 12) + (games / 1000);
  return _TeamPowerRow(teamId: _text(row['team_id']), games: games, wins: wins, losses: _num(row['losses']), ppg: _num(row['points_per_game']), oppPpg: _num(row['opponent_points_per_game']), margin: margin, rating: rating);
}

_GameScreenRow _gameScreenRow(Map<String, dynamic> row) {
  final away = _num(row['away_score']);
  final home = _num(row['home_score']);
  return _GameScreenRow(date: _text(row['game_date']), gameId: _text(row['game_id']), away: _text(row['away_team_id']), awayScore: _text(row['away_score']), home: _text(row['home_team_id']), homeScore: _text(row['home_score']), winner: _text(row['winner_team_id']), margin: (home - away).abs());
}

String _rowCountForFile(NbaTerminalSeedSnapshot data, String filename) {
  return switch (filename) {
    'teams.json' => '${data.teams.length}',
    'players.json' => '${data.players.length}',
    'games.json' => '${data.games.length}',
    'team_records.json' => '${data.teamRecords.length}',
    'team_game_logs.json' => '${data.teamGameLogs.length}',
    'player_season_totals.json' => '${data.playerSeasonTotals.length}',
    'player_leaders.json' => '${data.playerLeaders.length} boards',
    'player_game_highs.json' => '${data.playerGameHighs.length} boards',
    'player_game_logs_top.json' => '${data.playerGameLogsTop.length}',
    'search_index.json' => '${data.searchIndex.length}',
    'data_dictionary.json' => '${data.dataDictionary.length} keys',
    'validation_report.json' => data.validationStatus,
    'manifest.json' => '${data.manifest.length} keys',
    'asset_manifest.json' => '${data.copiedAssetFiles} copied',
    _ => '—',
  };
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

double _avg(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) return 0;
  return list.fold<double>(0, (sum, item) => sum + item) / list.length;
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

String _titleize(String value) => value.split('_').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');

InputDecoration _inputDecoration(String hintText) => InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF657386)),
      filled: true,
      fillColor: terminalPanelDark,
      isDense: true,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalAccent)),
    );
