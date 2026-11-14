import 'package:flutter/material.dart';

import '../services/nba_player_profile_stats.dart';
import '../services/nba_stats_metric_catalog.dart';
import '../widgets/nba_percentage_heat_cell.dart';
import '../widgets/website_sticky_stats_table.dart';

/// Uses the same shared compact, frozen-column table as Stats and Advanced
/// Stats, including expandable columns and heat-colored shooting percentages.
class NbaPlayerProfileMetricTable extends StatefulWidget {
  const NbaPlayerProfileMetricTable({
    super.key,
    required this.rows,
    required this.keys,
    this.expansions = const {},
  });
  final List<ArcsidePlayerSeasonStat> rows;
  final List<String> keys;
  final Map<String, List<String>> expansions;

  @override
  State<NbaPlayerProfileMetricTable> createState() =>
      _NbaPlayerProfileMetricTableState();
}

class _NbaPlayerProfileMetricTableState extends State<NbaPlayerProfileMetricTable> {
  static const _stats = ArcsidePlayerProfileStats();
  final _expanded = <String>{};
  String _sort = 'season';
  bool _descending = true;

  @override
  void didUpdateWidget(covariant NbaPlayerProfileMetricTable old) {
    super.didUpdateWidget(old);
    if (old.keys.join('|') != widget.keys.join('|')) _expanded.clear();
  }

  List<String> _children(String key) =>
      widget.expansions[key] ?? nbaTerminalMetricByKey[key]?.children ?? const [];

  void _toggle(String key) => setState(() {
    if (!_expanded.add(key)) _expanded.remove(key);
  });

  void _sortBy(String key) => setState(() {
    if (_sort == key) {
      _descending = !_descending;
    } else {
      _sort = key;
      _descending = true;
    }
  });

  double _width(String key) {
    final label = nbaTerminalMetricByKey[key]?.shortLabel ?? key.toUpperCase();
    final extra = _children(key).isEmpty ? 0.0 : 24.0;
    return (label.length * 7 + 25 + extra).clamp(62.0, 175.0);
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
      return const Padding(padding: EdgeInsets.all(20),
        child: Text('No player-season rows are published for this segment.'));
    }
    final visible = <String>[];
    for (final key in widget.keys) {
      if (!visible.contains(key)) visible.add(key);
      if (_expanded.contains(key)) {
        for (final child in _children(key)) {
          if (!visible.contains(child)) visible.add(child);
        }
      }
    }
    // Keep metrics present for any season (older seasons legitimately have
    // blanks). This avoids losing a stat because it isn't in the latest year.
    final available = visible.where((key) => widget.rows.any((entry) =>
      _stats.value(entry.row, key) != null ||
      (key == 'bio_country' && entry.row.raw['bio_country'] != null) ||
      (key == 'bio_college' && entry.row.raw['bio_college'] != null),
    )).toList();
    final records = [...widget.rows]..sort((a,b) {
      if (_sort == 'season') {
        final compare = a.season.compareTo(b.season);
        return _descending ? -compare : compare;
      }
      final l = _stats.value(a.row, _sort);
      final r = _stats.value(b.row, _sort);
      if (l == null && r == null) return b.season.compareTo(a.season);
      if (l == null) return 1;
      if (r == null) return -1;
      final compared = l.compareTo(r);
      return _descending ? -compared : compared;
    });
    final colors = Theme.of(context).colorScheme;
    final columns = <WebsiteStickyStatsColumn>[
      WebsiteStickyStatsColumn(label: const Text('Season'), width: 88,
        onTap: () => _sortBy('season')),
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 65),
      const WebsiteStickyStatsColumn(label: Text('Pos'), width: 67),
      for (final key in available)
        WebsiteStickyStatsColumn(
          width: _width(key),
          numeric: true,
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_children(key).isNotEmpty)
              InkWell(
                onTap: () => _toggle(key),
                child: Icon(_expanded.contains(key)
                    ? Icons.arrow_drop_down_rounded
                    : Icons.arrow_right_rounded,
                  size: 22, color: colors.primary),
              ),
            Flexible(child: Text(
              nbaTerminalMetricByKey[key]?.shortLabel ?? key.toUpperCase(),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          onTap: () => _sortBy(key),
        ),
    ];
    final tableRows = <List<Widget>>[
      for (final entry in records)
        [
          Text(entry.season, style: TextStyle(color: colors.primary,
            fontWeight: FontWeight.w700)),
          Text(entry.row.team, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(entry.row.position, maxLines: 1,
            overflow: TextOverflow.ellipsis),
          for (final key in available)
            Align(alignment: Alignment.centerRight,
              child: _valueCell(entry, key)),
        ],
    ];
    return WebsiteStickyStatsTable(
      columns: columns,
      rows: tableRows,
      firstColumnWidth: 88,
      rowHeight: 39,
      headerHeight: 44,
      maxBodyHeight: 620,
      stripeRows: true,
    );
  }

  Widget _valueCell(ArcsidePlayerSeasonStat entry, String key) {
    if (key == 'bio_country' || key == 'bio_college') {
      return Text(entry.row.raw[key]?.toString() ?? '—');
    }
    final value = _stats.value(entry.row, key);
    final formatted = _stats.format(entry.row, key);
    final heat = _heat(key);
    if (heat == null) return Text(formatted);
    return NbaPercentageHeatCell(
      metric: heat, value: value, child: Text(formatted));
  }
}
