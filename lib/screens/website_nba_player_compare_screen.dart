import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/website_sticky_stats_table.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaPlayerCompareScreen extends StatefulWidget {
  const WebsiteNbaPlayerCompareScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaPlayerCompareScreen> createState() => _WebsiteNbaPlayerCompareScreenState();
}

class _WebsiteNbaPlayerCompareScreenState extends State<WebsiteNbaPlayerCompareScreen> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();

  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<NbaTerminalSeedSnapshot>? _dataFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  final List<String> _selected = [];
  String _query = '';

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
    _search.clear();
    setState(() {
      _selected.clear();
      _query = '';
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<WebsiteNbaSeason>>(
        future: _seasonsFuture,
        builder: (context, catalog) {
          if (catalog.connectionState != ConnectionState.done) {
            return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
          }
          if (catalog.hasError || _seasons.isEmpty || _dataFuture == null) {
            return _CompareError(
              error: catalog.error,
              onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
            );
          }
          return FutureBuilder<NbaTerminalSeedSnapshot>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _CompareError(error: snapshot.error, onRetry: _reload);
              }
              return _buildPage(context, snapshot.data!);
            },
          );
        },
      );

  Widget _buildPage(BuildContext context, NbaTerminalSeedSnapshot data) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(
      data,
      basis: NbaStatsBasis.perGame,
      seasonType: _seasonType,
    );
    final byId = <String, NbaStatsRow>{for (final row in rows) row.playerId: row};
    final selectedRows = [
      for (final id in _selected)
        if (byId[id] != null) byId[id]!,
    ];
    final query = _query.trim().toLowerCase();
    final suggestions = query.length < 2
        ? const <NbaStatsRow>[]
        : rows
            .where((row) =>
                !_selected.contains(row.playerId) &&
                '${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query))
            .take(10)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Player Compare',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Put up to four players from the same NBA season sample side by side. Every value comes from the same static season corpus used by Stats and Advanced Stats.',
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
                    key: ValueKey('compare-season-$_season'),
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
                  width: 300,
                  child: TextField(
                    controller: _search,
                    enabled: _selected.length < 4,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_search_outlined),
                      hintText: _selected.length >= 4 ? 'Maximum 4 players selected' : 'Search player to add',
                      isDense: true,
                    ),
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      _search.clear();
                      setState(() {
                        _selected.clear();
                        _query = '';
                      });
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear players'),
                  ),
              ],
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SuggestionPanel(
            rows: suggestions,
            onAdd: (row) {
              if (_selected.length >= 4) return;
              _search.clear();
              setState(() {
                _selected.add(row.playerId);
                _query = '';
              });
            },
          ),
        ],
        if (selectedRows.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final row in selectedRows)
                InputChip(
                  avatar: const Icon(Icons.person_outline_rounded, size: 17),
                  label: Text('${row.player} · ${row.team}'),
                  onPressed: () => openWebsiteNbaPlayerPage(
                    context,
                    session: widget.session,
                    playerKey: row.playerId,
                    playerName: row.player,
                  ),
                  onDeleted: () => setState(() => _selected.remove(row.playerId)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        if (selectedRows.isEmpty)
          _EmptyCompare(season: _season, seasonType: _seasonType)
        else
          _ComparisonTable(session: widget.session, rows: selectedRows),
        const SizedBox(height: 18),
        Text(
          'Comparison policy: all selected players use the same season, season type and per-game basis. A dash means that metric is not available for that player in the stored sample; Sports Terminal does not substitute a similarly named metric from another source.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({required this.rows, required this.onAdd});

  final List<NbaStatsRow> rows;
  final ValueChanged<NbaStatsRow> onAdd;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final row in rows)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: Text(row.player, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${row.team} · ${row.position}'),
                  trailing: Text('${_fmt(row.value('pts'))} PPG'),
                  onTap: () => onAdd(row),
                ),
            ],
          ),
        ),
      );
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.session, required this.rows});

  final AppSession session;
  final List<NbaStatsRow> rows;

  @override
  Widget build(BuildContext context) {
    final columns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Metric'), width: 190),
      for (final row in rows)
        WebsiteStickyStatsColumn(
          width: 155,
          numeric: true,
          label: InkWell(
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
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
    ];
    final tableRows = <List<Widget>>[
      for (final metric in _metrics)
        [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (metric.group.isNotEmpty)
                Text(
                  metric.group,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          for (final row in rows)
            Text(_formatMetric(row.value(metric.key), metric), maxLines: 1),
        ],
    ];
    return WebsiteStickyStatsTable(
      columns: columns,
      rows: tableRows,
      firstColumnWidth: 190,
      headerHeight: 44,
      rowHeight: 46,
    );
  }
}

class _EmptyCompare extends StatelessWidget {
  const _EmptyCompare({required this.season, required this.seasonType});

  final String season;
  final NbaStatsSeasonType seasonType;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add players to start comparing',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Search above for players in $season · ${seasonType == NbaStatsSeasonType.playoffs ? 'Playoffs' : 'Regular Season'}. You can compare two, three or four players at once.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

class _CompareError extends StatelessWidget {
  const _CompareError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Player comparison unavailable', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('${error ?? 'Unable to read the selected static NBA season.'}'),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _CompareMetric {
  const _CompareMetric(
    this.key,
    this.label,
    this.group, {
    this.percent = false,
    this.integer = false,
    this.signed = false,
  });

  final String key;
  final String label;
  final String group;
  final bool percent;
  final bool integer;
  final bool signed;
}

const _metrics = <_CompareMetric>[
  _CompareMetric('gp', 'GP', 'Availability', integer: true),
  _CompareMetric('min', 'MPG', 'Traditional'),
  _CompareMetric('pts', 'PPG', 'Traditional'),
  _CompareMetric('reb', 'RPG', 'Traditional'),
  _CompareMetric('ast', 'APG', 'Traditional'),
  _CompareMetric('stl', 'SPG', 'Traditional'),
  _CompareMetric('blk', 'BPG', 'Traditional'),
  _CompareMetric('tov', 'TPG', 'Traditional'),
  _CompareMetric('pf', 'PF', 'Traditional'),
  _CompareMetric('fg_pct', 'FG%', 'Shooting', percent: true),
  _CompareMetric('fg3_pct', '3P%', 'Shooting', percent: true),
  _CompareMetric('ft_pct', 'FT%', 'Shooting', percent: true),
  _CompareMetric('efg_pct', 'eFG%', 'Efficiency', percent: true),
  _CompareMetric('ts_pct', 'TS%', 'Efficiency', percent: true),
  _CompareMetric('usg_pct', 'USG%', 'Role', percent: true),
  _CompareMetric('off_rating', 'ORtg', 'Impact'),
  _CompareMetric('def_rating', 'DRtg', 'Impact'),
  _CompareMetric('net_rating', 'Net Rating', 'Impact', signed: true),
  _CompareMetric('ast_pct', 'AST%', 'Playmaking', percent: true),
  _CompareMetric('reb_pct', 'REB%', 'Rebounding', percent: true),
  _CompareMetric('pie', 'PIE', 'Impact', percent: true),
  _CompareMetric('bpm', 'BPM', 'Aggregate', signed: true),
  _CompareMetric('vorp', 'VORP', 'Aggregate', signed: true),
];

String _formatMetric(double? value, _CompareMetric metric) {
  if (value == null || value.isNaN || value.isInfinite) return '—';
  if (metric.integer) return value.round().toString();
  if (metric.percent) {
    final scaled = value.abs() <= 1.5 ? value * 100 : value;
    return '${scaled.toStringAsFixed(1)}%';
  }
  if (metric.signed) return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  return value.toStringAsFixed(1);
}

String _fmt(double? value) => value == null ? '—' : value.toStringAsFixed(1);
