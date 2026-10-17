import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/nba_with_without_repository.dart';
import '../services/website_nba_api_service.dart';

class WebsiteNbaWithWithoutScreen extends StatefulWidget {
  const WebsiteNbaWithWithoutScreen({super.key});

  @override
  State<WebsiteNbaWithWithoutScreen> createState() =>
      _WebsiteNbaWithWithoutScreenState();
}

class _WebsiteNbaWithWithoutScreenState
    extends State<WebsiteNbaWithWithoutScreen> {
  static const _defaultMetrics = <String>{
    'pts',
    'ast',
    'reb',
    'tov',
    'ts_pct',
    'fta',
    'three_pct',
    'plus_minus',
  };

  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _splits = NbaWithWithoutRepository();

  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _team = '';
  String? _playerOne;
  String? _playerTwo;
  final Set<String> _metrics = Set<String>.from(_defaultMetrics);
  late Future<_WithWithoutData> _future;
  _WithWithoutData? _lastData;
  final Map<String, NbaTerminalSeedSnapshot> _snapshotCache = {};
  final Map<String, _WithWithoutData> _dataCache = {};
  int _loadSerial = 0;

  static const _metricChoices = <String>[
    'pts',
    'ast',
    'reb',
    'stl',
    'blk',
    'tov',
    'fg_pct',
    'three_pm',
    'three_pct',
    'fta',
    'ft_pct',
    'ts_pct',
    'efg_pct',
    'plus_minus',
    'bpm',
  ];

  @override
  void initState() {
    super.initState();
    _future = _initialize();
  }

  Future<_WithWithoutData> _initialize() async {
    _seasons = await _api.seasons();
    if (_seasons.isNotEmpty && !_seasons.any((item) => item.id == _season)) {
      _season = _seasons.first.id;
    }
    return _load();
  }

  String _datasetKey(String season, NbaStatsSeasonType type) =>
      '$season/${type.name}';

  String _dataKey(String season, NbaStatsSeasonType type, NbaStatsBasis basis) =>
      '$season/${type.name}/${basis.name}';

  Future<_WithWithoutData> _load() async {
    final serial = ++_loadSerial;
    final season = _season;
    final type = _seasonType;
    final basis = _basis;
    final rawKey = _datasetKey(season, type);
    final cacheKey = _dataKey(season, type, basis);
    final old = _dataCache[cacheKey];
    if (old != null) {
      if (serial == _loadSerial) _reconcileSelection(old);
      return old;
    }
    var snapshot = _snapshotCache[rawKey];
    snapshot ??= await _api.seasonSnapshot(
      season,
      seasonType: type == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
    );
    _snapshotCache[rawKey] = snapshot;
    final rows = _engine.buildRows(
      snapshot, basis: basis, seasonType: type,
    )..sort((a, b) => (b.value('gp') ?? 0).compareTo(a.value('gp') ?? 0));
    final teams = <String>{};
    for (final row in rows) {
      for (final token in row.team.split(RegExp(r'[,/ ]+'))) {
        if (token.isNotEmpty && token != '—' && token != 'TOT' &&
            !RegExp(r'^\d+TM
          teams.add(token);
        }
      }
    }
    final orderedTeams = teams.toList()..sort();
    final splitSnapshot = await _splits.load(
      season,
      seasonType: type == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
    );
    final data = _WithWithoutData(
      rows: rows, teams: orderedTeams, splitSnapshot: splitSnapshot,
      season: season, seasonType: type, basis: basis,
    );
    _dataCache[cacheKey] = data;
    if (serial == _loadSerial) _reconcileSelection(data);
    return data;
  }

  void _reconcileSelection(_WithWithoutData data) {
    if (_team.isEmpty || !data.teams.contains(_team)) {
      _team = data.teams.isEmpty ? '' : data.teams.first;
    }
    final teamRows = _rowsForTeam(data.rows, _team);
    final ids = teamRows.map((row) => row.playerId).toSet();
    if (_playerOne == null || !ids.contains(_playerOne)) {
      _playerOne = teamRows.isEmpty ? null : teamRows.first.playerId;
    }
    if (_playerTwo == null || !ids.contains(_playerTwo) ||
        _playerOne == _playerTwo) {
      _playerTwo = null;
      for (final row in teamRows) {
        if (row.playerId != _playerOne) {
          _playerTwo = row.playerId;
          break;
        }
      }
    }
  }

  void _reload() => setState(() {
    final cached = _dataCache[_dataKey(_season, _seasonType, _basis)];
    if (cached != null) {
      ++_loadSerial;
      _reconcileSelection(cached);
      _lastData = cached;
      _future = Future.value(cached);
    } else {
      _future = _load();
    }
  });

  void _swapPlayers() {
    if (_playerOne == null || _playerTwo == null) return;
    setState(() {
      final first = _playerOne;
      _playerOne = _playerTwo;
      _playerTwo = first;
    });
  }

  Future<void> _customizeMetrics() async {
    final working = Set<String>.from(_metrics);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize stat line',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the statistics shown on both player cards. At least one metric stays selected.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in _metricChoices)
                      FilterChip(
                        selected: working.contains(key),
                        label: Text(_engine.metric(key).shortLabel),
                        onSelected: (selected) => setSheetState(() {
                          if (selected) {
                            working.add(key);
                          } else if (working.length > 1) {
                            working.remove(key);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setSheetState(() {
                        working
                          ..clear()
                          ..addAll(_defaultMetrics);
                      }),
                      child: const Text('Reset defaults'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, working),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() {
      _metrics
        ..clear()
        ..addAll(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WithWithoutData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          _lastData = snapshot.data!;
          return _buildPage(context, snapshot.data!);
        }
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasError) {
          return _ErrorCard(error: snapshot.error, onRetry: _reload);
        }
        if (_lastData != null) return _buildPage(context, _lastData!, busy: true);
        return const SizedBox(height: 330,
          child: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _buildPage(BuildContext context, _WithWithoutData data, {bool busy = false}) {
    final stale = busy || data.season != _season ||
        data.seasonType != _seasonType || data.basis != _basis;
    final teamRows = stale ? const <NbaStatsRow>[] : _rowsForTeam(data.rows, _team);
    final first = _find(teamRows, _playerOne);
    final second = _find(teamRows, _playerTwo);
    final firstSplit = first == null || second == null
        ? null
        : data.splitSnapshot.find(
            team: _team,
            playerId: first.playerId,
            teammateId: second.playerId,
          );
    final secondSplit = first == null || second == null
        ? null
        : data.splitSnapshot.find(
            team: _team,
            playerId: second.playerId,
            teammateId: first.playerId,
          );
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'Stat Line Shift',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analyze how a player’s production changes with and without one specific teammate.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _seasons.any((item) => item.id == _season) ? _season : null,
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
                DropdownButton<String>(
                  value: data.teams.contains(_team) ? _team : null,
                  hint: const Text('Team'),
                  items: [
                    for (final team in data.teams)
                      DropdownMenuItem(value: team, child: Text(team)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _team = value;
                      _playerOne = null;
                      _playerTwo = null;
                      if (!stale) _reconcileSelection(data);
                    });
                  },
                ),
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
                    _reload();
                  },
                ),
                DropdownButton<NbaStatsBasis>(
                  value: _basis,
                  items: [
                    for (final basis in const [
                      NbaStatsBasis.perGame,
                      NbaStatsBasis.per36,
                      NbaStatsBasis.per75,
                      NbaStatsBasis.per100,
                    ])
                      DropdownMenuItem(value: basis, child: Text(basis.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _basis = value;
                    _reload();
                  },
                ),
                FilledButton.icon(
                  onPressed: _customizeMetrics,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Customize Stats'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (stale) const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(minHeight: 3)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final firstSelector = _PlayerSelector(
                  label: 'Player 1',
                  rows: teamRows,
                  value: _playerOne,
                  excluded: _playerTwo,
                  onChanged: (value) => setState(() => _playerOne = value),
                );
                final secondSelector = _PlayerSelector(
                  label: 'Player 2',
                  rows: teamRows,
                  value: _playerTwo,
                  excluded: _playerOne,
                  onChanged: (value) => setState(() => _playerTwo = value),
                );
                final swap = OutlinedButton.icon(
                  onPressed:
                      first != null && second != null ? _swapPlayers : null,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Swap'),
                );
                return compact
                    ? Column(
                        children: [
                          firstSelector,
                          const SizedBox(height: 10),
                          swap,
                          const SizedBox(height: 10),
                          secondSelector,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: firstSelector),
                          const SizedBox(width: 14),
                          swap,
                          const SizedBox(width: 14),
                          Expanded(child: secondSelector),
                        ],
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (first == null || second == null)
          const _InfoCard(
            'Select exactly two distinct players from the same team to run the analysis.',
          )
        else ...[
          _PairContextCard(
            team: _team,
            season: _season,
            first: first,
            second: second,
            firstSplit: firstSplit,
            secondSplit: secondSplit,
            sourceAvailable: data.splitSnapshot.available,
          ),
          const SizedBox(height: 12),
          if (firstSplit == null || secondSplit == null) ...[
            _InfoCard(
              '${data.splitSnapshot.message.isEmpty ? 'Player-pair splits are not available for this selection.' : data.splitSnapshot.message} '
              'Season baselines are source-backed; pair-split values remain blank until lineup stints or play-by-play are loaded.',
            ),
            const SizedBox(height: 14),
            _SeasonBaselineComparison(first: first, second: second,
                metrics: _metrics, engine: _engine, basis: _basis),
          ] else LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _ShiftCard(
                  player: first,
                  teammate: second,
                  split: firstSplit,
                  metrics: _metrics,
                  engine: _engine,
                  basis: _basis,
                ),
                _ShiftCard(
                  player: second,
                  teammate: first,
                  split: secondSplit,
                  metrics: _metrics,
                  engine: _engine,
                  basis: _basis,
                ),
              ];
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 16),
                    cards[1],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _WithWithoutData {
  const _WithWithoutData({
    required this.rows,
    required this.teams,
    required this.splitSnapshot,
    required this.season,
    required this.seasonType,
    required this.basis,
  });

  final List<NbaStatsRow> rows;
  final List<String> teams;
  final NbaWithWithoutSnapshot splitSnapshot;
  final String season;
  final NbaStatsSeasonType seasonType;
  final NbaStatsBasis basis;
}

class _PlayerSelector extends StatelessWidget {
  const _PlayerSelector({
    required this.label,
    required this.rows,
    required this.value,
    required this.excluded,
    required this.onChanged,
  });

  final String label;
  final List<NbaStatsRow> rows;
  final String? value;
  final String? excluded;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final unique = <String, NbaStatsRow>{};
    for (final row in rows) {
      if (row.playerId != excluded) unique.putIfAbsent(row.playerId, () => row);
    }
    final safeValue = unique.containsKey(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$safeValue-${unique.keys.join(',')}'),
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final row in unique.values)
          DropdownMenuItem(
            value: row.playerId,
            child: Text('${row.player} · ${row.position}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: unique.isEmpty ? null : onChanged,
    );
  }
}

class _SeasonBaselineComparison extends StatelessWidget {
  const _SeasonBaselineComparison({
    required this.first, required this.second,
    required this.metrics, required this.engine, required this.basis,
  });
  final NbaStatsRow first;
  final NbaStatsRow second;
  final Set<String> metrics;
  final NbaStatsWorkstationEngine engine;
  final NbaStatsBasis basis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Season baseline comparison',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('These are season-level ${basis.label.toLowerCase()} statistics, not '
          'with/without splits. Pair effects cannot be calculated without lineup data.',
          style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(first.player, maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 100, child: Text('METRIC', textAlign: TextAlign.center)),
          Expanded(child: Text(second.player, textAlign: TextAlign.right, maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const Divider(height: 20),
        for (final key in metrics)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(engine.formatValue(key, first.value(key)),
                textAlign: TextAlign.left,
                style: const TextStyle(fontWeight: FontWeight.w700))),
              SizedBox(width: 100, child: Text(engine.metric(key).shortLabel,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant))),
              Expanded(child: Text(engine.formatValue(key, second.value(key)),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
      ]),
    ));
  }
}

class _PairContextCard extends StatelessWidget {
  const _PairContextCard({
    required this.team,
    required this.season,
    required this.first,
    required this.second,
    required this.firstSplit,
    required this.secondSplit,
    required this.sourceAvailable,
  });

  final String team;
  final String season;
  final NbaStatsRow first;
  final NbaStatsRow second;
  final NbaWithWithoutSplit? firstSplit;
  final NbaWithWithoutSplit? secondSplit;
  final bool sourceAvailable;

  @override
  Widget build(BuildContext context) {
    final withMinutes = firstSplit?.minutesWith ?? secondSplit?.minutesWith;
    final withoutMinutes = firstSplit?.minutesWithout;
    final smallSample = (withMinutes != null && withMinutes < 100) ||
        (withoutMinutes != null && withoutMinutes < 100);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$team · $season',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text('${first.player} ↔ ${second.player}'),
            Chip(
              avatar: Icon(
                sourceAvailable
                    ? Icons.verified_rounded
                    : Icons.hourglass_empty_rounded,
                size: 17,
              ),
              label: Text(
                sourceAvailable ? 'Lineup data loaded' : 'Awaiting lineup data',
              ),
            ),
            if (withMinutes != null)
              Text('Together: ${withMinutes.toStringAsFixed(0)} min'),
            if (smallSample)
              const Chip(
                avatar: Icon(Icons.warning_amber_rounded, size: 17),
                label: Text('Small sample'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.player,
    required this.teammate,
    required this.split,
    required this.metrics,
    required this.engine,
    required this.basis,
  });

  final NbaStatsRow player;
  final NbaStatsRow teammate;
  final NbaWithWithoutSplit? split;
  final Set<String> metrics;
  final NbaStatsWorkstationEngine engine;
  final NbaStatsBasis basis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.primaryContainer,
              child: Text(
                _initials(player.player),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              player.player,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              '${basis.label} · ${player.team}',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'With ${_shortName(teammate.player)}\n${_minutes(split?.minutesWith)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 116, child: Center(child: Text('STAT / Δ'))),
                Expanded(
                  child: Text(
                    'Without ${_shortName(teammate.player)}\n${_minutes(split?.minutesWithout)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final key in metrics) ...[
              _MetricLine(
                metricKey: key,
                metric: engine.metric(key).shortLabel,
                withValue: split?.withStats[key],
                withoutValue: split?.withoutStats[key],
                baseline: player.value(key),
                formattedWith: engine.formatValue(key, split?.withStats[key]),
                formattedWithout:
                    engine.formatValue(key, split?.withoutStats[key]),
                formattedBaseline: engine.formatValue(key, player.value(key)),
              ),
              const SizedBox(height: 9),
            ],
            const Divider(height: 24),
            Text(
              split == null
                  ? 'Season baseline is shown on every row while pair values await a source-backed lineup dataset.'
                  : 'Δ is With minus Without. Positive and negative signs describe direction only, not whether the change is favorable.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.metricKey,
    required this.metric,
    required this.withValue,
    required this.withoutValue,
    required this.baseline,
    required this.formattedWith,
    required this.formattedWithout,
    required this.formattedBaseline,
  });

  final String metricKey;
  final String metric;
  final double? withValue;
  final double? withoutValue;
  final double? baseline;
  final String formattedWith;
  final String formattedWithout;
  final String formattedBaseline;

  @override
  Widget build(BuildContext context) {
    final delta = withValue == null || withoutValue == null
        ? null
        : withValue! - withoutValue!;
    return Row(
      children: [
        Expanded(
          child: Text(
            withValue == null ? '—' : formattedWith,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          width: 116,
          child: Column(
            children: [
              Text(
                metric,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (delta != null)
                Text(
                  _formatDelta(metricKey, delta, withValue, withoutValue),
                  style: TextStyle(
                    color: delta >= 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              Text(
                'Season $formattedBaseline',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            withoutValue == null ? '—' : formattedWithout,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('With/Without unavailable: ${error ?? 'Unknown error'}'),
              const SizedBox(height: 12),
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

List<NbaStatsRow> _rowsForTeam(List<NbaStatsRow> rows, String team) {
  if (team.isEmpty) return const [];
  final unique = <String, NbaStatsRow>{};
  for (final row in rows) {
    if (row.team.split(RegExp(r'[,/ ]+')).contains(team)) {
      unique.putIfAbsent(row.playerId, () => row);
    }
  }
  return unique.values.toList(growable: false);
}

NbaStatsRow? _find(List<NbaStatsRow> rows, String? id) {
  if (id == null) return null;
  for (final row in rows) {
    if (row.playerId == id) return row;
  }
  return null;
}

String _formatDelta(
  String metricKey,
  double delta,
  double? withValue,
  double? withoutValue,
) {
  final percentMetric = metricKey.endsWith('_pct') ||
      metricKey == 'ts_pct' ||
      metricKey == 'efg_pct';
  if (percentMetric) {
    final valuesLookFractional = (withValue?.abs() ?? 0) <= 1.5 &&
        (withoutValue?.abs() ?? 0) <= 1.5;
    final points = valuesLookFractional ? delta * 100 : delta;
    return '${points >= 0 ? '+' : ''}${points.toStringAsFixed(1)} pp';
  }
  return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty);
  return parts
      .take(2)
      .map((item) => item.substring(0, 1).toUpperCase())
      .join();
}

String _shortName(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? value : parts.last;
}

String _minutes(double? value) =>
    value == null ? 'minutes unavailable' : '${value.toStringAsFixed(0)} mins';
).hasMatch(token) && token.length <= 4) {
          teams.add(token);
        }
      }
    }
    final orderedTeams = teams.toList()..sort();
    final splitSnapshot = await _splits.load(
      season,
      seasonType: type == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
    );
    final data = _WithWithoutData(
      rows: rows, teams: orderedTeams, splitSnapshot: splitSnapshot,
      season: season, seasonType: type, basis: basis,
    );
    _dataCache[cacheKey] = data;
    if (serial == _loadSerial) _reconcileSelection(data);
    return data;
  }

  void _reconcileSelection(_WithWithoutData data) {
    if (_team.isEmpty || !data.teams.contains(_team)) {
      _team = data.teams.isEmpty ? '' : data.teams.first;
    }
    final teamRows = _rowsForTeam(data.rows, _team);
    final ids = teamRows.map((row) => row.playerId).toSet();
    if (_playerOne == null || !ids.contains(_playerOne)) {
      _playerOne = teamRows.isEmpty ? null : teamRows.first.playerId;
    }
    if (_playerTwo == null || !ids.contains(_playerTwo) ||
        _playerOne == _playerTwo) {
      _playerTwo = null;
      for (final row in teamRows) {
        if (row.playerId != _playerOne) {
          _playerTwo = row.playerId;
          break;
        }
      }
    }
  }

  void _reload() => setState(() {
    final cached = _dataCache[_dataKey(_season, _seasonType, _basis)];
    if (cached != null) {
      ++_loadSerial;
      _reconcileSelection(cached);
      _lastData = cached;
      _future = Future.value(cached);
    } else {
      _future = _load();
    }
  });

  void _swapPlayers() {
    if (_playerOne == null || _playerTwo == null) return;
    setState(() {
      final first = _playerOne;
      _playerOne = _playerTwo;
      _playerTwo = first;
    });
  }

  Future<void> _customizeMetrics() async {
    final working = Set<String>.from(_metrics);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize stat line',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the statistics shown on both player cards. At least one metric stays selected.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in _metricChoices)
                      FilterChip(
                        selected: working.contains(key),
                        label: Text(_engine.metric(key).shortLabel),
                        onSelected: (selected) => setSheetState(() {
                          if (selected) {
                            working.add(key);
                          } else if (working.length > 1) {
                            working.remove(key);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setSheetState(() {
                        working
                          ..clear()
                          ..addAll(_defaultMetrics);
                      }),
                      child: const Text('Reset defaults'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, working),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() {
      _metrics
        ..clear()
        ..addAll(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WithWithoutData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          _lastData = snapshot.data!;
          return _buildPage(context, snapshot.data!);
        }
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasError) {
          return _ErrorCard(error: snapshot.error, onRetry: _reload);
        }
        if (_lastData != null) return _buildPage(context, _lastData!, busy: true);
        return const SizedBox(height: 330,
          child: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _buildPage(BuildContext context, _WithWithoutData data, {bool busy = false}) {
    final stale = busy || data.season != _season ||
        data.seasonType != _seasonType || data.basis != _basis;
    final teamRows = stale ? const <NbaStatsRow>[] : _rowsForTeam(data.rows, _team);
    final first = _find(teamRows, _playerOne);
    final second = _find(teamRows, _playerTwo);
    final firstSplit = first == null || second == null
        ? null
        : data.splitSnapshot.find(
            team: _team,
            playerId: first.playerId,
            teammateId: second.playerId,
          );
    final secondSplit = first == null || second == null
        ? null
        : data.splitSnapshot.find(
            team: _team,
            playerId: second.playerId,
            teammateId: first.playerId,
          );
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'Stat Line Shift',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analyze how a player’s production changes with and without one specific teammate.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _seasons.any((item) => item.id == _season) ? _season : null,
                  items: [
                    for (final season in _seasons)
                      DropdownMenuItem(value: season.id, child: Text(season.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _season = value;
                    _playerOne = null;
                    _playerTwo = null;
                    _reload();
                  },
                ),
                DropdownButton<String>(
                  value: data.teams.contains(_team) ? _team : null,
                  hint: const Text('Team'),
                  items: [
                    for (final team in data.teams)
                      DropdownMenuItem(value: team, child: Text(team)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _team = value;
                      _playerOne = null;
                      _playerTwo = null;
                      if (!stale) _reconcileSelection(data);
                    });
                  },
                ),
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
                    _playerOne = null;
                    _playerTwo = null;
                    _reload();
                  },
                ),
                DropdownButton<NbaStatsBasis>(
                  value: _basis,
                  items: [
                    for (final basis in const [
                      NbaStatsBasis.perGame,
                      NbaStatsBasis.per36,
                      NbaStatsBasis.per75,
                      NbaStatsBasis.per100,
                    ])
                      DropdownMenuItem(value: basis, child: Text(basis.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _basis = value;
                    _reload();
                  },
                ),
                FilledButton.icon(
                  onPressed: _customizeMetrics,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Customize Stats'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (stale) const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(minHeight: 3)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final firstSelector = _PlayerSelector(
                  label: 'Player 1',
                  rows: teamRows,
                  value: _playerOne,
                  excluded: _playerTwo,
                  onChanged: (value) => setState(() => _playerOne = value),
                );
                final secondSelector = _PlayerSelector(
                  label: 'Player 2',
                  rows: teamRows,
                  value: _playerTwo,
                  excluded: _playerOne,
                  onChanged: (value) => setState(() => _playerTwo = value),
                );
                final swap = OutlinedButton.icon(
                  onPressed:
                      first != null && second != null ? _swapPlayers : null,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Swap'),
                );
                return compact
                    ? Column(
                        children: [
                          firstSelector,
                          const SizedBox(height: 10),
                          swap,
                          const SizedBox(height: 10),
                          secondSelector,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: firstSelector),
                          const SizedBox(width: 14),
                          swap,
                          const SizedBox(width: 14),
                          Expanded(child: secondSelector),
                        ],
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (first == null || second == null)
          const _InfoCard(
            'Select exactly two distinct players from the same team to run the analysis.',
          )
        else ...[
          _PairContextCard(
            team: _team,
            season: _season,
            first: first,
            second: second,
            firstSplit: firstSplit,
            secondSplit: secondSplit,
            sourceAvailable: data.splitSnapshot.available,
          ),
          const SizedBox(height: 12),
          if (firstSplit == null || secondSplit == null) ...[
            _InfoCard(
              '${data.splitSnapshot.message.isEmpty ? 'Player-pair splits are not available for this selection.' : data.splitSnapshot.message} '
              'Season baselines are source-backed; pair-split values remain blank until lineup stints or play-by-play are loaded.',
            ),
            const SizedBox(height: 14),
            _SeasonBaselineComparison(first: first, second: second,
                metrics: _metrics, engine: _engine, basis: _basis),
          ] else LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _ShiftCard(
                  player: first,
                  teammate: second,
                  split: firstSplit,
                  metrics: _metrics,
                  engine: _engine,
                  basis: _basis,
                ),
                _ShiftCard(
                  player: second,
                  teammate: first,
                  split: secondSplit,
                  metrics: _metrics,
                  engine: _engine,
                  basis: _basis,
                ),
              ];
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 16),
                    cards[1],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _WithWithoutData {
  const _WithWithoutData({
    required this.rows,
    required this.teams,
    required this.splitSnapshot,
    required this.season,
    required this.seasonType,
    required this.basis,
  });

  final List<NbaStatsRow> rows;
  final List<String> teams;
  final NbaWithWithoutSnapshot splitSnapshot;
  final String season;
  final NbaStatsSeasonType seasonType;
  final NbaStatsBasis basis;
}

class _PlayerSelector extends StatelessWidget {
  const _PlayerSelector({
    required this.label,
    required this.rows,
    required this.value,
    required this.excluded,
    required this.onChanged,
  });

  final String label;
  final List<NbaStatsRow> rows;
  final String? value;
  final String? excluded;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final unique = <String, NbaStatsRow>{};
    for (final row in rows) {
      if (row.playerId != excluded) unique.putIfAbsent(row.playerId, () => row);
    }
    final safeValue = unique.containsKey(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$safeValue-${unique.keys.join(',')}'),
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final row in unique.values)
          DropdownMenuItem(
            value: row.playerId,
            child: Text('${row.player} · ${row.position}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: unique.isEmpty ? null : onChanged,
    );
  }
}

class _SeasonBaselineComparison extends StatelessWidget {
  const _SeasonBaselineComparison({
    required this.first, required this.second,
    required this.metrics, required this.engine, required this.basis,
  });
  final NbaStatsRow first;
  final NbaStatsRow second;
  final Set<String> metrics;
  final NbaStatsWorkstationEngine engine;
  final NbaStatsBasis basis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Season baseline comparison',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('These are season-level ${basis.label.toLowerCase()} statistics, not '
          'with/without splits. Pair effects cannot be calculated without lineup data.',
          style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(first.player, maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 100, child: Text('METRIC', textAlign: TextAlign.center)),
          Expanded(child: Text(second.player, textAlign: TextAlign.right, maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const Divider(height: 20),
        for (final key in metrics)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(engine.formatValue(key, first.value(key)),
                textAlign: TextAlign.left,
                style: const TextStyle(fontWeight: FontWeight.w700))),
              SizedBox(width: 100, child: Text(engine.metric(key).shortLabel,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant))),
              Expanded(child: Text(engine.formatValue(key, second.value(key)),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
      ]),
    ));
  }
}

class _PairContextCard extends StatelessWidget {
  const _PairContextCard({
    required this.team,
    required this.season,
    required this.first,
    required this.second,
    required this.firstSplit,
    required this.secondSplit,
    required this.sourceAvailable,
  });

  final String team;
  final String season;
  final NbaStatsRow first;
  final NbaStatsRow second;
  final NbaWithWithoutSplit? firstSplit;
  final NbaWithWithoutSplit? secondSplit;
  final bool sourceAvailable;

  @override
  Widget build(BuildContext context) {
    final withMinutes = firstSplit?.minutesWith ?? secondSplit?.minutesWith;
    final withoutMinutes = firstSplit?.minutesWithout;
    final smallSample = (withMinutes != null && withMinutes < 100) ||
        (withoutMinutes != null && withoutMinutes < 100);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$team · $season',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text('${first.player} ↔ ${second.player}'),
            Chip(
              avatar: Icon(
                sourceAvailable
                    ? Icons.verified_rounded
                    : Icons.hourglass_empty_rounded,
                size: 17,
              ),
              label: Text(
                sourceAvailable ? 'Lineup data loaded' : 'Awaiting lineup data',
              ),
            ),
            if (withMinutes != null)
              Text('Together: ${withMinutes.toStringAsFixed(0)} min'),
            if (smallSample)
              const Chip(
                avatar: Icon(Icons.warning_amber_rounded, size: 17),
                label: Text('Small sample'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.player,
    required this.teammate,
    required this.split,
    required this.metrics,
    required this.engine,
    required this.basis,
  });

  final NbaStatsRow player;
  final NbaStatsRow teammate;
  final NbaWithWithoutSplit? split;
  final Set<String> metrics;
  final NbaStatsWorkstationEngine engine;
  final NbaStatsBasis basis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.primaryContainer,
              child: Text(
                _initials(player.player),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              player.player,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              '${basis.label} · ${player.team}',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'With ${_shortName(teammate.player)}\n${_minutes(split?.minutesWith)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 116, child: Center(child: Text('STAT / Δ'))),
                Expanded(
                  child: Text(
                    'Without ${_shortName(teammate.player)}\n${_minutes(split?.minutesWithout)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final key in metrics) ...[
              _MetricLine(
                metricKey: key,
                metric: engine.metric(key).shortLabel,
                withValue: split?.withStats[key],
                withoutValue: split?.withoutStats[key],
                baseline: player.value(key),
                formattedWith: engine.formatValue(key, split?.withStats[key]),
                formattedWithout:
                    engine.formatValue(key, split?.withoutStats[key]),
                formattedBaseline: engine.formatValue(key, player.value(key)),
              ),
              const SizedBox(height: 9),
            ],
            const Divider(height: 24),
            Text(
              split == null
                  ? 'Season baseline is shown on every row while pair values await a source-backed lineup dataset.'
                  : 'Δ is With minus Without. Positive and negative signs describe direction only, not whether the change is favorable.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.metricKey,
    required this.metric,
    required this.withValue,
    required this.withoutValue,
    required this.baseline,
    required this.formattedWith,
    required this.formattedWithout,
    required this.formattedBaseline,
  });

  final String metricKey;
  final String metric;
  final double? withValue;
  final double? withoutValue;
  final double? baseline;
  final String formattedWith;
  final String formattedWithout;
  final String formattedBaseline;

  @override
  Widget build(BuildContext context) {
    final delta = withValue == null || withoutValue == null
        ? null
        : withValue! - withoutValue!;
    return Row(
      children: [
        Expanded(
          child: Text(
            withValue == null ? '—' : formattedWith,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          width: 116,
          child: Column(
            children: [
              Text(
                metric,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (delta != null)
                Text(
                  _formatDelta(metricKey, delta, withValue, withoutValue),
                  style: TextStyle(
                    color: delta >= 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              Text(
                'Season $formattedBaseline',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            withoutValue == null ? '—' : formattedWithout,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('With/Without unavailable: ${error ?? 'Unknown error'}'),
              const SizedBox(height: 12),
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

List<NbaStatsRow> _rowsForTeam(List<NbaStatsRow> rows, String team) {
  if (team.isEmpty) return const [];
  final unique = <String, NbaStatsRow>{};
  for (final row in rows) {
    if (row.team.split(RegExp(r'[,/ ]+')).contains(team)) {
      unique.putIfAbsent(row.playerId, () => row);
    }
  }
  return unique.values.toList(growable: false);
}

NbaStatsRow? _find(List<NbaStatsRow> rows, String? id) {
  if (id == null) return null;
  for (final row in rows) {
    if (row.playerId == id) return row;
  }
  return null;
}

String _formatDelta(
  String metricKey,
  double delta,
  double? withValue,
  double? withoutValue,
) {
  final percentMetric = metricKey.endsWith('_pct') ||
      metricKey == 'ts_pct' ||
      metricKey == 'efg_pct';
  if (percentMetric) {
    final valuesLookFractional = (withValue?.abs() ?? 0) <= 1.5 &&
        (withoutValue?.abs() ?? 0) <= 1.5;
    final points = valuesLookFractional ? delta * 100 : delta;
    return '${points >= 0 ? '+' : ''}${points.toStringAsFixed(1)} pp';
  }
  return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty);
  return parts
      .take(2)
      .map((item) => item.substring(0, 1).toUpperCase())
      .join();
}

String _shortName(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? value : parts.last;
}

String _minutes(double? value) =>
    value == null ? 'minutes unavailable' : '${value.toStringAsFixed(0)} mins';
