import 'package:flutter/material.dart';

import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import 'nba_percentage_heat_cell.dart';
import 'website_sticky_stats_table.dart';

/// Historical player tables deliberately use the same season snapshot,
/// metric resolver, column treatment, and sticky grid as Arcside leaderboards.
class WebsitePlayerHistoryStatsTable extends StatefulWidget {
  const WebsitePlayerHistoryStatsTable({
    super.key,
    required this.playerKey,
    required this.dossierRows,
    required this.seasonType,
    this.advanced = false,
  });

  final String playerKey;
  final List<Map<String, dynamic>> dossierRows;
  final String seasonType;
  final bool advanced;

  @override
  State<WebsitePlayerHistoryStatsTable> createState() =>
      _WebsitePlayerHistoryStatsTableState();
}

class _WebsitePlayerHistoryStatsTableState
    extends State<WebsitePlayerHistoryStatsTable> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _resolver = const NbaTerminalMetricResolver();
  final _snapshots = <String, Future<NbaTerminalSeedSnapshot>>{};
  Future<List<_HistoricalRow>>? _rowsFuture;
  final _expanded = <String>{};
  final _expandedStints = <String>{};
  String _family = 'basic';
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _sort = 'season';
  bool _descending = true;

  @override
  void didUpdateWidget(covariant WebsitePlayerHistoryStatsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerKey != widget.playerKey) _snapshots.clear();
    if (oldWidget.playerKey != widget.playerKey ||
        oldWidget.seasonType != widget.seasonType ||
        !identical(oldWidget.dossierRows, widget.dossierRows)) {
      _rowsFuture = null;
    }
    if (oldWidget.playerKey != widget.playerKey ||
        oldWidget.seasonType != widget.seasonType) {
      _expandedStints.clear();
    }
  }

  Future<NbaTerminalSeedSnapshot> _snapshot(String season) =>
      _snapshots.putIfAbsent(
        '$season/${widget.seasonType}',
        () => _api.seasonSnapshot(season, seasonType: widget.seasonType),
      );

  Future<List<_HistoricalRow>> _loadRows() async {
    final source = widget.dossierRows;
    if (source.isEmpty) return const [];
    final seasons = source.map((r) => _seasonId(r['season_id']))
        .where((s) => s.isNotEmpty).toSet().toList()..sort();
    if (seasons.isEmpty) return const [];
    final snapshots = await Future.wait(
      seasons.map((s) async {
        try {
          return await _snapshot(s);
        } catch (_) {
          // A missing shard must not suppress the player's canonical dossier.
          return null;
        }
      }),
    );
    final result = <_HistoricalRow>[];
    final playerId = widget.playerKey.replaceFirst(RegExp(r'^nba_'), '');
    for (var i = 0; i < seasons.length; i++) {
      final season = seasons[i];
      final matching = source.where((row) =>
          _seasonId(row['season_id']) == season).toList();
      final normalized = snapshots[i] == null
          ? <NbaStatsRow>[]
          : _engine.buildRows(
              snapshots[i]!,
              basis: _basis,
              seasonType: widget.seasonType == 'playoffs'
                  ? NbaStatsSeasonType.playoffs
                  : NbaStatsSeasonType.regular,
            ).where((row) => _matchesPlayer(row, playerId)).toList();
      final combined = normalized.where((row) =>
          row.team.toUpperCase().contains('TM') ||
          row.raw['team_stints'] is List).toList();
      final parent = combined.isNotEmpty
          ? combined.first
          : normalized.isNotEmpty ? normalized.first : null;
      // Match only by player ID and season, never by name. Preserve historical
      // dossier rows when a season shard is absent or has incomplete coverage.
      final fallback = matching.firstWhere(
        (row) => _isCombined(row),
        orElse: () => matching.first,
      );
      result.add(_HistoricalRow(season,
          parent == null ? _fromDossier(fallback) : _withDossierValues(parent, fallback), false));
      final recorded = parent == null
          ? <NbaStatsRow>[]
          : _engine.teamStintRows(parent, basis: _basis);
      if (recorded.isNotEmpty) {
        for (final row in recorded) {
          result.add(_HistoricalRow(season, row, true));
        }
      } else if (matching.length > 1) {
        for (final row in matching.where((row) => !_isCombined(row))) {
          result.add(_HistoricalRow(season, _fromDossier(row), true));
        }
      }
    }
    return result;
  }

  bool _matchesPlayer(NbaStatsRow row, String id) {
    final values = [row.playerId, row.raw['player_key']?.toString() ?? '',
      row.raw['nba_player_id']?.toString() ?? ''];
    return values.any((value) =>
        value == id || value == 'nba_$id' || value == widget.playerKey);
  }

  bool _isCombined(Map<String, dynamic> row) {
    final team = (row['team_abbreviation'] ?? row['team_ids'] ?? '')
        .toString().toUpperCase();
    return RegExp(r'^[2-9]TM$').hasMatch(team) || team == 'TOT';
  }

  String _seasonId(Object? value) {
    final text = value?.toString().trim() ?? '';
    final match = RegExp(r'((?:19|20)\d{2})[-/]?(\d{2})').firstMatch(text);
    if (match != null) return '${match.group(1)}-${match.group(2)}';
    final year = RegExp(r'((?:19|20)\d{2})').firstMatch(text);
    if (year == null) return text;
    final start = int.parse(year.group(1)!);
    return '$start-${((start + 1) % 100).toString().padLeft(2, '0')}';
  }

  NbaStatsRow _withDossierValues(NbaStatsRow row, Map<String, dynamic> dossier) {
    final merged = <String, dynamic>{...dossier, ...row.raw};
    for (final entry in dossier.entries) {
      if (merged[entry.key] == null) merged[entry.key] = entry.value;
    }
    return NbaStatsRow(
      playerId: row.playerId,
      player: row.player,
      team: row.team,
      position: row.position,
      values: row.values,
      percentiles: row.percentiles,
      raw: merged,
      possessionsEstimated: row.possessionsEstimated,
    );
  }

  NbaStatsRow _fromDossier(Map<String, dynamic> row) {
    // Construct a snapshot-shaped row and delegate normalization to the
    // exact same workstation engine used by the Stats and Advanced Stats pages.
    final raw = <String, dynamic>{
      ...row,
      'player_id': widget.playerKey.replaceFirst(RegExp(r'^nba_'), ''),
      'player_label': row['player_name'] ?? '',
      'team_ids': row['team_abbreviation'] ?? row['team_ids'] ?? '',
      'position': row['positions'] ?? row['position'] ?? '',
      'season_type': widget.seasonType,
    };
    final snapshot = NbaTerminalSeedSnapshot.fromMap({
      'player_season_totals': [raw],
    });
    final normalized = _engine.buildRows(snapshot,
        basis: _basis,
        seasonType: widget.seasonType == 'playoffs'
            ? NbaStatsSeasonType.playoffs : NbaStatsSeasonType.regular);
    return normalized.first;
  }

  List<_HistoricalMetric> _columns() {
    final families = widget.advanced
        ? nbaTerminalStatFamilies
        : [nbaTerminalFamily('basic')];
    final family = families.firstWhere(
        (item) => item.id == _family, orElse: () => families.first);
    final columns = <_HistoricalMetric>[];
    for (final key in family.metrics) {
      columns.add(_HistoricalMetric(key, false));
      if (_expanded.contains(key)) {
        final metric = nbaTerminalMetricByKey[key];
        for (final child in family.expansionOverrides[key] ??
            metric?.children ?? const <String>[]) {
          columns.add(_HistoricalMetric(child, true));
        }
      }
    }
    if (!widget.advanced) {
      for (final key in const ['per','bpm','vorp','ts_pct']) {
        if (!columns.any((item) => item.key == key)) {
          columns.add(_HistoricalMetric(key, false));
        }
      }
    }
    return columns;
  }

  double? _value(NbaStatsRow row, String key) {
    final definition = nbaTerminalMetricByKey[key];
    final v = (definition?.engineKey == null
            ? _resolver.value(row, key)
            : row.value(definition!.engineKey!) ?? _resolver.value(row, key)) ??
        row.value(key);
    return v != null && v.isFinite ? v : null;
  }

  String _format(NbaStatsRow row, String key) {
    final metric = nbaTerminalMetricByKey[key];
    if (metric != null) {
      final value = _value(row, key);
      if (value == null) return '—';
      if (metric.format == NbaTerminalMetricFormat.feetInches) {
        final feet = value ~/ 12;
        final inches = (value % 12).round();
        return '\$feet′\$inches″';
      }
      if (metric.format == NbaTerminalMetricFormat.percent) {
        return '${(value * 100).toStringAsFixed(metric.decimals)}%';
      }
      if (metric.format == NbaTerminalMetricFormat.integer) {
        return value.round().toString();
      }
      if (metric.format == NbaTerminalMetricFormat.signed) {
        return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(metric.decimals)}';
      }
      return value.toStringAsFixed(metric.decimals);
    }
    final value = _value(row, key);
    if (value == null) return '—';
    if (key == 'bpm') {
      return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final families = widget.advanced
        ? nbaTerminalStatFamilies
        : [nbaTerminalFamily('basic')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.advanced)
              SizedBox(
                width: 245,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_family),
                  initialValue: _family,
                  decoration: const InputDecoration(labelText: 'Stat category', isDense: true),
                  items: [for (final family in families)
                    DropdownMenuItem(value: family.id, child: Text(family.label))],
                  onChanged: (next) {
                    if (next != null) setState(() {
                      _family = next;
                      _expanded.clear();
                      _sort = 'season';
                    });
                  },
                ),
              ),
            SizedBox(
              width: 155,
              child: DropdownButtonFormField<NbaStatsBasis>(
                initialValue: _basis,
                decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                items: [for (final basis in NbaStatsBasis.values)
                  DropdownMenuItem(value: basis, child: Text(basis.label))],
                onChanged: (next) {
                  if (next != null) setState(() {
                    _basis = next;
                    _rowsFuture = null;
                  });
                },
              ),
            ),
            Text('All available seasons · no GP/MPG cutoff',
              style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<_HistoricalRow>>(
          // FutureBuilder needs a stable computation across UI-only rebuilds.
          future: _rowsFuture ??= _loadRows(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) return Text('Unable to load player statistics: ${snapshot.error}');
              return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
            }
            final all = snapshot.data!;
            if (all.isEmpty) return const Text('No source-backed statistics are available.');
            final parents = all.where((r) => !r.child).toList();
            final columns = _columns();
            double? sortValue(_HistoricalRow row) => _value(row.row, _sort);
            parents.sort((a,b) {
              if (_sort == 'season') {
                return _descending ? b.season.compareTo(a.season) : a.season.compareTo(b.season);
              }
              final av = sortValue(a), bv = sortValue(b);
              if (av == null && bv == null) return b.season.compareTo(a.season);
              if (av == null) return 1;
              if (bv == null) return -1;
              return _descending ? bv.compareTo(av) : av.compareTo(bv);
            });
            final visible = <_HistoricalRow>[];
            for (final parent in parents) {
              visible.add(parent);
              if (_expandedStints.contains(parent.season)) {
                visible.addAll(all.where((r) => r.child && r.season == parent.season));
              }
            }
            final colors = Theme.of(context).colorScheme;
            final tint = Color.alphaBlend(colors.primary.withValues(alpha: .10), colors.surface);
            final tableColumns = <WebsiteStickyStatsColumn>[
              WebsiteStickyStatsColumn(label: const Text('Season'), width: 92,
                onTap: () => setState(() {
                  if (_sort == 'season') _descending = !_descending;
                  else { _sort = 'season'; _descending = true; }
                })),
              const WebsiteStickyStatsColumn(label: Text('Team'), width: 62),
              const WebsiteStickyStatsColumn(label: Text('Position'), width: 76),
              for (final item in columns)
                WebsiteStickyStatsColumn(
                  label: InkWell(
                    onTap: () {
                      if ((nbaTerminalMetricByKey[item.key]?.children ?? const <String>[]).isNotEmpty ||
                          families.firstWhere((f) => f.id == _family,
                            orElse: () => families.first)
                              .expansionOverrides.containsKey(item.key)) {
                        setState(() {
                          if (!_expanded.add(item.key)) _expanded.remove(item.key);
                        });
                      }
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!item.child && ((nbaTerminalMetricByKey[item.key]?.children ?? const <String>[]).isNotEmpty ||
                          families.firstWhere((f) => f.id == _family,
                            orElse: () => families.first).expansionOverrides.containsKey(item.key)))
                        Icon(_expanded.contains(item.key)
                            ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, size: 23),
                      Text(nbaTerminalMetricByKey[item.key]?.shortLabel ?? item.key.toUpperCase(),
                        maxLines: 1),
                    ]),
                  ),
                  width: ((nbaTerminalMetricByKey[item.key]?.shortLabel.length ?? item.key.length) * 7 + 35)
                      .clamp(item.child ? 62.0 : 67.0, 190.0).toDouble(),
                  numeric: true,
                  backgroundColor: item.child
                      ? colors.primaryContainer.withValues(alpha: .28) : null,
                  onTap: () => setState(() {
                    if (_sort == item.key) _descending = !_descending;
                    else { _sort = item.key; _descending = true; }
                  }),
                ),
            ];
            final rows = <List<Widget>>[
              for (final entry in visible) [
                Row(children: [
                  if (!entry.child && all.any((r) => r.child && r.season == entry.season))
                    InkWell(
                      onTap: () => setState(() {
                        if (!_expandedStints.add(entry.season)) _expandedStints.remove(entry.season);
                      }),
                      child: Icon(_expandedStints.contains(entry.season)
                          ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, size: 24),
                    )
                  else if (entry.child) const SizedBox(width: 16),
                  Flexible(child: Text(entry.child ? '↳ ${entry.season}' : entry.season,
                      overflow: TextOverflow.ellipsis)),
                ]),
                Text(entry.row.team, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(entry.row.position, maxLines: 1, overflow: TextOverflow.ellipsis),
                for (final item in columns)
                  Align(alignment: Alignment.centerRight,
                    child: Builder(builder: (context) {
                      final value = _value(entry.row, item.key);
                      final text = Text(_format(entry.row, item.key), maxLines: 1,
                        overflow: TextOverflow.ellipsis);
                      final heat = nbaPercentageHeatMetricForKey(item.key);
                      return heat == null ? text : NbaPercentageHeatCell(
                        metric: heat, value: value, child: text);
                    }),
                  ),
              ],
            ];
            return WebsiteStickyStatsTable(
              columns: tableColumns,
              rows: rows,
              rowBackgrounds: [for (final row in visible) row.child ? tint : null],
              firstColumnWidth: 92,
              headerHeight: widget.advanced ? 46 : 43,
              rowHeight: 40,
              maxBodyHeight: 1800,
            );
          },
        ),
      ],
    );
  }
}

class _HistoricalRow {
  const _HistoricalRow(this.season, this.row, this.child);
  final String season;
  final NbaStatsRow row;
  final bool child;
}

class _HistoricalMetric {
  const _HistoricalMetric(this.key, this.child);
  final String key;
  final bool child;
}
