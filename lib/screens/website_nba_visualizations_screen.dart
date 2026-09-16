import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/website_nba_api_service.dart';

enum _ChartType {
  scatter('Scatterplot'),
  bubble('Bubble chart'),
  bar('Bar chart'),
  line('Line chart'),
  area('Area chart'),
  pie('Pie chart'),
  histogram('Histogram'),
  radar('Radar chart');

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
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();

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

  void _reload() => setState(() => _future = _loadRows());

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
    final usable = allRows.where((row) {
      if ((row.value('gp') ?? 0) < _minGames) return false;
      if (query.isNotEmpty &&
          !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) {
        return false;
      }
      return row.value(_yMetric) != null;
    }).toList();
    usable.sort(
      (a, b) => (b.value(_yMetric) ?? -99999).compareTo(a.value(_yMetric) ?? -99999),
    );
    final rows = usable.take(_topN).toList(growable: false);
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visualization Studio',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Build interactive charts from the same static player-season dataset that powers Stats and Advanced Stats.',
          style: TextStyle(color: colors.onSurfaceVariant),
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
                _LabeledControl(
                  label: 'Chart',
                  child: DropdownButton<_ChartType>(
                    value: _chart,
                    items: [
                      for (final type in _ChartType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _chart = value);
                    },
                  ),
                ),
                _LabeledControl(
                  label: 'Season',
                  child: DropdownButton<String>(
                    value: _season,
                    items: [
                      for (final season in _seasons)
                        DropdownMenuItem(value: season.id, child: Text(season.label)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _season = value;
                      _reload();
                    },
                  ),
                ),
                _LabeledControl(
                  label: 'Segment',
                  child: DropdownButton<NbaStatsSeasonType>(
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
                      _reload();
                    },
                  ),
                ),
                _LabeledControl(
                  label: 'Rate',
                  child: DropdownButton<NbaStatsBasis>(
                    value: _basis,
                    items: [
                      for (final basis in const [
                        NbaStatsBasis.perGame,
                        NbaStatsBasis.per36,
                        NbaStatsBasis.per75,
                        NbaStatsBasis.per100,
                        NbaStatsBasis.totals,
                      ])
                        DropdownMenuItem(value: basis, child: Text(basis.label)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _basis = value;
                      _reload();
                    },
                  ),
                ),
                _MetricControl(
                  label: 'X metric',
                  value: _xMetric,
                  keys: _metricKeys,
                  engine: _engine,
                  onChanged: (value) => setState(() => _xMetric = value),
                ),
                _MetricControl(
                  label: 'Y metric',
                  value: _yMetric,
                  keys: _metricKeys,
                  engine: _engine,
                  onChanged: (value) => setState(() => _yMetric = value),
                ),
                if (_chart == _ChartType.bubble)
                  _MetricControl(
                    label: 'Bubble size',
                    value: _sizeMetric,
                    keys: _metricKeys,
                    engine: _engine,
                    onChanged: (value) => setState(() => _sizeMetric = value),
                  ),
                _LabeledControl(
                  label: 'Color by',
                  child: DropdownButton<String>(
                    value: _groupBy,
                    items: const [
                      DropdownMenuItem(value: 'Team', child: Text('Team')),
                      DropdownMenuItem(value: 'Position', child: Text('Position')),
                      DropdownMenuItem(value: 'None', child: Text('None')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _groupBy = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Filter players / teams',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Minimum games: ${_minGames.round()}'),
            SizedBox(
              width: 220,
              child: Slider(
                value: _minGames,
                min: 0,
                max: 82,
                divisions: 82,
                onChanged: (value) => setState(() => _minGames = value),
              ),
            ),
            Text('Players plotted: ${math.min(_topN, usable.length)}'),
            DropdownButton<int>(
              value: _topN,
              items: const [10, 20, 30, 40, 60, 100]
                  .map((value) => DropdownMenuItem(value: value, child: Text('$value')))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _topN = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 18, 18, 12),
            child: rows.isEmpty
                ? const SizedBox(
                    height: 420,
                    child: Center(child: Text('No players match the active filters.')),
                  )
                : AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CustomPaint(
                      painter: _NbaChartPainter(
                        rows: rows,
                        chart: _chart,
                        xMetric: _xMetric,
                        yMetric: _yMetric,
                        sizeMetric: _sizeMetric,
                        groupBy: _groupBy,
                        engine: _engine,
                        colorScheme: colors,
                        textStyle: Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        _ChartReadout(
          rows: rows.take(12).toList(growable: false),
          xMetric: _xMetric,
          yMetric: _yMetric,
          engine: _engine,
        ),
      ],
    );
  }
}

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          child,
        ],
      );
}

class _MetricControl extends StatelessWidget {
  const _MetricControl({
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
  Widget build(BuildContext context) => _LabeledControl(
        label: label,
        child: DropdownButton<String>(
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
        ),
      );
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
                    DataCell(Text(engine.formatValue(xMetric, row.value(xMetric)))),
                    DataCell(Text(engine.formatValue(yMetric, row.value(yMetric)))),
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

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      62,
      20,
      math.max(10.0, size.width - 88),
      math.max(10.0, size.height - 72),
    );
    final paint = Paint()..strokeWidth = 1.2;
    paint.color = colorScheme.outlineVariant;
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.bottomLeft, rect.topLeft, paint);

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
    if (chart == _ChartType.scatter ||
        chart == _ChartType.bubble ||
        chart == _ChartType.line ||
        chart == _ChartType.area) {
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
        .where((row) => row.value(xMetric) != null && row.value(yMetric) != null)
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
      if (valid.length <= 24 || index < 12) {
        _text(
          canvas,
          _shortLabel(row.player),
          point + const Offset(6, -11),
          colorScheme.onSurface,
          small: true,
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
      _text(
        canvas,
        _shortLabel(valid[index].player),
        Offset(bar.left, rect.bottom + 8),
        colorScheme.onSurfaceVariant,
        small: true,
      );
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
    final radius = (math.min(rect.width, rect.height) * .34).toDouble();
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
      final index = raw.clamp(0, bins - 1);
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
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius * fraction;
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
              percentile.clamp(0, 1);
      canvas.drawLine(center, outer, grid);
      _text(
        canvas,
        engine.metric(metric).shortLabel,
        outer + Offset(math.cos(angle) * 10 - 10, math.sin(angle) * 10 - 6),
        colorScheme.onSurfaceVariant,
        bold: true,
        small: true,
      );
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
    _text(
      canvas,
      '${row.player} percentile profile',
      Offset(rect.left + 8, rect.top + 8),
      colorScheme.onSurface,
      bold: true,
    );
  }

  double _bubbleRadius(double? value, List<double> values) {
    if (value == null || values.isEmpty) return 5;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    if (maxValue == minValue) return 10;
    return 5 +
        15 * ((value - minValue) / (maxValue - minValue)).clamp(0, 1);
  }

  Color _colorFor(NbaStatsRow row, int index) {
    if (groupBy == 'None') return colorScheme.primary;
    final token = groupBy == 'Position' ? row.position : row.team;
    final hash = token.codeUnits.fold<int>(
          0,
          (sum, value) => sum + value * 17,
        ) +
        index;
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
