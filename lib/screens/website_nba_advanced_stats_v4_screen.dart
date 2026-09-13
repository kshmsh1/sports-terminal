import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/nba_percentage_heat_cell.dart';
import '../widgets/website_pagination.dart';
import '../widgets/website_sticky_stats_table.dart';
import 'website_nba_entity_pages.dart';

// NOTE: The remainder of this file is intentionally kept identical to the
// previous implementation except for percentage heat-cell rendering and a
// visible 3PM metric in Overview/Shooting categories.

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
              .contains(query)) return false;
      if (_team != 'All' &&
          !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
      if (_position != 'All' && !_matchesPosition(row.position, _position)) {
        return false;
      }
      if ((row.value('gp') ?? 0) < _minGp) return false;
      if ((row.value('min') ?? 0) < _minMpg) return false;
      return true;
    }).toList();

    final definition = _categories.firstWhere((item) => item.name == _category);
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
    final safePage = _page < 1 ? 1 : _page > pageCount ? pageCount : _page;
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
            _AdvancedMetricValueCell(
              metric: item.metric,
              value: _metricValue(row, item.metric.key, _basis),
              basis: _basis,
            ),
        ],
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1510),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Advanced Stats', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 8),
            Text('Deep player statistics organized by basketball questions, with explicit source boundaries and stable rate conversions.', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45)),
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
                      onSelectionChanged: (value) => _changeSegment(value.first),
                    ),
                    SizedBox(
                      width: 148,
                      child: DropdownButtonFormField<NbaStatsBasis>(
                        initialValue: _basis,
                        decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                        items: [for (final item in NbaStatsBasis.values) DropdownMenuItem(value: item, child: Text(item.label))],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _basis = value;
                            _page = 1;
                          });
                        },
                      ),
                    ),
                    _StringDropdown(label: 'Stat group', value: _category, values: [for (final item in _categories) item.name], width: 205, onChanged: _selectCategory),
                    SizedBox(width: 220, child: TextField(controller: _search, onChanged: (_) => setState(() => _page = 1), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search players', isDense: true))),
                    _StringDropdown(label: 'Team', value: _team, values: teams.toList()..sort(), onChanged: (value) => setState(() { _team = value; _page = 1; })),
                    _StringDropdown(label: 'Position', value: _position, values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'], width: 112, onChanged: (value) => setState(() { _position = value; _page = 1; })),
                    _MinimumDropdown(label: 'GP', value: _minGp, values: const [50,65,60,40,30,20,10,0], onChanged: (value) => setState(() { _minGp = value; _page = 1; })),
                    _MinimumDropdown(label: 'MPG', value: _minMpg, values: const [0,30,25,20,15,10], onChanged: (value) => setState(() { _minMpg = value; _page = 1; })),
                    TextButton.icon(onPressed: _resetFilters, icon: const Icon(Icons.restart_alt_rounded, size: 18), label: const Text('Reset filters')),
                    OutlinedButton.icon(onPressed: () => _copyCsv(context, filtered, visibleMetrics), icon: const Icon(Icons.copy_all_outlined, size: 18), label: const Text('Copy CSV')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final item in _categories) Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(item.name), selected: item.name == _category, onSelected: (_) => _selectCategory(item.name)))])),
            const SizedBox(height: 10),
            Text(definition.description, style: TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 4),
            Text(_basisDescription(_basis), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 12),
            pager(),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              _EmptyCard(_seasonType == NbaStatsSeasonType.playoffs ? 'No playoff rows match these filters for $_season.' : 'No regular-season rows match these filters for $_season.')
            else
              WebsiteStickyStatsTable(columns: tableColumns, rows: tableRows, firstColumnWidth: 164, headerHeight: 46, rowHeight: 40),
            const SizedBox(height: 8),
            pager(),
            const SizedBox(height: 16),
            _StatGlossary(category: definition, basis: _basis),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCsv(BuildContext context, List<NbaStatsRow> rows, List<_VisibleMetric> metrics) async {
    final header = ['Player','Team','Pos',...metrics.map((item) => item.metric.displayLabel(_basis))];
    final lines = <String>[_csvLine(header)];
    for (final row in rows) {
      lines.add(_csvLine([row.player,row.team,row.position,for (final item in metrics) _formatMetric(_metricValue(row, item.metric.key, _basis),item.metric,_basis)]));
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${rows.length} filtered rows as CSV.')));
  }
}

class _AdvancedMetricValueCell extends StatelessWidget {
  const _AdvancedMetricValueCell({required this.metric, required this.value, required this.basis});
  final _Metric metric;
  final double? value;
  final NbaStatsBasis basis;
  @override
  Widget build(BuildContext context) {
    final text = Text(_formatMetric(value, metric, basis), maxLines: 1, overflow: TextOverflow.ellipsis);
    final heat = nbaPercentageHeatMetricForKey(metric.key);
    if (heat == null) return text;
    return Align(alignment: Alignment.centerRight, child: NbaPercentageHeatCell(metric: heat, value: value, child: text));
  }
}

class _TeamLink extends StatelessWidget {
  const _TeamLink({required this.session, required this.row});
  final AppSession session;
  final NbaStatsRow row;
  @override
  Widget build(BuildContext context) {
    final teams = row.team.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—').toList();
    final team = teams.length == 1 ? teams.first : '';
    return InkWell(
      onTap: team.isEmpty ? null : () => openWebsiteNbaTeamPage(context, session: session, teamKey: team, teamName: team),
      child: Text(row.team, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: team.isEmpty ? null : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({required this.label,required this.value,required this.values,required this.onChanged,this.width = 124});
  final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; final double width;
  @override Widget build(BuildContext context) => SizedBox(width: width, child: DropdownButtonFormField<String>(initialValue: values.contains(value) ? value : values.first, decoration: InputDecoration(labelText: label, isDense: true), items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))], onChanged: (next) { if (next != null) onChanged(next); }));
}

class _MinimumDropdown extends StatelessWidget {
  const _MinimumDropdown({required this.label,required this.value,required this.values,required this.onChanged});
  final String label; final int value; final List<int> values; final ValueChanged<int> onChanged;
  @override Widget build(BuildContext context) => SizedBox(width: 104, child: DropdownButtonFormField<int>(initialValue: values.contains(value) ? value : values.first, decoration: InputDecoration(labelText: label, isDense: true), items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item == 0 ? 'Any' : '$item+'))], onChanged: (next) { if (next != null) onChanged(next); }));
}

class _VisibleMetric { const _VisibleMetric(this.metric,this.child); final _Metric metric; final bool child; }
class _Category { const _Category(this.name,this.description,this.metrics); final String name; final String description; final List<_Metric> metrics; }
class _Metric {
  const _Metric(this.key,this.label,this.glossary,{this.totalLabel,this.rateAbbreviation,this.rateSensitive=false,this.percent=false,this.signed=false,this.integer=false,this.children=const []});
  final String key; final String label; final String glossary; final String? totalLabel; final String? rateAbbreviation; final bool rateSensitive; final bool percent; final bool signed; final bool integer; final List<_Metric> children;
  String displayLabel(NbaStatsBasis basis) { if (!rateSensitive) return label; final stem = rateAbbreviation ?? label.replaceAll(' PG','').replaceAll('PG',''); switch (basis) { case NbaStatsBasis.perGame: return label; case NbaStatsBasis.totals: return totalLabel ?? stem; case NbaStatsBasis.per36: return '$stem/36'; case NbaStatsBasis.per48: return '$stem/48'; case NbaStatsBasis.per75: return '$stem/75'; case NbaStatsBasis.per100: return '$stem/100'; } }
}

_Metric countMetric(String key,String perGameLabel,String totalLabel,String abbreviation,String glossary,{List<_Metric> children=const []}) => _Metric(key,perGameLabel,glossary,totalLabel:totalLabel,rateAbbreviation:abbreviation,rateSensitive:true,children:children);
_Metric childCount(String key,String label,String totalLabel,String abbreviation,String glossary) => _Metric(key,label,glossary,totalLabel:totalLabel,rateAbbreviation:abbreviation,rateSensitive:true);

final _categories = <_Category>[
  _Category('Overview','Core production, traditional shooting efficiency and headline impact measures.',[
    const _Metric('gp','GP','Games played.',integer:true),
    countMetric('min','MPG','Minutes','MIN','Minutes played.'),
    countMetric('pts','PPG','Points','PTS','Points scored.'),
    countMetric('reb','RPG','Rebounds','REB','Total rebounds.',children:[childCount('oreb','ORB','Offensive Rebounds','OREB','Offensive rebounds.'),childCount('dreb','DREB','Defensive Rebounds','DREB','Defensive rebounds.')]),
    countMetric('ast','APG','Assists','AST','Assists.'),
    countMetric('stl','SPG','Steals','STL','Steals.'),
    countMetric('blk','BPG','Blocks','BLK','Blocks.'),
    countMetric('tov','TPG','Turnovers','TOV','Turnovers.'),
    countMetric('pf','PF PG','Personal Fouls','PF','Personal fouls.'),
    _Metric('fg_pct','FG%','Field-goal percentage.',percent:true,children:[childCount('fgm','FGM','Field Goals Made','FGM','Field goals made.'),childCount('fga','FGA','Field Goal Attempts','FGA','Field-goal attempts.')]),
    countMetric('three_pm','3PM','Three-Pointers Made','3PM','Three-pointers made.'),
    countMetric('three_pa','3PA','Three-Point Attempts','3PA','Three-point attempts.'),
    const _Metric('three_pct','3P%','Three-point percentage.',percent:true),
    _Metric('ft_pct','FT%','Free-throw percentage.',percent:true,children:[childCount('ftm','FTM','Free Throws Made','FTM','Free throws made.'),childCount('fta','FTA','Free Throw Attempts','FTA','Free-throw attempts.')]),
    const _Metric('pace','Pace','Estimated possessions per 48 team minutes.'),
    const _Metric('pie','PIE','NBA Player Impact Estimate.'),
    const _Metric('per','PER','Player Efficiency Rating.'),
    const _Metric('bpm','BPM','Box Plus/Minus.',signed:true,children:[_Metric('obpm','OBPM','Offensive Box Plus/Minus.',signed:true),_Metric('dbpm','DBPM','Defensive Box Plus/Minus.',signed:true)]),
    const _Metric('vorp','VORP','Value Over Replacement Player.'),
    const _Metric('ws','WS','Win Shares.'),
  ]),
  _Category('Shooting & Efficiency','Scoring efficiency, shot mix and three-point production.',[
    const _Metric('fg_pct','FG%','Field-goal percentage.',percent:true),
    countMetric('three_pm','3PM','Three-Pointers Made','3PM','Three-pointers made.'),
    countMetric('three_pa','3PA','Three-Point Attempts','3PA','Three-point attempts.'),
    const _Metric('three_pct','3P%','Three-point percentage.',percent:true),
    const _Metric('ft_pct','FT%','Free-throw percentage.',percent:true),
    const _Metric('efg_pct','eFG%','Effective field-goal percentage.',percent:true),
    const _Metric('ts_pct','TS%','True shooting percentage.',percent:true),
  ]),
  _Category('Defense','Box-score events, hustle activity, defended shooting, contests, deterrence and foul discipline.',[
    countMetric('stl','SPG','Steals','STL','Steals.'),
    countMetric('blk','BPG','Blocks','BLK','Blocks.'),
    countMetric('deflections_pg','DPG','Deflections','DEFL','Deflections.'),
    _Metric('dfg_pct','DFG%','Opponent field-goal percentage on attempts defended by the player.',percent:true,children:[childCount('dfgm','DFGM','Defended Field Goals Made','DFGM','Opponent field goals made when defended.'),childCount('dfga','DFGA','Defended Field Goal Attempts','DFGA','Opponent field-goal attempts when defended.')]),
    const _Metric('rim_dfg_pct','Rim DFG%','Opponent rim FG% when defended by the player.',percent:true),
    const _Metric('three_dfg_pct','3P DFG%','Opponent 3P% when defended by the player.',percent:true),
    const _Metric('dbpm','DBPM','Defensive Box Plus/Minus.',signed:true),
    const _Metric('drtg','DRtg','Defensive rating.'),
  ]),
  _Category('Rebounding','Overall, offensive and defensive rebounding volume.',[
    countMetric('reb','RPG','Rebounds','REB','Total rebounds.'),
    countMetric('dreb','DREB','Defensive Rebounds','DREB','Defensive rebounds.'),
    countMetric('oreb','OREB','Offensive Rebounds','OREB','Offensive rebounds.'),
  ]),
  _Category('Impact','Team impact and all-in-one value metrics.',const [
    _Metric('ortg','ORtg','Offensive rating.'),
    _Metric('drtg','DRtg','Defensive rating.'),
    _Metric('net_rating','Net Rating','Offensive rating minus defensive rating.',signed:true),
    _Metric('per','PER','Player Efficiency Rating.'),
    _Metric('bpm','BPM','Box Plus/Minus.',signed:true),
    _Metric('vorp','VORP','Value Over Replacement Player.'),
    _Metric('ws','WS','Win Shares.'),
  ]),
  _Category('Rate Adjusted','Core counting production on the selected rate basis.',[
    countMetric('min','MPG','Minutes','MIN','Minutes played.'),
    countMetric('pts','PPG','Points','PTS','Points.'),
    countMetric('reb','RPG','Rebounds','REB','Rebounds.'),
    countMetric('ast','APG','Assists','AST','Assists.'),
    countMetric('stl','SPG','Steals','STL','Steals.'),
    countMetric('blk','BPG','Blocks','BLK','Blocks.'),
    countMetric('tov','TPG','Turnovers','TOV','Turnovers.'),
    countMetric('fgm','FGM PG','Field Goals Made','FGM','Field goals made.'),
    countMetric('three_pm','3PM PG','Three-Pointers Made','3PM','Three-pointers made.'),
    countMetric('ftm','FTM PG','Free Throws Made','FTM','Free throws made.'),
  ]),
];

class _StatGlossary extends StatelessWidget {
  const _StatGlossary({required this.category, required this.basis});
  final _Category category; final NbaStatsBasis basis;
  @override Widget build(BuildContext context) => ExpansionTile(title: const Text('Stat Glossary'), children: [for (final metric in category.metrics) ListTile(title: Text(metric.displayLabel(basis)), subtitle: Text(metric.glossary))]);
}

class _Loading extends StatelessWidget { const _Loading(); @override Widget build(BuildContext context) => const SizedBox(height:360, child:Center(child:CircularProgressIndicator())); }
class _ErrorState extends StatelessWidget { const _ErrorState({required this.error,required this.onRetry}); final Object? error; final VoidCallback onRetry; @override Widget build(BuildContext context)=>Center(child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Advanced Stats source unavailable'),const SizedBox(height:8),Text('${error ?? ''}'),const SizedBox(height:12),OutlinedButton(onPressed:onRetry,child:const Text('Retry'))])))); }
class _EmptyCard extends StatelessWidget { const _EmptyCard(this.message); final String message; @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Text(message))); }

bool _matchesPosition(String value,String wanted){final positions=RegExp(r'PG|SG|SF|PF|C').allMatches(value.toUpperCase()).map((m)=>m.group(0)).whereType<String>().toSet();return positions.contains(wanted.toUpperCase());}

double? _metricValue(NbaStatsRow row,String key,NbaStatsBasis basis){
  final base=row.value(key); if(base==null)return null;
  if (basis==NbaStatsBasis.perGame) return base;
  if (const {'fg_pct','three_pct','ft_pct','efg_pct','ts_pct','dfg_pct','rim_dfg_pct','three_dfg_pct','pie','per','bpm','vorp','ws','ortg','drtg','net_rating'}.contains(key)) return base;
  final gp=row.value('gp')??0; final min=row.value('min')??0;
  switch(basis){case NbaStatsBasis.totals:return base*gp;case NbaStatsBasis.per36:return min>0?base*36/min:null;case NbaStatsBasis.per48:return min>0?base*48/min:null;case NbaStatsBasis.per75:case NbaStatsBasis.per100:return base;case NbaStatsBasis.perGame:return base;}
}

String _formatMetric(double? value,_Metric metric,NbaStatsBasis basis){if(value==null||value.isNaN||value.isInfinite)return '—';if(metric.percent)return '${(value*100).toStringAsFixed(1)}%';if(metric.integer)return value.round().toString();if(metric.signed)return '${value>=0?'+':''}${value.toStringAsFixed(1)}';return value.toStringAsFixed(1);}
String _basisDescription(NbaStatsBasis basis)=>switch(basis){NbaStatsBasis.perGame=>'Per-game values.',NbaStatsBasis.totals=>'Season totals.',NbaStatsBasis.per36=>'Per 36 minutes.',NbaStatsBasis.per48=>'Per 48 minutes.',NbaStatsBasis.per75=>'Per 75 possessions.',NbaStatsBasis.per100=>'Per 100 possessions.'};
String _csvLine(List<Object?> values)=>values.map((value){final text=value?.toString()??'';return '"${text.replaceAll('"','""')}"';}).join(',');
