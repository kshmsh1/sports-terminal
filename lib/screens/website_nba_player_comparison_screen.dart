import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _savedViewsKey = 'nba_player_compare_saved_views_v2';
  static const _maxPlayers = 5;
  static const _maxSavedViews = 5;

  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final List<_PlayerSlot> _slots = [
    _PlayerSlot(season: '2025-26'),
    _PlayerSlot(season: '2025-26'),
  ];
  final List<_SavedPlayerView> _savedViews = [];
  final Set<String> _customMetricKeys = {
    'pts',
    'reb',
    'ast',
    'stl',
    'blk',
    'tov',
    'ts_pct',
    'three_pct',
  };

  List<WebsiteNbaSeason> _seasons = const [];
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _category = 'Basic';
  bool _lockSeasons = true;
  String? _activeSavedViewId;
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
    await _loadSavedViews();
    return _loadData();
  }

  Future<void> _loadSavedViews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedViewsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _savedViews
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map(
                (item) => _SavedPlayerView.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
        );
    } catch (_) {
      // Saved views are convenience state. Ignore malformed local values.
    }
  }

  Future<void> _persistSavedViews() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedViewsKey,
      jsonEncode([for (final view in _savedViews) view.toJson()]),
    );
  }

  Future<_ComparisonData> _loadData() async {
    final uniqueSeasons = _slots.map((slot) => slot.season).toSet().toList();
    final rowsBySeason = <String, List<NbaStatsRow>>{};
    for (final season in uniqueSeasons) {
      final snapshot = await _api.seasonSnapshot(
        season,
        seasonType:
            _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
      );
      final rows = _engine.buildRows(
        snapshot,
        basis: _basis,
        seasonType: _seasonType,
      )..sort(
          (a, b) =>
              (b.value('pts') ?? -1).compareTo(a.value('pts') ?? -1),
        );
      rowsBySeason[season] = rows;
    }

    for (var index = 0; index < _slots.length; index++) {
      final slot = _slots[index];
      final rows = rowsBySeason[slot.season] ?? const <NbaStatsRow>[];
      if (rows.isEmpty) {
        slot.playerId = null;
        continue;
      }
      if (!rows.any((row) => row.playerId == slot.playerId)) {
        final used = <String>{
          for (var other = 0; other < _slots.length; other++)
            if (other != index && _slots[other].season == slot.season)
              if (_slots[other].playerId != null) _slots[other].playerId!,
        };
        slot.playerId = rows
            .firstWhere(
              (row) => !used.contains(row.playerId),
              orElse: () => rows.first,
            )
            .playerId;
      }
    }
    return _ComparisonData(rowsBySeason);
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
    if (_slots.length >= _maxPlayers) return;
    final season = _slots.isEmpty ? '2025-26' : _slots.last.season;
    setState(() {
      _slots.add(_PlayerSlot(season: season));
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

  Future<void> _saveCurrent({required bool saveAs}) async {
    if (!saveAs && _activeSavedViewId != null) {
      final index = _savedViews.indexWhere(
        (view) => view.id == _activeSavedViewId,
      );
      if (index >= 0) {
        _savedViews[index] = _captureView(
          id: _savedViews[index].id,
          name: _savedViews[index].name,
        );
        await _persistSavedViews();
        if (mounted) setState(() {});
        return;
      }
    }

    if (_savedViews.length >= _maxSavedViews) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can save up to 5 comparison views.')),
      );
      return;
    }

    final controller = TextEditingController(
      text: 'Comparison ${_savedViews.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save comparison view'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'View name'),
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
    _savedViews.add(_captureView(id: id, name: name.trim()));
    _activeSavedViewId = id;
    await _persistSavedViews();
    if (mounted) setState(() {});
  }

  _SavedPlayerView _captureView({required String id, required String name}) =>
      _SavedPlayerView(
        id: id,
        name: name,
        seasonType: _seasonType.name,
        basis: _basis.name,
        category: _category,
        lockSeasons: _lockSeasons,
        customMetricKeys: _customMetricKeys.toList(),
        slots: [for (final slot in _slots) slot.toJson()],
      );

  void _applySavedView(_SavedPlayerView view) {
    setState(() {
      _seasonType = NbaStatsSeasonType.values.firstWhere(
        (item) => item.name == view.seasonType,
        orElse: () => NbaStatsSeasonType.regular,
      );
      _basis = NbaStatsBasis.values.firstWhere(
        (item) => item.name == view.basis,
        orElse: () => NbaStatsBasis.perGame,
      );
      _category = _categoryMetrics.containsKey(view.category)
          ? view.category
          : 'Basic';
      _lockSeasons = view.lockSeasons;
      _customMetricKeys
        ..clear()
        ..addAll(view.customMetricKeys.where(_metricCatalog.containsKey));
      _slots
        ..clear()
        ..addAll(view.slots.take(_maxPlayers).map(_PlayerSlot.fromJson));
      while (_slots.length < 2) {
        _slots.add(_PlayerSlot(season: '2025-26'));
      }
      _activeSavedViewId = view.id;
      _future = _loadData();
    });
  }

  Future<void> _deleteSavedView(_SavedPlayerView view) async {
    _savedViews.removeWhere((item) => item.id == view.id);
    if (_activeSavedViewId == view.id) _activeSavedViewId = null;
    await _persistSavedViews();
    if (mounted) setState(() {});
  }

  Future<void> _copyComparison(
    List<_SelectedPlayer> players,
    List<_CompareMetric> metrics,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        [
          'metric',
          for (final player in players)
            '${player.row.player} (${player.season})',
        ].map(_csvCell).join(','),
      );
    for (final metric in metrics) {
      buffer.writeln(
        [
          metric.label,
          for (final player in players)
            metric.format(metric.value(player.row), _engine),
        ].map(_csvCell).join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${metrics.length} metrics for ${players.length} players as CSV.',
        ),
      ),
    );
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _editCustomMetrics() async {
    final working = Set<String>.from(_customMetricKeys);
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded),
                      const SizedBox(width: 8),
                      Text(
                        'Custom metric set',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Text('${working.length} selected'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final group in _customGroups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            group.key,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final key in group.value)
                              if (_metricCatalog[key] != null)
                                FilterChip(
                                  selected: working.contains(key),
                                  label: Text(_metricCatalog[key]!.label),
                                  onSelected: (value) {
                                    setSheetState(() {
                                      if (value) {
                                        working.add(key);
                                      } else if (working.length > 1) {
                                        working.remove(key);
                                      }
                                    });
                                  },
                                ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, working),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Apply metrics'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      _customMetricKeys
        ..clear()
        ..addAll(selected);
      _category = 'Custom';
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ComparisonData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 460,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ErrorCard(error: snapshot.error, onRetry: _reload);
        }
        return _buildPage(context, snapshot.data!);
      },
    );
  }

  Widget _buildPage(BuildContext context, _ComparisonData data) {
    final colors = Theme.of(context).colorScheme;
    final palette = <Color>[
      colors.primary,
      colors.tertiary,
      colors.secondary,
      const Color(0xFFFFB74D),
      const Color(0xFF80CBC4),
    ];
    final selected = <_SelectedPlayer>[];
    for (var index = 0; index < _slots.length; index++) {
      final slot = _slots[index];
      final row = _findRow(data.rowsBySeason[slot.season], slot.playerId);
      if (row != null) {
        selected.add(
          _SelectedPlayer(
            row: row,
            season: slot.season,
            color: palette[index],
          ),
        );
      }
    }

    final metricKeys = _category == 'Custom'
        ? _customMetricKeys.toList()
        : (_categoryMetrics[_category] ?? _categoryMetrics['Basic']!);
    final metrics = [
      for (final key in metricKeys)
        if (_metricCatalog[key] != null) _metricCatalog[key]!,
    ];
    final standings = _standings(selected, metrics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Player Comparison Lab',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
            Chip(
              avatar: const Icon(Icons.storage_rounded, size: 17),
              label: const Text('Static NBA history · 1946-47 → 2025-26'),
            ),
            FilledButton.icon(
              onPressed: _slots.length < _maxPlayers ? _addPlayer : null,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                _slots.length < _maxPlayers ? 'Add player' : '5 players max',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Compare two to five player seasons or playoff runs across eras, rate bases and custom stat bundles.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        _ControlBar(
          seasonType: _seasonType,
          basis: _basis,
          lockSeasons: _lockSeasons,
          savedViews: _savedViews,
          activeSavedViewId: _activeSavedViewId,
          onSeasonType: (value) {
            _seasonType = value;
            for (final slot in _slots) {
              slot.playerId = null;
            }
            _reload();
          },
          onBasis: (value) {
            _basis = value;
            _reload();
          },
          onLockSeasons: (value) {
            setState(() {
              _lockSeasons = value;
              if (value && _slots.isNotEmpty) {
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
          onSave: () => _saveCurrent(saveAs: false),
          onSaveAs: () => _saveCurrent(saveAs: true),
          onApply: _applySavedView,
          onDelete: _deleteSavedView,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < _slots.length; index++) ...[
                SizedBox(
                  width: 292,
                  child: _PlayerSelectorCard(
                    label: 'Player ${String.fromCharCode(65 + index)}',
                    accent: palette[index],
                    season: _slots[index].season,
                    seasons: _seasons,
                    rows: data.rowsBySeason[_slots[index].season] ??
                        const <NbaStatsRow>[],
                    playerId: _slots[index].playerId,
                    canRemove: _slots.length > 2,
                    onSeason: (value) => _setSeason(index, value),
                    onPlayer: (value) =>
                        setState(() => _slots[index].playerId = value),
                    onRemove: () => _removePlayer(index),
                    onOpen: () {
                      final row = _findRow(
                        data.rowsBySeason[_slots[index].season],
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
          _StandingsCard(standings: standings),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final category in [
                ..._categoryMetrics.keys,
                'Custom',
              ])
                ChoiceChip(
                  selected: _category == category,
                  label: Text(category),
                  onSelected: (_) => setState(() => _category = category),
                ),
              if (_category == 'Custom')
                OutlinedButton.icon(
                  onPressed: _editCustomMetrics,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Edit metrics'),
                ),
              OutlinedButton.icon(
                onPressed: () => _copyComparison(selected, metrics),
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Copy comparison'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MetricTable(players: selected, metrics: metrics, engine: _engine),
          const SizedBox(height: 18),
          _PercentileCard(players: selected, metrics: metrics),
          const SizedBox(height: 12),
          Text(
            '★ marks the most favorable available value in each row. Ties are marked together. Cross-era percentiles remain relative to each player’s selected season.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.seasonType,
    required this.basis,
    required this.lockSeasons,
    required this.savedViews,
    required this.activeSavedViewId,
    required this.onSeasonType,
    required this.onBasis,
    required this.onLockSeasons,
    required this.onSave,
    required this.onSaveAs,
    required this.onApply,
    required this.onDelete,
  });

  final NbaStatsSeasonType seasonType;
  final NbaStatsBasis basis;
  final bool lockSeasons;
  final List<_SavedPlayerView> savedViews;
  final String? activeSavedViewId;
  final ValueChanged<NbaStatsSeasonType> onSeasonType;
  final ValueChanged<NbaStatsBasis> onBasis;
  final ValueChanged<bool> onLockSeasons;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final ValueChanged<_SavedPlayerView> onApply;
  final ValueChanged<_SavedPlayerView> onDelete;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
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
                selected: {seasonType},
                onSelectionChanged: (value) => onSeasonType(value.first),
              ),
              SizedBox(
                width: 165,
                child: DropdownButtonFormField<NbaStatsBasis>(
                  initialValue: basis,
                  decoration: const InputDecoration(
                    labelText: 'Rate basis',
                    isDense: true,
                  ),
                  items: [
                    for (final value in NbaStatsBasis.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) onBasis(value);
                  },
                ),
              ),
              FilterChip(
                selected: lockSeasons,
                avatar: Icon(
                  lockSeasons ? Icons.link_rounded : Icons.link_off_rounded,
                  size: 18,
                ),
                label: Text(lockSeasons ? 'Seasons linked' : 'Cross-era mode'),
                onSelected: onLockSeasons,
              ),
              FilledButton.tonalIcon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save'),
              ),
              OutlinedButton.icon(
                onPressed: onSaveAs,
                icon: const Icon(Icons.save_as_rounded),
                label: const Text('Save As'),
              ),
              if (savedViews.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Saved comparison views',
                  onSelected: (value) {
                    for (final view in savedViews) {
                      if (view.id == value) {
                        onApply(view);
                        return;
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    for (final view in savedViews)
                      PopupMenuItem(
                        value: view.id,
                        child: Row(
                          children: [
                            if (view.id == activeSavedViewId)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.check_rounded, size: 18),
                              ),
                            Expanded(child: Text(view.name)),
                            IconButton(
                              tooltip: 'Delete saved view',
                              onPressed: () {
                                Navigator.pop(context);
                                onDelete(view);
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.bookmarks_outlined, size: 17),
                    label: Text('Saved views'),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _PlayerSelectorCard extends StatelessWidget {
  const _PlayerSelectorCard({
    required this.label,
    required this.accent,
    required this.season,
    required this.seasons,
    required this.rows,
    required this.playerId,
    required this.canRemove,
    required this.onSeason,
    required this.onPlayer,
    required this.onRemove,
    required this.onOpen,
  });

  final String label;
  final Color accent;
  final String season;
  final List<WebsiteNbaSeason> seasons;
  final List<NbaStatsRow> rows;
  final String? playerId;
  final bool canRemove;
  final ValueChanged<String> onSeason;
  final ValueChanged<String> onPlayer;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final row = _findRow(rows, playerId);
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 4, color: accent),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
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
                DropdownButtonFormField<String>(
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
                const SizedBox(height: 12),
                DropdownMenu<String>(
                  key: ValueKey('$label-$season-$playerId'),
                  initialSelection: playerId,
                  enableFilter: true,
                  enableSearch: true,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Search player'),
                  leadingIcon: const Icon(Icons.search_rounded),
                  dropdownMenuEntries: [
                    for (final player in rows)
                      DropdownMenuEntry(
                        value: player.playerId,
                        label: '${player.player} · ${player.team}',
                      ),
                  ],
                  onSelected: (value) {
                    if (value != null) onPlayer(value);
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  height: 112,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: .25)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_rounded, color: accent, size: 46),
                      const SizedBox(height: 4),
                      Text(
                        'PLAYER IMAGE PLACEHOLDER',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (row == null)
                  const Text('Choose a player')
                else ...[
                  Text(
                    row.player,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${row.team} · ${row.position} · ${_whole(row.value('gp'))} GP',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Open canonical player page',
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTable extends StatelessWidget {
  const _MetricTable({
    required this.players,
    required this.metrics,
    required this.engine,
  });

  final List<_SelectedPlayer> players;
  final List<_CompareMetric> metrics;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) {
    final minWidth = 170.0 + players.length * 170.0;
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: math.max(minWidth, MediaQuery.sizeOf(context).width - 90),
          child: Table(
            columnWidths: {
              0: const FixedColumnWidth(150),
              for (var index = 0; index < players.length; index++)
                index + 1: const FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: .35),
                ),
                children: [
                  const _TableCellText('METRIC', bold: true),
                  for (final player in players)
                    _TableCellText(
                      '${player.row.player}\n${player.season}',
                      bold: true,
                      color: player.color,
                    ),
                ],
              ),
              for (final metric in metrics) _metricRow(context, metric),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _metricRow(BuildContext context, _CompareMetric metric) {
    final values = [for (final player in players) metric.value(player.row)];
    final winners = metric.winnerIndexes(values);
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      children: [
        _TableCellText(metric.label, bold: true),
        for (var index = 0; index < players.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            color: winners.contains(index)
                ? players[index].color.withValues(alpha: .13)
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (winners.contains(index)) ...[
                  Icon(Icons.star_rounded, size: 16, color: players[index].color),
                  const SizedBox(width: 4),
                ],
                Text(
                  metric.format(values[index], engine),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: winners.contains(index)
                        ? FontWeight.w900
                        : FontWeight.w600,
                    color: winners.contains(index) ? players[index].color : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText(this.text, {this.bold = false, this.color});
  final String text;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
            color: color,
          ),
        ),
      );
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.standings});
  final List<_PlayerStanding> standings;

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) return const SizedBox.shrink();
    final top = standings.first;
    final tied = standings
        .where(
          (item) =>
              item.bestCount == top.bestCount &&
              item.tiedBestCount == top.tiedBestCount,
        )
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tied.length > 1
                  ? 'Category edge: tie'
                  : 'Category edge: ${top.player.row.player}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in standings)
                  Chip(
                    avatar: CircleAvatar(backgroundColor: item.player.color),
                    label: Text(
                      '${item.player.row.player}: ${item.bestCount} best · ${item.tiedBestCount} tied best',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentileCard extends StatelessWidget {
  const _PercentileCard({required this.players, required this.metrics});
  final List<_SelectedPlayer> players;
  final List<_CompareMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final available = metrics
        .where(
          (metric) => players.any((player) => metric.percentile(player.row) != null),
        )
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Season-relative fingerprint',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            for (final metric in available)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        metric.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          for (final player in players)
                            SizedBox(
                              width: 180,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${player.row.player}: ${metric.percentile(player.row)?.round() ?? '—'}p',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(height: 3),
                                  LinearProgressIndicator(
                                    value: ((metric.percentile(player.row) ?? 0)
                                            .clamp(0, 100)) /
                                        100,
                                    minHeight: 7,
                                    backgroundColor:
                                        player.color.withValues(alpha: .10),
                                    valueColor:
                                        AlwaysStoppedAnimation(player.color),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
              const Text(
                'Player comparison data unavailable',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'The comparison page reads the same local static NBA shards as Stats and Advanced Stats. ${error ?? ''}',
              ),
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

class _PlayerSlot {
  _PlayerSlot({required this.season, this.playerId});
  String season;
  String? playerId;

  Map<String, dynamic> toJson() => {
        'season': season,
        'player_id': playerId,
      };

  factory _PlayerSlot.fromJson(Map<String, dynamic> json) => _PlayerSlot(
        season: json['season']?.toString() ?? '2025-26',
        playerId: json['player_id']?.toString(),
      );
}

class _SavedPlayerView {
  const _SavedPlayerView({
    required this.id,
    required this.name,
    required this.seasonType,
    required this.basis,
    required this.category,
    required this.lockSeasons,
    required this.customMetricKeys,
    required this.slots,
  });

  final String id;
  final String name;
  final String seasonType;
  final String basis;
  final String category;
  final bool lockSeasons;
  final List<String> customMetricKeys;
  final List<Map<String, dynamic>> slots;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'season_type': seasonType,
        'basis': basis,
        'category': category,
        'lock_seasons': lockSeasons,
        'custom_metric_keys': customMetricKeys,
        'slots': slots,
      };

  factory _SavedPlayerView.fromJson(Map<String, dynamic> json) =>
      _SavedPlayerView(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Saved comparison',
        seasonType: json['season_type']?.toString() ?? 'regular',
        basis: json['basis']?.toString() ?? 'perGame',
        category: json['category']?.toString() ?? 'Basic',
        lockSeasons: json['lock_seasons'] != false,
        customMetricKeys: [
          for (final item in (json['custom_metric_keys'] as List? ?? const []))
            item.toString(),
        ],
        slots: [
          for (final item in (json['slots'] as List? ?? const []))
            if (item is Map) Map<String, dynamic>.from(item),
        ],
      );
}

class _ComparisonData {
  const _ComparisonData(this.rowsBySeason);
  final Map<String, List<NbaStatsRow>> rowsBySeason;
}

class _SelectedPlayer {
  const _SelectedPlayer({
    required this.row,
    required this.season,
    required this.color,
  });
  final NbaStatsRow row;
  final String season;
  final Color color;
}

class _PlayerStanding {
  const _PlayerStanding({
    required this.player,
    required this.bestCount,
    required this.tiedBestCount,
  });
  final _SelectedPlayer player;
  final int bestCount;
  final int tiedBestCount;
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
    for (final alias in [key, ...rawAliases]) {
      final raw = _number(row.raw[alias]);
      if (raw != null) return percent && raw > 1.5 ? raw / 100 : raw;
    }
    return null;
  }

  double? percentile(NbaStatsRow row) => row.percentiles[key];

  Set<int> winnerIndexes(List<double?> values) {
    final available = <int, double>{
      for (var index = 0; index < values.length; index++)
        if (values[index] != null) index: values[index]!,
    };
    if (available.isEmpty) return const {};
    final best = higherIsBetter
        ? available.values.reduce(math.max)
        : available.values.reduce(math.min);
    return {
      for (final entry in available.entries)
        if ((entry.value - best).abs() < .000001) entry.key,
    };
  }

  String format(double? value, NbaStatsWorkstationEngine engine) {
    if (value == null || !value.isFinite) return '—';
    if (percent) return '${(value * 100).toStringAsFixed(1)}%';
    return engine.formatValue(key, value);
  }
}

NbaStatsRow? _findRow(List<NbaStatsRow>? rows, String? id) {
  if (id == null || rows == null) return null;
  for (final row in rows) {
    if (row.playerId == id) return row;
  }
  return null;
}

List<_PlayerStanding> _standings(
  List<_SelectedPlayer> players,
  List<_CompareMetric> metrics,
) {
  final best = List<int>.filled(players.length, 0);
  final tied = List<int>.filled(players.length, 0);
  for (final metric in metrics) {
    final winners = metric.winnerIndexes([
      for (final player in players) metric.value(player.row),
    ]);
    for (final winner in winners) {
      if (winners.length == 1) {
        best[winner]++;
      } else {
        tied[winner]++;
      }
    }
  }
  final result = [
    for (var index = 0; index < players.length; index++)
      _PlayerStanding(
        player: players[index],
        bestCount: best[index],
        tiedBestCount: tied[index],
      ),
  ];
  result.sort((a, b) {
    final byBest = b.bestCount.compareTo(a.bestCount);
    return byBest != 0
        ? byBest
        : b.tiedBestCount.compareTo(a.tiedBestCount);
  });
  return result;
}

String _whole(double? value) => value == null ? '—' : value.round().toString();

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll('%', '').trim() ?? '');
}

final Map<String, _CompareMetric> _metricCatalog = {
  'gp': const _CompareMetric('gp', 'GP'),
  'min': const _CompareMetric('min', 'MIN'),
  'pts': const _CompareMetric('pts', 'PTS'),
  'reb': const _CompareMetric('reb', 'REB'),
  'oreb': const _CompareMetric('oreb', 'OREB'),
  'dreb': const _CompareMetric('dreb', 'DREB'),
  'ast': const _CompareMetric('ast', 'AST'),
  'stl': const _CompareMetric('stl', 'STL'),
  'blk': const _CompareMetric('blk', 'BLK'),
  'tov': const _CompareMetric('tov', 'TOV', higherIsBetter: false),
  'pf': const _CompareMetric('pf', 'PF', higherIsBetter: false),
  'fgm': const _CompareMetric('fgm', 'FGM'),
  'fga': const _CompareMetric('fga', 'FGA'),
  'fg_pct': const _CompareMetric('fg_pct', 'FG%', percent: true),
  'two_pct': const _CompareMetric('two_pct', '2P%', percent: true),
  'three_pm': const _CompareMetric('three_pm', '3PM'),
  'three_pa': const _CompareMetric('three_pa', '3PA'),
  'three_pct': const _CompareMetric('three_pct', '3P%', percent: true),
  'ftm': const _CompareMetric('ftm', 'FTM'),
  'fta': const _CompareMetric('fta', 'FTA'),
  'ft_pct': const _CompareMetric('ft_pct', 'FT%', percent: true),
  'efg_pct': const _CompareMetric('efg_pct', 'eFG%', percent: true),
  'ts_pct': const _CompareMetric('ts_pct', 'TS%', percent: true),
  'points_per_shot': const _CompareMetric('points_per_shot', 'PTS/SA'),
  'ast_tov': const _CompareMetric('ast_tov', 'AST/TOV'),
  'three_rate': const _CompareMetric('three_rate', '3PA Rate', percent: true),
  'ft_rate': const _CompareMetric('ft_rate', 'FTA Rate', percent: true),
  'stocks': const _CompareMetric('stocks', 'STOCKS'),
  'defense_events': const _CompareMetric('defense_events', 'DEF EVT'),
  'deflections_pg': const _CompareMetric(
    'deflections_pg',
    'Deflections',
    rawAliases: ['deflections'],
  ),
  'dfg_pct': const _CompareMetric(
    'dfg_pct',
    'DFG%',
    higherIsBetter: false,
    percent: true,
    rawAliases: ['defended_fg_pct'],
  ),
  'rim_dfg_pct': const _CompareMetric(
    'rim_dfg_pct',
    'Rim DFG%',
    higherIsBetter: false,
    percent: true,
  ),
  'three_dfg_pct': const _CompareMetric(
    'three_dfg_pct',
    '3P DFG%',
    higherIsBetter: false,
    percent: true,
  ),
  'bpm': const _CompareMetric('bpm', 'BPM'),
  'plus_minus': const _CompareMetric('plus_minus', '+/-'),
  'game_score_proxy': const _CompareMetric('game_score_proxy', 'Production'),
};

final Map<String, List<String>> _categoryMetrics = {
  'Basic': ['pts', 'reb', 'ast', 'stl', 'blk', 'tov', 'pf'],
  'Scoring': ['pts', 'fgm', 'fga', 'three_pm', 'fta', 'points_per_shot'],
  'Shooting': [
    'fg_pct',
    'two_pct',
    'three_pm',
    'three_pa',
    'three_pct',
    'ft_pct',
    'efg_pct',
    'ts_pct',
    'three_rate',
    'ft_rate',
  ],
  'Playmaking': ['ast', 'tov', 'ast_tov'],
  'Rebounding': ['reb', 'oreb', 'dreb'],
  'Defense': [
    'stl',
    'blk',
    'stocks',
    'defense_events',
    'pf',
    'deflections_pg',
    'dfg_pct',
    'rim_dfg_pct',
    'three_dfg_pct',
  ],
  'Impact': ['bpm', 'plus_minus', 'game_score_proxy', 'ts_pct', 'ast_tov'],
};

final Map<String, List<String>> _customGroups = {
  'Basic': ['gp', 'min', 'pts', 'reb', 'ast', 'stl', 'blk', 'tov', 'pf'],
  'Shooting & Efficiency': [
    'fgm',
    'fga',
    'fg_pct',
    'two_pct',
    'three_pm',
    'three_pa',
    'three_pct',
    'ftm',
    'fta',
    'ft_pct',
    'efg_pct',
    'ts_pct',
    'points_per_shot',
    'three_rate',
    'ft_rate',
  ],
  'Playmaking & Rebounding': ['ast_tov', 'oreb', 'dreb'],
  'Defense & Impact': [
    'stocks',
    'defense_events',
    'deflections_pg',
    'dfg_pct',
    'rim_dfg_pct',
    'three_dfg_pct',
    'bpm',
    'plus_minus',
    'game_score_proxy',
  ],
};
