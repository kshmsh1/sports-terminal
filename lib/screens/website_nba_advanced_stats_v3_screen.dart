import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/website_pagination.dart';
import '../widgets/website_sticky_stats_table.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaAdvancedStatsV3Screen extends StatefulWidget {
  const WebsiteNbaAdvancedStatsV3Screen({super.key, required this.session});
  final AppSession session;

  @override
  State<WebsiteNbaAdvancedStatsV3Screen> createState() => _WebsiteNbaAdvancedStatsV3ScreenState();
}

class _WebsiteNbaAdvancedStatsV3ScreenState extends State<WebsiteNbaAdvancedStatsV3Screen> {
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
  String _gamesFilter = '65+';
  String _minutesFilter = '20+';
  String _sortKey = 'pts';
  bool _descending = true;
  final Set<String> _expandedMetrics = <String>{};
  int _pageSize = 20;
  int? _customPageSize;
  int _page = 1;

  int get _effectivePageSize => _customPageSize ?? _pageSize;

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
      _season = seasons.firstWhere((item) => item.id == '2025-26', orElse: () => seasons.first).id;
      _dataFuture = _loadData();
    }
    return seasons;
  }

  Future<NbaTerminalSeedSnapshot> _loadData() => _api.seasonSnapshot(
        _season,
        seasonType: _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
      );

  void _reload({bool resetTeam = true}) {
    setState(() {
      if (resetTeam) _team = 'All';
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
    if (metric.children.isEmpty) return Text(metric.label, maxLines: 2, overflow: TextOverflow.ellipsis);
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
            size: 32,
          ),
          const SizedBox(width: 1),
          Flexible(child: Text(metric.label, maxLines: 2, overflow: TextOverflow.ellipsis)),
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
    final qualificationRows = _engine.buildRows(data, basis: NbaStatsBasis.perGame, seasonType: _seasonType);
    final qualificationByPlayer = <String, NbaStatsRow>{for (final row in qualificationRows) row.playerId: row};
    final query = _search.text.trim().toLowerCase();
    final teams = <String>{'All'};
    for (final row in rows) {
      teams.addAll(row.team.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—'));
    }

    final minGames = _filterFloor(_gamesFilter);
    final minMpg = _filterFloor(_minutesFilter);
    final visible = rows.where((row) {
      final qualifier = qualificationByPlayer[row.playerId] ?? row;
      final gp = qualifier.values['gp'] ?? _metricValue(qualifier, 'gp') ?? 0;
      final mpg = qualifier.values['min'] ?? _metricValue(qualifier, 'min') ?? 0;
      if (query.isNotEmpty && !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) return false;
      if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
      if (_position != 'All' && !_matchesPosition(row.position, _position)) return false;
      if (minGames != null && gp < minGames) return false;
      if (minMpg != null && mpg < minMpg) return false;
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

    final pageSize = _effectivePageSize;
    final pageCount = math.max(1, (visible.length / pageSize).ceil());
    final safePage = _page.clamp(1, pageCount);
    if (safePage != _page) _page = safePage;
    final pageStart = (safePage - 1) * pageSize;
    final pagedRows = visible.skip(pageStart).take(pageSize).toList();

    Widget pager() => WebsitePagination(
          totalItems: visible.length,
          pageSize: pageSize,
          currentPage: safePage,
          customPageSize: _customPageSize,
          onPageChanged: (value) => setState(() => _page = value),
          onPageSizeChanged: (value) => setState(() {
            _pageSize = value;
            _customPageSize = null;
            _page = 1;
          }),
          onCustomPageSizeChanged: (value) => setState(() {
            _customPageSize = value;
            _page = 1;
          }),
        );

    final childTint = Theme.of(context).brightness == Brightness.dark
        ? colors.primaryContainer.withValues(alpha: .22)
        : colors.primaryContainer.withValues(alpha: .42);

    final tableColumns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Player'), width: 158),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 60),
      const WebsiteStickyStatsColumn(label: Text('Pos'), width: 52),
      for (final item in visibleMetrics)
        WebsiteStickyStatsColumn(
          label: _metricHeader(item.metric),
          width: item.child ? 74 : 70,
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
            child: Text(row.player, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
          ),
          InkWell(
            onTap: () {
              final team = row.team.split(RegExp(r'[,/ ]+')).firstWhere(
                    (item) => item.isNotEmpty && item != '—',
                    orElse: () => '',
                  );
              if (team.isNotEmpty) {
                openWebsiteNbaTeamPage(context, session: widget.session, teamKey: team, teamName: team);
              }
            },
            child: Text(row.team, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
          ),
          Text(row.position),
          for (final item in visibleMetrics)
            Text(_formatMetric(_metricValue(row, item.metric.key), item.metric)),
        ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Stats',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const SizedBox(height: 8),
        Text(
          'Deep player statistics organized by the basketball questions they answer—not by a terminal command system.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
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
                    decoration: const InputDecoration(labelText: 'Season', isDense: true),
                    items: [for (final item in _seasons) DropdownMenuItem(value: item.id, child: Text(item.id))],
                    onChanged: (value) {
                      if (value == null || value == _season) return;
                      _season = value;
                      _reload();
                    },
                  ),
                ),
                SegmentedButton<NbaStatsSeasonType>(
                  segments: const [
                    ButtonSegment(value: NbaStatsSeasonType.regular, label: Text('Regular Season')),
                    ButtonSegment(value: NbaStatsSeasonType.playoffs, label: Text('Playoffs')),
                  ],
                  selected: {_seasonType},
                  onSelectionChanged: (value) {
                    final next = value.first;
                    setState(() {
                      _seasonType = next;
                      if (next == NbaStatsSeasonType.regular) {
                        _gamesFilter = '65+';
                        _minutesFilter = '20+';
                      } else {
                        _gamesFilter = 'All';
                        _minutesFilter = 'All';
                      }
                    });
                    _reload();
                  },
                ),
                SizedBox(
                  width: 132,
                  child: DropdownButtonFormField<NbaStatsBasis>(
                    initialValue: _basis,
                    decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                    items: [for (final item in NbaStatsBasis.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setState(() { _basis = value; _page = 1; });
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
                  width: 230,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() => _page = 1),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search players', isDense: true),
                  ),
                ),
                _StringDropdown(
                  label: 'Team',
                  value: _team,
                  values: teams.toList()..sort(),
                  width: 128,
                  onChanged: (value) => setState(() { _team = value; _page = 1; }),
                ),
                _StringDropdown(
                  label: 'Position',
                  value: _position,
                  values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'],
                  width: 112,
                  onChanged: (value) => setState(() { _position = value; _page = 1; }),
                ),
                _StringDropdown(
                  label: 'Games played',
                  value: _gamesFilter,
                  values: const ['65+', '60+', '50+', '40+', '30+', 'All'],
                  width: 132,
                  onChanged: (value) => setState(() { _gamesFilter = value; _page = 1; }),
                ),
                _StringDropdown(
                  label: 'Minutes / game',
                  value: _minutesFilter,
                  values: const ['20+', '15+', '10+', 'All'],
                  width: 142,
                  onChanged: (value) => setState(() { _minutesFilter = value; _page = 1; }),
                ),
              ],
            ),
          ),
        ),
        if (_seasonType == NbaStatsSeasonType.regular) ...[
          const SizedBox(height: 8),
          Text(
            'Default qualification view: 65+ games and 20+ minutes per game. Use the filters above to broaden the player pool.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
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
        Text(definition.description, style: TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
        if (definition.metrics.any((metric) => metric.children.isNotEmpty)) ...[
          const SizedBox(height: 5),
          Text(
            'Select the triangle beside an expandable column to reveal lightly shaded component stats. Missing source coverage remains visible as —.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 12),
        pager(),
        const SizedBox(height: 8),
        WebsiteStickyStatsTable(
          columns: tableColumns,
          rows: tableRows,
          firstColumnWidth: 158,
          headerHeight: 48,
          rowHeight: 42,
        ),
        const SizedBox(height: 8),
        pager(),
        const SizedBox(height: 18),
        _StatGlossary(category: definition),
        const SizedBox(height: 12),
        Text(
          'Source boundary: every column remains part of the Sports Terminal schema even when the selected season does not contain that metric. Sourced fields and transparent derivations are displayed; unavailable values remain —.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
        ),
      ],
    );
  }
}

class _VisibleMetric {
  const _VisibleMetric(this.metric, this.child);
  final _Metric metric;
  final bool child;
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({required this.label, required this.value, required this.values, required this.onChanged, this.width = 132});
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
          items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))],
          onChanged: (next) { if (next != null) onChanged(next); },
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Advanced NBA data unavailable', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('Sports Terminal could not read its precompiled static NBA season file. ${error ?? ''}'),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ]),
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

List<_Metric> _playType(String prefix, String label) => [
      _Metric('${prefix}_ppp', '$label PPP', 'Points per possession for $label possessions.', children: [
        _Metric('${prefix}_poss', 'Poss', '$label possessions.'),
        _Metric('${prefix}_freq_pct', 'Freq%', 'Frequency of $label possessions.', percent: true),
        _Metric('${prefix}_pts', 'PTS', 'Points scored or allowed on $label possessions.'),
        _Metric('${prefix}_fgm', 'FGM', 'Field goals made on $label possessions.'),
        _Metric('${prefix}_fga', 'FGA', 'Field-goal attempts on $label possessions.'),
        _Metric('${prefix}_fg_pct', 'FG%', 'Field-goal percentage on $label possessions.', percent: true),
        _Metric('${prefix}_efg_pct', 'eFG%', 'Effective field-goal percentage on $label possessions.', percent: true),
        _Metric('${prefix}_ft_freq', 'FT Freq%', 'Free-throw frequency on $label possessions.', percent: true),
        _Metric('${prefix}_tov_freq', 'TOV Freq%', 'Turnover frequency on $label possessions.', percent: true),
        _Metric('${prefix}_sf_freq', 'SF Freq%', 'Shooting-foul frequency on $label possessions.', percent: true),
        _Metric('${prefix}_and_one_freq', 'And-1 Freq%', 'And-one frequency on $label possessions.', percent: true),
        _Metric('${prefix}_score_freq', 'Score Freq%', 'Share of $label possessions producing at least one point.', percent: true),
        _Metric('${prefix}_percentile', 'Percentile', 'PPP percentile versus eligible league players.', percent: true),
      ]),
    ];

List<_Metric> _clutchTraditional() => const [
      _Metric('clutch_gp', 'GP', 'Clutch games played.', integer: true),
      _Metric('clutch_min', 'MIN', 'Clutch minutes.'),
      _Metric('clutch_pts', 'PTS', 'Clutch points.'),
      _Metric('clutch_fg_pct', 'FG%', 'Clutch field-goal percentage.', percent: true, children: [
        _Metric('clutch_fgm', 'FGM', 'Clutch field goals made.'),
        _Metric('clutch_fga', 'FGA', 'Clutch field goals attempted.'),
      ]),
      _Metric('clutch_three_pct', '3P%', 'Clutch three-point percentage.', percent: true, children: [
        _Metric('clutch_three_pm', '3PM', 'Clutch threes made.'),
        _Metric('clutch_three_pa', '3PA', 'Clutch threes attempted.'),
      ]),
      _Metric('clutch_ft_pct', 'FT%', 'Clutch free-throw percentage.', percent: true, children: [
        _Metric('clutch_ftm', 'FTM', 'Clutch free throws made.'),
        _Metric('clutch_fta', 'FTA', 'Clutch free throws attempted.'),
      ]),
      _Metric('clutch_reb', 'REB', 'Clutch rebounds.'),
      _Metric('clutch_ast', 'AST', 'Clutch assists.'),
      _Metric('clutch_tov', 'TOV', 'Clutch turnovers.'),
      _Metric('clutch_stl', 'STL', 'Clutch steals.'),
      _Metric('clutch_blk', 'BLK', 'Clutch blocks.'),
      _Metric('clutch_pf', 'PF', 'Clutch personal fouls.'),
      _Metric('clutch_plus_minus', '+/-', 'Clutch plus-minus.', signed: true),
    ];

final _categories = <_Category>[
  _Category('Overview', 'Traditional production, shooting and headline all-in-one measures.', [
    const _Metric('gp', 'GP', 'Games played.', integer: true),
    const _Metric('min', 'MPG', 'Minutes played per game.'),
    const _Metric('pts', 'PPG', 'Points scored per game.'),
    const _Metric('reb', 'RPG', 'Total rebounds per game.', children: [
      _Metric('oreb', 'ORB', 'Offensive rebounds per game.'),
      _Metric('dreb', 'DRB', 'Defensive rebounds per game.'),
    ]),
    const _Metric('ast', 'APG', 'Assists per game.'),
    const _Metric('stl', 'SPG', 'Steals per game.'),
    const _Metric('blk', 'BPG', 'Blocks per game.'),
    const _Metric('tov', 'TPG', 'Turnovers per game.'),
    const _Metric('pf', 'PF', 'Personal fouls.'),
    const _Metric('fantasy_points', 'FP', 'NBA fantasy points.'),
    const _Metric('double_doubles', 'DD2', 'Double-doubles.'),
    const _Metric('triple_doubles', 'TD3', 'Triple-doubles.'),
    const _Metric('plus_minus', '+/-', 'Point differential while the player is on the floor.', signed: true),
    const _Metric('fg_pct', 'FG%', 'Field-goal percentage.', percent: true, children: [
      _Metric('fgm', 'FGM', 'Field goals made.'),
      _Metric('fga', 'FGA', 'Field goals attempted.'),
    ]),
    const _Metric('three_pct', '3P%', 'The player’s own three-point percentage: 3PM divided by 3PA.', percent: true, children: [
      _Metric('three_pm', '3PM', 'Three-pointers made.'),
      _Metric('three_pa', '3PA', 'Three-pointers attempted.'),
    ]),
    const _Metric('ft_pct', 'FT%', 'Free-throw percentage.', percent: true, children: [
      _Metric('ftm', 'FTM', 'Free throws made.'),
      _Metric('fta', 'FTA', 'Free throws attempted.'),
    ]),
  ]),
  _Category('Advanced', 'NBA advanced rates, efficiency, possession estimates and estimated metrics.', [
    const _Metric('ortg', 'ORtg', 'Team points scored per 100 possessions while the player is on court.'),
    const _Metric('drtg', 'DRtg', 'Team points allowed per 100 possessions while the player is on court.'),
    const _Metric('net_rating', 'NetRtg', 'Offensive rating minus defensive rating.', signed: true),
    const _Metric('ast_pct', 'AST%', 'Share of teammate field goals assisted while on court.', percent: true),
    const _Metric('ast_tov', 'AST/TO', 'Assist-to-turnover ratio.'),
    const _Metric('ast_ratio', 'AST Ratio', 'Assists per 100 possessions used.'),
    const _Metric('oreb_pct', 'OREB%', 'Offensive rebound percentage.', percent: true),
    const _Metric('dreb_pct', 'DREB%', 'Defensive rebound percentage.', percent: true),
    const _Metric('reb_pct', 'REB%', 'Total rebound percentage.', percent: true),
    const _Metric('tov_ratio', 'TO Ratio', 'Turnovers per 100 possessions used.'),
    const _Metric('efg_pct', 'eFG%', 'Effective field-goal percentage.', percent: true),
    const _Metric('ts_pct', 'TS%', 'True shooting percentage.', percent: true),
    const _Metric('usg_pct', 'USG%', 'Usage percentage.', percent: true),
    const _Metric('pace', 'Pace', 'Possessions per 48 minutes while on court.'),
    const _Metric('pie', 'PIE', 'Player Impact Estimate.', percent: true),
    const _Metric('possessions', 'Poss', 'Possessions played or estimated.'),
    const _Metric('e_off_rating', 'Est ORtg', 'Estimated offensive rating.'),
    const _Metric('e_def_rating', 'Est DRtg', 'Estimated defensive rating.'),
    const _Metric('e_net_rating', 'Est NetRtg', 'Estimated net rating.', signed: true),
    const _Metric('e_ast_ratio', 'Est AST Ratio', 'Estimated assist ratio.'),
    const _Metric('e_oreb_pct', 'Est OREB%', 'Estimated offensive rebound percentage.', percent: true),
    const _Metric('e_dreb_pct', 'Est DREB%', 'Estimated defensive rebound percentage.', percent: true),
    const _Metric('e_reb_pct', 'Est REB%', 'Estimated total rebound percentage.', percent: true),
    const _Metric('e_tm_tov_pct', 'Est TO Ratio', 'Estimated turnover ratio.', percent: true),
    const _Metric('e_usg_pct', 'Est USG%', 'Estimated usage percentage.', percent: true),
    const _Metric('e_pace', 'Est Pace', 'Estimated pace.'),
  ]),
  _Category('Shooting & Efficiency', 'Scoring efficiency, shot mix, assisted creation and location profile.', [
    const _Metric('efg_pct', 'eFG%', 'Effective field-goal percentage.', percent: true),
    const _Metric('ts_pct', 'TS%', 'True shooting percentage.', percent: true),
    const _Metric('ftr', 'FTR', 'Free-throw attempts divided by field-goal attempts.'),
    const _Metric('three_par', '3PAr', 'Three-point attempts divided by field-goal attempts.'),
    const _Metric('pps', 'PPS', 'Points scored per field-goal attempt.'),
    const _Metric('two_point_attempt_share', '%FGA 2PT', 'Share of field-goal attempts that are twos.', percent: true),
    const _Metric('three_freq', '%FGA 3PT', 'Share of field-goal attempts that are threes.', percent: true),
    const _Metric('two_point_points_share', '%PTS 2PT', 'Share of points from two-point field goals.', percent: true),
    const _Metric('midrange_points_share', '%PTS 2PT MR', 'Share of points from midrange two-point field goals.', percent: true),
    const _Metric('three_point_points_share', '%PTS 3PT', 'Share of points from threes.', percent: true),
    const _Metric('fast_break_points_share', '%PTS FB', 'Share of points from fast breaks.', percent: true),
    const _Metric('free_throw_points_share', '%PTS FT', 'Share of points from free throws.', percent: true),
    const _Metric('off_turnover_points_share', '%PTS Off TO', 'Share of points scored after opponent turnovers.', percent: true),
    const _Metric('paint_points_share', '%PTS Paint', 'Share of points scored in the paint.', percent: true),
    const _Metric('pct_ast_2pm', '2FGM %AST', 'Share of made twos that are assisted.', percent: true),
    const _Metric('pct_uast_2pm', '2FGM %UAST', 'Share of made twos that are unassisted.', percent: true),
    const _Metric('pct_ast_3pm', '3FGM %AST', 'Share of made threes that are assisted.', percent: true),
    const _Metric('pct_uast_3pm', '3FGM %UAST', 'Share of made threes that are unassisted.', percent: true),
    const _Metric('pct_ast_fgm', 'FGM %AST', 'Share of all made field goals that are assisted.', percent: true),
    const _Metric('pct_uast_fgm', 'FGM %UAST', 'Share of all made field goals that are unassisted.', percent: true),
    const _Metric('rim_freq', 'Rim Freq', 'Share of attempts at the rim.', percent: true),
    const _Metric('rim_fg_pct', 'Rim FG%', 'Field-goal percentage at the rim.', percent: true),
    const _Metric('paint_freq', 'Paint Freq', 'Share of attempts from the paint.', percent: true),
    const _Metric('paint_fg_pct', 'Paint FG%', 'Field-goal percentage in the paint.', percent: true),
    const _Metric('midrange_freq', 'Midrange Freq', 'Share of attempts from midrange.', percent: true),
    const _Metric('midrange_fg_pct', 'Midrange FG%', 'Midrange field-goal percentage.', percent: true),
    const _Metric('corner_three_freq', 'Corner 3 Freq', 'Share of attempts from either corner three.', percent: true),
    const _Metric('corner_three_pct', 'Corner 3P%', 'Three-point percentage from the corners.', percent: true),
    const _Metric('catch_shoot_three_freq', 'C&S 3 Freq', 'Share of attempts that are catch-and-shoot threes.', percent: true),
    const _Metric('catch_shoot_three_pct', 'C&S 3P%', 'Three-point percentage on catch-and-shoot threes.', percent: true),
    const _Metric('pullup_three_freq', 'Pull-Up 3 Freq', 'Share of attempts that are pull-up threes.', percent: true),
    const _Metric('pullup_three_pct', 'Pull-Up 3P%', 'Three-point percentage on pull-up threes.', percent: true),
    const _Metric('heaves_pg', 'HPG', 'Heave attempts per game.'),
    const _Metric('dunks_pg', 'Dunks PG', 'Dunks per game.'),
    const _Metric('layups_pg', 'Layups PG', 'Layups per game.'),
  ]),
  _Category('Playmaking & Creation', 'Passing volume, assist creation, touch control and turnover management.', [
    const _Metric('ast', 'APG', 'Assists per game.'),
    const _Metric('tov', 'TPG', 'Turnovers per game.'),
    const _Metric('screen_ast_pg', 'Screen APG', 'Screen assists per game.'),
    const _Metric('secondary_ast_pg', 'Secondary APG', 'Secondary assists per game.'),
    const _Metric('potential_ast_pg', 'Potential APG', 'Potential assists per game.'),
    const _Metric('passes_pg', 'Passes PG', 'Passes made per game.'),
    const _Metric('passes_received_pg', 'Passes Rec PG', 'Passes received per game.'),
    const _Metric('ast_tov', 'AST:TO', 'Assist-to-turnover ratio.'),
    const _Metric('ast_pct', 'AST%', 'Assist percentage.', percent: true),
    const _Metric('tov_pct', 'TOV%', 'Turnover percentage.', percent: true),
    const _Metric('ft_ast_pg', 'FT APG', 'Free-throw assists per game.'),
    const _Metric('ast_points_created', 'AST PTS Created', 'Points created through assists.'),
    const _Metric('ast_adj', 'AST Adj', 'Assists plus free-throw assists plus secondary assists.'),
    const _Metric('ast_to_pass_pct', 'AST to Pass%', 'Assists divided by passes made.', percent: true),
    const _Metric('ast_to_pass_adj_pct', 'AST to Pass% Adj', 'Adjusted assists divided by passes made.', percent: true),
    const _Metric('touches', 'Touches', 'Touches per game.'),
    const _Metric('front_ct_touches', 'Front CT Touches', 'Front-court touches per game.'),
    const _Metric('time_of_poss', 'Time of Poss', 'Minutes of ball possession.'),
    const _Metric('avg_sec_per_touch', 'Sec / Touch', 'Average seconds per touch.'),
    const _Metric('avg_drib_per_touch', 'Drib / Touch', 'Average dribbles per touch.'),
    const _Metric('pts_per_touch', 'PTS / Touch', 'Points scored per touch.'),
  ]),
  _Category('Defense', 'Defensive events, shot suppression, impact, hustle and matchup outcomes.', [
    const _Metric('stl', 'SPG', 'Steals per game.', children: [
      _Metric('stl_pct', 'STL%', 'Percentage of team steals credited to the player while on court.', percent: true),
    ]),
    const _Metric('blk', 'BPG', 'Blocks per game.', children: [
      _Metric('blk_pct', 'BLK%', 'Percentage of team blocks credited to the player while on court.', percent: true),
    ]),
    const _Metric('deflections_pg', 'DPG', 'Deflections per game.'),
    const _Metric('dreb', 'DREB', 'Defensive rebounds per game.'),
    const _Metric('charges_drawn_pg', 'Charges Drawn PG', 'Charges drawn per game.'),
    const _Metric('contested_shots_pg', 'Contested Shots PG', 'Contested shots per game.', children: [
      _Metric('contested_shots_2pt_pg', '2PT Contests PG', 'Contested two-point shots per game.'),
      _Metric('contested_shots_3pt_pg', '3PT Contests PG', 'Contested three-point shots per game.'),
    ]),
    const _Metric('loose_balls_recovered_pg', 'Loose Balls PG', 'Loose balls recovered per game.', children: [
      _Metric('off_loose_balls_recovered_pg', 'OFF Loose PG', 'Offensive loose balls recovered per game.'),
      _Metric('def_loose_balls_recovered_pg', 'DEF Loose PG', 'Defensive loose balls recovered per game.'),
    ]),
    const _Metric('dfg_pct', 'DFG%', 'Opponent field-goal percentage on attempts defended by the player.', percent: true, children: [
      _Metric('dfgm', 'DFGM', 'Defended field goals made.'),
      _Metric('dfga', 'DFGA', 'Defended field-goal attempts.'),
      _Metric('rim_dfg_pct', 'Rim DFG%', 'Opponent field-goal percentage on defended shots inside six feet.', percent: true),
      _Metric('three_dfg_pct', '3P DFG%', 'Opponent three-point percentage on defended threes; distinct from the player’s own 3P%.', percent: true),
      _Metric('two_dfg_pct', '2P DFG%', 'Opponent two-point percentage on defended twos.', percent: true),
    ]),
    const _Metric('box_out_pct', 'Box Out %', 'Rebound outcome rate on player box-outs.', percent: true),
    const _Metric('dbpm', 'D-BPM', 'Defensive component of Box Plus/Minus.', signed: true),
    const _Metric('drtg', 'DRtg', 'Team points allowed per 100 possessions while the player is on court.'),
    const _Metric('def_ws', 'DEF WS', 'Defensive Win Shares.'),
    const _Metric('opp_pts_off_tov', 'Opp PTS Off TO', 'Opponent points following turnovers.'),
    const _Metric('opp_pts_second_chance', 'Opp 2nd PTS', 'Opponent second-chance points.'),
    const _Metric('opp_fast_break_points', 'Opp FBPs', 'Opponent fast-break points.'),
    const _Metric('opp_paint_points', 'Opp PITP', 'Opponent points in the paint.'),
    const _Metric('blow_by_rate', 'Blow-By Rate', 'Rate at which the primary defender is beaten off the dribble.', percent: true),
    const _Metric('contest_distance', 'Contest Distance', 'Average distance from the shooter at the contest.'),
    const _Metric('help_defense', 'Help Defense', 'Source-backed help-defense activity or impact.'),
    const _Metric('deterrence_rate', 'Deterrence', 'Estimated shot deterrence rate.', percent: true),
    const _Metric('switch_attrition_rate', 'Switch Attrition', 'Performance retention across defensive switches.', percent: true),
  ]),
  _Category('Rebounding', 'Rebound volume, opportunity, contestedness, distance, box-outs and deferred chances.', [
    const _Metric('reb', 'RPG', 'Total rebounds per game.', children: [
      _Metric('contested_reb_pg', 'Contested RPG', 'Contested rebounds per game.'),
      _Metric('uncontested_reb_pg', 'Uncontested RPG', 'Uncontested rebounds per game.'),
      _Metric('reb_pct', 'TRB%', 'Total rebound percentage.', percent: true),
      _Metric('reb_chances_pg', 'REB Chances', 'Rebound chances per game.'),
      _Metric('reb_chance_pct', 'REB Chance%', 'Rebounds gathered divided by rebound chances.', percent: true),
      _Metric('deferred_reb_chances_pg', 'Deferred Chances', 'Deferred rebound chances per game.'),
      _Metric('adjusted_reb_chance_pct', 'Adj REB Chance%', 'Rebound chance percentage excluding deferred chances.', percent: true),
      _Metric('avg_reb_distance', 'Avg REB Dist', 'Average rebound distance.'),
    ]),
    const _Metric('dreb', 'DRB', 'Defensive rebounds per game.', children: [
      _Metric('contested_dreb_pg', 'Contested DRB', 'Contested defensive rebounds per game.'),
      _Metric('uncontested_dreb_pg', 'Uncontested DRB', 'Uncontested defensive rebounds per game.'),
      _Metric('dreb_pct', 'DRB%', 'Defensive rebound percentage.', percent: true),
      _Metric('dreb_chances_pg', 'DREB Chances', 'Defensive rebound chances per game.'),
      _Metric('dreb_chance_pct', 'DREB Chance%', 'Defensive rebound chance percentage.', percent: true),
      _Metric('deferred_dreb_chances_pg', 'Deferred DREB', 'Deferred defensive rebound chances per game.'),
      _Metric('adjusted_dreb_chance_pct', 'Adj DREB Chance%', 'Defensive rebound chance percentage excluding deferred chances.', percent: true),
      _Metric('avg_dreb_distance', 'Avg DREB Dist', 'Average defensive rebound distance.'),
    ]),
    const _Metric('oreb', 'ORB', 'Offensive rebounds per game.', children: [
      _Metric('contested_oreb_pg', 'Contested ORB', 'Contested offensive rebounds per game.'),
      _Metric('uncontested_oreb_pg', 'Uncontested ORB', 'Uncontested offensive rebounds per game.'),
      _Metric('oreb_pct', 'ORB%', 'Offensive rebound percentage.', percent: true),
      _Metric('oreb_chances_pg', 'OREB Chances', 'Offensive rebound chances per game.'),
      _Metric('oreb_chance_pct', 'OREB Chance%', 'Offensive rebound chance percentage.', percent: true),
      _Metric('deferred_oreb_chances_pg', 'Deferred OREB', 'Deferred offensive rebound chances per game.'),
      _Metric('adjusted_oreb_chance_pct', 'Adj OREB Chance%', 'Offensive rebound chance percentage excluding deferred chances.', percent: true),
      _Metric('avg_oreb_distance', 'Avg OREB Dist', 'Average offensive rebound distance.'),
    ]),
    const _Metric('box_outs_pg', 'Box Outs PG', 'Box-outs per game.', children: [
      _Metric('off_box_outs_pg', 'OFF Box Outs PG', 'Offensive box-outs per game.'),
      _Metric('def_box_outs_pg', 'DEF Box Outs PG', 'Defensive box-outs per game.'),
      _Metric('pct_box_outs_off', '% Box Outs Off', 'Share of box-outs occurring on offense.', percent: true),
      _Metric('pct_box_outs_def', '% Box Outs Def', 'Share of box-outs occurring on defense.', percent: true),
      _Metric('pct_box_outs_team_reb', '% Team Reb', 'Team rebound rate when the player boxes out.', percent: true),
      _Metric('pct_box_outs_reb', '% Player Reb', 'Player rebound rate when the player boxes out.', percent: true),
    ]),
  ]),
  _Category('Usage', 'Share of team actions and outcomes attributed to the player while on court.', const [
    _Metric('usg_pct', 'USG%', 'Usage percentage.', percent: true),
    _Metric('pct_team_fgm', '%FGM', 'Percent of team made field goals.', percent: true),
    _Metric('pct_team_fga', '%FGA', 'Percent of team field-goal attempts.', percent: true),
    _Metric('pct_team_fg3m', '%3PM', 'Percent of team made threes.', percent: true),
    _Metric('pct_team_fg3a', '%3PA', 'Percent of team three-point attempts.', percent: true),
    _Metric('pct_team_ftm', '%FTM', 'Percent of team made free throws.', percent: true),
    _Metric('pct_team_fta', '%FTA', 'Percent of team free-throw attempts.', percent: true),
    _Metric('pct_team_oreb', '%OREB', 'Percent of team offensive rebounds.', percent: true),
    _Metric('pct_team_dreb', '%DREB', 'Percent of team defensive rebounds.', percent: true),
    _Metric('pct_team_reb', '%REB', 'Percent of team rebounds.', percent: true),
    _Metric('pct_team_ast', '%AST', 'Percent of team assists.', percent: true),
    _Metric('pct_team_tov', '%TOV', 'Percent of team turnovers.', percent: true),
    _Metric('pct_team_stl', '%STL', 'Percent of team steals.', percent: true),
    _Metric('pct_team_blk', '%BLK', 'Percent of team blocks.', percent: true),
    _Metric('pct_team_blka', '%BLKA', 'Percent of team blocked field-goal attempts.', percent: true),
    _Metric('pct_team_pf', '%PF', 'Percent of team personal fouls.', percent: true),
    _Metric('pct_team_pfd', '%PFD', 'Percent of team personal fouls drawn.', percent: true),
    _Metric('pct_team_pts', '%PTS', 'Percent of team points.', percent: true),
  ]),
  _Category('Opponent', 'Opponent production while the selected player is on court or in the specified matchup context.', const [
    _Metric('opp_fgm', 'Opp FGM', 'Opponent field goals made.'),
    _Metric('opp_fga', 'Opp FGA', 'Opponent field-goal attempts.'),
    _Metric('opp_fg_pct', 'Opp FG%', 'Opponent field-goal percentage.', percent: true),
    _Metric('opp_three_pm', 'Opp 3PM', 'Opponent threes made.'),
    _Metric('opp_three_pa', 'Opp 3PA', 'Opponent threes attempted.'),
    _Metric('opp_three_pct', 'Opp 3P%', 'Opponent three-point percentage.', percent: true),
    _Metric('opp_ftm', 'Opp FTM', 'Opponent free throws made.'),
    _Metric('opp_fta', 'Opp FTA', 'Opponent free throws attempted.'),
    _Metric('opp_ft_pct', 'Opp FT%', 'Opponent free-throw percentage.', percent: true),
    _Metric('opp_oreb', 'Opp OREB', 'Opponent offensive rebounds.'),
    _Metric('opp_dreb', 'Opp DREB', 'Opponent defensive rebounds.'),
    _Metric('opp_reb', 'Opp REB', 'Opponent rebounds.'),
    _Metric('opp_ast', 'Opp AST', 'Opponent assists.'),
    _Metric('opp_tov', 'Opp TOV', 'Opponent turnovers.'),
    _Metric('opp_stl', 'Opp STL', 'Opponent steals.'),
    _Metric('opp_blk', 'Opp BLK', 'Opponent blocks.'),
    _Metric('opp_blka', 'Opp BLKA', 'Opponent blocked attempts.'),
    _Metric('opp_pf', 'Opp PF', 'Opponent personal fouls.'),
    _Metric('opp_pfd', 'Opp PFD', 'Opponent personal fouls drawn.'),
    _Metric('opp_pts', 'Opp PTS', 'Opponent points.'),
    _Metric('opp_plus_minus', '+/-', 'Opponent-context plus-minus.', signed: true),
  ]),
  _Category('Impact', 'Team impact and all-in-one impact models.', const [
    _Metric('ortg', 'ORtg', 'Offensive rating.'),
    _Metric('drtg', 'DRtg', 'Defensive rating.'),
    _Metric('net_rating', 'Net Rating', 'Offensive rating minus defensive rating.', signed: true),
    _Metric('on_off_net', 'On/Off Diff', 'Net-rating swing between player-on and player-off minutes.', signed: true),
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
    _Metric('la_rapm', 'LA-RAPM', 'Luck-adjusted RAPM.', signed: true),
    _Metric('warv', 'WARV', 'Wins above replacement value.'),
    _Metric('pie', 'PIE', 'Player Impact Estimate.', percent: true),
  ]),
  _Category('Rate Adjusted', 'Production normalized by the selected rate basis.', const [
    _Metric('pts', 'PTS', 'Points under the selected rate basis.'),
    _Metric('reb', 'REB', 'Rebounds under the selected rate basis.'),
    _Metric('ast', 'AST', 'Assists under the selected rate basis.'),
    _Metric('stl', 'STL', 'Steals under the selected rate basis.'),
    _Metric('blk', 'BLK', 'Blocks under the selected rate basis.'),
    _Metric('tov', 'TOV', 'Turnovers under the selected rate basis.'),
    _Metric('possessions', 'Poss', 'Possessions used or estimated.'),
    _Metric('usg_pct', 'USG%', 'Usage percentage.', percent: true),
  ]),
  _Category('Clutch', 'Traditional, advanced, miscellaneous, scoring and usage metrics in source-defined clutch possessions.', [
    ..._clutchTraditional(),
    const _Metric('clutch_ortg', 'Clutch ORtg', 'Clutch offensive rating.'),
    const _Metric('clutch_drtg', 'Clutch DRtg', 'Clutch defensive rating.'),
    const _Metric('clutch_net', 'Clutch NetRtg', 'Clutch net rating.', signed: true),
    const _Metric('clutch_ast_pct', 'Clutch AST%', 'Clutch assist percentage.', percent: true),
    const _Metric('clutch_ast_tov', 'Clutch AST/TO', 'Clutch assist-to-turnover ratio.'),
    const _Metric('clutch_ast_ratio', 'Clutch AST Ratio', 'Clutch assist ratio.'),
    const _Metric('clutch_oreb_pct', 'Clutch OREB%', 'Clutch offensive rebound percentage.', percent: true),
    const _Metric('clutch_dreb_pct', 'Clutch DREB%', 'Clutch defensive rebound percentage.', percent: true),
    const _Metric('clutch_reb_pct', 'Clutch REB%', 'Clutch rebound percentage.', percent: true),
    const _Metric('clutch_tov_ratio', 'Clutch TO Ratio', 'Clutch turnover ratio.'),
    const _Metric('clutch_efg_pct', 'Clutch eFG%', 'Clutch effective FG%.', percent: true),
    const _Metric('clutch_ts_pct', 'Clutch TS%', 'Clutch true shooting percentage.', percent: true),
    const _Metric('clutch_usg_pct', 'Clutch USG%', 'Clutch usage percentage.', percent: true),
    const _Metric('clutch_pace', 'Clutch Pace', 'Clutch pace.'),
    const _Metric('clutch_pie', 'Clutch PIE', 'Clutch Player Impact Estimate.', percent: true),
    const _Metric('clutch_pts_off_tov', 'Clutch PTS Off TO', 'Clutch points off turnovers.'),
    const _Metric('clutch_second_chance_pts', 'Clutch 2nd PTS', 'Clutch second-chance points.'),
    const _Metric('clutch_fast_break_pts', 'Clutch FBPs', 'Clutch fast-break points.'),
    const _Metric('clutch_paint_pts', 'Clutch PITP', 'Clutch points in the paint.'),
  ]),
  _Category('Play Types', 'Synergy-style offensive and defensive possession outcomes by play type.', [
    ..._playType('iso_off', 'Isolation Off'),
    ..._playType('iso_def', 'Isolation Def'),
    ..._playType('transition_off', 'Transition Off'),
    ..._playType('pnr_handler_off', 'PnR Handler Off'),
    ..._playType('pnr_handler_def', 'PnR Handler Def'),
    ..._playType('pnr_roll_off', 'PnR Roll Off'),
    ..._playType('pnr_roll_def', 'PnR Roll Def'),
    ..._playType('post_off', 'Post-Up Off'),
    ..._playType('post_def', 'Post-Up Def'),
    ..._playType('spot_up_off', 'Spot-Up Off'),
    ..._playType('spot_up_def', 'Spot-Up Def'),
    ..._playType('handoff_off', 'Handoff Off'),
    ..._playType('handoff_def', 'Handoff Def'),
    ..._playType('cut_off', 'Cut Off'),
    ..._playType('off_screen_off', 'Off-Screen Off'),
    ..._playType('off_screen_def', 'Off-Screen Def'),
    ..._playType('putback_off', 'Putback Off'),
    ..._playType('misc_playtype_off', 'Misc Off'),
  ]),
  _Category('Tracking', 'Drives, passing, touches, shot creation and other optical-tracking outputs.', const [
    _Metric('drives', 'Drives', 'Drives per game.', children: [
      _Metric('drive_fgm', 'FGM', 'Field goals made on drives.'),
      _Metric('drive_fga', 'FGA', 'Field-goal attempts on drives.'),
      _Metric('drive_fg_pct', 'FG%', 'Field-goal percentage on drives.', percent: true),
      _Metric('drive_ftm', 'FTM', 'Free throws made from drives.'),
      _Metric('drive_fta', 'FTA', 'Free-throw attempts from drives.'),
      _Metric('drive_ft_pct', 'FT%', 'Free-throw percentage on drive-generated attempts.', percent: true),
      _Metric('drive_pts', 'PTS', 'Points scored on drives.'),
      _Metric('drive_pts_pct', 'PTS%', 'Share of drive possessions ending in points.', percent: true),
      _Metric('drive_pass', 'PASS', 'Passes out of drives.'),
      _Metric('drive_pass_pct', 'PASS%', 'Drive pass percentage.', percent: true),
      _Metric('drive_ast', 'AST', 'Assists from drives.'),
      _Metric('drive_ast_pct', 'AST%', 'Drive assist percentage.', percent: true),
      _Metric('drive_tov', 'TO', 'Turnovers on drives.'),
      _Metric('drive_tov_pct', 'TOV%', 'Drive turnover percentage.', percent: true),
      _Metric('drive_pf', 'PF', 'Fouls drawn or attributed in drive context.'),
      _Metric('drive_pf_pct', 'PF%', 'Drive foul percentage.', percent: true),
    ]),
    _Metric('defensive_impact_dfg_pct', 'Def Impact DFG%', 'Defensive Impact defended FG%.', percent: true, children: [
      _Metric('defensive_impact_dfgm', 'DFGM', 'Defensive Impact defended makes.'),
      _Metric('defensive_impact_dfga', 'DFGA', 'Defensive Impact defended attempts.'),
      _Metric('defensive_impact_stl', 'STL', 'Steals in Defensive Impact feed.'),
      _Metric('defensive_impact_blk', 'BLK', 'Blocks in Defensive Impact feed.'),
      _Metric('defensive_impact_dreb', 'DREB', 'Defensive rebounds in Defensive Impact feed.'),
    ]),
    _Metric('catch_shoot_efg_pct', 'C&S eFG%', 'Catch-and-shoot effective field-goal percentage.', percent: true, children: [
      _Metric('catch_shoot_pts', 'PTS', 'Catch-and-shoot points.'),
      _Metric('catch_shoot_fgm', 'FGM', 'Catch-and-shoot field goals made.'),
      _Metric('catch_shoot_fga', 'FGA', 'Catch-and-shoot attempts.'),
      _Metric('catch_shoot_fg_pct', 'FG%', 'Catch-and-shoot field-goal percentage.', percent: true),
      _Metric('catch_shoot_three_pm', '3PM', 'Catch-and-shoot threes made.'),
      _Metric('catch_shoot_three_pa', '3PA', 'Catch-and-shoot threes attempted.'),
      _Metric('catch_shoot_three_pct', '3P%', 'Catch-and-shoot three-point percentage.', percent: true),
    ]),
    _Metric('passes_pg', 'Passing', 'Passes made per game.', children: [
      _Metric('passes_received_pg', 'Passes Received', 'Passes received per game.'),
      _Metric('ast', 'AST', 'Assists.'),
      _Metric('secondary_ast_pg', 'Secondary AST', 'Secondary assists per game.'),
      _Metric('potential_ast_pg', 'Potential AST', 'Potential assists per game.'),
      _Metric('ast_points_created', 'AST PTS Created', 'Assist points created.'),
      _Metric('ast_adj', 'AST Adj', 'Adjusted assists.'),
      _Metric('ast_to_pass_pct', 'AST to Pass%', 'Assist-to-pass percentage.', percent: true),
      _Metric('ast_to_pass_adj_pct', 'AST to Pass% Adj', 'Adjusted assist-to-pass percentage.', percent: true),
    ]),
    _Metric('touches', 'Touches', 'Touches per game.', children: [
      _Metric('front_ct_touches', 'Front CT', 'Front-court touches.'),
      _Metric('time_of_poss', 'Time of Poss', 'Time of possession.'),
      _Metric('avg_sec_per_touch', 'Sec / Touch', 'Average seconds per touch.'),
      _Metric('avg_drib_per_touch', 'Drib / Touch', 'Average dribbles per touch.'),
      _Metric('pts_per_touch', 'PTS / Touch', 'Points per touch.'),
      _Metric('elbow_touches', 'Elbow Touches', 'Elbow touches.'),
      _Metric('post_ups', 'Post Ups', 'Post touches/post-ups.'),
      _Metric('paint_touches', 'Paint Touches', 'Paint touches.'),
      _Metric('pts_per_elbow_touch', 'PTS / Elbow', 'Points per elbow touch.'),
      _Metric('pts_per_post_touch', 'PTS / Post', 'Points per post touch.'),
      _Metric('pts_per_paint_touch', 'PTS / Paint', 'Points per paint touch.'),
    ]),
    _Metric('pull_up_efg_pct', 'Pull-Up eFG%', 'Pull-up effective field-goal percentage.', percent: true, children: [
      _Metric('pull_up_pts', 'PTS', 'Pull-up points.'),
      _Metric('pull_up_fgm', 'FGM', 'Pull-up field goals made.'),
      _Metric('pull_up_fga', 'FGA', 'Pull-up attempts.'),
      _Metric('pull_up_fg_pct', 'FG%', 'Pull-up field-goal percentage.', percent: true),
      _Metric('pull_up_three_pm', '3PM', 'Pull-up threes made.'),
      _Metric('pull_up_three_pa', '3PA', 'Pull-up threes attempted.'),
      _Metric('pull_up_three_pct', '3P%', 'Pull-up three-point percentage.', percent: true),
    ]),
    _Metric('shooting_efficiency_efg_pct', 'Tracking eFG%', 'Tracking shooting-efficiency eFG%.', percent: true, children: [
      _Metric('drive_pts', 'Drive PTS', 'Points on drives.'),
      _Metric('drive_fg_pct', 'Drive FG%', 'Field-goal percentage on drives.', percent: true),
      _Metric('catch_shoot_pts', 'C&S PTS', 'Catch-and-shoot points.'),
      _Metric('catch_shoot_fg_pct', 'C&S FG%', 'Catch-and-shoot field-goal percentage.', percent: true),
      _Metric('pull_up_pts', 'Pull-Up PTS', 'Pull-up points.'),
      _Metric('pull_up_fg_pct', 'Pull-Up FG%', 'Pull-up field-goal percentage.', percent: true),
      _Metric('paint_touch_pts', 'Paint Touch PTS', 'Paint-touch points.'),
      _Metric('paint_touch_fg_pct', 'Paint Touch FG%', 'Paint-touch FG%.', percent: true),
      _Metric('post_touch_pts', 'Post Touch PTS', 'Post-touch points.'),
      _Metric('post_touch_fg_pct', 'Post Touch FG%', 'Post-touch FG%.', percent: true),
      _Metric('elbow_touch_pts', 'Elbow Touch PTS', 'Elbow-touch points.'),
      _Metric('elbow_touch_fg_pct', 'Elbow Touch FG%', 'Elbow-touch FG%.', percent: true),
    ]),
    _Metric('distance_miles', 'Distance', 'Distance traveled in miles.', children: [
      _Metric('distance_feet', 'Feet', 'Distance traveled in feet.'),
      _Metric('distance_miles_off', 'Miles Off', 'Miles traveled on offense.'),
      _Metric('distance_miles_def', 'Miles Def', 'Miles traveled on defense.'),
      _Metric('avg_speed', 'Avg Speed', 'Average speed.'),
      _Metric('avg_speed_off', 'Speed Off', 'Average offensive speed.'),
      _Metric('avg_speed_def', 'Speed Def', 'Average defensive speed.'),
    ]),
    _Metric('elbow_touches', 'Elbow Touches', 'Elbow touches.', children: [
      _Metric('elbow_fgm', 'FGM', 'Elbow-touch field goals made.'),
      _Metric('elbow_fga', 'FGA', 'Elbow-touch field-goal attempts.'),
      _Metric('elbow_fg_pct', 'FG%', 'Elbow-touch FG%.', percent: true),
      _Metric('elbow_pts', 'PTS', 'Elbow-touch points.'),
      _Metric('elbow_pass', 'PASS', 'Passes from elbow touches.'),
      _Metric('elbow_ast', 'AST', 'Assists from elbow touches.'),
      _Metric('elbow_tov', 'TO', 'Turnovers from elbow touches.'),
    ]),
    _Metric('post_ups', 'Post Ups', 'Post touches.', children: [
      _Metric('post_fgm', 'FGM', 'Post-touch field goals made.'),
      _Metric('post_fga', 'FGA', 'Post-touch attempts.'),
      _Metric('post_fg_pct', 'FG%', 'Post-touch FG%.', percent: true),
      _Metric('post_pts', 'PTS', 'Post-touch points.'),
      _Metric('post_pass', 'PASS', 'Passes from post touches.'),
      _Metric('post_ast', 'AST', 'Assists from post touches.'),
      _Metric('post_tov', 'TO', 'Turnovers from post touches.'),
    ]),
    _Metric('paint_touches', 'Paint Touches', 'Paint touches.', children: [
      _Metric('paint_fgm', 'FGM', 'Paint-touch field goals made.'),
      _Metric('paint_fga', 'FGA', 'Paint-touch attempts.'),
      _Metric('paint_fg_pct', 'FG%', 'Paint-touch FG%.', percent: true),
      _Metric('paint_pts', 'PTS', 'Paint-touch points.'),
      _Metric('paint_pass', 'PASS', 'Passes from paint touches.'),
      _Metric('paint_ast', 'AST', 'Assists from paint touches.'),
      _Metric('paint_tov', 'TO', 'Turnovers from paint touches.'),
    ]),
  ]),
  _Category('Hustle & Box Outs', 'Hustle events and box-out outcomes from NBA optical/manual tracking.', const [
    _Metric('screen_ast_pg', 'Screen Assists PG', 'Screen assists per game.', children: [
      _Metric('screen_ast_points_pg', 'Screen AST PTS PG', 'Points created by screen assists per game.'),
    ]),
    _Metric('deflections_pg', 'Deflections PG', 'Deflections per game.'),
    _Metric('loose_balls_recovered_pg', 'Loose Balls PG', 'Loose balls recovered per game.', children: [
      _Metric('off_loose_balls_recovered_pg', 'OFF Loose PG', 'Offensive loose balls recovered per game.'),
      _Metric('def_loose_balls_recovered_pg', 'DEF Loose PG', 'Defensive loose balls recovered per game.'),
    ]),
    _Metric('charges_drawn_pg', 'Charges PG', 'Charges drawn per game.'),
    _Metric('contested_shots_pg', 'Contested Shots PG', 'Contested shots per game.', children: [
      _Metric('contested_shots_2pt_pg', '2PT Contests PG', 'Contested two-point shots per game.'),
      _Metric('contested_shots_3pt_pg', '3PT Contests PG', 'Contested three-point shots per game.'),
    ]),
    _Metric('box_outs_pg', 'Box Outs PG', 'Box-outs per game.', children: [
      _Metric('off_box_outs_pg', 'OFF Box Outs', 'Offensive box-outs per game.'),
      _Metric('def_box_outs_pg', 'DEF Box Outs', 'Defensive box-outs per game.'),
      _Metric('box_out_player_team_rebs_pg', 'Team Reb / Box Out', 'Team rebounds generated on box-outs per game.'),
      _Metric('box_out_player_rebs_pg', 'Player Reb / Box Out', 'Player rebounds generated on box-outs per game.'),
      _Metric('pct_box_outs_off', '% Box Outs Off', 'Share of box-outs on offense.', percent: true),
      _Metric('pct_box_outs_def', '% Box Outs Def', 'Share of box-outs on defense.', percent: true),
      _Metric('pct_box_outs_team_reb', '% Team Reb', 'Team rebound percentage when the player boxes out.', percent: true),
      _Metric('pct_box_outs_reb', '% Player Reb', 'Player rebound percentage when the player boxes out.', percent: true),
    ]),
  ]),
  _Category('Gravity & Spacing', 'Shot gravity, offensive attention, spacing and advantage creation.', const [
    _Metric('gravity', 'Gravity', 'Source-backed offensive or shot gravity.'),
    _Metric('spacing_value', 'Spacing', 'Estimated spacing value created for teammates.'),
    _Metric('double_team_rate', 'Double-Team Rate', 'Share of possessions attracting a double team.', percent: true),
    _Metric('drive_gravity', 'Drive Gravity', 'Defensive attention generated on drives.'),
    _Metric('shot_gravity', 'Shot Gravity', 'Defensive attention generated by shooting threat.'),
    _Metric('freeze_time', 'Freeze Time', 'Time defenders are held by the player’s threat.'),
    _Metric('offensive_gravity', 'Off. Gravity', 'Overall offensive gravity.'),
    _Metric('pass_windows_opened', 'Pass Windows', 'Passing lanes opened by offensive attention.'),
  ]),
  _Category('On / Off', 'On-court and off-court team performance splits.', const [
    _Metric('on_off_net', 'On/Off Net', 'Net-rating swing between player-on and player-off minutes.', signed: true),
    _Metric('on_court_net', 'On-Court Net', 'Team net rating with the player on court.', signed: true),
    _Metric('off_court_net', 'Off-Court Net', 'Team net rating with the player off court.', signed: true),
  ]),
  _Category('Lineups & Roles', 'Lineup context and role-level impact.', const [
    _Metric('lineup_net', 'Lineup Net', 'Net rating for qualifying lineups associated with the player.', signed: true),
    _Metric('screens_set_pg', 'Screens Set PG', 'Screens set per game.'),
    _Metric('screens_used_pg', 'Screens Used PG', 'Screens used by the ball handler per game.'),
  ]),
  _Category('Movement & Physical', 'Movement load and physical measurements.', const [
    _Metric('distance_miles', 'Distance', 'Distance traveled.'),
    _Metric('avg_speed', 'Avg Speed', 'Average on-court speed.'),
    _Metric('avg_speed_off', 'Avg Speed Off', 'Average offensive speed.'),
    _Metric('avg_speed_def', 'Avg Speed Def', 'Average defensive speed.'),
    _Metric('height', 'Height', 'Listed or measured height.'),
    _Metric('weight', 'Weight', 'Listed or measured weight.'),
    _Metric('wingspan', 'Wingspan', 'Measured wingspan.'),
    _Metric('standing_reach', 'Standing Reach', 'Measured standing reach.'),
    _Metric('hand_length', 'Hand Length', 'Measured hand length.'),
    _Metric('hand_width', 'Hand Width', 'Measured hand width.'),
    _Metric('standing_jump', 'Standing Vertical', 'Standing vertical leap.'),
    _Metric('max_vertical_jump', 'Max Vertical', 'Maximum vertical leap.'),
    _Metric('body_fat_pct', 'Body Fat %', 'Measured body-fat percentage.', percent: true),
    _Metric('lane_agility', 'Lane Agility', 'Lane agility drill time.'),
    _Metric('shuttle_run', 'Shuttle Run', 'Shuttle-run time.'),
    _Metric('three_quarter_sprint', '3/4 Sprint', 'Three-quarter-court sprint time.'),
  ]),
  _Category('Discipline & Events', 'Violations, foul types, sanctions and end-of-clock events.', const [
    _Metric('travel', 'Travel', 'Traveling violations.'),
    _Metric('double_dribble', 'Double Dribble', 'Double-dribble violations.'),
    _Metric('discontinued_dribble', 'Disc. Dribble', 'Discontinued-dribble violations.'),
    _Metric('off_three_sec', 'Off. 3 Sec', 'Offensive three-second violations.'),
    _Metric('inbound', 'Inbound', 'Inbound violations.'),
    _Metric('backcourt', 'Backcourt', 'Backcourt violations.'),
    _Metric('off_goaltending', 'Off. Goaltend', 'Offensive goaltending violations.'),
    _Metric('palming', 'Palming', 'Palming/carrying violations.'),
    _Metric('offensive_fouls', 'Off. Fouls', 'Offensive fouls.'),
    _Metric('def_three_sec', 'Def. 3 Sec', 'Defensive three-second violations.'),
    _Metric('charges', 'Charges', 'Charge violations/fouls.'),
    _Metric('def_goaltending', 'Def. Goaltend', 'Defensive goaltending violations.'),
    _Metric('lane', 'Lane', 'Lane violations.'),
    _Metric('jump_ball', 'Jump Ball', 'Jump-ball violations/events.'),
    _Metric('kicked_ball', 'Kicked Ball', 'Kicked-ball violations.'),
    _Metric('technical_fouls', 'Technical Fouls', 'Technical fouls.'),
    _Metric('shooting_fouls', 'Shooting Fouls', 'Shooting fouls.'),
    _Metric('defensive_fouls', 'Defensive Fouls', 'Defensive fouls.'),
    _Metric('other_fouls', 'Other Fouls', 'Other categorized fouls.'),
    _Metric('ejections', 'Ejections', 'Ejections.'),
    _Metric('disqualifications', 'Disqualifications', 'Disqualifications.'),
    _Metric('suspensions', 'Suspensions', 'Suspensions.'),
    _Metric('game_buzzer_beaters', 'Game Buzzer Beaters', 'Made shots beating the final game buzzer.'),
    _Metric('quarter_buzzer_beaters', 'Quarter Buzzer Beaters', 'Made shots beating a quarter-ending buzzer.'),
    _Metric('shot_clock_buzzer_beaters', 'Shot-Clock Beaters', 'Made shots immediately before shot-clock expiration.'),
  ]),
];

class _StatGlossary extends StatefulWidget {
  const _StatGlossary({required this.category});
  final _Category category;

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
      for (final child in metric.children) metrics[child.key] = child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.category.name} Glossary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              Text('${metrics.length} metrics · concise definitions', style: Theme.of(context).textTheme.bodySmall),
            ])),
            Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          ]),
        ),
        if (_open) ...[
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080 ? 4 : constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 520 ? 2 : 1;
            final width = (constraints.maxWidth - ((columns - 1) * 8)) / columns;
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
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(metric.glossary, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3)),
                        ]),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ],
    );
  }
}

double? _filterFloor(String value) {
  if (value == 'All') return null;
  return double.tryParse(value.replaceAll('+', ''));
}

double? _metricValue(NbaStatsRow row, String key) {
  double? rawValue(List<String> keys) {
    for (final candidate in keys) {
      final direct = row.values[candidate];
      if (direct != null) return direct;
      for (final entry in row.raw.entries) {
        if (entry.key.toLowerCase() != candidate.toLowerCase()) continue;
        final value = entry.value;
        if (value is num) return value.toDouble();
        final parsed = double.tryParse(value?.toString().replaceAll(',', '').replaceAll('%', '') ?? '');
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  const aliases = <String, List<String>>{
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
    'fg_pct': ['fg_pct'],
    'three_pm': ['three_pm', 'three_pointers_made', 'fg3m'],
    'three_pa': ['three_pa', 'three_point_attempts', 'fg3a'],
    'three_pct': ['three_pct'],
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
    'possessions': ['possessions', 'poss'],
    'ast_pct': ['ast_pct'],
    'ast_tov': ['ast_to', 'ast_tov'],
    'ast_ratio': ['ast_ratio'],
    'tov_pct': ['tov_pct', 'tm_tov_pct', 'e_tov_pct'],
    'tov_ratio': ['tov_ratio', 'tm_tov_pct'],
    'stl_pct': ['stl_pct'],
    'blk_pct': ['blk_pct'],
    'oreb_pct': ['oreb_pct'],
    'dreb_pct': ['dreb_pct'],
    'reb_pct': ['reb_pct', 'trb_pct'],
    'e_off_rating': ['e_off_rating'],
    'e_def_rating': ['e_def_rating'],
    'e_net_rating': ['e_net_rating'],
    'e_ast_ratio': ['e_ast_ratio'],
    'e_oreb_pct': ['e_oreb_pct'],
    'e_dreb_pct': ['e_dreb_pct'],
    'e_reb_pct': ['e_reb_pct'],
    'e_tm_tov_pct': ['e_tm_tov_pct'],
    'e_usg_pct': ['e_usg_pct'],
    'e_pace': ['e_pace'],
    'deflections_pg': ['deflections_pg'],
    'charges_drawn_pg': ['charges_drawn_pg'],
    'contested_shots_pg': ['contested_shots_pg'],
    'contested_shots_2pt_pg': ['contested_shots_2pt_pg'],
    'contested_shots_3pt_pg': ['contested_shots_3pt_pg'],
    'loose_balls_recovered_pg': ['loose_balls_recovered_pg'],
    'off_loose_balls_recovered_pg': ['off_loose_balls_recovered_pg'],
    'def_loose_balls_recovered_pg': ['def_loose_balls_recovered_pg'],
    'dfg_pct': ['d_fg_pct', 'dfg_pct'],
    'dfgm': ['d_fgm', 'dfgm'],
    'dfga': ['d_fga', 'dfga'],
    'rim_dfg_pct': ['rim_dfg_pct'],
    'three_dfg_pct': ['three_dfg_pct'],
    'two_dfg_pct': ['two_dfg_pct'],
    'box_out_pct': ['box_out_pct', 'pct_box_outs_reb'],
    'box_outs_pg': ['box_outs_pg'],
    'screen_ast_pg': ['screen_ast_pg'],
    'screen_ast_points_pg': ['screen_ast_points_pg'],
    'secondary_ast_pg': ['secondary_ast_pg', 'secondary_ast'],
    'potential_ast_pg': ['potential_ast_pg', 'potential_ast'],
    'passes_pg': ['passes_pg', 'passes_made'],
    'passes_received_pg': ['passes_received_pg', 'passes_received'],
    'ft_ast_pg': ['ft_ast_pg', 'ft_assists'],
    'ast_points_created': ['ast_points_created'],
    'distance_miles': ['distance_miles', 'dist_miles'],
    'avg_speed': ['avg_speed'],
    'on_off_net': ['on_off_net', 'on_off_net_rating'],
    'on_court_net': ['on_court_net', 'on_court_net_rating'],
    'off_court_net': ['off_court_net', 'off_court_net_rating'],
    'lineup_net': ['lineup_net', 'lineup_net_rating'],
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
  };

  final direct = rawValue(aliases[key] ?? [key]);
  if (direct != null) return direct;

  final fga = rawValue(['fga', 'field_goal_attempts']);
  final fta = rawValue(['fta', 'free_throw_attempts']);
  final threeA = rawValue(['three_pa', 'three_point_attempts', 'fg3a']);
  final pts = rawValue(['pts', 'points']);
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
