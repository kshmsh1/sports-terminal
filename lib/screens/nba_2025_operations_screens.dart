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
  Widget build(BuildContext context) => _SeedFuture(builder: (data) {
        final rows = _teamSplits(data.teamGameLogs).where((row) => row.team.toLowerCase().contains(query.trim().toLowerCase())).toList()..sort((a, b) => b.margin.compareTo(a.margin));
        final best = rows.isEmpty ? null : rows.first;
        return _Page(title: '2025 Team Splits', subtitle: 'Home/away split terminal built from generated team-game logs.', children: [
          _Metrics([
            _Metric('Teams', '${rows.length}', query.trim().isEmpty ? 'All loaded teams' : 'Query filtered'),
            _Metric('Best Margin', best?.team ?? '—', best == null ? 'No rows' : best.margin.toStringAsFixed(2)),
            _Metric('Avg Home Win%', rows.isEmpty ? '—' : _avg(rows.map((row) => row.homeWinRate)).toStringAsFixed(3), 'Visible teams'),
            _Metric('Avg Away Win%', rows.isEmpty ? '—' : _avg(rows.map((row) => row.awayWinRate)).toStringAsFixed(3), 'Visible teams'),
          ]),
          _Search(value: query, hint: 'Search team code...', onChanged: (value) => setState(() => query = value)),
          _Table(
            title: 'Team Home/Away Splits',
            subtitle: 'Sorted by overall average margin.',
            columns: const ['Team', 'Games', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Home W-L', 'Home Margin', 'Away W-L', 'Away Margin'],
            rows: [for (final row in rows) [row.team, '${row.games}', row.winRate.toStringAsFixed(3), row.ppg.toStringAsFixed(1), row.oppPpg.toStringAsFixed(1), row.margin.toStringAsFixed(2), '${row.homeWins}-${row.homeLosses}', row.homeMargin.toStringAsFixed(2), '${row.awayWins}-${row.awayLosses}', row.awayMargin.toStringAsFixed(2)]],
          ),
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
  Widget build(BuildContext context) => _SeedFuture(builder: (data) {
        final teamId = team.trim().isEmpty ? 'OKC' : team.trim().toUpperCase();
        final rows = _opponents(data.teamGameLogs, teamId);
        final bestRows = List<_OpponentRow>.from(rows)..sort((a, b) => b.margin.compareTo(a.margin));
        final worstRows = List<_OpponentRow>.from(rows)..sort((a, b) => a.margin.compareTo(b.margin));
        final best = bestRows.isEmpty ? null : bestRows.first;
        final worst = worstRows.isEmpty ? null : worstRows.first;
        return _Page(title: '2025 Opponent Matrix', subtitle: 'Team-vs-opponent matchup matrix from generated team-game logs.', children: [
          _Metrics([
            _Metric('Selected Team', teamId, '${rows.fold<int>(0, (sum, row) => sum + row.games)} games'),
            _Metric('Opponents', '${rows.length}', 'Unique opponents'),
            _Metric('Best Matchup', best?.opponent ?? '—', best == null ? 'No rows' : best.margin.toStringAsFixed(1)),
            _Metric('Worst Matchup', worst?.opponent ?? '—', worst == null ? 'No rows' : worst.margin.toStringAsFixed(1)),
          ]),
          _Search(value: team, hint: 'Enter team code: OKC, BOS, NYK...', onChanged: (value) => setState(() => team = value)),
          _Table(
            title: '$teamId Opponent Matrix',
            subtitle: 'Aggregated across all loaded meetings with each opponent.',
            columns: const ['Opponent', 'Games', 'W-L', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Last Game', 'Last Result'],
            rows: [for (final row in rows) [row.opponent, '${row.games}', '${row.wins}-${row.losses}', row.winRate.toStringAsFixed(3), row.ppg.toStringAsFixed(1), row.oppPpg.toStringAsFixed(1), row.margin.toStringAsFixed(1), row.lastGame, row.lastResult]],
          ),
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
  Widget build(BuildContext context) => _SeedFuture(builder: (data) {
        final rows = _filter(data.playerSeasonTotals, query, const ['player_label', 'player_id', 'team_ids']).map(_role).toList()..sort((a, b) => b.score.compareTo(a.score));
        final buckets = <String, int>{};
        for (final row in rows) {
          buckets[row.role] = (buckets[row.role] ?? 0) + 1;
        }
        return _Page(title: '2025 Player Role Board', subtitle: 'Role classification from games, minutes, scoring, efficiency, and BPM.', children: [
          _Metrics([
            _Metric('Players', '${rows.length}', query.trim().isEmpty ? 'All active summaries' : 'Query filtered'),
            _Metric('Stars', '${buckets['Star'] ?? 0}', 'High usage/scoring'),
            _Metric('Starters', '${buckets['Starter'] ?? 0}', 'High-minute profiles'),
            _Metric('Rotation+', '${(buckets['Rotation'] ?? 0) + (buckets['Specialist'] ?? 0)}', 'Rotation and specialist roles'),
          ]),
          _Search(value: query, hint: 'Search player, team, or id...', onChanged: (value) => setState(() => query = value)),
          _Table(
            title: 'Role Board',
            subtitle: 'Internal sorting heuristic for terminal triage, not a formal value model.',
            columns: const ['Role', 'Score', 'Player', 'Teams', 'GP', 'MPG', 'PPG', 'REB', 'AST', 'TS%', 'BPM'],
            rows: [for (final row in rows.take(150)) [row.role, row.score.toStringAsFixed(2), row.player, row.teams, row.games.round().toString(), row.mpg.toStringAsFixed(1), row.ppg.toStringAsFixed(1), row.rebounds.round().toString(), row.assists.round().toString(), row.ts.toStringAsFixed(3), row.bpm.toStringAsFixed(2)]],
          ),
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
  Widget build(BuildContext context) => _SeedFuture(builder: (data) {
        final minPts = _num(minPoints);
        final bpmGate = _num(minBpm);
        final base = _filter(data.playerGameLogsTop, query, const ['game_id', 'game_date', 'player_label', 'team_id', 'opponent_team_id']);
        final rows = base.where((row) => _num(row['pts']) >= minPts && _num(row['bpm']) >= bpmGate).toList()
          ..sort((a, b) {
            final ptsCompare = _num(b['pts']).compareTo(_num(a['pts']));
            if (ptsCompare != 0) return ptsCompare;
            return _num(b['bpm']).compareTo(_num(a['bpm']));
          });
        return _Page(title: '2025 Box Score Finder', subtitle: 'High-value player-game finder with point and BPM gates.', children: [
          _Metrics([
            _Metric('Matching Rows', '${rows.length}', '${base.length} before gates'),
            _Metric('Min Points', minPts.toStringAsFixed(0), 'Editable gate'),
            _Metric('Min BPM', bpmGate.toStringAsFixed(1), 'Editable gate'),
            _Metric('Top Row', rows.isEmpty ? '—' : _text(rows.first['player_label']), rows.isEmpty ? 'No rows' : '${_decimal(rows.first['pts'], decimals: 0)} pts'),
          ]),
          _TripleSearch(query, minPoints, minBpm, (value) => setState(() => query = value), (value) => setState(() => minPoints = value), (value) => setState(() => minBpm = value)),
          _Table(
            title: 'Box Score Finder Results',
            subtitle: 'Sorted by points, then BPM.',
            columns: const ['Date', 'Game', 'Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', 'STL', 'BLK', '+/-', 'TS%', 'BPM'],
            rows: [for (final row in rows.take(150)) [_text(row['game_date']), _text(row['game_id']), _text(row['player_label']), _text(row['team_id']), _text(row['opponent_team_id']), _text(row['mp_text']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['stl'], decimals: 0), _decimal(row['blk'], decimals: 0), _decimal(row['plus_minus'], decimals: 0), _decimal(row['ts_pct'], decimals: 3), _decimal(row['bpm'])]],
          ),
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
  Widget build(BuildContext context) => _SeedFuture(builder: (data) {
        final size = _num(window).round().clamp(1, 40);
        final rows = _momentum(data.teamGameLogs, size)..sort((a, b) => b.margin.compareTo(a.margin));
        final best = rows.isEmpty ? null : rows.first;
        final worst = rows.isEmpty ? null : rows.last;
        return _Page(title: '2025 Momentum Board', subtitle: 'Recent-form board for every team using the last N generated team-game rows.', children: [
          _Metrics([
            _Metric('Window', '$size games', 'Editable lookback'),
            _Metric('Best Form', best?.team ?? '—', best == null ? 'No rows' : '${best.wins}-${best.losses}, ${best.margin.toStringAsFixed(1)} margin'),
            _Metric('Worst Form', worst?.team ?? '—', worst == null ? 'No rows' : '${worst.wins}-${worst.losses}, ${worst.margin.toStringAsFixed(1)} margin'),
            _Metric('Teams', '${rows.length}', 'Momentum rows'),
          ]),
          _Search(value: window, hint: 'Recent-game window: 5, 10, 20...', onChanged: (value) => setState(() => window = value)),
          _Table(
            title: 'Recent Momentum Ranking',
            subtitle: 'Sorted by average margin over the selected window.',
            columns: const ['Rank', 'Team', 'Games', 'W-L', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Last Game', 'Last Result'],
            rows: [for (var i = 0; i < rows.length; i++) ['${i + 1}', rows[i].team, '${rows[i].games}', '${rows[i].wins}-${rows[i].losses}', rows[i].winRate.toStringAsFixed(3), rows[i].ppg.toStringAsFixed(1), rows[i].oppPpg.toStringAsFixed(1), rows[i].margin.toStringAsFixed(1), rows[i].lastGame, rows[i].lastResult]],
          ),
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
  Widget build(BuildContext context) => _SeedFuture(builder: (data) {
        final allMonths = _months(data.games);
        final months = query.trim().isEmpty ? allMonths : allMonths.where((row) => row.month.contains(query.trim())).toList();
        final selectedGames = _filter(data.games, query, const ['game_date', 'game_id', 'away_team_id', 'home_team_id', 'winner_team_id']);
        final busyRows = List<_MonthRow>.from(months)..sort((a, b) => b.games.compareTo(a.games));
        final busiest = busyRows.isEmpty ? null : busyRows.first;
        return _Page(title: '2025 Season Timeline', subtitle: 'Month-by-month schedule/result terminal from generated games.json.', children: [
          _Metrics([
            _Metric('Months', '${months.length}', query.trim().isEmpty ? 'Full season' : 'Filtered'),
            _Metric('Matching Games', '${selectedGames.length}', 'Query drilldown'),
            _Metric('Busiest Month', busiest?.month ?? '—', busiest == null ? 'No rows' : '${busiest.games} games'),
            _Metric('Close Games', '${months.fold<int>(0, (sum, row) => sum + row.closeGames)}', 'Margin ≤ 5'),
          ]),
          _Search(value: query, hint: 'Filter by month/date/team/game, e.g. 2024-10, BOS...', onChanged: (value) => setState(() => query = value)),
          _Table(
            title: 'Season Timeline by Month',
            subtitle: 'Aggregated by game_date month.',
            columns: const ['Month', 'Games', 'Avg Total', 'Avg Margin', 'Close Games', 'Home Wins', 'Away Wins'],
            rows: [for (final row in months) [row.month, '${row.games}', row.avgTotal.toStringAsFixed(1), row.avgMargin.toStringAsFixed(1), '${row.closeGames}', '${row.homeWins}', '${row.awayWins}']],
          ),
          _Table(
            title: 'Selected Games',
            subtitle: 'Games matching the current query.',
            columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Winner', 'Margin'],
            rows: [for (final row in selectedGames.take(100)) [_text(row['game_date']), _text(row['game_id']), _text(row['away_team_id']), _text(row['away_score']), _text(row['home_team_id']), _text(row['home_score']), _text(row['winner_team_id']), (_num(row['home_score']) - _num(row['away_score'])).abs().round().toString()]],
          ),
        ]);
      });
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: title, subtitle: subtitle),
        for (final child in children) ...[const SizedBox(height: 22), child],
      ]);
}

class _SeedFuture extends StatelessWidget {
  const _SeedFuture({required this.builder});
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
  const _Search({required this.value, required this.hint, required this.onChanged});
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

class _Metrics extends StatelessWidget {
  const _Metrics(this.metrics);
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
  const _Table({required this.title, required this.subtitle, required this.columns, required this.rows});
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

class _SplitRow {
  const _SplitRow({required this.team, required this.games, required this.wins, required this.losses, required this.points, required this.oppPoints, required this.totalMargin, required this.homeGames, required this.homeWins, required this.homeLosses, required this.homeTotalMargin, required this.awayGames, required this.awayWins, required this.awayLosses, required this.awayTotalMargin});
  final String team;
  final int games;
  final int wins;
  final int losses;
  final double points;
  final double oppPoints;
  final double totalMargin;
  final int homeGames;
  final int homeWins;
  final int homeLosses;
  final double homeTotalMargin;
  final int awayGames;
  final int awayWins;
  final int awayLosses;
  final double awayTotalMargin;
  double get winRate => games == 0 ? 0 : wins / games;
  double get homeWinRate => homeGames == 0 ? 0 : homeWins / homeGames;
  double get awayWinRate => awayGames == 0 ? 0 : awayWins / awayGames;
  double get ppg => games == 0 ? 0 : points / games;
  double get oppPpg => games == 0 ? 0 : oppPoints / games;
  double get margin => games == 0 ? 0 : totalMargin / games;
  double get homeMargin => homeGames == 0 ? 0 : homeTotalMargin / homeGames;
  double get awayMargin => awayGames == 0 ? 0 : awayTotalMargin / awayGames;
}

class _SplitBuilder {
  _SplitBuilder(this.team);
  final String team;
  int games = 0;
  int wins = 0;
  int losses = 0;
  double points = 0;
  double oppPoints = 0;
  double totalMargin = 0;
  int homeGames = 0;
  int homeWins = 0;
  int homeLosses = 0;
  double homeTotalMargin = 0;
  int awayGames = 0;
  int awayWins = 0;
  int awayLosses = 0;
  double awayTotalMargin = 0;
}

class _OpponentRow {
  const _OpponentRow({required this.opponent, required this.games, required this.wins, required this.losses, required this.points, required this.oppPoints, required this.totalMargin, required this.lastGame, required this.lastResult});
  final String opponent;
  final int games;
  final int wins;
  final int losses;
  final double points;
  final double oppPoints;
  final double totalMargin;
  final String lastGame;
  final String lastResult;
  double get winRate => games == 0 ? 0 : wins / games;
  double get ppg => games == 0 ? 0 : points / games;
  double get oppPpg => games == 0 ? 0 : oppPoints / games;
  double get margin => games == 0 ? 0 : totalMargin / games;
}

class _OpponentBuilder {
  _OpponentBuilder(this.opponent);
  final String opponent;
  int games = 0;
  int wins = 0;
  int losses = 0;
  double points = 0;
  double oppPoints = 0;
  double totalMargin = 0;
  String lastGame = '—';
  String lastResult = '—';
}

class _RoleRow {
  const _RoleRow({required this.player, required this.teams, required this.role, required this.score, required this.games, required this.mpg, required this.ppg, required this.rebounds, required this.assists, required this.ts, required this.bpm});
  final String player;
  final String teams;
  final String role;
  final double score;
  final double games;
  final double mpg;
  final double ppg;
  final double rebounds;
  final double assists;
  final double ts;
  final double bpm;
}

class _MomentumRow {
  const _MomentumRow({required this.team, required this.games, required this.wins, required this.losses, required this.points, required this.oppPoints, required this.totalMargin, required this.lastGame, required this.lastResult});
  final String team;
  final int games;
  final int wins;
  final int losses;
  final double points;
  final double oppPoints;
  final double totalMargin;
  final String lastGame;
  final String lastResult;
  double get winRate => games == 0 ? 0 : wins / games;
  double get ppg => games == 0 ? 0 : points / games;
  double get oppPpg => games == 0 ? 0 : oppPoints / games;
  double get margin => games == 0 ? 0 : totalMargin / games;
}

class _MonthRow {
  const _MonthRow({required this.month, required this.games, required this.totalPoints, required this.totalMargin, required this.closeGames, required this.homeWins, required this.awayWins});
  final String month;
  final int games;
  final double totalPoints;
  final double totalMargin;
  final int closeGames;
  final int homeWins;
  final int awayWins;
  double get avgTotal => games == 0 ? 0 : totalPoints / games;
  double get avgMargin => games == 0 ? 0 : totalMargin / games;
}

List<_SplitRow> _teamSplits(List<Map<String, dynamic>> logs) {
  final builders = <String, _SplitBuilder>{};
  for (final log in logs) {
    final team = _text(log['team_id']);
    final row = builders.putIfAbsent(team, () => _SplitBuilder(team));
    final result = _text(log['result']).toUpperCase();
    final margin = _num(log['margin']);
    final home = _isOne(log['is_home']);
    row.games += 1;
    row.points += _num(log['points']);
    row.oppPoints += _num(log['opponent_points']);
    row.totalMargin += margin;
    if (result == 'W') row.wins += 1;
    if (result == 'L') row.losses += 1;
    if (home) {
      row.homeGames += 1;
      row.homeTotalMargin += margin;
      if (result == 'W') row.homeWins += 1;
      if (result == 'L') row.homeLosses += 1;
    } else {
      row.awayGames += 1;
      row.awayTotalMargin += margin;
      if (result == 'W') row.awayWins += 1;
      if (result == 'L') row.awayLosses += 1;
    }
  }
  return [for (final row in builders.values) _SplitRow(team: row.team, games: row.games, wins: row.wins, losses: row.losses, points: row.points, oppPoints: row.oppPoints, totalMargin: row.totalMargin, homeGames: row.homeGames, homeWins: row.homeWins, homeLosses: row.homeLosses, homeTotalMargin: row.homeTotalMargin, awayGames: row.awayGames, awayWins: row.awayWins, awayLosses: row.awayLosses, awayTotalMargin: row.awayTotalMargin)];
}

List<_OpponentRow> _opponents(List<Map<String, dynamic>> logs, String teamId) {
  final builders = <String, _OpponentBuilder>{};
  for (final log in logs) {
    if (_text(log['team_id']).toUpperCase() != teamId) continue;
    final opponent = _text(log['opponent_team_id']);
    final row = builders.putIfAbsent(opponent, () => _OpponentBuilder(opponent));
    final result = _text(log['result']).toUpperCase();
    row.games += 1;
    row.points += _num(log['points']);
    row.oppPoints += _num(log['opponent_points']);
    row.totalMargin += _num(log['margin']);
    if (result == 'W') row.wins += 1;
    if (result == 'L') row.losses += 1;
    row.lastGame = _text(log['game_id']);
    row.lastResult = result;
  }
  final rows = [for (final row in builders.values) _OpponentRow(opponent: row.opponent, games: row.games, wins: row.wins, losses: row.losses, points: row.points, oppPoints: row.oppPoints, totalMargin: row.totalMargin, lastGame: row.lastGame, lastResult: row.lastResult)];
  rows.sort((a, b) {
    final gameCompare = b.games.compareTo(a.games);
    if (gameCompare != 0) return gameCompare;
    return b.margin.compareTo(a.margin);
  });
  return rows;
}

_RoleRow _role(Map<String, dynamic> row) {
  final games = _num(row['games']);
  final mpg = _num(row['minutes_per_game']);
  final ppg = _num(row['points_per_game']);
  final bpm = _num(row['avg_bpm']);
  final ts = _num(row['avg_ts_pct']);
  final role = ppg >= 25 && mpg >= 30 ? 'Star' : mpg >= 28 ? 'Starter' : mpg >= 15 ? 'Rotation' : games >= 20 ? 'Specialist' : 'Depth';
  final score = ppg + bpm + (mpg / 3) + (ts * 4);
  return _RoleRow(player: _text(row['player_label']), teams: _text(row['team_ids']), role: role, score: score, games: games, mpg: mpg, ppg: ppg, rebounds: _num(row['rebounds']), assists: _num(row['assists']), ts: ts, bpm: bpm);
}

List<_MomentumRow> _momentum(List<Map<String, dynamic>> logs, int window) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in logs) {
    grouped.putIfAbsent(_text(row['team_id']), () => <Map<String, dynamic>>[]).add(row);
  }
  final out = <_MomentumRow>[];
  for (final entry in grouped.entries) {
    final recent = entry.value.length <= window ? entry.value : entry.value.sublist(entry.value.length - window);
    var wins = 0;
    var losses = 0;
    var points = 0.0;
    var opp = 0.0;
    var margin = 0.0;
    for (final row in recent) {
      final result = _text(row['result']).toUpperCase();
      if (result == 'W') wins += 1;
      if (result == 'L') losses += 1;
      points += _num(row['points']);
      opp += _num(row['opponent_points']);
      margin += _num(row['margin']);
    }
    final last = recent.isEmpty ? null : recent.last;
    out.add(_MomentumRow(team: entry.key, games: recent.length, wins: wins, losses: losses, points: points, oppPoints: opp, totalMargin: margin, lastGame: _text(last?['game_id']), lastResult: _text(last?['result'])));
  }
  return out;
}

List<_MonthRow> _months(List<Map<String, dynamic>> games) {
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final game in games) {
    final date = _text(game['game_date']);
    if (date.length >= 7) buckets.putIfAbsent(date.substring(0, 7), () => <Map<String, dynamic>>[]).add(game);
  }
  final rows = <_MonthRow>[];
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
      if (_text(game['winner_team_id']) == _text(game['home_team_id'])) {
        homeWins += 1;
      } else {
        awayWins += 1;
      }
    }
    rows.add(_MonthRow(month: entry.key, games: entry.value.length, totalPoints: total, totalMargin: margin, closeGames: close, homeWins: homeWins, awayWins: awayWins));
  }
  rows.sort((a, b) => a.month.compareTo(b.month));
  return rows;
}

List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> rows, String query, List<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((row) => fields.map((field) => _text(row[field])).join(' ').toLowerCase().contains(q)).toList();
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

String _decimal(Object? value, {int decimals = 3}) {
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
