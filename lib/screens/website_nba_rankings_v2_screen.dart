import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/website_nba_api_service.dart';

class WebsiteNbaRankingsScreen extends StatefulWidget {
  const WebsiteNbaRankingsScreen({super.key});

  @override
  State<WebsiteNbaRankingsScreen> createState() =>
      _WebsiteNbaRankingsScreenState();
}

class _WebsiteNbaRankingsScreenState extends State<WebsiteNbaRankingsScreen> {
  static const _savedKey = 'nba_custom_rankings_v1';
  static const _tiers = ['S', 'A', 'B', 'C', 'D', 'E', 'F'];

  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();
  final Map<String, List<String>> _tierPlayers = {
    for (final tier in _tiers) tier: <String>[],
  };
  final List<_SavedRankingBoard> _saved = [];

  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  String _statOne = 'pts';
  String _statTwo = 'tov';
  String _positionFilter = 'All';
  String _poolSort = 'Minutes';
  bool _showStats = true;
  String? _activeBoardId;
  late Future<List<NbaStatsRow>> _future;

  static const _statChoices = [
    'pts',
    'reb',
    'ast',
    'stl',
    'blk',
    'tov',
    'fg_pct',
    'three_pm',
    'three_pct',
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
      basis: NbaStatsBasis.perGame,
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
                (item) => _SavedRankingBoard.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              ),
        );
    } catch (_) {
      // Saved boards are local convenience state.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedKey,
      jsonEncode([for (final item in _saved) item.toJson()]),
    );
  }

  void _reloadRows() => setState(() => _future = _loadRows());

  void _move(String playerId, String tier, {String? beforeId}) {
    setState(() {
      for (final values in _tierPlayers.values) {
        values.remove(playerId);
      }
      final target = _tierPlayers[tier]!;
      final beforeIndex = beforeId == null ? -1 : target.indexOf(beforeId);
      if (beforeIndex >= 0) {
        target.insert(beforeIndex, playerId);
      } else {
        target.add(playerId);
      }
    });
  }

  void _nudge(String tier, String playerId, int delta) {
    setState(() {
      final values = _tierPlayers[tier]!;
      final index = values.indexOf(playerId);
      if (index < 0) return;
      final next = (index + delta).clamp(0, values.length - 1);
      if (next == index) return;
      values.removeAt(index);
      values.insert(next, playerId);
    });
  }

  void _toPool(String playerId) {
    setState(() {
      for (final values in _tierPlayers.values) {
        values.remove(playerId);
      }
    });
  }

  void _clearBoard() {
    setState(() {
      for (final values in _tierPlayers.values) {
        values.clear();
      }
      _activeBoardId = null;
    });
  }

  void _autoSeed(List<NbaStatsRow> rows) {
    final candidates = rows
        .where((row) => row.value(_statOne) != null)
        .toList()
      ..sort(
        (a, b) => (b.value(_statOne) ?? double.negativeInfinity)
            .compareTo(a.value(_statOne) ?? double.negativeInfinity),
      );
    final seeded = candidates.take(_tiers.length * 5).toList(growable: false);
    setState(() {
      for (final values in _tierPlayers.values) {
        values.clear();
      }
      for (var index = 0; index < seeded.length; index++) {
        final tierIndex = index ~/ 5;
        _tierPlayers[_tiers[tierIndex]]!.add(seeded[index].playerId);
      }
      _activeBoardId = null;
    });
  }

  Future<void> _saveBoard({bool saveAs = false}) async {
    if (!saveAs && _activeBoardId != null) {
      final index = _saved.indexWhere((item) => item.id == _activeBoardId);
      if (index >= 0) {
        _saved[index] = _capture(
          id: _saved[index].id,
          name: _saved[index].name,
        );
        await _persist();
        if (mounted) setState(() {});
        return;
      }
    }
    if (_saved.length >= 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can save up to 10 ranking boards.')),
      );
      return;
    }
    final controller = TextEditingController(
      text: 'NBA Rankings ${_saved.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save ranking board'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Board name'),
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
    _activeBoardId = id;
    await _persist();
    if (mounted) setState(() {});
  }

  _SavedRankingBoard _capture({required String id, required String name}) =>
      _SavedRankingBoard(
        id: id,
        name: name,
        season: _season,
        seasonType: _seasonType.name,
        statOne: _statOne,
        statTwo: _statTwo,
        showStats: _showStats,
        tiers: {
          for (final entry in _tierPlayers.entries)
            entry.key: List<String>.from(entry.value),
        },
      );

  void _apply(_SavedRankingBoard board) {
    setState(() {
      _season = board.season;
      _seasonType = NbaStatsSeasonType.values.firstWhere(
        (value) => value.name == board.seasonType,
        orElse: () => NbaStatsSeasonType.regular,
      );
      _statOne = _statChoices.contains(board.statOne) ? board.statOne : 'pts';
      _statTwo = _statChoices.contains(board.statTwo) ? board.statTwo : 'tov';
      _showStats = board.showStats;
      for (final tier in _tiers) {
        _tierPlayers[tier]!
          ..clear()
          ..addAll(board.tiers[tier] ?? const []);
      }
      _activeBoardId = board.id;
      _future = _loadRows();
    });
  }

  Future<void> _deleteSaved(_SavedRankingBoard board) async {
    _saved.removeWhere((item) => item.id == board.id);
    if (_activeBoardId == board.id) _activeBoardId = null;
    await _persist();
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
              child: Text('Rankings player pool unavailable: ${snapshot.error}'),
            ),
          );
        }
        return _buildPage(context, snapshot.data!);
      },
    );
  }

  Widget _buildPage(BuildContext context, List<NbaStatsRow> rows) {
    final byId = {for (final row in rows) row.playerId: row};
    for (final values in _tierPlayers.values) {
      values.removeWhere((id) => !byId.containsKey(id));
    }
    final ranked = _tierPlayers.values.expand((value) => value).toSet();
    final rankById = <String, int>{};
    var rank = 1;
    for (final tier in _tiers) {
      for (final id in _tierPlayers[tier]!) {
        rankById[id] = rank++;
      }
    }

    final query = _search.text.trim().toLowerCase();
    final pool = rows.where((row) {
      if (ranked.contains(row.playerId)) return false;
      if (!_matchesPosition(row.position, _positionFilter)) return false;
      if (query.isNotEmpty &&
          !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
    pool.sort((a, b) {
      if (_poolSort == 'Name') return a.player.compareTo(b.player);
      final key = _poolSort == 'Stat 1' ? _statOne : 'min';
      return (b.value(key) ?? double.negativeInfinity)
          .compareTo(a.value(key) ?? double.negativeInfinity);
    });
    final visiblePool = pool.take(160).toList(growable: false);
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'Player Rankings',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Build ordered tiers, drag players into exact positions, and save the board locally.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _season,
                  items: [
                    for (final season in _seasons)
                      DropdownMenuItem(value: season.id, child: Text(season.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _season = value;
                    _clearBoard();
                    _reloadRows();
                  },
                ),
                SegmentedButton<NbaStatsSeasonType>(
                  segments: const [
                    ButtonSegment(
                      value: NbaStatsSeasonType.regular,
                      label: Text('Regular'),
                    ),
                    ButtonSegment(
                      value: NbaStatsSeasonType.playoffs,
                      label: Text('Playoffs'),
                    ),
                  ],
                  selected: {_seasonType},
                  onSelectionChanged: (value) {
                    _seasonType = value.first;
                    _clearBoard();
                    _reloadRows();
                  },
                ),
                _StatDropdown(
                  label: 'Stat 1',
                  value: _statOne,
                  engine: _engine,
                  onChanged: (value) => setState(() => _statOne = value),
                ),
                _StatDropdown(
                  label: 'Stat 2',
                  value: _statTwo,
                  engine: _engine,
                  onChanged: (value) => setState(() => _statTwo = value),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Show stats'),
                    Switch(
                      value: _showStats,
                      onChanged: (value) => setState(() => _showStats = value),
                    ),
                  ],
                ),
                Chip(
                  avatar: const Icon(Icons.format_list_numbered_rounded, size: 17),
                  label: Text('${ranked.length} ranked'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearBoard,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Clear'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _autoSeed(rows),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    'Auto-seed by ${_engine.metric(_statOne).shortLabel}',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _saveBoard(),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveBoard(saveAs: true),
                  icon: const Icon(Icons.save_as_outlined),
                  label: const Text('Save As'),
                ),
              ],
            ),
          ),
        ),
        if (_saved.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final board in _saved)
                InputChip(
                  selected: board.id == _activeBoardId,
                  label: Text(board.name),
                  onPressed: () => _apply(board),
                  onDeleted: () => _deleteSaved(board),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final board = _TierBoard(
              tiers: _tierPlayers,
              byId: byId,
              rankById: rankById,
              statOne: _statOne,
              statTwo: _statTwo,
              showStats: _showStats,
              engine: _engine,
              onMove: _move,
              onNudge: _nudge,
              onRemove: _toPool,
            );
            final playerPool = _PlayerPool(
              rows: visiblePool,
              totalRows: pool.length,
              statOne: _statOne,
              statTwo: _statTwo,
              showStats: _showStats,
              engine: _engine,
              positionFilter: _positionFilter,
              poolSort: _poolSort,
              search: _search,
              onPosition: (value) => setState(() => _positionFilter = value),
              onSort: (value) => setState(() => _poolSort = value),
              onSearch: () => setState(() {}),
              onAdd: (id) => _move(id, 'S'),
            );
            if (constraints.maxWidth < 980) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  board,
                  const SizedBox(height: 18),
                  playerPool,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: board),
                const SizedBox(width: 18),
                SizedBox(width: 360, child: playerPool),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatDropdown extends StatelessWidget {
  const _StatDropdown({
    required this.label,
    required this.value,
    required this.engine,
    required this.onChanged,
  });
  final String label;
  final String value;
  final NbaStatsWorkstationEngine engine;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: '),
          DropdownButton<String>(
            value: value,
            items: [
              for (final key in _WebsiteNbaRankingsScreenState._statChoices)
                DropdownMenuItem(
                  value: key,
                  child: Text(engine.metric(key).shortLabel),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ],
      );
}

class _TierBoard extends StatelessWidget {
  const _TierBoard({
    required this.tiers,
    required this.byId,
    required this.rankById,
    required this.statOne,
    required this.statTwo,
    required this.showStats,
    required this.engine,
    required this.onMove,
    required this.onNudge,
    required this.onRemove,
  });

  final Map<String, List<String>> tiers;
  final Map<String, NbaStatsRow> byId;
  final Map<String, int> rankById;
  final String statOne;
  final String statTwo;
  final bool showStats;
  final NbaStatsWorkstationEngine engine;
  final void Function(String playerId, String tier, {String? beforeId}) onMove;
  final void Function(String tier, String playerId, int delta) onNudge;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final tier in _WebsiteNbaRankingsScreenState._tiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TierLane(
                tier: tier,
                playerIds: tiers[tier] ?? const [],
                byId: byId,
                rankById: rankById,
                statOne: statOne,
                statTwo: statTwo,
                showStats: showStats,
                engine: engine,
                onMove: onMove,
                onNudge: onNudge,
                onRemove: onRemove,
              ),
            ),
        ],
      );
}

class _TierLane extends StatelessWidget {
  const _TierLane({
    required this.tier,
    required this.playerIds,
    required this.byId,
    required this.rankById,
    required this.statOne,
    required this.statTwo,
    required this.showStats,
    required this.engine,
    required this.onMove,
    required this.onNudge,
    required this.onRemove,
  });

  final String tier;
  final List<String> playerIds;
  final Map<String, NbaStatsRow> byId;
  final Map<String, int> rankById;
  final String statOne;
  final String statTwo;
  final bool showStats;
  final NbaStatsWorkstationEngine engine;
  final void Function(String playerId, String tier, {String? beforeId}) onMove;
  final void Function(String tier, String playerId, int delta) onNudge;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(tier);
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onMove(details.data, tier),
      builder: (context, candidate, rejected) => Container(
        constraints: const BoxConstraints(minHeight: 102),
        decoration: BoxDecoration(
          color: candidate.isNotEmpty
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: .22)
              : Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tierColor,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(11)),
              ),
              child: Text(
                tier,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: playerIds.isEmpty
                    ? Center(
                        child: Text(
                          'Drop players here',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in playerIds)
                            if (byId[id] != null)
                              DragTarget<String>(
                                onWillAcceptWithDetails: (details) =>
                                    details.data != id,
                                onAcceptWithDetails: (details) =>
                                    onMove(details.data, tier, beforeId: id),
                                builder: (context, incoming, rejected) =>
                                    DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: incoming.isNotEmpty
                                        ? Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: _DraggablePlayerCard(
                                    row: byId[id]!,
                                    rank: rankById[id] ?? 0,
                                    statOne: statOne,
                                    statTwo: statTwo,
                                    showStats: showStats,
                                    engine: engine,
                                    onEarlier: () => onNudge(tier, id, -1),
                                    onLater: () => onNudge(tier, id, 1),
                                    onRemove: () => onRemove(id),
                                  ),
                                ),
                              ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggablePlayerCard extends StatelessWidget {
  const _DraggablePlayerCard({
    required this.row,
    required this.rank,
    required this.statOne,
    required this.statTwo,
    required this.showStats,
    required this.engine,
    required this.onEarlier,
    required this.onLater,
    required this.onRemove,
  });

  final NbaStatsRow row;
  final int rank;
  final String statOne;
  final String statTwo;
  final bool showStats;
  final NbaStatsWorkstationEngine engine;
  final VoidCallback onEarlier;
  final VoidCallback onLater;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final card = _RankingPlayerCard(
      row: row,
      rank: rank,
      statOne: statOne,
      statTwo: statTwo,
      showStats: showStats,
      engine: engine,
      onEarlier: onEarlier,
      onLater: onLater,
      onRemove: onRemove,
    );
    return Draggable<String>(
      data: row.playerId,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 250, child: card),
      ),
      childWhenDragging: Opacity(opacity: .35, child: card),
      child: card,
    );
  }
}

class _RankingPlayerCard extends StatelessWidget {
  const _RankingPlayerCard({
    required this.row,
    required this.rank,
    required this.statOne,
    required this.statTwo,
    required this.showStats,
    required this.engine,
    this.onEarlier,
    this.onLater,
    this.onRemove,
  });

  final NbaStatsRow row;
  final int rank;
  final String statOne;
  final String statTwo;
  final bool showStats;
  final NbaStatsWorkstationEngine engine;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
        width: 244,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (rank > 0) ...[
              SizedBox(
                width: 30,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            CircleAvatar(
              radius: 17,
              child: Text(
                _initials(row.player),
                style:
                    const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.player,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${row.team} · ${row.position}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (showStats)
                    Text(
                      '${engine.metric(statOne).shortLabel} ${engine.formatValue(statOne, row.value(statOne))} · ${engine.metric(statTwo).shortLabel} ${engine.formatValue(statTwo, row.value(statTwo))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (onRemove != null)
              PopupMenuButton<String>(
                tooltip: 'Rank controls',
                onSelected: (value) {
                  if (value == 'earlier') onEarlier?.call();
                  if (value == 'later') onLater?.call();
                  if (value == 'remove') onRemove?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'earlier', child: Text('Move earlier')),
                  PopupMenuItem(value: 'later', child: Text('Move later')),
                  PopupMenuItem(value: 'remove', child: Text('Return to pool')),
                ],
                icon: const Icon(Icons.more_vert_rounded, size: 18),
              ),
          ],
        ),
      );
}

class _PlayerPool extends StatelessWidget {
  const _PlayerPool({
    required this.rows,
    required this.totalRows,
    required this.statOne,
    required this.statTwo,
    required this.showStats,
    required this.engine,
    required this.positionFilter,
    required this.poolSort,
    required this.search,
    required this.onPosition,
    required this.onSort,
    required this.onSearch,
    required this.onAdd,
  });

  final List<NbaStatsRow> rows;
  final int totalRows;
  final String statOne;
  final String statTwo;
  final bool showStats;
  final NbaStatsWorkstationEngine engine;
  final String positionFilter;
  final String poolSort;
  final TextEditingController search;
  final ValueChanged<String> onPosition;
  final ValueChanged<String> onSort;
  final VoidCallback onSearch;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Player Pool · $totalRows',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final filter in const ['All', 'Guards', 'Wings', 'Bigs'])
                    ChoiceChip(
                      label: Text(filter),
                      selected: positionFilter == filter,
                      onSelected: (_) => onPosition(filter),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: poolSort,
                decoration: const InputDecoration(
                  labelText: 'Sort pool',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'Minutes', child: Text('Minutes')),
                  DropdownMenuItem(value: 'Stat 1', child: Text('Stat 1')),
                  DropdownMenuItem(value: 'Name', child: Text('Name')),
                ],
                onChanged: (value) {
                  if (value != null) onSort(value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: search,
                onChanged: (_) => onSearch(),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search players',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Drag to a tier. Drop onto a ranked player to insert immediately before them.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final row in rows)
                    Draggable<String>(
                      data: row.playerId,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 244,
                          child: _RankingPlayerCard(
                            row: row,
                            rank: 0,
                            statOne: statOne,
                            statTwo: statTwo,
                            showStats: showStats,
                            engine: engine,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: .35,
                        child: _PoolChip(
                          row: row,
                          engine: engine,
                          statOne: statOne,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => onAdd(row.playerId),
                        child: _PoolChip(
                          row: row,
                          engine: engine,
                          statOne: statOne,
                        ),
                      ),
                    ),
                ],
              ),
              if (totalRows > rows.length)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Showing ${rows.length} of $totalRows matching players. Narrow the search to reach the rest.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No unranked players match this filter.'),
                ),
            ],
          ),
        ),
      );
}

class _PoolChip extends StatelessWidget {
  const _PoolChip({
    required this.row,
    required this.engine,
    required this.statOne,
  });
  final NbaStatsRow row;
  final NbaStatsWorkstationEngine engine;
  final String statOne;

  @override
  Widget build(BuildContext context) => Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.player,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '${row.team} · ${row.position} · ${engine.formatValue(statOne, row.value(statOne))} ${engine.metric(statOne).shortLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _SavedRankingBoard {
  const _SavedRankingBoard({
    required this.id,
    required this.name,
    required this.season,
    required this.seasonType,
    required this.statOne,
    required this.statTwo,
    required this.showStats,
    required this.tiers,
  });

  final String id;
  final String name;
  final String season;
  final String seasonType;
  final String statOne;
  final String statTwo;
  final bool showStats;
  final Map<String, List<String>> tiers;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'season': season,
        'season_type': seasonType,
        'stat_one': statOne,
        'stat_two': statTwo,
        'show_stats': showStats,
        'tiers': tiers,
      };

  factory _SavedRankingBoard.fromJson(Map<String, dynamic> json) {
    final tierMap = <String, List<String>>{};
    final rawTiers = json['tiers'];
    if (rawTiers is Map) {
      for (final entry in rawTiers.entries) {
        final value = entry.value;
        tierMap[entry.key.toString()] = value is List
            ? value.map((item) => item.toString()).toList()
            : <String>[];
      }
    }
    return _SavedRankingBoard(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Saved rankings',
      season: json['season']?.toString() ?? '2025-26',
      seasonType: json['season_type']?.toString() ?? 'regular',
      statOne: json['stat_one']?.toString() ?? 'pts',
      statTwo: json['stat_two']?.toString() ?? 'tov',
      showStats: json['show_stats'] != false,
      tiers: tierMap,
    );
  }
}

bool _matchesPosition(String position, String filter) {
  if (filter == 'All') return true;
  final value = position.toUpperCase();
  if (filter == 'Guards') {
    return value.contains('G') || value.contains('PG') || value.contains('SG');
  }
  if (filter == 'Wings') {
    return value.contains('SF') || value.contains('SG') || value == 'F';
  }
  if (filter == 'Bigs') return value.contains('PF') || value.contains('C');
  return true;
}

Color _tierColor(String tier) {
  switch (tier) {
    case 'S':
      return const Color(0xFFD32F2F);
    case 'A':
      return const Color(0xFFE07A2D);
    case 'B':
      return const Color(0xFFD6A928);
    case 'C':
      return const Color(0xFF2E9E5B);
    case 'D':
      return const Color(0xFF2F9DA3);
    case 'E':
      return const Color(0xFF3368C5);
    default:
      return const Color(0xFF76529D);
  }
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
