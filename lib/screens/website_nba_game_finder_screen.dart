import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/website_pagination.dart';
import '../widgets/website_sticky_stats_table.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaGameFinderScreen extends StatefulWidget {
  const WebsiteNbaGameFinderScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaGameFinderScreen> createState() =>
      _WebsiteNbaGameFinderScreenState();
}

class _WebsiteNbaGameFinderScreenState
    extends State<WebsiteNbaGameFinderScreen> {
  final _api = const WebsiteNbaApiService();
  final _search = TextEditingController();

  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<List<Map<String, dynamic>>>? _gamesFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  String _seasonType = 'regular';
  String _team = 'All';
  String _resultFilter = 'All';
  String _sortKey = 'date';
  bool _descending = true;
  int _pageSize = 20;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _seasonsFuture = _loadSeasons();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<WebsiteNbaSeason>> _loadSeasons() async {
    final seasons = await _api.seasons();
    if (seasons.isNotEmpty) {
      _seasons = seasons;
      _season = seasons.firstWhere(
        (item) => item.id == '2025-26',
        orElse: () => seasons.first,
      ).id;
      _gamesFuture = _loadGames();
    }
    return seasons;
  }

  Future<List<Map<String, dynamic>>> _loadGames() => _api.games(
        season: _season,
        seasonType: _seasonType,
      );

  void _reload({bool resetTeam = true}) {
    setState(() {
      if (resetTeam) _team = 'All';
      _page = 1;
      _gamesFuture = _loadGames();
    });
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _team = 'All';
      _resultFilter = 'All';
      _sortKey = 'date';
      _descending = true;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, seasons) {
        if (seasons.connectionState != ConnectionState.done) {
          return const _GameLoading();
        }
        if (seasons.hasError || _seasons.isEmpty || _gamesFuture == null) {
          return _GameError(
            title: 'Game Finder unavailable',
            error: seasons.error,
            onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
          );
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _gamesFuture,
          builder: (context, games) {
            if (games.connectionState != ConnectionState.done) {
              return const _GameLoading();
            }
            if (games.hasError) {
              return _GameError(
                title: 'Static game catalog unavailable',
                error: games.error,
                onRetry: _reload,
              );
            }
            return _buildPage(context, games.data ?? const []);
          },
        );
      },
    );
  }

  Widget _buildPage(
    BuildContext context,
    List<Map<String, dynamic>> sourceRows,
  ) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final teams = <String>{'All'};
    for (final row in sourceRows) {
      for (final value in [
        row['home_team_abbreviation'],
        row['away_team_abbreviation'],
      ]) {
        final text = _text(value);
        if (text.isNotEmpty) teams.add(text);
      }
    }

    final rows = sourceRows.where((row) {
      final home = _text(row['home_team_name'], _text(row['home_team_abbreviation']));
      final away = _text(row['away_team_name'], _text(row['away_team_abbreviation']));
      final homeAbbr = _text(row['home_team_abbreviation']);
      final awayAbbr = _text(row['away_team_abbreviation']);
      if (_team != 'All' && homeAbbr != _team && awayAbbr != _team) return false;
      if (query.isNotEmpty) {
        final haystack = '$home $away $homeAbbr $awayAbbr '
                '${_text(row['game_date'])} ${_text(row['nba_game_id'])}'
            .toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      final margin = _margin(row);
      switch (_resultFilter) {
        case 'Close (≤5)':
          if (margin == null || margin > 5) return false;
          break;
        case 'Single digits':
          if (margin == null || margin > 9) return false;
          break;
        case '10+ point margin':
          if (margin == null || margin < 10) return false;
          break;
        case '20+ point margin':
          if (margin == null || margin < 20) return false;
          break;
      }
      return true;
    }).toList();

    rows.sort((a, b) {
      int comparison;
      switch (_sortKey) {
        case 'margin':
          comparison = (_margin(a) ?? -1).compareTo(_margin(b) ?? -1);
          break;
        case 'home_score':
          comparison = (_number(a['home_score']) ?? -1)
              .compareTo(_number(b['home_score']) ?? -1);
          break;
        case 'away_score':
          comparison = (_number(a['away_score']) ?? -1)
              .compareTo(_number(b['away_score']) ?? -1);
          break;
        default:
          comparison = _text(a['game_date']).compareTo(_text(b['game_date']));
      }
      return _descending ? -comparison : comparison;
    });

    final pageCount = math.max(1, (rows.length / _pageSize).ceil());
    final safePage = _page.clamp(1, pageCount);
    if (safePage != _page) _page = safePage;
    final start = (safePage - 1) * _pageSize;
    final paged = rows.skip(start).take(_pageSize).toList();

    Widget pager() => WebsitePagination(
          totalItems: rows.length,
          pageSize: _pageSize,
          currentPage: safePage,
          onPageChanged: (value) => setState(() => _page = value),
          onPageSizeChanged: (value) => setState(() {
            _pageSize = value;
            _page = 1;
          }),
        );

    final columns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Matchup'), width: 285),
      WebsiteStickyStatsColumn(
        label: const Text('Date'),
        width: 96,
        onTap: () => _sort('date'),
      ),
      const WebsiteStickyStatsColumn(label: Text('Away'), width: 64),
      WebsiteStickyStatsColumn(
        label: const Text('PTS'),
        width: 60,
        numeric: true,
        onTap: () => _sort('away_score'),
      ),
      const WebsiteStickyStatsColumn(label: Text('Home'), width: 64),
      WebsiteStickyStatsColumn(
        label: const Text('PTS'),
        width: 60,
        numeric: true,
        onTap: () => _sort('home_score'),
      ),
      WebsiteStickyStatsColumn(
        label: const Text('Margin'),
        width: 70,
        numeric: true,
        onTap: () => _sort('margin'),
      ),
      const WebsiteStickyStatsColumn(label: Text('Status'), width: 96),
      const WebsiteStickyStatsColumn(label: Text('Game ID'), width: 118),
    ];

    final tableRows = <List<Widget>>[
      for (final row in paged)
        [
          InkWell(
            onTap: () => openWebsiteNbaGamePage(
              context,
              session: widget.session,
              gameKey: _text(row['game_key'], _text(row['nba_game_id'])),
            ),
            child: Text(
              '${_shortTeam(row, away: true)} at ${_shortTeam(row, away: false)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(_dateLabel(row['game_date'])),
          _TeamAbbreviationLink(
            session: widget.session,
            keyValue: _text(row['away_team_key']),
            abbreviation: _text(row['away_team_abbreviation']),
            name: _text(row['away_team_name']),
          ),
          Text(_whole(row['away_score']), textAlign: TextAlign.right),
          _TeamAbbreviationLink(
            session: widget.session,
            keyValue: _text(row['home_team_key']),
            abbreviation: _text(row['home_team_abbreviation']),
            name: _text(row['home_team_name']),
          ),
          Text(_whole(row['home_score']), textAlign: TextAlign.right),
          Text(_margin(row)?.toString() ?? '—', textAlign: TextAlign.right),
          Text(_text(row['status'], 'Final'), maxLines: 1),
          Text(_text(row['nba_game_id'], '—'), maxLines: 1),
        ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Finder',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Search historical NBA games, inspect box scores and open play-by-play when that source has been materialized.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 145,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('games-season-$_season'),
                    initialValue: _season,
                    decoration: const InputDecoration(
                      labelText: 'Season',
                      isDense: true,
                    ),
                    items: [
                      for (final item in _seasons)
                        DropdownMenuItem(value: item.id, child: Text(item.id)),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _season) return;
                      _season = value;
                      _reload();
                    },
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'regular',
                      label: Text('Regular Season'),
                    ),
                    ButtonSegment(
                      value: 'playoffs',
                      label: Text('Playoffs'),
                    ),
                  ],
                  selected: {_seasonType},
                  onSelectionChanged: (value) {
                    _seasonType = value.first;
                    _reload();
                  },
                ),
                SizedBox(
                  width: 230,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() => _page = 1),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search team, date or game ID',
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('games-team-$_team-${teams.length}'),
                    initialValue: teams.contains(_team) ? _team : 'All',
                    decoration: const InputDecoration(
                      labelText: 'Team',
                      isDense: true,
                    ),
                    items: [
                      for (final item in (teams.toList()..sort()))
                        DropdownMenuItem(value: item, child: Text(item)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _team = value;
                          _page = 1;
                        });
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('games-result-$_resultFilter'),
                    initialValue: _resultFilter,
                    decoration: const InputDecoration(
                      labelText: 'Margin',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('Any margin')),
                      DropdownMenuItem(value: 'Close (≤5)', child: Text('Close (≤5)')),
                      DropdownMenuItem(value: 'Single digits', child: Text('Single digits')),
                      DropdownMenuItem(value: '10+ point margin', child: Text('10+ points')),
                      DropdownMenuItem(value: '20+ point margin', child: Text('20+ points')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _resultFilter = value;
                          _page = 1;
                        });
                      }
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset filters'),
                ),
                OutlinedButton.icon(
                  onPressed: rows.isEmpty ? null : () => _copyGames(context, rows),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy CSV'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '${rows.length} games',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              'Static historical catalog · no runtime NBA.com request',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        pager(),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text('No games match the selected filters.'),
            ),
          )
        else
          WebsiteStickyStatsTable(
            columns: columns,
            rows: tableRows,
            firstColumnWidth: 285,
            headerHeight: 43,
            rowHeight: 42,
          ),
        const SizedBox(height: 10),
        pager(),
      ],
    );
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) {
        _descending = !_descending;
      } else {
        _sortKey = key;
        _descending = true;
      }
      _page = 1;
    });
  }

  Future<void> _copyGames(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) async {
    final lines = <String>[
      'date,away,away_score,home,home_score,margin,game_id',
      for (final row in rows)
        [
          _text(row['game_date']),
          _text(row['away_team_abbreviation']),
          _whole(row['away_score']),
          _text(row['home_team_abbreviation']),
          _whole(row['home_score']),
          _margin(row)?.toString() ?? '',
          _text(row['nba_game_id']),
        ].map(_csv).join(','),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${rows.length} filtered games as CSV.')),
    );
  }
}

Future<void> openWebsiteNbaGamePage(
  BuildContext context, {
  required AppSession session,
  required String gameKey,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/games/${Uri.encodeComponent(gameKey)}',
      ),
      builder: (_) => WebsiteNbaGamePage(
        session: session,
        gameKey: gameKey,
      ),
    ),
  );
}

class WebsiteNbaGamePage extends StatefulWidget {
  const WebsiteNbaGamePage({
    super.key,
    required this.session,
    required this.gameKey,
  });

  final AppSession session;
  final String gameKey;

  @override
  State<WebsiteNbaGamePage> createState() => _WebsiteNbaGamePageState();
}

class _WebsiteNbaGamePageState extends State<WebsiteNbaGamePage> {
  final _api = const WebsiteNbaApiService();
  late Future<_GamePagePayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_GamePagePayload> _load() async {
    final detail = await _api.gameDetail(widget.gameKey);
    List<Map<String, dynamic>> pbp = const [];
    try {
      pbp = await _api.gamePlayByPlay(widget.gameKey);
    } catch (_) {
      pbp = const [];
    }
    return _GamePagePayload(detail: detail, playByPlay: pbp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sports Terminal · Game')),
      body: FutureBuilder<_GamePagePayload>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: _GameError(
                title: 'Game could not be loaded',
                error: snapshot.error,
                onRetry: () => setState(() => _future = _load()),
              ),
            );
          }
          return _buildGame(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildGame(BuildContext context, _GamePagePayload payload) {
    final detail = payload.detail;
    final game = _map(detail['game']);
    final players = _maps(detail['players']);
    final teams = _maps(detail['teams']);
    final colors = Theme.of(context).colorScheme;
    final awayName = _text(
      game['away_team_name'],
      _text(game['away_team_abbreviation'], 'Away'),
    );
    final homeName = _text(
      game['home_team_name'],
      _text(game['home_team_abbreviation'], 'Home'),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$awayName at $homeName',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  _dateLabel(game['game_date']),
                  _text(game['season_id']),
                  _seasonTypeLabel(_text(game['season_type'])),
                  _text(game['nba_game_id']),
                ].where((value) => value.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ScoreTeam(
                          name: awayName,
                          abbreviation: _text(game['away_team_abbreviation']),
                          score: _whole(game['away_score']),
                          onTap: () => _openTeamFromGame(
                            context,
                            keyValue: _text(game['away_team_key']),
                            name: awayName,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'FINAL',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      Expanded(
                        child: _ScoreTeam(
                          name: homeName,
                          abbreviation: _text(game['home_team_abbreviation']),
                          score: _whole(game['home_score']),
                          alignEnd: true,
                          onTap: () => _openTeamFromGame(
                            context,
                            keyValue: _text(game['home_team_key']),
                            name: homeName,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (teams.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  'Team box score',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                _TeamGameTable(rows: teams),
              ],
              const SizedBox(height: 28),
              Text(
                'Player box score',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              if (players.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Player box-score rows are not available for this game.'),
                  ),
                )
              else
                _PlayerGameTable(
                  rows: players,
                  session: widget.session,
                ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Play-by-play',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Text(
                    '${payload.playByPlay.length} events',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (payload.playByPlay.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Possession-level play-by-play has not been materialized for this game. The game and box score remain canonical static data; Sports Terminal does not invent missing events.',
                      style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
                    ),
                  ),
                )
              else
                _PlayByPlayList(rows: payload.playByPlay),
            ],
          ),
        ),
      ),
    );
  }

  void _openTeamFromGame(
    BuildContext context, {
    required String keyValue,
    required String name,
  }) {
    if (keyValue.isEmpty) return;
    openWebsiteNbaTeamPage(
      context,
      session: widget.session,
      teamKey: keyValue,
      teamName: name,
    );
  }
}

class _PlayerGameTable extends StatelessWidget {
  const _PlayerGameTable({required this.rows, required this.session});

  final List<Map<String, dynamic>> rows;
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const metrics = <_BoxMetric>[
      _BoxMetric('min', 'MIN', 58),
      _BoxMetric('pts', 'PTS', 56),
      _BoxMetric('reb', 'REB', 56),
      _BoxMetric('ast', 'AST', 56),
      _BoxMetric('stl', 'STL', 56),
      _BoxMetric('blk', 'BLK', 56),
      _BoxMetric('tov', 'TOV', 56),
      _BoxMetric('pf', 'PF', 52),
      _BoxMetric('fgm', 'FGM', 58),
      _BoxMetric('fga', 'FGA', 58),
      _BoxMetric('fg3m', '3PM', 58),
      _BoxMetric('fg3a', '3PA', 58),
      _BoxMetric('ftm', 'FTM', 58),
      _BoxMetric('fta', 'FTA', 58),
      _BoxMetric('plus_minus', '+/-', 58),
    ];
    final columns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Player'), width: 185),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 62),
      for (final metric in metrics)
        WebsiteStickyStatsColumn(
          label: Text(metric.label),
          width: metric.width,
          numeric: true,
        ),
    ];
    final tableRows = <List<Widget>>[
      for (final row in rows)
        [
          InkWell(
            onTap: () {
              final key = _text(row['player_key']);
              final name = _text(row['player_name'], 'Player');
              if (key.isNotEmpty) {
                openWebsiteNbaPlayerPage(
                  context,
                  session: session,
                  playerKey: key,
                  playerName: name,
                );
              }
            },
            child: Text(
              _text(row['player_name'], 'Player'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800),
            ),
          ),
          Text(_text(row['team_abbreviation'], '—')),
          for (final metric in metrics)
            Text(_boxValue(row[metric.key]), textAlign: TextAlign.right),
        ],
    ];
    return WebsiteStickyStatsTable(
      columns: columns,
      rows: tableRows,
      firstColumnWidth: 185,
      headerHeight: 43,
      rowHeight: 42,
    );
  }
}

class _TeamGameTable extends StatelessWidget {
  const _TeamGameTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    const metrics = <_BoxMetric>[
      _BoxMetric('min', 'MIN', 58),
      _BoxMetric('pts', 'PTS', 56),
      _BoxMetric('reb', 'REB', 56),
      _BoxMetric('ast', 'AST', 56),
      _BoxMetric('stl', 'STL', 56),
      _BoxMetric('blk', 'BLK', 56),
      _BoxMetric('tov', 'TOV', 56),
      _BoxMetric('pf', 'PF', 52),
      _BoxMetric('fgm', 'FGM', 58),
      _BoxMetric('fga', 'FGA', 58),
      _BoxMetric('fg3m', '3PM', 58),
      _BoxMetric('fg3a', '3PA', 58),
      _BoxMetric('ftm', 'FTM', 58),
      _BoxMetric('fta', 'FTA', 58),
      _BoxMetric('plus_minus', '+/-', 58),
    ];
    final columns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 150),
      for (final metric in metrics)
        WebsiteStickyStatsColumn(
          label: Text(metric.label),
          width: metric.width,
          numeric: true,
        ),
    ];
    final tableRows = <List<Widget>>[
      for (final row in rows)
        [
          Text(
            _text(
              row['team_abbreviation'],
              _text(row['team_name'], _text(row['team_key'], 'Team')),
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final metric in metrics)
            Text(_boxValue(row[metric.key]), textAlign: TextAlign.right),
        ],
    ];
    return WebsiteStickyStatsTable(
      columns: columns,
      rows: tableRows,
      firstColumnWidth: 150,
      headerHeight: 43,
      rowHeight: 42,
    );
  }
}

class _PlayByPlayList extends StatelessWidget {
  const _PlayByPlayList({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            Container(
              color: index.isOdd
                  ? colors.surfaceContainerHighest.withValues(alpha: .24)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      'Q${_whole(_first(rows[index], ['period', 'quarter']))} '
                      '${_text(_first(rows[index], ['clock', 'game_clock', 'pctimestring']))}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _eventText(rows[index]),
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                  if (_text(_first(rows[index], ['score', 'score_text'])).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        _text(_first(rows[index], ['score', 'score_text'])),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreTeam extends StatelessWidget {
  const _ScoreTeam({
    required this.name,
    required this.abbreviation,
    required this.score,
    required this.onTap,
    this.alignEnd = false,
  });

  final String name;
  final String abbreviation;
  final String score;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              abbreviation,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              score,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      );
}

class _TeamAbbreviationLink extends StatelessWidget {
  const _TeamAbbreviationLink({
    required this.session,
    required this.keyValue,
    required this.abbreviation,
    required this.name,
  });

  final AppSession session;
  final String keyValue;
  final String abbreviation;
  final String name;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: keyValue.isEmpty
            ? null
            : () => openWebsiteNbaTeamPage(
                  context,
                  session: session,
                  teamKey: keyValue,
                  teamName: name.isEmpty ? abbreviation : name,
                ),
        child: Text(
          abbreviation.isEmpty ? '—' : abbreviation,
          style: TextStyle(
            color: keyValue.isEmpty
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _GamePagePayload {
  const _GamePagePayload({required this.detail, required this.playByPlay});
  final Map<String, dynamic> detail;
  final List<Map<String, dynamic>> playByPlay;
}

class _BoxMetric {
  const _BoxMetric(this.key, this.label, this.width);
  final String key;
  final String label;
  final double width;
}

class _GameLoading extends StatelessWidget {
  const _GameLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _GameError extends StatelessWidget {
  const _GameError({
    required this.title,
    required this.error,
    required this.onRetry,
  });
  final String title;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text('${error ?? 'The requested static NBA file is unavailable.'}'),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

String _shortTeam(Map<String, dynamic> row, {required bool away}) {
  final prefix = away ? 'away' : 'home';
  return _text(
    row['${prefix}_team_abbreviation'],
    _text(row['${prefix}_team_name'], away ? 'Away' : 'Home'),
  );
}

int? _margin(Map<String, dynamic> row) {
  final home = _number(row['home_score']);
  final away = _number(row['away_score']);
  if (home == null || away == null) return null;
  return (home - away).abs().round();
}

num? _number(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

String _whole(Object? value) {
  final number = _number(value);
  if (number == null) return '—';
  return number.round().toString();
}

String _boxValue(Object? value) {
  if (value == null || value.toString().isEmpty) return '—';
  if (value is num) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }
  return value.toString();
}

String _dateLabel(Object? value) {
  final text = _text(value);
  if (text.length >= 10) return text.substring(0, 10);
  return text;
}

String _seasonTypeLabel(String value) {
  return value.toLowerCase().contains('play') ? 'Playoffs' : 'Regular Season';
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, field) => MapEntry(key.toString(), field));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, field) => MapEntry(key.toString(), field)),
  ];
}

Object? _first(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && value.toString().isNotEmpty) return value;
  }
  return null;
}

String _eventText(Map<String, dynamic> row) {
  final value = _first(row, [
    'description',
    'event_description',
    'action_description',
    'text',
    'action_type',
  ]);
  return _text(value, 'Event ${_whole(_first(row, ['event_number', 'event_num']))}');
}

String _csv(String value) {
  if (!value.contains(RegExp(r'[,"\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
