import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../widgets/terminal_primitives.dart';

class NbaTerminalSeedScreen extends StatefulWidget {
  const NbaTerminalSeedScreen({super.key});

  @override
  State<NbaTerminalSeedScreen> createState() => _NbaTerminalSeedScreenState();
}

class _NbaTerminalSeedScreenState extends State<NbaTerminalSeedScreen> {
  late final Future<NbaTerminalSeedSnapshot> snapshotFuture = const NbaTerminalSeedRepository().load();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading generated 2024-25 NBA terminal seed...', style: TextStyle(color: terminalTextSoft)));
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

        final data = snapshot.data!;
        final normalizedQuery = query.trim().toLowerCase();
        bool rowMatches(Map<String, dynamic> row, Iterable<String> fields) {
          if (normalizedQuery.isEmpty) return true;
          return fields.any((field) => _text(row[field]).toLowerCase().contains(normalizedQuery));
        }

        final filteredSearchIndex = data.searchIndex.where((row) => rowMatches(row, const ['type', 'id', 'label', 'subtitle'])).toList();
        final filteredTeamRecords = data.teamRecords.where((row) => rowMatches(row, const ['team_id'])).toList();
        final filteredTeamGameLogs = data.teamGameLogs.where((row) => rowMatches(row, const ['game_date', 'game_id', 'team_id', 'opponent_team_id', 'result'])).toList();
        final filteredPlayerTotals = data.playerSeasonTotals.where((row) => rowMatches(row, const ['player_label', 'player_id', 'team_ids'])).toList();
        final pointsLeaders = _asMapList(data.playerLeaders['points_per_game']).where((row) => rowMatches(row, const ['player_label', 'player_id'])).toList();
        final gameHighs = _asMapList(data.playerGameHighs['points']).where((row) => rowMatches(row, const ['game_date', 'game_id', 'player_label', 'player_id', 'team_id', 'opponent_team_id'])).toList();
        final filteredTopGameLogs = data.playerGameLogsTop.where((row) => rowMatches(row, const ['game_date', 'game_id', 'player_label', 'player_id', 'team_id', 'opponent_team_id'])).toList();
        final filteredGames = data.games.where((row) => rowMatches(row, const ['game_date', 'game_id', 'away_team_id', 'home_team_id', 'winner_team_id'])).toList();
        final visibleMatches = filteredSearchIndex.length + filteredTeamRecords.length + filteredTeamGameLogs.length + filteredPlayerTotals.length + filteredTopGameLogs.length + filteredGames.length;
        final validationPass = data.validationStatus == 'pass';

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(
            title: '2024-25 NBA Data Terminal',
            subtitle: 'Validated product-facing seed generated from the completed local Basketball Reference warehouse. This screen reads the generated JSON asset mirror used by the Flutter app.',
          ),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: wide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: wide ? 1.8 : 1.35,
              children: [
                _MetricCard(label: 'Validation', value: validationPass ? 'PASS' : data.validationStatus.toUpperCase(), detail: 'Terminal seed report'),
                _MetricCard(label: 'Games', value: '${data.games.length}', detail: 'Regular season + playoffs'),
                _MetricCard(label: 'Players', value: '${data.players.length}', detail: 'Warehouse identities'),
                _MetricCard(label: 'Teams', value: '${data.teams.length}', detail: 'NBA franchises'),
                _MetricCard(label: 'Team Game Logs', value: '${data.teamGameLogs.length}', detail: 'Team-game rows'),
                _MetricCard(label: 'Player Summaries', value: '${data.playerSeasonTotals.length}', detail: 'Loaded-season totals'),
                _MetricCard(label: 'Top Game Logs', value: '${data.playerGameLogsTop.length}', detail: 'High-value player games'),
                _MetricCard(label: 'Search Index', value: '${data.searchIndex.length}', detail: 'Teams + players'),
                _MetricCard(label: 'Visible Matches', value: '$visibleMatches', detail: normalizedQuery.isEmpty ? 'All seed rows' : 'Current query'),
                _MetricCard(label: 'Normalized PBP', value: _compactNumber(data.playByPlayEvents), detail: 'Event rows'),
                _MetricCard(label: 'Asset Files', value: '${data.copiedAssetFiles}', detail: 'Synced into Flutter'),
                _MetricCard(label: 'Generated', value: _shortDate(data.warehouseGeneratedAt), detail: 'Warehouse build'),
              ],
            );
          }),
          const SizedBox(height: 22),
          _SeedSearchPanel(query: query, onChanged: (value) => setState(() => query = value)),
          const SizedBox(height: 22),
          _SeedHealthPanel(data: data),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Generated Search Results',
            subtitle: normalizedQuery.isEmpty ? 'Top searchable teams and players from the generated seed.' : 'Search results matching the current query across generated team and player identities.',
            columns: const ['Type', 'ID', 'Label', 'Subtitle'],
            rows: [
              for (final row in filteredSearchIndex.take(18))
                [_text(row['type']), _text(row['id']), _text(row['label']), _shortText(row['subtitle'], 54)],
            ],
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Team Records',
            subtitle: 'All loaded games, including postseason games.',
            columns: const ['Team', 'Games', 'W', 'L', 'PPG', 'Opp PPG', 'Margin'],
            rows: [
              for (final row in filteredTeamRecords.take(12))
                [
                  _text(row['team_id']),
                  _text(row['games']),
                  _text(row['wins']),
                  _text(row['losses']),
                  _decimal(row['points_per_game']),
                  _decimal(row['opponent_points_per_game']),
                  _decimal(row['average_margin']),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Team Game Log Sample',
            subtitle: 'Team-game rows with opponent, location, result, margin, and period scoring.',
            columns: const ['Date', 'Team', 'Opp', 'H/A', 'Result', 'PTS', 'Opp PTS', 'Margin', 'Q1', 'Q2', 'Q3', 'Q4'],
            rows: [
              for (final row in filteredTeamGameLogs.take(12))
                [
                  _text(row['game_date']),
                  _text(row['team_id']),
                  _text(row['opponent_team_id']),
                  _text(row['is_home']) == '1' ? 'Home' : 'Away',
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
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Player Loaded-Season Totals',
            subtitle: 'One row per player summary derived from materialized player game stats.',
            columns: const ['Player', 'Teams', 'GP', 'MPG', 'PTS', 'PPG', 'REB', 'AST', 'TS%', 'BPM'],
            rows: [
              for (final row in filteredPlayerTotals.take(12))
                [
                  _text(row['player_label']),
                  _shortText(row['team_ids'], 16),
                  _text(row['games']),
                  _decimal(row['minutes_per_game'], decimals: 1),
                  _decimal(row['points'], decimals: 0),
                  _decimal(row['points_per_game']),
                  _decimal(row['rebounds'], decimals: 0),
                  _decimal(row['assists'], decimals: 0),
                  _decimal(row['avg_ts_pct'], decimals: 3),
                  _decimal(row['avg_bpm']),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Points Per Game Leaders',
            subtitle: 'Leaderboard slice derived from materialized player game stats.',
            columns: const ['Player', 'Games', 'PTS', 'PPG', 'REB', 'AST'],
            rows: [
              for (final row in pointsLeaders.take(12))
                [
                  _text(row['player_label']),
                  _text(row['games']),
                  _decimal(row['points'], decimals: 0),
                  _decimal(row['points_per_game']),
                  _decimal(row['rebounds']),
                  _decimal(row['assists']),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Single-Game Scoring Highs',
            subtitle: 'Top individual scoring games in the loaded warehouse.',
            columns: const ['Date', 'Player', 'Team', 'Opp', 'Game', 'PTS', 'REB', 'AST', '+/-'],
            rows: [
              for (final row in gameHighs.take(12))
                [
                  _text(row['game_date']),
                  _text(row['player_label']),
                  _text(row['team_id']),
                  _text(row['opponent_team_id']),
                  _text(row['game_id']),
                  _decimal(row['pts'], decimals: 0),
                  _decimal(row['trb'], decimals: 0),
                  _decimal(row['ast'], decimals: 0),
                  _decimal(row['plus_minus'], decimals: 0),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Top Player Game Log Rows',
            subtitle: 'Compact high-value player-game rows exported for early player and game pages.',
            columns: const ['Date', 'Player', 'Team', 'Opp', 'MIN', 'PTS', 'REB', 'AST', 'TS%', 'BPM'],
            rows: [
              for (final row in filteredTopGameLogs.take(12))
                [
                  _text(row['game_date']),
                  _text(row['player_label']),
                  _text(row['team_id']),
                  _text(row['opponent_team_id']),
                  _text(row['mp_text']),
                  _decimal(row['pts'], decimals: 0),
                  _decimal(row['trb'], decimals: 0),
                  _decimal(row['ast'], decimals: 0),
                  _decimal(row['ts_pct'], decimals: 3),
                  _decimal(row['bpm']),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _TablePanel(
            title: 'Opening Games Sample',
            subtitle: 'Game rows generated from the line-score warehouse table.',
            columns: const ['Date', 'Away', 'Away PTS', 'Home', 'Home PTS', 'Winner'],
            rows: [
              for (final row in filteredGames.take(12))
                [
                  _text(row['game_date']),
                  _text(row['away_team_id']),
                  _text(row['away_score']),
                  _text(row['home_team_id']),
                  _text(row['home_score']),
                  _text(row['winner_team_id']),
                ],
            ],
          ),
          const SizedBox(height: 22),
          _DataDictionaryPanel(data: data),
        ]);
      },
    );
  }
}

class _SeedSearchPanel extends StatelessWidget {
  const _SeedSearchPanel({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Generated Data Explorer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('Search across generated team/player identities, player summaries, game logs, team logs, and game rows without touching the raw warehouse.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
        const SizedBox(height: 14),
        TextField(
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          cursorColor: terminalAccent,
          decoration: InputDecoration(
            hintText: 'Try Shai, Celtics, OKC, 202410220BOS, BOS, NYK...',
            hintStyle: const TextStyle(color: Color(0xFF657386)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF657386)),
            filled: true,
            fillColor: const Color(0xFF0D1218),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalAccent)),
          ),
        ),
        if (query.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Current query: ${query.trim()}', style: const TextStyle(color: terminalAccent, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }
}

class _SeedHealthPanel extends StatelessWidget {
  const _SeedHealthPanel({required this.data});

  final NbaTerminalSeedSnapshot data;

  @override
  Widget build(BuildContext context) {
    final checks = _asMapList(data.validationReport?['checks']);
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Expanded(child: Text('Seed Validation Gates', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            InfoPill(label: data.validationStatus.toUpperCase(), color: data.validationStatus == 'pass' ? const Color(0xFF7EE787) : const Color(0xFFFFB86B)),
          ]),
        ),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columns: const [
              DataColumn(label: Text('Check')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actual')),
              DataColumn(label: Text('Expected')),
            ],
            rows: [
              for (final check in checks.take(20))
                DataRow(cells: [
                  DataCell(SizedBox(width: 260, child: Text(_text(check['name'])))),
                  DataCell(InfoPill(label: _text(check['status']).toUpperCase())),
                  DataCell(SizedBox(width: 220, child: Text(_compactValue(check['actual'])))),
                  DataCell(SizedBox(width: 220, child: Text(_compactValue(check['expected'])))),
                ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _DataDictionaryPanel extends StatelessWidget {
  const _DataDictionaryPanel({required this.data});

  final NbaTerminalSeedSnapshot data;

  @override
  Widget build(BuildContext context) {
    final files = data.dataDictionary['files'];
    final rows = <List<String>>[];
    if (files is Map) {
      for (final entry in files.entries.take(14)) {
        rows.add([entry.key.toString(), entry.value.toString()]);
      }
    }
    return _TablePanel(
      title: 'Generated Seed File Dictionary',
      subtitle: 'Product-facing JSON files available to Flutter after the local pipeline sync step.',
      columns: const ['File', 'Purpose'],
      rows: rows,
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
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: terminalTextMuted)),
              ]),
            ),
            const SizedBox(width: 12),
            Text('${rows.length} rows', style: const TextStyle(color: terminalTextMuted)),
          ]),
        ),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columns: [for (final column in columns) DataColumn(label: Text(column))],
            rows: [
              for (final row in rows)
                DataRow(cells: [
                  for (final cell in row) DataCell(Text(cell)),
                ]),
            ],
          ),
        ),
      ]),
    );
  }
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

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) item.cast<String, dynamic>()];
}

String _text(Object? value) => value?.toString() ?? '—';

String _shortText(Object? value, int maxLength) {
  final text = _text(value);
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}

String _decimal(Object? value, {int decimals = 3}) {
  if (value is num) return decimals == 0 ? value.round().toString() : value.toStringAsFixed(decimals);
  final parsed = num.tryParse(value?.toString() ?? '');
  if (parsed == null) return '—';
  return decimals == 0 ? parsed.round().toString() : parsed.toStringAsFixed(decimals);
}

String _compactNumber(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String _compactValue(Object? value) {
  final text = _text(value);
  return text.length <= 42 ? text : '${text.substring(0, 39)}...';
}

String _shortDate(String value) {
  if (value.length >= 10) return value.substring(0, 10);
  return value;
}
