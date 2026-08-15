import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
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
  String _sortKey = 'bpm';
  bool _descending = true;

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
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, catalog) {
        if (catalog.connectionState != ConnectionState.done) return const _Loading();
        if (catalog.hasError || _seasons.isEmpty || _dataFuture == null) {
          return _ErrorState(error: catalog.error, onRetry: () => setState(() => _seasonsFuture = _loadSeasons()));
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
      teams.addAll(row.team.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—'));
    }
    final visible = rows.where((row) {
      if (query.isNotEmpty && !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) return false;
      if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
      if (_position != 'All' && row.position != _position) return false;
      return true;
    }).toList();

    final definition = _categories.firstWhere((item) => item.name == _category);
    final metrics = definition.metrics.where((metric) => visible.any((row) => _metricValue(row, metric.key) != null)).toList();
    if (metrics.isNotEmpty) {
      visible.sort((a, b) {
        final left = _metricValue(a, _sortKey);
        final right = _metricValue(b, _sortKey);
        if (left == null && right == null) return a.player.compareTo(b.player);
        if (left == null) return 1;
        if (right == null) return -1;
        return _descending ? right.compareTo(left) : left.compareTo(right);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Advanced Stats', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 8),
        Text(
          'Deep player statistics organized by the basketball questions they answer—not by a terminal command system.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
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
                    _seasonType = value.first;
                    _reload();
                  },
                ),
                SizedBox(
                  width: 145,
                  child: DropdownButtonFormField<NbaStatsBasis>(
                    initialValue: _basis,
                    decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                    items: [for (final item in NbaStatsBasis.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setState(() => _basis = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search players', isDense: true),
                  ),
                ),
                _StringDropdown(label: 'Team', value: _team, values: teams.toList()..sort(), onChanged: (value) => setState(() => _team = value)),
                _StringDropdown(label: 'Position', value: _position, values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'], onChanged: (value) => setState(() => _position = value)),
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
                    onSelected: (_) => setState(() {
                      _category = item.name;
                      _sortKey = item.metrics.first.key;
                      _descending = true;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(definition.description, style: TextStyle(color: colors.onSurfaceVariant, height: 1.45)),
        const SizedBox(height: 14),
        if (metrics.isEmpty)
          _CoverageNotice(category: definition.name)
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 48,
                columns: [
                  const DataColumn(label: Text('Player')),
                  const DataColumn(label: Text('Team')),
                  const DataColumn(label: Text('Pos')),
                  for (final metric in metrics)
                    DataColumn(
                      numeric: true,
                      label: Text(metric.label),
                      onSort: (_, ascending) => setState(() {
                        _sortKey = metric.key;
                        _descending = !ascending;
                      }),
                    ),
                ],
                rows: [
                  for (final row in visible.take(750))
                    DataRow(cells: [
                      DataCell(
                        Text(row.player, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                        onTap: () => openWebsiteNbaPlayerPage(
                          context,
                          session: widget.session,
                          playerKey: row.playerId,
                          playerName: row.player,
                        ),
                      ),
                      DataCell(
                        Text(row.team, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                        onTap: () {
                          final team = row.team.split(RegExp(r'[,/ ]+')).firstWhere((item) => item.isNotEmpty && item != '—', orElse: () => '');
                          if (team.isNotEmpty) {
                            openWebsiteNbaTeamPage(context, session: widget.session, teamKey: team, teamName: team);
                          }
                        },
                      ),
                      DataCell(Text(row.position)),
                      for (final metric in metrics)
                        DataCell(Text(_formatMetric(_metricValue(row, metric.key), metric))),
                    ]),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'Source boundary: Sports Terminal displays historical fields only when they exist in the canonical warehouse or can be transparently derived from sourced box-score totals. Tracking-only concepts are never fabricated for seasons without tracking coverage.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }
}

class _CoverageNotice extends StatelessWidget {
  const _CoverageNotice({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$category metrics are not source-backed for this season in the active warehouse. The category remains part of the Sports Terminal taxonomy, but the website will not manufacture values to fill it.',
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 145,
        child: DropdownButtonFormField<String>(
          initialValue: values.contains(value) ? value : values.first,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item))],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Advanced NBA data unavailable', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('The canonical NBA warehouse could not be reached. ${error ?? ''}'),
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
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
  const _Metric(this.key, this.label, {this.percent = false, this.signed = false, this.integer = false});
  final String key;
  final String label;
  final bool percent;
  final bool signed;
  final bool integer;
}

const _categories = <_Category>[
  _Category('Overview', 'A compact view of efficiency, workload and overall box-score impact.', [
    _Metric('per', 'PER'), _Metric('ts_pct', 'TS%', percent: true), _Metric('usg_pct', 'USG%', percent: true), _Metric('ws', 'WS'), _Metric('ws48', 'WS/48'), _Metric('bpm', 'BPM', signed: true), _Metric('vorp', 'VORP'),
  ]),
  _Category('Shooting & Efficiency', 'Scoring efficiency and shot-conversion measures.', [
    _Metric('pts', 'PTS'), _Metric('fg_pct', 'FG%', percent: true), _Metric('two_pct', '2P%', percent: true), _Metric('three_pct', '3P%', percent: true), _Metric('ft_pct', 'FT%', percent: true), _Metric('efg_pct', 'eFG%', percent: true), _Metric('ts_pct', 'TS%', percent: true),
  ]),
  _Category('Playmaking & Creation', 'Passing, turnover control and offensive workload.', [
    _Metric('ast', 'AST'), _Metric('tov', 'TOV'), _Metric('ast_tov', 'AST/TOV'), _Metric('usg_pct', 'USG%', percent: true), _Metric('ortg', 'ORtg'),
  ]),
  _Category('Defense', 'Box-score defensive events and source-backed defensive impact metrics.', [
    _Metric('stl', 'STL'), _Metric('blk', 'BLK'), _Metric('dreb', 'DREB'), _Metric('dbpm', 'DBPM', signed: true), _Metric('drtg', 'DRtg'),
  ]),
  _Category('Rebounding', 'Offensive, defensive and total rebounding production.', [
    _Metric('oreb', 'OREB'), _Metric('dreb', 'DREB'), _Metric('reb', 'REB'),
  ]),
  _Category('Impact', 'Basketball-Reference-style box impact and value metrics when sourced.', [
    _Metric('per', 'PER'), _Metric('ws', 'WS'), _Metric('ws48', 'WS/48'), _Metric('obpm', 'OBPM', signed: true), _Metric('dbpm', 'DBPM', signed: true), _Metric('bpm', 'BPM', signed: true), _Metric('vorp', 'VORP'),
  ]),
  _Category('Rate Adjusted', 'Counting production under the selected per-game, per-minute or possession-rate basis.', [
    _Metric('pts', 'PTS'), _Metric('reb', 'REB'), _Metric('ast', 'AST'), _Metric('stl', 'STL'), _Metric('blk', 'BLK'), _Metric('tov', 'TOV'),
  ]),
  _Category('Clutch', 'Late-game and close-game performance when play-by-play-derived clutch fields are available.', [
    _Metric('clutch_pts', 'Clutch PTS'), _Metric('clutch_ts_pct', 'Clutch TS%', percent: true), _Metric('clutch_plus_minus', 'Clutch +/-', signed: true),
  ]),
  _Category('Gravity & Spacing', 'Tracking or derived spacing pressure when source coverage supports it.', [
    _Metric('gravity', 'Gravity'), _Metric('spacing_value', 'Spacing'), _Metric('double_team_rate', 'Double-team%', percent: true),
  ]),
  _Category('On / Off', 'Team performance with the player on and off the court when lineup stints are sourced.', [
    _Metric('on_off_net', 'On/Off Net', signed: true), _Metric('on_court_net', 'On Net', signed: true), _Metric('off_court_net', 'Off Net', signed: true),
  ]),
  _Category('Lineups & Play Types', 'Lineup and possession-type metrics when tracking or event classification exists.', [
    _Metric('lineup_net', 'Lineup Net', signed: true), _Metric('play_type_ppp', 'PPP'), _Metric('possessions', 'Poss', integer: true),
  ]),
];

double? _metricValue(NbaStatsRow row, String key) {
  final normalized = row.value(key);
  if (normalized != null) return normalized;
  final raw = row.raw;
  final aliases = <String, List<String>>{
    'per': ['per'],
    'ws': ['win_shares', 'ws'],
    'ws48': ['win_shares_per_48', 'ws48'],
    'obpm': ['offensive_bpm', 'obpm'],
    'dbpm': ['defensive_bpm', 'dbpm'],
    'bpm': ['avg_bpm', 'bpm'],
    'vorp': ['vorp'],
    'usg_pct': ['usage_percentage', 'usg_pct'],
    'ortg': ['offensive_rating', 'ortg'],
    'drtg': ['defensive_rating', 'drtg'],
    'clutch_pts': ['clutch_points', 'clutch_pts'],
    'clutch_ts_pct': ['clutch_ts_pct'],
    'clutch_plus_minus': ['clutch_plus_minus'],
    'gravity': ['gravity', 'gravity_score'],
    'spacing_value': ['spacing_value'],
    'double_team_rate': ['double_team_rate'],
    'on_off_net': ['on_off_net', 'on_off_net_rating'],
    'on_court_net': ['on_court_net', 'on_court_net_rating'],
    'off_court_net': ['off_court_net', 'off_court_net_rating'],
    'lineup_net': ['lineup_net', 'lineup_net_rating'],
    'play_type_ppp': ['play_type_ppp'],
    'possessions': ['possessions'],
  };
  for (final alias in aliases[key] ?? [key]) {
    final value = raw[alias];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

String _formatMetric(double? value, _Metric metric) {
  if (value == null) return '—';
  if (metric.integer) return value.round().toString();
  if (metric.percent) {
    final scaled = value.abs() <= 1.5 ? value * 100 : value;
    return '${scaled.toStringAsFixed(1)}%';
  }
  if (metric.signed) return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  return value.toStringAsFixed(1);
}
