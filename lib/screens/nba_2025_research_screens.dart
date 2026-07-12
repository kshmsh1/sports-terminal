import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../widgets/terminal_primitives.dart';

class Nba2025CommandCenterScreen extends StatelessWidget {
  const Nba2025CommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      builder: (data) {
        final ppgLeaders = _asMapList(data.playerLeaders['points_per_game']);
        final scoringHighs = _asMapList(data.playerGameHighs['points']);
        final validationChecks = _asMapList(data.validationReport?['checks']);
        final lastGames = data.games.length <= 10 ? data.games : data.games.sublist(data.games.length - 10);
        final totalPoints = data.teamRecords.fold<double>(0, (sum, row) => sum + _num(row['points']));
        final totalGames = data.games.length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Command Center',
            subtitle: 'Executive NBA terminal overview powered by the generated 2024-25 warehouse asset mirror: pipeline health, coverage, leaders, top teams, recent games, and source-ready counts.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Validation', data.validationStatus.toUpperCase(), 'Generated seed gate'),
            _MetricSpec('Games', '$totalGames', 'Regular season + playoffs'),
            _MetricSpec('Players', '${data.playerSeasonTotals.length}', '${data.players.length} identities'),
            _MetricSpec('Team Points', totalPoints.round().toString(), 'All loaded team records'),
            _MetricSpec('Team Games', '${data.teamGameLogs.length}', 'One row per team-game'),
            _MetricSpec('Player Game Rows', '${data.playerGameLogsTop.length}', 'Compact high-value rows'),
            _MetricSpec('PBP Events', _compactNumber(data.playByPlayEvents), 'Normalized event count'),
            _MetricSpec('Asset Files', '${data.copiedAssetFiles}', 'Synced into Flutter'),
          ]),
          const SizedBox(height: 22),
          _TwoColumnLayout(
            left: _TablePanel(
              title: 'Top Team Records',
              subtitle: 'Sorted by generated team_records.json order.',
              columns: const ['Team', 'Games', 'W', 'L', 'PPG', 'Opp PPG', 'Margin'],
              rows: [
                for (final row in data.teamRecords.take(10))
                  [_text(row['team_id']), _text(row['games']), _text(row['wins']), _text(row['losses']), _decimal(row['points_per_game']), _decimal(row['opponent_points_per_game']), _decimal(row['average_margin'])],
              ],
            ),
            right: _TablePanel(
              title: 'Scoring Leaders',
              subtitle: 'Top points-per-game leaderboard slice.',
              columns: const ['Player', 'GP', 'PTS', 'PPG', 'REB', 'AST'],
              rows: [
                for (final row in ppgLeaders.take(10))
                  [_text(row['player_label']), _text(row['games']), _decimal(row['points'], decimals: 0), _decimal(row['points_per_game']), _decimal(row['rebounds'], decimals: 0), _decimal(row['assists'], decimals: 0)],
              ],
            ),
          ),
          const SizedBox(height: 22),
          _TwoColumnLayout(
            left: _TablePanel(
              title: 'Recent Loaded Games',
              subtitle: 'Tail of generated games.json.',
              columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Winner'],
              rows: [
                for (final row in lastGames.reversed)
                  [_text(row['game_date']), _text(row['game_id']), _text(row['away_team_id']), _text(row['away_score']), _text(row['home_team_id']), _text(row['home_score']), _text(row['winner_team_id'])],
              ],
            ),
            right: _TablePanel(
              title: 'Single-Game Scoring Highs',
              subtitle: 'Top scoring rows from generated high boards.',
              columns: const ['Date', 'Player', 'Team', 'Opp', 'PTS', 'Game'],
              rows: [
                for (final row in scoringHighs.take(10))
                  [_text(row['game_date']), _text(row['player_label']), _text(row['team_id']), _text(row['opponent_team_id']), _decimal(row['pts'], decimals: 0), _text(row['game_id'])],
              ],
            ),
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Pipeline Validation Snapshot',
            subtitle: 'First validation gates from validation_report.json.',
            columns: const ['Check', 'Status', 'Actual', 'Expected'],
            rows: [
              for (final row in validationChecks.take(18))
                [_text(row['name']), _text(row['status']).toUpperCase(), _shortText(row['actual'], 42), _shortText(row['expected'], 42)],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025ExplorerScreen extends StatefulWidget {
  const Nba2025ExplorerScreen({super.key});

  @override
  State<Nba2025ExplorerScreen> createState() => _Nba2025ExplorerScreenState();
}

class _Nba2025ExplorerScreenState extends State<Nba2025ExplorerScreen> {
  String query = 'OKC';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      builder: (data) {
        final q = query.trim();
        final searchRows = _filter(data.searchIndex, q, const ['type', 'id', 'label', 'subtitle']);
        final players = _filter(data.playerSeasonTotals, q, const ['player_label', 'player_id', 'team_ids']);
        final teams = _filter(data.teamRecords, q, const ['team_id']);
        final games = _filter(data.games, q, const ['game_id', 'game_date', 'away_team_id', 'home_team_id', 'winner_team_id']);
        final teamLogs = _filter(data.teamGameLogs, q, const ['game_id', 'game_date', 'team_id', 'opponent_team_id', 'result']);
        final playerLogs = _filter(data.playerGameLogsTop, q, const ['game_id', 'game_date', 'player_label', 'team_id', 'opponent_team_id']);
        final totalMatches = searchRows.length + players.length + teams.length + games.length + teamLogs.length + playerLogs.length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Explorer',
            subtitle: 'Global generated-data search across teams, players, games, team logs, compact player game logs, and the generated search index.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Total Matches', '$totalMatches', q.isEmpty ? 'Unfiltered seed' : 'Across generated assets'),
            _MetricSpec('Players', '${players.length}', 'Player summaries'),
            _MetricSpec('Games', '${games.length}', 'Game rows'),
            _MetricSpec('Logs', '${teamLogs.length + playerLogs.length}', 'Team + player rows'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(value: query, hint: 'Search anything: Shai, OKC, BOS, 202410220BOS...', onChanged: (value) => setState(() => query = value)),
          const SizedBox(height: 22),
          _TwoColumnLayout(
            left: _TablePanel(
              title: 'Search Index Matches',
              subtitle: 'Generated teams + players index.',
              columns: const ['Type', 'ID', 'Label', 'Subtitle'],
              rows: [for (final row in searchRows.take(30)) [_text(row['type']), _text(row['id']), _text(row['label']), _text(row['subtitle'])]],
            ),
            right: _TablePanel(
              title: 'Player Matches',
              subtitle: 'Loaded-season player summaries.',
              columns: const ['Player', 'Teams', 'GP', 'PPG', 'REB', 'AST', 'BPM'],
              rows: [
                for (final row in players.take(30))
                  [_text(row['player_label']), _text(row['team_ids']), _text(row['games']), _decimal(row['points_per_game']), _decimal(row['rebounds'], decimals: 0), _decimal(row['assists'], decimals: 0), _decimal(row['avg_bpm'])],
              ],
            ),
          ),
          const SizedBox(height: 22),
          _TwoColumnLayout(
            left: _TablePanel(
              title: 'Game Matches',
              subtitle: 'Generated game rows.',
              columns: const ['Date', 'Game', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Winner'],
              rows: [
                for (final row in games.take(30))
                  [_text(row['game_date']), _text(row['game_id']), _text(row['away_team_id']), _text(row['away_score']), _text(row['home_team_id']), _text(row['home_score']), _text(row['winner_team_id'])],
              ],
            ),
            right: _TablePanel(
              title: 'Team Log Matches',
              subtitle: 'Team-game context rows.',
              columns: const ['Date', 'Game', 'Team', 'Opp', 'Result', 'PTS', 'Opp PTS', 'Margin'],
              rows: [
                for (final row in teamLogs.take(30))
                  [_text(row['game_date']), _text(row['game_id']), _text(row['team_id']), _text(row['opponent_team_id']), _text(row['result']), _text(row['points']), _text(row['opponent_points']), _text(row['margin'])],
              ],
            ),
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Player Game Log Matches',
            subtitle: 'High-value compact player-game rows matching the query.',
            columns: const ['Date', 'Game', 'Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', '+/-', 'BPM'],
            rows: [
              for (final row in playerLogs.take(60))
                [_text(row['game_date']), _text(row['game_id']), _text(row['player_label']), _text(row['team_id']), _text(row['opponent_team_id']), _text(row['mp_text']), _decimal(row['pts'], decimals: 0), _decimal(row['trb'], decimals: 0), _decimal(row['ast'], decimals: 0), _decimal(row['plus_minus'], decimals: 0), _decimal(row['bpm'])],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025CompareLabScreen extends StatefulWidget {
  const Nba2025CompareLabScreen({super.key});

  @override
  State<Nba2025CompareLabScreen> createState() => _Nba2025CompareLabScreenState();
}

class _Nba2025CompareLabScreenState extends State<Nba2025CompareLabScreen> {
  String playerA = 'Shai';
  String playerB = 'Jokic';
  String teamA = 'OKC';
  String teamB = 'BOS';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      builder: (data) {
        final a = _firstMatch(data.playerSeasonTotals, playerA, const ['player_label', 'player_id', 'team_ids']);
        final b = _firstMatch(data.playerSeasonTotals, playerB, const ['player_label', 'player_id', 'team_ids']);
        final ta = _firstMatch(data.teamRecords, teamA, const ['team_id']);
        final tb = _firstMatch(data.teamRecords, teamB, const ['team_id']);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Compare Lab',
            subtitle: 'Quick side-by-side terminal for generated player summaries and team records. Type names or team codes to change each side.',
          ),
          const SizedBox(height: 22),
          _CompareControls(
            playerA: playerA,
            playerB: playerB,
            teamA: teamA,
            teamB: teamB,
            playerAChanged: (value) => setState(() => playerA = value),
            playerBChanged: (value) => setState(() => playerB = value),
            teamAChanged: (value) => setState(() => teamA = value),
            teamBChanged: (value) => setState(() => teamB = value),
          ),
          const SizedBox(height: 22),
          _TwoColumnLayout(
            left: _ComparisonCard(title: 'Player A', row: a, labels: _playerCompareLabels),
            right: _ComparisonCard(title: 'Player B', row: b, labels: _playerCompareLabels),
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Player Delta',
            subtitle: 'A minus B for numeric generated player fields.',
            columns: const ['Metric', 'A', 'B', 'Delta'],
            rows: _deltaRows(a, b, const ['games', 'minutes_per_game', 'points_per_game', 'rebounds', 'assists', 'steals', 'blocks', 'avg_ts_pct', 'avg_bpm']),
          ),
          const SizedBox(height: 22),
          _TwoColumnLayout(
            left: _ComparisonCard(title: 'Team A', row: ta, labels: _teamCompareLabels),
            right: _ComparisonCard(title: 'Team B', row: tb, labels: _teamCompareLabels),
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Team Delta',
            subtitle: 'A minus B for generated team-record fields.',
            columns: const ['Metric', 'A', 'B', 'Delta'],
            rows: _deltaRows(ta, tb, const ['games', 'wins', 'losses', 'points_per_game', 'opponent_points_per_game', 'average_margin']),
          ),
        ]);
      },
    );
  }
}

class Nba2025TrendLabScreen extends StatefulWidget {
  const Nba2025TrendLabScreen({super.key});

  @override
  State<Nba2025TrendLabScreen> createState() => _Nba2025TrendLabScreenState();
}

class _Nba2025TrendLabScreenState extends State<Nba2025TrendLabScreen> {
  String teamQuery = 'OKC';

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      builder: (data) {
        final teamId = teamQuery.trim().isEmpty ? 'OKC' : teamQuery.trim().toUpperCase();
        final logs = data.teamGameLogs.where((row) => _text(row['team_id']).toUpperCase() == teamId).toList();
        final recent = logs.length <= 20 ? logs : logs.sublist(logs.length - 20);
        final last10 = logs.length <= 10 ? logs : logs.sublist(logs.length - 10);
        final wins = last10.where((row) => _text(row['result']).toUpperCase() == 'W').length;
        final avgMargin = last10.isEmpty ? 0 : last10.fold<double>(0, (sum, row) => sum + _num(row['margin'])) / last10.length;
        final avgPoints = last10.isEmpty ? 0 : last10.fold<double>(0, (sum, row) => sum + _num(row['points'])) / last10.length;
        final homeRows = logs.where((row) => _isOne(row['is_home'])).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Trend Lab',
            subtitle: 'Team game-log trend terminal with recent form, last-10 scoring, home/away context, quarter scoring, and margin bars.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Selected Team', teamId, '${logs.length} loaded rows'),
            _MetricSpec('Last 10', '$wins-${last10.length - wins}', 'Recent W-L'),
            _MetricSpec('Last 10 Margin', avgMargin.toStringAsFixed(1), 'Average point margin'),
            _MetricSpec('Last 10 PPG', avgPoints.toStringAsFixed(1), '$homeRows home rows total'),
          ]),
          const SizedBox(height: 22),
          _SearchBox(value: teamQuery, hint: 'Enter a team code: OKC, BOS, NYK...', onChanged: (value) => setState(() => teamQuery = value)),
          const SizedBox(height: 22),
          _MarginBars(rows: recent.reversed.toList()),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Recent Team Game Log',
            subtitle: 'Most recent visible rows for the selected team.',
            columns: const ['Date', 'Game', 'Opp', 'H/A', 'Result', 'PTS', 'Opp PTS', 'Margin', 'Q1', 'Q2', 'Q3', 'Q4'],
            rows: [
              for (final row in recent.reversed)
                [_text(row['game_date']), _text(row['game_id']), _text(row['opponent_team_id']), _isOne(row['is_home']) ? 'Home' : 'Away', _text(row['result']), _text(row['points']), _text(row['opponent_points']), _text(row['margin']), _text(row['q1']), _text(row['q2']), _text(row['q3']), _text(row['q4'])],
            ],
          ),
        ]);
      },
    );
  }
}

class Nba2025QAConsoleScreen extends StatelessWidget {
  const Nba2025QAConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SeedFuture(
      builder: (data) {
        final checks = _asMapList(data.validationReport?['checks']);
        final files = data.dataDictionary['files'];
        final fileRows = <List<String>>[];
        if (files is Map) {
          for (final entry in files.entries) {
            fileRows.add([entry.key.toString(), entry.value.toString()]);
          }
        }
        final manifestCounts = data.manifest['counts'];
        final countRows = <List<String>>[];
        if (manifestCounts is Map) {
          for (final entry in manifestCounts.entries) {
            countRows.add([entry.key.toString(), entry.value.toString()]);
          }
        }
        final copiedFiles = data.assetManifest?['copiedFiles'];
        final copiedRows = copiedFiles is List ? [for (final item in copiedFiles) [item.toString()]] : <List<String>>[];

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2025 Data QA Console',
            subtitle: 'Validation, asset manifest, file dictionary, and generated-count console for the local NBA 2025 terminal seed.',
          ),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('Validation', data.validationStatus.toUpperCase(), 'validation_report.json'),
            _MetricSpec('Checks', '${checks.length}', 'Validation gates'),
            _MetricSpec('Files', '${fileRows.length}', 'Data dictionary rows'),
            _MetricSpec('Copied Assets', '${data.copiedAssetFiles}', 'Flutter asset sync'),
          ]),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Validation Gates',
            subtitle: 'Every pass/fail check written by the pipeline finalizer.',
            columns: const ['Check', 'Status', 'Actual', 'Expected'],
            rows: [for (final row in checks) [_text(row['name']), _text(row['status']).toUpperCase(), _shortText(row['actual'], 72), _shortText(row['expected'], 72)]],
          ),
          const SizedBox(height: 22),
          _TwoColumnLayout(
            left: _TablePanel(title: 'Manifest Counts', subtitle: 'Counts from manifest.json.', columns: const ['Key', 'Value'], rows: countRows),
            right: _TablePanel(title: 'Copied Asset Files', subtitle: 'Files mirrored into Flutter assets.', columns: const ['File'], rows: copiedRows),
          ),
          const SizedBox(height: 22),
          _TablePanel(title: 'Data Dictionary', subtitle: 'Generated file purposes from data_dictionary.json.', columns: const ['File', 'Purpose'], rows: fileRows),
        ]);
      },
    );
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
          return const TerminalCard(child: Text('Loading generated NBA 2025 assets...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Generated NBA 2025 assets are unavailable.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('${snapshot.error}', style: const TextStyle(color: terminalTextSoft, height: 1.4)),
              const SizedBox(height: 14),
              const Text('Run tools/run_nba_terminal_data_pipeline.py --season 2025, then relaunch Flutter.', style: TextStyle(color: terminalAccent)),
            ]),
          );
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
  Widget build(BuildContext context) {
    return TerminalCard(
      child: TextField(
        controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        cursorColor: terminalAccent,
        decoration: _inputDecoration(hint),
      ),
    );
  }
}

class _CompareControls extends StatelessWidget {
  const _CompareControls({
    required this.playerA,
    required this.playerB,
    required this.teamA,
    required this.teamB,
    required this.playerAChanged,
    required this.playerBChanged,
    required this.teamAChanged,
    required this.teamBChanged,
  });

  final String playerA;
  final String playerB;
  final String teamA;
  final String teamB;
  final ValueChanged<String> playerAChanged;
  final ValueChanged<String> playerBChanged;
  final ValueChanged<String> teamAChanged;
  final ValueChanged<String> teamBChanged;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final width = compact ? constraints.maxWidth : 250.0;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: width, child: TextField(controller: TextEditingController(text: playerA), onChanged: playerAChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Player A'))),
          SizedBox(width: width, child: TextField(controller: TextEditingController(text: playerB), onChanged: playerBChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Player B'))),
          SizedBox(width: width, child: TextField(controller: TextEditingController(text: teamA), onChanged: teamAChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Team A'))),
          SizedBox(width: width, child: TextField(controller: TextEditingController(text: teamB), onChanged: teamBChanged, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Team B'))),
        ]);
      }),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.title, required this.row, required this.labels});

  final String title;
  final Map<String, dynamic>? row;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final item = row;
    return TerminalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (item == null)
          const Text('No matching row.', style: TextStyle(color: terminalTextSoft))
        else
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final entry in labels.entries) InfoPill(label: '${entry.value}: ${_shortText(item[entry.key], 24)}'),
          ]),
      ]),
    );
  }
}

class _MarginBars extends StatelessWidget {
  const _MarginBars({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    var maxMagnitude = 1.0;
    for (final row in rows) {
      final magnitude = _num(row['margin']).abs();
      if (magnitude > maxMagnitude) maxMagnitude = magnitude;
    }
    return TerminalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Margin Bars', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('No team rows match the selected team.', style: TextStyle(color: terminalTextSoft))
        else
          for (final row in rows.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LayoutBuilder(builder: (context, constraints) {
                final margin = _num(row['margin']);
                final width = constraints.maxWidth * (margin.abs() / maxMagnitude) * 0.78;
                return Row(children: [
                  SizedBox(width: 96, child: Text(_text(row['game_date']), style: const TextStyle(color: terminalTextMuted, fontSize: 12))),
                  SizedBox(width: 78, child: Text('${_text(row['opponent_team_id'])} ${_text(row['result'])}', style: const TextStyle(color: terminalTextSoft, fontSize: 12))),
                  Container(width: width < 4 ? 4 : width, height: 12, decoration: BoxDecoration(color: margin >= 0 ? const Color(0xFF7EE787) : const Color(0xFFFF7B72), borderRadius: BorderRadius.circular(6))),
                  const SizedBox(width: 8),
                  Text(margin.round().toString(), style: const TextStyle(color: terminalTextSoft, fontSize: 12)),
                ]);
              }),
            ),
      ]),
    );
  }
}

class _TwoColumnLayout extends StatelessWidget {
  const _TwoColumnLayout({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 900) {
        return Column(children: [left, const SizedBox(height: 22), right]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 22), Expanded(child: right)]);
    });
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
        children: [for (final metric in metrics) _MetricCard(metric: metric)],
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
  const _MetricCard({required this.metric});

  final _MetricSpec metric;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(metric.label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
        Text(metric.value, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(metric.detail, style: const TextStyle(color: terminalAccent, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _TablePanel extends StatelessWidget {
  const _TablePanel({required this.title, required this.subtitle, required this.columns, required this.rows});

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
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: terminalTextMuted))])),
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
              rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 34 ? 300 : 112, child: Text(cell, overflow: TextOverflow.ellipsis)))])],
            ),
          ),
      ]),
    );
  }
}

const _playerCompareLabels = <String, String>{
  'player_label': 'Player',
  'team_ids': 'Teams',
  'games': 'GP',
  'points_per_game': 'PPG',
  'rebounds': 'REB',
  'assists': 'AST',
  'avg_ts_pct': 'TS%',
  'avg_bpm': 'BPM',
};

const _teamCompareLabels = <String, String>{
  'team_id': 'Team',
  'games': 'Games',
  'wins': 'Wins',
  'losses': 'Losses',
  'points_per_game': 'PPG',
  'opponent_points_per_game': 'Opp PPG',
  'average_margin': 'Margin',
};

List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> rows, String query, List<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows.where((row) => fields.map((field) => _text(row[field])).join(' ').toLowerCase().contains(q)).toList();
}

Map<String, dynamic>? _firstMatch(List<Map<String, dynamic>> rows, String query, List<String> fields) {
  final matches = _filter(rows, query, fields);
  if (matches.isEmpty) return null;
  return matches.first;
}

List<List<String>> _deltaRows(Map<String, dynamic>? a, Map<String, dynamic>? b, List<String> keys) {
  return [
    for (final key in keys)
      [
        key,
        a == null ? '—' : _decimal(a[key]),
        b == null ? '—' : _decimal(b[key]),
        a == null || b == null ? '—' : _decimal(_num(a[key]) - _num(b[key])),
      ],
  ];
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

String _compactNumber(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
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
