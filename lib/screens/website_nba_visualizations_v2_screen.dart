import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';

enum _ChartType {
  scatter('Scatter'),
  bubble('Bubble'),
  bar('Player ranking'),
  histogram('Distribution'),
  box('Position box plot'),
  cumulative('Cumulative percentile'),
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
  String? _populationFilterKey;
  int _populationSearchVersion = 0;
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
  double _minGames = 50;
  double get _defaultMinGames => _seasonType == NbaStatsSeasonType.playoffs ? 4 : 50;
  int _topN = 40;
  int _rankingTopN = 20;
  bool _showLabels = true;
  bool _showTrendLine = true;
  bool _showMeans = false;
  bool _showGrid = true;
  bool _showZeroLine = false;
  bool _showOutliers = true;
  String _labelDensity = 'More';
  int _histogramBins = 12;
  String? _radarPlayer;
  String? _radarComparePlayer;
  String? _activePresetId;
  late Future<NbaTerminalSeedSnapshot> _snapshotFuture;

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
    _snapshotFuture = _initialize();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<NbaTerminalSeedSnapshot> _initialize() async {
    _seasons = await _api.seasons();
    if (_seasons.isNotEmpty && !_seasons.any((item) => item.id == _season)) {
      _season = _seasons.first.id;
    }
    await _loadSaved();
    return _loadSnapshot();
  }

  Future<NbaTerminalSeedSnapshot> _loadSnapshot() => _api.seasonSnapshot(
        _season,
        seasonType: _seasonType == NbaStatsSeasonType.playoffs
            ? 'playoffs'
            : 'regular',
      );

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

  void _reload() => setState(() => _snapshotFuture = _loadSnapshot());

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
      _minGames = 50;
      _topN = 40;
      _rankingTopN = 20;
      _showLabels = true;
      _showTrendLine = true;
      _showMeans = false;
      _showGrid = true;
      _showZeroLine = false;
      _showOutliers = true;
      _labelDensity = 'More';
      _histogramBins = 12;
      _radarPlayer = null;
      _radarComparePlayer = null;
      _search.clear();
      _populationFilterKey = null;
      _populationSearchVersion++;
      _activePresetId = null;
      _snapshotFuture = _loadSnapshot();
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
        topN: _chart == _ChartType.bar ? _rankingTopN : _topN,
        showLabels: _showLabels,
        showTrendLine: _showTrendLine,
        showMeans: _showMeans,
        showGrid: _showGrid,
        showZeroLine: _showZeroLine,
        showOutliers: _showOutliers,
        labelDensity: _labelDensity,
        histogramBins: _histogramBins,
        radarPlayer: _radarPlayer,
        radarComparePlayer: _radarComparePlayer,
        search: _search.text,
        populationFilterKey: _populationFilterKey,
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
      _minGames = preset.minGames.clamp(0, _seasonType == NbaStatsSeasonType.playoffs ? 28 : 82).toDouble();
      final savedTopN =
          const [0, 10, 20, 30, 40, 60, 100].contains(preset.topN)
              ? preset.topN
              : 40;
      if (_chart == _ChartType.bar) {
        _rankingTopN = savedTopN == 10 ? 10 : 20;
      } else {
        _topN = savedTopN;
      }
      _showLabels = preset.showLabels;
      _showTrendLine = preset.showTrendLine;
      _showMeans = preset.showMeans;
      _showGrid = preset.showGrid;
      _showZeroLine = preset.showZeroLine;
      _showOutliers = preset.showOutliers;
      _labelDensity = preset.labelDensity;
      _histogramBins =
          const [8, 10, 12, 16, 20].contains(preset.histogramBins)
              ? preset.histogramBins
              : 12;
      _radarPlayer = preset.radarPlayer;
      _radarComparePlayer = preset.radarComparePlayer;
      _search.text = preset.search;
      _populationFilterKey = preset.populationFilterKey;
      _populationSearchVersion++;
      _activePresetId = preset.id;
      _snapshotFuture = _loadSnapshot();
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
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      key: ValueKey('$_season/${_seasonType.name}'),
      future: _snapshotFuture,
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
        return _buildPage(
          context,
          _engine.buildRows(
            snapshot.data!,
            basis: _basis,
            seasonType: _seasonType,
          ),
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, List<NbaStatsRow> allRows) {
    final selected = _populationFilterKey;
    final matching = allRows.where((row) {
      if ((row.value('gp') ?? 0) < _minGames) return false;
      if (selected != null) {
        if (selected.startsWith('team:') &&
            !_studioTeams(row).contains(selected.substring(5))) return false;
        if (selected.startsWith('player:') &&
            row.playerId != selected.substring(7)) return false;
      }
      return true;
    }).toList(growable: false);

    final filtered = matching.where((row) {
      if (_chart == _ChartType.radar) {
        return const ['pts', 'reb', 'ast', 'stl', 'blk', 'ts_pct']
            .any((metric) => _studioHasMetric(row, metric, _basis));
      }
      if (!_studioHasMetric(row, _yMetric, _basis)) return false;
      if (_supportsXYAnalytics &&
          !_studioHasMetric(row, _xMetric, _basis)) return false;
      if (_chart == _ChartType.bubble &&
          !_studioHasMetric(row, _sizeMetric, _basis)) return false;
      return true;
    }).toList(growable: false);

    // Deterministic top-N selection: highest Y/ranking metric first,
    // followed by full player name and stable player ID for ties.
    final ranked = [...filtered]
      ..sort((a, b) {
        final byMetric = _chart == _ChartType.radar
            ? 0
            : b.value(_yMetric)!.compareTo(a.value(_yMetric)!);
        if (byMetric != 0) return byMetric;
        final byName = a.player.compareTo(b.player);
        return byName != 0 ? byName : a.playerId.compareTo(b.playerId);
      });

    final radarName = _radarPlayer != null &&
            ranked.any((row) => row.player == _radarPlayer)
        ? _radarPlayer
        : (ranked.isEmpty ? null : ranked.first.player);
    final radarCompareName = _radarComparePlayer != null &&
            _radarComparePlayer != radarName &&
            ranked.any((row) => row.player == _radarComparePlayer)
        ? _radarComparePlayer
        : null;

    final rows = switch (_chart) {
      _ChartType.histogram || _ChartType.box || _ChartType.cumulative => filtered,
      _ChartType.radar => radarName == null
          ? <NbaStatsRow>[]
          : [
              ranked.firstWhere((row) => row.player == radarName),
              if (radarCompareName != null)
                ranked.firstWhere((row) => row.player == radarCompareName),
            ],
      _ => (_chart == _ChartType.bar ? _rankingTopN : _topN) == 0
          ? ranked
          : ranked
              .take(_chart == _ChartType.bar ? _rankingTopN : _topN)
              .toList(growable: false),
    };
    final readoutRows =
        _chart == _ChartType.histogram || _chart == _ChartType.box || _chart == _ChartType.cumulative ? ranked : rows;

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
          filtered: ranked,
          allRows: allRows,
          matchingCount: matching.length,
          dataCount: allRows.length,
          radarName: radarName,
          radarCompareName: radarCompareName,
        );
        final workspace = _buildWorkspace(
          context,
          rows: rows,
          analytics: analytics,
          metricLabel: metricLabel,
          xLabel: xLabel,
          eligibleCount: filtered.length,
          readoutRows: readoutRows,
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
                      'Built from the same static player-season dataset used by Stats and Advanced Stats. $plotted plotted from $eligible eligible players.',
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
            const _StudioContextChip(
              icon: Icons.storage_rounded,
              label: 'Static season data',
            ),
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
    required List<NbaStatsRow> filtered,
    required List<NbaStatsRow> allRows,
    required int matchingCount,
    required int dataCount,
    required String? radarName,
    required String? radarCompareName,
  }) {
    final colors = Theme.of(context).colorScheme;
    final playerNames = filtered.map((row) => row.player).toSet().toList()
      ..sort();

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
                setState(() {
                  _season = value;
                  _minGames = _defaultMinGames;
                  _populationFilterKey = null;
                  _search.clear();
                  _populationSearchVersion++;
                  _radarPlayer = null;
                  _radarComparePlayer = null;
                  _snapshotFuture = _loadSnapshot();
                });
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
                setState(() {
                  _seasonType = value;
                  _minGames = _defaultMinGames;
                  _populationFilterKey = null;
                  _search.clear();
                  _populationSearchVersion++;
                  _radarPlayer = null;
                  _radarComparePlayer = null;
                  _snapshotFuture = _loadSnapshot();
                });
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
                setState(() => _basis = value);
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
                  setState(() => _chart = value);
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
                onChanged: (value) {
                  setState(() {
                    _radarPlayer = value;
                    if (_radarComparePlayer == value) {
                      _radarComparePlayer = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              _StudioSelect<String>(
                label: 'Compare with',
                value: radarCompareName ?? '__none__',
                items: [
                  const DropdownMenuItem(
                    value: '__none__',
                    child: Text('No comparison'),
                  ),
                  for (final player in playerNames)
                    if (player != radarName)
                      DropdownMenuItem(
                        value: player,
                        child: Text(
                          player,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: (value) => setState(
                  () => _radarComparePlayer =
                      value == null || value == '__none__' ? null : value,
                ),
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
              if (_yMetric == 'game_score_proxy')
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    'PROD is a custom box-score index: PTS + 0.7×REB + 0.7×AST + STL + BLK − 0.7×TOV. Not an official NBA metric.',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              if (_chart == _ChartType.histogram) ...[
                const SizedBox(height: 10),
                _StudioSelect<int>(
                  label: 'Bins',
                  value: _histogramBins,
                  items: const [8, 10, 12, 16, 20]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value bins'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _histogramBins = value);
                    }
                  },
                ),
              ],
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
              if (_chart != _ChartType.histogram && _chart != _ChartType.box && _chart != _ChartType.cumulative) ...[
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
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${filtered.length} eligible · $matchingCount match filters · $dataCount season players',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
            ),
            _StudioPopulationPicker(
              key: ValueKey('$_season/${_seasonType.name}/$_populationSearchVersion'),
              rows: allRows,
              initialText: _search.text,
              selectedKey: _populationFilterKey,
              onTyping: (value) {
                _search.text = value;
                if (_populationFilterKey != null) {
                  setState(() => _populationFilterKey = null);
                }
              },
              onSelected: (option) {
                setState(() {
                  _populationFilterKey = option.key;
                  _search.text = option.label;
                });
              },
              onClear: () {
                setState(() {
                  _populationFilterKey = null;
                  _search.clear();
                  _populationSearchVersion++;
                });
              },
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
              max: _seasonType == NbaStatsSeasonType.playoffs ? 28 : 82,
              divisions: _seasonType == NbaStatsSeasonType.playoffs ? 28 : 82,
              onChanged: (value) => setState(() => _minGames = value),
            ),
            if (_chart != _ChartType.histogram &&
                _chart != _ChartType.box &&
                _chart != _ChartType.cumulative &&
                _chart != _ChartType.radar)
              _StudioSelect<int>(
                label: 'Population size',
                value: _chart == _ChartType.bar ? _rankingTopN : _topN,
                items: (_chart == _ChartType.bar
                        ? const [10, 20]
                        : const [0, 10, 20, 30, 40, 60, 100])
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == 0
                              ? 'All eligible players'
                              : 'Top $value by ${_engine.metric(_yMetric).shortLabel}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      if (_chart == _ChartType.bar) {
                        _rankingTopN = value;
                      } else {
                        _topN = value;
                      }
                    });
                  }
                },
              ),
            if (_supportsXYAnalytics) ...[
              const _StudioSectionDivider(),
              const _StudioSectionTitle('DISPLAY'),
              _StudioToggle(
                label: 'Player labels',
                value: _showLabels,
                onChanged: (value) => setState(() => _showLabels = value),
              ),
              _StudioToggle(
                label: 'Best-fit line',
                value: _showTrendLine,
                onChanged: (value) =>
                    setState(() => _showTrendLine = value),
              ),
              _StudioToggle(
                label: 'Mean reference lines',
                value: _showMeans,
                onChanged: (value) => setState(() => _showMeans = value),
              ),
              _StudioToggle(
                label: 'Gridlines',
                value: _showGrid,
                onChanged: (value) => setState(() => _showGrid = value),
              ),
              _StudioToggle(
                label: 'Zero reference lines',
                value: _showZeroLine,
                onChanged: (value) => setState(() => _showZeroLine = value),
              ),
              if (_showLabels)
                _StudioSelect<String>(
                  label: 'Label density',
                  value: _labelDensity,
                  items: const [
                    DropdownMenuItem(value: 'Selective', child: Text('Selective')),
                    DropdownMenuItem(value: 'More', child: Text('More (recommended)')),
                    DropdownMenuItem(value: 'All', child: Text('All (where space permits)')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _labelDensity = value);
                  },
                ),
            ],
            if (_chart == _ChartType.box) ...[
              const _StudioSectionDivider(),
              const _StudioSectionTitle('DISPLAY'),
              _StudioToggle(
                label: 'Show outlier points',
                value: _showOutliers,
                onChanged: (value) => setState(() => _showOutliers = value),
              ),
            ],
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
    required int eligibleCount,
    required List<NbaStatsRow> readoutRows,
  }) {
    final colors = Theme.of(context).colorScheme;
    final top = rows.isEmpty ? null : rows.first;
    final chartTitle = switch (_chart) {
      _ChartType.scatter => '$metricLabel vs $xLabel',
      _ChartType.bubble => '$metricLabel vs $xLabel · bubble size ${_engine.metric(_sizeMetric).shortLabel}',
      _ChartType.bar => '$metricLabel player ranking',
      _ChartType.histogram => '$metricLabel distribution',
      _ChartType.box => '$metricLabel by position · quartiles',
      _ChartType.cumulative => '$metricLabel cumulative percentile',
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
                      (_chart == _ChartType.histogram || _chart == _ChartType.box || _chart == _ChartType.cumulative)
                          ? 'Full eligible population · ${rows.length} players'
                          : _chart == _ChartType.radar
                              ? rows.length > 1
                                  ? 'Percentile comparison across six core metrics'
                                  : 'Percentile profile across six core metrics'
                              : _chart == _ChartType.bar
                                  ? 'Top ${rows.length} by $metricLabel after filters'
                                  : _topN == 0
                                      ? '${rows.length} eligible players plotted'
                                      : '${rows.length} plotted from $eligibleCount eligible · ranked by $metricLabel',
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
                    if (_chart == _ChartType.scatter ||
                        _chart == _ChartType.bubble ||
                        _chart == _ChartType.bar)
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
        ] else if ((_chart == _ChartType.histogram || _chart == _ChartType.box || _chart == _ChartType.cumulative) && rows.isNotEmpty) ...[
          _DistributionInsightBar(
            rows: rows,
            metricKey: _yMetric,
            metricLabel: metricLabel,
            engine: _engine,
          ),
          const SizedBox(height: 10),
        ] else if (_chart == _ChartType.radar && top != null) ...[
          _ProfileInsightBar(players: rows),
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
              Widget chartPanel() => _InteractiveChartPanel(
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
                    showGrid: _showGrid,
                    showZeroLine: _showZeroLine,
                    showOutliers: _showOutliers,
                    labelDensity: _labelDensity,
                    histogramBins: _histogramBins,
                    season: _season,
                    seasonType: _seasonType,
                  );

              return Column(
                children: [
                  SizedBox(
                    height: height,
                    child: rows.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('No eligible player data for this view.'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Check minimum games, the selected season and rate, or choose a metric with source coverage.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () => setState(() => _minGames = 0),
                                    child: const Text('Clear games minimum'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _chart == _ChartType.radar &&
                                constraints.maxWidth >= 940
                            ? Row(
                                children: [
                                  Expanded(child: chartPanel()),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  SizedBox(
                                    width: 310,
                                    child: _ProfileMetricPanel(
                                      primary: rows.first,
                                      comparison:
                                          rows.length > 1 ? rows[1] : null,
                                      engine: _engine,
                                      colorScheme: colors,
                                    ),
                                  ),
                                ],
                              )
                            : chartPanel(),
                  ),
                  if (_chart == _ChartType.bubble && rows.isNotEmpty) ...[
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    _BubbleSizeLegend(
                      rows: rows,
                      metricKey: _sizeMetric,
                      engine: _engine,
                      colorScheme: colors,
                    ),
                  ],
                  if (_chart == _ChartType.radar && rows.length > 1) ...[
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    _ProfileComparisonLegend(
                      primary: rows[0],
                      comparison: rows[1],
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
          rows: readoutRows.take(15).toList(growable: false),
          xMetric: _xMetric,
          yMetric: _yMetric,
          engine: _engine,
          showX: _supportsXYAnalytics,
          profileMode: _chart == _ChartType.radar,
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


class _StudioPopulationChoice {
  const _StudioPopulationChoice(this.key, this.label, this.subtitle);
  final String key;
  final String label;
  final String subtitle;
}

const _studioTeamNames = <String, String>{
  'ATL': 'Atlanta Hawks', 'BOS': 'Boston Celtics',
  'BKN': 'Brooklyn Nets', 'BRK': 'Brooklyn Nets',
  'CHA': 'Charlotte Hornets', 'CHI': 'Chicago Bulls',
  'CLE': 'Cleveland Cavaliers', 'DAL': 'Dallas Mavericks',
  'DEN': 'Denver Nuggets', 'DET': 'Detroit Pistons',
  'GSW': 'Golden State Warriors', 'HOU': 'Houston Rockets',
  'IND': 'Indiana Pacers', 'LAC': 'LA Clippers',
  'LAL': 'Los Angeles Lakers', 'MEM': 'Memphis Grizzlies',
  'MIA': 'Miami Heat', 'MIL': 'Milwaukee Bucks',
  'MIN': 'Minnesota Timberwolves', 'NOP': 'New Orleans Pelicans',
  'NYK': 'New York Knicks', 'OKC': 'Oklahoma City Thunder',
  'ORL': 'Orlando Magic', 'PHI': 'Philadelphia 76ers',
  'PHO': 'Phoenix Suns', 'PHX': 'Phoenix Suns',
  'POR': 'Portland Trail Blazers', 'SAC': 'Sacramento Kings',
  'SAS': 'San Antonio Spurs', 'TOR': 'Toronto Raptors',
  'UTA': 'Utah Jazz', 'WAS': 'Washington Wizards',
  'WSB': 'Washington Bullets', 'SEA': 'Seattle SuperSonics',
  'NJN': 'New Jersey Nets', 'NOH': 'New Orleans Hornets',
  'NOK': 'New Orleans/Oklahoma City Hornets',
  'VAN': 'Vancouver Grizzlies', 'SDC': 'San Diego Clippers',
  'KCK': 'Kansas City Kings', 'KCO': 'Kansas City-Omaha Kings',
};

class _StudioPopulationPicker extends StatelessWidget {
  const _StudioPopulationPicker({
    super.key,
    required this.rows,
    required this.initialText,
    required this.selectedKey,
    required this.onTyping,
    required this.onSelected,
    required this.onClear,
  });

  final List<NbaStatsRow> rows;
  final String initialText;
  final String? selectedKey;
  final ValueChanged<String> onTyping;
  final ValueChanged<_StudioPopulationChoice> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final teams = <String>{};
    final players = <String, _StudioPopulationChoice>{};
    for (final row in rows) {
      teams.addAll(_studioTeams(row));
      players.putIfAbsent(row.playerId, () => _StudioPopulationChoice(
        'player:${row.playerId}', row.player, 'Player · ${row.position}',
      ));
    }
    final choices = <_StudioPopulationChoice>[
      for (final team in teams.toList()..sort())
        _StudioPopulationChoice(
          'team:$team', '${_studioTeamNames[team] ?? team} ($team)', 'Team',
        ),
      ...players.values,
    ];
    choices.sort((a, b) {
      final group = a.subtitle == 'Team' ? 0 : 1;
      final other = b.subtitle == 'Team' ? 0 : 1;
      return group != other
          ? group.compareTo(other)
          : a.label.compareTo(b.label);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<_StudioPopulationChoice>(
          initialValue: TextEditingValue(text: initialText),
          displayStringForOption: (option) => option.label,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const Iterable<_StudioPopulationChoice>.empty();
            return choices.where((option) =>
                option.label.toLowerCase().contains(query) ||
                option.subtitle.toLowerCase().contains(query))
                .take(12);
          },
          onSelected: onSelected,
          optionsViewBuilder: (context, select, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 9,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300, maxWidth: 325),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        dense: true,
                        title: Text(option.label, maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(option.subtitle),
                        onTap: () => select(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
          fieldViewBuilder: (context, controller, focusNode, submit) =>
              TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onTyping,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Filter by team or player',
                  hintText: 'Search and select…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: selectedKey == null
                      ? null
                      : IconButton(
                          tooltip: 'Clear selection',
                          onPressed: onClear,
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                ),
              ),
        ),
        const SizedBox(height: 5),
        Text(
          selectedKey == null
              ? 'Choose a result to filter. Typing alone does not change the chart.'
              : 'Exact selection active · clear to see all players',
          style: TextStyle(fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
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
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: colors.primary.withValues(alpha: .72),
              activeThumbColor: colors.onPrimary,
              inactiveTrackColor:
                  colors.surfaceContainerHighest.withValues(alpha: .9),
              inactiveThumbColor: colors.onSurfaceVariant,
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
          caption: 'plotted sample',
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

class _DistributionInsightBar extends StatelessWidget {
  const _DistributionInsightBar({
    required this.rows,
    required this.metricKey,
    required this.metricLabel,
    required this.engine,
  });

  final List<NbaStatsRow> rows;
  final String metricKey;
  final String metricLabel;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) {
    final values = rows
        .map((row) => row.value(metricKey))
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);
    if (values.isEmpty) return const SizedBox.shrink();

    values.sort();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final median = values.length.isOdd
        ? values[values.length ~/ 2]
        : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;
    final minValue = values.first;
    final maxValue = values.last;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InsightTile(
          label: 'POPULATION',
          value: '${values.length}',
          caption: 'filtered players',
        ),
        _InsightTile(
          label: 'MEAN $metricLabel',
          value: engine.formatValue(metricKey, mean),
          caption: 'population average',
        ),
        _InsightTile(
          label: 'MEDIAN $metricLabel',
          value: engine.formatValue(metricKey, median),
          caption: '50th percentile',
        ),
        _InsightTile(
          label: 'RANGE',
          value:
              '${engine.formatValue(metricKey, minValue)} – ${engine.formatValue(metricKey, maxValue)}',
          caption: 'min to max',
          wide: true,
        ),
      ],
    );
  }
}

class _ProfileInsightBar extends StatelessWidget {
  const _ProfileInsightBar({required this.players});
  final List<NbaStatsRow> players;

  @override
  Widget build(BuildContext context) {
    final primary = players.first;
    final comparison = players.length > 1 ? players[1] : null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InsightTile(
          label: comparison == null ? 'PLAYER' : 'PRIMARY',
          value: primary.player,
          caption: '${primary.team} · ${primary.position}',
          wide: true,
        ),
        if (comparison != null)
          _InsightTile(
            label: 'COMPARE',
            value: comparison.player,
            caption: '${comparison.team} · ${comparison.position}',
            wide: true,
          ),
        _InsightTile(
          label: 'PROFILE',
          value: '6 metrics',
          caption: 'percentile view',
        ),
      ],
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
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
              fontSize: 9.5,
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
              fontSize: 13,
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

class _BubbleSizeLegend extends StatelessWidget {
  const _BubbleSizeLegend({
    required this.rows,
    required this.metricKey,
    required this.engine,
    required this.colorScheme,
  });

  final List<NbaStatsRow> rows;
  final String metricKey;
  final NbaStatsWorkstationEngine engine;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final values = rows
        .map((row) => row.value(metricKey))
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList()
      ..sort();
    if (values.isEmpty) return const SizedBox.shrink();

    final samples = <double>[
      values.first,
      values[values.length ~/ 2],
      values.last,
    ];
    const radii = [5.0, 8.0, 11.0];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'SIZE · ${engine.metric(metricKey).shortLabel}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .55,
            ),
          ),
          for (var index = 0; index < samples.length; index++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Container(
                      width: radii[index] * 2,
                      height: radii[index] * 2,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: .48),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: .8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  engine.formatValue(metricKey, samples[index]),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProfileComparisonLegend extends StatelessWidget {
  const _ProfileComparisonLegend({
    required this.primary,
    required this.comparison,
    required this.colorScheme,
  });

  final NbaStatsRow primary;
  final NbaStatsRow comparison;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'PROFILE',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
              ),
            ),
            _ProfileLegendItem(
              color: colorScheme.primary,
              label: '${primary.player} · ${primary.team}',
            ),
            _ProfileLegendItem(
              color: colorScheme.tertiary,
              label: '${comparison.player} · ${comparison.team}',
            ),
          ],
        ),
      );
}

class _ProfileLegendItem extends StatelessWidget {
  const _ProfileLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .28),
              border: Border.all(color: color, width: 1.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _ProfileMetricPanel extends StatelessWidget {
  const _ProfileMetricPanel({
    required this.primary,
    required this.comparison,
    required this.engine,
    required this.colorScheme,
  });

  final NbaStatsRow primary;
  final NbaStatsRow? comparison;
  final NbaStatsWorkstationEngine engine;
  final ColorScheme colorScheme;

  static const _metrics = ['pts', 'reb', 'ast', 'stl', 'blk', 'ts_pct'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'METRIC PERCENTILES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            comparison == null
                ? 'Raw value and league percentile'
                : 'Primary and comparison percentile',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < _metrics.length; index++) ...[
            _ProfileMetricRow(
              metricKey: _metrics[index],
              primary: primary,
              comparison: comparison,
              engine: engine,
              colorScheme: colorScheme,
            ),
            if (index != _metrics.length - 1) const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }
}

class _ProfileMetricRow extends StatelessWidget {
  const _ProfileMetricRow({
    required this.metricKey,
    required this.primary,
    required this.comparison,
    required this.engine,
    required this.colorScheme,
  });

  final String metricKey;
  final NbaStatsRow primary;
  final NbaStatsRow? comparison;
  final NbaStatsWorkstationEngine engine;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final primaryPct = (primary.percentiles[metricKey] ?? 0).clamp(0, 100);
    final comparisonPct =
        (comparison?.percentiles[metricKey] ?? 0).clamp(0, 100);

    Widget progress(double value, Color color) => ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 5,
            backgroundColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: .55),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                engine.metric(metricKey).shortLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${engine.formatValue(metricKey, primary.value(metricKey))} · P${primaryPct.round()}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        progress(primaryPct.toDouble(), colorScheme.primary),
        if (comparison != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  comparison!.team,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${engine.formatValue(metricKey, comparison!.value(metricKey))} · P${comparisonPct.round()}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          progress(comparisonPct.toDouble(), colorScheme.tertiary),
        ],
      ],
    );
  }
}

class _ChartReadout extends StatelessWidget {
  const _ChartReadout({
    required this.rows,
    required this.xMetric,
    required this.yMetric,
    required this.engine,
    required this.showX,
    required this.profileMode,
  });

  final List<NbaStatsRow> rows;
  final String xMetric;
  final String yMetric;
  final NbaStatsWorkstationEngine engine;
  final bool showX;
  final bool profileMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'UNDERLYING DATA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
                Text(
                  'Showing ${rows.length}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 34,
              headingRowHeight: 42,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              columns: profileMode
                  ? [
                      const DataColumn(label: Text('Player')),
                      const DataColumn(label: Text('Team')),
                      for (final metric
                          in const ['pts', 'reb', 'ast', 'stl', 'blk', 'ts_pct'])
                        DataColumn(
                          numeric: true,
                          label: Text(engine.metric(metric).shortLabel),
                        ),
                    ]
                  : [
                      const DataColumn(label: Text('Player')),
                      const DataColumn(label: Text('Team')),
                      if (showX)
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
                    cells: profileMode
                        ? [
                            DataCell(
                              Text(
                                row.player,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(Text(row.team)),
                            for (final metric in const [
                              'pts',
                              'reb',
                              'ast',
                              'stl',
                              'blk',
                              'ts_pct',
                            ])
                              DataCell(
                                Text(
                                  engine.formatValue(
                                    metric,
                                    row.value(metric),
                                  ),
                                ),
                              ),
                          ]
                        : [
                            DataCell(
                              Text(
                                row.player,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(Text(row.team)),
                            if (showX)
                              DataCell(
                                Text(
                                  engine.formatValue(
                                    xMetric,
                                    row.value(xMetric),
                                  ),
                                ),
                              ),
                            DataCell(
                              Text(
                                engine.formatValue(
                                  yMetric,
                                  row.value(yMetric),
                                ),
                              ),
                            ),
                          ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveChartPanel extends StatefulWidget {
  const _InteractiveChartPanel({
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
    required this.showGrid,
    required this.showZeroLine,
    required this.showOutliers,
    required this.labelDensity,
    required this.histogramBins,
    required this.season,
    required this.seasonType,
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
  final bool showGrid;
  final bool showZeroLine;
  final bool showOutliers;
  final String labelDensity;
  final int histogramBins;
  final String season;
  final NbaStatsSeasonType seasonType;

  @override
  State<_InteractiveChartPanel> createState() => _InteractiveChartPanelState();
}

class _InteractiveChartPanelState extends State<_InteractiveChartPanel> {
  NbaStatsRow? _hovered;
  NbaStatsRow? _pinned;
  Offset? _pointer;
  double _zoom = 1;
  Offset _center = const Offset(.5, .5);
  double _gestureStartZoom = 1;
  Offset? _lastFocal;
  final _teamLookups = <String, Future<List<String>>>{};

  bool get _bar => widget.chart == _ChartType.bar;
  bool get _inspectable => _xy || _bar;

  bool get _xy =>
      widget.chart == _ChartType.scatter ||
      widget.chart == _ChartType.bubble;

  bool _samePopulation(
    List<NbaStatsRow> before,
    List<NbaStatsRow> after,
  ) {
    if (before.length != after.length) return false;
    for (var i = 0; i < before.length; i++) {
      if (before[i].playerId != after[i].playerId) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant _InteractiveChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart != widget.chart ||
        oldWidget.xMetric != widget.xMetric ||
        oldWidget.yMetric != widget.yMetric ||
        !_samePopulation(oldWidget.rows, widget.rows) ||
        oldWidget.season != widget.season ||
        oldWidget.seasonType != widget.seasonType) {
      _zoom = 1;
      _center = const Offset(.5, .5);
      _hovered = null;
      _pinned = null;
      _pointer = null;
    }
    if (_pinned != null &&
        !widget.rows.any((row) => row.player == _pinned!.player)) {
      _pinned = null;
      _hovered = null;
      _pointer = null;
    }
  }

  Rect _plotRect(Size size) => Rect.fromLTWH(
        72,
        28,
        math.max(10.0, size.width - 104),
        math.max(10.0, size.height - 88),
      );

  _StudioViewport? _viewport() {
    if (!_xy || widget.rows.isEmpty) return null;
    final valid = widget.rows.where((row) =>
        row.value(widget.xMetric) != null &&
        row.value(widget.yMetric) != null &&
        row.value(widget.xMetric)!.isFinite &&
        row.value(widget.yMetric)!.isFinite).toList();
    if (valid.isEmpty) return null;
    final x = _paddedChartRange(
        valid.map((row) => row.value(widget.xMetric)!).toList(),
        percentage: _studioPercent(widget.xMetric));
    final y = _paddedChartRange(
        valid.map((row) => row.value(widget.yMetric)!).toList(),
        percentage: _studioPercent(widget.yMetric));
    final width = (x.$2 - x.$1) / _zoom;
    final height = (y.$2 - y.$1) / _zoom;
    final centerX = x.$1 + (x.$2 - x.$1) * _center.dx;
    final centerY = y.$1 + (y.$2 - y.$1) * _center.dy;
    return _StudioViewport(
      xMin: centerX - width / 2,
      xMax: centerX + width / 2,
      yMin: centerY - height / 2,
      yMax: centerY + height / 2,
    );
  }

  void _zoomTo(double next, Offset focalPoint, Size size) {
    if (!_xy) return;
    final nextZoom = next.clamp(1.0, 16.0).toDouble();
    final plot = _plotRect(size);
    final fx = ((focalPoint.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    final fy = ((plot.bottom - focalPoint.dy) / plot.height).clamp(0.0, 1.0);
    final shift = 1 / _zoom - 1 / nextZoom;
    setState(() {
      _center = Offset(
        (_center.dx + (fx - .5) * shift)
            .clamp(.5 / nextZoom, 1 - .5 / nextZoom),
        (_center.dy + (fy - .5) * shift)
            .clamp(.5 / nextZoom, 1 - .5 / nextZoom),
      );
      _zoom = nextZoom;
      _hovered = null;
    });
  }

  void _dragView(Offset pixels, Size size) {
    if (!_xy || _zoom <= 1) return;
    final plot = _plotRect(size);
    setState(() {
      _center = Offset(
        (_center.dx - pixels.dx / plot.width / _zoom)
            .clamp(.5 / _zoom, 1 - .5 / _zoom),
        (_center.dy + pixels.dy / plot.height / _zoom)
            .clamp(.5 / _zoom, 1 - .5 / _zoom),
      );
      _hovered = null;
    });
  }

  void _resetViewport() {
    setState(() {
      _zoom = 1;
      _center = const Offset(.5, .5);
      _hovered = null;
    });
  }

  void _scaleStart(ScaleStartDetails details) {
    _gestureStartZoom = _zoom;
    _lastFocal = details.localFocalPoint;
  }

  void _scaleUpdate(ScaleUpdateDetails details, Size size) {
    final delta = details.localFocalPoint - (_lastFocal ?? details.localFocalPoint);
    _lastFocal = details.localFocalPoint;
    if (details.scale != 1) {
      _zoomTo(_gestureStartZoom * details.scale, details.localFocalPoint, size);
    }
    if (delta != Offset.zero) _dragView(delta, size);
  }

  Future<List<String>> _teamsFor(NbaStatsRow row) {
    final direct = _studioTeams(row);
    if (direct.isNotEmpty) return Future.value(direct);
    final key = '${widget.season}/${widget.seasonType.name}/${row.playerId}';
    return _teamLookups.putIfAbsent(key, () async {
      try {
        final dossier = await const WebsiteNbaApiService().playerDossier(row.playerId);
        final entries = dossier['seasons'];
        if (entries is! List) return const <String>[];
        final teams = <String>{};
        for (final entry in entries) {
          if (entry is! Map) continue;
          final year = (entry['season_id'] ?? '').toString();
          final segment = (entry['season_type'] ?? '').toString().toLowerCase();
          final wanted = widget.seasonType == NbaStatsSeasonType.playoffs
              ? segment.contains('play') || segment.contains('postseason')
              : segment == 'regular';
          if (year != widget.season || !wanted) continue;
          final abbr = (entry['team_abbreviation'] ?? entry['team'] ?? '')
              .toString().trim();
          if (abbr.isNotEmpty && !_studioAggregateTeam(abbr)) teams.add(abbr);
        }
        return teams.toList()..sort();
      } catch (_) {
        return const <String>[];
      }
    });
  }

  NbaStatsRow? _nearest(Offset position, Size size) {
    if (!_inspectable) return null;
    final plot = _plotRect(size);
    if (!plot.inflate(8).contains(position)) return null;
    if (_bar) {
      final index = ((position.dy - plot.top) / plot.height *
              widget.rows.length).floor();
      if (index < 0 || index >= widget.rows.length) return null;
      return widget.rows[index];
    }
    final valid = widget.rows
        .where(
          (row) =>
              row.value(widget.xMetric) != null &&
              row.value(widget.yMetric) != null &&
              row.value(widget.xMetric)!.isFinite &&
              row.value(widget.yMetric)!.isFinite,
        )
        .toList(growable: false);
    if (valid.isEmpty) return null;

    final viewport = _viewport()!;
    final xMin = viewport.xMin;
    final xMax = viewport.xMax;
    final yMin = viewport.yMin;
    final yMax = viewport.yMax;
    final rect = _plotRect(size);

    NbaStatsRow? nearest;
    var best = double.infinity;
    for (final row in valid) {
      final point = Offset(
        _scaleChartValue(
          row.value(widget.xMetric)!,
          xMin,
          xMax,
          rect.left,
          rect.right,
        ),
        _scaleChartValue(
          row.value(widget.yMetric)!,
          yMin,
          yMax,
          rect.bottom,
          rect.top,
        ),
      );
      final distance = (point - position).distance;
      if (distance < best) {
        best = distance;
        nearest = row;
      }
    }
    return best <= 18 ? nearest : null;
  }

  void _hover(PointerHoverEvent event, Size size) {
    final next = _nearest(event.localPosition, size);
    if (next?.player == _hovered?.player && next == null) return;
    setState(() {
      _hovered = next;
      if (next != null) _pointer = event.localPosition;
    });
  }

  void _tap(TapDownDetails details, Size size) {
    final next = _nearest(details.localPosition, size);
    setState(() {
      _pinned = next;
      _hovered = next;
      _pointer = next == null ? null : details.localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered ?? _pinned;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final pointer = _pointer ?? Offset(size.width * .62, 72);
        final tooltipWidth =
            widget.chart == _ChartType.bubble ? 276.0 : 244.0;
        final tooltipLeft = (pointer.dx + 14)
            .clamp(12.0, math.max(12.0, size.width - tooltipWidth - 12))
            .toDouble();
        final tooltipTop = (pointer.dy - 32)
            .clamp(12.0, math.max(12.0, size.height - 140))
            .toDouble();

        return MouseRegion(
          cursor: _inspectable
              ? SystemMouseCursors.precise
              : SystemMouseCursors.basic,
          onHover: (event) => _hover(event, size),
          onExit: (_) => setState(() => _hovered = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _inspectable ? (details) => _tap(details, size) : null,
            onScaleStart: _xy ? _scaleStart : null,
            onScaleUpdate: _xy ? (details) => _scaleUpdate(details, size) : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NbaChartPainter(
                      rows: widget.rows,
                      chart: widget.chart,
                      xMetric: widget.xMetric,
                      yMetric: widget.yMetric,
                      sizeMetric: widget.sizeMetric,
                      groupBy: widget.groupBy,
                      engine: widget.engine,
                      colorScheme: widget.colorScheme,
                      textStyle: widget.textStyle,
                      showLabels: widget.showLabels,
                      showTrendLine: widget.showTrendLine,
                      showMeans: widget.showMeans,
                      showGrid: widget.showGrid,
                      showZeroLine: widget.showZeroLine,
                      showOutliers: widget.showOutliers,
                      labelDensity: widget.labelDensity,
                      histogramBins: widget.histogramBins,
                      highlightedPlayer: active?.player,
                      viewport: _viewport(),
                    ),
                  ),
                ),
                if (_xy)
                  Positioned(
                    right: 14,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: widget.colorScheme.surface.withValues(alpha: .86),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: widget.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        _pinned == null
                            ? 'Hover/click to inspect · use +/− to zoom'
                            : 'Pinned · click another point to replace',
                        style: TextStyle(
                          color: widget.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (_xy)
                  Positioned(
                    left: 82,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.colorScheme.surface.withValues(alpha: .94),
                        border: Border.all(color: widget.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Zoom out',
                            icon: const Icon(Icons.remove, size: 17),
                            onPressed: _zoom <= 1
                                ? null
                                : () => _zoomTo(_zoom / 1.5, _plotRect(size).center, size),
                          ),
                          Text('${_zoom.toStringAsFixed(1)}×',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          IconButton(
                            tooltip: 'Zoom in',
                            icon: const Icon(Icons.add, size: 17),
                            onPressed: _zoom >= 16
                                ? null
                                : () => _zoomTo(_zoom * 1.5, _plotRect(size).center, size),
                          ),
                          TextButton(
                            onPressed: _zoom == 1 ? null : _resetViewport,
                            child: const Text('Reset view'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (active != null && _inspectable)
                  Positioned(
                    left: tooltipLeft,
                    top: tooltipTop,
                    child: IgnorePointer(
                      child: Container(
                        width: tooltipWidth,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: widget.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.colorScheme.outlineVariant,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x24000000),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: _visualColorForRow(
                                      active,
                                      widget.groupBy,
                                      widget.colorScheme,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    active.player,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            if (_studioTeams(active).isNotEmpty)
                              Text(
                                'Teams: ${_studioTeams(active).join(', ')} · ${active.position}',
                                maxLines: 2,
                                style: TextStyle(
                                  color: widget.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              )
                            else
                              FutureBuilder<List<String>>(
                                future: _teamsFor(active),
                                builder: (context, snapshot) => Text(
                                  'Teams: ${snapshot.data == null
                                      ? 'Loading…'
                                      : snapshot.data!.isEmpty
                                          ? 'Team stints unavailable'
                                          : snapshot.data!.join(', ')} · ${active.position}',
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: widget.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (_xy) ...[
                                  Expanded(
                                    child: _TooltipMetric(
                                      label: widget.engine.metric(widget.xMetric).shortLabel,
                                      value: widget.engine.formatValue(
                                        widget.xMetric,
                                        active.value(widget.xMetric),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: _TooltipMetric(
                                    label: widget.engine
                                        .metric(widget.yMetric)
                                        .shortLabel,
                                    value: widget.engine.formatValue(
                                      widget.yMetric,
                                      active.value(widget.yMetric),
                                    ),
                                  ),
                                ),
                                if (widget.chart == _ChartType.bubble) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _TooltipMetric(
                                      label:
                                          'SIZE · ${widget.engine.metric(widget.sizeMetric).shortLabel}',
                                      value: widget.engine.formatValue(
                                        widget.sizeMetric,
                                        active.value(widget.sizeMetric),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TooltipMetric extends StatelessWidget {
  const _TooltipMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      );
}

class _StudioViewport {
  const _StudioViewport({
    required this.xMin, required this.xMax,
    required this.yMin, required this.yMax,
  });
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
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
    required this.showGrid,
    required this.showZeroLine,
    required this.showOutliers,
    required this.labelDensity,
    required this.histogramBins,
    this.highlightedPlayer,
    this.viewport,
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
  final bool showGrid;
  final bool showZeroLine;
  final bool showOutliers;
  final String labelDensity;
  final int histogramBins;
  final String? highlightedPlayer;
  final _StudioViewport? viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      72,
      28,
      math.max(10.0, size.width - 104),
      math.max(10.0, size.height - 88),
    );

    switch (chart) {
      case _ChartType.scatter:
        _paintXY(canvas, rect, bubbles: false);
      case _ChartType.bubble:
        _paintXY(canvas, rect, bubbles: true);
      case _ChartType.bar:
        _paintBars(canvas, rect);
      case _ChartType.histogram:
        _paintHistogram(canvas, rect);
      case _ChartType.box:
        _paintBox(canvas, rect);
      case _ChartType.cumulative:
        _paintCumulative(canvas, rect);
      case _ChartType.radar:
        _paintRadar(canvas, rect);
    }
  }

  void _paintXY(
    Canvas canvas,
    Rect rect, {
    required bool bubbles,
  }) {
    final valid = rows
        .where(
          (row) =>
              row.value(xMetric) != null &&
              row.value(yMetric) != null &&
              row.value(xMetric)!.isFinite &&
              row.value(yMetric)!.isFinite,
        )
        .toList(growable: false);
    if (valid.isEmpty) return;

    final xs = valid.map((row) => row.value(xMetric)!).toList();
    final ys = valid.map((row) => row.value(yMetric)!).toList();
    final xRange = _paddedChartRange(xs, percentage: _studioPercent(xMetric));
    final yRange = _paddedChartRange(ys, percentage: _studioPercent(yMetric));
    final xMin = viewport?.xMin ?? xRange.$1;
    final xMax = viewport?.xMax ?? xRange.$2;
    final yMin = viewport?.yMin ?? yRange.$1;
    final yMax = viewport?.yMax ?? yRange.$2;

    _paintXYGrid(
      canvas,
      rect,
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
    );

    if (showMeans && valid.length > 1) {
      final meanX = xs.reduce((a, b) => a + b) / xs.length;
      final meanY = ys.reduce((a, b) => a + b) / ys.length;
      final meanPaint = Paint()
        ..color = colorScheme.onSurfaceVariant.withValues(alpha: .46)
        ..strokeWidth = 1;
      final x = _scaleChartValue(meanX, xMin, xMax, rect.left, rect.right);
      final y = _scaleChartValue(meanY, yMin, yMax, rect.bottom, rect.top);
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), meanPaint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), meanPaint);
    }

    if (showTrendLine && valid.length > 1) {
      final summary = _RegressionSummary.fromRows(valid, xMetric, yMetric);
      if (summary.count >= 2 && summary.slope.isFinite) {
        final yAtMin = summary.intercept + summary.slope * xMin;
        final yAtMax = summary.intercept + summary.slope * xMax;
        canvas.save();
        canvas.clipRect(rect);
        canvas.drawLine(
          Offset(
            rect.left,
            _scaleChartValue(yAtMin, yMin, yMax, rect.bottom, rect.top),
          ),
          Offset(
            rect.right,
            _scaleChartValue(yAtMax, yMin, yMax, rect.bottom, rect.top),
          ),
          Paint()
            ..color = colorScheme.tertiary
            ..strokeWidth = 2.1,
        );
        canvas.restore();
      }
    }

    // Rank labels by statistical prominence, then place them after the points
    // to avoid masking marks and overlapping nearby player names.
    final labelCandidates = <NbaStatsRow>[];
    final seen = <String>{};
    void include(Iterable<NbaStatsRow> candidates) {
      for (final row in candidates) {
        if (seen.add(row.playerId)) labelCandidates.add(row);
      }
    }
    if (showLabels) {
      if (highlightedPlayer != null) {
        include(valid.where((row) => row.player == highlightedPlayer));
      }
      final byY = [...valid]..sort(
        (a, b) => b.value(yMetric)!.compareTo(a.value(yMetric)!));
      final byX = [...valid]..sort(
        (a, b) => b.value(xMetric)!.compareTo(a.value(xMetric)!));
      if (labelDensity == 'All' || valid.length <= 20) {
        include(byY);
      } else {
        final high = labelDensity == 'Selective' ? 7 : 15;
        include(byY.take(high));
        include(byX.take(high));
        include(byY.reversed.take(labelDensity == 'Selective' ? 2 : 6));
        include(byX.reversed.take(labelDensity == 'Selective' ? 2 : 5));
        if (bubbles) {
          final bySize = [...valid]..sort(
            (a, b) => (b.value(sizeMetric) ?? 0)
                .compareTo(a.value(sizeMetric) ?? 0));
          include(bySize.take(labelDensity == 'Selective' ? 4 : 9));
        }
      }
    }

    final bubbleValues = bubbles
        ? valid.map((item) => item.value(sizeMetric))
            .whereType<double>().toList(growable: false)
        : const <double>[];
    Offset chartPoint(NbaStatsRow row) => Offset(
      _scaleChartValue(row.value(xMetric)!, xMin, xMax, rect.left, rect.right),
      _scaleChartValue(row.value(yMetric)!, yMin, yMax, rect.bottom, rect.top),
    );
    double radiusFor(NbaStatsRow row) => bubbles
        ? _bubbleRadius(row.value(sizeMetric), bubbleValues)
        : 5.8;

    canvas.save();
    canvas.clipRect(rect);
    for (final row in valid) {
      final point = chartPoint(row);
      if (!rect.inflate(-2).contains(point)) continue;
      final color = _visualColorForRow(row, groupBy, colorScheme);
      final radius = radiusFor(row);
      final highlighted = row.player == highlightedPlayer;
      if (highlighted) {
        canvas.drawCircle(
          point, radius + 5,
          Paint()..color = color.withValues(alpha: .16),
        );
        canvas.drawCircle(
          point, radius + 2.2,
          Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8,
        );
      }
      canvas.drawCircle(point, radius, Paint()
        ..color = color.withValues(alpha: highlighted ? 1 : (bubbles ? .76 : .90)));
    }

    final placedLabels = <Rect>[];
    for (final row in labelCandidates) {
      final point = chartPoint(row);
      if (!rect.contains(point)) continue;
      final label = _shortLabel(row.player);
      final measure = TextPainter(
        text: TextSpan(text: label,
          style: textStyle.copyWith(fontSize: 11.7, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 180);
      final width = measure.width + 5;
      final height = measure.height + 3;
      measure.dispose();
      final radius = radiusFor(row);
      final offsets = <Offset>[
        Offset(radius + 6, -height - 2),
        Offset(-width - radius - 6, -height - 2),
        Offset(radius + 6, 3),
        Offset(-width - radius - 6, 3),
        Offset(-width / 2, -height - radius - 7),
      ];
      Rect? chosen;
      for (final offset in offsets) {
        final candidate = Rect.fromLTWH(
          point.dx + offset.dx, point.dy + offset.dy, width, height);
        if (!rect.deflate(3).contains(candidate.topLeft) ||
            !rect.deflate(3).contains(candidate.bottomRight)) continue;
        if (placedLabels.any((other) => other.inflate(3).overlaps(candidate))) {
          continue;
        }
        chosen = candidate;
        break;
      }
      if (chosen == null) continue;
      placedLabels.add(chosen);
      _text(canvas, label, chosen.topLeft + const Offset(2, 1),
        colorScheme.onSurface, small: true,
        background: colorScheme.surface.withValues(alpha: .87));
    }
    canvas.restore();
  }

  void _paintXYGrid(
    Canvas canvas,
    Rect rect, {
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
  }) {
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: .42)
      ..strokeWidth = .8;
    final axisPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1.1;

    for (final xValue in _studioTicks(xMin, xMax, percentage: _studioPercent(xMetric))) {
      final x = _scaleChartValue(xValue, xMin, xMax, rect.left, rect.right);
      if (showGrid) canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
      _text(canvas, _studioTickLabel(xValue, xMetric),
        Offset((x - 18).clamp(4.0, rect.right - 35).toDouble(), rect.bottom + 11),
        colorScheme.onSurfaceVariant, tiny: true);
    }
    for (final yValue in _studioTicks(yMin, yMax, percentage: _studioPercent(yMetric))) {
      final y = _scaleChartValue(yValue, yMin, yMax, rect.bottom, rect.top);
      if (showGrid) canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      _text(canvas, _studioTickLabel(yValue, yMetric), Offset(6, y - 7),
        colorScheme.onSurfaceVariant, tiny: true);
    }
    if (showZeroLine) {
      final zero = Paint()..color = colorScheme.onSurfaceVariant.withValues(alpha: .52)..strokeWidth = 1.4;
      if (xMin <= 0 && xMax >= 0) {
        final x = _scaleChartValue(0, xMin, xMax, rect.left, rect.right);
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), zero);
      }
      if (yMin <= 0 && yMax >= 0) {
        final y = _scaleChartValue(0, yMin, yMax, rect.bottom, rect.top);
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), zero);
      }
    }
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, axisPaint);
    canvas.drawLine(rect.bottomLeft, rect.topLeft, axisPaint);

    _text(
      canvas,
      engine.metric(yMetric).shortLabel,
      Offset(8, rect.top - 18),
      colorScheme.onSurfaceVariant,
      bold: true,
    );
    _text(
      canvas,
      engine.metric(xMetric).shortLabel,
      Offset(rect.right - 28, rect.bottom + 34),
      colorScheme.onSurfaceVariant,
      bold: true,
    );
  }

  void _paintBars(Canvas canvas, Rect rect) {
    final valid = rows
        .where((row) => row.value(yMetric) != null)
        .toList(growable: false);
    if (valid.isEmpty) return;

    final values = valid.map((row) => row.value(yMetric)!).toList();
    final minValue = math.min(0.0, values.reduce(math.min)).toDouble();
    final maxValue = math.max(0.0, values.reduce(math.max)).toDouble();
    final labelWidth = math.min(190.0, rect.width * .22).toDouble();
    final valueWidth = 58.0;
    final barLeft = rect.left + labelWidth;
    final barRight = rect.right - valueWidth;
    final zeroX = _scaleChartValue(
      0,
      minValue,
      maxValue == minValue ? minValue + 1 : maxValue,
      barLeft,
      barRight,
    );
    final rowHeight = rect.height / valid.length;

    for (var index = 0; index < valid.length; index++) {
      final row = valid[index];
      final value = row.value(yMetric)!;
      final y = rect.top + index * rowHeight;
      final centerY = y + rowHeight * .5;
      final valueX = _scaleChartValue(
        value,
        minValue,
        maxValue == minValue ? minValue + 1 : maxValue,
        barLeft,
        barRight,
      );
      final left = math.min(zeroX, valueX).toDouble();
      final width = math.max(1.5, (valueX - zeroX).abs()).toDouble();
      final color = _visualColorForRow(row, groupBy, colorScheme);

      if (index.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(rect.left, y, rect.width, rowHeight),
          Paint()
            ..color =
                colorScheme.surfaceContainerHighest.withValues(alpha: .12),
        );
      }
      _text(
        canvas,
        '${index + 1}. ${_shortLabel(row.player)} · ${row.team}',
        Offset(rect.left + 2, centerY - 7),
        colorScheme.onSurface,
        small: true,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left,
            centerY - rowHeight * .22,
            width,
            rowHeight * .44,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = color.withValues(alpha: .88),
      );
      _text(
        canvas,
        engine.formatValue(yMetric, value),
        Offset(barRight + 8, centerY - 7),
        colorScheme.onSurface,
        small: true,
        bold: true,
      );
    }

    canvas.drawLine(
      Offset(zeroX, rect.top),
      Offset(zeroX, rect.bottom),
      Paint()
        ..color = colorScheme.outlineVariant
        ..strokeWidth = 1,
    );
    _text(
      canvas,
      engine.metric(yMetric).shortLabel,
      Offset(barLeft, rect.bottom + 20),
      colorScheme.onSurfaceVariant,
      bold: true,
    );
  }

  void _paintHistogram(Canvas canvas, Rect rect) {
    final values = rows
        .map((row) => row.value(yMetric))
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);
    if (values.isEmpty) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final bins = histogramBins.clamp(6, 24).toInt();
    final counts = List<int>.filled(bins, 0);
    final span = maxValue - minValue;
    for (final value in values) {
      final raw =
          span == 0 ? 0 : ((value - minValue) / span * bins).floor();
      counts[raw.clamp(0, bins - 1).toInt()] += 1;
    }
    final maxCount = math.max(1, counts.reduce(math.max));
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: .42)
      ..strokeWidth = .8;

    for (var index = 0; index <= 4; index++) {
      final t = index / 4;
      final y = rect.bottom - rect.height * t;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      _text(
        canvas,
        '${(maxCount * t).round()}',
        Offset(22, y - 6),
        colorScheme.onSurfaceVariant,
        tiny: true,
      );
    }

    final width = rect.width / bins;
    for (var index = 0; index < bins; index++) {
      final height = rect.height * counts[index] / maxCount;
      final bar = Rect.fromLTWH(
        rect.left + index * width + 2,
        rect.bottom - height,
        math.max(2.0, width - 4).toDouble(),
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(4)),
        Paint()..color = colorScheme.primary.withValues(alpha: .76),
      );
      if (index % 2 == 0 || bins <= 8) {
        final value = minValue + span * index / bins;
        _text(
          canvas,
          engine.formatValue(yMetric, value),
          Offset(bar.left, rect.bottom + 10),
          colorScheme.onSurfaceVariant,
          tiny: true,
        );
      }
    }

    final sorted = [...values]..sort();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final median = sorted.length.isOdd
        ? sorted[sorted.length ~/ 2]
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
    final meanX = _scaleChartValue(
      mean,
      minValue,
      maxValue == minValue ? minValue + 1 : maxValue,
      rect.left,
      rect.right,
    );
    final medianX = _scaleChartValue(
      median,
      minValue,
      maxValue == minValue ? minValue + 1 : maxValue,
      rect.left,
      rect.right,
    );
    canvas.drawLine(
      Offset(meanX, rect.top),
      Offset(meanX, rect.bottom),
      Paint()
        ..color = colorScheme.tertiary
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(medianX, rect.top),
      Offset(medianX, rect.bottom),
      Paint()
        ..color = colorScheme.secondary
        ..strokeWidth = 1.2,
    );
    _text(
      canvas,
      'MEAN ${engine.formatValue(yMetric, mean)}',
      Offset(meanX + 5, rect.top + 8),
      colorScheme.tertiary,
      small: true,
      bold: true,
      background: colorScheme.surface.withValues(alpha: .78),
    );
    _text(
      canvas,
      'MEDIAN ${engine.formatValue(yMetric, median)}',
      Offset(medianX + 5, rect.top + 25),
      colorScheme.secondary,
      small: true,
      bold: true,
      background: colorScheme.surface.withValues(alpha: .78),
    );

    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomRight,
      Paint()
        ..color = colorScheme.outlineVariant
        ..strokeWidth = 1.1,
    );
    _text(
      canvas,
      'PLAYERS',
      Offset(8, rect.top - 18),
      colorScheme.onSurfaceVariant,
      bold: true,
    );
    _text(
      canvas,
      engine.metric(yMetric).shortLabel,
      Offset(rect.right - 36, rect.bottom + 34),
      colorScheme.onSurfaceVariant,
      bold: true,
    );
  }


  void _paintBox(Canvas canvas, Rect rect) {
    final groups = <String, List<double>>{};
    for (final row in rows) {
      final value = row.value(yMetric);
      if (value == null || !value.isFinite) continue;
      final position = row.position.split(RegExp(r'[-,/ ]+')).first.toUpperCase();
      final group = const ['PG', 'SG', 'SF', 'PF', 'C', 'G', 'F']
              .contains(position) ? position : 'Other';
      groups.putIfAbsent(group, () => []).add(value);
    }
    if (groups.isEmpty) return;
    const preferred = ['PG', 'SG', 'SF', 'PF', 'C', 'G', 'F', 'Other'];
    final labels = preferred.where(groups.containsKey).toList();
    final all = [for (final v in groups.values) ...v];
    final bounds = _paddedChartRange(all, percentage: _studioPercent(yMetric));
    final plot = Rect.fromLTRB(rect.left + 66, rect.top + 16,
        rect.right - 15, rect.bottom - 24);
    _paintStatAxis(canvas, plot, bounds.$1, bounds.$2);
    final height = plot.height / labels.length;
    double at(double value) => _scaleChartValue(
        value, bounds.$1, bounds.$2, plot.left, plot.right);

    for (var index = 0; index < labels.length; index++) {
      final label = labels[index];
      final numbers = [...groups[label]!]..sort();
      double quantile(double p) {
        if (numbers.length == 1) return numbers.first;
        final rank = (numbers.length - 1) * p;
        final lo = rank.floor();
        final hi = rank.ceil();
        return numbers[lo] + (numbers[hi] - numbers[lo]) * (rank - lo);
      }
      final q1 = quantile(.25);
      final median = quantile(.50);
      final q3 = quantile(.75);
      final iqr = q3 - q1;
      final lowFence = q1 - 1.5 * iqr;
      final highFence = q3 + 1.5 * iqr;
      final inliers = numbers.where((value) =>
          value >= lowFence && value <= highFence).toList();
      final low = inliers.isEmpty ? numbers.first : inliers.first;
      final high = inliers.isEmpty ? numbers.last : inliers.last;
      final centerY = plot.top + (index + .5) * height;
      final h = math.min(30.0, height * .48);
      final ink = _visualGroupColor(label, colorScheme);
      final thin = Paint()..color = ink..strokeWidth = 1.5;
      if (index.isOdd) {
        canvas.drawRect(Rect.fromLTWH(plot.left, centerY - height / 2,
            plot.width, height),
            Paint()..color = colorScheme.surfaceContainerHighest.withValues(alpha: .10));
      }
      _text(canvas, '$label · n=${numbers.length}',
          Offset(rect.left + 3, centerY - 7), colorScheme.onSurface, small: true);
      canvas.drawLine(Offset(at(low), centerY), Offset(at(high), centerY), thin);
      for (final end in [low, high]) {
        canvas.drawLine(Offset(at(end), centerY - h * .28),
            Offset(at(end), centerY + h * .28), thin);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(at(q1), centerY - h / 2,
            math.max(at(q1) + 1, at(q3)), centerY + h / 2),
        const Radius.circular(5)),
        Paint()..color = ink.withValues(alpha: .75));
      canvas.drawLine(Offset(at(median), centerY - h / 2),
          Offset(at(median), centerY + h / 2),
          Paint()..color = colorScheme.onSurface..strokeWidth = 2.5);
      if (showOutliers) {
        for (final value in numbers) {
          if (value < lowFence || value > highFence) {
            canvas.drawCircle(Offset(at(value), centerY), 3.0,
                Paint()..color = ink);
          }
        }
      }
    }
    _text(canvas, 'Boxes = 25th–75th percentile · line = median · whiskers = 1.5×IQR',
      Offset(plot.left, rect.bottom + 31), colorScheme.onSurfaceVariant, small: true);
  }

  void _paintCumulative(Canvas canvas, Rect rect) {
    final values = rows.map((row) => row.value(yMetric))
        .whereType<double>().where((v) => v.isFinite).toList()..sort();
    if (values.isEmpty) return;
    final bounds = _paddedChartRange(values, percentage: _studioPercent(yMetric));
    final plot = Rect.fromLTRB(rect.left + 4, rect.top + 10,
        rect.right - 12, rect.bottom - 12);
    _paintStatAxis(canvas, plot, bounds.$1, bounds.$2);
    final grid = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: .38)
      ..strokeWidth = .9;
    for (final percent in const [0, 25, 50, 75, 100]) {
      final y = _scaleChartValue(percent.toDouble(), 0, 100, plot.bottom, plot.top);
      if (showGrid) {
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      }
      _text(canvas, '${percent.toStringAsFixed(0)}.0%',
          Offset(3, y - 7), colorScheme.onSurfaceVariant, tiny: true);
    }
    double x(double value) => _scaleChartValue(value, bounds.$1,
        bounds.$2, plot.left, plot.right);
    double y(double count) => _scaleChartValue(count, 0,
        values.length.toDouble(), plot.bottom, plot.top);
    final line = Path()..moveTo(x(values.first), plot.bottom);
    for (var i = 0; i < values.length; i++) {
      line.lineTo(x(values[i]), y(i.toDouble()));
      line.lineTo(x(values[i]), y(i + 1.0));
    }
    canvas.save();
    canvas.clipRect(plot);
    canvas.drawPath(line, Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    final median = values[(values.length - 1) ~/ 2];
    final medianX = x(median);
    canvas.drawLine(Offset(medianX, plot.top), Offset(medianX, plot.bottom),
      Paint()..color = colorScheme.tertiary.withValues(alpha: .8)..strokeWidth = 1.4);
    canvas.restore();
    _text(canvas, 'Share of eligible players at or below each value',
      Offset(plot.left, rect.bottom + 33),
      colorScheme.onSurfaceVariant, small: true);
  }

  void _paintStatAxis(Canvas canvas, Rect plot, double min, double max) {
    final grid = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: .4)
      ..strokeWidth = .9;
    for (final value in _studioTicks(min, max,
        percentage: _studioPercent(yMetric))) {
      final x = _scaleChartValue(value, min, max, plot.left, plot.right);
      if (showGrid) {
        canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      }
      _text(canvas, _studioTickLabel(value, yMetric),
          Offset((x - 20).clamp(plot.left, plot.right - 35).toDouble(),
              plot.bottom + 12),
          colorScheme.onSurfaceVariant, tiny: true);
    }
    canvas.drawLine(plot.bottomLeft, plot.bottomRight,
        Paint()..color = colorScheme.outlineVariant..strokeWidth = 1.2);
    _text(canvas, engine.metric(yMetric).shortLabel,
        Offset(plot.right - 38, plot.bottom + 33),
        colorScheme.onSurfaceVariant, bold: true);
  }

  void _paintRadar(Canvas canvas, Rect rect) {
    final primary = rows.first;
    final comparison = rows.length > 1 ? rows[1] : null;
    const metrics = ['pts', 'reb', 'ast', 'stl', 'blk', 'ts_pct'];
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) * .42;
    final grid = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: .68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;

    for (final fraction in const [.25, .5, .75, 1.0]) {
      final path = Path();
      for (var index = 0; index < metrics.length; index++) {
        final angle =
            -math.pi / 2 + index * math.pi * 2 / metrics.length;
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

      if (fraction < 1) {
        _text(
          canvas,
          '${(fraction * 100).round()}',
          Offset(center.dx + 7, center.dy - radius * fraction - 5),
          colorScheme.onSurfaceVariant.withValues(alpha: .7),
          tiny: true,
        );
      }
    }

    Path shapeFor(NbaStatsRow row) {
      final shape = Path();
      for (var index = 0; index < metrics.length; index++) {
        final metric = metrics[index];
        final percentile = (row.percentiles[metric] ?? 0) / 100;
        final angle =
            -math.pi / 2 + index * math.pi * 2 / metrics.length;
        final point = center +
            Offset(math.cos(angle), math.sin(angle)) *
                radius *
                percentile.clamp(0, 1).toDouble();
        if (index == 0) {
          shape.moveTo(point.dx, point.dy);
        } else {
          shape.lineTo(point.dx, point.dy);
        }
      }
      shape.close();
      return shape;
    }

    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      final primaryPct = (primary.percentiles[metric] ?? 0).round();
      final comparePct = comparison == null
          ? null
          : (comparison.percentiles[metric] ?? 0).round();
      final angle =
          -math.pi / 2 + index * math.pi * 2 / metrics.length;
      final outer =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;

      canvas.drawLine(center, outer, grid);
      _text(
        canvas,
        comparison == null
            ? '${engine.metric(metric).shortLabel}  $primaryPct'
            : '${engine.metric(metric).shortLabel}  $primaryPct · $comparePct',
        outer +
            Offset(
              math.cos(angle) * 16 - 22,
              math.sin(angle) * 16 - 7,
            ),
        colorScheme.onSurfaceVariant,
        bold: true,
        small: true,
      );
    }

    if (comparison != null) {
      final compareShape = shapeFor(comparison);
      canvas.drawPath(
        compareShape,
        Paint()..color = colorScheme.tertiary.withValues(alpha: .10),
      );
      canvas.drawPath(
        compareShape,
        Paint()
          ..color = colorScheme.tertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    final primaryShape = shapeFor(primary);
    canvas.drawPath(
      primaryShape,
      Paint()
        ..color = colorScheme.primary.withValues(
          alpha: comparison == null ? .18 : .11,
        ),
    );
    canvas.drawPath(
      primaryShape,
      Paint()
        ..color = colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  double _bubbleRadius(double? value, List<double> values) {
    if (value == null || values.isEmpty) return 5.5;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    if (maxValue == minValue) return 10;
    return 5.5 +
        13.5 *
            ((value - minValue) / (maxValue - minValue))
                .clamp(0, 1)
                .toDouble();
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    Color color, {
    bool bold = false,
    bool small = false,
    bool tiny = false,
    Color? background,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: textStyle.copyWith(
          color: color,
          fontSize: tiny ? 10.2 : (small ? 11.7 : 12.5),
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 180);
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            offset.dx - 2,
            offset.dy - 1,
            painter.width + 4,
            painter.height + 2,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = background,
      );
    }
    painter.paint(canvas, offset);
  }

  String _shortLabel(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return value;
    const suffixes = {'Jr.', 'Sr.', 'II', 'III', 'IV'};
    final suffix = suffixes.contains(parts.last) && parts.length >= 3
        ? ' ${parts.last}'
        : '';
    final familyName =
        suffix.isEmpty ? parts.last : parts[parts.length - 2];
    return '${parts.first.substring(0, 1)}. $familyName$suffix';
  }

  @override
  bool shouldRepaint(covariant _NbaChartPainter oldDelegate) => true;
}

// The historical seed uses MULTI/2TM for aggregate rows. These are not
// actual team names and must never be presented as teams on inspection.
bool _studioAggregateTeam(String value) =>
    value.toUpperCase() == 'MULTI' ||
    value.toUpperCase() == 'TOT' ||
    RegExp(r'^[2-9]TM$', caseSensitive: false).hasMatch(value);

List<String> _studioTeams(NbaStatsRow row) {
  final rawTeams = row.raw['teams_played_for'];
  final values = rawTeams is List
      ? rawTeams.map((value) => value.toString()).toList()
      : (rawTeams is String && rawTeams.trim().isNotEmpty
          ? rawTeams.split(RegExp(r'[,/;]+'))
          : row.team.split(RegExp(r'[,/;]+')));
  return values
      .map((value) => value.trim())
      .where((value) =>
          value.isNotEmpty && value != '—' && !_studioAggregateTeam(value))
      .toSet()
      .toList(growable: false);
}

// Historical source rows sometimes have games but no box-score fields or
// minute denominator. Never turn absent fields/per-36 rates into chart zeros.
bool _studioHasMetric(
  NbaStatsRow row,
  String key,
  NbaStatsBasis basis,
) {
  final value = row.value(key);
  if (value == null || !value.isFinite) return false;
  if (key == 'gp') return true;

  final raw = row.raw;
  final minuteSource = raw['minutes'] ?? raw['mp'] ??
      raw['minutes_per_game'] ?? raw['mpg'];
  final minutes = minuteSource is num
      ? minuteSource.toDouble()
      : double.tryParse(minuteSource?.toString() ?? '');
  if (basis == NbaStatsBasis.per36 || basis == NbaStatsBasis.per48) {
    if (minutes == null || minutes <= 0) return false;
  }
  if (basis == NbaStatsBasis.per75 || basis == NbaStatsBasis.per100) {
    // Production can be estimated for possession rates; a source with no
    // minute/attempt information cannot support a defensible rate.
    if ((minutes ?? 0) <= 0 &&
        raw['field_goal_attempts'] == null &&
        raw['fga'] == null) return false;
  }

  const sourceFields = <String, List<String>>{
    'min': ['minutes', 'mp', 'minutes_per_game', 'mpg'],
    'pts': ['points', 'pts', 'points_per_game', 'ppg'],
    'reb': ['rebounds', 'trb', 'reb', 'rebounds_per_game', 'rpg'],
    'ast': ['assists', 'ast', 'assists_per_game', 'apg'],
    'stl': ['steals', 'stl', 'steals_per_game', 'spg'],
    'blk': ['blocks', 'blk', 'blocks_per_game', 'bpg'],
    'tov': ['turnovers', 'tov', 'turnovers_per_game'],
    'fg_pct': ['field_goals_made', 'fg', 'fgm', 'fg_pct', 'field_goal_percentage'],
    'three_pm': ['three_pointers_made', 'fg3', 'three_pm'],
    'three_pa': ['three_point_attempts', 'fg3a', 'three_pa'],
    'three_pct': ['three_pointers_made', 'three_point_percentage', 'fg3_pct'],
    'ft_pct': ['free_throws_made', 'free_throw_percentage', 'ft_pct'],
    'plus_minus': ['plus_minus'],
    'bpm': ['bpm', 'avg_bpm', 'box_plus_minus'],
  };
  final fields = sourceFields[key];
  if (fields != null && !fields.any((field) => raw[field] != null)) {
    return false;
  }
  if (key == 'ts_pct' || key == 'efg_pct') {
    return raw['points'] != null &&
        raw['field_goal_attempts'] != null ||
        raw['true_shooting_percentage'] != null ||
        raw['effective_field_goal_percentage'] != null;
  }
  if (key == 'game_score_proxy') {
    return raw['points'] != null && raw['rebounds'] != null &&
        raw['assists'] != null;
  }
  return true;
}

Color _visualColorForRow(
  NbaStatsRow row,
  String groupBy,
  ColorScheme colorScheme,
) {
  if (groupBy == 'None') return colorScheme.primary;
  final token = groupBy == 'Position' ? row.position : row.team;
  return _visualGroupColor(token, colorScheme);
}

Color _visualGroupColor(String token, ColorScheme colorScheme) {
  if (token.isEmpty) return colorScheme.primary;

  const teamColors = <String, Color>{
    'ATL': Color(0xFFE03A3E),
    'BOS': Color(0xFF007A33),
    'BKN': Color(0xFF8C8C8C),
    'BRK': Color(0xFF8C8C8C),
    'CHA': Color(0xFF1D8E9F),
    'CHI': Color(0xFFCE1141),
    'CLE': Color(0xFF860038),
    'DAL': Color(0xFF2D7DC1),
    'DEN': Color(0xFFF0B323),
    'DET': Color(0xFFC8102E),
    'GSW': Color(0xFF1D70B7),
    'HOU': Color(0xFFCE1141),
    'IND': Color(0xFFFDBB30),
    'LAC': Color(0xFFC8102E),
    'LAL': Color(0xFF8A63D2),
    'MEM': Color(0xFF6C8EBF),
    'MIA': Color(0xFFB6264F),
    'MIL': Color(0xFF2F8B57),
    'MIN': Color(0xFF5D87B5),
    'NOP': Color(0xFFC79A4A),
    'NYK': Color(0xFFF58426),
    'OKC': Color(0xFF4AA3DF),
    'ORL': Color(0xFF5AA7D9),
    'PHI': Color(0xFF3D78C5),
    'PHO': Color(0xFFE56020),
    'POR': Color(0xFFE03A3E),
    'SAC': Color(0xFF7B61A8),
    'SAS': Color(0xFFA6A6A6),
    'TOR': Color(0xFFD43B5E),
    'UTA': Color(0xFF6B63B5),
    'WAS': Color(0xFF56789A),
  };
  if (teamColors.containsKey(token)) return teamColors[token]!;

  const positionColors = <String, Color>{
    'PG': Color(0xFF5C8FDB),
    'SG': Color(0xFF4FB6A8),
    'SF': Color(0xFF7DBA57),
    'PF': Color(0xFFE1A74F),
    'C': Color(0xFF9B73D2),
    'G': Color(0xFF4FA2C6),
    'F': Color(0xFFD17C5E),
  };
  if (positionColors.containsKey(token)) return positionColors[token]!;

  final hash = token.codeUnits.fold<int>(
    17,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );
  final hue = (hash % 330).toDouble();
  return HSVColor.fromAHSV(1, hue, .58, .86).toColor();
}


bool _studioPercent(String key) => const {
  'fg_pct', 'three_pct', 'ft_pct', 'ts_pct', 'efg_pct',
  'two_pct', 'three_rate', 'ft_rate', 'scoring_load',
}.contains(key);

double _studioNiceStep(double span, {required bool percentage}) {
  final target = math.max(percentage ? 0.01 : 1.0, span.abs() / 5);
  final exponent = math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
  for (final factor in const [1.0, 2.0, 5.0, 10.0]) {
    final candidate = exponent * factor;
    if (candidate >= target) return candidate;
  }
  return exponent * 10;
}

List<double> _studioTicks(double minValue, double maxValue, {required bool percentage}) {
  if (!minValue.isFinite || !maxValue.isFinite || maxValue <= minValue) return const [];
  final step = _studioNiceStep(maxValue - minValue, percentage: percentage);
  final first = (minValue / step - 1e-8).ceil();
  final last = (maxValue / step + 1e-8).floor();
  return [
    for (var index = first; index <= last && index < first + 25; index++)
      index * step,
  ];
}

String _studioTickLabel(double value, String metric) {
  final clean = value.abs() < 0.0000001 ? 0.0 : value;
  return _studioPercent(metric)
      ? '${(clean * 100).toStringAsFixed(1)}%'
      : clean.toStringAsFixed(1);
}

(double, double) _paddedChartRange(
  List<double> values, {
  bool percentage = false,
}) {
  var minimum = values.reduce(math.min);
  var maximum = values.reduce(math.max);
  final width = maximum - minimum;
  final pad = width == 0
      ? math.max(percentage ? .01 : 1.0, minimum.abs() * .08)
      : width * .065;
  minimum -= pad;
  maximum += pad;
  final step = _studioNiceStep(maximum - minimum, percentage: percentage);
  return (
    (minimum / step).floorToDouble() * step,
    (maximum / step).ceilToDouble() * step,
  );
}

double _scaleChartValue(
  double value,
  double min,
  double max,
  double outMin,
  double outMax,
) {
  if (max == min) return (outMin + outMax) / 2;
  return outMin + (value - min) / (max - min) * (outMax - outMin);
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
    required this.showGrid,
    required this.showZeroLine,
    required this.showOutliers,
    required this.labelDensity,
    required this.histogramBins,
    required this.radarPlayer,
    required this.radarComparePlayer,
    required this.search,
    required this.populationFilterKey,
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
  final bool showGrid;
  final bool showZeroLine;
  final bool showOutliers;
  final String labelDensity;
  final int histogramBins;
  final String? radarPlayer;
  final String? radarComparePlayer;
  final String search;
  final String? populationFilterKey;

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
        'show_grid': showGrid,
        'show_zero_line': showZeroLine,
        'show_outliers': showOutliers,
        'label_density': labelDensity,
        'histogram_bins': histogramBins,
        'radar_player': radarPlayer,
        'radar_compare_player': radarComparePlayer,
        'search': search,
        'population_filter_key': populationFilterKey,
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
        minGames: (json['min_games'] as num?)?.toDouble() ?? (json['season_type'] == 'playoffs' ? 4 : 50),
        topN: (json['top_n'] as num?)?.toInt() ?? 40,
        showLabels: json['show_labels'] != false,
        showTrendLine: json['show_trend_line'] != false,
        showMeans: json['show_means'] == true,
        showGrid: json['show_grid'] != false,
        showZeroLine: json['show_zero_line'] == true,
        showOutliers: json['show_outliers'] != false,
        labelDensity: const ['Selective', 'More', 'All']
                .contains(json['label_density'])
            ? json['label_density'].toString()
            : 'More',
        histogramBins: (json['histogram_bins'] as num?)?.toInt() ?? 12,
        radarPlayer: json['radar_player']?.toString(),
        radarComparePlayer: json['radar_compare_player']?.toString(),
        search: json['search']?.toString() ?? '',
        populationFilterKey: json['population_filter_key']?.toString(),
      );
}
