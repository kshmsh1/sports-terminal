import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/nba_player_profile_format.dart';
import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';
import 'nba_percentage_heat_cell.dart';
import 'website_sticky_stats_table.dart';

/// The same responsive, sticky-column table component used by Arcside's
/// Stats and Advanced Stats pages. Player dossiers are read from the published
/// static season records, never a second hardcoded list of advanced metrics.
class NbaPlayerProfileStatsTable extends StatefulWidget {
  const NbaPlayerProfileStatsTable({
    super.key,
    required this.rows,
    required this.family,
    this.basis = NbaStatsBasis.perGame,
  });

  final List<Map<String, dynamic>> rows;
  final NbaTerminalStatFamily family;
  final NbaStatsBasis basis;

  @override
  State<NbaPlayerProfileStatsTable> createState() =>
      _NbaPlayerProfileStatsTableState();
}

class _NbaPlayerProfileStatsTableState
    extends State<NbaPlayerProfileStatsTable> {
  final Set<String> _expanded = <String>{};
  final _resolver = const NbaTerminalMetricResolver();

  @override
  void didUpdateWidget(covariant NbaPlayerProfileStatsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.family.id != widget.family.id) _expanded.clear();
  }

  NbaPercentageHeatMetric? _heat(String key) => switch (key) {
    'fg_pct' => NbaPercentageHeatMetric.fieldGoal,
    'three_pct' => NbaPercentageHeatMetric.threePoint,
    'ft_pct' => NbaPercentageHeatMetric.freeThrow,
    'efg_pct' => NbaPercentageHeatMetric.effectiveFieldGoal,
    'ts_pct' => NbaPercentageHeatMetric.trueShooting,
    'ast_to' => NbaPercentageHeatMetric.assistTurnover,
    'box_out_pct' => NbaPercentageHeatMetric.boxOut,
    'dfg_pct' => NbaPercentageHeatMetric.defensiveFieldGoal,
    'rim_dfg_pct' => NbaPercentageHeatMetric.rimDefensiveFieldGoal,
    'three_dfg_pct' => NbaPercentageHeatMetric.threePointDefensiveFieldGoal,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 25),
        child: Text('No published player-season data is available.'),
      );
    }
    final metrics = <NbaTerminalMetric>[];
    for (final key in widget.family.metrics) {
      final metric = nbaTerminalMetricByKey[key];
      if (metric == null) continue;
      metrics.add(metric);
      if (_expanded.contains(key)) {
        for (final child in widget.family.expansionOverrides[key] ??
            metric.children) {
          final detail = nbaTerminalMetricByKey[child];
          if (detail != null && !metrics.any((m) => m.key == child)) {
            metrics.add(detail);
          }
        }
      }
    }
    final ordered = [...widget.rows]
      ..sort((a, b) =>
          (b['season_id']?.toString() ?? '').compareTo(
            a['season_id']?.toString() ?? '',
          ));
    final normalized = [
      for (final row in ordered) _PlayerSeasonValues(row, widget.basis).asRow(),
    ];
    const compact = 83.0;
    final cols = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Season'), width: 98),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 65),
      const WebsiteStickyStatsColumn(label: Text('Pos'), width: 72),
      for (final metric in metrics)
        WebsiteStickyStatsColumn(
          width: metric.shortLabel.length > 14 ? 126
              : metric.shortLabel.length > 9 ? 106 : compact,
          numeric: true,
          label: _header(context, metric),
        ),
    ];
    return WebsiteStickyStatsTable(
      key: ValueKey('${widget.family.id}:${widget.basis.name}'),
      columns: cols,
      firstColumnWidth: 98,
      headerHeight: 40,
      rowHeight: 39,
      maxBodyHeight: math.min(820, 40 + normalized.length * 39).toDouble(),
      borderRadius: 8,
      rows: [
        for (var index = 0; index < ordered.length; index++)
          [
            Text(ordered[index]['season_id']?.toString() ?? '—',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(ordered[index]['team_abbreviation']?.toString() ?? '—',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(nbaOrderedPositions(
                (ordered[index]['positions'] ??
                    ordered[index]['position'] ??
                    ordered[index]['pos'] ??
                    '').toString()),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            for (final metric in metrics)
              _metricCell(normalized[index], metric),
          ],
      ],
    );
  }

  Widget _header(BuildContext context, NbaTerminalMetric metric) {
    final children = widget.family.expansionOverrides[metric.key] ??
        metric.children;
    if (children.isEmpty) {
      return Tooltip(message: metric.label,
        child: Text(metric.shortLabel, maxLines: 1,
          overflow: TextOverflow.ellipsis));
    }
    final open = _expanded.contains(metric.key);
    return Tooltip(
      message: '${open ? 'Collapse' : 'Expand'} ${metric.label}',
      child: InkWell(
        onTap: () => setState(() {
          if (open) { _expanded.remove(metric.key); }
          else { _expanded.add(metric.key); }
        }),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(open ? Icons.arrow_drop_down_rounded :
              Icons.arrow_right_rounded, size: 20),
          Flexible(child: Text(metric.shortLabel, maxLines: 1,
            overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _metricCell(NbaStatsRow row, NbaTerminalMetric metric) {
    final text = _resolver.format(row, metric.key);
    final native = _resolver.value(row, metric.key);
    final heat = _heat(metric.key);
    if (heat == null) return Text(text, maxLines: 1,
      textAlign: TextAlign.right, overflow: TextOverflow.ellipsis);
    return NbaPercentageHeatCell(
      metric: heat,
      value: native,
      child: Text(text, maxLines: 1, textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis),
    );
  }
}

/// Provides the shared metric resolver its normal input shape. The canonical
/// dossier stores season *totals*, while the Stats default basis is per game.
/// Missing tracking measures stay null; no substitute estimates are generated.
class _PlayerSeasonValues {
  const _PlayerSeasonValues(this.raw, this.basis);
  final Map<String, dynamic> raw;
  final NbaStatsBasis basis;

  double? _first(List<String> keys) {
    for (final key in keys) {
      final item = raw[key];
      if (item is num) return item.toDouble();
      if (item is String) {
        final value = double.tryParse(item);
        if (value != null) return value;
      }
    }
    return null;
  }

  NbaStatsRow asRow() {
    final gp = _first(const ['games', 'gp']);
    final minutes = _first(const ['minutes', 'min']);
    final poss = _first(const ['possessions', 'poss', 'estimated_possessions']);
    double? scale;
    switch (basis) {
      case NbaStatsBasis.totals:
        scale = 1;
      case NbaStatsBasis.perGame:
        scale = gp == null || gp == 0 ? null : 1 / gp;
      case NbaStatsBasis.per36:
        scale = minutes == null || minutes == 0 ? null : 36 / minutes;
      case NbaStatsBasis.per48:
        scale = minutes == null || minutes == 0 ? null : 48 / minutes;
      case NbaStatsBasis.per75:
        scale = poss == null || poss == 0 ? null : 75 / poss;
      case NbaStatsBasis.per100:
        scale = poss == null || poss == 0 ? null : 100 / poss;
    }
    double? scaled(List<String> names) {
      final direct = _first(names);
      if (direct == null || scale == null) return null;
      return direct * scale;
    }
    double? ratio(List<String> numKeys, List<String> denKeys,
        List<String> sourceKeys) {
      final n = _first(numKeys);
      final d = _first(denKeys);
      if (n != null && d != null && d > 0) return n / d;
      final source = _first(sourceKeys);
      if (source == null) return null;
      return source.abs() > 1.5 ? source / 100 : source;
    }
    final pts = _first(const ['points', 'pts']);
    final fga = _first(const ['field_goal_attempts', 'fga']);
    final fta = _first(const ['free_throw_attempts', 'fta']);
    final fgm = _first(const ['field_goals_made', 'fgm', 'fg']);
    final threePm = _first(const ['three_pointers_made', 'three_pm', 'fg3']);
    final threePa = _first(const ['three_point_attempts', 'three_pa', 'fg3a']);
    final twoPm = fgm != null && threePm != null ? fgm - threePm : null;
    final twoPa = fga != null && threePa != null ? fga - threePa : null;
    final tsDen = fga != null && fta != null
        ? 2 * (fga + .44 * fta) : null;
    final values = <String, double?>{
      'gp': gp, 'age': _first(const ['age']),
      'min': scaled(const ['minutes', 'min']),
      'pts': scaled(const ['points', 'pts']),
      'reb': scaled(const ['rebounds', 'reb', 'trb']),
      'oreb': scaled(const ['offensive_rebounds', 'oreb', 'orb']),
      'dreb': scaled(const ['defensive_rebounds', 'dreb', 'drb']),
      'ast': scaled(const ['assists', 'ast']),
      'stl': scaled(const ['steals', 'stl']),
      'blk': scaled(const ['blocks', 'blk']),
      'tov': scaled(const ['turnovers', 'tov']),
      'pf': scaled(const ['personal_fouls', 'pf']),
      'fgm': scaled(const ['field_goals_made', 'fgm', 'fg']),
      'fga': scaled(const ['field_goal_attempts', 'fga']),
      'three_pm': scaled(const ['three_pointers_made','three_pm','fg3']),
      'three_pa': scaled(const ['three_point_attempts','three_pa','fg3a']),
      'two_pm': twoPm == null || scale == null ? null : twoPm * scale,
      'two_pa': twoPa == null || scale == null ? null : twoPa * scale,
      'ftm': scaled(const ['free_throws_made','ftm','ft']),
      'fta': scaled(const ['free_throw_attempts','fta']),
      'fg_pct': ratio(const ['field_goals_made','fgm','fg'],
          const ['field_goal_attempts','fga'],
          const ['fg_pct','field_goal_percentage']),
      'three_pct': ratio(const ['three_pointers_made','three_pm','fg3'],
          const ['three_point_attempts','three_pa','fg3a'],
          const ['three_pct','three_point_percentage','fg3_pct']),
      'two_pct': twoPm != null && twoPa != null && twoPa > 0
          ? twoPm / twoPa : _first(const ['two_pct']),
      'ft_pct': ratio(const ['free_throws_made','ftm','ft'],
          const ['free_throw_attempts','fta'],
          const ['ft_pct','free_throw_percentage']),
      'ts_pct': pts != null && tsDen != null && tsDen > 0
          ? pts / tsDen : _first(const ['ts_pct']),
      'efg_pct': fgm != null && threePm != null &&
          fga != null && fga > 0
          ? (fgm + .5 * threePm) / fga : _first(const ['efg_pct']),
      'bpm': _first(const ['bpm','avg_bpm']),
      'per': _first(const ['per','avg_per']),
      'vorp': _first(const ['vorp']),
      'ortg': _first(const ['ortg']),
      'drtg': _first(const ['drtg']),
      'usage': _first(const ['usage','usg_pct']),
      'ast_tov': _first(const ['ast_to']),
    };
    return NbaStatsRow(
      playerId: raw['player_key']?.toString() ??
          raw['player_id']?.toString() ?? '',
      player: raw['player_name']?.toString() ?? '',
      team: raw['team_abbreviation']?.toString() ?? '',
      position: raw['positions']?.toString() ?? '',
      values: values,
      percentiles: const {},
      raw: raw,
      possessionsEstimated: poss == null,
    );
  }
}
