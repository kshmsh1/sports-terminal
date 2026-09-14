import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/website_nba_api_service.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaPlayerComparisonScreen extends StatefulWidget {
  const WebsiteNbaPlayerComparisonScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaPlayerComparisonScreen> createState() =>
      _WebsiteNbaPlayerComparisonScreenState();
}

class _WebsiteNbaPlayerComparisonScreenState
    extends State<WebsiteNbaPlayerComparisonScreen> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();

  List<WebsiteNbaSeason> _seasons = const [];
  String _leftSeason = '2025-26';
  String _rightSeason = '2025-26';
  String? _leftPlayerId;
  String? _rightPlayerId;
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _category = 'Overall';
  bool _lockSeasons = true;
  late Future<_ComparisonData> _future;

  @override
  void initState() {
    super.initState();
    _future = _initialize();
  }

  Future<_ComparisonData> _initialize() async {
    _seasons = await _api.seasons();
    if (_seasons.isNotEmpty) {
      final preferred = _seasons.firstWhere(
        (item) => item.id == '2025-26',
        orElse: () => _seasons.first,
      );
      _leftSeason = preferred.id;
      _rightSeason = preferred.id;
    }
    return _loadData();
  }

  Future<_ComparisonData> _loadData() async {
    final snapshots = await Future.wait([
      _api.seasonSnapshot(
        _leftSeason,
        seasonType:
            _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
      ),
      _api.seasonSnapshot(
        _rightSeason,
        seasonType:
            _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
      ),
    ]);
    final leftRows = _engine.buildRows(
      snapshots[0],
      basis: _basis,
      seasonType: _seasonType,
    );
    final rightRows = _engine.buildRows(
      snapshots[1],
      basis: _basis,
      seasonType: _seasonType,
    );
    leftRows.sort(
      (a, b) => (b.value('pts') ?? -1).compareTo(a.value('pts') ?? -1),
    );
    rightRows.sort(
      (a, b) => (b.value('pts') ?? -1).compareTo(a.value('pts') ?? -1),
    );

    if (leftRows.isNotEmpty &&
        !leftRows.any((row) => row.playerId == _leftPlayerId)) {
      _leftPlayerId = leftRows.first.playerId;
    }
    if (rightRows.isNotEmpty &&
        !rightRows.any((row) => row.playerId == _rightPlayerId)) {
      _rightPlayerId = rightRows
          .firstWhere(
            (row) => row.playerId != _leftPlayerId,
            orElse: () => rightRows.first,
          )
          .playerId;
    }
    return _ComparisonData(leftRows: leftRows, rightRows: rightRows);
  }

  void _reload() => setState(() => _future = _loadData());

  void _setLeftSeason(String season) {
    _leftSeason = season;
    if (_lockSeasons) _rightSeason = season;
    _leftPlayerId = null;
    if (_lockSeasons) _rightPlayerId = null;
    _reload();
  }

  void _setRightSeason(String season) {
    _rightSeason = season;
    if (_lockSeasons) _leftSeason = season;
    _rightPlayerId = null;
    if (_lockSeasons) _leftPlayerId = null;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ComparisonData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ComparisonLoading();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ComparisonError(error: snapshot.error, onRetry: _reload);
        }
        return _buildPage(context, snapshot.data!);
      },
    );
  }

  Widget _buildPage(BuildContext context, _ComparisonData data) {
    final colors = Theme.of(context).colorScheme;
    final left = _findRow(data.leftRows, _leftPlayerId);
    final right = _findRow(data.rightRows, _rightPlayerId);
    final metrics = _categories[_category] ?? _categories['Overall']!;
    final edge = _edgeSummary(left, right, metrics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.compare_arrows_rounded, color: colors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Player Comparison Lab',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compare players within one season or across eras using the local static NBA corpus.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<NbaStatsSeasonType>(
                  segments: const [
                    ButtonSegment(
                      value: NbaStatsSeasonType.regular,
                      label: Text('Regular Season'),
                    ),
                    ButtonSegment(
                      value: NbaStatsSeasonType.playoffs,
                      label: Text('Playoffs'),
                    ),
                  ],
                  selected: {_seasonType},
                  onSelectionChanged: (value) {
                    _seasonType = value.first;
                    _leftPlayerId = null;
                    _rightPlayerId = null;
                    _reload();
                  },
                ),
                SizedBox(
                  width: 155,
                  child: DropdownButtonFormField<NbaStatsBasis>(
                    initialValue: _basis,
                    decoration: const InputDecoration(
                      labelText: 'Rate basis',
                      isDense: true,
                    ),
                    items: [
                      for (final basis in NbaStatsBasis.values)
                        DropdownMenuItem(value: basis, child: Text(basis.label)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _basis = value;
                      _reload();
                    },
                  ),
                ),
                FilterChip(
                  selected: _lockSeasons,
                  avatar: Icon(
                    _lockSeasons ? Icons.link_rounded : Icons.link_off_rounded,
                    size: 18,
                  ),
                  label: Text(_lockSeasons ? 'Seasons linked' : 'Cross-era mode'),
                  onSelected: (selected) {
                    setState(() {
                      _lockSeasons = selected;
                      if (selected) {
                        _rightSeason = _leftSeason;
                        _rightPlayerId = null;
                        _future = _loadData();
                      }
                    });
                  },
                ),
                Tooltip(
                  message:
                      'Cross-era mode compares each player to the league environment of their own selected season.',
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 820;
            final leftCard = _PlayerSelectorCard(
              accent: colors.primary,
              season: _leftSeason,
              seasons: _seasons,
              rows: data.leftRows,
              selectedPlayerId: _leftPlayerId,
              player: left,
              label: 'Player A',
              onSeason: _setLeftSeason,
              onPlayer: (id) => setState(() => _leftPlayerId = id),
              onOpen: left == null
                  ? null
                  : () => openWebsiteNbaPlayerPage(
                        context,
                        session: widget.session,
                        playerKey: left.playerId,
                        playerName: left.player,
                      ),
            );
            final rightCard = _PlayerSelectorCard(
              accent: colors.tertiary,
              season: _rightSeason,
              seasons: _seasons,
              rows: data.rightRows,
              selectedPlayerId: _rightPlayerId,
              player: right,
              label: 'Player B',
              onSeason: _setRightSeason,
              onPlayer: (id) => setState(() => _rightPlayerId = id),
              onOpen: right == null
                  ? null
                  : () => openWebsiteNbaPlayerPage(
                        context,
                        session: widget.session,
                        playerKey: right.playerId,
                        playerName: right.player,
                      ),
            );
            if (stacked) {
              return Column(
                children: [leftCard, const SizedBox(height: 12), rightCard],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftCard),
                const SizedBox(width: 14),
                Expanded(child: rightCard),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        if (left != null && right != null) ...[
          _ComparisonSummary(left: left, right: right, edge: edge),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in _categories.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: category == _category,
                      label: Text(category),
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MetricBattleTable(
            left: left,
            right: right,
            leftSeason: _leftSeason,
            rightSeason: _rightSeason,
            metrics: metrics,
            engine: _engine,
          ),
          const SizedBox(height: 18),
          _PercentileFingerprint(left: left, right: right, metrics: metrics),
          const SizedBox(height: 16),
          Text(
            'Percentile bars are season-relative. In cross-era mode, each player is ranked against the player pool from that player’s selected season, which makes era-to-era comparison more meaningful than raw values alone.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
        ],
      ],
    );
  }
}

class _ComparisonData {
  const _ComparisonData({required this.leftRows, required this.rightRows});
  final List<NbaStatsRow> leftRows;
  final List<NbaStatsRow> rightRows;
}

class _PlayerSelectorCard extends StatelessWidget {
  const _PlayerSelectorCard({
    required this.accent,
    required this.season,
    required this.seasons,
    required this.rows,
    required this.selectedPlayerId,
    required this.player,
    required this.label,
    required this.onSeason,
    required this.onPlayer,
    required this.onOpen,
  });

  final Color accent;
  final String season;
  final List<WebsiteNbaSeason> seasons;
  final List<NbaStatsRow> rows;
  final String? selectedPlayerId;
  final NbaStatsRow? player;
  final String label;
  final ValueChanged<String> onSeason;
  final ValueChanged<String> onPlayer;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 4, color: accent),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 128,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('$label-$season'),
                        initialValue: season,
                        decoration: const InputDecoration(
                          labelText: 'Season',
                          isDense: true,
                        ),
                        items: [
                          for (final item in seasons)
                            DropdownMenuItem(value: item.id, child: Text(item.id)),
                        ],
                        onChanged: (value) {
                          if (value != null) onSeason(value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownMenu<String>(
                  key: ValueKey('$label-$season-$selectedPlayerId'),
                  initialSelection: selectedPlayerId,
                  enableFilter: true,
                  enableSearch: true,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Search player'),
                  leadingIcon: const Icon(Icons.search_rounded),
                  dropdownMenuEntries: [
                    for (final row in rows)
                      DropdownMenuEntry(
                        value: row.playerId,
                        label: '${row.player} · ${row.team}',
                      ),
                  ],
                  onSelected: (value) {
                    if (value != null) onPlayer(value);
                  },
                ),
                const SizedBox(height: 18),
                if (player == null)
                  const SizedBox(
                    height: 100,
                    child: Center(child: Text('Choose a player')),
                  )
                else
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: accent.withValues(alpha: .16),
                        child: Text(
                          _initials(player!.player),
                          style: TextStyle(
                            color: accent,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player!.player,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${player!.team} · ${player!.position} · ${_whole(player!.value('gp'))} GP',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open player page',
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new_rounded),
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

class _ComparisonSummary extends StatelessWidget {
  const _ComparisonSummary({
    required this.left,
    required this.right,
    required this.edge,
  });

  final NbaStatsRow left;
  final NbaStatsRow right;
  final _EdgeSummary edge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final headline = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Matchup readout',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  edge.text(left.player, right.player),
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
                ),
              ],
            );
            final chips = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  icon: Icons.trending_up_rounded,
                  label: '${edge.leftWins} metric edges',
                  color: colors.primary,
                ),
                _SummaryChip(
                  icon: Icons.trending_down_rounded,
                  label: '${edge.rightWins} metric edges',
                  color: colors.tertiary,
                ),
                _SummaryChip(
                  icon: Icons.balance_rounded,
                  label: '${edge.ties} ties',
                  color: colors.secondary,
                ),
                _SummaryChip(
                  icon: Icons.dataset_outlined,
                  label: '${edge.available}/${edge.total} comparable',
                  color: colors.onSurfaceVariant,
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [headline, const SizedBox(height: 14), chips],
              );
            }
            return Row(
              children: [
                Expanded(child: headline),
                const SizedBox(width: 18),
                chips,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _MetricBattleTable extends StatelessWidget {
  const _MetricBattleTable({
    required this.left,
    required this.right,
    required this.leftSeason,
    required this.rightSeason,
    required this.metrics,
    required this.engine,
  });

  final NbaStatsRow left;
  final NbaStatsRow right;
  final String leftSeason;
  final String rightSeason;
  final List<_CompareMetric> metrics;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${left.player} · $leftSeason',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 112,
                  child: Center(
                    child: Text(
                      'METRIC',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${right.player} · $rightSeason',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.tertiary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final metric in metrics)
              _MetricBattleRow(
                metric: metric,
                left: left,
                right: right,
                engine: engine,
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricBattleRow extends StatelessWidget {
  const _MetricBattleRow({
    required this.metric,
    required this.left,
    required this.right,
    required this.engine,
  });
  final _CompareMetric metric;
  final NbaStatsRow left;
  final NbaStatsRow right;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final leftValue = metric.value(left);
    final rightValue = metric.value(right);
    final winner = metric.winner(leftValue, rightValue);
    final leftPercentile = metric.percentile(left);
    final rightPercentile = metric.percentile(right);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    metric.format(leftValue, engine),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          winner == -1 ? FontWeight.w900 : FontWeight.w600,
                      color: winner == -1 ? colors.primary : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _EdgeBadge(
                  value: leftValue,
                  other: rightValue,
                  winner: winner == -1,
                  metric: metric,
                  color: colors.primary,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 112,
            child: Column(
              children: [
                Text(
                  metric.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (leftPercentile != null || rightPercentile != null)
                  Text(
                    '${leftPercentile?.round() ?? '—'}p · ${rightPercentile?.round() ?? '—'}p',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _EdgeBadge(
                  value: rightValue,
                  other: leftValue,
                  winner: winner == 1,
                  metric: metric,
                  color: colors.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metric.format(rightValue, engine),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          winner == 1 ? FontWeight.w900 : FontWeight.w600,
                      color: winner == 1 ? colors.tertiary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgeBadge extends StatelessWidget {
  const _EdgeBadge({
    required this.value,
    required this.other,
    required this.winner,
    required this.metric,
    required this.color,
  });
  final double? value;
  final double? other;
  final bool winner;
  final _CompareMetric metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final current = value;
    final comparison = other;
    if (!winner || current == null || comparison == null) {
      return const SizedBox(width: 46);
    }
    final delta = (current - comparison).abs();
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        metric.delta(delta),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PercentileFingerprint extends StatelessWidget {
  const _PercentileFingerprint({
    required this.left,
    required this.right,
    required this.metrics,
  });
  final NbaStatsRow left;
  final NbaStatsRow right;
  final List<_CompareMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = metrics
        .where(
          (metric) =>
              metric.percentile(left) != null || metric.percentile(right) != null,
        )
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Season-relative fingerprint',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Percentile context helps separate raw production from the league environment around each player.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final metric in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PercentileRow(metric: metric, left: left, right: right),
              ),
          ],
        ),
      ),
    );
  }
}

class _PercentileRow extends StatelessWidget {
  const _PercentileRow({
    required this.metric,
    required this.left,
    required this.right,
  });
  final _CompareMetric metric;
  final NbaStatsRow left;
  final NbaStatsRow right;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final leftPercentile = metric.percentile(left) ?? 0;
    final rightPercentile = metric.percentile(right) ?? 0;
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            metric.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _PercentileBar(value: leftPercentile, color: colors.primary),
              const SizedBox(height: 4),
              _PercentileBar(value: rightPercentile, color: colors.tertiary),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            '${leftPercentile.round()}p · ${rightPercentile.round()}p',
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _PercentileBar extends StatelessWidget {
  const _PercentileBar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: value.clamp(0, 100) / 100,
          minHeight: 8,
          backgroundColor: color.withValues(alpha: .10),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
}

class _CompareMetric {
  const _CompareMetric(
    this.key,
    this.label, {
    this.higherIsBetter = true,
    this.percent = false,
    this.rawAliases = const [],
  });

  final String key;
  final String label;
  final bool higherIsBetter;
  final bool percent;
  final List<String> rawAliases;

  double? value(NbaStatsRow row) {
    final direct = row.value(key);
    if (direct != null) return direct;
    for (final alias in <String>[key, ...rawAliases]) {
      final raw = _number(row.raw[alias]);
      if (raw != null) return percent && raw > 1 ? raw / 100 : raw;
    }
    return null;
  }

  double? percentile(NbaStatsRow row) => row.percentiles[key];

  int winner(double? left, double? right) {
    if (left == null || right == null) return 0;
    if ((left - right).abs() < 0.000001) return 0;
    final leftWins = higherIsBetter ? left > right : left < right;
    return leftWins ? -1 : 1;
  }

  String format(double? value, NbaStatsWorkstationEngine engine) {
    if (value == null || !value.isFinite) return '—';
    if (percent) return '${(value * 100).toStringAsFixed(1)}%';
    return engine.formatValue(key, value);
  }

  String delta(double value) =>
      percent ? (value * 100).toStringAsFixed(1) : value.toStringAsFixed(1);
}

class _EdgeSummary {
  const _EdgeSummary({
    required this.leftWins,
    required this.rightWins,
    required this.ties,
    required this.available,
    required this.total,
  });
  final int leftWins;
  final int rightWins;
  final int ties;
  final int available;
  final int total;

  String text(String left, String right) {
    if (available == 0) {
      return 'No comparable metrics are available for this category.';
    }
    if (leftWins == rightWins) {
      return '$left and $right are even across the available metrics in this view.';
    }
    final leader = leftWins > rightWins ? left : right;
    final margin = (leftWins - rightWins).abs();
    return '$leader holds the broader edge in this view, leading by $margin metric${margin == 1 ? '' : 's'} across $available comparable fields.';
  }
}

_EdgeSummary _edgeSummary(
  NbaStatsRow? left,
  NbaStatsRow? right,
  List<_CompareMetric> metrics,
) {
  if (left == null || right == null) {
    return _EdgeSummary(
      leftWins: 0,
      rightWins: 0,
      ties: 0,
      available: 0,
      total: metrics.length,
    );
  }
  var leftWins = 0;
  var rightWins = 0;
  var ties = 0;
  var available = 0;
  for (final metric in metrics) {
    final leftValue = metric.value(left);
    final rightValue = metric.value(right);
    if (leftValue == null || rightValue == null) continue;
    available++;
    final winner = metric.winner(leftValue, rightValue);
    if (winner == -1) leftWins++;
    if (winner == 1) rightWins++;
    if (winner == 0) ties++;
  }
  return _EdgeSummary(
    leftWins: leftWins,
    rightWins: rightWins,
    ties: ties,
    available: available,
    total: metrics.length,
  );
}

NbaStatsRow? _findRow(List<NbaStatsRow> rows, String? id) {
  if (id == null) return null;
  for (final row in rows) {
    if (row.playerId == id) return row;
  }
  return null;
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final count = math.min(2, words.first.length);
    return words.first.substring(0, count).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

String _whole(double? value) => value == null ? '—' : value.round().toString();

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll('%', '').trim() ?? '');
}

const _categories = <String, List<_CompareMetric>>{
  'Overall': [
    _CompareMetric('pts', 'PTS'),
    _CompareMetric('reb', 'REB'),
    _CompareMetric('ast', 'AST'),
    _CompareMetric('stl', 'STL'),
    _CompareMetric('blk', 'BLK'),
    _CompareMetric('tov', 'TOV', higherIsBetter: false),
    _CompareMetric('ts_pct', 'TS%', percent: true),
    _CompareMetric('bpm', 'BPM'),
  ],
  'Scoring': [
    _CompareMetric('pts', 'PTS'),
    _CompareMetric('fgm', 'FGM'),
    _CompareMetric('fga', 'FGA'),
    _CompareMetric('three_pm', '3PM'),
    _CompareMetric('fta', 'FTA'),
    _CompareMetric('points_per_shot', 'PTS/SA'),
    _CompareMetric('scoring_load', 'LOAD', percent: true),
  ],
  'Shooting': [
    _CompareMetric('fg_pct', 'FG%', percent: true),
    _CompareMetric('two_pct', '2P%', percent: true),
    _CompareMetric('three_pct', '3P%', percent: true),
    _CompareMetric('ft_pct', 'FT%', percent: true),
    _CompareMetric('efg_pct', 'eFG%', percent: true),
    _CompareMetric('ts_pct', 'TS%', percent: true),
    _CompareMetric('three_rate', '3PA Rate', percent: true),
    _CompareMetric('ft_rate', 'FTA Rate', percent: true),
  ],
  'Playmaking': [
    _CompareMetric('ast', 'AST'),
    _CompareMetric('tov', 'TOV', higherIsBetter: false),
    _CompareMetric('ast_tov', 'AST/TOV'),
    _CompareMetric('scoring_load', 'Scoring Load', percent: true),
  ],
  'Rebounding': [
    _CompareMetric('reb', 'REB'),
    _CompareMetric('oreb', 'OREB'),
    _CompareMetric('dreb', 'DREB'),
  ],
  'Defense': [
    _CompareMetric('stl', 'STL'),
    _CompareMetric('blk', 'BLK'),
    _CompareMetric('stocks', 'STOCKS'),
    _CompareMetric('defense_events', 'DEF EVT'),
    _CompareMetric('pf', 'PF', higherIsBetter: false),
    _CompareMetric(
      'deflections_pg',
      'Deflections',
      rawAliases: ['deflections'],
    ),
    _CompareMetric(
      'dfg_pct',
      'DFG%',
      higherIsBetter: false,
      percent: true,
      rawAliases: ['defended_fg_pct'],
    ),
    _CompareMetric(
      'rim_dfg_pct',
      'Rim DFG%',
      higherIsBetter: false,
      percent: true,
    ),
    _CompareMetric(
      'three_dfg_pct',
      '3P DFG%',
      higherIsBetter: false,
      percent: true,
    ),
  ],
  'Impact': [
    _CompareMetric('bpm', 'BPM'),
    _CompareMetric('plus_minus', '+/-'),
    _CompareMetric('game_score_proxy', 'Production'),
    _CompareMetric('ts_pct', 'TS%', percent: true),
    _CompareMetric('ast_tov', 'AST/TOV'),
  ],
};

class _ComparisonLoading extends StatelessWidget {
  const _ComparisonLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 420,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ComparisonError extends StatelessWidget {
  const _ComparisonError({required this.error, required this.onRetry});
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
                'Player comparison data unavailable',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'The comparison lab reads the same local static season shards as Stats and Advanced Stats. ${error ?? ''}',
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
