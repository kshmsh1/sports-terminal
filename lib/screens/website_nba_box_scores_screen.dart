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
  static const _pageSize = 20;

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
      final byDate = _day(b['game_date']).compareTo(_day(a['game_date']));
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
    final latest = archive.games.isEmpty ? '—' : _day(archive.games.first['game_date']);

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
          'Search the locally indexed game archive by team, date or game ID. Open a matchup to inspect source-backed player statistics where available.',
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
                  width: 168,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
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
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
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
                  '${filtered.length} games · latest indexed: $latest',
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
                tooltip: 'First page',
                onPressed: _page > 1 ? () => setState(() => _page = 1) : null,
                icon: const Icon(Icons.first_page_rounded),
              ),
              IconButton(
                tooltip: 'Previous page',
                onPressed: _page > 1 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('Page $_page of $pageCount  ·  ${start + 1}–${start + visible.length} of ${filtered.length}'),
              IconButton(
                tooltip: 'Next page',
                onPressed: _page < pageCount
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                tooltip: 'Last page',
                onPressed: _page < pageCount ? () => setState(() => _page = pageCount) : null,
                icon: const Icon(Icons.last_page_rounded),
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
  ) => showDialog<void>(
    context: context,
    builder: (_) => _BoxScoreDetailLoader(
      game: game,
      api: _api,
    ),
  );

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
    final available = game['box_score_available'] == true;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: LayoutBuilder(builder: (context, box) {
            final matchup = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_team(game, away: true)}  @  ${_team(game, away: false)}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${_day(game['game_date'])}  ·  ${_segment(game)}  ·  ${_text(game['season_id'])}',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
              ],
            );
            final result = Row(mainAxisSize: MainAxisSize.min, children: [
              Text(awayScore == null || homeScore == null ? 'Score unavailable' :
                  '${awayScore.round()} – ${homeScore.round()}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 12),
              Tooltip(
                message: available ? 'Player box score indexed' :
                    'Game indexed; player box score not yet available',
                child: Icon(available ? Icons.table_rows_rounded :
                    Icons.table_rows_outlined, size: 19,
                    color: available ? colors.primary : colors.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ]);
            return box.maxWidth < 640
              ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [matchup, const SizedBox(height: 10), result])
              : Row(children: [Expanded(child: matchup), result]);
          }),
        ),
      ),
    );
  }
}

/// Open the modal before I/O begins so clicks always receive immediate feedback.
class _BoxScoreDetailLoader extends StatefulWidget {
  const _BoxScoreDetailLoader({required this.game, required this.api});
  final Map<String, dynamic> game;
  final WebsiteNbaApiService api;

  @override
  State<_BoxScoreDetailLoader> createState() => _BoxScoreDetailLoaderState();
}

class _BoxScoreDetailLoaderState extends State<_BoxScoreDetailLoader> {
  late Future<Map<String, dynamic>> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.api.gameDetail(_text(widget.game['game_key']));
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Map<String, dynamic>>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Dialog(
              child: SizedBox(width: 520, height: 220,
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 18),
                    Text('Loading ${_team(widget.game, away: true)} at '
                         '${_team(widget.game, away: false)}…'),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => Navigator.pop(context),
                      child: const Text('Close')),
                  ]),
              ),
            );
          }
          return _BoxScoreDialog(
            game: widget.game,
            detail: snapshot.data,
            error: snapshot.error,
          );
        },
      );
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
    final rows = _maps(detail?['player_box_scores']);
    final colors = Theme.of(context).colorScheme;
    final away = _text(game['away_team_abbreviation']);
    final home = _text(game['home_team_abbreviation']);
    final awayRows = _rowsForBoxTeam(rows, away);
    final homeRows = _rowsForBoxTeam(rows, home);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1150,
          maxHeight: MediaQuery.sizeOf(context).height * .90,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_team(game, away: true)} at ${_team(game, away: false)}',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900)),
                  Text('${_day(game['game_date'])} · ${_text(game['season_id'])} · ${_segment(game)}',
                    style: TextStyle(color: colors.onSurfaceVariant)),
                ],
              )),
              IconButton(tooltip: 'Close box score',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 12),
            _ScoreBanner(game: detail == null || _map(detail!['game']).isEmpty
                ? game : _map(detail!['game'])),
            const SizedBox(height: 12),
            Expanded(
              child: rows.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      error == null
                        ? 'A detailed player box score is not available for this indexed game.'
                        : 'The game is indexed, but its detailed box score could not be loaded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  ))
                : DefaultTabController(
                    length: 2,
                    child: Column(children: [
                      TabBar(tabs: [
                        Tab(text: '${_team(game, away: true)} · ${awayRows.length} players'),
                        Tab(text: '${_team(game, away: false)} · ${homeRows.length} players'),
                      ]),
                      const SizedBox(height: 10),
                      Expanded(child: TabBarView(children: [
                        _PlayerBoxTable(rows: awayRows),
                        _PlayerBoxTable(rows: homeRows),
                      ])),
                    ]),
                  ),
            ),
            const SizedBox(height: 6),
            Text('Unavailable player statistics and did-not-play entries are shown separately; blank source values are not converted to zero.',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
          ]),
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
    final awayScore = _num(game['away_score']);
    final homeScore = _num(game['home_score']);
    return Card(
      child: Padding(padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 15, runSpacing: 8, children: [
            Text(_team(game, away: true),
              style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${awayScore?.round() ?? '—'} – ${homeScore?.round() ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
            Text(_team(game, away: false),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
      ),
    );
  }
}

List<Map<String, dynamic>> _rowsForBoxTeam(List<Map<String, dynamic>> rows, String code) {
  final selected = rows.where((r) =>
    _text(r['team_abbreviation']).toUpperCase() == code.toUpperCase()).toList();
  selected.sort((a, b) =>
    (_num(b['minutes']) ?? -1).compareTo(_num(a['minutes']) ?? -1));
  return selected;
}

class _PlayerBoxTable extends StatelessWidget {
  const _PlayerBoxTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final active = rows.where((row) => _num(row['minutes']) != null).toList();
    final inactive = rows.where((row) => _num(row['minutes']) == null).toList();
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (active.isEmpty && inactive.isEmpty)
        const Padding(padding: EdgeInsets.all(18),
          child: Text('No player rows are available for this team.')),
      if (active.isNotEmpty)
        Expanded(child: Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 44, dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('PLAYER')),
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
                  for (final row in active)
                    DataRow(cells: [
                      DataCell(SizedBox(width: 174, child: Text(
                        _text(row['player_name'], 'Player'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 2))),
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
                    ]),
                ],
              ),
            ),
          ),
        )),
      if (inactive.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Did not play / no minutes reported · ${inactive.length}',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
            children: [
              for (final player in inactive)
                ListTile(dense: true, title: Text(_text(player['player_name'], 'Player')),
                  trailing: const Text('—')),
            ],
          ),
        ),
    ]);
  }
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

String _day(Object? value) {
  final raw = _text(value);
  return raw.length >= 10 ? raw.substring(0, 10) : raw;
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
