import 'package:flutter/material.dart';

import '../services/website_nba_api_service.dart';

class WebsiteNbaBoxScoresScreen extends StatefulWidget {
  const WebsiteNbaBoxScoresScreen({super.key});

  @override
  State<WebsiteNbaBoxScoresScreen> createState() =>
      _WebsiteNbaBoxScoresScreenState();
}

class _WebsiteNbaBoxScoresScreenState extends State<WebsiteNbaBoxScoresScreen> {
  final _api = const WebsiteNbaApiService();
  final _search = TextEditingController();
  late Future<_BoxScoreArchive> _future;
  String _season = 'All';
  String _segment = 'All';
  int _page = 1;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_BoxScoreArchive> _load() async {
    final results = await Future.wait<dynamic>([
      _api.seasons(),
      _api.games(),
    ]);
    final seasons = results[0] as List<WebsiteNbaSeason>;
    final games = results[1] as List<Map<String, dynamic>>;
    games.sort((a, b) {
      final byDate = _text(b['game_date']).compareTo(_text(a['game_date']));
      return byDate != 0
          ? byDate
          : _text(b['game_key']).compareTo(_text(a['game_key']));
    });
    return _BoxScoreArchive(seasons: seasons, games: games);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BoxScoreArchive>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 460,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ArchiveError(
            error: snapshot.error,
            onRetry: () => setState(() => _future = _load()),
          );
        }
        return _buildPage(context, snapshot.data!);
      },
    );
  }

  Widget _buildPage(BuildContext context, _BoxScoreArchive archive) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final filtered = archive.games.where((game) {
      if (_season != 'All' && _text(game['season_id']) != _season) return false;
      if (_segment != 'All') {
        final type = _text(game['season_type']).toLowerCase();
        if (_segment == 'Regular Season' && type.contains('play')) return false;
        if (_segment == 'Playoffs' && !type.contains('play')) return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        game['game_date'],
        game['game_key'],
        game['nba_game_id'],
        game['home_team_name'],
        game['away_team_name'],
        game['home_team_abbreviation'],
        game['away_team_abbreviation'],
      ].map((value) => _text(value).toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList(growable: false);

    final pageCount = filtered.isEmpty
        ? 1
        : ((filtered.length + _pageSize - 1) ~/ _pageSize);
    if (_page > pageCount) _page = pageCount;
    final start = (_page - 1) * _pageSize;
    final visible = filtered.skip(start).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Box Scores',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
            const Chip(
              avatar: Icon(Icons.inventory_2_outlined, size: 17),
              label: Text('Historical static archive'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Browse the newest completed games or search the historical game catalog by team, date or game ID. Detailed player rows appear whenever a source-backed box score has been materialized locally.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() => _page = 1),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Search box scores',
                      hintText: 'Celtics, 2024-06-17, game ID…',
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _season,
                    decoration: const InputDecoration(
                      labelText: 'Season',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All seasons')),
                      for (final season in archive.seasons)
                        DropdownMenuItem(
                          value: season.id,
                          child: Text(season.id),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _season = value;
                        _page = 1;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 165,
                  child: DropdownButtonFormField<String>(
                    initialValue: _segment,
                    decoration: const InputDecoration(
                      labelText: 'Segment',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All games')),
                      DropdownMenuItem(
                        value: 'Regular Season',
                        child: Text('Regular Season'),
                      ),
                      DropdownMenuItem(value: 'Playoffs', child: Text('Playoffs')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _segment = value;
                        _page = 1;
                      });
                    },
                  ),
                ),
                Text(
                  '${filtered.length} games',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('No historical games match these filters.')),
            ),
          )
        else ...[
          for (final game in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GameRow(
                game: game,
                onOpen: () => _openGame(context, game),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: _page > 1 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('Page $_page of $pageCount'),
              IconButton(
                tooltip: 'Next page',
                onPressed: _page < pageCount
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openGame(
    BuildContext context,
    Map<String, dynamic> game,
  ) async {
    final key = _text(game['game_key']);
    Map<String, dynamic>? detail;
    Object? error;
    try {
      detail = await _api.gameDetail(key);
    } catch (caught) {
      error = caught;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _BoxScoreDialog(game: game, detail: detail, error: error),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.onOpen});

  final Map<String, dynamic> game;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final homeScore = _num(game['home_score']);
    final awayScore = _num(game['away_score']);
    final available = game['box_score_available'] == true ||
        _text(game['file']).isNotEmpty;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  _text(game['game_date'], 'Unknown date'),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${_team(game, away: true)}  @  ${_team(game, away: false)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  awayScore == null || homeScore == null
                      ? '—'
                      : '${awayScore.round()} – ${homeScore.round()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: available
                    ? 'Detailed box score available'
                    : 'Game indexed; detailed player box score not materialized yet',
                child: Icon(
                  available
                      ? Icons.table_rows_rounded
                      : Icons.table_rows_outlined,
                  color: available ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoxScoreDialog extends StatelessWidget {
  const _BoxScoreDialog({
    required this.game,
    required this.detail,
    required this.error,
  });

  final Map<String, dynamic> game;
  final Map<String, dynamic>? detail;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final playerRows = _maps(detail?['player_box_scores']);
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      child: SizedBox(
        width: 1050,
        height: 720,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_team(game, away: true)} at ${_team(game, away: false)}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_text(game['game_date'])} · ${_text(game['season_id'])} · ${_segment(game)}',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ScoreBanner(game: detail == null ? game : _map(detail!['game'])),
              const SizedBox(height: 16),
              Expanded(
                child: playerRows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'This game is in the historical catalog, but a detailed player box score has not been materialized from the source data yet.${error == null ? '' : '\n\n$error'}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ),
                      )
                    : _PlayerBoxTable(rows: playerRows),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.game});
  final Map<String, dynamic> game;

  @override
  Widget build(BuildContext context) {
    final away = _team(game, away: true);
    final home = _team(game, away: false);
    final awayScore = _num(game['away_score']);
    final homeScore = _num(game['home_score']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                away,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 18),
            Text(
              awayScore == null ? '—' : awayScore.round().toString(),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('–', style: TextStyle(fontSize: 28)),
            ),
            Text(
              homeScore == null ? '—' : homeScore.round().toString(),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                home,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerBoxTable extends StatelessWidget {
  const _PlayerBoxTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('PLAYER')),
              DataColumn(label: Text('TEAM')),
              DataColumn(label: Text('MIN')),
              DataColumn(label: Text('PTS')),
              DataColumn(label: Text('REB')),
              DataColumn(label: Text('AST')),
              DataColumn(label: Text('STL')),
              DataColumn(label: Text('BLK')),
              DataColumn(label: Text('TOV')),
              DataColumn(label: Text('FG')),
              DataColumn(label: Text('3P')),
              DataColumn(label: Text('FT')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(_text(row['player_name'], 'Player'))),
                    DataCell(Text(_text(row['team_abbreviation']))),
                    DataCell(Text(_stat(row, 'minutes'))),
                    DataCell(Text(_stat(row, 'pts'))),
                    DataCell(Text(_stat(row, 'reb'))),
                    DataCell(Text(_stat(row, 'ast'))),
                    DataCell(Text(_stat(row, 'stl'))),
                    DataCell(Text(_stat(row, 'blk'))),
                    DataCell(Text(_stat(row, 'tov'))),
                    DataCell(Text('${_stat(row, 'fgm')}/${_stat(row, 'fga')}')),
                    DataCell(Text('${_stat(row, 'three_pm')}/${_stat(row, 'three_pa')}')),
                    DataCell(Text('${_stat(row, 'ftm')}/${_stat(row, 'fta')}')),
                  ],
                ),
            ],
          ),
        ),
      );
}

class _ArchiveError extends StatelessWidget {
  const _ArchiveError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historical game archive unavailable',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('${error ?? ''}'),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

class _BoxScoreArchive {
  const _BoxScoreArchive({required this.seasons, required this.games});
  final List<WebsiteNbaSeason> seasons;
  final List<Map<String, dynamic>> games;
}

String _team(Map<String, dynamic> game, {required bool away}) {
  final prefix = away ? 'away' : 'home';
  return _text(
    game['${prefix}_team_name'],
    _text(game['${prefix}_team_abbreviation'], 'Team'),
  );
}

String _segment(Map<String, dynamic> game) =>
    _text(game['season_type']).toLowerCase().contains('play')
        ? 'Playoffs'
        : 'Regular Season';

String _stat(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return '—';
  if (value is num && value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _map(item),
  ];
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
