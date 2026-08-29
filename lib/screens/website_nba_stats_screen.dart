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
  Future<NbaTerminalSeedSnapshot>? _dataFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  String _team = 'All';
  String _position = 'All';
  int _minGp = 0;
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
      _season = seasons.firstWhere(
        (item) => item.id == '2025-26',
        orElse: () => seasons.first,
      ).id;
      _dataFuture = _loadData();
    }
    return seasons;
  }

  Future<NbaTerminalSeedSnapshot> _loadData() => _api.seasonSnapshot(
        _season,
        seasonType: _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
      );

  void _reload() {
    setState(() {
      _team = 'All';
      _page = 1;
      _dataFuture = _loadData();
    });
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _team = 'All';
      _position = 'All';
      _minGp = 0;
      _minMpg = 0;
      _page = 1;
    });
  }

  List<_VisibleColumn> _visibleColumns() {
    final result = <_VisibleColumn>[];
    for (final column in _baseColumns) {
      result.add(_VisibleColumn(column, false));
      if (_expanded.contains(column.key)) {
        result.addAll(column.children.map((child) => _VisibleColumn(child, true)));
      }
    }
    return result;
  }

  Widget _headerFor(_StatColumn column) {
    if (column.children.isEmpty) return Text(column.label);
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
          Icon(open ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, size: 29),
          const SizedBox(width: 1),
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
        if (catalog.connectionState != ConnectionState.done) return const _StatsLoading();
        if (catalog.hasError || _seasons.isEmpty || _dataFuture == null) {
          return _StatsError(
            error: catalog.error,
            onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
          );
        }
        return FutureBuilder<NbaTerminalSeedSnapshot>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _StatsLoading();
            if (snapshot.hasError || snapshot.data == null) {
              return _StatsError(error: snapshot.error, onRetry: _reload);
            }
            return _buildPage(context, snapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, NbaTerminalSeedSnapshot data) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(
      data,
      basis: NbaStatsBasis.perGame,
      seasonType: _seasonType,
    );
    final query = _search.text.trim().toLowerCase();
    final teams = <String>{'All'};
    for (final row in rows) {
      teams.addAll(
        row.team.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—'),
      );
    }

    final filtered = rows.where((row) {
      if (query.isNotEmpty &&
          !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) {
        return false;
      }
      if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
      if (_position != 'All' && !_matchesPosition(row.position, _position)) return false;
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
    final safePage = _page.clamp(1, pageCount);
    if (safePage != _page) _page = safePage;
    final start = (safePage - 1) * _pageSize;
    final paged = filtered.skip(start).take(_pageSize).toList();
    final visibleColumns = _visibleColumns();
    final childTint = Theme.of(context).brightness == Brightness.dark
        ? colors.surfaceContainerHighest.withValues(alpha: .9)
        : colors.surfaceContainerHighest.withValues(alpha: .74);

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
      const WebsiteStickyStatsColumn(label: Text('Player'), width: 154),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 58),
      const WebsiteStickyStatsColumn(label: Text('Pos'), width: 50),
      for (final visible in visibleColumns)
        WebsiteStickyStatsColumn(
          label: _headerFor(visible.column),
          width: visible.child ? 58 : 60,
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
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          _TeamLink(session: widget.session, row: row),
          Text(row.position, maxLines: 1, overflow: TextOverflow.ellipsis),
          for (final visible in visibleColumns)
            Text(
              _format(row.value(visible.column.key), visible.column),
              maxLines: 1,
            ),
        ],
    ];

    return Column(
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
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _season,
                    decoration: const InputDecoration(labelText: 'Season', isDense: true),
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
                  values: const [0, 65, 60, 50, 40, 30],
                  onChanged: (value) => setState(() {
                    _minGp = value;
                    _page = 1;
                  }),
                ),
                _MinimumDropdown(
                  label: 'MPG',
                  value: _minMpg,
                  values: const [0, 20, 15, 10],
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
                  onPressed: () => _copyCsv(context, filtered, visibleColumns),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy CSV'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Use the triangle beside RPG, FG%, 3P% or FT% to reveal component columns. Expanded columns are lightly shaded.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        pager(),
        const SizedBox(height: 10),
        WebsiteStickyStatsTable(
          columns: tableColumns,
          rows: tableRows,
          firstColumnWidth: 154,
          headerHeight: 43,
          rowHeight: 42,
        ),
        const SizedBox(height: 10),
        pager(),
        const SizedBox(height: 14),
        Text(
          'Historical rows are served from the precompiled local NBA corpus. Qualification filters are applied to the selected regular-season or playoff sample; they do not change the underlying stored data.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
      ],
    );
  }

  Future<void> _copyCsv(
    BuildContext context,
    List<NbaStatsRow> rows,
    List<_VisibleColumn> columns,
  ) async {
    final header = ['Player', 'Team', 'Pos', ...columns.map((item) => item.column.label)];
    final lines = <String>[_csvLine(header)];
    for (final row in rows) {
      lines.add(
        _csvLine([
          row.player,
          row.team,
          row.position,
          for (final item in columns) _format(row.value(item.column.key), item.column),
        ]),
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${rows.length} filtered stat rows as CSV.')),
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
    this.width = 130,
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
        width: 112,
        child: DropdownButtonFormField<int>(
          initialValue: value,
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

String _csvLine(Iterable<String> values) => values.map((value) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }).join(',');

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.error, required this.onRetry});

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
                'NBA statistics unavailable',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text('Sports Terminal could not read its precompiled static NBA season file. ${error ?? ''}'),
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
