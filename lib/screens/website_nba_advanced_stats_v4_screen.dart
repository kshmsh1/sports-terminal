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

class WebsiteNbaAdvancedStatsScreen extends StatefulWidget {
  const WebsiteNbaAdvancedStatsScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaAdvancedStatsScreen> createState() =>
      _WebsiteNbaAdvancedStatsScreenState();
}

class _WebsiteNbaAdvancedStatsScreenState
    extends State<WebsiteNbaAdvancedStatsScreen> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();

  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<NbaTerminalSeedSnapshot>? _snapshotFuture;
  List<WebsiteNbaSeason> _seasons = const [];

  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _category = 'Overview';
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
      _minGp = next == NbaStatsSeasonType.regular ? 50 : 0;
      _team = 'All';
      _page = 1;
      _snapshotFuture = _loadSnapshot();
    });
  }

  void _selectCategory(String category) {
    final definition = _categories.firstWhere((item) => item.name == category);
    setState(() {
      _category = category;
      _sortKey = definition.metrics.first.key;
      _descending = true;
      _expanded.clear();
      _page = 1;
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

  List<_VisibleMetric> _visibleMetrics(_Category category) {
    final result = <_VisibleMetric>[];
    for (final metric in category.metrics) {
      result.add(_VisibleMetric(metric, false));
      if (_expanded.contains(metric.key)) {
        result.addAll(
          metric.children.map((child) => _VisibleMetric(child, true)),
        );
      }
    }
    return result;
  }

  Widget _metricHeader(_Metric metric) {
    final label = metric.displayLabel(_basis);
    if (metric.children.isEmpty) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final open = _expanded.contains(metric.key);
    return InkWell(
      onTap: () => setState(() {
        if (open) {
          _expanded.remove(metric.key);
        } else {
          _expanded.add(metric.key);
        }
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            open
                ? Icons.arrow_drop_down_rounded
                : Icons.arrow_right_rounded,
            size: 26,
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
          return const _Loading();
        }
        if (catalog.hasError || _seasons.isEmpty || _snapshotFuture == null) {
          return _ErrorState(
            error: catalog.error,
            onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
          );
        }
        return FutureBuilder<NbaTerminalSeedSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _Loading();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _ErrorState(
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

    // The engine is intentionally asked for a per-game base row only. The page
    // converts that stable base to totals/per-36/per-48/per-75/per-100. This
    // avoids mixing NBA.com's per-game POSS field with season-total counting
    // stats, which was the cause of the previous 2,000+ MPG / 600+ PPG outputs.
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

    final definition =
        _categories.firstWhere((item) => item.name == _category);
    final visibleMetrics = _visibleMetrics(definition);
    filtered.sort((a, b) {
      final left = _metricValue(a, _sortKey, _basis);
      final right = _metricValue(b, _sortKey, _basis);
      if (left == null && right == null) return a.player.compareTo(b.player);
      if (left == null) return 1;
      if (right == null) return -1;
      return _descending ? right.compareTo(left) : left.compareTo(right);
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

    final childTint = Theme.of(context).brightness == Brightness.dark
        ? colors.primaryContainer.withValues(alpha: .27)
        : colors.primaryContainer.withValues(alpha: .48);

    final tableColumns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Player'), width: 164),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 58),
      const WebsiteStickyStatsColumn(label: Text('Pos'), width: 48),
      for (final item in visibleMetrics)
        WebsiteStickyStatsColumn(
          label: _metricHeader(item.metric),
          width: item.child ? 67 : 70,
          numeric: true,
          backgroundColor: item.child ? childTint : null,
          onTap: () => setState(() {
            if (_sortKey == item.metric.key) {
              _descending = !_descending;
            } else {
              _sortKey = item.metric.key;
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
          for (final item in visibleMetrics)
            Text(
              _formatMetric(
                _metricValue(row, item.metric.key, _basis),
                item.metric,
                _basis,
              ),
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
              'Advanced Stats',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deep player statistics organized by basketball questions, with explicit source boundaries and stable rate conversions.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
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
                      width: 148,
                      child: DropdownButtonFormField<NbaStatsBasis>(
                        initialValue: _basis,
                        decoration: const InputDecoration(
                          labelText: 'Rate',
                          isDense: true,
                        ),
                        items: [
                          for (final item in NbaStatsBasis.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _basis = value;
                            _page = 1;
                          });
                        },
                      ),
                    ),
                    _StringDropdown(
                      label: 'Stat group',
                      value: _category,
                      values: [for (final item in _categories) item.name],
                      width: 205,
                      onChanged: _selectCategory,
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
                      width: 112,
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
                          _copyCsv(context, filtered, visibleMetrics),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('Copy CSV'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(item.name),
                        selected: item.name == _category,
                        onSelected: (_) => _selectCategory(item.name),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              definition.description,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _basisDescription(_basis),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            if (definition.metrics.any((metric) => metric.children.isNotEmpty)) ...[
              const SizedBox(height: 4),
              Text(
                'Select the triangle beside an expandable column to reveal its lightly shaded component columns. Missing source coverage remains visible as —.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            pager(),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              _EmptyCard(
                _seasonType == NbaStatsSeasonType.playoffs
                    ? 'No playoff rows match these filters for $_season.'
                    : 'No regular-season rows match these filters for $_season.',
              )
            else
              WebsiteStickyStatsTable(
                columns: tableColumns,
                rows: tableRows,
                firstColumnWidth: 164,
                headerHeight: 46,
                rowHeight: 40,
              ),
            const SizedBox(height: 8),
            pager(),
            const SizedBox(height: 16),
            _StatGlossary(category: definition, basis: _basis),
            const SizedBox(height: 12),
            Text(
              'Source boundary: the schema keeps requested columns visible even when a historical source does not contain the metric. Sourced fields and transparent derivations are shown; unavailable values remain —.',
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
    List<_VisibleMetric> metrics,
  ) async {
    final header = [
      'Player',
      'Team',
      'Pos',
      ...metrics.map((item) => item.metric.displayLabel(_basis)),
    ];
    final lines = <String>[_csvLine(header)];
    for (final row in rows) {
      lines.add(
        _csvLine([
          row.player,
          row.team,
          row.position,
          for (final item in metrics)
            _formatMetric(
              _metricValue(row, item.metric.key, _basis),
              item.metric,
              _basis,
            ),
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
          color: team.isEmpty ? null : Theme.of(context).colorScheme.primary,
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
    this.width = 124,
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

class _VisibleMetric {
  const _VisibleMetric(this.metric, this.child);

  final _Metric metric;
  final bool child;
}

class _Category {
  const _Category(this.name, this.description, this.metrics);

  final String name;
  final String description;
  final List<_Metric> metrics;
}

class _Metric {
  const _Metric(
    this.key,
    this.label,
    this.glossary, {
    this.totalLabel,
    this.rateAbbreviation,
    this.rateSensitive = false,
    this.percent = false,
    this.signed = false,
    this.integer = false,
    this.children = const [],
  });

  final String key;
  final String label;
  final String glossary;
  final String? totalLabel;
  final String? rateAbbreviation;
  final bool rateSensitive;
  final bool percent;
  final bool signed;
  final bool integer;
  final List<_Metric> children;

  String displayLabel(NbaStatsBasis basis) {
    if (!rateSensitive) return label;
    final stem = rateAbbreviation ?? label.replaceAll(' PG', '').replaceAll('PG', '');
    switch (basis) {
      case NbaStatsBasis.perGame:
        return label;
      case NbaStatsBasis.totals:
        return totalLabel ?? stem;
      case NbaStatsBasis.per36:
        return '$stem/36';
      case NbaStatsBasis.per48:
        return '$stem/48';
      case NbaStatsBasis.per75:
        return '$stem/75';
      case NbaStatsBasis.per100:
        return '$stem/100';
    }
  }
}

_Metric countMetric(
  String key,
  String perGameLabel,
  String totalLabel,
  String abbreviation,
  String glossary, {
  List<_Metric> children = const [],
}) =>
    _Metric(
      key,
      perGameLabel,
      glossary,
      totalLabel: totalLabel,
      rateAbbreviation: abbreviation,
      rateSensitive: true,
      children: children,
    );

_Metric childCount(
  String key,
  String label,
  String totalLabel,
  String abbreviation,
  String glossary,
) =>
    _Metric(
      key,
      label,
      glossary,
      totalLabel: totalLabel,
      rateAbbreviation: abbreviation,
      rateSensitive: true,
    );

final _categories = <_Category>[
  _Category(
    'Overview',
    'Core production, traditional shooting efficiency and headline impact measures.',
    [
      const _Metric('gp', 'GP', 'Games played.', integer: true),
      countMetric('min', 'MPG', 'Minutes', 'MIN', 'Minutes played.'),
      countMetric('pts', 'PPG', 'Points', 'PTS', 'Points scored.'),
      countMetric(
        'reb',
        'RPG',
        'Rebounds',
        'REB',
        'Total rebounds.',
        children: [
          childCount('oreb', 'ORB', 'Offensive Rebounds', 'OREB', 'Offensive rebounds.'),
          childCount('dreb', 'DREB', 'Defensive Rebounds', 'DREB', 'Defensive rebounds.'),
        ],
      ),
      countMetric('ast', 'APG', 'Assists', 'AST', 'Assists.'),
      countMetric('stl', 'SPG', 'Steals', 'STL', 'Steals.'),
      countMetric('blk', 'BPG', 'Blocks', 'BLK', 'Blocks.'),
      countMetric('tov', 'TPG', 'Turnovers', 'TOV', 'Turnovers.'),
      countMetric('pf', 'PF PG', 'Personal Fouls', 'PF', 'Personal fouls.'),
      _Metric(
        'fg_pct',
        'FG%',
        'Field-goal percentage.',
        percent: true,
        children: [
          childCount('fgm', 'FGM', 'Field Goals Made', 'FGM', 'Field goals made.'),
          childCount('fga', 'FGA', 'Field Goal Attempts', 'FGA', 'Field-goal attempts.'),
        ],
      ),
      _Metric(
        'three_pct',
        '3P%',
        'Three-point percentage.',
        percent: true,
        children: [
          childCount('three_pm', '3PM', 'Three-Pointers Made', '3PM', 'Three-pointers made.'),
          childCount('three_pa', '3PA', 'Three-Point Attempts', '3PA', 'Three-point attempts.'),
        ],
      ),
      _Metric(
        'ft_pct',
        'FT%',
        'Free-throw percentage.',
        percent: true,
        children: [
          childCount('ftm', 'FTM', 'Free Throws Made', 'FTM', 'Free throws made.'),
          childCount('fta', 'FTA', 'Free Throw Attempts', 'FTA', 'Free-throw attempts.'),
        ],
      ),
      const _Metric('pace', 'Pace', 'Estimated possessions per 48 team minutes.'),
      const _Metric('pie', 'PIE', 'NBA Player Impact Estimate.'),
      const _Metric('per', 'PER', 'Player Efficiency Rating.'),
      const _Metric(
        'bpm',
        'BPM',
        'Box Plus/Minus.',
        signed: true,
        children: [
          _Metric('obpm', 'OBPM', 'Offensive Box Plus/Minus.', signed: true),
          _Metric('dbpm', 'DBPM', 'Defensive Box Plus/Minus.', signed: true),
        ],
      ),
      const _Metric('vorp', 'VORP', 'Value Over Replacement Player.'),
      const _Metric('ws', 'WS', 'Win Shares.'),
      const _Metric('epm', 'EPM', 'Estimated Plus-Minus.', signed: true),
      const _Metric('lebron', 'LEBRON', 'LEBRON impact metric.', signed: true),
    ],
  ),
  _Category(
    'Shooting & Efficiency',
    'Scoring efficiency, shot-location mix, assisted creation and three-point shot-type splits.',
    [
      const _Metric('fg_pct', 'FG%', 'Field-goal percentage.', percent: true),
      const _Metric('three_pct', '3P%', 'Three-point percentage.', percent: true),
      const _Metric('ft_pct', 'FT%', 'Free-throw percentage.', percent: true),
      const _Metric('efg_pct', 'eFG%', 'Effective field-goal percentage.', percent: true),
      const _Metric('ts_pct', 'TS%', 'True shooting percentage.', percent: true),
      const _Metric('ftr', 'FTR', 'Free-throw attempt rate.'),
      const _Metric('three_par', '3PAr', 'Three-point attempt rate.'),
      const _Metric('pps', 'PPS', 'Points per field-goal attempt.'),
      const _Metric('rim_freq', 'Rim Freq', 'Share of attempts at the rim.', percent: true),
      const _Metric('rim_fg_pct', 'Rim FG%', 'Field-goal percentage at the rim.', percent: true),
      const _Metric('paint_freq', 'Paint Freq', 'Share of attempts in the paint.', percent: true),
      const _Metric('paint_fg_pct', 'Paint FG%', 'Paint field-goal percentage.', percent: true),
      const _Metric('midrange_freq', 'Mid Freq', 'Share of attempts from midrange.', percent: true),
      const _Metric('midrange_fg_pct', 'Mid FG%', 'Midrange field-goal percentage.', percent: true),
      const _Metric('three_freq', '3P Freq', 'Share of attempts from three.', percent: true),
      const _Metric('half_court_freq', 'Halfcourt Freq', 'Share of attempts in halfcourt contexts.', percent: true),
      const _Metric('half_court_fg_pct', 'Halfcourt FG%', 'Halfcourt field-goal percentage.', percent: true),
      countMetric('heaves_pg', 'HPG', 'Heaves', 'HEAVE', 'Heave attempts.'),
      const _Metric('corner_three_freq', 'Corner 3 Freq', 'Corner-three attempt frequency.', percent: true),
      const _Metric('corner_three_pct', 'Corner 3P%', 'Corner-three percentage.', percent: true),
      const _Metric('right_corner_three_freq', 'R Corner Freq', 'Right-corner three frequency.', percent: true),
      const _Metric('right_corner_three_pct', 'R Corner 3P%', 'Right-corner three percentage.', percent: true),
      const _Metric('left_corner_three_freq', 'L Corner Freq', 'Left-corner three frequency.', percent: true),
      const _Metric('left_corner_three_pct', 'L Corner 3P%', 'Left-corner three percentage.', percent: true),
      const _Metric('catch_shoot_three_freq', 'C&S 3 Freq', 'Catch-and-shoot three frequency.', percent: true),
      const _Metric('catch_shoot_three_pct', 'C&S 3P%', 'Catch-and-shoot three percentage.', percent: true),
      const _Metric('pullup_three_freq', 'Pull-Up 3 Freq', 'Pull-up three frequency.', percent: true),
      const _Metric('pullup_three_pct', 'Pull-Up 3P%', 'Pull-up three percentage.', percent: true),
      const _Metric('right_wing_three_freq', 'R Wing Freq', 'Right-wing three frequency.', percent: true),
      const _Metric('right_wing_three_pct', 'R Wing 3P%', 'Right-wing three percentage.', percent: true),
      const _Metric('left_wing_three_freq', 'L Wing Freq', 'Left-wing three frequency.', percent: true),
      const _Metric('left_wing_three_pct', 'L Wing 3P%', 'Left-wing three percentage.', percent: true),
      const _Metric('middle_three_freq', 'Middle 3 Freq', 'Above-the-break middle three frequency.', percent: true),
      const _Metric('middle_three_pct', 'Middle 3P%', 'Above-the-break middle three percentage.', percent: true),
      const _Metric('assisted_fg_pct', 'Assisted FG%', 'Share of made field goals that were assisted.', percent: true),
      const _Metric('unassisted_fg_pct', 'Unassisted FG%', 'Share of made field goals that were unassisted.', percent: true),
      countMetric('assisted_pts_pg', 'Assisted PPG', 'Assisted Points', 'AST PTS', 'Points on assisted field goals.'),
      countMetric('unassisted_pts_pg', 'Unassisted PPG', 'Unassisted Points', 'UNAST PTS', 'Points on unassisted field goals.'),
    ],
  ),
  _Category(
    'Playmaking & Creation',
    'Passing volume, creation quality, assist opportunity, touch profile and ball-security measures.',
    [
      countMetric('ast', 'APG', 'Assists', 'AST', 'Assists.'),
      countMetric('tov', 'TPG', 'Turnovers', 'TOV', 'Turnovers.'),
      countMetric('screen_ast_pg', 'Screen APG', 'Screen Assists', 'SCR AST', 'Screen assists.'),
      countMetric('secondary_ast_pg', 'Secondary APG', 'Secondary Assists', '2AST', 'Secondary or hockey assists.'),
      countMetric('potential_ast_pg', 'Potential APG', 'Potential Assists', 'POT AST', 'Potential assists.'),
      countMetric('passes_pg', 'Passes PG', 'Passes', 'PASS', 'Passes made.'),
      countMetric('passes_received_pg', 'Passes Rec PG', 'Passes Received', 'REC PASS', 'Passes received.'),
      const _Metric('ast_tov', 'AST:TO', 'Assist-to-turnover ratio.'),
      const _Metric('ast_pct', 'AST%', 'Assist percentage.', percent: true),
      const _Metric('tov_pct', 'TOV%', 'Turnover percentage.', percent: true),
      countMetric('ft_ast_pg', 'FT APG', 'Free-Throw Assists', 'FT AST', 'Free-throw assists.'),
      const _Metric('adj_ast_ratio', 'Adj AST Ratio', 'Adjusted assist ratio including free-throw and secondary-assist creation.'),
      const _Metric('time_per_touch', 'Time / Touch', 'Average seconds per touch.'),
      const _Metric('dribbles_per_touch', 'Dribbles / Touch', 'Average dribbles per touch.'),
      const _Metric('pass_windows_opened', 'Pass Windows', 'Passing windows opened by offensive gravity.'),
      const _Metric('passing_lanes_opened', 'Passing Lanes', 'Passing lanes created for teammates.'),
      const _Metric('passing_decision_time', 'Pass Decision', 'Average passing decision time.'),
      const _Metric('panic_turnover_rate', 'Panic TOV%', 'Turnover rate under acute pressure.', percent: true),
    ],
  ),
  _Category(
    'Defense',
    'Box-score events, hustle activity, defended shooting, contests, deterrence and foul discipline.',
    [
      countMetric(
        'stl',
        'SPG',
        'Steals',
        'STL',
        'Steals.',
        children: const [
          _Metric('stl_pct', 'STL%', 'Steal percentage.', percent: true),
        ],
      ),
      countMetric(
        'blk',
        'BPG',
        'Blocks',
        'BLK',
        'Blocks.',
        children: const [
          _Metric('blk_pct', 'BLK%', 'Block percentage.', percent: true),
        ],
      ),
      countMetric('deflections_pg', 'DPG', 'Deflections', 'DEFL', 'Deflections.'),
      countMetric(
        'dreb',
        'DREB',
        'Defensive Rebounds',
        'DREB',
        'Defensive rebounds.',
        children: [
          childCount('contested_dreb_pg', 'Cont. DREB', 'Contested Defensive Rebounds', 'C-DREB', 'Contested defensive rebounds.'),
          childCount('uncontested_dreb_pg', 'Uncont. DREB', 'Uncontested Defensive Rebounds', 'U-DREB', 'Uncontested defensive rebounds.'),
          const _Metric('dreb_pct', 'DREB%', 'Defensive rebound percentage.', percent: true),
        ],
      ),
      countMetric('charges_drawn_pg', 'Charges PG', 'Charges Drawn', 'CHG', 'Charges drawn.'),
      countMetric(
        'contested_shots_pg',
        'Contests PG',
        'Contested Shots',
        'CONTEST',
        'Contested shots.',
        children: [
          childCount('contested_shots_2pt_pg', '2PT Cont.', '2PT Contested Shots', '2PT-C', 'Two-point shots contested.'),
          childCount('contested_shots_3pt_pg', '3PT Cont.', '3PT Contested Shots', '3PT-C', 'Three-point shots contested.'),
        ],
      ),
      countMetric('loose_balls_recovered_pg', 'Loose Balls PG', 'Loose Balls Recovered', 'LBR', 'Loose balls recovered.'),
      _Metric(
        'dfg_pct',
        'DFG%',
        'Opponent field-goal percentage on attempts defended by the player.',
        percent: true,
        children: [
          childCount('dfgm', 'DFGM', 'Defended Field Goals Made', 'DFGM', 'Opponent field goals made when defended.'),
          childCount('dfga', 'DFGA', 'Defended Field Goal Attempts', 'DFGA', 'Opponent field-goal attempts when defended.'),
        ],
      ),
      const _Metric('rim_dfg_pct', 'Rim DFG%', 'Opponent rim FG% when defended by the player.', percent: true),
      const _Metric('three_dfg_pct', '3P DFG%', 'Opponent 3P% when defended by the player.', percent: true),
      const _Metric('midrange_dfg_pct', 'Mid DFG%', 'Opponent midrange FG% when defended by the player.', percent: true),
      const _Metric('blow_by_rate', 'Blow-By Rate', 'Rate at which the defender is beaten off the dribble.', percent: true),
      const _Metric('contest_distance', 'Contest Dist', 'Average defender distance on contests.'),
      const _Metric('help_defense', 'Help Defense', 'Source-backed help-defense activity or impact.'),
      const _Metric('deterrence_rate', 'Deterrence', 'Estimated shot deterrence rate.', percent: true),
      const _Metric('dbpm', 'DBPM', 'Defensive Box Plus/Minus.', signed: true),
      const _Metric('drtg', 'DRtg', 'Defensive rating.'),
    ],
  ),
  _Category(
    'Rebounding',
    'Overall, offensive and defensive rebounding volume plus contested and box-out context.',
    [
      countMetric(
        'reb',
        'RPG',
        'Rebounds',
        'REB',
        'Total rebounds.',
        children: [
          childCount('contested_reb_pg', 'Cont. RPG', 'Contested Rebounds', 'C-REB', 'Contested rebounds.'),
          childCount('uncontested_reb_pg', 'Uncont. RPG', 'Uncontested Rebounds', 'U-REB', 'Uncontested rebounds.'),
          const _Metric('reb_pct', 'TRB%', 'Total rebound percentage.', percent: true),
        ],
      ),
      countMetric(
        'dreb',
        'DREB',
        'Defensive Rebounds',
        'DREB',
        'Defensive rebounds.',
        children: [
          childCount('contested_dreb_pg', 'Cont. DREB', 'Contested Defensive Rebounds', 'C-DREB', 'Contested defensive rebounds.'),
          childCount('uncontested_dreb_pg', 'Uncont. DREB', 'Uncontested Defensive Rebounds', 'U-DREB', 'Uncontested defensive rebounds.'),
          const _Metric('dreb_pct', 'DRB%', 'Defensive rebound percentage.', percent: true),
        ],
      ),
      countMetric(
        'oreb',
        'OREB',
        'Offensive Rebounds',
        'OREB',
        'Offensive rebounds.',
        children: [
          childCount('contested_oreb_pg', 'Cont. OREB', 'Contested Offensive Rebounds', 'C-OREB', 'Contested offensive rebounds.'),
          childCount('uncontested_oreb_pg', 'Uncont. OREB', 'Uncontested Offensive Rebounds', 'U-OREB', 'Uncontested offensive rebounds.'),
          const _Metric('oreb_pct', 'ORB%', 'Offensive rebound percentage.', percent: true),
        ],
      ),
      countMetric('box_outs_pg', 'Box Outs PG', 'Box Outs', 'BOX', 'Box-outs.'),
      const _Metric('box_out_pct', 'Box Out %', 'Player rebound share following box-outs.', percent: true),
      countMetric('tap_outs_pg', 'Tap Outs PG', 'Tap Outs', 'TAP', 'Rebound tap-outs.'),
      countMetric('deferred_rebounds_pg', 'Deferred Reb PG', 'Deferred Rebounds', 'DEF-REB', 'Rebounds intentionally deferred to teammates.'),
    ],
  ),
  _Category(
    'Impact',
    'Team impact, all-in-one value metrics and source-backed adjusted plus-minus families.',
    const [
      _Metric('ortg', 'ORtg', 'Offensive rating.'),
      _Metric('drtg', 'DRtg', 'Defensive rating.'),
      _Metric('net_rating', 'Net Rating', 'Offensive rating minus defensive rating.', signed: true),
      _Metric('on_off_net', 'On/Off Diff', 'Net-rating swing between on-court and off-court minutes.', signed: true),
      _Metric('per', 'PER', 'Player Efficiency Rating.'),
      _Metric('bpm', 'BPM', 'Box Plus/Minus.', signed: true, children: [
        _Metric('obpm', 'OBPM', 'Offensive Box Plus/Minus.', signed: true),
        _Metric('dbpm', 'DBPM', 'Defensive Box Plus/Minus.', signed: true),
      ]),
      _Metric('vorp', 'VORP', 'Value Over Replacement Player.'),
      _Metric('ws', 'WS', 'Win Shares.'),
      _Metric('epm', 'EPM', 'Estimated Plus-Minus.', signed: true),
      _Metric('lebron', 'LEBRON', 'LEBRON impact metric.', signed: true),
      _Metric('darko', 'DARKO', 'DARKO player-impact estimate.', signed: true),
      _Metric('rapm', 'RAPM', 'Regularized Adjusted Plus-Minus.', signed: true),
      _Metric('la_rapm', 'LA-RAPM', 'Luck-adjusted RAPM.', signed: true),
      _Metric('warv', 'WARV', 'Wins Above Replacement Value.'),
      _Metric('pie', 'PIE', 'NBA Player Impact Estimate.'),
    ],
  ),
  _Category(
    'Rate Adjusted',
    'Core counting production on the selected rate basis. Totals uses full-season totals; possession modes use estimated player possessions per game.',
    [
      countMetric('min', 'MPG', 'Minutes', 'MIN', 'Minutes played.'),
      countMetric('pts', 'PPG', 'Points', 'PTS', 'Points.'),
      countMetric('reb', 'RPG', 'Rebounds', 'REB', 'Rebounds.'),
      countMetric('ast', 'APG', 'Assists', 'AST', 'Assists.'),
      countMetric('stl', 'SPG', 'Steals', 'STL', 'Steals.'),
      countMetric('blk', 'BPG', 'Blocks', 'BLK', 'Blocks.'),
      countMetric('tov', 'TPG', 'Turnovers', 'TOV', 'Turnovers.'),
      countMetric('fgm', 'FGM PG', 'Field Goals Made', 'FGM', 'Field goals made.'),
      countMetric('three_pm', '3PM PG', 'Three-Pointers Made', '3PM', 'Three-pointers made.'),
      countMetric('ftm', 'FTM PG', 'Free Throws Made', 'FTM', 'Free throws made.'),
      const _Metric('usg_pct', 'Usage', 'Usage percentage.', percent: true),
      const _Metric('pace', 'Pace', 'Estimated team pace.'),
    ],
  ),
  _Category(
    'Clutch',
    'Late-and-close scoring, shooting, playmaking and defensive production when supplied by the source.',
    const [
      _Metric('clutch_gp', 'Clutch GP', 'Clutch games played.', integer: true),
      _Metric('clutch_min', 'Clutch MIN', 'Clutch minutes.'),
      _Metric('clutch_pts', 'CPPG', 'Clutch points per game.'),
      _Metric('clutch_reb', 'CRPG', 'Clutch rebounds per game.'),
      _Metric('clutch_ast', 'CAPG', 'Clutch assists per game.'),
      _Metric('clutch_stl', 'CSPG', 'Clutch steals per game.'),
      _Metric('clutch_blk', 'CBPG', 'Clutch blocks per game.'),
      _Metric('clutch_tov', 'CTPG', 'Clutch turnovers per game.'),
      _Metric('clutch_pf', 'Clutch PF', 'Clutch personal fouls.'),
      _Metric('clutch_fg_pct', 'Clutch FG%', 'Clutch field-goal percentage.', percent: true),
      _Metric('clutch_three_pct', 'Clutch 3P%', 'Clutch three-point percentage.', percent: true),
      _Metric('clutch_ft_pct', 'Clutch FT%', 'Clutch free-throw percentage.', percent: true),
      _Metric('clutch_plus_minus', 'Clutch +/-', 'Clutch plus-minus.', signed: true),
    ],
  ),
  _Category(
    'Gravity & Spacing',
    'Offensive attention, shot gravity, drive gravity and spacing effects.',
    const [
      _Metric('gravity', 'Gravity', 'Source-backed offensive gravity.'),
      _Metric('offensive_gravity', 'Off. Gravity', 'Overall offensive gravity.'),
      _Metric('shot_gravity', 'Shot Gravity', 'Defensive attention generated by shooting threat.'),
      _Metric('drive_gravity', 'Drive Gravity', 'Defensive attention generated on drives.'),
      _Metric('spacing_value', 'Spacing', 'Estimated spacing value for teammates.'),
      _Metric('double_team_rate', 'Double-Team Rate', 'Share of possessions drawing a double team.', percent: true),
      _Metric('freeze_time', 'Freeze Time', 'Time defenders are held by offensive threat.'),
      _Metric('pass_windows_opened', 'Pass Windows', 'Passing windows opened for teammates.'),
      _Metric('blitz_escape_rate', 'Blitz Escape%', 'Success rate escaping blitzes or traps.', percent: true),
      _Metric('double_team_navigation', 'Double-Team Nav', 'Source-backed double-team navigation measure.'),
      _Metric('triple_team_navigation', 'Triple-Team Nav', 'Source-backed triple-team navigation measure.'),
    ],
  ),
  _Category(
    'On / Off',
    'On-court and off-court team performance splits.',
    const [
      _Metric('on_off_net', 'On/Off Net', 'Net-rating swing between player-on and player-off minutes.', signed: true),
      _Metric('on_court_net', 'On-Court Net', 'Team net rating with the player on court.', signed: true),
      _Metric('off_court_net', 'Off-Court Net', 'Team net rating with the player off court.', signed: true),
      _Metric('on_court_ortg', 'On ORtg', 'Team offensive rating with player on court.'),
      _Metric('off_court_ortg', 'Off ORtg', 'Team offensive rating with player off court.'),
      _Metric('on_court_drtg', 'On DRtg', 'Team defensive rating with player on court.'),
      _Metric('off_court_drtg', 'Off DRtg', 'Team defensive rating with player off court.'),
    ],
  ),
  _Category(
    'Lineups & Roles',
    'Lineup context, screening role and lineup-level impact.',
    [
      const _Metric('lineup_net', 'Lineup Net', 'Net rating for qualifying lineups associated with the player.', signed: true),
      countMetric('screens_set_pg', 'Screens Set PG', 'Screens Set', 'SCR SET', 'Screens set.'),
      countMetric('screens_used_pg', 'Screens Used PG', 'Screens Used', 'SCR USE', 'Screens used as ball handler.'),
      const _Metric('starter_pct', 'Starter%', 'Share of appearances as a starter.', percent: true),
      const _Metric('bench_pct', 'Bench%', 'Share of appearances off the bench.', percent: true),
    ],
  ),
  _Category(
    'Movement & Physical',
    'Movement load, touch mechanics and physical measurements.',
    const [
      _Metric('usg_pct', 'Usage', 'Usage percentage.', percent: true),
      _Metric('distance_miles', 'Distance', 'Distance traveled.'),
      _Metric('avg_speed', 'Avg Speed', 'Average on-court speed.'),
      _Metric('avg_speed_off', 'Speed Off', 'Average offensive speed.'),
      _Metric('avg_speed_def', 'Speed Def', 'Average defensive speed.'),
      _Metric('time_per_touch', 'Time / Touch', 'Average seconds per touch.'),
      _Metric('dribbles_per_touch', 'Dribbles / Touch', 'Average dribbles per touch.'),
      _Metric('height', 'Height', 'Listed or measured height.'),
      _Metric('weight', 'Weight', 'Listed or measured weight.'),
      _Metric('wingspan', 'Wingspan', 'Measured wingspan.'),
      _Metric('standing_reach', 'Standing Reach', 'Measured standing reach.'),
      _Metric('hand_length', 'Hand Length', 'Measured hand length.'),
      _Metric('hand_width', 'Hand Width', 'Measured hand width.'),
      _Metric('standing_jump', 'Standing Vert', 'Standing vertical leap.'),
      _Metric('max_vertical_jump', 'Max Vert', 'Maximum vertical leap.'),
      _Metric('lane_agility', 'Lane Agility', 'Lane-agility drill time.'),
      _Metric('three_quarter_sprint', '3/4 Sprint', 'Three-quarter-court sprint time.'),
    ],
  ),
  _Category(
    'Play Types',
    'Possession efficiency for isolation, transition, pick-and-roll, post-up, spot-up, drives and cuts.',
    const [
      _Metric('isolation_ppp', 'Isolation PPP', 'Points per isolation possession.'),
      _Metric('transition_off_ppp', 'Transition Off PPP', 'Offensive transition points per possession.'),
      _Metric('transition_def_ppp', 'Transition Def PPP', 'Defensive transition points allowed per possession.'),
      _Metric('pnr_ball_handler_ppp', 'PnR BH PPP', 'Pick-and-roll ball-handler points per possession.'),
      _Metric('pnr_roll_man_ppp', 'PnR Roll PPP', 'Pick-and-roll roll-man points per possession.'),
      _Metric('post_up_ppp', 'Post-Up PPP', 'Post-up points per possession.'),
      _Metric('spot_up_ppp', 'Spot-Up PPP', 'Spot-up points per possession.'),
      _Metric('cut_ppp', 'Cut PPP', 'Cutting points per possession.'),
      _Metric('backdoor_cut_freq', 'Backdoor Cut%', 'Backdoor-cut frequency.', percent: true),
      _Metric('v_cut_freq', 'V-Cut%', 'V-cut frequency.', percent: true),
      _Metric('l_cut_freq', 'L-Cut%', 'L-cut frequency.', percent: true),
      _Metric('drive_ppp', 'Drive PPP', 'Points per drive possession.'),
      _Metric('drive_pts_pg', 'Drive PPG', 'Points per game on drives.'),
      _Metric('drive_ast_pg', 'Drive APG', 'Assists per game generated on drives.'),
    ],
  ),
  _Category(
    'Hustle & Box Outs',
    'Hustle events, screening value and box-out outcomes from tracked sources.',
    [
      countMetric('screen_ast_pg', 'Screen APG', 'Screen Assists', 'SCR AST', 'Screen assists.'),
      countMetric('screen_ast_points_pg', 'Screen PTS PG', 'Screen Assist Points', 'SCR PTS', 'Points created by screen assists.'),
      countMetric('deflections_pg', 'Deflections PG', 'Deflections', 'DEFL', 'Deflections.'),
      countMetric('loose_balls_recovered_pg', 'Loose Balls PG', 'Loose Balls Recovered', 'LBR', 'Loose balls recovered.'),
      countMetric('charges_drawn_pg', 'Charges PG', 'Charges Drawn', 'CHG', 'Charges drawn.'),
      countMetric('contested_shots_pg', 'Contests PG', 'Contested Shots', 'CONTEST', 'Contested shots.'),
      countMetric('box_outs_pg', 'Box Outs PG', 'Box Outs', 'BOX', 'Box-outs.'),
      const _Metric('box_out_pct', 'Box Out %', 'Player rebound percentage following box-outs.', percent: true),
    ],
  ),
  _Category(
    'Touches & Drives',
    'Touches, drives and decision-speed measures.',
    [
      countMetric('touches_pg', 'Touches PG', 'Touches', 'TOUCH', 'Touches.'),
      countMetric('front_court_touches_pg', 'Frontcourt Touches PG', 'Frontcourt Touches', 'FC TOUCH', 'Frontcourt touches.'),
      countMetric('paint_touches_pg', 'Paint Touches PG', 'Paint Touches', 'PAINT', 'Paint touches.'),
      countMetric('elbow_touches_pg', 'Elbow Touches PG', 'Elbow Touches', 'ELBOW', 'Elbow touches.'),
      countMetric('post_touches_pg', 'Post Touches PG', 'Post Touches', 'POST', 'Post touches.'),
      countMetric('drives_pg', 'Drives PG', 'Drives', 'DRIVE', 'Drives.'),
      countMetric('drive_pts_pg', 'Drive PPG', 'Drive Points', 'DRV PTS', 'Points generated on drives.'),
      countMetric('drive_ast_pg', 'Drive APG', 'Drive Assists', 'DRV AST', 'Assists generated on drives.'),
      const _Metric('scoring_decision_time', 'Score Decision', 'Average scoring decision time.'),
      const _Metric('passing_decision_time', 'Pass Decision', 'Average passing decision time.'),
      const _Metric('driving_decision_time', 'Drive Decision', 'Average driving decision time.'),
      const _Metric('anticipation', 'Anticipation', 'Source-backed anticipation measure.'),
      const _Metric('whistle_reaction', 'Whistle Reaction', 'Source-backed whistle-reaction measure.'),
    ],
  ),
  _Category(
    'Discipline & Events',
    'Foul types, sanctions, violations and end-of-clock events.',
    [
      countMetric('technical_fouls_pg', 'Tech PG', 'Technical Fouls', 'TECH', 'Technical fouls.'),
      countMetric('shooting_fouls_pg', 'Shooting Fouls PG', 'Shooting Fouls', 'S-FL', 'Shooting fouls.'),
      countMetric('offensive_fouls_pg', 'Off. Fouls PG', 'Offensive Fouls', 'O-FL', 'Offensive fouls.'),
      countMetric('defensive_fouls_pg', 'Def. Fouls PG', 'Defensive Fouls', 'D-FL', 'Defensive fouls.'),
      countMetric('other_fouls_pg', 'Other Fouls PG', 'Other Fouls', 'OTH-FL', 'Other categorized fouls.'),
      countMetric('ejections_pg', 'Ejections PG', 'Ejections', 'EJECT', 'Ejections.'),
      countMetric('disqualifications_pg', 'DQ PG', 'Disqualifications', 'DQ', 'Disqualifications.'),
      countMetric('suspensions_pg', 'Suspensions PG', 'Suspensions', 'SUSP', 'Suspensions.'),
      countMetric('game_buzzer_beaters_pg', 'Game BB PG', 'Game Buzzer Beaters', 'GBB', 'Made shots beating the final game buzzer.'),
      countMetric('quarter_buzzer_beaters_pg', 'Quarter BB PG', 'Quarter Buzzer Beaters', 'QBB', 'Made shots beating a quarter-ending buzzer.'),
      countMetric('shot_clock_buzzer_beaters_pg', 'Clock BB PG', 'Shot-Clock Buzzer Beaters', 'SBB', 'Made shots beating the shot clock.'),
      countMetric('travel_pg', 'Travels PG', 'Travels', 'TRAVEL', 'Traveling violations.'),
      countMetric('double_dribble_pg', 'Double Dribble PG', 'Double Dribbles', 'DBL DRB', 'Double-dribble violations.'),
      countMetric('kicked_ball_pg', 'Kicked Ball PG', 'Kicked Balls', 'KICK', 'Kicked-ball violations.'),
    ],
  ),
];

const _aliases = <String, List<String>>{
  'gp': ['gp', 'games', 'g'],
  'min': ['mpg', 'min', 'minutes_per_game', 'minutes'],
  'pts': ['ppg', 'pts', 'points'],
  'reb': ['rpg', 'reb', 'trb', 'rebounds'],
  'oreb': ['oreb', 'orb', 'offensive_rebounds'],
  'dreb': ['dreb', 'drb', 'defensive_rebounds'],
  'ast': ['apg', 'ast', 'assists'],
  'stl': ['spg', 'stl', 'steals'],
  'blk': ['bpg', 'blk', 'blocks'],
  'tov': ['tpg', 'tov', 'turnovers'],
  'pf': ['pf', 'personal_fouls'],
  'fgm': ['fgm', 'field_goals_made'],
  'fga': ['fga', 'field_goal_attempts'],
  'fg_pct': ['fg_pct', 'field_goal_pct'],
  'three_pm': ['three_pm', 'three_pointers_made', 'fg3m'],
  'three_pa': ['three_pa', 'three_point_attempts', 'fg3a'],
  'three_pct': ['three_pct', 'three_point_pct', 'fg3_pct'],
  'ftm': ['ftm', 'free_throws_made'],
  'fta': ['fta', 'free_throw_attempts'],
  'ft_pct': ['ft_pct', 'free_throw_pct'],
  'efg_pct': ['efg_pct'],
  'ts_pct': ['ts_pct'],
  'per': ['per'],
  'ws': ['win_shares', 'ws'],
  'obpm': ['offensive_bpm', 'obpm'],
  'dbpm': ['defensive_bpm', 'dbpm'],
  'bpm': ['avg_bpm', 'bpm'],
  'vorp': ['vorp'],
  'usg_pct': ['usage_percentage', 'usg_pct'],
  'ortg': ['offensive_rating', 'off_rating', 'ortg'],
  'drtg': ['defensive_rating', 'def_rating', 'drtg'],
  'net_rating': ['net_rating', 'net_rtg'],
  'pace': ['pace'],
  'pie': ['pie'],
  'possessions': ['possessions', 'poss'],
  'ast_pct': ['ast_pct'],
  'ast_tov': ['ast_to', 'ast_tov'],
  'tov_pct': ['tov_pct', 'tm_tov_pct', 'e_tov_pct'],
  'stl_pct': ['stl_pct'],
  'blk_pct': ['blk_pct'],
  'oreb_pct': ['oreb_pct', 'orb_pct'],
  'dreb_pct': ['dreb_pct', 'drb_pct'],
  'reb_pct': ['reb_pct', 'trb_pct'],
  'deflections_pg': ['deflections_pg', 'deflections_per_game'],
  'charges_drawn_pg': ['charges_drawn_pg', 'charges_drawn_per_game'],
  'contested_shots_pg': ['contested_shots_pg', 'contested_shots_per_game'],
  'contested_shots_2pt_pg': ['contested_shots_2pt_pg'],
  'contested_shots_3pt_pg': ['contested_shots_3pt_pg'],
  'loose_balls_recovered_pg': ['loose_balls_recovered_pg', 'loose_balls_recovered_per_game'],
  'dfg_pct': ['d_fg_pct', 'dfg_pct'],
  'dfgm': ['d_fgm', 'dfgm'],
  'dfga': ['d_fga', 'dfga'],
  'rim_dfg_pct': ['rim_dfg_pct'],
  'three_dfg_pct': ['three_dfg_pct', 'three_pt_dfg_pct'],
  'midrange_dfg_pct': ['midrange_dfg_pct'],
  'box_out_pct': ['box_out_pct', 'pct_box_outs_reb'],
  'box_outs_pg': ['box_outs_pg'],
  'screen_ast_pg': ['screen_ast_pg', 'screen_assists_pg'],
  'screen_ast_points_pg': ['screen_ast_points_pg'],
  'secondary_ast_pg': ['secondary_ast_pg', 'secondary_ast'],
  'potential_ast_pg': ['potential_ast_pg', 'potential_ast'],
  'passes_pg': ['passes_pg', 'passes_made'],
  'passes_received_pg': ['passes_received_pg', 'passes_received'],
  'ft_ast_pg': ['ft_ast_pg', 'ft_assists'],
  'distance_miles': ['distance_miles', 'dist_miles'],
  'avg_speed': ['avg_speed'],
  'on_off_net': ['on_off_net', 'on_off_net_rating'],
  'on_court_net': ['on_court_net', 'on_court_net_rating'],
  'off_court_net': ['off_court_net', 'off_court_net_rating'],
  'lineup_net': ['lineup_net', 'lineup_net_rating'],
};

double? _metricValue(
  NbaStatsRow row,
  String key,
  NbaStatsBasis basis,
) {
  final metric = _metricByKey(key);
  final perGameValue = _sourceValue(row, key);
  if (perGameValue == null) {
    if (key == 'ftr') {
      final fga = _sourceValue(row, 'fga');
      final fta = _sourceValue(row, 'fta');
      return fga == null || fga == 0 || fta == null ? null : fta / fga;
    }
    if (key == 'three_par') {
      final fga = _sourceValue(row, 'fga');
      final threePa = _sourceValue(row, 'three_pa');
      return fga == null || fga == 0 || threePa == null
          ? null
          : threePa / fga;
    }
    if (key == 'pps') {
      final fga = _sourceValue(row, 'fga');
      final pts = _sourceValue(row, 'pts');
      return fga == null || fga == 0 || pts == null ? null : pts / fga;
    }
    if (key == 'ast_tov') {
      final ast = _sourceValue(row, 'ast');
      final tov = _sourceValue(row, 'tov');
      return ast == null || tov == null || tov == 0 ? null : ast / tov;
    }
    return null;
  }
  if (metric == null || !metric.rateSensitive) return perGameValue;
  return _convertPerGame(perGameValue, row, basis, key: key);
}

_Metric? _metricByKey(String key) {
  for (final category in _categories) {
    for (final metric in category.metrics) {
      if (metric.key == key) return metric;
      for (final child in metric.children) {
        if (child.key == key) return child;
      }
    }
  }
  return null;
}

double? _sourceValue(NbaStatsRow row, String key) {
  final direct = row.value(key);
  if (direct != null) return direct;
  final candidates = _aliases[key] ?? [key];
  for (final candidate in candidates) {
    final lower = candidate.toLowerCase();
    for (final entry in row.raw.entries) {
      if (entry.key.toLowerCase() != lower) continue;
      final parsed = _number(entry.value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _convertPerGame(
  double perGame,
  NbaStatsRow row,
  NbaStatsBasis basis, {
  required String key,
}) {
  final gp = row.value('gp') ?? _sourceValue(row, 'gp') ?? 0;
  final mpg = row.value('min') ?? 0;
  switch (basis) {
    case NbaStatsBasis.perGame:
      return perGame;
    case NbaStatsBasis.totals:
      return key == 'gp' ? perGame : perGame * gp;
    case NbaStatsBasis.per36:
      return mpg <= 0 ? null : perGame * 36 / mpg;
    case NbaStatsBasis.per48:
      return mpg <= 0 ? null : perGame * 48 / mpg;
    case NbaStatsBasis.per75:
      final poss = _possessionsPerGame(row);
      return poss <= 0 ? null : perGame * 75 / poss;
    case NbaStatsBasis.per100:
      final poss = _possessionsPerGame(row);
      return poss <= 0 ? null : perGame * 100 / poss;
  }
}

double _possessionsPerGame(NbaStatsRow row) {
  final gp = row.value('gp') ?? 0;
  final mpg = row.value('min') ?? 0;
  final raw = _rawNumber(row, const ['possessions', 'poss', 'estimated_possessions']);
  if (raw != null && raw > 0) {
    // NBA.com aggregate captures can label either a per-game POSS value (~70)
    // or a season total (~5,000) with the same field name. Normalize by scale.
    if (gp > 1 && (raw > 250 || (mpg > 0 && raw / mpg > 4.5))) {
      return raw / gp;
    }
    return raw;
  }
  final pace = _rawNumber(row, const ['pace']);
  if (pace != null && pace > 0 && mpg > 0) {
    return pace * mpg / 48;
  }
  return mpg > 0 ? mpg * 2.05 : 0;
}

double? _rawNumber(NbaStatsRow row, List<String> keys) {
  for (final key in keys) {
    for (final entry in row.raw.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        final parsed = _number(entry.value);
        if (parsed != null) return parsed;
      }
    }
  }
  return null;
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(
    value?.toString().replaceAll(',', '').replaceAll('%', '') ?? '',
  );
}

String _formatMetric(
  double? value,
  _Metric metric,
  NbaStatsBasis basis,
) {
  if (value == null || value.isNaN || value.isInfinite) return '—';
  if (metric.integer) return value.round().toString();
  if (metric.percent) {
    final scaled = value.abs() <= 1.5 ? value * 100 : value;
    return '${scaled.toStringAsFixed(1)}%';
  }
  if (metric.signed) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  }
  if (basis == NbaStatsBasis.totals && metric.rateSensitive) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String _basisDescription(NbaStatsBasis basis) {
  switch (basis) {
    case NbaStatsBasis.perGame:
      return 'Per Game shows per-appearance counting rates. Percentages and all-in-one metrics remain unchanged.';
    case NbaStatsBasis.totals:
      return 'Totals shows full-sample counting totals and renames counting headers to Points, Rebounds, Assists, Steals, Blocks and similar total phrasing.';
    case NbaStatsBasis.per36:
      return 'Per 36 normalizes rate-sensitive counting statistics to 36 minutes played.';
    case NbaStatsBasis.per48:
      return 'Per 48 normalizes rate-sensitive counting statistics to 48 minutes played.';
    case NbaStatsBasis.per75:
      return 'Per 75 normalizes rate-sensitive counting statistics to 75 player possessions using source POSS when available and a transparent pace/minutes fallback otherwise.';
    case NbaStatsBasis.per100:
      return 'Per 100 normalizes rate-sensitive counting statistics to 100 player possessions using the same possession denominator as Per 75.';
  }
}

class _StatGlossary extends StatefulWidget {
  const _StatGlossary({required this.category, required this.basis});

  final _Category category;
  final NbaStatsBasis basis;

  @override
  State<_StatGlossary> createState() => _StatGlossaryState();
}

class _StatGlossaryState extends State<_StatGlossary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final metrics = <String, _Metric>{};
    for (final metric in widget.category.metrics) {
      metrics[metric.key] = metric;
      for (final child in metric.children) {
        metrics[child.key] = child;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.category.name} Glossary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${metrics.length} metrics · concise definitions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                _open
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 760
                      ? 3
                      : constraints.maxWidth >= 520
                          ? 2
                          : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 8)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in metrics.values)
                    SizedBox(
                      width: width,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.displayLabel(widget.basis),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                metric.glossary,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

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
                    'Advanced NBA data unavailable',
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);

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

String _csvLine(Iterable<String> cells) => cells.map((cell) {
      final escaped = cell.replaceAll('"', '""');
      return escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')
          ? '"$escaped"'
          : escaped;
    }).join(',');
