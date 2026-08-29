import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/website_pagination.dart';
import '../widgets/website_sticky_stats_table.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaLineupAnalysisScreen extends StatefulWidget {
  const WebsiteNbaLineupAnalysisScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaLineupAnalysisScreen> createState() => _WebsiteNbaLineupAnalysisScreenState();
}

class _WebsiteNbaLineupAnalysisScreenState extends State<WebsiteNbaLineupAnalysisScreen> {
  final _api = const WebsiteNbaApiService();
  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<List<Map<String, dynamic>>>? _lineupsFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  String _seasonType = 'regular';
  String _team = 'All';
  int _minGp = 0;
  String _sortKey = 'min';
  bool _descending = true;
  int _pageSize = 20;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _seasonsFuture = _loadSeasons();
  }

  Future<List<WebsiteNbaSeason>> _loadSeasons() async {
    final seasons = await _api.seasons();
    if (seasons.isNotEmpty) {
      _seasons = seasons;
      _season = seasons.firstWhere(
        (item) => item.id == '2025-26',
        orElse: () => seasons.first,
      ).id;
      _lineupsFuture = _loadLineups();
    }
    return seasons;
  }

  Future<List<Map<String, dynamic>>> _loadLineups() async {
    final uri = Uri.base.resolve('data/nba_static/lineups/$_season/$_seasonType.json');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode == 404) return const [];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Static lineup file returned ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw StateError('Static lineup data has an invalid shape.');
    return [
      for (final item in decoded)
        if (item is Map)
          item.map((key, value) => MapEntry(key.toString(), value)),
    ];
  }

  void _reload() {
    setState(() {
      _team = 'All';
      _page = 1;
      _lineupsFuture = _loadLineups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, catalog) {
        if (catalog.connectionState != ConnectionState.done) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }
        if (catalog.hasError || _seasons.isEmpty || _lineupsFuture == null) {
          return _ErrorCard(error: catalog.error, onRetry: () => setState(() => _seasonsFuture = _loadSeasons()));
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _lineupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) return _ErrorCard(error: snapshot.error, onRetry: _reload);
            return _buildPage(context, snapshot.data ?? const []);
          },
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, List<Map<String, dynamic>> sourceRows) {
    final colors = Theme.of(context).colorScheme;
    final teams = <String>{'All'};
    for (final row in sourceRows) {
      final team = (row['team'] ?? '').toString();
      if (team.isNotEmpty) teams.add(team);
    }
    final rows = sourceRows.where((row) {
      if (_team != 'All' && row['team']?.toString() != _team) return false;
      if ((_num(row[_sortAlias('gp')]) ?? _num(row['gp']) ?? 0) < _minGp && _minGp > 0) return false;
      return true;
    }).toList();
    rows.sort((a, b) {
      final left = _value(a, _sortKey);
      final right = _value(b, _sortKey);
      if (left == null && right == null) {
        return (a['group_name'] ?? '').toString().compareTo((b['group_name'] ?? '').toString());
      }
      if (left == null) return 1;
      if (right == null) return -1;
      return _descending ? right.compareTo(left) : left.compareTo(right);
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
      const WebsiteStickyStatsColumn(label: Text('Lineup'), width: 275),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 58),
      for (final metric in _metrics)
        WebsiteStickyStatsColumn(
          label: Text(metric.label),
          width: metric.width,
          numeric: true,
          onTap: () => setState(() {
            if (_sortKey == metric.key) {
              _descending = !_descending;
            } else {
              _sortKey = metric.key;
              _descending = true;
            }
            _page = 1;
          }),
        ),
    ];

    final tableRows = <List<Widget>>[
      for (final row in paged)
        [
          Text(
            (row['group_name'] ?? '—').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          _LineupTeamLink(session: widget.session, team: (row['team'] ?? '').toString()),
          for (final metric in _metrics)
            Text(_format(_value(row, metric.key), metric)),
        ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lineup Analysis',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Five-player unit performance from locally stored NBA.com lineup captures—built for comparison, not a live network dependency.',
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
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'regular', label: Text('Regular Season')),
                    ButtonSegment(value: 'playoffs', label: Text('Playoffs')),
                  ],
                  selected: {_seasonType},
                  onSelectionChanged: (value) {
                    _seasonType = value.first;
                    _reload();
                  },
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    initialValue: teams.contains(_team) ? _team : 'All',
                    decoration: const InputDecoration(labelText: 'Team', isDense: true),
                    items: [
                      for (final item in (teams.toList()..sort()))
                        DropdownMenuItem(value: item, child: Text(item)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() { _team = value; _page = 1; });
                    },
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    initialValue: _minGp,
                    decoration: const InputDecoration(labelText: 'Lineup GP', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Any')),
                      DropdownMenuItem(value: 50, child: Text('50+')),
                      DropdownMenuItem(value: 25, child: Text('25+')),
                      DropdownMenuItem(value: 10, child: Text('10+')),
                      DropdownMenuItem(value: 5, child: Text('5+')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() { _minGp = value; _page = 1; });
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: rows.isEmpty ? null : () => _copyCsv(context, rows),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy CSV'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (sourceRows.isEmpty)
          _NoLineupData(season: _season, seasonType: _seasonType)
        else ...[
          pager(),
          const SizedBox(height: 10),
          WebsiteStickyStatsTable(
            columns: columns,
            rows: tableRows,
            firstColumnWidth: 275,
            headerHeight: 43,
            rowHeight: 42,
          ),
          const SizedBox(height: 10),
          pager(),
        ],
        const SizedBox(height: 18),
        Text(
          'Source: NBA.com LeagueDashLineups captures. Historical lineup rows are materialized into static files at launch; the browser does not call NBA.com to render this page.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  Future<void> _copyCsv(BuildContext context, List<Map<String, dynamic>> rows) async {
    final lines = <String>[
      _csvLine(['Lineup', 'Team', ..._metrics.map((metric) => metric.label)]),
    ];
    for (final row in rows) {
      lines.add(
        _csvLine([
          (row['group_name'] ?? '').toString(),
          (row['team'] ?? '').toString(),
          for (final metric in _metrics) _format(_value(row, metric.key), metric),
        ]),
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${rows.length} lineup rows as CSV.')),
    );
  }
}

class _LineupTeamLink extends StatelessWidget {
  const _LineupTeamLink({required this.session, required this.team});

  final AppSession session;
  final String team;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: team.isEmpty
            ? null
            : () => openWebsiteNbaTeamPage(
                  context,
                  session: session,
                  teamKey: team,
                  teamName: team,
                ),
        child: Text(
          team.isEmpty ? '—' : team,
          style: TextStyle(
            color: team.isEmpty ? null : Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _NoLineupData extends StatelessWidget {
  const _NoLineupData({required this.season, required this.seasonType});

  final String season;
  final String seasonType;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lineup data has not been materialized for this sample yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '$season · ${seasonType == 'playoffs' ? 'Playoffs' : 'Regular Season'} is still available as soon as an authorized local LeagueDashLineups capture is present. Sports Terminal will not invent lineup rows to fill the table.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lineup analysis unavailable',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('${error ?? 'Unable to read the static lineup dataset.'}'),
              const SizedBox(height: 14),
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

class _LineupMetric {
  const _LineupMetric(this.key, this.label, {this.percent = false, this.signed = false, this.integer = false, this.width = 70});

  final String key;
  final String label;
  final bool percent;
  final bool signed;
  final bool integer;
  final double width;
}

const _metrics = <_LineupMetric>[
  _LineupMetric('gp', 'GP', integer: true, width: 54),
  _LineupMetric('min', 'MIN', width: 64),
  _LineupMetric('poss', 'POSS', width: 68),
  _LineupMetric('off_rating', 'ORtg'),
  _LineupMetric('def_rating', 'DRtg'),
  _LineupMetric('net_rating', 'Net', signed: true),
  _LineupMetric('ast_pct', 'AST%', percent: true),
  _LineupMetric('ast_to', 'AST:TO'),
  _LineupMetric('oreb_pct', 'ORB%', percent: true),
  _LineupMetric('dreb_pct', 'DRB%', percent: true),
  _LineupMetric('reb_pct', 'REB%', percent: true),
  _LineupMetric('tov_pct', 'TOV%', percent: true),
  _LineupMetric('efg_pct', 'eFG%', percent: true),
  _LineupMetric('ts_pct', 'TS%', percent: true),
  _LineupMetric('pace', 'Pace'),
  _LineupMetric('pie', 'PIE', percent: true),
];

double? _value(Map<String, dynamic> row, String key) {
  final direct = _num(row[key]);
  if (direct != null) return direct;
  final alias = _sortAlias(key);
  return _num(row[alias]);
}

String _sortAlias(String key) => const {
      'gp': 'GP',
      'min': 'MIN',
      'poss': 'POSS',
      'off_rating': 'OFF_RATING',
      'def_rating': 'DEF_RATING',
      'net_rating': 'NET_RATING',
      'ast_pct': 'AST_PCT',
      'ast_to': 'AST_TO',
      'oreb_pct': 'OREB_PCT',
      'dreb_pct': 'DREB_PCT',
      'reb_pct': 'REB_PCT',
      'tov_pct': 'TM_TOV_PCT',
      'efg_pct': 'EFG_PCT',
      'ts_pct': 'TS_PCT',
      'pace': 'PACE',
      'pie': 'PIE',
    }[key] ?? key;

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '').replaceAll('%', '') ?? '');
}

String _format(double? value, _LineupMetric metric) {
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
