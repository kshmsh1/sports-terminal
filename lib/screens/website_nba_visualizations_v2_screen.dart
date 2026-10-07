import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/website_nba_api_service.dart';

enum _ChartType {
  scatter('Scatter'),
  bubble('Bubble'),
  bar('Player ranking'),
  histogram('Distribution'),
  radar('Player profile');

  const _ChartType(this.label);
  final String label;
}

class WebsiteNbaVisualizationsScreen extends StatefulWidget {
  const WebsiteNbaVisualizationsScreen({super.key});

  @override
  State<WebsiteNbaVisualizationsScreen> createState() =>
      _WebsiteNbaVisualizationsScreenState();
}

class _WebsiteNbaVisualizationsScreenState
    extends State<WebsiteNbaVisualizationsScreen> {
  static const _savedKey = 'nba_visualization_presets_v1';
  static const _maxSaved = 10;

  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();
  final List<_SavedVisualization> _saved = [];

  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  _ChartType _chart = _ChartType.scatter;
  String _xMetric = 'ast';
  String _yMetric = 'pts';
  String _sizeMetric = 'reb';
  String _groupBy = 'Team';
  double _minGames = 20;
  int _topN = 40;
  bool _showLabels = true;
  bool _showTrendLine = true;
  bool _showMeans = false;
  String? _radarPlayer;
  String? _activePresetId;
  late Future<List<NbaStatsRow>> _future;

  static const _metricKeys = <String>[
    'gp',
    'min',
    'pts',
    'reb',
    'ast',
    'stl',
    'blk',
    'tov',
    'fg_pct',
    'three_pm',
    'three_pa',
    'three_pct',
    'ft_pct',
    'ts_pct',
    'efg_pct',
    'plus_minus',
    'bpm',
    'game_score_proxy',
  ];

  @override
  void initState() {
    super.initState();
    _future = _initialize();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<NbaStatsRow>> _initialize() async {
    _seasons = await _api.seasons();
    if (_seasons.isNotEmpty && !_seasons.any((item) => item.id == _season)) {
      _season = _seasons.first.id;
    }
    await _loadSaved();
    return _loadRows();
  }

  Future<List<NbaStatsRow>> _loadRows() async {
    final snapshot = await _api.seasonSnapshot(
      _season,
      seasonType:
          _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
    );
    return _engine.buildRows(
      snapshot,
      basis: _basis,
      seasonType: _seasonType,
    );
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _saved
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map(
                (item) => _SavedVisualization.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              ),
        );
    } catch (_) {
      // Local visualization presets are convenience state only.
    }
  }

  Future<void> _persistSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedKey,
      jsonEncode([for (final item in _saved) item.toJson()]),
    );
  }

  void _reload() => setState(() => _future = _loadRows());

  bool get _supportsXYAnalytics =>
      _chart == _ChartType.scatter || _chart == _ChartType.bubble;

  void _resetStudio() {
    setState(() {
      _season = _seasons.any((item) => item.id == '2025-26')
          ? '2025-26'
          : (_seasons.isEmpty ? _season : _seasons.first.id);
      _seasonType = NbaStatsSeasonType.regular;
      _basis = NbaStatsBasis.perGame;
      _chart = _ChartType.scatter;
      _xMetric = 'ast';
      _yMetric = 'pts';
      _sizeMetric = 'reb';
      _groupBy = 'Team';
      _minGames = 20;
      _topN = 40;
      _showLabels = true;
      _showTrendLine = true;
      _showMeans = false;
      _radarPlayer = null;
      _search.clear();
      _activePresetId = null;
      _future = _loadRows();
    });
  }

  _SavedVisualization _capture({required String id, required String name}) =>
      _SavedVisualization(
        id: id,
        name: name,
        season: _season,
        seasonType: _seasonType.name,
        basis: _basis.name,
        chart: _chart.name,
        xMetric: _xMetric,
        yMetric: _yMetric,
        sizeMetric: _sizeMetric,
        groupBy: _groupBy,
        minGames: _minGames,
        topN: _topN,
        showLabels: _showLabels,
        showTrendLine: _showTrendLine,
        showMeans: _showMeans,
        search: _search.text,
      );

  Future<void> _savePreset({bool saveAs = false}) async {
    if (!saveAs && _activePresetId != null) {
      final index = _saved.indexWhere((item) => item.id == _activePresetId);
      if (index >= 0) {
        _saved[index] = _capture(id: _saved[index].id, name: _saved[index].name);
        await _persistSaved();
        if (mounted) setState(() {});
        return;
      }
    }
    if (_saved.length >= _maxSaved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can save up to 10 visualization presets.')),
      );
      return;
    }
    final controller = TextEditingController(
      text: '${_chart.label}: ${_engine.metric(_yMetric).shortLabel}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save visualization preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Preset name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _saved.add(_capture(id: id, name: name.trim()));
    _activePresetId = id;
    await _persistSaved();
    if (mounted) setState(() {});
  }

  void _applyPreset(_SavedVisualization preset) {
    setState(() {
      _season = _seasons.any((item) => item.id == preset.season)
          ? preset.season
          : (_seasons.isEmpty ? _season : _seasons.first.id);
      _seasonType = NbaStatsSeasonType.values.firstWhere(
        (value) => value.name == preset.seasonType,
        orElse: () => NbaStatsSeasonType.regular,
      );
      _basis = NbaStatsBasis.values.firstWhere(
        (value) => value.name == preset.basis,
        orElse: () => NbaStatsBasis.perGame,
      );
      _chart = _ChartType.values.firstWhere(
        (value) => value.name == preset.chart,
        orElse: () => _ChartType.scatter,
      );
      _xMetric = _metricKeys.contains(preset.xMetric) ? preset.xMetric : 'ast';
      _yMetric = _metricKeys.contains(preset.yMetric) ? preset.yMetric : 'pts';
      _sizeMetric = _metricKeys.contains(preset.sizeMetric) ? preset.sizeMetric : 'reb';
      _groupBy = const ['Team', 'Position', 'None'].contains(preset.groupBy)
          ? preset.groupBy
          : 'Team';
      _minGames = preset.minGames.clamp(0, 82).toDouble();
      _topN = const [10, 20, 30, 40, 60, 100].contains(preset.topN) ? preset.topN : 40;
      _showLabels = preset.showLabels;
      _showTrendLine = preset.showTrendLine;
      _showMeans = preset.showMeans;
      _search.text = preset.search;
      _activePresetId = preset.id;
      _future = _loadRows();
    });
  }

  Future<void> _deletePreset(_SavedVisualization preset) async {
    _saved.removeWhere((item) => item.id == preset.id);
    if (_activePresetId == preset.id) _activePresetId = null;
    await _persistSaved();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NbaStatsRow>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 520,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Text('Visualization data unavailable: ${snapshot.error}'),
            ),
          );
        }
        return _buildPage(context, snapshot.data!);
      },
    );
  }

  Widget _buildPage(BuildContext context, List<NbaStatsRow> allRows) {
    final query = _search.text.trim().toLowerCase();
    final filtered = allRows.where((row) {
      if ((row.value('gp') ?? 0) < _minGames) return false;
      if (query.isNotEmpty &&
          !'${row.player} ${row.team} ${row.position}'
              .toLowerCase()
              .contains(query)) {
        return false;
      }
      return row.value(_yMetric) != null;
    }).toList(growable: false);

    final ranked = [...filtered]
      ..sort(
        (a, b) => (b.value(_yMetric) ?? -99999)
            .compareTo(a.value(_yMetric) ?? -99999),
      );

    final radarName = _radarPlayer != null &&
            ranked.any((row) => row.player == _radarPlayer)
        ? _radarPlayer
        : (ranked.isEmpty ? null : ranked.first.player);

    final rows = switch (_chart) {
      _ChartType.histogram => filtered,
      _ChartType.radar => radarName == null
          ? <NbaStatsRow>[]
          : ranked.where((row) => row.player == radarName).take(1).toList(),
      _ => ranked.take(_topN).toList(growable: false),
    };

    final analytics = _supportsXYAnalytics
        ? _RegressionSummary.fromRows(rows, _xMetric, _yMetric)
        : null;
    final colors = Theme.of(context).colorScheme;
    final metricLabel = _engine.metric(_yMetric).shortLabel;
    final xLabel = _engine.metric(_xMetric).shortLabel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        final header = _buildStudioHeader(
          context,
          colors,
          plotted: rows.length,
          eligible: filtered.length,
        );
        final controls = _buildControlRail(
          context,
          allRows: allRows,
          filtered: ranked,
          radarName: radarName,
        );
        final workspace = _buildWorkspace(
          context,
          rows: rows,
          analytics: analytics,
          metricLabel: metricLabel,
          xLabel: xLabel,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 18),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 314, child: controls),
                  const SizedBox(width: 16),
                  Expanded(child: workspace),
                ],
              )
            else ...[
              controls,
              const SizedBox(height: 16),
              workspace,
            ],
          ],
        );
      },
    );
  }

  Widget _buildStudioHeader(
    BuildContext context,
    ColorScheme colors, {
    required int plotted,
    required int eligible,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Visualization Studio',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.7,
                      ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message:
                      'Built from the same static player-season dataset used by Stats and Advanced Stats.',
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Explore relationships, rankings, distributions, and player profiles without leaving the Terminal.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        );

        final contextChips = Wrap(
          spacing: 7,
          runSpacing: 7,
          alignment: WrapAlignment.end,
          children: [
            _StudioContextChip(
              icon: Icons.calendar_month_outlined,
              label: _season,
            ),
            _StudioContextChip(
              icon: Icons.layers_outlined,
              label: _seasonType == NbaStatsSeasonType.playoffs
                  ? 'Playoffs'
                  : 'Regular Season',
            ),
            _StudioContextChip(
              icon: Icons.speed_outlined,
              label: _basis.label,
            ),
            _StudioContextChip(
              icon: Icons.groups_outlined,
              label: '$plotted plotted · $eligible eligible',
            ),
          ],
        );

        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              contextChips,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            Flexible(child: contextChips),
          ],
        );
      },
    );
  }

  Widget _buildControlRail(
    BuildContext context, {
    required List<NbaStatsRow> allRows,
    required List<NbaStatsRow> filtered,
    required String? radarName,
  }) {
    final colors = Theme.of(context).colorScheme;
    final playerNames = filtered
        .map((row) => row.player)
        .toSet()
        .take(120)
        .toList(growable: false);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'BUILD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetStudio,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const _StudioSectionTitle('DATASET'),
            _StudioSelect<String>(
              label: 'Season',
              value: _season,
              items: [
                for (final season in _seasons)
                  DropdownMenuItem(
                    value: season.id,
                    child: Text(season.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _season = value;
                _radarPlayer = null;
                _reload();
              },
            ),
            const SizedBox(height: 10),
            _StudioSelect<NbaStatsSeasonType>(
              label: 'Segment',
              value: _seasonType,
              items: const [
                DropdownMenuItem(
                  value: NbaStatsSeasonType.regular,
                  child: Text('Regular Season'),
                ),
                DropdownMenuItem(
                  value: NbaStatsSeasonType.playoffs,
                  child: Text('Playoffs'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _seasonType = value;
                _radarPlayer = null;
                _reload();
              },
            ),
            const SizedBox(height: 10),
            _StudioSelect<NbaStatsBasis>(
              label: 'Rate',
              value: _basis,
              items: [
                for (final basis in const [
                  NbaStatsBasis.perGame,
                  NbaStatsBasis.per36,
                  NbaStatsBasis.per75,
                  NbaStatsBasis.per100,
                  NbaStatsBasis.totals,
                ])
                  DropdownMenuItem(
                    value: basis,
                    child: Text(basis.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _basis = value;
                _reload();
              },
            ),
            const _StudioSectionDivider(),
            const _StudioSectionTitle('VISUAL'),
            _StudioSelect<_ChartType>(
              label: 'Chart',
              value: _chart,
              items: [
                for (final type in _ChartType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _chart = value;
                    if (_chart == _ChartType.radar) {
                      _showTrendLine = false;
                    }
                  });
                }
              },
            ),
            if (_chart == _ChartType.radar) ...[
              const SizedBox(height: 10),
              _StudioSelect<String>(
                label: 'Player',
                value: radarName,
                items: [
                  for (final player in playerNames)
                    DropdownMenuItem(
                      value: player,
                      child: Text(
                        player,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _radarPlayer = value),
              ),
            ] else ...[
              if (_supportsXYAnalytics) ...[
                const SizedBox(height: 10),
                _StudioMetricSelect(
                  label: 'X axis',
                  value: _xMetric,
                  keys: _metricKeys,
                  engine: _engine,
                  onChanged: (value) => setState(() => _xMetric = value),
                ),
              ],
              const SizedBox(height: 10),
              _StudioMetricSelect(
                label: _chart == _ChartType.histogram
                    ? 'Distribution metric'
                    : 'Y axis / ranking metric',
                value: _yMetric,
                keys: _metricKeys,
                engine: _engine,
                onChanged: (value) => setState(() => _yMetric = value),
              ),
              if (_chart == _ChartType.bubble) ...[
                const SizedBox(height: 10),
                _StudioMetricSelect(
                  label: 'Bubble size',
                  value: _sizeMetric,
                  keys: _metricKeys,
                  engine: _engine,
                  onChanged: (value) => setState(() => _sizeMetric = value),
                ),
              ],
              if (_chart != _ChartType.histogram) ...[
                const SizedBox(height: 10),
                _StudioSelect<String>(
                  label: 'Color by',
                  value: _groupBy,
                  items: const [
                    DropdownMenuItem(value: 'Team', child: Text('Team')),
                    DropdownMenuItem(
                      value: 'Position',
                      child: Text('Position'),
                    ),
                    DropdownMenuItem(value: 'None', child: Text('Single color')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _groupBy = value);
                  },
                ),
              ],
            ],
            const _StudioSectionDivider(),
            const _StudioSectionTitle('POPULATION'),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 19),
                hintText: 'Player, team, position…',
                labelText: 'Filter',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Minimum games',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${_minGames.round()}',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Slider(
              value: _minGames,
              min: 0,
              max: 82,
              divisions: 82,
              onChanged: (value) => setState(() => _minGames = value),
            ),
            if (_chart != _ChartType.histogram &&
                _chart != _ChartType.radar)
              _StudioSelect<int>(
                label: 'Population size',
                value: _topN,
                items: const [10, 20, 30, 40, 60, 100]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('Top $value by selected metric'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _topN = value);
                },
              ),
            const _StudioSectionDivider(),
            const _StudioSectionTitle('DISPLAY'),
            if (_chart != _ChartType.histogram)
              _StudioToggle(
                label: 'Player labels',
                value: _showLabels,
                onChanged: (value) => setState(() => _showLabels = value),
              ),
            if (_supportsXYAnalytics)
              _StudioToggle(
                label: 'Best-fit line',
                value: _showTrendLine,
                onChanged: (value) =>
                    setState(() => _showTrendLine = value),
              ),
            if (_supportsXYAnalytics)
              _StudioToggle(
                label: 'Mean reference lines',
                value: _showMeans,
                onChanged: (value) => setState(() => _showMeans = value),
              ),
            const _StudioSectionDivider(),
            const _StudioSectionTitle('PRESETS'),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _savePreset(),
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _savePreset(saveAs: true),
                    icon: const Icon(Icons.save_as_outlined, size: 17),
                    label: const Text('Save as'),
                  ),
                ),
              ],
            ),
            if (_saved.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in _saved)
                    InputChip(
                      selected: preset.id == _activePresetId,
                      label: Text(
                        preset.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _applyPreset(preset),
                      onDeleted: () => _deletePreset(preset),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required List<NbaStatsRow> rows,
    required _RegressionSummary? analytics,
    required String metricLabel,
    required String xLabel,
  }) {
    final colors = Theme.of(context).colorScheme;
    final top = rows.isEmpty ? null : rows.first;
    final chartTitle = switch (_chart) {
      _ChartType.scatter => '$metricLabel vs $xLabel',
      _ChartType.bubble => '$metricLabel vs $xLabel · bubble size ${_engine.metric(_sizeMetric).shortLabel}',
      _ChartType.bar => '$metricLabel player ranking',
      _ChartType.histogram => '$metricLabel distribution',
      _ChartType.radar => top == null ? 'Player profile' : '${top.player} profile',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chartTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _chart == _ChartType.histogram
                          ? 'Filtered population · ${rows.length} players'
                          : _chart == _ChartType.radar
                              ? 'Percentile profile across six core metrics'
                              : 'Top ${rows.length} by $metricLabel after filters',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (_supportsXYAnalytics)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            final oldX = _xMetric;
                            _xMetric = _yMetric;
                            _yMetric = oldX;
                          });
                        },
                        icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                        label: const Text('Swap axes'),
                      ),
                    _StudioContextChip(
                      icon: Icons.palette_outlined,
                      label: _groupBy == 'None'
                          ? 'Single color'
                          : 'Color: $_groupBy',
                    ),
                  ],
                );
                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 10),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (analytics != null && analytics.count >= 2) ...[
          _StudioAnalyticsBar(
            summary: analytics,
            xLabel: xLabel,
            yLabel: metricLabel,
          ),
          const SizedBox(height: 10),
        ] else if (top != null) ...[
          _NonRegressionInsightBar(
            player: top,
            metricLabel: metricLabel,
            metricValue: _engine.formatValue(
              _yMetric,
              top.value(_yMetric),
            ),
            count: rows.length,
          ),
          const SizedBox(height: 10),
        ],
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = (constraints.maxWidth * .52)
                  .clamp(500.0, 720.0)
                  .toDouble();
              return Column(
                children: [
                  SizedBox(
                    height: height,
                    child: rows.isEmpty
                        ? const Center(
                            child: Text(
                              'No players match the active filters.',
                            ),
                          )
                        : _InteractiveChartPanel(
                            rows: rows,
                            chart: _chart,
                            xMetric: _xMetric,
                            yMetric: _yMetric,
                            sizeMetric: _sizeMetric,
                            groupBy: _groupBy,
                            engine: _engine,
                            colorScheme: colors,
                            textStyle:
                                Theme.of(context).textTheme.bodySmall ??
                                    const TextStyle(),
                            showLabels: _showLabels,
                            showTrendLine: _showTrendLine,
                            showMeans: _showMeans,
                          ),
                  ),
                  if (rows.isNotEmpty && _groupBy != 'None') ...[
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    _ChartLegend(
                      rows: rows,
                      groupBy: _groupBy,
                      colorScheme: colors,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _ChartReadout(
          rows: rows.take(15).toList(growable: false),
          xMetric: _xMetric,
          yMetric: _yMetric,
          engine: _engine,
        ),
      ],
    );
  }

}

class _StudioContextChip extends StatelessWidget {
  const _StudioContextChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioSectionTitle extends StatelessWidget {
  const _StudioSectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
      );
}

class _StudioSectionDivider extends StatelessWidget {
  const _StudioSectionDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Divider(height: 1, color: Theme.of(context).dividerColor),
      );
}

class _StudioSelect<T> extends StatelessWidget {
  const _StudioSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isDense: true,
            isExpanded: true,
            menuMaxHeight: 420,
          ),
        ),
      );
}

class _StudioMetricSelect extends StatelessWidget {
  const _StudioMetricSelect({
    required this.label,
    required this.value,
    required this.keys,
    required this.engine,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> keys;
  final NbaStatsWorkstationEngine engine;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _StudioSelect<String>(
        label: label,
        value: value,
        items: [
          for (final key in keys)
            DropdownMenuItem(
              value: key,
              child: Text(engine.metric(key).shortLabel),
            ),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      );
}

class _StudioToggle extends StatelessWidget {
  const _StudioToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioAnalyticsBar extends StatelessWidget {
  const _StudioAnalyticsBar({
    required this.summary,
    required this.xLabel,
    required this.yLabel,
  });

  final _RegressionSummary summary;
  final String xLabel;
  final String yLabel;

  @override
  Widget build(BuildContext context) {
    final sign = summary.intercept < 0 ? '−' : '+';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InsightTile(
          label: 'PAIRED',
          value: '${summary.count}',
          caption: 'players',
        ),
        _InsightTile(
          label: 'CORRELATION',
          value: summary.r.toStringAsFixed(3),
          caption: _correlationLabel(summary.r),
        ),
        _InsightTile(
          label: 'R²',
          value: summary.rSquared.toStringAsFixed(3),
          caption: 'variance explained',
        ),
        _InsightTile(
          label: 'BEST FIT',
          value:
              '$yLabel = ${summary.slope.toStringAsFixed(2)}×$xLabel $sign ${summary.intercept.abs().toStringAsFixed(2)}',
          caption: 'linear model',
          wide: true,
        ),
      ],
    );
  }

  static String _correlationLabel(double r) {
    final value = r.abs();
    if (value >= .7) return 'strong ${r >= 0 ? 'positive' : 'negative'}';
    if (value >= .4) return 'moderate ${r >= 0 ? 'positive' : 'negative'}';
    if (value >= .2) return 'weak ${r >= 0 ? 'positive' : 'negative'}';
    return 'little linear relationship';
  }
}

class _NonRegressionInsightBar extends StatelessWidget {
  const _NonRegressionInsightBar({
    required this.player,
    required this.metricLabel,
    required this.metricValue,
    required this.count,
  });

  final NbaStatsRow player;
  final String metricLabel;
  final String metricValue;
  final int count;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InsightTile(
            label: 'VISIBLE',
            value: '$count',
            caption: count == 1 ? 'player' : 'players',
          ),
          _InsightTile(
            label: 'LEADER / FOCUS',
            value: player.player,
            caption: '${player.team} · ${player.position}',
            wide: true,
          ),
          _InsightTile(
            label: metricLabel.toUpperCase(),
            value: metricValue,
            caption: 'selected metric',
          ),
        ],
      );
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.label,
    required this.value,
    required this.caption,
    this.wide = false,
  });

  final String label;
  final String value;
  final String caption;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(
        minWidth: wide ? 250 : 122,
        maxWidth: wide ? 420 : 190,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .55,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.rows,
    required this.groupBy,
    required this.colorScheme,
  });

  final List<NbaStatsRow> rows;
  final String groupBy;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final tokens = <String>[];
    for (final row in rows) {
      final token = groupBy == 'Position' ? row.position : row.team;
      if (token.isNotEmpty && !tokens.contains(token)) tokens.add(token);
    }
    final visible = tokens.take(12).toList(growable: false);
    final hidden = tokens.length - visible.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
      child: Wrap(
        spacing: 13,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            groupBy.toUpperCase(),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .65,
            ),
          ),
          for (final token in visible)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _visualGroupColor(token, colorScheme),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  token,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          if (hidden > 0)
            Text(
              '+$hidden more',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartReadout extends StatelessWidget {
  const _ChartReadout({
    required this.rows,
    required this.xMetric,
    required this.yMetric,
    required this.engine,
  });

  final List<NbaStatsRow> rows;
  final String xMetric;
  final String yMetric;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Player')),
              const DataColumn(label: Text('Team')),
              DataColumn(
                numeric: true,
                label: Text(engine.metric(xMetric).shortLabel),
              ),
              DataColumn(
                numeric: true,
                label: Text(engine.metric(yMetric).shortLabel),
              ),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.player)),
                    DataCell(Text(row.team)),
                    DataCell(
                      Text(engine.formatValue(xMetric, row.value(xMetric))),
                    ),
                    DataCell(
                      Text(engine.formatValue(yMetric, row.value(yMetric))),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
}

class _NbaChartPainter extends CustomPainter {
  const _NbaChartPainter({
    required this.rows,
    required this.chart,
    required this.xMetric,
    required this.yMetric,
    required this.sizeMetric,
    required this.groupBy,
    required this.engine,
    required this.colorScheme,
    required this.textStyle,
    required this.showLabels,
    required this.showTrendLine,
    required this.showMeans,
  });

  final List<NbaStatsRow> rows;
  final _ChartType chart;
  final String xMetric;
  final String yMetric;
  final String sizeMetric;
  final String groupBy;
  final NbaStatsWorkstationEngine engine;
  final ColorScheme colorScheme;
  final TextStyle textStyle;
  final bool showLabels;
  final bool showTrendLine;
  final bool showMeans;

  bool get _xy =>
      chart == _ChartType.scatter ||
      chart == _ChartType.bubble ||
      chart == _ChartType.line ||
      chart == _ChartType.area;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      62,
      20,
      math.max(10.0, size.width - 88),
      math.max(10.0, size.height - 72),
    );
    final axisPaint = Paint()
      ..strokeWidth = 1.2
      ..color = colorScheme.outlineVariant;
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, axisPaint);
    canvas.drawLine(rect.bottomLeft, rect.topLeft, axisPaint);

    switch (chart) {
      case _ChartType.bar:
        _paintBars(canvas, rect);
      case _ChartType.pie:
        _paintPie(canvas, rect);
      case _ChartType.histogram:
        _paintHistogram(canvas, rect);
      case _ChartType.radar:
        _paintRadar(canvas, rect);
      case _ChartType.line:
        _paintXY(canvas, rect, connect: true, fill: false, bubbles: false);
      case _ChartType.area:
        _paintXY(canvas, rect, connect: true, fill: true, bubbles: false);
      case _ChartType.bubble:
        _paintXY(canvas, rect, connect: false, fill: false, bubbles: true);
      case _ChartType.scatter:
        _paintXY(canvas, rect, connect: false, fill: false, bubbles: false);
    }

    _text(
      canvas,
      engine.metric(yMetric).shortLabel,
      Offset(8, rect.top + 4),
      colorScheme.onSurfaceVariant,
      bold: true,
    );
    if (_xy) {
      _text(
        canvas,
        engine.metric(xMetric).shortLabel,
        Offset(rect.right - 42, rect.bottom + 20),
        colorScheme.onSurfaceVariant,
        bold: true,
      );
    }
  }

  void _paintXY(
    Canvas canvas,
    Rect rect, {
    required bool connect,
    required bool fill,
    required bool bubbles,
  }) {
    final valid = rows
        .where(
          (row) => row.value(xMetric) != null && row.value(yMetric) != null,
        )
        .toList();
    if (valid.isEmpty) return;
    valid.sort((a, b) => a.value(xMetric)!.compareTo(b.value(xMetric)!));
    final xs = valid.map((row) => row.value(xMetric)!).toList();
    final ys = valid.map((row) => row.value(yMetric)!).toList();
    final xMin = xs.reduce(math.min);
    final xMax = xs.reduce(math.max);
    final yMin = ys.reduce(math.min);
    final yMax = ys.reduce(math.max);
    final points = <Offset>[];

    if (showMeans && valid.length > 1) {
      final meanX = xs.reduce((a, b) => a + b) / xs.length;
      final meanY = ys.reduce((a, b) => a + b) / ys.length;
      final meanPaint = Paint()
        ..color = colorScheme.outline.withValues(alpha: .7)
        ..strokeWidth = 1;
      final x = _scale(meanX, xMin, xMax, rect.left, rect.right);
      final y = _scale(meanY, yMin, yMax, rect.bottom, rect.top);
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), meanPaint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), meanPaint);
    }

    for (var index = 0; index < valid.length; index++) {
      final row = valid[index];
      final point = Offset(
        _scale(row.value(xMetric)!, xMin, xMax, rect.left, rect.right),
        _scale(row.value(yMetric)!, yMin, yMax, rect.bottom, rect.top),
      );
      points.add(point);
      final color = _colorFor(row, index);
      final radius = bubbles
          ? _bubbleRadius(
              row.value(sizeMetric),
              valid
                  .map((item) => item.value(sizeMetric))
                  .whereType<double>()
                  .toList(),
            )
          : 4.5;
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = color.withValues(alpha: .82),
      );
      if (showLabels && (valid.length <= 24 || index < 12)) {
        _text(
          canvas,
          _shortLabel(row.player),
          point + const Offset(6, -11),
          colorScheme.onSurface,
          small: true,
        );
      }
    }

    if (showTrendLine && valid.length > 1) {
      final summary = _RegressionSummary.fromRows(valid, xMetric, yMetric);
      if (summary.count >= 2 && summary.slope.isFinite) {
        final yAtMin = summary.intercept + summary.slope * xMin;
        final yAtMax = summary.intercept + summary.slope * xMax;
        canvas.drawLine(
          Offset(
            rect.left,
            _scale(yAtMin, yMin, yMax, rect.bottom, rect.top),
          ),
          Offset(
            rect.right,
            _scale(yAtMax, yMin, yMax, rect.bottom, rect.top),
          ),
          Paint()
            ..color = colorScheme.tertiary
            ..strokeWidth = 2.2,
        );
      }
    }

    if (connect && points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (fill) {
        final area = Path.from(path)
          ..lineTo(points.last.dx, rect.bottom)
          ..lineTo(points.first.dx, rect.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()..color = colorScheme.primary.withValues(alpha: .14),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colorScheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _paintBars(Canvas canvas, Rect rect) {
    final valid = rows
        .where((row) => row.value(yMetric) != null)
        .take(16)
        .toList();
    if (valid.isEmpty) return;
    final maxValue = valid
        .map((row) => row.value(yMetric)!.abs())
        .fold<double>(0, math.max);
    final width = rect.width / valid.length;
    for (var index = 0; index < valid.length; index++) {
      final value = valid[index].value(yMetric)!;
      final height = maxValue <= 0
          ? 0.0
          : rect.height * .82 * (value.abs() / maxValue);
      final bar = Rect.fromLTWH(
        rect.left + index * width + width * .14,
        rect.bottom - height,
        width * .72,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(4)),
        Paint()
          ..color = _colorFor(valid[index], index).withValues(alpha: .86),
      );
      if (showLabels) {
        _text(
          canvas,
          _shortLabel(valid[index].player),
          Offset(bar.left, rect.bottom + 8),
          colorScheme.onSurfaceVariant,
          small: true,
        );
      }
    }
  }

  void _paintPie(Canvas canvas, Rect rect) {
    final valid = rows
        .where((row) => (row.value(yMetric) ?? 0) > 0)
        .take(10)
        .toList();
    if (valid.isEmpty) return;
    final total = valid.fold<double>(
      0,
      (sum, row) => sum + row.value(yMetric)!,
    );
    final radius = math.min(rect.width, rect.height) * .34;
    final center = Offset(rect.center.dx - rect.width * .12, rect.center.dy);
    var start = -math.pi / 2;
    for (var index = 0; index < valid.length; index++) {
      final sweep = total <= 0
          ? 0.0
          : valid[index].value(yMetric)! / total * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = _colorFor(valid[index], index),
      );
      start += sweep;
      if (showLabels) {
        final legendY = rect.top + index * 22.0;
        canvas.drawRect(
          Rect.fromLTWH(rect.right - 170, legendY, 12, 12),
          Paint()..color = _colorFor(valid[index], index),
        );
        _text(
          canvas,
          '${_shortLabel(valid[index].player)} ${engine.formatValue(yMetric, valid[index].value(yMetric))}',
          Offset(rect.right - 152, legendY - 2),
          colorScheme.onSurface,
          small: true,
        );
      }
    }
  }

  void _paintHistogram(Canvas canvas, Rect rect) {
    final values = rows
        .map((row) => row.value(yMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    const bins = 10;
    final counts = List<int>.filled(bins, 0);
    final span = maxValue - minValue;
    for (final value in values) {
      final raw = span == 0
          ? 0
          : ((value - minValue) / span * bins).floor();
      final index = raw.clamp(0, bins - 1).toInt();
      counts[index] += 1;
    }
    final maxCount = counts.reduce(math.max);
    final width = rect.width / bins;
    for (var index = 0; index < bins; index++) {
      final height = maxCount == 0
          ? 0.0
          : rect.height * .84 * counts[index] / maxCount;
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + index * width + 1,
          rect.bottom - height,
          width - 2,
          height,
        ),
        Paint()..color = colorScheme.primary.withValues(alpha: .76),
      );
    }
  }

  void _paintRadar(Canvas canvas, Rect rect) {
    final row = rows.first;
    const metrics = ['pts', 'reb', 'ast', 'stl', 'blk', 'ts_pct'];
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) * .35;
    final grid = Paint()
      ..color = colorScheme.outlineVariant
      ..style = PaintingStyle.stroke;
    for (final fraction in const [.25, .5, .75, 1.0]) {
      final path = Path();
      for (var index = 0; index < metrics.length; index++) {
        final angle = -math.pi / 2 + index * math.pi * 2 / metrics.length;
        final point = center +
            Offset(math.cos(angle), math.sin(angle)) * radius * fraction;
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    final shape = Path();
    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      final percentile = (row.percentiles[metric] ?? 0) / 100;
      final angle = -math.pi / 2 + index * math.pi * 2 / metrics.length;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final point = center +
          Offset(math.cos(angle), math.sin(angle)) *
              radius *
              percentile.clamp(0, 1).toDouble();
      canvas.drawLine(center, outer, grid);
      if (showLabels) {
        _text(
          canvas,
          engine.metric(metric).shortLabel,
          outer +
              Offset(
                math.cos(angle) * 10 - 10,
                math.sin(angle) * 10 - 6,
              ),
          colorScheme.onSurfaceVariant,
          bold: true,
          small: true,
        );
      }
      if (index == 0) {
        shape.moveTo(point.dx, point.dy);
      } else {
        shape.lineTo(point.dx, point.dy);
      }
    }
    shape.close();
    canvas.drawPath(
      shape,
      Paint()..color = colorScheme.primary.withValues(alpha: .18),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    if (showLabels) {
      _text(
        canvas,
        '${row.player} percentile profile',
        Offset(rect.left + 8, rect.top + 8),
        colorScheme.onSurface,
        bold: true,
      );
    }
  }

  double _bubbleRadius(double? value, List<double> values) {
    if (value == null || values.isEmpty) return 5;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    if (maxValue == minValue) return 10;
    return 5 +
        15 *
            ((value - minValue) / (maxValue - minValue))
                .clamp(0, 1)
                .toDouble();
  }

  Color _colorFor(NbaStatsRow row, int index) {
    if (groupBy == 'None') return colorScheme.primary;
    final token = groupBy == 'Position' ? row.position : row.team;
    final hash =
        token.codeUnits.fold<int>(0, (sum, value) => sum + value * 17) + index;
    final hue = (hash * 37) % 360;
    return HSVColor.fromAHSV(1, hue.toDouble(), .62, .86).toColor();
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    Color color, {
    bool bold = false,
    bool small = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: textStyle.copyWith(
          color: color,
          fontSize: small ? 9 : 11,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 180);
    painter.paint(canvas, offset);
  }

  double _scale(
    double value,
    double min,
    double max,
    double outMin,
    double outMax,
  ) {
    if (max == min) return (outMin + outMax) / 2;
    return outMin + (value - min) / (max - min) * (outMax - outMin);
  }

  String _shortLabel(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return value;
    return '${parts.first.substring(0, 1)}. ${parts.last}';
  }

  @override
  bool shouldRepaint(covariant _NbaChartPainter oldDelegate) => true;
}

class _RegressionSummary {
  const _RegressionSummary({
    required this.count,
    required this.slope,
    required this.intercept,
    required this.r,
  });

  final int count;
  final double slope;
  final double intercept;
  final double r;
  double get rSquared => r * r;

  factory _RegressionSummary.fromRows(
    List<NbaStatsRow> rows,
    String xMetric,
    String yMetric,
  ) {
    final pairs = <(double, double)>[];
    for (final row in rows) {
      final x = row.value(xMetric);
      final y = row.value(yMetric);
      if (x != null && y != null && x.isFinite && y.isFinite) {
        pairs.add((x, y));
      }
    }
    if (pairs.length < 2) {
      return _RegressionSummary(
        count: pairs.length,
        slope: 0,
        intercept: pairs.isEmpty ? 0 : pairs.first.$2,
        r: 0,
      );
    }
    final meanX = pairs.fold<double>(0, (sum, pair) => sum + pair.$1) /
        pairs.length;
    final meanY = pairs.fold<double>(0, (sum, pair) => sum + pair.$2) /
        pairs.length;
    var covariance = 0.0;
    var varianceX = 0.0;
    var varianceY = 0.0;
    for (final pair in pairs) {
      final dx = pair.$1 - meanX;
      final dy = pair.$2 - meanY;
      covariance += dx * dy;
      varianceX += dx * dx;
      varianceY += dy * dy;
    }
    final slope = varianceX == 0 ? 0.0 : covariance / varianceX;
    final intercept = meanY - slope * meanX;
    final denominator = math.sqrt(varianceX * varianceY);
    final r = denominator == 0 ? 0.0 : covariance / denominator;
    return _RegressionSummary(
      count: pairs.length,
      slope: slope,
      intercept: intercept,
      r: r.clamp(-1, 1).toDouble(),
    );
  }
}

class _SavedVisualization {
  const _SavedVisualization({
    required this.id,
    required this.name,
    required this.season,
    required this.seasonType,
    required this.basis,
    required this.chart,
    required this.xMetric,
    required this.yMetric,
    required this.sizeMetric,
    required this.groupBy,
    required this.minGames,
    required this.topN,
    required this.showLabels,
    required this.showTrendLine,
    required this.showMeans,
    required this.search,
  });

  final String id;
  final String name;
  final String season;
  final String seasonType;
  final String basis;
  final String chart;
  final String xMetric;
  final String yMetric;
  final String sizeMetric;
  final String groupBy;
  final double minGames;
  final int topN;
  final bool showLabels;
  final bool showTrendLine;
  final bool showMeans;
  final String search;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'season': season,
        'season_type': seasonType,
        'basis': basis,
        'chart': chart,
        'x_metric': xMetric,
        'y_metric': yMetric,
        'size_metric': sizeMetric,
        'group_by': groupBy,
        'min_games': minGames,
        'top_n': topN,
        'show_labels': showLabels,
        'show_trend_line': showTrendLine,
        'show_means': showMeans,
        'search': search,
      };

  factory _SavedVisualization.fromJson(Map<String, dynamic> json) =>
      _SavedVisualization(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Saved visualization',
        season: json['season']?.toString() ?? '2025-26',
        seasonType: json['season_type']?.toString() ?? 'regular',
        basis: json['basis']?.toString() ?? 'perGame',
        chart: json['chart']?.toString() ?? 'scatter',
        xMetric: json['x_metric']?.toString() ?? 'ast',
        yMetric: json['y_metric']?.toString() ?? 'pts',
        sizeMetric: json['size_metric']?.toString() ?? 'reb',
        groupBy: json['group_by']?.toString() ?? 'Team',
        minGames: (json['min_games'] as num?)?.toDouble() ?? 20,
        topN: (json['top_n'] as num?)?.toInt() ?? 40,
        showLabels: json['show_labels'] != false,
        showTrendLine: json['show_trend_line'] != false,
        showMeans: json['show_means'] == true,
        search: json['search']?.toString() ?? '',
      );
}
