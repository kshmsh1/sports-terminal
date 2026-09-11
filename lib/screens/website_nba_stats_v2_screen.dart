import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/website_pagination.dart';
import '../widgets/website_sticky_stats_table.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaStatsScreen extends StatefulWidget {
  const WebsiteNbaStatsScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaStatsScreen> createState() => _WebsiteNbaStatsScreenState();
}

class _WebsiteNbaStatsScreenState extends State<WebsiteNbaStatsScreen> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();

  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<NbaTerminalSeedSnapshot>? _snapshotFuture;
  List<WebsiteNbaSeason> _seasons = const [];

  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  String _team = 'All';
  String _position = 'All';
  int _minGp = 50;
  int _minMpg = 0;
  String _sortKey = 'pts';
  bool _descending = true;
  final Set<String> _expanded = <String>{};
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
      _season = seasons
          .firstWhere(
            (item) => item.id == '2025-26',
            orElse: () => seasons.first,
          )
          .id;
      _snapshotFuture = _loadSnapshot();
    }
    return seasons;
  }

  Future<NbaTerminalSeedSnapshot> _loadSnapshot() => _api.seasonSnapshot(
        _season,
        seasonType: _seasonType == NbaStatsSeasonType.playoffs
            ? 'playoffs'
            : 'regular',
      );

  void _reload({bool resetTeam = true}) {
    setState(() {
      if (resetTeam) _team = 'All';
      _page = 1;
      _snapshotFuture = _loadSnapshot();
    });
  }

  void _changeSegment(NbaStatsSeasonType next) {
    if (next == _seasonType) return;
    setState(() {
      _seasonType = next;
      // 50+ is the default regular-season qualification. A playoff sample can
      // never reach 50 games, so switching to playoffs intentionally opens the
      // GP filter while preserving 50+ as the regular-season default.
      _minGp = next == NbaStatsSeasonType.regular ? 50 : 0;
      _team = 'All';
      _page = 1;
      _snapshotFuture = _loadSnapshot();
    });
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _team = 'All';
      _position = 'All';
      _minGp = _seasonType == NbaStatsSeasonType.regular ? 50 : 0;
      _minMpg = 0;
      _page = 1;
    });
  }

  List<_VisibleColumn> _visibleColumns() {
    final result = <_VisibleColumn>[];
    for (final column in _baseColumns) {
      result.add(_VisibleColumn(column, false));
      if (_expanded.contains(column.key)) {
        result.addAll(
          column.children.map((child) => _VisibleColumn(child, true)),
        );
      }
    }
    return result;
  }

  Widget _columnHeader(_StatColumn column) {
    if (column.children.isEmpty) {
      return Text(column.label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final open = _expanded.contains(column.key);
    return InkWell(
      onTap: () => setState(() {
        if (open) {
          _expanded.remove(column.key);
        } else {
          _expanded.add(column.key);
        }
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            open
                ? Icons.arrow_drop_down_rounded
                : Icons.arrow_right_rounded,
            size: 25,
          ),
          Text(column.label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, catalog) {
        if (catalog.connectionState != ConnectionState.done) {
          return const _StatsLoading();
        }
        if (catalog.hasError || _seasons.isEmpty || _snapshotFuture == null) {
          return _StatsError(
            error: catalog.error,
            onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
          );
        }
        return FutureBuilder<NbaTerminalSeedSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _StatsLoading();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _StatsError(
                error: snapshot.error,
                onRetry: () => _reload(resetTeam: false),
              );
            }
            return _buildPage(context, snapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, NbaTerminalSeedSnapshot snapshot) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(
      snapshot,
      basis: NbaStatsBasis.perGame,
      seasonType: _seasonType,
    );
    final query = _search.text.trim().toLowerCase();
    final teams = <String>{'All'};
    for (final row in rows) {
      teams.addAll(
        row.team
            .split(RegExp(r'[,/ ]+'))
            .where((item) => item.isNotEmpty && item != '—'),
      );
    }

    final filtered = rows.where((row) {
      if (query.isNotEmpty &&
          !'${row.player} ${row.team} ${row.position}'
              .toLowerCase()
              .contains(query)) {
        return false;
      }
      if (_team != 'All' &&
          !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) {
        return false;
      }
      if (_position != 'All' && !_matchesPosition(row.position, _position)) {
        return false;
      }
      if ((row.value('gp') ?? 0) < _minGp) return false;
      if ((row.value('min') ?? 0) < _minMpg) return false;
      return true;
    }).toList();

    filtered.sort((left, right) {
      final a = left.value(_sortKey);
      final b = right.value(_sortKey);
      if (a == null && b == null) return left.player.compareTo(right.player);
      if (a == null) return 1;
      if (b == null) return -1;
      return _descending ? b.compareTo(a) : a.compareTo(b);
    });

    final pageCount = math.max(1, (filtered.length / _pageSize).ceil());
    final safePage = _page < 1
        ? 1
        : _page > pageCount
            ? pageCount
            : _page;
    if (safePage != _page) _page = safePage;
    final start = (safePage - 1) * _pageSize;
    final paged = filtered.skip(start).take(_pageSize).toList();
    final visibleColumns = _visibleColumns();
    final childTint = Theme.of(context).brightness == Brightness.dark
        ? colors.primaryContainer.withValues(alpha: .25)
        : colors.primaryContainer.withValues(alpha: .45);

    Widget pager() => WebsitePagination(
          totalItems: filtered.length,
          pageSize: _pageSize,
          currentPage: safePage,
          onPageChanged: (value) => setState(() => _page = value),
          onPageSizeChanged: (value) => setState(() {
            _pageSize = value;
            _page = 1;
          }),
        );

    final tableColumns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Player'), width: 164),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 58),
      const WebsiteStickyStatsColumn(label: Text('Pos'), width: 48),
      for (final visible in visibleColumns)
        WebsiteStickyStatsColumn(
          label: _columnHeader(visible.column),
          width: visible.child ? 58 : 61,
          numeric: true,
          backgroundColor: visible.child ? childTint : null,
          onTap: () => setState(() {
            if (_sortKey == visible.column.key) {
              _descending = !_descending;
            } else {
              _sortKey = visible.column.key;
              _descending = true;
            }
            _page = 1;
          }),
        ),
    ];

    final tableRows = <List<Widget>>[
      for (final row in paged)
        [
          InkWell(
            onTap: () => openWebsiteNbaPlayerPage(
              context,
              session: widget.session,
              playerKey: row.playerId,
              playerName: row.player,
            ),
            child: Text(
              row.player,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _TeamLink(session: widget.session, row: row),
          Text(row.position, maxLines: 1, overflow: TextOverflow.ellipsis),
          for (final visible in visibleColumns)
            Text(
              _format(row.value(visible.column.key), visible.column),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1510),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stats',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Conventional NBA player statistics with qualification filters, sortable columns and direct player and team navigation.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 145,
                      child: DropdownButtonFormField<String>(
                        initialValue: _season,
                        decoration: const InputDecoration(
                          labelText: 'Season',
                          isDense: true,
                        ),
                        items: [
                          for (final item in _seasons)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(item.id),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null || value == _season) return;
                          _season = value;
                          _reload();
                        },
                      ),
                    ),
                    SegmentedButton<NbaStatsSeasonType>(
                      segments: const [
                        ButtonSegment(
                          value: NbaStatsSeasonType.regular,
                          label: Text('Regular Season'),
                        ),
                        ButtonSegment(
                          value: NbaStatsSeasonType.playoffs,
                          label: Text('Playoffs'),
                        ),
                      ],
                      selected: {_seasonType},
                      onSelectionChanged: (value) =>
                          _changeSegment(value.first),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() => _page = 1),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search players',
                          isDense: true,
                        ),
                      ),
                    ),
                    _StringDropdown(
                      label: 'Team',
                      value: _team,
                      values: teams.toList()..sort(),
                      onChanged: (value) => setState(() {
                        _team = value;
                        _page = 1;
                      }),
                    ),
                    _StringDropdown(
                      label: 'Position',
                      value: _position,
                      values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'],
                      onChanged: (value) => setState(() {
                        _position = value;
                        _page = 1;
                      }),
                    ),
                    _MinimumDropdown(
                      label: 'GP',
                      value: _minGp,
                      values: const [50, 65, 60, 40, 30, 20, 10, 0],
                      onChanged: (value) => setState(() {
                        _minGp = value;
                        _page = 1;
                      }),
                    ),
                    _MinimumDropdown(
                      label: 'MPG',
                      value: _minMpg,
                      values: const [0, 30, 25, 20, 15, 10],
                      onChanged: (value) => setState(() {
                        _minMpg = value;
                        _page = 1;
                      }),
                    ),
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Reset filters'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _copyCsv(context, filtered, visibleColumns),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('Copy CSV'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _seasonType == NbaStatsSeasonType.regular
                  ? 'Default qualification: 50+ games. Use the triangle beside RPG, FG%, 3P% or FT% to reveal component columns.'
                  : 'Playoff statistics use the same immutable static season files as the regular-season table. The GP filter opens automatically because no playoff sample reaches 50 games.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            pager(),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              _EmptyStatsCard(
                _seasonType == NbaStatsSeasonType.playoffs
                    ? 'No playoff player rows match these filters for $_season.'
                    : 'No regular-season player rows match these filters for $_season.',
              )
            else
              WebsiteStickyStatsTable(
                columns: tableColumns,
                rows: tableRows,
                firstColumnWidth: 164,
                headerHeight: 43,
                rowHeight: 40,
              ),
            const SizedBox(height: 8),
            pager(),
            const SizedBox(height: 14),
            Text(
              'Historical rows are served directly from the precompiled local NBA corpus. No runtime NBA.com request is required to browse regular-season or playoff tables.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCsv(
    BuildContext context,
    List<NbaStatsRow> rows,
    List<_VisibleColumn> columns,
  ) async {
    final header = [
      'Player',
      'Team',
      'Pos',
      ...columns.map((item) => item.column.label),
    ];
    final lines = <String>[_csvLine(header)];
    for (final row in rows) {
      lines.add(
        _csvLine([
          row.player,
          row.team,
          row.position,
          for (final item in columns)
            _format(row.value(item.column.key), item.column),
        ]),
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${rows.length} filtered rows as CSV.')),
    );
  }
}

class _TeamLink extends StatelessWidget {
  const _TeamLink({required this.session, required this.row});

  final AppSession session;
  final NbaStatsRow row;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final teams = row.team
        .split(RegExp(r'[,/ ]+'))
        .where((item) => item.isNotEmpty && item != '—')
        .toList();
    final team = teams.length == 1 ? teams.first : '';
    return InkWell(
      onTap: team.isEmpty
          ? null
          : () => openWebsiteNbaTeamPage(
                context,
                session: session,
                teamKey: team,
                teamName: team,
              ),
      child: Text(
        row.team,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: team.isEmpty ? null : colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.width = 125,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
          initialValue: values.contains(value) ? value : values.first,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            for (final item in values)
              DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

class _MinimumDropdown extends StatelessWidget {
  const _MinimumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 104,
        child: DropdownButtonFormField<int>(
          initialValue: values.contains(value) ? value : values.first,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            for (final item in values)
              DropdownMenuItem(
                value: item,
                child: Text(item == 0 ? 'Any' : '$item+'),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

class _StatColumn {
  const _StatColumn(
    this.key,
    this.label, {
    this.percent = false,
    this.integer = false,
    this.children = const [],
  });

  final String key;
  final String label;
  final bool percent;
  final bool integer;
  final List<_StatColumn> children;
}

class _VisibleColumn {
  const _VisibleColumn(this.column, this.child);

  final _StatColumn column;
  final bool child;
}

const _baseColumns = <_StatColumn>[
  _StatColumn('gp', 'GP', integer: true),
  _StatColumn('min', 'MPG'),
  _StatColumn('pts', 'PPG'),
  _StatColumn(
    'reb',
    'RPG',
    children: [
      _StatColumn('oreb', 'ORB'),
      _StatColumn('dreb', 'DRB'),
    ],
  ),
  _StatColumn('ast', 'APG'),
  _StatColumn('stl', 'SPG'),
  _StatColumn('blk', 'BPG'),
  _StatColumn('tov', 'TPG'),
  _StatColumn('pf', 'PF'),
  _StatColumn(
    'fg_pct',
    'FG%',
    percent: true,
    children: [
      _StatColumn('fgm', 'FGM'),
      _StatColumn('fga', 'FGA'),
    ],
  ),
  _StatColumn(
    'three_pct',
    '3P%',
    percent: true,
    children: [
      _StatColumn('three_pm', '3PM'),
      _StatColumn('three_pa', '3PA'),
    ],
  ),
  _StatColumn(
    'ft_pct',
    'FT%',
    percent: true,
    children: [
      _StatColumn('ftm', 'FTM'),
      _StatColumn('fta', 'FTA'),
    ],
  ),
];

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NBA statistics unavailable',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sports Terminal could not read its precompiled static NBA season file. ${error ?? ''}',
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _EmptyStatsCard extends StatelessWidget {
  const _EmptyStatsCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(message),
          ),
        ),
      );
}

bool _matchesPosition(String value, String wanted) {
  final positions = RegExp(r'PG|SG|SF|PF|C')
      .allMatches(value.toUpperCase())
      .map((match) => match.group(0))
      .whereType<String>()
      .toSet();
  return positions.contains(wanted.toUpperCase());
}

String _format(double? value, _StatColumn column) {
  if (value == null || value.isNaN || value.isInfinite) return '—';
  if (column.integer) return value.round().toString();
  if (column.percent) {
    final scaled = value.abs() <= 1.5 ? value * 100 : value;
    return '${scaled.toStringAsFixed(1)}%';
  }
  return value.toStringAsFixed(1);
}

String _csvLine(Iterable<String> cells) => cells.map((cell) {
      final escaped = cell.replaceAll('"', '""');
      return escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')
          ? '"$escaped"'
          : escaped;
    }).join(',');
