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
  final List<_PlayerSlotState> _slots = [
    _PlayerSlotState(season: '2025-26'),
    _PlayerSlotState(season: '2025-26'),
  ];
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
      for (final slot in _slots) {
        slot.season = preferred.id;
      }
    }
    return _loadData();
  }

  Future<_ComparisonData> _loadData() async {
    final uniqueSeasons = _slots.map((slot) => slot.season).toSet().toList();
    final entries = await Future.wait([
      for (final season in uniqueSeasons) _loadSeason(season),
    ]);
    final rowsBySeason = <String, List<NbaStatsRow>>{
      for (var i = 0; i < uniqueSeasons.length; i++) uniqueSeasons[i]: entries[i],
    };

    for (var index = 0; index < _slots.length; index++) {
      final slot = _slots[index];
      final rows = rowsBySeason[slot.season] ?? const <NbaStatsRow>[];
      if (rows.isEmpty) {
        slot.playerId = null;
        continue;
      }
      if (!rows.any((row) => row.playerId == slot.playerId)) {
        slot.playerId = _defaultPlayer(rows, index);
      }
    }
    return _ComparisonData(rowsBySeason: rowsBySeason);
  }

  Future<List<NbaStatsRow>> _loadSeason(String season) async {
    final snapshot = await _api.seasonSnapshot(
      season,
      seasonType:
          _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
    );
    final rows = _engine.buildRows(
      snapshot,
      basis: _basis,
      seasonType: _seasonType,
    );
    rows.sort(
      (a, b) => (b.value('pts') ?? -1).compareTo(a.value('pts') ?? -1),
    );
    return rows;
  }

  String _defaultPlayer(List<NbaStatsRow> rows, int slotIndex) {
    final used = <String>{
      for (var i = 0; i < _slots.length; i++)
        if (i != slotIndex && _slots[i].season == _slots[slotIndex].season)
          if (_slots[i].playerId != null) _slots[i].playerId!,
    };
    return rows
        .firstWhere(
          (row) => !used.contains(row.playerId),
          orElse: () => rows.first,
        )
        .playerId;
  }

  void _reload() => setState(() => _future = _loadData());

  void _setSeason(int index, String season) {
    if (_lockSeasons) {
      for (final slot in _slots) {
        slot
          ..season = season
          ..playerId = null;
      }
    } else {
      _slots[index]
        ..season = season
        ..playerId = null;
    }
    _reload();
  }

  void _addPlayer() {
    if (_slots.length >= 5) return;
    final season = _lockSeasons ? _slots.first.season : _slots.last.season;
    setState(() {
      _slots.add(_PlayerSlotState(season: season));
      _future = _loadData();
    });
  }

  void _removePlayer(int index) {
    if (_slots.length <= 2) return;
    setState(() {
      _slots.removeAt(index);
      _future = _loadData();
    });
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
    final palette = _playerColors(colors);
    final selected = <_SelectedPlayer>[];
    for (var i = 0; i < _slots.length; i++) {
      final slot = _slots[i];
      final rows = data.rowsBySeason[slot.season] ?? const <NbaStatsRow>[];
      final row = _findRow(rows, slot.playerId);
      if (row != null) {
        selected.add(
          _SelectedPlayer(
            slotIndex: i,
            row: row,
            season: slot.season,
            color: palette[i],
          ),
        );
      }
    }
    final metrics = _categories[_category] ?? _categories['Overall']!;
    final standings = _buildStandings(selected, metrics);

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
                    'Compare two to five players within one season or across eras using the local static NBA corpus.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _slots.length < 5 ? _addPlayer : null,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(_slots.length < 5 ? 'Add player' : '5 players max'),
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
                    for (final slot in _slots) {
                      slot.playerId = null;
                    }
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
                  onSelected: (selectedValue) {
                    setState(() {
                      _lockSeasons = selectedValue;
                      if (selectedValue && _slots.isNotEmpty) {
                        final season = _slots.first.season;
                        for (final slot in _slots) {
                          slot
                            ..season = season
                            ..playerId = null;
                        }
                        _future = _loadData();
                      }
                    });
                  },
                ),
                Tooltip(
                  message:
                      'Cross-era mode lets every player use a different season. Percentiles remain relative to each player’s own season.',
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < _slots.length; index++) ...[
                SizedBox(
                  width: 300,
                  child: _PlayerSelectorCard(
                    accent: palette[index],
                    season: _slots[index].season,
                    seasons: _seasons,
                    rows: data.rowsBySeason[_slots[index].season] ??
                        const <NbaStatsRow>[],
                    selectedPlayerId: _slots[index].playerId,
                    player: _findRow(
                      data.rowsBySeason[_slots[index].season] ??
                          const <NbaStatsRow>[],
                      _slots[index].playerId,
                    ),
                    label: 'Player ${String.fromCharCode(65 + index)}',
                    canRemove: _slots.length > 2,
                    onRemove: () => _removePlayer(index),
                    onSeason: (season) => _setSeason(index, season),
                    onPlayer: (id) => setState(() => _slots[index].playerId = id),
                    onOpen: _slots[index].playerId == null
                        ? null
                        : () {
                            final row = _findRow(
                              data.rowsBySeason[_slots[index].season] ??
                                  const <NbaStatsRow>[],
                              _slots[index].playerId,
                            );
                            if (row == null) return;
                            openWebsiteNbaPlayerPage(
                              context,
                              session: widget.session,
                              playerKey: row.playerId,
                              playerName: row.player,
                            );
                          },
                  ),
                ),
                if (index != _slots.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (selected.length >= 2) ...[
          _ComparisonSummary(players: selected, standings: standings),
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
            players: selected,
            metrics: metrics,
            engine: _engine,
          ),
          const SizedBox(height: 18),
          _PercentileFingerprint(players: selected, metrics: metrics),
          const SizedBox(height: 16),
          Text(
            'The ★ marker identifies the most favorable available value for each metric among every selected player. Ties receive the marker together. Percentile bars are season-relative, so cross-era mode compares each player against the league environment of that player’s selected season.',
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

class _PlayerSlotState {
  _PlayerSlotState({required this.season, this.playerId});
  String season;
  String? playerId;
}

class _ComparisonData {
  const _ComparisonData({required this.rowsBySeason});
  final Map<String, List<NbaStatsRow>> rowsBySeason;
}

class _SelectedPlayer {
  const _SelectedPlayer({
    required this.slotIndex,
    required this.row,
    required this.season,
    required this.color,
  });
  final int slotIndex;
  final NbaStatsRow row;
  final String season;
  final Color color;
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
    required this.canRemove,
    required this.onRemove,
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
  final bool canRemove;
  final VoidCallback onRemove;
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    if (canRemove)
                      IconButton(
                        tooltip: 'Remove player',
                        onPressed: onRemove,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                if (player == null)
                  const SizedBox(
                    height: 88,
                    child: Center(child: Text('Choose a player')),
                  )
                else
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: accent.withValues(alpha: .16),
                        child: Text(
                          _initials(player!.player),
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player!.player,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${player!.team} · ${player!.position} · ${_whole(player!.value('gp'))} GP',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open player page',
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
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
  const _ComparisonSummary({required this.players, required this.standings});

  final List<_SelectedPlayer> players;
  final List<_PlayerStanding> standings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxWins = standings.isEmpty
        ? 0
        : standings.map((item) => item.wins).reduce(math.max);
    final leaders = standings.where((item) => item.wins == maxWins).toList();
    final leaderText = maxWins == 0
        ? 'No comparable metrics are available in this view.'
        : leaders.length == 1
            ? '${leaders.first.player.row.player} leads this category with $maxWins best-in-group metric${maxWins == 1 ? '' : 's'}.'
            : '${leaders.map((item) => item.player.row.player).join(', ')} are tied with $maxWins best-in-group metrics.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comparison readout',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              leaderText,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final standing in standings)
                  _SummaryChip(
                    icon: standing.wins == maxWins && maxWins > 0
                        ? Icons.workspace_premium_rounded
                        : Icons.bar_chart_rounded,
                    label:
                        '${standing.player.row.player}: ${standing.wins} best · ${standing.ties} tied',
                    color: standing.player.color,
                  ),
              ],
            ),
          ],
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
    required this.players,
    required this.metrics,
    required this.engine,
  });

  final List<_SelectedPlayer> players;
  final List<_CompareMetric> metrics;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const metricWidth = 120.0;
    const playerWidth = 174.0;
    final tableWidth = metricWidth + playerWidth * players.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(tableWidth, 620),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: colors.surfaceContainerHighest.withValues(alpha: .35),
                child: Row(
                  children: [
                    const SizedBox(
                      width: metricWidth,
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
                    for (final player in players)
                      SizedBox(
                        width: playerWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Text(
                                player.row.player,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: player.color,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                player.season,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (var index = 0; index < metrics.length; index++)
                _MetricBattleRow(
                  metric: metrics[index],
                  players: players,
                  engine: engine,
                  shaded: index.isOdd,
                  metricWidth: metricWidth,
                  playerWidth: playerWidth,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricBattleRow extends StatelessWidget {
  const _MetricBattleRow({
    required this.metric,
    required this.players,
    required this.engine,
    required this.shaded,
    required this.metricWidth,
    required this.playerWidth,
  });

  final _CompareMetric metric;
  final List<_SelectedPlayer> players;
  final NbaStatsWorkstationEngine engine;
  final bool shaded;
  final double metricWidth;
  final double playerWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final values = [for (final player in players) metric.value(player.row)];
    final winnerIndexes = metric.bestIndexes(values);
    return Container(
      color: shaded
          ? colors.surfaceContainerHighest.withValues(alpha: .14)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: metricWidth,
            child: Column(
              children: [
                Text(
                  metric.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  metric.higherIsBetter ? 'higher is better' : 'lower is better',
                  style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          for (var index = 0; index < players.length; index++)
            SizedBox(
              width: playerWidth,
              child: _MetricValueCell(
                value: values[index],
                percentile: metric.percentile(players[index].row),
                winner: winnerIndexes.contains(index),
                metric: metric,
                engine: engine,
                color: players[index].color,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricValueCell extends StatelessWidget {
  const _MetricValueCell({
    required this.value,
    required this.percentile,
    required this.winner,
    required this.metric,
    required this.engine,
    required this.color,
  });

  final double? value;
  final double? percentile;
  final bool winner;
  final _CompareMetric metric;
  final NbaStatsWorkstationEngine engine;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: winner ? color.withValues(alpha: .13) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: winner
              ? Border.all(color: color.withValues(alpha: .45))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (winner && value != null) ...[
              Icon(Icons.star_rounded, size: 17, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric.format(value, engine),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: winner ? FontWeight.w900 : FontWeight.w600,
                      color: winner ? color : null,
                    ),
                  ),
                  if (percentile != null)
                    Text(
                      '${percentile!.round()}th pct',
                      style: TextStyle(
                        fontSize: 9,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentileFingerprint extends StatelessWidget {
  const _PercentileFingerprint({
    required this.players,
    required this.metrics,
  });

  final List<_SelectedPlayer> players;
  final List<_CompareMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = metrics
        .where(
          (metric) => players.any(
            (player) => metric.percentile(player.row) != null,
          ),
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
              'Every bar is a percentile within that player’s selected season, preserving era context.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final player in players)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: player.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        player.row.player,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final metric in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PercentileMultiRow(metric: metric, players: players),
              ),
          ],
        ),
      ),
    );
  }
}

class _PercentileMultiRow extends StatelessWidget {
  const _PercentileMultiRow({required this.metric, required this.players});

  final _CompareMetric metric;
  final List<_SelectedPlayer> players;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              metric.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              for (final player in players) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        player.row.player,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: _PercentileBar(
                        value: metric.percentile(player.row),
                        color: player.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 38,
                      child: Text(
                        metric.percentile(player.row) == null
                            ? '—'
                            : '${metric.percentile(player.row)!.round()}p',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PercentileBar extends StatelessWidget {
  const _PercentileBar({required this.value, required this.color});
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: value == null ? 0 : value!.clamp(0, 100) / 100,
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

  Set<int> bestIndexes(List<double?> values) {
    final valid = <MapEntry<int, double>>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value != null && value.isFinite) valid.add(MapEntry(i, value));
    }
    if (valid.isEmpty) return const <int>{};
    var best = valid.first.value;
    for (final entry in valid.skip(1)) {
      if (higherIsBetter ? entry.value > best : entry.value < best) {
        best = entry.value;
      }
    }
    const epsilon = 0.000001;
    return {
      for (final entry in valid)
        if ((entry.value - best).abs() < epsilon) entry.key,
    };
  }

  String format(double? value, NbaStatsWorkstationEngine engine) {
    if (value == null || !value.isFinite) return '—';
    if (percent) return '${(value * 100).toStringAsFixed(1)}%';
    return engine.formatValue(key, value);
  }
}

class _PlayerStanding {
  const _PlayerStanding({
    required this.player,
    required this.wins,
    required this.ties,
  });
  final _SelectedPlayer player;
  final int wins;
  final int ties;
}

List<_PlayerStanding> _buildStandings(
  List<_SelectedPlayer> players,
  List<_CompareMetric> metrics,
) {
  final wins = List<int>.filled(players.length, 0);
  final ties = List<int>.filled(players.length, 0);
  for (final metric in metrics) {
    final values = [for (final player in players) metric.value(player.row)];
    final winners = metric.bestIndexes(values);
    if (winners.isEmpty) continue;
    final tied = winners.length > 1;
    for (final index in winners) {
      if (tied) {
        ties[index]++;
      } else {
        wins[index]++;
      }
    }
  }
  return [
    for (var i = 0; i < players.length; i++)
      _PlayerStanding(player: players[i], wins: wins[i], ties: ties[i]),
  ];
}

NbaStatsRow? _findRow(List<NbaStatsRow> rows, String? id) {
  if (id == null) return null;
  for (final row in rows) {
    if (row.playerId == id) return row;
  }
  return null;
}

List<Color> _playerColors(ColorScheme colors) => [
      colors.primary,
      colors.tertiary,
      const Color(0xFFFFB74D),
      const Color(0xFF66D9A7),
      const Color(0xFFE879F9),
    ];

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
