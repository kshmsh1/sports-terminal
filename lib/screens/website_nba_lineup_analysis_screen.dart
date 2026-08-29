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
  final _search = TextEditingController();

  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<List<Map<String, dynamic>>>? _lineupsFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  String _seasonType = 'regular';
  String _team = 'All';
  int _groupQuantity = 5;
  int _minGp = 0;
  int _minMinutes = 0;
  String _metricGroup = 'Overview';
  String _sortKey = 'min';
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
      _lineupsFuture = _loadLineups();
    }
    return seasons;
  }

  String get _staticPath {
    if (_groupQuantity == 5) {
      return 'data/nba_static/lineups/$_season/$_seasonType.json';
    }
    return 'data/nba_static/lineups/q$_groupQuantity/$_season/$_seasonType.json';
  }

  Future<List<Map<String, dynamic>>> _loadLineups() async {
    final response = await http.get(Uri.base.resolve(_staticPath)).timeout(const Duration(seconds: 8));
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

  void _reload({bool resetTeam = true}) {
    setState(() {
      if (resetTeam) _team = 'All';
      _page = 1;
      _lineupsFuture = _loadLineups();
    });
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _team = 'All';
      _minGp = 0;
      _minMinutes = 0;
      _metricGroup = 'Overview';
      _sortKey = 'min';
      _descending = true;
      _page = 1;
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
          return _ErrorCard(
            error: catalog.error,
            onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
          );
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
    final query = _search.text.trim().toLowerCase();
    final teams = <String>{'All'};
    for (final row in sourceRows) {
      final team = (row['team'] ?? '').toString();
      if (team.isNotEmpty) teams.add(team);
    }

    final rows = sourceRows.where((row) {
      final groupName = (row['group_name'] ?? '').toString();
      final team = (row['team'] ?? '').toString();
      if (query.isNotEmpty && !'$groupName $team'.toLowerCase().contains(query)) return false;
      if (_team != 'All' && team != _team) return false;
      if ((_value(row, 'gp') ?? 0) < _minGp) return false;
      if ((_value(row, 'min') ?? 0) < _minMinutes) return false;
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
    final metrics = _metricGroups[_metricGroup] ?? _metricGroups['Overview']!;

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
      const WebsiteStickyStatsColumn(label: Text('Lineup'), width: 300),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 58),
      for (final metric in metrics)
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
          _LineupLink(
            session: widget.session,
            groupName: (row['group_name'] ?? '—').toString(),
            groupId: (row['group_id'] ?? row['GROUP_ID'] ?? '').toString(),
          ),
          _LineupTeamLink(session: widget.session, team: (row['team'] ?? '').toString()),
          for (final metric in metrics)
            Text(_format(_value(row, metric.key), metric), maxLines: 1),
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
          'Compare $_groupQuantity-player units using locally stored NBA.com lineup captures. Historical samples are static, reproducible and independent of live NBA.com requests.',
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
                    key: ValueKey('lineup-season-$_season'),
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
                  width: 126,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('lineup-q-$_groupQuantity'),
                    initialValue: _groupQuantity,
                    decoration: const InputDecoration(labelText: 'Unit size', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5-player')),
                      DropdownMenuItem(value: 4, child: Text('4-player')),
                      DropdownMenuItem(value: 3, child: Text('3-player')),
                      DropdownMenuItem(value: 2, child: Text('2-player')),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _groupQuantity) return;
                      _groupQuantity = value;
                      _reload();
                    },
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() => _page = 1),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search players in lineups',
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('lineup-team-$_team-${teams.length}'),
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
                _IntFilter(
                  label: 'Lineup GP',
                  value: _minGp,
                  options: const [0, 50, 25, 10, 5],
                  suffix: '+',
                  onChanged: (value) => setState(() { _minGp = value; _page = 1; }),
                ),
                _IntFilter(
                  label: 'Minutes',
                  value: _minMinutes,
                  options: const [0, 500, 250, 100, 50, 20],
                  suffix: '+ MIN',
                  onChanged: (value) => setState(() { _minMinutes = value; _page = 1; }),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('lineup-metrics-$_metricGroup'),
                    initialValue: _metricGroup,
                    decoration: const InputDecoration(labelText: 'Metric group', isDense: true),
                    items: [
                      for (final item in _metricGroups.keys)
                        DropdownMenuItem(value: item, child: Text(item)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() { _metricGroup = value; _page = 1; });
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset filters'),
                ),
                OutlinedButton.icon(
                  onPressed: rows.isEmpty ? null : () => _copyCsv(context, rows, metrics),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy CSV'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (sourceRows.isEmpty)
          _NoLineupData(
            season: _season,
            seasonType: _seasonType,
            groupQuantity: _groupQuantity,
          )
        else ...[
          _LineupSummary(rows: rows),
          const SizedBox(height: 14),
          pager(),
          const SizedBox(height: 10),
          WebsiteStickyStatsTable(
            columns: columns,
            rows: tableRows,
            firstColumnWidth: 300,
            headerHeight: 43,
            rowHeight: 42,
          ),
          const SizedBox(height: 10),
          pager(),
        ],
        const SizedBox(height: 18),
        Text(
          'Source: NBA.com LeagueDashLineups captures. Click a lineup to inspect its members; team links open canonical team pages. Five-player captures remain backward compatible, while 2-, 3- and 4-player unit files are materialized separately when available.',
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
    List<Map<String, dynamic>> rows,
    List<_LineupMetric> metrics,
  ) async {
    final lines = <String>[
      _csvLine(['Lineup', 'Team', ...metrics.map((metric) => metric.label)]),
    ];
    for (final row in rows) {
      lines.add(
        _csvLine([
          (row['group_name'] ?? '').toString(),
          (row['team'] ?? '').toString(),
          for (final metric in metrics) _format(_value(row, metric.key), metric),
        ]),
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${rows.length} filtered lineup rows as CSV.')),
    );
  }
}

class _IntFilter extends StatelessWidget {
  const _IntFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final String suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 126,
        child: DropdownButtonFormField<int>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            for (final item in options)
              DropdownMenuItem(
                value: item,
                child: Text(item == 0 ? 'Any' : '$item$suffix'),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

class _LineupLink extends StatelessWidget {
  const _LineupLink({
    required this.session,
    required this.groupName,
    required this.groupId,
  });

  final AppSession session;
  final String groupName;
  final String groupId;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Open lineup members',
        child: InkWell(
          onTap: groupName == '—' || groupName.isEmpty
              ? null
              : () => _openMembers(context, session, groupName, groupId),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new_rounded,
                size: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
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

class _LineupSummary extends StatelessWidget {
  const _LineupSummary({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? maxBy(String key) {
      Map<String, dynamic>? best;
      double? bestValue;
      for (final row in rows) {
        final value = _value(row, key);
        if (value == null) continue;
        if (bestValue == null || value > bestValue) {
          best = row;
          bestValue = value;
        }
      }
      return best;
    }

    Map<String, dynamic>? minBy(String key) {
      Map<String, dynamic>? best;
      double? bestValue;
      for (final row in rows) {
        final value = _value(row, key);
        if (value == null) continue;
        if (bestValue == null || value < bestValue) {
          best = row;
          bestValue = value;
        }
      }
      return best;
    }

    final bestNet = maxBy('net_rating');
    final bestOffense = maxBy('off_rating');
    final bestDefense = minBy('def_rating');
    final cards = [
      _SummaryValue(label: 'Matching units', value: '${rows.length}', detail: 'after filters'),
      _summaryFromRow('Best net rating', bestNet, 'net_rating', signed: true),
      _summaryFromRow('Best offense', bestOffense, 'off_rating'),
      _summaryFromRow('Best defense', bestDefense, 'def_rating'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 30) / 4
            : constraints.maxWidth >= 520
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final item in cards) SizedBox(width: width, child: item)],
        );
      },
    );
  }

  _SummaryValue _summaryFromRow(
    String label,
    Map<String, dynamic>? row,
    String key, {
    bool signed = false,
  }) {
    final value = row == null ? null : _value(row, key);
    final formatted = value == null
        ? '—'
        : signed
            ? '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}'
            : value.toStringAsFixed(1);
    return _SummaryValue(
      label: label,
      value: formatted,
      detail: row == null ? 'No qualifying sample' : (row['group_name'] ?? '').toString(),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 5),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}

class _NoLineupData extends StatelessWidget {
  const _NoLineupData({
    required this.season,
    required this.seasonType,
    required this.groupQuantity,
  });

  final String season;
  final String seasonType;
  final int groupQuantity;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$groupQuantity-player lineup data has not been materialized for this sample yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '$season · ${seasonType == 'playoffs' ? 'Playoffs' : 'Regular Season'} will appear automatically after a local NBA.com LeagueDashLineups capture for GroupQuantity=$groupQuantity is stored and materialized. Sports Terminal will not invent lineup rows to fill the table.',
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
  const _LineupMetric(
    this.key,
    this.label, {
    this.percent = false,
    this.signed = false,
    this.integer = false,
    this.width = 70,
  });

  final String key;
  final String label;
  final bool percent;
  final bool signed;
  final bool integer;
  final double width;
}

const _gp = _LineupMetric('gp', 'GP', integer: true, width: 54);
const _min = _LineupMetric('min', 'MIN', width: 64);
const _poss = _LineupMetric('poss', 'POSS', width: 68);
const _winPct = _LineupMetric('win_pct', 'W%', percent: true, width: 62);
const _ortg = _LineupMetric('off_rating', 'ORtg');
const _drtg = _LineupMetric('def_rating', 'DRtg');
const _net = _LineupMetric('net_rating', 'Net', signed: true);
const _astPct = _LineupMetric('ast_pct', 'AST%', percent: true);
const _astTo = _LineupMetric('ast_to', 'AST:TO');
const _astRatio = _LineupMetric('ast_ratio', 'AST Ratio', width: 78);
const _orebPct = _LineupMetric('oreb_pct', 'ORB%', percent: true);
const _drebPct = _LineupMetric('dreb_pct', 'DRB%', percent: true);
const _rebPct = _LineupMetric('reb_pct', 'REB%', percent: true);
const _tovPct = _LineupMetric('tov_pct', 'TOV%', percent: true);
const _efgPct = _LineupMetric('efg_pct', 'eFG%', percent: true);
const _tsPct = _LineupMetric('ts_pct', 'TS%', percent: true);
const _pace = _LineupMetric('pace', 'Pace');
const _pie = _LineupMetric('pie', 'PIE', percent: true);

const _metricGroups = <String, List<_LineupMetric>>{
  'Overview': [_gp, _min, _poss, _winPct, _ortg, _drtg, _net, _pie],
  'Shooting & Efficiency': [_gp, _min, _efgPct, _tsPct, _ortg, _drtg, _net],
  'Ball Movement': [_gp, _min, _astPct, _astTo, _astRatio, _tovPct, _ortg, _net],
  'Rebounding': [_gp, _min, _orebPct, _drebPct, _rebPct, _net],
  'Tempo & Possessions': [_gp, _min, _poss, _pace, _ortg, _drtg, _net, _pie],
  'All metrics': [
    _gp,
    _min,
    _poss,
    _winPct,
    _ortg,
    _drtg,
    _net,
    _astPct,
    _astTo,
    _astRatio,
    _orebPct,
    _drebPct,
    _rebPct,
    _tovPct,
    _efgPct,
    _tsPct,
    _pace,
    _pie,
  ],
};

double? _value(Map<String, dynamic> row, String key) {
  final direct = _num(row[key]);
  if (direct != null) return direct;
  return _num(row[_sortAlias(key)]);
}

String _sortAlias(String key) => const {
      'gp': 'GP',
      'min': 'MIN',
      'poss': 'POSS',
      'win_pct': 'W_PCT',
      'off_rating': 'OFF_RATING',
      'def_rating': 'DEF_RATING',
      'net_rating': 'NET_RATING',
      'ast_pct': 'AST_PCT',
      'ast_to': 'AST_TO',
      'ast_ratio': 'AST_RATIO',
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

List<String> _memberNames(String groupName) {
  final separator = groupName.contains(' - ') ? RegExp(r'\s+-\s+') : RegExp(r'\s*,\s*');
  final names = groupName
      .split(separator)
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  return names.isEmpty ? [groupName] : names;
}

List<String> _memberIds(String groupId) => groupId
    .split(RegExp(r'[^0-9]+'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

Future<void> _openMembers(
  BuildContext context,
  AppSession session,
  String groupName,
  String groupId,
) async {
  final names = _memberNames(groupName);
  final ids = _memberIds(groupId);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Lineup members'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < names.length; index++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded, size: 19),
                title: Text(names[index]),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  final id = index < ids.length ? ids[index] : names[index];
                  Navigator.of(dialogContext).pop();
                  Future<void>.microtask(
                    () => openWebsiteNbaPlayerPage(
                      context,
                      session: session,
                      playerKey: id,
                      playerName: names[index],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
      ],
    ),
  );
}

String _csvLine(Iterable<String> values) => values.map((value) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }).join(',');
