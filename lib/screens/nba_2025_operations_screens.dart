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
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final rows = _buildTeamSplitRows(data.teamGameLogs).where((row) => row.teamId.toLowerCase().contains(query.trim().toLowerCase())).toList()
        ..sort((a, b) => b.avgMargin.compareTo(a.avgMargin));
      final best = rows.isEmpty ? null : rows.first;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Team Splits',
          subtitle: 'Home/away split terminal built from generated team-game logs: win rates, scoring, margins, and home-road differences.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Teams', '${rows.length}', query.trim().isEmpty ? 'All loaded teams' : 'Query filtered'),
          _MetricSpec('Best Margin', best?.teamId ?? '—', best == null ? 'No rows' : best.avgMargin.toStringAsFixed(2)),
          _MetricSpec('Avg Home Win%', rows.isEmpty ? '—' : _avg(rows.map((row) => row.homeWinRate)).toStringAsFixed(3), 'Visible teams'),
          _MetricSpec('Avg Away Win%', rows.isEmpty ? '—' : _avg(rows.map((row) => row.awayWinRate)).toStringAsFixed(3), 'Visible teams'),
        ]),
        const SizedBox(height: 22),
        _SearchBox(value: query, hint: 'Search team code...', onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Team Home/Away Splits',
          subtitle: 'Sorted by overall average margin from team_game_logs.json.',
          columns: const ['Team', 'Games', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Home W-L', 'Home Margin', 'Away W-L', 'Away Margin'],
          rows: [
            for (final row in rows)
              [
                row.teamId,
                '${row.games}',
                row.winRate.toStringAsFixed(3),
                row.ppg.toStringAsFixed(1),
                row.oppPpg.toStringAsFixed(1),
                row.avgMargin.toStringAsFixed(2),
                '${row.homeWins}-${row.homeLosses}',
                row.homeMargin.toStringAsFixed(2),
                '${row.awayWins}-${row.awayLosses}',
                row.awayMargin.toStringAsFixed(2),
              ],
          ],
        ),
      ]);
    });
  }
}

class Nba2025OpponentMatrixScreen extends StatefulWidget {
  const Nba2025OpponentMatrixScreen({super.key});

  @override
  State<Nba2025OpponentMatrixScreen> createState() => _Nba2025OpponentMatrixScreenState();
}

class _Nba2025OpponentMatrixScreenState extends State<Nba2025OpponentMatrixScreen> {
  String team = 'OKC';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final teamId = team.trim().isEmpty ? 'OKC' : team.trim().toUpperCase();
      final rows = _buildOpponentRows(data.teamGameLogs, teamId);
      final best = rows.isEmpty ? null : [...rows]..sort((a, b) => b.avgMargin.compareTo(a.avgMargin));
      final worst = rows.isEmpty ? null : [...rows]..sort((a, b) => a.avgMargin.compareTo(b.avgMargin));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Opponent Matrix',
          subtitle: 'Team-vs-opponent terminal from team-game logs. Use this to inspect matchup records, scoring, margins, and recent meetings for one team.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Selected Team', teamId, '${rows.fold<int>(0, (sum, row) => sum + row.games)} games'),
          _MetricSpec('Opponents', '${rows.length}', 'Unique opponents'),
          _MetricSpec('Best Matchup', best == null ? '—' : best.first.opponent, best == null ? 'No rows' : best.first.avgMargin.toStringAsFixed(1)),
          _MetricSpec('Worst Matchup', worst == null ? '—' : worst.first.opponent, worst == null ? 'No rows' : worst.first.avgMargin.toStringAsFixed(1)),
        ]),
        const SizedBox(height: 22),
        _SearchBox(value: team, hint: 'Enter team code: OKC, BOS, NYK...', onChanged: (value) => setState(() => team = value)),
        const SizedBox(height: 22),
        _TablePanel(
          title: '$teamId Opponent Matrix',
          subtitle: 'Aggregated from every team-game row for the selected team.',
          columns: const ['Opponent', 'Games', 'W-L', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Last Game', 'Last Result'],
          rows: [
            for (final row in rows)
              [row.opponent, '${row.games}', '${row.wins}-${row.losses}', row.winRate.toStringAsFixed(3), row.ppg.toStringAsFixed(1), row.oppPpg.toStringAsFixed(1), row.avgMargin.toStringAsFixed(1), row.lastGame, row.lastResult],
          ],
        ),
      ]);
    });
  }
}

class Nba2025PlayerRoleBoardScreen extends StatefulWidget {
  const Nba2025PlayerRoleBoardScreen({super.key});

  @override
  State<Nba2025PlayerRoleBoardScreen> createState() => _Nba2025PlayerRoleBoardScreenState();
}

class _Nba2025PlayerRoleBoardScreenState extends State<Nba2025PlayerRoleBoardScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final rows = _filter(data.playerSeasonTotals, query, const ['player_label', 'player_id', 'team_ids']).map(_roleRow).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      final buckets = <String, int>{};
      for (final row in rows) {
        buckets[row.role] = (buckets[row.role] ?? 0) + 1;
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Player Role Board',
          subtitle: 'Role-classification terminal from loaded-season player summaries. Roles are generated from minutes, scoring, games, and efficiency proxies.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Players', '${rows.length}', query.trim().isEmpty ? 'All active summaries' : 'Query filtered'),
          _MetricSpec('Stars', '${buckets['Star'] ?? 0}', 'PPG/minute driven'),
          _MetricSpec('Starters', '${buckets['Starter'] ?? 0}', 'High-minute profiles'),
          _MetricSpec('Rotation+', '${(buckets['Rotation'] ?? 0) + (buckets['Specialist'] ?? 0)}', 'Rotation and specialist roles'),
        ]),
        const SizedBox(height: 22),
        _SearchBox(value: query, hint: 'Search player, id, or team...', onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Role Board',
          subtitle: 'Internal heuristic: role and score are for terminal sorting and triage, not a formal player value model.',
          columns: const ['Role', 'Score', 'Player', 'Teams', 'GP', 'MPG', 'PPG', 'REB', 'AST', 'TS%', 'BPM'],
          rows: [
            for (final row in rows.take(150))
              [row.role, row.score.toStringAsFixed(2), row.player, row.teams, row.games.round().toString(), row.mpg.toStringAsFixed(1), row.ppg.toStringAsFixed(1), row.rebounds.round().toString(), row.assists.round().toString(), row.ts.toStringAsFixed(3), row.bpm.toStringAsFixed(2)],
          ],
        ),
      ]);
    });
  }
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
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final minPts = _num(minPoints);
      final bpmGate = _num(minBpm);
      final base = _filter(data.playerGameLogsTop, query, const ['game_id', 'game_date', 'player_label', 'team_id', 'opponent_team_id']);
      final rows = base.where((row) => _num(row['pts']) >= minPts && _num(row['bpm']) >= bpmGate).toList()
        ..sort((a, b) {
          final ptsCompare = _num(b['pts']).compareTo(_num(a['pts']));
          if (ptsCompare != 0) return ptsCompare;
          return _num(b['bpm']).compareTo(_num(a['bpm']));
        });
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Box Score Finder',
          subtitle: 'High-value player-game finder for compact box-score rows. Search player/team/game and apply point/BPM gates.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Matching Rows', '${rows.length}', '${base.length} before gates'),
          _MetricSpec('Min Points', minPts.toStringAsFixed(0), 'Editable gate'),
          _MetricSpec('Min BPM', bpmGate.toStringAsFixed(1), 'Editable gate'),
          _MetricSpec('Top Row', rows.isEmpty ? '—' : _text(rows.first['player_label']), rows.isEmpty ? 'No rows' : '${_decimal(rows.first['pts'], decimals: 0)} pts'),
        ]),
        const SizedBox(height: 22),
        _TripleSearchBox(
          firstValue: query,
          firstHint: 'Search player, team, game...',
          firstChanged: (value) => setState(() => query = value),
          secondValue: minPoints,
          secondHint: 'Min points',
          secondChanged: (value) => setState(() => minPoints = value),
          thirdValue: minBpm,
          thirdHint: 'Min BPM',
          thirdChanged: (value) => setState(() => minBpm = value),
        ),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Box Score Finder Results',
          subtitle: 'Sorted by points, then BPM.',
          columns: const ['Date', 'Game', 'Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', 'STL', 'BLK', '+/-', 'TS%', 'BPM'],
          rows: [
            for (final row in rows.take(150))
              [_text(row['game_date']), _text(row['game_id']), _text(row['player_label']), _text(row['team_id']), _text(row['opponent_team_id']), _text(row['mp_text']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['stl'], decimals: 0), _decimal(row['blk'], decimals: 0), _decimal(row['plus_minus'], decimals: 0), _decimal(row['ts_pct'], decimals: 3), _decimal(row['bpm'])],
          ],
        ),
      ]);
    });
  }
}

class Nba2025MomentumBoardScreen extends StatefulWidget {
  const Nba2025MomentumBoardScreen({super.key});

  @override
  State<Nba2025MomentumBoardScreen> createState() => _Nba2025MomentumBoardScreenState();
}

class _Nba2025MomentumBoardScreenState extends State<Nba2025MomentumBoardScreen> {
  String window = '10';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final size = _num(window).round().clamp(1, 40);
      final rows = _buildMomentumRows(data.teamGameLogs, size)..sort((a, b) => b.avgMargin.compareTo(a.avgMargin));
      final best = rows.isEmpty ? null : rows.first;
      final worst = rows.isEmpty ? null : rows.last;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Momentum Board',
          subtitle: 'Recent-form board for every team using the last N generated team-game rows. Adjust N to compare recent momentum windows.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Window', '$size games', 'Editable recent-game lookback'),
          _MetricSpec('Best Form', best?.teamId ?? '—', best == null ? 'No rows' : '${best.wins}-${best.losses}, ${best.avgMargin.toStringAsFixed(1)} margin'),
          _MetricSpec('Worst Form', worst?.teamId ?? '—', worst == null ? 'No rows' : '${worst.wins}-${worst.losses}, ${worst.avgMargin.toStringAsFixed(1)} margin'),
          _MetricSpec('Teams', '${rows.length}', 'Momentum rows'),
        ]),
        const SizedBox(height: 22),
        _SearchBox(value: window, hint: 'Recent-game window: 5, 10, 20...', onChanged: (value) => setState(() => window = value)),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Recent Momentum Ranking',
          subtitle: 'Sorted by average margin over the selected recent-game window.',
          columns: const ['Rank', 'Team', 'Games', 'W-L', 'Win%', 'PPG', 'Opp PPG', 'Margin', 'Last Game', 'Last Result'],
          rows: [
            for (var i = 0; i < rows.length; i++)
              ['${i + 1}', rows[i].teamId, '${rows[i].games}', '${rows[i].wins}-${rows[i].losses}', rows[i].winRate.toStringAsFixed(3), rows[i].ppg.toStringAsFixed(1), rows[i].oppPpg.toStringAsFixed(1), rows[i].avgMargin.toStringAsFixed(1), rows[i].lastGame, rows[i].lastResult],
          ],
        ),
      ]);
    });
  }
}

class Nba2025SeasonTimelineScreen extends StatefulWidget {
  const Nba2025SeasonTimelineScreen({super.key});

  @override
  State<Nba2025SeasonTimelineScreen> createState() => _Nba2025SeasonTimelineScreenState();
}

class _Nba2025SeasonTimelineScreenState extends State<Nba2025SeasonTimelineScreen> {
  String monthQuery = '';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(builder: (data) {
      final months = _buildMonthRows(data.games).where((row) => row.month.contains(monthQuery.trim())).toList();
      final selectedGames = _filter(data.games, monthQuery, const ['game_date', 'game_id', 'away_team_id', 'home_team_id', 'winner_team_id']);
      final busiest = months.isEmpty ? null : [...months]..sort((a, b) => b.games.compareTo(a.games));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
          title: '2025 Season Timeline',
          subtitle: 'Month-by-month schedule/result terminal from generated games.json, with scoring totals, close games, and selected-game drilldown.',
        ),
        const SizedBox(height: 22),
        _MetricGrid(metrics: [
          _MetricSpec('Months', '${months.length}', monthQuery.trim().isEmpty ? 'Full season' : 'Filtered'),
          _MetricSpec('Matching Games', '${selectedGames.length}', 'Query drilldown'),
          _MetricSpec('Busiest Month', busiest == null ? '—' : busiest.first.month, busiest == null ? 'No rows' : '${busiest.first.games} games'),
          _MetricSpec('Close Games', '${months.fold<int>(0, (sum, row) => sum + row.closeGames)}', 'Margin ≤ 5'),
        ]),
        const SizedBox(height: 22),
        _SearchBox(value: monthQuery, hint: 'Filter by month/date/team/game, e.g. 2024-10, 2025-06, BOS...', onChanged: (value) => setState(() => monthQuery = value)),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Season Timeline by Month',
          subtitle: 'Aggregated from games.json by game_date month.',
          columns: const ['Month', 'Games', 'Avg Total', 'Avg Margin', 'Close Games', 'Home Wins', 'Away Wins'],
          rows: [for (final row in months) [row.month, '${row.games}', row.avgTotal.toStringAsFixed(1), row.avgMargin.toStringAsFixed(1), '${row.closeGames}', '${row.homeWins}', '${row.awayWins}']],
        ),
        const SizedBox(height: 22),
        _TablePanel(
          title: 'Selected Games',
          subtitle: 'Games matching the current query.',
          columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Winner', 'Margin'],
          rows: [
            for (final row in selectedGames.take(100))
              [_text(row['game_date']), _text(row['game_id']), _text(row['away_team_id']), _text(row['away_score']), _text(row['home_team_id']), _text(row['home_score']), _text(row['winner_team_id']), (_num(row['home_score']) - _num(row['away_score'])).abs().round().toString()],
          ],
        ),
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
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading NBA 2025 operations assets...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load NBA 2025 generated assets: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }
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
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final wide = compact ? constraints.maxWidth : 360.0;
          final narrow = compact ? constraints.maxWidth : 160.0;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: wide, child: TextField(controller: TextEditingController(text: firstValue), onChanged: firstChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration(firstHint))),
            SizedBox(width: narrow, child: TextField(controller: TextEditingController(text: secondValue), onChanged: secondChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration(secondHint))),
            SizedBox(width: narrow, child: TextField(controller: TextEditingController(text: thirdValue), onChanged: thirdChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration(thirdHint))),
          ]);
        }),
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
                rows: [
                  for (final row in rows)
                    DataRow(cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 32 ? 280 : 110, child: Text(cell, overflow: TextOverflow.ellipsis)))]),
                ],
              ),
            ),
        ]),
      );
}

class _TeamSplitRow {
  const _TeamSplitRow({required this.teamId, required this.games, required this.wins, required this.losses, required this.points, required this.oppPoints, required this.margin, required this.homeGames, required this.homeWins, required this.homeLosses, required this.homeMarginTotal, required this.awayGames, required this.awayWins, required this.awayLosses, required this.awayMarginTotal});
  final String teamId;
  final int games;
  final int wins;
  final int losses;
  final double points;
  final double oppPoints;
  final double margin;
  final int homeGames;
  final int homeWins;
  final int homeLosses;
  final double homeMarginTotal;
  final int awayGames;
  final int awayWins;
  final int awayLosses;
  final double awayMarginTotal;
  double get winRate => games == 0 ? 0 : wins / games;
  double get homeWinRate => homeGames == 0 ? 0 : homeWins / homeGames;
  double get awayWinRate => awayGames == 0 ? 0 : awayWins / awayGames;
  double get ppg => games == 0 ? 0 : points / games;
  double get oppPpg => games == 0 ? 0 : oppPoints / games;
  double get avgMargin => games == 0 ? 0 : margin / games;
  double get homeMargin => homeGames == 0 ? 0 : homeMarginTotal / homeGames;
  double get awayMargin => awayGames == 0 ? 0 : awayMarginTotal / awayGames;
}

class _TeamSplitBuilder {
  _TeamSplitBuilder(this.teamId);
  final String teamId;
  int games = 0;
  int wins = 0;
  int losses = 0;
  double points = 0;
  double oppPoints = 0;
  double margin = 0;
  int homeGames = 0;
  int homeWins = 0;
  int homeLosses = 0;
  double homeMarginTotal = 0;
  int awayGames = 0;
  int awayWins = 0;
  int awayLosses = 0;
  double awayMarginTotal = 0;
  _TeamSplitRow freeze() => _TeamSplitRow(teamId: teamId, games: games, wins: wins, losses: losses, points: points, oppPoints: oppPoints, margin: margin, homeGames: homeGames, homeWins: homeWins, homeLosses: homeLosses, homeMarginTotal: homeMarginTotal, awayGames: awayGames, awayWins: awayWins, awayLosses: awayLosses, awayMarginTotal: awayMarginTotal);
}

class _OpponentRow {
  const _OpponentRow({required this.opponent, required this.games, required this.wins, required this.losses, required this.points, required this.oppPoints, required this.margin, required this.lastGame, required this.lastResult});
  final String opponent;
  final int games;
  final int wins;
  final int losses;
  final double points;
  final double oppPoints;
  final double margin;
  final String lastGame;
  final String lastResult;
  double get winRate => games == 0 ? 0 : wins / games;
  double get ppg => games == 0 ? 0 : points / games;
  double get oppPpg => games == 0 ? 0 : oppPoints / games;
  double get avgMargin => games == 0 ? 0 : margin / games;
}

class _OpponentBuilder {
  _OpponentBuilder(this.opponent);
  final String opponent;
  int games = 0;
  int wins = 0;
  int losses = 0;
  double points = 0;
  double oppPoints = 0;
  double margin = 0;
  String lastGame = '—';
  String lastResult = '—';
  _OpponentRow freeze() => _OpponentRow(opponent: opponent, games: games, wins: wins, losses: losses, points: points, oppPoints: oppPoints, margin: margin, lastGame: lastGame, lastResult: lastResult);
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
  const _MomentumRow({required this.teamId, required this.games, required this.wins, required this.losses, required this.points, required this.oppPoints, required this.margin, required this.lastGame, required this.lastResult});
  final String teamId;
  final int games;
  final int wins;
  final int losses;
  final double points;
  final double oppPoints;
  final double margin;
  final String lastGame;
  final String lastResult;
  double get winRate => games == 0 ? 0 : wins / games;
  double get ppg => games == 0 ? 0 : points / games;
  double get oppPpg => games == 0 ? 0 : oppPoints / games;
  double get avgMargin => games == 0 ? 0 : margin / games;
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

List<_TeamSplitRow> _buildTeamSplitRows(List<Map<String, dynamic>> logs) {
  final builders = <String, _TeamSplitBuilder>{};
  for (final log in logs) {
    final team = _text(log['team_id']);
    if (team == '—') continue;
    final row = builders.putIfAbsent(team, () => _TeamSplitBuilder(team));
    final result = _text(log['result']).toUpperCase();
    final isHome = _isOne(log['is_home']);
    final margin = _num(log['margin']);
    row.games += 1;
    row.points += _num(log['points']);
    row.oppPoints += _num(log['opponent_points']);
    row.margin += margin;
    if (result == 'W') row.wins += 1;
    if (result == 'L') row.losses += 1;
    if (isHome) {
      row.homeGames += 1;
      row.homeMarginTotal += margin;
      if (result == 'W') row.homeWins += 1;
      if (result == 'L') row.homeLosses += 1;
    } else {
      row.awayGames += 1;
      row.awayMarginTotal += margin;
      if (result == 'W') row.awayWins += 1;
      if (result == 'L') row.awayLosses += 1;
    }
  }
  return [for (final builder in builders.values) builder.freeze()];
}

List<_OpponentRow> _buildOpponentRows(List<Map<String, dynamic>> logs, String teamId) {
  final builders = <String, _OpponentBuilder>{};
  for (final log in logs) {
    if (_text(log['team_id']).toUpperCase() != teamId) continue;
    final opponent = _text(log['opponent_team_id']);
    final row = builders.putIfAbsent(opponent, () => _OpponentBuilder(opponent));
    final result = _text(log['result']).toUpperCase();
    row.games += 1;
    row.points += _num(log['points']);
    row.oppPoints += _num(log['opponent_points']);
    row.margin += _num(log['margin']);
    if (result == 'W') row.wins += 1;
    if (result == 'L') row.losses += 1;
    row.lastGame = _text(log['game_id']);
    row.lastResult = result;
  }
  final rows = [for (final builder in builders.values) builder.freeze()];
  rows.sort((a, b) {
    final gameCompare = b.games.compareTo(a.games);
    if (gameCompare != 0) return gameCompare;
    return b.avgMargin.compareTo(a.avgMargin);
  });
  return rows;
}

_RoleRow _roleRow(Map<String, dynamic> row) {
  final games = _num(row['games']);
  final mpg = _num(row['minutes_per_game']);
  final ppg = _num(row['points_per_game']);
  final bpm = _num(row['avg_bpm']);
  final ts = _num(row['avg_ts_pct']);
  final role = ppg >= 25 && mpg >= 30
      ? 'Star'
      : mpg >= 28
          ? 'Starter'
          : mpg >= 15
              ? 'Rotation'
              : games >= 20
                  ? 'Specialist'
                  : 'Depth';
  final score = ppg + bpm + (mpg / 3) + (ts * 4);
  return _RoleRow(player: _text(row['player_label']), teams: _text(row['team_ids']), role: role, score: score, games: games, mpg: mpg, ppg: ppg, rebounds: _num(row['rebounds']), assists: _num(row['assists']), ts: ts, bpm: bpm);
}

List<_MomentumRow> _buildMomentumRows(List<Map<String, dynamic>> logs, int window) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in logs) {
    final team = _text(row['team_id']);
    grouped.putIfAbsent(team, () => <Map<String, dynamic>>[]).add(row);
  }
  final output = <_MomentumRow>[];
  for (final entry in grouped.entries) {
    final teamLogs = entry.value;
    final recent = teamLogs.length <= window ? teamLogs : teamLogs.sublist(teamLogs.length - window);
    var wins = 0;
    var losses = 0;
    var points = 0.0;
    var oppPoints = 0.0;
    var margin = 0.0;
    for (final row in recent) {
      final result = _text(row['result']).toUpperCase();
      if (result == 'W') wins += 1;
      if (result == 'L') losses += 1;
      points += _num(row['points']);
      oppPoints += _num(row['opponent_points']);
      margin += _num(row['margin']);
    }
    final last = recent.isEmpty ? null : recent.last;
    output.add(_MomentumRow(teamId: entry.key, games: recent.length, wins: wins, losses: losses, points: points, oppPoints: oppPoints, margin: margin, lastGame: _text(last?['game_id']), lastResult: _text(last?['result'])));
  }
  return output;
}

List<_MonthRow> _buildMonthRows(List<Map<String, dynamic>> games) {
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final game in games) {
    final date = _text(game['game_date']);
    if (date.length < 7) continue;
    buckets.putIfAbsent(date.substring(0, 7), () => <Map<String, dynamic>>[]).add(game);
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
