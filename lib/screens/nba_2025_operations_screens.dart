import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../widgets/terminal_primitives.dart';

class Nba2025TeamSplitsScreen extends StatefulWidget {
  const Nba2025TeamSplitsScreen({super.key});
  @override
  State<Nba2025TeamSplitsScreen> createState() => _Nba2025TeamSplitsScreenState();
}

class _Nba2025TeamSplitsScreenState extends State<Nba2025TeamSplitsScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final rows = _teamSplits(data.teamGameLogs).where((row) => _txt(row['team']).toLowerCase().contains(query.trim().toLowerCase())).toList()..sort((a, b) => _num(b['margin']).compareTo(_num(a['margin'])));
        final best = rows.isEmpty ? null : rows.first;
        return _Page('2025 Team Splits', 'Home/away split terminal built from generated team-game logs.', [
          _MetricGrid([
            _Metric('Teams', '${rows.length}', query.trim().isEmpty ? 'All loaded teams' : 'Query filtered'),
            _Metric('Best Margin', _txt(best?['team']), best == null ? 'No rows' : _decimal(best['margin'])),
            _Metric('Avg Home Win%', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['homeWinRate']))).toStringAsFixed(3), 'Visible teams'),
            _Metric('Avg Away Win%', rows.isEmpty ? '—' : _avg(rows.map((row) => _num(row['awayWinRate']))).toStringAsFixed(3), 'Visible teams'),
          ]),
          _Search(query, 'Search team code...', (value) => setState(() => query = value)),
          _Table('Team Home/Away Splits', 'Sorted by overall average margin.', const ['Team', 'Games', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Home W-L', 'Home Margin', 'Away W-L', 'Away Margin'], [
            for (final row in rows)
              [_txt(row['team']), _txt(row['games']), _decimal(row['winRate'], decimals: 3), _decimal(row['ppg'], decimals: 1), _decimal(row['oppPpg'], decimals: 1), _decimal(row['margin']), '${_txt(row['homeWins'])}-${_txt(row['homeLosses'])}', _decimal(row['homeMargin']), '${_txt(row['awayWins'])}-${_txt(row['awayLosses'])}', _decimal(row['awayMargin'])],
          ]),
        ]);
      });
}

class Nba2025OpponentMatrixScreen extends StatefulWidget {
  const Nba2025OpponentMatrixScreen({super.key});
  @override
  State<Nba2025OpponentMatrixScreen> createState() => _Nba2025OpponentMatrixScreenState();
}

class _Nba2025OpponentMatrixScreenState extends State<Nba2025OpponentMatrixScreen> {
  String team = 'OKC';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final teamId = team.trim().isEmpty ? 'OKC' : team.trim().toUpperCase();
        final rows = _opponentRows(data.teamGameLogs, teamId);
        final byBest = List<Map<String, dynamic>>.from(rows)..sort((a, b) => _num(b['margin']).compareTo(_num(a['margin'])));
        final byWorst = List<Map<String, dynamic>>.from(rows)..sort((a, b) => _num(a['margin']).compareTo(_num(b['margin'])));
        final best = byBest.isEmpty ? null : byBest.first;
        final worst = byWorst.isEmpty ? null : byWorst.first;
        return _Page('2025 Opponent Matrix', 'Team-vs-opponent matchup matrix from generated team-game logs.', [
          _MetricGrid([
            _Metric('Selected Team', teamId, '${rows.fold<int>(0, (sum, row) => sum + _num(row['games']).round())} games'),
            _Metric('Opponents', '${rows.length}', 'Unique opponents'),
            _Metric('Best Matchup', _txt(best?['opponent']), best == null ? 'No rows' : _decimal(best['margin'], decimals: 1)),
            _Metric('Worst Matchup', _txt(worst?['opponent']), worst == null ? 'No rows' : _decimal(worst['margin'], decimals: 1)),
          ]),
          _Search(team, 'Enter team code: OKC, BOS, NYK...', (value) => setState(() => team = value)),
          _Table('$teamId Opponent Matrix', 'Aggregated across every loaded meeting with each opponent.', const ['Opponent', 'Games', 'W-L', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Last Game', 'Last Result'], [
            for (final row in rows)
              [_txt(row['opponent']), _txt(row['games']), '${_txt(row['wins'])}-${_txt(row['losses'])}', _decimal(row['winRate'], decimals: 3), _decimal(row['ppg'], decimals: 1), _decimal(row['oppPpg'], decimals: 1), _decimal(row['margin'], decimals: 1), _txt(row['lastGame']), _txt(row['lastResult'])],
          ]),
        ]);
      });
}

class Nba2025PlayerRoleBoardScreen extends StatefulWidget {
  const Nba2025PlayerRoleBoardScreen({super.key});
  @override
  State<Nba2025PlayerRoleBoardScreen> createState() => _Nba2025PlayerRoleBoardScreenState();
}

class _Nba2025PlayerRoleBoardScreenState extends State<Nba2025PlayerRoleBoardScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final rows = _filter(data.playerSeasonTotals, query, const ['player_label', 'player_id', 'team_ids']).map(_roleRow).toList()..sort((a, b) => _num(b['score']).compareTo(_num(a['score'])));
        final buckets = <String, int>{};
        for (final row in rows) {
          buckets[_txt(row['role'])] = (buckets[_txt(row['role'])] ?? 0) + 1;
        }
        return _Page('2025 Player Role Board', 'Role classification from games, minutes, scoring, efficiency, and BPM.', [
          _MetricGrid([
            _Metric('Players', '${rows.length}', query.trim().isEmpty ? 'All active summaries' : 'Query filtered'),
            _Metric('Stars', '${buckets['Star'] ?? 0}', 'High usage/scoring'),
            _Metric('Starters', '${buckets['Starter'] ?? 0}', 'High-minute profiles'),
            _Metric('Rotation+', '${(buckets['Rotation'] ?? 0) + (buckets['Specialist'] ?? 0)}', 'Rotation and specialist roles'),
          ]),
          _Search(query, 'Search player, team, or id...', (value) => setState(() => query = value)),
          _Table('Role Board', 'Internal sorting heuristic for terminal triage, not a formal value model.', const ['Role', 'Score', 'Player', 'Teams', 'GP', 'MPG', 'PPG', 'REB', 'AST', 'TS%', 'BPM'], [
            for (final row in rows.take(150))
              [_txt(row['role']), _decimal(row['score']), _txt(row['player']), _txt(row['teams']), _decimal(row['games'], decimals: 0), _decimal(row['mpg'], decimals: 1), _decimal(row['ppg'], decimals: 1), _decimal(row['rebounds'], decimals: 0), _decimal(row['assists'], decimals: 0), _decimal(row['ts'], decimals: 3), _decimal(row['bpm'])],
          ]),
        ]);
      });
}

class Nba2025BoxScoreFinderScreen extends StatefulWidget {
  const Nba2025BoxScoreFinderScreen({super.key});
  @override
  State<Nba2025BoxScoreFinderScreen> createState() => _Nba2025BoxScoreFinderScreenState();
}

class _Nba2025BoxScoreFinderScreenState extends State<Nba2025BoxScoreFinderScreen> {
  String query = '';
  String minPoints = '25';
  String minBpm = '0';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final ptsGate = _num(minPoints);
        final bpmGate = _num(minBpm);
        final base = _filter(data.playerGameLogsTop, query, const ['game_id', 'game_date', 'player_label', 'team_id', 'opponent_team_id']);
        final rows = base.where((row) => _num(row['pts']) >= ptsGate && _num(row['bpm']) >= bpmGate).toList()
          ..sort((a, b) {
            final pts = _num(b['pts']).compareTo(_num(a['pts']));
            return pts != 0 ? pts : _num(b['bpm']).compareTo(_num(a['bpm']));
          });
        return _Page('2025 Box Score Finder', 'High-value player-game finder with point and BPM gates.', [
          _MetricGrid([
            _Metric('Matching Rows', '${rows.length}', '${base.length} before gates'),
            _Metric('Min Points', ptsGate.toStringAsFixed(0), 'Editable gate'),
            _Metric('Min BPM', bpmGate.toStringAsFixed(1), 'Editable gate'),
            _Metric('Top Row', _txt(rows.isEmpty ? null : rows.first['player_label']), rows.isEmpty ? 'No rows' : '${_decimal(rows.first['pts'], decimals: 0)} pts'),
          ]),
          _TripleSearch(query, minPoints, minBpm, (value) => setState(() => query = value), (value) => setState(() => minPoints = value), (value) => setState(() => minBpm = value)),
          _Table('Box Score Finder Results', 'Sorted by points, then BPM.', const ['Date', 'Game', 'Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', 'STL', 'BLK', '+/-', 'TS%', 'BPM'], [
            for (final row in rows.take(150))
              [_txt(row['game_date']), _txt(row['game_id']), _txt(row['player_label']), _txt(row['team_id']), _txt(row['opponent_team_id']), _txt(row['mp_text']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['stl'], decimals: 0), _decimal(row['blk'], decimals: 0), _decimal(row['plus_minus'], decimals: 0), _decimal(row['ts_pct'], decimals: 3), _decimal(row['bpm'])],
          ]),
        ]);
      });
}

class Nba2025MomentumBoardScreen extends StatefulWidget {
  const Nba2025MomentumBoardScreen({super.key});
  @override
  State<Nba2025MomentumBoardScreen> createState() => _Nba2025MomentumBoardScreenState();
}

class _Nba2025MomentumBoardScreenState extends State<Nba2025MomentumBoardScreen> {
  String window = '10';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final windowSize = _clamp(_num(window).round(), 1, 40);
        final rows = _momentumRows(data.teamGameLogs, windowSize)..sort((a, b) => _num(b['margin']).compareTo(_num(a['margin'])));
        final best = rows.isEmpty ? null : rows.first;
        final worst = rows.isEmpty ? null : rows.last;
        return _Page('2025 Momentum Board', 'Recent-form board for every team using the last N generated team-game rows.', [
          _MetricGrid([
            _Metric('Window', '$windowSize games', 'Editable lookback'),
            _Metric('Best Form', _txt(best?['team']), best == null ? 'No rows' : '${_txt(best['wins'])}-${_txt(best['losses'])}, ${_decimal(best['margin'], decimals: 1)} margin'),
            _Metric('Worst Form', _txt(worst?['team']), worst == null ? 'No rows' : '${_txt(worst['wins'])}-${_txt(worst['losses'])}, ${_decimal(worst['margin'], decimals: 1)} margin'),
            _Metric('Teams', '${rows.length}', 'Momentum rows'),
          ]),
          _Search(window, 'Recent-game window: 5, 10, 20...', (value) => setState(() => window = value)),
          _Table('Recent Momentum Ranking', 'Sorted by average margin over the selected window.', const ['Rank', 'Team', 'Games', 'W-L', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Last Game', 'Last Result'], [
            for (var i = 0; i < rows.length; i++)
              ['${i + 1}', _txt(rows[i]['team']), _txt(rows[i]['games']), '${_txt(rows[i]['wins'])}-${_txt(rows[i]['losses'])}', _decimal(rows[i]['winRate'], decimals: 3), _decimal(rows[i]['ppg'], decimals: 1), _decimal(rows[i]['oppPpg'], decimals: 1), _decimal(rows[i]['margin'], decimals: 1), _txt(rows[i]['lastGame']), _txt(rows[i]['lastResult'])],
          ]),
        ]);
      });
}

class Nba2025SeasonTimelineScreen extends StatefulWidget {
  const Nba2025SeasonTimelineScreen({super.key});
  @override
  State<Nba2025SeasonTimelineScreen> createState() => _Nba2025SeasonTimelineScreenState();
}

class _Nba2025SeasonTimelineScreenState extends State<Nba2025SeasonTimelineScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => _Seed(builder: (data) {
        final allMonths = _monthRows(data.games);
        final months = query.trim().isEmpty ? allMonths : allMonths.where((row) => _txt(row['month']).contains(query.trim())).toList();
        final selectedGames = _filter(data.games, query, const ['game_date', 'game_id', 'away_team_id', 'home_team_id', 'winner_team_id']);
        final busy = List<Map<String, dynamic>>.from(months)..sort((a, b) => _num(b['games']).compareTo(_num(a['games'])));
        final busiest = busy.isEmpty ? null : busy.first;
        return _Page('2025 Season Timeline', 'Month-by-month schedule/result terminal from generated games.json.', [
          _MetricGrid([
            _Metric('Months', '${months.length}', query.trim().isEmpty ? 'Full season' : 'Filtered'),
            _Metric('Matching Games', '${selectedGames.length}', 'Query drilldown'),
            _Metric('Busiest Month', _txt(busiest?['month']), busiest == null ? 'No rows' : '${_txt(busiest['games'])} games'),
            _Metric('Close Games', '${months.fold<int>(0, (sum, row) => sum + _num(row['closeGames']).round())}', 'Margin ≤ 5'),
          ]),
          _Search(query, 'Filter by month/date/team/game, e.g. 2024-10, BOS...', (value) => setState(() => query = value)),
          _Table('Season Timeline by Month', 'Aggregated by game_date month.', const ['Month', 'Games', 'Avg Total', 'Avg Margin', 'Close Games', 'Home Wins', 'Away Wins'], [
            for (final row in months)
              [_txt(row['month']), _txt(row['games']), _decimal(row['avgTotal'], decimals: 1), _decimal(row['avgMargin'], decimals: 1), _txt(row['closeGames']), _txt(row['homeWins']), _txt(row['awayWins'])],
          ]),
          _Table('Selected Games', 'Games matching the current query.', const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Winner', 'Margin'], [
            for (final row in selectedGames.take(100))
              [_txt(row['game_date']), _txt(row['game_id']), _txt(row['away_team_id']), _txt(row['away_score']), _txt(row['home_team_id']), _txt(row['home_score']), _txt(row['winner_team_id']), (_num(row['home_score']) - _num(row['away_score'])).abs().round().toString()],
          ]),
        ]);
      });
}

class _Page extends StatelessWidget {
  const _Page(this.title, this.subtitle, this.children);
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionHeader(title: title, subtitle: subtitle), for (final child in children) ...[const SizedBox(height: 22), child]]);
}

class _Seed extends StatelessWidget {
  const _Seed({required this.builder});
  final Widget Function(NbaTerminalSeedSnapshot data) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const TerminalCard(child: Text('Loading NBA 2025 operations assets...', style: TextStyle(color: terminalTextSoft)));
          if (snapshot.hasError) return TerminalCard(child: Text('Unable to load NBA 2025 generated assets: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
          return builder(snapshot.data!);
        },
      );
}

class _Search extends StatelessWidget {
  const _Search(this.value, this.hint, this.onChanged);
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TerminalCard(child: TextField(controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length), onChanged: onChanged, style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration(hint)));
}

class _TripleSearch extends StatelessWidget {
  const _TripleSearch(this.first, this.second, this.third, this.firstChanged, this.secondChanged, this.thirdChanged);
  final String first;
  final String second;
  final String third;
  final ValueChanged<String> firstChanged;
  final ValueChanged<String> secondChanged;
  final ValueChanged<String> thirdChanged;
  @override
  Widget build(BuildContext context) => TerminalCard(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final wide = compact ? constraints.maxWidth : 360.0;
          final narrow = compact ? constraints.maxWidth : 160.0;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: wide, child: TextField(controller: TextEditingController(text: first), onChanged: firstChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Search player, team, game...'))),
            SizedBox(width: narrow, child: TextField(controller: TextEditingController(text: second), onChanged: secondChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Min points'))),
            SizedBox(width: narrow, child: TextField(controller: TextEditingController(text: third), onChanged: thirdChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Min BPM'))),
          ]);
        }),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid(this.metrics);
  final List<_Metric> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: wide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: wide ? 1.9 : 1.35, children: [for (final metric in metrics) _MetricCard(metric)]);
      });
}

class _Metric {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);
  final _Metric metric;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(metric.label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(metric.value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis), Text(metric.detail, style: const TextStyle(color: terminalAccent, fontSize: 12), overflow: TextOverflow.ellipsis)]));
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
          Padding(padding: const EdgeInsets.all(18), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: terminalTextMuted))])), const SizedBox(width: 12), InfoPill(label: '${rows.length} rows')])),
          const Divider(height: 1, color: terminalBorder),
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.all(18), child: Text('No rows match this context.', style: TextStyle(color: terminalTextSoft)))
          else
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 28, columns: [for (final column in columns) DataColumn(label: Text(column))], rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 32 ? 280 : 110, child: Text(cell, overflow: TextOverflow.ellipsis)))])])),
        ]),
      );
}

List<Map<String, dynamic>> _teamSplits(List<Map<String, dynamic>> logs) {
  final out = <String, Map<String, dynamic>>{};
  for (final log in logs) {
    final team = _txt(log['team_id']);
    final row = out.putIfAbsent(team, () => {'team': team, 'games': 0, 'wins': 0, 'losses': 0, 'points': 0.0, 'opp': 0.0, 'marginTotal': 0.0, 'homeGames': 0, 'homeWins': 0, 'homeLosses': 0, 'homeMarginTotal': 0.0, 'awayGames': 0, 'awayWins': 0, 'awayLosses': 0, 'awayMarginTotal': 0.0});
    final result = _txt(log['result']).toUpperCase();
    final home = _isOne(log['is_home']);
    final margin = _num(log['margin']);
    row['games'] = _num(row['games']).round() + 1;
    row['points'] = _num(row['points']) + _num(log['points']);
    row['opp'] = _num(row['opp']) + _num(log['opponent_points']);
    row['marginTotal'] = _num(row['marginTotal']) + margin;
    if (result == 'W') row['wins'] = _num(row['wins']).round() + 1;
    if (result == 'L') row['losses'] = _num(row['losses']).round() + 1;
    if (home) {
      row['homeGames'] = _num(row['homeGames']).round() + 1;
      row['homeMarginTotal'] = _num(row['homeMarginTotal']) + margin;
      if (result == 'W') row['homeWins'] = _num(row['homeWins']).round() + 1;
      if (result == 'L') row['homeLosses'] = _num(row['homeLosses']).round() + 1;
    } else {
      row['awayGames'] = _num(row['awayGames']).round() + 1;
      row['awayMarginTotal'] = _num(row['awayMarginTotal']) + margin;
      if (result == 'W') row['awayWins'] = _num(row['awayWins']).round() + 1;
      if (result == 'L') row['awayLosses'] = _num(row['awayLosses']).round() + 1;
    }
  }
  return [for (final row in out.values) _splitFinalize(row)];
}

Map<String, dynamic> _splitFinalize(Map<String, dynamic> row) {
  final games = _num(row['games']);
  final homeGames = _num(row['homeGames']);
  final awayGames = _num(row['awayGames']);
  return {...row, 'winRate': games == 0 ? 0 : _num(row['wins']) / games, 'ppg': games == 0 ? 0 : _num(row['points']) / games, 'oppPpg': games == 0 ? 0 : _num(row['opp']) / games, 'margin': games == 0 ? 0 : _num(row['marginTotal']) / games, 'homeWinRate': homeGames == 0 ? 0 : _num(row['homeWins']) / homeGames, 'homeMargin': homeGames == 0 ? 0 : _num(row['homeMarginTotal']) / homeGames, 'awayWinRate': awayGames == 0 ? 0 : _num(row['awayWins']) / awayGames, 'awayMargin': awayGames == 0 ? 0 : _num(row['awayMarginTotal']) / awayGames};
}

List<Map<String, dynamic>> _opponentRows(List<Map<String, dynamic>> logs, String teamId) {
  final out = <String, Map<String, dynamic>>{};
  for (final log in logs) {
    if (_txt(log['team_id']).toUpperCase() != teamId) continue;
    final opponent = _txt(log['opponent_team_id']);
    final row = out.putIfAbsent(opponent, () => {'opponent': opponent, 'games': 0, 'wins': 0, 'losses': 0, 'points': 0.0, 'opp': 0.0, 'marginTotal': 0.0, 'lastGame': '—', 'lastResult': '—'});
    final result = _txt(log['result']).toUpperCase();
    row['games'] = _num(row['games']).round() + 1;
    row['points'] = _num(row['points']) + _num(log['points']);
    row['opp'] = _num(row['opp']) + _num(log['opponent_points']);
    row['marginTotal'] = _num(row['marginTotal']) + _num(log['margin']);
    if (result == 'W') row['wins'] = _num(row['wins']).round() + 1;
    if (result == 'L') row['losses'] = _num(row['losses']).round() + 1;
    row['lastGame'] = _txt(log['game_id']);
    row['lastResult'] = result;
  }
  final rows = [for (final row in out.values) _opponentFinalize(row)]..sort((a, b) => _num(b['games']).compareTo(_num(a['games'])));
  return rows;
}

Map<String, dynamic> _opponentFinalize(Map<String, dynamic> row) {
  final games = _num(row['games']);
  return {...row, 'winRate': games == 0 ? 0 : _num(row['wins']) / games, 'ppg': games == 0 ? 0 : _num(row['points']) / games, 'oppPpg': games == 0 ? 0 : _num(row['opp']) / games, 'margin': games == 0 ? 0 : _num(row['marginTotal']) / games};
}

Map<String, dynamic> _roleRow(Map<String, dynamic> row) {
  final games = _num(row['games']);
  final mpg = _num(row['minutes_per_game']);
  final ppg = _num(row['points_per_game']);
  final bpm = _num(row['avg_bpm']);
  final ts = _num(row['avg_ts_pct']);
  final role = ppg >= 25 && mpg >= 30 ? 'Star' : mpg >= 28 ? 'Starter' : mpg >= 15 ? 'Rotation' : games >= 20 ? 'Specialist' : 'Depth';
  return {'player': _txt(row['player_label']), 'teams': _txt(row['team_ids']), 'role': role, 'score': ppg + bpm + (mpg / 3) + (ts * 4), 'games': games, 'mpg': mpg, 'ppg': ppg, 'rebounds': _num(row['rebounds']), 'assists': _num(row['assists']), 'ts': ts, 'bpm': bpm};
}

List<Map<String, dynamic>> _momentumRows(List<Map<String, dynamic>> logs, int window) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in logs) {
    grouped.putIfAbsent(_txt(row['team_id']), () => <Map<String, dynamic>>[]).add(row);
  }
  final out = <Map<String, dynamic>>[];
  for (final entry in grouped.entries) {
    final recent = entry.value.length <= window ? entry.value : entry.value.sublist(entry.value.length - window);
    var wins = 0;
    var losses = 0;
    var points = 0.0;
    var opp = 0.0;
    var margin = 0.0;
    for (final row in recent) {
      final result = _txt(row['result']).toUpperCase();
      if (result == 'W') wins += 1;
      if (result == 'L') losses += 1;
      points += _num(row['points']);
      opp += _num(row['opponent_points']);
      margin += _num(row['margin']);
    }
    final last = recent.isEmpty ? null : recent.last;
    final games = recent.length;
    out.add({'team': entry.key, 'games': games, 'wins': wins, 'losses': losses, 'winRate': games == 0 ? 0 : wins / games, 'ppg': games == 0 ? 0 : points / games, 'oppPpg': games == 0 ? 0 : opp / games, 'margin': games == 0 ? 0 : margin / games, 'lastGame': _txt(last?['game_id']), 'lastResult': _txt(last?['result'])});
  }
  return out;
}

List<Map<String, dynamic>> _monthRows(List<Map<String, dynamic>> games) {
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final game in games) {
    final date = _txt(game['game_date']);
    if (date.length >= 7) buckets.putIfAbsent(date.substring(0, 7), () => <Map<String, dynamic>>[]).add(game);
  }
  final rows = <Map<String, dynamic>>[];
  for (final entry in buckets.entries) {
    var total = 0.0;
    var margin = 0.0;
    var close = 0;
    var homeWins = 0;
    var awayWins = 0;
    for (final game in entry.value) {
      final away = _num(game['away_score']);
      final home = _num(game['home_score']);
      final diff = (home - away).abs();
      total += away + home;
      margin += diff;
      if (diff <= 5) close += 1;
      if (_txt(game['winner_team_id']) == _txt(game['home_team_id'])) {
        homeWins += 1;
      } else {
        awayWins += 1;
      }
    }
    final count = entry.value.length;
    rows.add({'month': entry.key, 'games': count, 'avgTotal': count == 0 ? 0 : total / count, 'avgMargin': count == 0 ? 0 : margin / count, 'closeGames': close, 'homeWins': homeWins, 'awayWins': awayWins});
  }
  rows.sort((a, b) => _txt(a['month']).compareTo(_txt(b['month'])));
  return rows;
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

int _clamp(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _isOne(Object? value) => value == 1 || value == true || value?.toString() == '1';
String _txt(Object? value) => value?.toString() ?? '—';

String _decimal(Object? value, {int decimals = 2}) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (number == null) return '—';
  return decimals == 0 ? number.round().toString() : number.toStringAsFixed(decimals);
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF657386)),
      filled: true,
      fillColor: terminalPanelDark,
      isDense: true,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalAccent)),
    );
