import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../widgets/terminal_primitives.dart';

class Nba2025ClutchConsoleScreen extends StatefulWidget {
  const Nba2025ClutchConsoleScreen({super.key});
  @override
  State<Nba2025ClutchConsoleScreen> createState() => _Nba2025ClutchConsoleScreenState();
}

class _Nba2025ClutchConsoleScreenState extends State<Nba2025ClutchConsoleScreen> {
  String query = '';
  String margin = '5';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final limit = _num(margin).abs();
        final teams = _clutchRows(data.teamGameLogs, limit).where((row) => _txt(row['team']).toLowerCase().contains(query.trim().toLowerCase())).toList()
          ..sort((a, b) => _num(b['winRate']).compareTo(_num(a['winRate'])));
        final games = data.games.where((row) => (_num(row['home_score']) - _num(row['away_score'])).abs() <= limit && _gameMatches(row, query)).toList();
        final leader = teams.isEmpty ? null : teams.first;
        return _Page('2025 Clutch Console', 'Close-game terminal built from generated games and team-game rows.', [
          _MetricGrid([
            _Metric('Margin Gate', '≤ ${limit.round()}', 'Editable close-game definition'),
            _Metric('Team Rows', '${teams.length}', query.trim().isEmpty ? 'All teams' : 'Query filtered'),
            _Metric('Close Games', '${games.length}', 'Matching game rows'),
            _Metric('Best Close W%', _txt(leader?['team']), leader == null ? 'No rows' : _decimal(leader['winRate'], decimals: 3)),
          ]),
          _DoubleSearch(query, 'Search team...', margin, 'Close margin', (value) => setState(() => query = value), (value) => setState(() => margin = value)),
          _Table('Close-Game Team Board', 'Aggregated team rows where absolute margin is within the selected gate.', const ['Team', 'Games', 'W-L', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Last Close Game'], [
            for (final row in teams) [_txt(row['team']), _txt(row['games']), '${_txt(row['wins'])}-${_txt(row['losses'])}', _decimal(row['winRate'], decimals: 3), _decimal(row['ppg'], decimals: 1), _decimal(row['oppPpg'], decimals: 1), _decimal(row['margin'], decimals: 1), _txt(row['lastGame'])],
          ]),
          _Table('Close Games', 'Matching game rows sorted by date order from games.json.', const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Margin', 'Winner'], [
            for (final row in games.take(100)) [_txt(row['game_date']), _txt(row['game_id']), _txt(row['away_team_id']), _txt(row['away_score']), _txt(row['home_team_id']), _txt(row['home_score']), (_num(row['home_score']) - _num(row['away_score'])).abs().round().toString(), _txt(row['winner_team_id'])],
          ]),
        ]);
      });
}

class Nba2025RotationDepthScreen extends StatefulWidget {
  const Nba2025RotationDepthScreen({super.key});
  @override
  State<Nba2025RotationDepthScreen> createState() => _Nba2025RotationDepthScreenState();
}

class _Nba2025RotationDepthScreenState extends State<Nba2025RotationDepthScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final rows = _rotationRows(data.playerSeasonTotals).where((row) => _txt(row['team']).toLowerCase().contains(query.trim().toLowerCase())).toList()
          ..sort((a, b) => _num(b['top8Ppg']).compareTo(_num(a['top8Ppg'])));
        final top = rows.isEmpty ? null : rows.first;
        return _Page('2025 Rotation Depth', 'Front-office depth chart proxy built from active player season summaries.', [
          _MetricGrid([
            _Metric('Teams', '${rows.length}', query.trim().isEmpty ? 'All teams' : 'Query filtered'),
            _Metric('Deepest Scoring', _txt(top?['team']), top == null ? 'No rows' : '${_decimal(top['top8Ppg'], decimals: 1)} top-8 PPG'),
            _Metric('Avg Players', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['players']))).toStringAsFixed(1), 'Visible teams'),
            _Metric('Avg Top-8 PPG', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['top8Ppg']))).toStringAsFixed(1), 'Visible teams'),
          ]),
          _Search(query, 'Search team code...', (value) => setState(() => query = value)),
          _Table('Rotation Depth Board', 'Players are attached by generated team_ids. Multi-team players are counted for each listed team.', const ['Team', 'Players', '20+ PPG', '10+ PPG', 'Top Player', 'Top PPG', 'Top-5 PPG', 'Top-8 PPG', 'Total PTS'], [
            for (final row in rows) [_txt(row['team']), _txt(row['players']), _txt(row['stars']), _txt(row['doubleDigit']), _txt(row['topPlayer']), _decimal(row['topPpg'], decimals: 1), _decimal(row['top5Ppg'], decimals: 1), _decimal(row['top8Ppg'], decimals: 1), _decimal(row['points'], decimals: 0)],
          ]),
        ]);
      });
}

class Nba2025EfficiencyBoardScreen extends StatefulWidget {
  const Nba2025EfficiencyBoardScreen({super.key});
  @override
  State<Nba2025EfficiencyBoardScreen> createState() => _Nba2025EfficiencyBoardScreenState();
}

class _Nba2025EfficiencyBoardScreenState extends State<Nba2025EfficiencyBoardScreen> {
  String query = '';
  String minGames = '30';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final gate = _num(minGames);
        final rows = _filter(data.playerSeasonTotals, query, const ['player_label', 'player_id', 'team_ids']).where((row) => _num(row['games']) >= gate).toList()
          ..sort((a, b) {
            final bpm = _num(b['avg_bpm']).compareTo(_num(a['avg_bpm']));
            return bpm != 0 ? bpm : _num(b['avg_ts_pct']).compareTo(_num(a['avg_ts_pct']));
          });
        return _Page('2025 Efficiency Board', 'Player efficiency terminal sorted by BPM and true-shooting proxy from generated season summaries.', [
          _MetricGrid([
            _Metric('Players', '${rows.length}', 'Min ${gate.round()} games'),
            _Metric('Top BPM', rows.isEmpty ? '—' : _txt(rows.first['player_label']), rows.isEmpty ? 'No rows' : _decimal(rows.first['avg_bpm'])),
            _Metric('Avg BPM', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['avg_bpm']))).toStringAsFixed(2), 'Visible players'),
            _Metric('Avg TS%', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['avg_ts_pct']))).toStringAsFixed(3), 'Visible players'),
          ]),
          _DoubleSearch(query, 'Search player/team...', minGames, 'Min games', (value) => setState(() => query = value), (value) => setState(() => minGames = value)),
          _Table('Efficiency Board', 'Sorted by BPM, then TS%.', const ['Player', 'Teams', 'GP', 'MPG', 'PPG', 'TS%', 'BPM', 'PTS', 'REB', 'AST', 'STL', 'BLK'], [
            for (final row in rows.take(150)) [_txt(row['player_label']), _txt(row['team_ids']), _txt(row['games']), _decimal(row['minutes_per_game'], decimals: 1), _decimal(row['points_per_game'], decimals: 1), _decimal(row['avg_ts_pct'], decimals: 3), _decimal(row['avg_bpm']), _decimal(row['points'], decimals: 0), _decimal(row['rebounds'], decimals: 0), _decimal(row['assists'], decimals: 0), _decimal(row['steals'], decimals: 0), _decimal(row['blocks'], decimals: 0)],
          ]),
        ]);
      });
}

class Nba2025PeriodScoringScreen extends StatefulWidget {
  const Nba2025PeriodScoringScreen({super.key});
  @override
  State<Nba2025PeriodScoringScreen> createState() => _Nba2025PeriodScoringScreenState();
}

class _Nba2025PeriodScoringScreenState extends State<Nba2025PeriodScoringScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final rows = _periodRows(data.teamGameLogs).where((row) => _txt(row['team']).toLowerCase().contains(query.trim().toLowerCase())).toList()
          ..sort((a, b) => _num(b['q4']).compareTo(_num(a['q4'])));
        final q4 = rows.isEmpty ? null : rows.first;
        return _Page('2025 Period Scoring', 'Quarter-by-quarter team scoring profile from generated team-game logs.', [
          _MetricGrid([
            _Metric('Teams', '${rows.length}', query.trim().isEmpty ? 'All teams' : 'Query filtered'),
            _Metric('Best Q4', _txt(q4?['team']), q4 == null ? 'No rows' : _decimal(q4['q4'], decimals: 1)),
            _Metric('Avg Q1', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['q1']))).toStringAsFixed(1), 'Visible teams'),
            _Metric('Avg Q4', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['q4']))).toStringAsFixed(1), 'Visible teams'),
          ]),
          _Search(query, 'Search team code...', (value) => setState(() => query = value)),
          _Table('Quarter Scoring Board', 'Sorted by fourth-quarter scoring average.', const ['Team', 'Games', 'Q1', 'Q2', 'Q3', 'Q4', '1H', '2H', 'Q4-Q1', 'PPG'], [
            for (final row in rows) [_txt(row['team']), _txt(row['games']), _decimal(row['q1'], decimals: 1), _decimal(row['q2'], decimals: 1), _decimal(row['q3'], decimals: 1), _decimal(row['q4'], decimals: 1), _decimal(row['firstHalf'], decimals: 1), _decimal(row['secondHalf'], decimals: 1), _decimal(row['lateDelta'], decimals: 1), _decimal(row['ppg'], decimals: 1)],
          ]),
        ]);
      });
}

class Nba2025PlusMinusFinderScreen extends StatefulWidget {
  const Nba2025PlusMinusFinderScreen({super.key});
  @override
  State<Nba2025PlusMinusFinderScreen> createState() => _Nba2025PlusMinusFinderScreenState();
}

class _Nba2025PlusMinusFinderScreenState extends State<Nba2025PlusMinusFinderScreen> {
  String query = '';
  String threshold = '20';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final gate = _num(threshold).abs();
        final rows = _filter(data.playerGameLogsTop, query, const ['game_id', 'game_date', 'player_label', 'team_id', 'opponent_team_id']).where((row) => _num(row['plus_minus']).abs() >= gate).toList()
          ..sort((a, b) => _num(b['plus_minus']).abs().compareTo(_num(a['plus_minus']).abs()));
        return _Page('2025 Plus-Minus Finder', 'Player-game plus-minus event finder over compact high-value box-score rows.', [
          _MetricGrid([
            _Metric('Rows', '${rows.length}', '${gate.round()}+ absolute plus-minus'),
            _Metric('Top Swing', rows.isEmpty ? '—' : _txt(rows.first['player_label']), rows.isEmpty ? 'No rows' : _decimal(rows.first['plus_minus'], decimals: 0)),
            _Metric('Avg PTS', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['pts']))).toStringAsFixed(1), 'Visible rows'),
            _Metric('Avg BPM', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['bpm']))).toStringAsFixed(2), 'Visible rows'),
          ]),
          _DoubleSearch(query, 'Search player/team/game...', threshold, 'Abs +/- gate', (value) => setState(() => query = value), (value) => setState(() => threshold = value)),
          _Table('Plus-Minus Finder Results', 'Sorted by absolute plus-minus magnitude.', const ['Date', 'Game', 'Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', '+/-', 'TS%', 'BPM'], [
            for (final row in rows.take(150)) [_txt(row['game_date']), _txt(row['game_id']), _txt(row['player_label']), _txt(row['team_id']), _txt(row['opponent_team_id']), _txt(row['mp_text']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['plus_minus'], decimals: 0), _decimal(row['ts_pct'], decimals: 3), _decimal(row['bpm'])],
          ]),
        ]);
      });
}

class Nba2025ScoringEnvironmentScreen extends StatefulWidget {
  const Nba2025ScoringEnvironmentScreen({super.key});
  @override
  State<Nba2025ScoringEnvironmentScreen> createState() => _Nba2025ScoringEnvironmentScreenState();
}

class _Nba2025ScoringEnvironmentScreenState extends State<Nba2025ScoringEnvironmentScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final rows = _scoringEnvironmentRows(data.games).where((row) => _txt(row['month']).contains(query.trim())).toList();
        final games = _filter(data.games, query, const ['game_date', 'game_id', 'away_team_id', 'home_team_id', 'winner_team_id']);
        final highest = games.isEmpty ? null : (List<Map<String, dynamic>>.from(games)..sort((a, b) => (_num(b['home_score']) + _num(b['away_score'])).compareTo(_num(a['home_score']) + _num(a['away_score'])))).first;
        return _Page('2025 Scoring Environment', 'League scoring environment by month with high-total game drilldown.', [
          _MetricGrid([
            _Metric('Months', '${rows.length}', query.trim().isEmpty ? 'Full season' : 'Filtered'),
            _Metric('Games', '${games.length}', 'Matching game rows'),
            _Metric('Highest Total', _txt(highest?['game_id']), highest == null ? 'No rows' : '${(_num(highest['home_score']) + _num(highest['away_score'])).round()} points'),
            _Metric('Avg Total', games.isEmpty ? '—' : _avg(games.map((row) => _num(row['home_score']) + _num(row['away_score']))).toStringAsFixed(1), 'Matching games'),
          ]),
          _Search(query, 'Filter month/date/team/game, e.g. 2024-10, BOS...', (value) => setState(() => query = value)),
          _Table('Monthly Scoring Environment', 'Aggregated from game totals by game_date month.', const ['Month', 'Games', 'Avg Total', 'Avg Home', 'Avg Away', 'Avg Margin', 'Close Games', '220+ Totals'], [
            for (final row in rows) [_txt(row['month']), _txt(row['games']), _decimal(row['avgTotal'], decimals: 1), _decimal(row['avgHome'], decimals: 1), _decimal(row['avgAway'], decimals: 1), _decimal(row['avgMargin'], decimals: 1), _txt(row['closeGames']), _txt(row['highTotals'])],
          ]),
          _Table('Highest Matching Game Totals', 'Matching games sorted by total points.', const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Total', 'Winner'], [
            for (final row in (List<Map<String, dynamic>>.from(games)..sort((a, b) => (_num(b['home_score']) + _num(b['away_score'])).compareTo(_num(a['home_score']) + _num(a['away_score'])))).take(80)) [_txt(row['game_date']), _txt(row['game_id']), _txt(row['away_team_id']), _txt(row['away_score']), _txt(row['home_team_id']), _txt(row['home_score']), '${(_num(row['home_score']) + _num(row['away_score'])).round()}', _txt(row['winner_team_id'])],
          ]),
        ]);
      });
}

class _Seed extends StatelessWidget {
  const _Seed({required this.builder});
  final Widget Function(NbaTerminalSeedSnapshot data) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const TerminalCard(child: Text('Loading NBA 2025 generated assets...', style: TextStyle(color: terminalTextSoft)));
          if (snapshot.hasError) return TerminalCard(child: Text('Unable to load NBA 2025 generated assets: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
          return builder(snapshot.data!);
        },
      );
}

class _Page extends StatelessWidget {
  const _Page(this.title, this.subtitle, this.children);
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 22),
        for (final child in children) ...[child, const SizedBox(height: 22)],
      ]);
}

class _Metric {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid(this.metrics);
  final List<_Metric> metrics;
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
          children: [for (final metric in metrics) TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(metric.label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(metric.value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis), Text(metric.detail, style: const TextStyle(color: terminalAccent, fontSize: 12), overflow: TextOverflow.ellipsis)]))],
        );
      });
}

class _Search extends StatelessWidget {
  const _Search(this.value, this.hint, this.onChanged);
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TerminalCard(child: TextField(controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length), onChanged: onChanged, style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _decoration(hint)));
}

class _DoubleSearch extends StatelessWidget {
  const _DoubleSearch(this.first, this.firstHint, this.second, this.secondHint, this.onFirst, this.onSecond);
  final String first;
  final String firstHint;
  final String second;
  final String secondHint;
  final ValueChanged<String> onFirst;
  final ValueChanged<String> onSecond;
  @override
  Widget build(BuildContext context) => TerminalCard(
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 360, child: TextField(controller: TextEditingController(text: first), onChanged: onFirst, style: const TextStyle(color: Colors.white), decoration: _decoration(firstHint))),
          SizedBox(width: 180, child: TextField(controller: TextEditingController(text: second), onChanged: onSecond, style: const TextStyle(color: Colors.white), decoration: _decoration(secondHint))),
        ]),
      );
}

class _Table extends StatelessWidget {
  const _Table(this.title, this.subtitle, this.columns, this.rows);
  final String title;
  final String subtitle;
  final List<String> columns;
  final List<List<String>> rows;
  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(18), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: terminalTextMuted))])), const SizedBox(width: 12), InfoPill(label: '${rows.length} rows')])) ,
          const Divider(height: 1, color: terminalBorder),
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.all(18), child: Text('No rows match this context.', style: TextStyle(color: terminalTextSoft)))
          else
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: [for (final column in columns) DataColumn(label: Text(column))], rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 32 ? 280 : 110, child: Text(cell, overflow: TextOverflow.ellipsis)))])])),
        ]),
      );
}

List<Map<String, dynamic>> _clutchRows(List<Map<String, dynamic>> logs, double limit) {
  final map = <String, Map<String, dynamic>>{};
  for (final log in logs) {
    if (_num(log['margin']).abs() > limit) continue;
    final team = _txt(log['team_id']);
    final row = map.putIfAbsent(team, () => {'team': team, 'games': 0, 'wins': 0, 'losses': 0, 'points': 0.0, 'opp': 0.0, 'margin': 0.0, 'lastGame': '—'});
    row['games'] = _num(row['games']) + 1;
    row['wins'] = _num(row['wins']) + (_txt(log['result']).toUpperCase() == 'W' ? 1 : 0);
    row['losses'] = _num(row['losses']) + (_txt(log['result']).toUpperCase() == 'L' ? 1 : 0);
    row['points'] = _num(row['points']) + _num(log['points']);
    row['opp'] = _num(row['opp']) + _num(log['opponent_points']);
    row['margin'] = _num(row['margin']) + _num(log['margin']);
    row['lastGame'] = _txt(log['game_id']);
  }
  for (final row in map.values) {
    final games = _num(row['games']);
    row['winRate'] = games == 0 ? 0 : _num(row['wins']) / games;
    row['ppg'] = games == 0 ? 0 : _num(row['points']) / games;
    row['oppPpg'] = games == 0 ? 0 : _num(row['opp']) / games;
    row['margin'] = games == 0 ? 0 : _num(row['margin']) / games;
  }
  return map.values.toList();
}

List<Map<String, dynamic>> _rotationRows(List<Map<String, dynamic>> players) {
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final player in players) {
    for (final team in _txt(player['team_ids']).split(',')) {
      final clean = team.trim();
      if (clean.isEmpty || clean == '—') continue;
      buckets.putIfAbsent(clean, () => []).add(player);
    }
  }
  final rows = <Map<String, dynamic>>[];
  for (final entry in buckets.entries) {
    final roster = List<Map<String, dynamic>>.from(entry.value)..sort((a, b) => _num(b['points_per_game']).compareTo(_num(a['points_per_game'])));
    rows.add({
      'team': entry.key,
      'players': roster.length,
      'stars': roster.where((row) => _num(row['points_per_game']) >= 20).length,
      'doubleDigit': roster.where((row) => _num(row['points_per_game']) >= 10).length,
      'topPlayer': roster.isEmpty ? '—' : _txt(roster.first['player_label']),
      'topPpg': roster.isEmpty ? 0 : _num(roster.first['points_per_game']),
      'top5Ppg': roster.take(5).fold<double>(0, (sum, row) => sum + _num(row['points_per_game'])),
      'top8Ppg': roster.take(8).fold<double>(0, (sum, row) => sum + _num(row['points_per_game'])),
      'points': roster.fold<double>(0, (sum, row) => sum + _num(row['points'])),
    });
  }
  return rows;
}

List<Map<String, dynamic>> _periodRows(List<Map<String, dynamic>> logs) {
  final map = <String, Map<String, dynamic>>{};
  for (final log in logs) {
    final team = _txt(log['team_id']);
    final row = map.putIfAbsent(team, () => {'team': team, 'games': 0, 'q1': 0.0, 'q2': 0.0, 'q3': 0.0, 'q4': 0.0, 'points': 0.0});
    row['games'] = _num(row['games']) + 1;
    for (final key in ['q1', 'q2', 'q3', 'q4']) {
      row[key] = _num(row[key]) + _num(log[key]);
    }
    row['points'] = _num(row['points']) + _num(log['points']);
  }
  for (final row in map.values) {
    final games = _num(row['games']);
    for (final key in ['q1', 'q2', 'q3', 'q4']) {
      row[key] = games == 0 ? 0 : _num(row[key]) / games;
    }
    row['firstHalf'] = _num(row['q1']) + _num(row['q2']);
    row['secondHalf'] = _num(row['q3']) + _num(row['q4']);
    row['lateDelta'] = _num(row['q4']) - _num(row['q1']);
    row['ppg'] = games == 0 ? 0 : _num(row['points']) / games;
  }
  return map.values.toList();
}

List<Map<String, dynamic>> _scoringEnvironmentRows(List<Map<String, dynamic>> games) {
  final map = <String, Map<String, dynamic>>{};
  for (final game in games) {
    final date = _txt(game['game_date']);
    final month = date.length >= 7 ? date.substring(0, 7) : 'Unknown';
    final home = _num(game['home_score']);
    final away = _num(game['away_score']);
    final total = home + away;
    final row = map.putIfAbsent(month, () => {'month': month, 'games': 0, 'total': 0.0, 'home': 0.0, 'away': 0.0, 'margin': 0.0, 'closeGames': 0, 'highTotals': 0});
    row['games'] = _num(row['games']) + 1;
    row['total'] = _num(row['total']) + total;
    row['home'] = _num(row['home']) + home;
    row['away'] = _num(row['away']) + away;
    row['margin'] = _num(row['margin']) + (home - away).abs();
    row['closeGames'] = _num(row['closeGames']) + ((home - away).abs() <= 5 ? 1 : 0);
    row['highTotals'] = _num(row['highTotals']) + (total >= 220 ? 1 : 0);
  }
  final rows = map.values.toList()..sort((a, b) => _txt(a['month']).compareTo(_txt(b['month'])));
  for (final row in rows) {
    final count = _num(row['games']);
    row['avgTotal'] = count == 0 ? 0 : _num(row['total']) / count;
    row['avgHome'] = count == 0 ? 0 : _num(row['home']) / count;
    row['avgAway'] = count == 0 ? 0 : _num(row['away']) / count;
    row['avgMargin'] = count == 0 ? 0 : _num(row['margin']) / count;
  }
  return rows;
}

bool _gameMatches(Map<String, dynamic> row, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [_txt(row['game_id']), _txt(row['game_date']), _txt(row['away_team_id']), _txt(row['home_team_id']), _txt(row['winner_team_id'])].join(' ').toLowerCase().contains(q);
}

List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> rows, String query, List<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((row) => fields.map((field) => _txt(row[field])).join(' ').toLowerCase().contains(q)).toList();
}

double _avg(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) return 0;
  return list.fold<double>(0, (sum, value) => sum + value) / list.length;
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _txt(Object? value) => value?.toString() ?? '—';

String _decimal(Object? value, {int decimals = 2}) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (number == null) return '—';
  return decimals == 0 ? number.round().toString() : number.toStringAsFixed(decimals);
}

InputDecoration _decoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF657386)),
      filled: true,
      fillColor: terminalPanelDark,
      isDense: true,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalAccent)),
    );
