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
  State<WebsiteNbaAdvancedStatsScreen> createState() => _WebsiteNbaAdvancedStatsScreenState();
}

class _WebsiteNbaAdvancedStatsScreenState extends State<WebsiteNbaAdvancedStatsScreen> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();

  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<NbaTerminalSeedSnapshot>? _dataFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _category = 'Overview';
  String _team = 'All';
  String _position = 'All';
  int _minGp = 0;
  int _minMpg = 0;
  String _sortKey = 'pts';
  bool _descending = true;
  final Set<String> _expandedMetrics = <String>{};
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

  void _selectCategory(String category) {
    final definition = _categories.firstWhere((item) => item.name == category);
    setState(() {
      _category = category;
      _sortKey = definition.metrics.first.key;
      _descending = true;
      _expandedMetrics.clear();
      _page = 1;
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

  List<_VisibleMetric> _visibleMetrics(_Category category) {
    final result = <_VisibleMetric>[];
    for (final metric in category.metrics) {
      result.add(_VisibleMetric(metric, false));
      if (_expandedMetrics.contains(metric.key)) {
        result.addAll(metric.children.map((child) => _VisibleMetric(child, true)));
      }
    }
    return result;
  }

  Widget _metricHeader(_Metric metric) {
    if (metric.children.isEmpty) return Text(metric.label);
    final expanded = _expandedMetrics.contains(metric.key);
    return InkWell(
      onTap: () => setState(() {
        if (expanded) {
          _expandedMetrics.remove(metric.key);
        } else {
          _expandedMetrics.add(metric.key);
        }
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            expanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded,
            size: 30,
          ),
          const SizedBox(width: 1),
          Text(metric.label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, catalog) {
        if (catalog.connectionState != ConnectionState.done) return const _Loading();
        if (catalog.hasError || _seasons.isEmpty || _dataFuture == null) {
          return _ErrorState(
            error: catalog.error,
            onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
          );
        }
        return FutureBuilder<NbaTerminalSeedSnapshot>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _Loading();
            if (snapshot.hasError || snapshot.data == null) {
              return _ErrorState(error: snapshot.error, onRetry: _reload);
            }
            return _buildPage(context, snapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, NbaTerminalSeedSnapshot data) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(data, basis: _basis, seasonType: _seasonType);
    final query = _search.text.trim().toLowerCase();
    final teams = <String>{'All'};
    for (final row in rows) {
      teams.addAll(
        row.team.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—'),
      );
    }

    final visible = rows.where((row) {
      if (query.isNotEmpty &&
          !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) {
        return false;
      }
      if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
      if (_position != 'All' && !_matchesPosition(row.position, _position)) return false;
      if (_qualificationGp(row) < _minGp) return false;
      if (_qualificationMpg(row) < _minMpg) return false;
      return true;
    }).toList();

    final definition = _categories.firstWhere((item) => item.name == _category);
    final visibleMetrics = _visibleMetrics(definition);
    visible.sort((a, b) {
      final left = _metricValue(a, _sortKey);
      final right = _metricValue(b, _sortKey);
      if (left == null && right == null) return a.player.compareTo(b.player);
      if (left == null) return 1;
      if (right == null) return -1;
      return _descending ? right.compareTo(left) : left.compareTo(right);
    });

    final pageCount = math.max(1, (visible.length / _pageSize).ceil());
    final safePage = _page.clamp(1, pageCount);
    if (safePage != _page) _page = safePage;
    final pageStart = (safePage - 1) * _pageSize;
    final pagedRows = visible.skip(pageStart).take(_pageSize).toList();

    Widget pager() => WebsitePagination(
          totalItems: visible.length,
          pageSize: _pageSize,
          currentPage: safePage,
          onPageChanged: (value) => setState(() => _page = value),
          onPageSizeChanged: (value) => setState(() {
            _pageSize = value;
            _page = 1;
          }),
        );

    final childTint = Theme.of(context).brightness == Brightness.dark
        ? colors.surfaceContainerHighest.withValues(alpha: .90)
        : colors.surfaceContainerHighest.withValues(alpha: .74);

    final tableColumns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Player'), width: 156),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 58),
      const WebsiteStickyStatsColumn(label: Text('Pos'), width: 52),
      for (final item in visibleMetrics)
        WebsiteStickyStatsColumn(
          label: _metricHeader(item.metric),
          width: item.child ? 68 : 70,
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
      for (final row in pagedRows)
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
          for (final item in visibleMetrics)
            Text(
              _formatMetric(_metricValue(row, item.metric.key), item.metric),
              maxLines: 1,
            ),
        ],
    ];

    return Column(
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
          'Deep player statistics organized by basketball questions, with explicit source boundaries and qualification controls.',
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
                  width: 140,
                  child: DropdownButtonFormField<NbaStatsBasis>(
                    initialValue: _basis,
                    decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                    items: [
                      for (final item in NbaStatsBasis.values)
                        DropdownMenuItem(value: item, child: Text(item.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _basis = value;
                          _page = 1;
                        });
                      }
                    },
                  ),
                ),
                _StringDropdown(
                  label: 'Stat group',
                  value: _category,
                  values: [for (final item in _categories) item.name],
                  width: 210,
                  onChanged: _selectCategory,
                ),
                SizedBox(
                  width: 225,
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
                  onPressed: () => _copyCsv(context, visible, visibleMetrics),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy CSV'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in _categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.name),
                    selected: item.name == _category,
                    onSelected: (_) => _selectCategory(item.name),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          definition.description,
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
        ),
        if (definition.metrics.any((metric) => metric.children.isNotEmpty)) ...[
          const SizedBox(height: 6),
          Text(
            'Select the larger triangle beside an expandable column to reveal component stats. Expanded components are shaded; unavailable source coverage remains visible as —.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        if (_category == 'Defense') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Defended shooting is source-distinct: 3P DFG% is the opponent’s three-point percentage on attempts defended by the player. It is never substituted with the player’s offensive 3P%.',
              style: TextStyle(color: colors.onSecondaryContainer, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        const SizedBox(height: 14),
        pager(),
        const SizedBox(height: 10),
        WebsiteStickyStatsTable(
          columns: tableColumns,
          rows: tableRows,
          firstColumnWidth: 156,
          headerHeight: 43,
          rowHeight: 42,
        ),
        const SizedBox(height: 10),
        pager(),
        const SizedBox(height: 18),
        const _StatGlossary(),
        const SizedBox(height: 14),
        Text(
          'Source boundary: the schema intentionally keeps columns visible when historical coverage is incomplete. Sports Terminal displays sourced values and transparent derivations only; missing values remain — rather than being inferred from unrelated metrics.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  Future<void> _copyCsv(
    BuildContext context,
    List<NbaStatsRow> rows,
    List<_VisibleMetric> metrics,
  ) async {
    final lines = <String>[
      _csvLine(['Player', 'Team', 'Pos', ...metrics.map((item) => item.metric.label)]),
    ];
    for (final row in rows) {
      lines.add(
        _csvLine([
          row.player,
          row.team,
          row.position,
          for (final item in metrics)
            _formatMetric(_metricValue(row, item.metric.key), item.metric),
        ]),
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${rows.length} filtered advanced-stat rows as CSV.')),
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

class _VisibleMetric {
  const _VisibleMetric(this.metric, this.child);

  final _Metric metric;
  final bool child;
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
        width: 110,
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

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

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
                'Advanced NBA data unavailable',
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
    this.percent = false,
    this.signed = false,
    this.integer = false,
    this.children = const [],
  });

  final String key;
  final String label;
  final String glossary;
  final bool percent;
  final bool signed;
  final bool integer;
  final List<_Metric> children;
}

const _categories = <_Category>[
  _Category(
    'Overview',
    'Core production, traditional efficiency and headline impact measures.',
    [
      _Metric('gp', 'GP', 'Games played in the selected sample.', integer: true),
      _Metric('min', 'MPG', 'Minutes played per game.'),
      _Metric('pts', 'PPG', 'Points scored per game.'),
      _Metric('reb', 'RPG', 'Total rebounds per game.', children: [
        _Metric('oreb', 'ORB', 'Offensive rebounds per game.'),
        _Metric('dreb', 'DRB', 'Defensive rebounds per game.'),
      ]),
      _Metric('ast', 'APG', 'Assists per game.'),
      _Metric('stl', 'SPG', 'Steals per game.'),
      _Metric('blk', 'BPG', 'Blocks per game.'),
      _Metric('tov', 'TPG', 'Turnovers per game.'),
      _Metric('pf', 'PF', 'Personal fouls under the selected rate basis.'),
      _Metric('fg_pct', 'FG%', 'Field-goal percentage.', percent: true, children: [
        _Metric('fgm', 'FGM', 'Field goals made under the selected rate basis.'),
        _Metric('fga', 'FGA', 'Field goals attempted under the selected rate basis.'),
      ]),
      _Metric('three_pct', '3P%', 'The player’s offensive three-point field-goal percentage.', percent: true, children: [
        _Metric('three_pm', '3PM', 'Three-pointers made under the selected rate basis.'),
        _Metric('three_pa', '3PA', 'Three-pointers attempted under the selected rate basis.'),
      ]),
      _Metric('ft_pct', 'FT%', 'Free-throw percentage.', percent: true, children: [
        _Metric('ftm', 'FTM', 'Free throws made under the selected rate basis.'),
        _Metric('fta', 'FTA', 'Free throws attempted under the selected rate basis.'),
      ]),
      _Metric('pace', 'Pace', 'Estimated possessions per 48 minutes while the player is on the floor.'),
      _Metric('pie', 'PIE', 'Player Impact Estimate summarizes box-score contribution relative to game totals.', percent: true),
      _Metric('per', 'PER', 'Player Efficiency Rating is a pace-adjusted per-minute box-score efficiency metric.'),
      _Metric('bpm', 'BPM', 'Box Plus/Minus estimates points per 100 possessions above or below league average.', signed: true, children: [
        _Metric('obpm', 'OBPM', 'Offensive component of Box Plus/Minus.', signed: true),
        _Metric('dbpm', 'DBPM', 'Defensive component of Box Plus/Minus.', signed: true),
      ]),
      _Metric('vorp', 'VORP', 'Value Over Replacement Player converts BPM into cumulative value above replacement.'),
      _Metric('ws', 'WS', 'Win Shares estimates wins attributable to a player.'),
      _Metric('epm', 'EPM', 'Estimated Plus-Minus when a source-backed value is available.', signed: true),
      _Metric('lebron', 'LEBRON', 'LEBRON impact estimate when a source-backed value is available.', signed: true),
    ],
  ),
  _Category(
    'Shooting & Efficiency',
    'Efficiency, shot profile, location, creation mode and scoring context.',
    [
      _Metric('efg_pct', 'eFG%', 'Effective field-goal percentage gives extra weight to made threes.', percent: true),
      _Metric('ts_pct', 'TS%', 'True shooting percentage includes twos, threes and free throws.', percent: true),
      _Metric('ftr', 'FTR', 'Free-throw attempts divided by field-goal attempts.'),
      _Metric('three_par', '3PAr', 'Three-point attempts divided by field-goal attempts.'),
      _Metric('pps', 'PPS', 'Points scored per field-goal attempt.'),
      _Metric('rim_freq', 'Rim Freq', 'Share of attempts taken at the rim.', percent: true),
      _Metric('rim_fg_pct', 'Rim FG%', 'Field-goal percentage at the rim.', percent: true),
      _Metric('paint_freq', 'Paint Freq', 'Share of attempts taken in the paint.', percent: true),
      _Metric('paint_fg_pct', 'Paint FG%', 'Field-goal percentage on paint attempts.', percent: true),
      _Metric('midrange_freq', 'Midrange Freq', 'Share of attempts taken from midrange.', percent: true),
      _Metric('midrange_fg_pct', 'Midrange FG%', 'Field-goal percentage from midrange.', percent: true),
      _Metric('three_freq', '3P Freq', 'Share of attempts taken from three.', percent: true),
      _Metric('three_pct', '3P%', 'The player’s offensive three-point percentage.', percent: true),
      _Metric('halfcourt_freq', 'Halfcourt Freq', 'Share of offensive possessions occurring in halfcourt offense.', percent: true),
      _Metric('halfcourt_fg_pct', 'Halfcourt FG%', 'Field-goal percentage in halfcourt possessions.', percent: true),
      _Metric('heaves_pg', 'HPG', 'Heave attempts per game.'),
      _Metric('corner_three_freq', 'Corner 3 Freq', 'Share of attempts from either corner three area.', percent: true),
      _Metric('corner_three_pct', 'Corner 3P%', 'Three-point percentage from either corner.', percent: true),
      _Metric('right_corner_three_freq', 'R Corner Freq', 'Share of attempts from the right corner.', percent: true),
      _Metric('right_corner_three_pct', 'R Corner 3P%', 'Three-point percentage from the right corner.', percent: true),
      _Metric('left_corner_three_freq', 'L Corner Freq', 'Share of attempts from the left corner.', percent: true),
      _Metric('left_corner_three_pct', 'L Corner 3P%', 'Three-point percentage from the left corner.', percent: true),
      _Metric('catch_shoot_three_freq', 'C&S 3 Freq', 'Share of attempts that are catch-and-shoot threes.', percent: true),
      _Metric('catch_shoot_three_pct', 'C&S 3P%', 'Three-point percentage on catch-and-shoot attempts.', percent: true),
      _Metric('pullup_three_freq', 'Pull-Up 3 Freq', 'Share of attempts that are pull-up threes.', percent: true),
      _Metric('pullup_three_pct', 'Pull-Up 3P%', 'Three-point percentage on pull-up attempts.', percent: true),
      _Metric('right_wing_three_freq', 'R Wing Freq', 'Share of attempts from the right wing.', percent: true),
      _Metric('right_wing_three_pct', 'R Wing 3P%', 'Three-point percentage from the right wing.', percent: true),
      _Metric('left_wing_three_freq', 'L Wing Freq', 'Share of attempts from the left wing.', percent: true),
      _Metric('left_wing_three_pct', 'L Wing 3P%', 'Three-point percentage from the left wing.', percent: true),
      _Metric('wing_three_freq', 'Wing 3 Freq', 'Share of attempts from either wing.', percent: true),
      _Metric('wing_three_pct', 'Wing 3P%', 'Three-point percentage from the wings.', percent: true),
      _Metric('middle_three_freq', 'Middle 3 Freq', 'Share of attempts from middle above-the-break areas.', percent: true),
      _Metric('middle_three_pct', 'Middle 3P%', 'Three-point percentage from middle above-the-break areas.', percent: true),
      _Metric('unassisted_fg_pct', 'Unassisted FG%', 'Field-goal percentage on unassisted attempts.', percent: true),
      _Metric('assisted_fg_pct', 'Assisted FG%', 'Field-goal percentage on assisted attempts.', percent: true),
      _Metric('unassisted_pts_pg', 'Unassisted PPG', 'Points per game scored without an assist.'),
      _Metric('assisted_pts_pg', 'Assisted PPG', 'Points per game scored on assisted field goals.'),
      _Metric('dunks_pg', 'Dunks PG', 'Dunks per game according to the source definition.'),
      _Metric('layups_pg', 'Layups PG', 'Layups per game according to the source definition.'),
    ],
  ),
  _Category(
    'Playmaking & Creation',
    'Passing volume, creation quality, turnover control and advantage generation.',
    [
      _Metric('ast', 'APG', 'Assists per game.'),
      _Metric('tov', 'TPG', 'Turnovers per game.'),
      _Metric('screen_ast_pg', 'Screen APG', 'Screen assists per game credited to the screener.'),
      _Metric('secondary_ast_pg', 'Secondary APG', 'Secondary or hockey assists per game.'),
      _Metric('potential_ast_pg', 'Potential APG', 'Passes per game that become assists if the receiving shot is made.'),
      _Metric('passes_pg', 'Passes PG', 'Passes made per game.'),
      _Metric('ast_tov', 'AST:TO', 'Assist-to-turnover ratio.'),
      _Metric('ast_pct', 'AST%', 'Estimated share of teammate field goals assisted while on court.', percent: true),
      _Metric('tov_pct', 'TO%', 'Turnover rate according to the source definition.', percent: true),
      _Metric('adj_ast_ratio', 'Adj. Assist Ratio', 'Adjusted assist ratio incorporating assists, free-throw assists and secondary assists.'),
      _Metric('ft_ast_pg', 'FT APG', 'Free-throw assists generated per game.'),
      _Metric('ast_points_created', 'Assist Pts Created', 'Points created directly from credited assists.'),
      _Metric('passing_decision_time', 'Pass Decision Time', 'Average time before a pass decision when tracking data supports it.'),
      _Metric('pass_windows_opened', 'Pass Windows', 'Passing lanes or windows created when a tracking model provides the measure.'),
      _Metric('panic_turnover_rate', 'Panic TOV Rate', 'Turnover rate under high-pressure decision states when source data supports it.', percent: true),
    ],
  ),
  _Category(
    'Defense',
    'Defensive events, shot suppression, matchup results, hustle and foul discipline.',
    [
      _Metric('stl', 'SPG', 'Steals per game.', children: [
        _Metric('stl_pct', 'STL%', 'Steal percentage.', percent: true),
      ]),
      _Metric('blk', 'BPG', 'Blocks per game.', children: [
        _Metric('blk_pct', 'BLK%', 'Block percentage.', percent: true),
      ]),
      _Metric('deflections_pg', 'DPG', 'Deflections per game.'),
      _Metric('dreb', 'DREB', 'Defensive rebounds per game.'),
      _Metric('charges_drawn_pg', 'Charges PG', 'Charges drawn per game.'),
      _Metric('contested_shots_pg', 'Contested PG', 'Contested shots per game.'),
      _Metric('loose_balls_recovered_pg', 'Loose Balls PG', 'Loose balls recovered per game.'),
      _Metric('dfg_pct', 'DFG%', 'Opponent field-goal percentage on attempts defended by this player.', percent: true, children: [
        _Metric('dfgm', 'DFGM', 'Defended field goals made by opponents.'),
        _Metric('dfga', 'DFGA', 'Defended field-goal attempts by opponents.'),
      ]),
      _Metric('three_dfg_pct', '3P DFG%', 'Opponent three-point percentage on defended three-point attempts. This is not the player’s offensive 3P%.', percent: true, children: [
        _Metric('three_dfgm', '3P DFGM', 'Opponent defended three-pointers made.'),
        _Metric('three_dfga', '3P DFGA', 'Opponent defended three-point attempts.'),
      ]),
      _Metric('rim_dfg_pct', 'Rim DFG%', 'Opponent field-goal percentage at the rim when defended by this player.', percent: true, children: [
        _Metric('rim_dfgm', 'Rim DFGM', 'Opponent defended rim field goals made.'),
        _Metric('rim_dfga', 'Rim DFGA', 'Opponent defended rim field-goal attempts.'),
      ]),
      _Metric('two_dfg_pct', '2P DFG%', 'Opponent two-point percentage on defended two-point attempts.', percent: true),
      _Metric('midrange_dfg_pct', 'Midrange DFG%', 'Opponent midrange percentage when defended by this player.', percent: true),
      _Metric('dfg_pct_diff', 'DFG% Diff', 'Difference between defended FG% and the opponents’ normal FG%.', signed: true),
      _Metric('three_dfg_pct_diff', '3P DFG% Diff', 'Difference between defended 3P% and opponents’ normal 3P%.', signed: true),
      _Metric('box_out_pct', 'Box Out %', 'Share of box-outs resulting in a rebound outcome.', percent: true),
      _Metric('box_outs_pg', 'Box Outs PG', 'Box-outs per game.'),
      _Metric('blow_by_rate', 'Blow-By Rate', 'Rate at which the primary defender is beaten off the dribble.', percent: true),
      _Metric('contest_distance', 'Contest Distance', 'Average distance from the shooter at contest.'),
      _Metric('help_defense', 'Help Defense', 'Source-backed help-defense activity or impact metric.'),
      _Metric('deterrence_rate', 'Deterrence', 'Estimated rate at which a defender suppresses or redirects attempts.', percent: true),
      _Metric('switch_attrition_rate', 'Switch Attrition', 'Performance retention across defensive switches.', percent: true),
      _Metric('closeout_speed', 'Closeout Speed', 'Average closeout speed when tracking data supports it.'),
    ],
  ),
  _Category(
    'Rebounding',
    'Rebound volume, opportunity, contestedness, box-outs and deferred rebound value.',
    [
      _Metric('reb', 'RPG', 'Total rebounds per game.', children: [
        _Metric('contested_reb_pg', 'Contested RPG', 'Contested rebounds per game.'),
        _Metric('uncontested_reb_pg', 'Uncontested RPG', 'Uncontested rebounds per game.'),
        _Metric('reb_pct', 'TRB%', 'Total rebound percentage.', percent: true),
      ]),
      _Metric('dreb', 'DRB', 'Defensive rebounds per game.', children: [
        _Metric('contested_dreb_pg', 'Contested DRB', 'Contested defensive rebounds per game.'),
        _Metric('uncontested_dreb_pg', 'Uncontested DRB', 'Uncontested defensive rebounds per game.'),
        _Metric('dreb_pct', 'DRB%', 'Defensive rebound percentage.', percent: true),
      ]),
      _Metric('oreb', 'ORB', 'Offensive rebounds per game.', children: [
        _Metric('contested_oreb_pg', 'Contested ORB', 'Contested offensive rebounds per game.'),
        _Metric('uncontested_oreb_pg', 'Uncontested ORB', 'Uncontested offensive rebounds per game.'),
        _Metric('oreb_pct', 'ORB%', 'Offensive rebound percentage.', percent: true),
      ]),
      _Metric('box_outs_pg', 'Box Outs PG', 'Total box-outs per game.'),
      _Metric('tap_outs_pg', 'Tap Outs PG', 'Tap-out rebounds retained by the offense per game.'),
      _Metric('deferred_rebounds_pg', 'Deferred RPG', 'Rebound opportunities intentionally deferred to teammates per game.'),
    ],
  ),
  _Category(
    'Impact',
    'Team impact, on-court efficiency and all-in-one impact models.',
    [
      _Metric('ortg', 'ORtg', 'Offensive rating.'),
      _Metric('drtg', 'DRtg', 'Defensive rating.'),
      _Metric('net_rating', 'Net Rating', 'Offensive rating minus defensive rating.', signed: true),
      _Metric('on_off_net', 'On/Off Diff', 'Team net-rating swing between player-on and player-off minutes.', signed: true),
      _Metric('per', 'PER', 'Player Efficiency Rating.'),
      _Metric('bpm', 'BPM', 'Box Plus/Minus.', signed: true, children: [
        _Metric('obpm', 'OBPM', 'Offensive BPM.', signed: true),
        _Metric('dbpm', 'DBPM', 'Defensive BPM.', signed: true),
      ]),
      _Metric('vorp', 'VORP', 'Value Over Replacement Player.'),
      _Metric('ws', 'WS', 'Win Shares.'),
      _Metric('epm', 'EPM', 'Estimated Plus-Minus.', signed: true),
      _Metric('lebron', 'LEBRON', 'LEBRON impact estimate.', signed: true),
      _Metric('darko', 'DARKO', 'DARKO impact estimate.', signed: true),
      _Metric('rapm', 'RAPM', 'Regularized Adjusted Plus-Minus.', signed: true),
      _Metric('la_rapm', 'LA-RAPM', 'Luck-adjusted or source-defined RAPM variant.', signed: true),
      _Metric('warv', 'WARV', 'Wins above replacement value when source-backed.'),
    ],
  ),
  _Category(
    'Rate Adjusted',
    'Per-minute, per-possession and playing-time-neutral views of production.',
    [
      _Metric('pts', 'PTS', 'Points under the selected rate basis.'),
      _Metric('reb', 'REB', 'Rebounds under the selected rate basis.'),
      _Metric('ast', 'AST', 'Assists under the selected rate basis.'),
      _Metric('stl', 'STL', 'Steals under the selected rate basis.'),
      _Metric('blk', 'BLK', 'Blocks under the selected rate basis.'),
      _Metric('tov', 'TOV', 'Turnovers under the selected rate basis.'),
      _Metric('pf', 'PF', 'Personal fouls under the selected rate basis.'),
      _Metric('possessions', 'Poss', 'Possessions represented by the source.'),
      _Metric('pace', 'Pace', 'Estimated possessions per 48 minutes.'),
      _Metric('usg_pct', 'USG%', 'Usage percentage.', percent: true),
    ],
  ),
  _Category(
    'Clutch',
    'Production and efficiency in the source-defined clutch window.',
    [
      _Metric('clutch_pts_pg', 'CPPG', 'Clutch points per game.'),
      _Metric('clutch_reb_pg', 'CRPG', 'Clutch rebounds per game.'),
      _Metric('clutch_ast_pg', 'CAPG', 'Clutch assists per game.'),
      _Metric('clutch_stl_pg', 'CSPG', 'Clutch steals per game.'),
      _Metric('clutch_blk_pg', 'CBPG', 'Clutch blocks per game.'),
      _Metric('clutch_tov_pg', 'CTPG', 'Clutch turnovers per game.'),
      _Metric('clutch_fg_pct', 'Clutch FG%', 'Field-goal percentage in clutch minutes.', percent: true),
      _Metric('clutch_three_pct', 'Clutch 3P%', 'Three-point percentage in clutch minutes.', percent: true),
      _Metric('clutch_ft_pct', 'Clutch FT%', 'Free-throw percentage in clutch minutes.', percent: true),
      _Metric('clutch_efg_pct', 'Clutch eFG%', 'Effective field-goal percentage in clutch minutes.', percent: true),
      _Metric('clutch_ts_pct', 'Clutch TS%', 'True shooting percentage in clutch minutes.', percent: true),
      _Metric('clutch_ortg', 'Clutch ORtg', 'Offensive rating in clutch minutes.'),
      _Metric('clutch_drtg', 'Clutch DRtg', 'Defensive rating in clutch minutes.'),
      _Metric('clutch_net', 'Clutch Net', 'Net rating in clutch minutes.', signed: true),
      _Metric('clutch_plus_minus', 'Clutch +/-', 'Plus-minus in clutch minutes.', signed: true),
    ],
  ),
  _Category(
    'Gravity & Spacing',
    'How strongly a player bends defensive attention and creates usable space for teammates.',
    [
      _Metric('gravity', 'Gravity', 'Source-defined overall offensive gravity estimate.'),
      _Metric('shot_gravity', 'Shot Gravity', 'Defensive attention generated by shooting threat.'),
      _Metric('drive_gravity', 'Drive Gravity', 'Defensive attention generated by driving threat.'),
      _Metric('spacing_value', 'Spacing Value', 'Estimated value of space created for teammates.'),
      _Metric('double_team_rate', 'Double-Team %', 'Share of possessions drawing a double team.', percent: true),
      _Metric('triple_team_rate', 'Triple-Team %', 'Share of possessions drawing a triple team.', percent: true),
      _Metric('pass_windows_opened', 'Pass Windows', 'Passing windows opened by defensive displacement.'),
      _Metric('freeze_time', 'Freeze Time', 'Time defenders are held or frozen by the player’s threat.'),
      _Metric('blitz_escape_rate', 'Blitz Escape %', 'Rate of successful escapes from blitzes or traps.', percent: true),
      _Metric('trap_navigation', 'Trap Navigation', 'Source-defined performance navigating traps and doubles.'),
    ],
  ),
  _Category(
    'On / Off',
    'Team performance with the player on the court versus off the court.',
    [
      _Metric('on_off_net', 'On/Off Net', 'Net-rating swing between player-on and player-off minutes.', signed: true),
      _Metric('on_court_net', 'On-Court Net', 'Team net rating with the player on court.', signed: true),
      _Metric('off_court_net', 'Off-Court Net', 'Team net rating with the player off court.', signed: true),
      _Metric('on_court_ortg', 'On ORtg', 'Team offensive rating with the player on court.'),
      _Metric('off_court_ortg', 'Off ORtg', 'Team offensive rating with the player off court.'),
      _Metric('on_court_drtg', 'On DRtg', 'Team defensive rating with the player on court.'),
      _Metric('off_court_drtg', 'Off DRtg', 'Team defensive rating with the player off court.'),
    ],
  ),
  _Category(
    'Lineups & Roles',
    'Lineup context, role statistics and play-type efficiency.',
    [
      _Metric('lineup_net', 'Lineup Net', 'Net rating for qualifying lineups associated with the player.', signed: true),
      _Metric('isolation_ppp', 'Isolation PPP', 'Points per possession on isolation plays.'),
      _Metric('transition_ppp', 'Transition PPP', 'Points per possession in transition.'),
      _Metric('transition_offense', 'Transition Off', 'Source-defined transition offense metric.'),
      _Metric('transition_defense', 'Transition Def', 'Source-defined transition defense metric.'),
      _Metric('pnr_ball_handler_ppp', 'PnR Handler PPP', 'Points per possession as pick-and-roll ball handler.'),
      _Metric('pnr_roll_man_ppp', 'PnR Roll PPP', 'Points per possession as pick-and-roll roll man.'),
      _Metric('post_up_ppp', 'Post-Up PPP', 'Points per possession on post-ups.'),
      _Metric('spot_up_ppp', 'Spot-Up PPP', 'Points per possession on spot-up plays.'),
      _Metric('drive_pts_pg', 'Drive PPG', 'Points per game created on drives.'),
      _Metric('drive_ast_pg', 'Drive APG', 'Assists per game created on drives.'),
      _Metric('screens_set_pg', 'Screens Set PG', 'Screens set per game.'),
      _Metric('screens_used_pg', 'Screens Used PG', 'Screens used by the ball handler per game.'),
      _Metric('cutting_ppp', 'Cutting PPP', 'Points per possession on cuts.'),
      _Metric('backdoor_cut_rate', 'Backdoor Cut %', 'Rate of backdoor cuts when source-backed.', percent: true),
    ],
  ),
  _Category(
    'Movement & Physical',
    'Movement load, touch behavior and physical measurements.',
    [
      _Metric('usg_pct', 'Usage', 'Usage percentage.', percent: true),
      _Metric('distance_traveled', 'Distance', 'Distance traveled.'),
      _Metric('avg_speed', 'Avg Speed', 'Average on-court speed.'),
      _Metric('time_per_touch', 'Time / Touch', 'Average time of possession per touch.'),
      _Metric('dribbles_per_touch', 'Dribbles / Touch', 'Average dribbles per touch.'),
      _Metric('height', 'Height', 'Listed or measured height.'),
      _Metric('weight', 'Weight', 'Listed or measured weight.'),
      _Metric('wingspan', 'Wingspan', 'Measured wingspan.'),
      _Metric('standing_reach', 'Standing Reach', 'Measured standing reach.'),
      _Metric('hand_length', 'Hand Length', 'Measured hand length.'),
      _Metric('hand_width', 'Hand Width', 'Measured hand width.'),
      _Metric('standing_jump', 'Standing Jump', 'Measured standing vertical jump.'),
      _Metric('max_vertical_jump', 'Max Vertical', 'Measured maximum vertical jump.'),
    ],
  ),
  _Category(
    'Discipline & Events',
    'Violations, foul types, sanctions and discrete end-of-clock events.',
    [
      _Metric('technical_fouls', 'Technical Fouls', 'Technical fouls assessed.'),
      _Metric('shooting_fouls', 'Shooting Fouls', 'Shooting fouls committed.'),
      _Metric('personal_fouls', 'Personal Fouls', 'Personal fouls committed.'),
      _Metric('offensive_fouls', 'Offensive Fouls', 'Offensive fouls committed.'),
      _Metric('defensive_fouls', 'Defensive Fouls', 'Defensive fouls committed.'),
      _Metric('other_fouls', 'Other Fouls', 'Other categorized fouls committed.'),
      _Metric('travel', 'Travels', 'Traveling violations.'),
      _Metric('double_dribble', 'Double Dribble', 'Double-dribble violations.'),
      _Metric('discontinued_dribble', 'Disc. Dribble', 'Discontinued-dribble violations.'),
      _Metric('off_three_sec', 'Off. 3 Sec', 'Offensive three-second violations.'),
      _Metric('def_three_sec', 'Def. 3 Sec', 'Defensive three-second violations.'),
      _Metric('backcourt', 'Backcourt', 'Backcourt violations.'),
      _Metric('palming', 'Palming', 'Palming or carrying violations.'),
      _Metric('kicked_ball', 'Kicked Ball', 'Kicked-ball violations.'),
      _Metric('off_goaltending', 'Off. Goaltending', 'Offensive goaltending violations.'),
      _Metric('def_goaltending', 'Def. Goaltending', 'Defensive goaltending violations.'),
      _Metric('ejections', 'Ejections', 'Ejections recorded.'),
      _Metric('disqualifications', 'Disqualifications', 'Game disqualifications recorded.'),
      _Metric('suspensions', 'Suspensions', 'Suspensions recorded in a source-backed dataset.'),
      _Metric('game_buzzer_beaters', 'Game Buzzer Beaters', 'Made shots beating the final game buzzer.'),
      _Metric('quarter_buzzer_beaters', 'Quarter Beaters', 'Made shots beating a quarter-ending buzzer.'),
      _Metric('shot_clock_buzzer_beaters', 'Shot-Clock Beaters', 'Made shots immediately before shot-clock expiration.'),
    ],
  ),
];

class _StatGlossary extends StatefulWidget {
  const _StatGlossary();

  @override
  State<_StatGlossary> createState() => _StatGlossaryState();
}

class _StatGlossaryState extends State<_StatGlossary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final metrics = <String, _Metric>{};
    for (final category in _categories) {
      for (final metric in category.metrics) {
        metrics[metric.key] = metric;
        for (final child in metric.children) {
          metrics[child.key] = child;
        }
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
                      'Stat Glossary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${metrics.length} metrics · concise definitions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final metric in metrics.values)
                    SizedBox(
                      width: width,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(
                                metric.glossary,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  height: 1.35,
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

double _qualificationGp(NbaStatsRow row) =>
    _rawValue(row, ['games', 'gp']) ?? row.value('gp') ?? 0;

double _qualificationMpg(NbaStatsRow row) {
  final explicit = _rawValue(row, ['minutes_per_game', 'mpg', 'min_pg']);
  if (explicit != null) return explicit;
  final games = _qualificationGp(row);
  final minutes = _rawValue(row, ['minutes', 'min']);
  if (minutes != null) {
    if (games > 0 && minutes > 60) return minutes / games;
    return minutes;
  }
  return row.value('min') ?? 0;
}

double? _rawValue(NbaStatsRow row, List<String> keys) {
  for (final candidate in keys) {
    for (final entry in row.raw.entries) {
      if (entry.key.toLowerCase() != candidate.toLowerCase()) continue;
      final value = entry.value;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(
        value?.toString().replaceAll(',', '').replaceAll('%', '') ?? '',
      );
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _metricValue(NbaStatsRow row, String key) {
  double? value(List<String> keys) {
    for (final candidate in keys) {
      final direct = row.values[candidate];
      if (direct != null) return direct;
    }
    return _rawValue(row, keys);
  }

  const aliases = <String, List<String>>{
    'gp': ['gp', 'games'],
    'min': ['mpg', 'min', 'minutes'],
    'pts': ['ppg', 'pts', 'points'],
    'reb': ['rpg', 'reb', 'trb'],
    'oreb': ['oreb', 'orb', 'offensive_rebounds'],
    'dreb': ['dreb', 'drb', 'defensive_rebounds'],
    'ast': ['apg', 'ast', 'assists'],
    'stl': ['spg', 'stl', 'steals'],
    'blk': ['bpg', 'blk', 'blocks'],
    'tov': ['tpg', 'tov', 'turnovers'],
    'pf': ['pf', 'personal_fouls'],
    'personal_fouls': ['pf', 'personal_fouls'],
    'fgm': ['fgm', 'field_goals_made'],
    'fga': ['fga', 'field_goal_attempts'],
    'fg_pct': ['fg_pct'],
    'three_pm': ['fg3m', 'three_pm', 'three_pointers_made'],
    'three_pa': ['fg3a', 'three_pa', 'three_point_attempts'],
    // Offensive shooting lineage only. Never alias defended 3P fields here.
    'three_pct': ['fg3_pct', 'three_pct'],
    'ftm': ['ftm', 'free_throws_made'],
    'fta': ['fta', 'free_throw_attempts'],
    'ft_pct': ['ft_pct'],
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
    'net_rating': ['net_rating'],
    'pace': ['pace'],
    'pie': ['pie'],
    'ast_pct': ['ast_pct'],
    'tov_pct': ['tm_tov_pct', 'tov_pct', 'e_tov_pct'],
    'stl_pct': ['stl_pct'],
    'blk_pct': ['blk_pct'],
    'oreb_pct': ['oreb_pct'],
    'dreb_pct': ['dreb_pct'],
    'reb_pct': ['reb_pct', 'trb_pct'],
    'ast_tov': ['ast_to', 'ast_tov'],
    'epm': ['epm'],
    'lebron': ['lebron'],
    'darko': ['darko'],
    'rapm': ['rapm'],
    'la_rapm': ['la_rapm'],
    'warv': ['warv'],
    'deflections_pg': ['deflections_pg'],
    'charges_drawn_pg': ['charges_drawn_pg'],
    'contested_shots_pg': ['contested_shots_pg'],
    'loose_balls_recovered_pg': ['loose_balls_recovered_pg'],
    'box_out_pct': ['box_out_pct', 'pct_box_outs_reb'],
    'box_outs_pg': ['box_outs_pg'],
    'screen_ast_pg': ['screen_ast_pg'],
    'secondary_ast_pg': ['secondary_ast_pg', 'secondary_ast'],
    'potential_ast_pg': ['potential_ast_pg', 'potential_ast'],
    'passes_pg': ['passes_pg', 'passes_made'],
    'ft_ast_pg': ['ft_ast_pg', 'ft_ast'],
    'ast_points_created': ['ast_points_created'],
    'distance_traveled': ['distance_traveled', 'dist_miles'],
    'avg_speed': ['avg_speed'],
    'time_per_touch': ['time_per_touch', 'time_of_possession_per_touch'],
    'dribbles_per_touch': ['dribbles_per_touch'],
    'clutch_pts_pg': ['clutch_pts_pg', 'clutch_points', 'clutch_pts'],
    'clutch_reb_pg': ['clutch_reb_pg'],
    'clutch_ast_pg': ['clutch_ast_pg'],
    'clutch_stl_pg': ['clutch_stl_pg'],
    'clutch_blk_pg': ['clutch_blk_pg'],
    'clutch_tov_pg': ['clutch_tov_pg'],
    'clutch_fg_pct': ['clutch_fg_pct'],
    'clutch_three_pct': ['clutch_three_pct'],
    'clutch_ft_pct': ['clutch_ft_pct'],
    'clutch_efg_pct': ['clutch_efg_pct'],
    'clutch_ts_pct': ['clutch_ts_pct'],
    'clutch_ortg': ['clutch_ortg'],
    'clutch_drtg': ['clutch_drtg'],
    'clutch_net': ['clutch_net'],
    'clutch_plus_minus': ['clutch_plus_minus'],
    'gravity': ['gravity', 'gravity_score'],
    'spacing_value': ['spacing_value'],
    'double_team_rate': ['double_team_rate'],
    'on_off_net': ['on_off_net', 'on_off_net_rating'],
    'on_court_net': ['on_court_net', 'on_court_net_rating'],
    'off_court_net': ['off_court_net', 'off_court_net_rating'],
    'lineup_net': ['lineup_net', 'lineup_net_rating'],
    'possessions': ['possessions', 'poss'],
    'travel': ['travel'],
    'double_dribble': ['double_dribble'],
    'discontinued_dribble': ['discontinued_dribble'],
    'off_three_sec': ['off_three_sec'],
    'def_three_sec': ['def_three_sec'],
    'backcourt': ['backcourt'],
    'palming': ['palming'],
    'off_goaltending': ['off_goaltending'],
    'def_goaltending': ['def_goaltending'],
    'kicked_ball': ['kicked_ball'],
    // Defended shooting has dedicated NBA.com Defense Dashboard lineage.
    'dfg_pct': ['d_fg_pct', 'dfg_pct'],
    'dfgm': ['d_fgm', 'dfgm'],
    'dfga': ['d_fga', 'dfga'],
    'dfg_pct_diff': ['dfg_pct_diff'],
    'three_dfg_pct': ['three_dfg_pct'],
    'three_dfgm': ['three_dfgm'],
    'three_dfga': ['three_dfga'],
    'three_dfg_pct_diff': ['three_dfg_pct_diff'],
    'two_dfg_pct': ['two_dfg_pct'],
    'rim_dfg_pct': ['rim_dfg_pct'],
    'rim_dfgm': ['rim_dfgm'],
    'rim_dfga': ['rim_dfga'],
  };

  final direct = value(aliases[key] ?? [key]);
  if (direct != null) return direct;

  final fga = value(['fga', 'field_goal_attempts']);
  final fta = value(['fta', 'free_throw_attempts']);
  final threeA = value(['fg3a', 'three_pa', 'three_point_attempts']);
  final pts = value(['pts', 'points']);
  if (key == 'ftr' && fga != null && fga != 0 && fta != null) return fta / fga;
  if (key == 'three_par' && fga != null && fga != 0 && threeA != null) return threeA / fga;
  if (key == 'pps' && fga != null && fga != 0 && pts != null) return pts / fga;
  return null;
}

bool _matchesPosition(String value, String wanted) {
  final positions = RegExp(r'PG|SG|SF|PF|C')
      .allMatches(value.toUpperCase())
      .map((match) => match.group(0))
      .whereType<String>()
      .toSet();
  return positions.contains(wanted.toUpperCase());
}

String _formatMetric(double? value, _Metric metric) {
  if (value == null || value.isNaN || value.isInfinite) return '—';
  if (metric.integer) return value.round().toString();
  if (metric.percent) {
    final scaled = value.abs() <= 1.5 ? value * 100 : value;
    return '${scaled.toStringAsFixed(1)}%';
  }
  if (metric.signed) return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  return value.toStringAsFixed(1);
}

String _csvLine(Iterable<String> values) => values.map((value) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }).join(',');
