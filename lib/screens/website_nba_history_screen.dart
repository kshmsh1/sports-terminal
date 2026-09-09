import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/website_pagination.dart';
import '../widgets/website_sticky_stats_table.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaHistoryScreen extends StatefulWidget {
  const WebsiteNbaHistoryScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaHistoryScreen> createState() => _WebsiteNbaHistoryScreenState();
}

class _WebsiteNbaHistoryScreenState extends State<WebsiteNbaHistoryScreen> {
  final _api = const WebsiteNbaApiService();
  final _search = TextEditingController();
  late Future<List<WebsiteNbaSeason>> _future;
  String _era = 'All';
  int _page = 1;
  int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _future = _api.seasons();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<WebsiteNbaSeason>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _HistoryError(
              error: snapshot.error,
              onRetry: () => setState(() => _future = _api.seasons()),
            );
          }
          return _buildPage(context, snapshot.data ?? const []);
        },
      );

  Widget _buildPage(BuildContext context, List<WebsiteNbaSeason> seasons) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final filtered = seasons.where((season) {
      if (query.isNotEmpty &&
          !'${season.id} ${season.label}'.toLowerCase().contains(query)) {
        return false;
      }
      return switch (_era) {
        '2020s' => season.startYear >= 2020,
        '2010s' => season.startYear >= 2010 && season.startYear < 2020,
        '2000s' => season.startYear >= 2000 && season.startYear < 2010,
        '1990s' => season.startYear >= 1990 && season.startYear < 2000,
        '1980s' => season.startYear >= 1980 && season.startYear < 1990,
        '1970s' => season.startYear >= 1970 && season.startYear < 1980,
        '1960s' => season.startYear >= 1960 && season.startYear < 1970,
        '1950s' => season.startYear >= 1950 && season.startYear < 1960,
        '1940s' => season.startYear < 1950,
        _ => true,
      };
    }).toList()
      ..sort((a, b) => b.startYear.compareTo(a.startYear));

    final pageCount = math.max(1, (filtered.length / _pageSize).ceil());
    final safePage = _page.clamp(1, pageCount);
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

    final columns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Season'), width: 190),
      const WebsiteStickyStatsColumn(
        label: Text('Start'),
        width: 70,
        numeric: true,
      ),
      const WebsiteStickyStatsColumn(
        label: Text('Players'),
        width: 82,
        numeric: true,
      ),
      const WebsiteStickyStatsColumn(
        label: Text('Coverage'),
        width: 180,
      ),
    ];
    final tableRows = <List<Widget>>[
      for (final season in paged)
        [
          InkWell(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                settings: RouteSettings(
                  name: '/nba/history/${Uri.encodeComponent(season.id)}',
                ),
                builder: (_) => WebsiteNbaSeasonOverviewPage(
                  session: widget.session,
                  season: season,
                ),
              ),
            ),
            child: Text(
              season.label,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text('${season.startYear}', textAlign: TextAlign.right),
          Text('${season.rowCount}', textAlign: TextAlign.right),
          const Text('Regular + playoffs when source-backed'),
        ],
    ];

    final earliest = seasons.isEmpty
        ? '—'
        : (seasons.toList()..sort((a, b) => a.startYear.compareTo(b.startYear)))
            .first
            .label;
    final latest = seasons.isEmpty
        ? '—'
        : (seasons.toList()..sort((a, b) => b.startYear.compareTo(a.startYear)))
            .first
            .label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NBA History',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Explore the canonical historical season catalog and open a source-backed season workspace without leaving the traditional website.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HistoryKpi(label: 'Seasons', value: '${seasons.length}'),
            _HistoryKpi(label: 'Earliest available', value: earliest),
            _HistoryKpi(label: 'Latest', value: latest),
            const _HistoryKpi(label: 'Historical delivery', value: 'Static'),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() => _page = 1),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search season',
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('history-era-$_era'),
                    initialValue: _era,
                    decoration: const InputDecoration(
                      labelText: 'Era',
                      isDense: true,
                    ),
                    items: const [
                      for (final era in [
                        'All',
                        '2020s',
                        '2010s',
                        '2000s',
                        '1990s',
                        '1980s',
                        '1970s',
                        '1960s',
                        '1950s',
                        '1940s',
                      ])
                        DropdownMenuItem(value: era, child: Text(era)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _era = value;
                          _page = 1;
                        });
                      }
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _search.clear();
                    setState(() {
                      _era = 'All';
                      _page = 1;
                    });
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              '${filtered.length} available seasons',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              'Known source gaps remain explicit rather than synthesized',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        pager(),
        const SizedBox(height: 10),
        WebsiteStickyStatsTable(
          columns: columns,
          rows: tableRows,
          firstColumnWidth: 190,
          headerHeight: 43,
          rowHeight: 44,
        ),
        const SizedBox(height: 10),
        pager(),
      ],
    );
  }
}

class WebsiteNbaSeasonOverviewPage extends StatefulWidget {
  const WebsiteNbaSeasonOverviewPage({
    super.key,
    required this.session,
    required this.season,
  });

  final AppSession session;
  final WebsiteNbaSeason season;

  @override
  State<WebsiteNbaSeasonOverviewPage> createState() =>
      _WebsiteNbaSeasonOverviewPageState();
}

class _WebsiteNbaSeasonOverviewPageState
    extends State<WebsiteNbaSeasonOverviewPage> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  String _seasonType = 'regular';
  String _metric = 'pts';
  late Future<NbaTerminalSeedSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<NbaTerminalSeedSnapshot> _load() => _api.seasonSnapshot(
        widget.season.id,
        seasonType: _seasonType,
      );

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sports Terminal · ${widget.season.label}')),
      body: FutureBuilder<NbaTerminalSeedSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: _HistoryError(error: snapshot.error, onRetry: _reload),
            );
          }
          return _buildSeason(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildSeason(BuildContext context, NbaTerminalSeedSnapshot snapshot) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(
      snapshot,
      basis: NbaStatsBasis.perGame,
      seasonType: _seasonType == 'playoffs'
          ? NbaStatsSeasonType.playoffs
          : NbaStatsSeasonType.regular,
    );
    rows.sort((a, b) {
      final left = a.value(_metric);
      final right = b.value(_metric);
      if (left == null && right == null) return a.player.compareTo(b.player);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    final top = rows.take(25).toList();
    final metricLabel = _seasonMetrics[_metric] ?? _metric.toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1450),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.season.label,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Canonical season overview · source-backed player leaders and historical context.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
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
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('season-metric-$_metric'),
                      initialValue: _metric,
                      decoration: const InputDecoration(
                        labelText: 'Leaderboard',
                        isDense: true,
                      ),
                      items: [
                        for (final entry in _seasonMetrics.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _metric = value);
                      },
                    ),
                  ),
                  _HistoryKpi(label: 'Players', value: '${rows.length}'),
                  _HistoryKpi(
                    label: 'Catalog players',
                    value: '${widget.season.rowCount}',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '$metricLabel leaders',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              _SeasonLeaderTable(
                rows: top,
                metric: _metric,
                metricLabel: metricLabel,
                session: widget.session,
              ),
              const SizedBox(height: 14),
              Text(
                'For full sortable columns, qualification filters, advanced metric groups and CSV export, use the main Stats and Advanced Stats pages. This page is the compact historical season entry point.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonLeaderTable extends StatelessWidget {
  const _SeasonLeaderTable({
    required this.rows,
    required this.metric,
    required this.metricLabel,
    required this.session,
  });

  final List<NbaStatsRow> rows;
  final String metric;
  final String metricLabel;
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Player'), width: 190),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 72),
      const WebsiteStickyStatsColumn(label: Text('Pos'), width: 58),
      const WebsiteStickyStatsColumn(label: Text('GP'), width: 58, numeric: true),
      WebsiteStickyStatsColumn(
        label: Text(metricLabel),
        width: 82,
        numeric: true,
      ),
    ];
    final tableRows = <List<Widget>>[
      for (final row in rows)
        [
          InkWell(
            onTap: () => openWebsiteNbaPlayerPage(
              context,
              session: session,
              playerKey: row.playerId,
              playerName: row.player,
            ),
            child: Text(
              row.player,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(row.team, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(row.position, maxLines: 1),
          Text(_formatNumber(row.value('gp'), 'gp'), textAlign: TextAlign.right),
          Text(_formatNumber(row.value(metric), metric), textAlign: TextAlign.right),
        ],
    ];
    return WebsiteStickyStatsTable(
      columns: columns,
      rows: tableRows,
      firstColumnWidth: 190,
      headerHeight: 43,
      rowHeight: 43,
    );
  }
}

class _HistoryKpi extends StatelessWidget {
  const _HistoryKpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 185,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.error, required this.onRetry});
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
                'NBA history unavailable',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text('${error ?? 'Static historical season data could not be read.'}'),
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

const _seasonMetrics = <String, String>{
  'pts': 'PPG',
  'reb': 'RPG',
  'ast': 'APG',
  'stl': 'SPG',
  'blk': 'BPG',
  'min': 'MPG',
  'fg_pct': 'FG%',
  'three_pct': '3P%',
  'ft_pct': 'FT%',
};

String _formatNumber(num? value, String metric) {
  if (value == null) return '—';
  if (metric == 'gp') return value.round().toString();
  if (metric.endsWith('_pct') || metric == 'three_pct') {
    final scaled = value.abs() <= 1.01 ? value * 100 : value;
    return '${scaled.toStringAsFixed(1)}%';
  }
  return value.toStringAsFixed(1);
}
