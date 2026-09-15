import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  static const _savedViewsKey = 'nba_player_compare_saved_views_v1';
  static const _maxSavedViews = 5;

  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();

  List<WebsiteNbaSeason> _seasons = const [];
  final List<_PlayerSlotState> _slots = [
    _PlayerSlotState(season: '2025-26'),
    _PlayerSlotState(season: '2025-26'),
  ];
  final List<_SavedComparisonView> _savedViews = [];
  final Set<String> _customMetricKeys = {
    'pts',
    'reb',
    'ast',
    'tov',
    'blk',
    'ts_pct',
    'three_pct',
    'ft_pct',
  };
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
    final payload = prefs.getString(_savedViewsKey);
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) return;
      _savedViews
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((item) => _SavedComparisonView.fromJson(Map<String, dynamic>.from(item))),
        );
    } catch (_) {
      // Ignore malformed local state; saved comparisons are user convenience only.
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

  Future<void> _saveCurrent({required bool saveAs}) async {
    final currentId = _activeSavedViewId;
    if (!saveAs && currentId != null) {
      final index = _savedViews.indexWhere((view) => view.id == currentId);
      if (index >= 0) {
        _savedViews[index] = _captureView(
          id: currentId,
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

    final name = await _promptForViewName();
    if (name == null || name.trim().isEmpty) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _savedViews.add(_captureView(id: id, name: name.trim()));
    _activeSavedViewId = id;
    await _persistSavedViews();
    if (mounted) setState(() {});
  }

  _SavedComparisonView _captureView({required String id, required String name}) {
    return _SavedComparisonView(
      id: id,
      name: name,
      seasonType: _seasonType.name,
      basis: _basis.name,
      category: _category,
      lockSeasons: _lockSeasons,
      customMetricKeys: _customMetricKeys.toList(),
      slots: [for (final slot in _slots) slot.toJson()],
    );
  }

  Future<String?> _promptForViewName() async {
    final controller = TextEditingController(
      text: 'Comparison ${_savedViews.length + 1}',
    );
    return showDialog<String>(
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
  }

  Future<void> _applySavedView(_SavedComparisonView view) async {
    setState(() {
      _seasonType = NbaStatsSeasonType.values.firstWhere(
        (value) => value.name == view.seasonType,
        orElse: () => NbaStatsSeasonType.regular,
      );
      _basis = NbaStatsBasis.values.firstWhere(
        (value) => value.name == view.basis,
        orElse: () => NbaStatsBasis.perGame,
      );
      _category = _categories.containsKey(view.category) ? view.category : 'Basic';
      _lockSeasons = view.lockSeasons;
      _customMetricKeys
        ..clear()
        ..addAll(view.customMetricKeys.where(_metricCatalog.containsKey));
      _slots
        ..clear()
        ..addAll(view.slots.take(5).map(_PlayerSlotState.fromJson));
      while (_slots.length < 2) {
        _slots.add(_PlayerSlotState(season: _seasons.isEmpty ? '2025-26' : _seasons.first.id));
      }
      _activeSavedViewId = view.id;
      _future = _loadData();
    });
  }

  Future<void> _deleteSavedView(_SavedComparisonView view) async {
    _savedViews.removeWhere((item) => item.id == view.id);
    if (_activeSavedViewId == view.id) _activeSavedViewId = null;
    await _persistSavedViews();
    if (mounted) setState(() {});
  }

  Future<void> _editMetrics() async {
    final working = Set<String>.from(_customMetricKeys);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final height = MediaQuery.sizeOf(context).height * .82;
          return SafeArea(
            child: SizedBox(
              height: height,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded),
                        const SizedBox(width: 8),
                        Text(
                          'Edit custom metrics',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const Spacer(),
                        Text('${working.length}/${_metricCatalog.length} selected'),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final group in _customMetricGroups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 8),
                            child: Text(
                              group.key,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final metric in group.value)
                                FilterChip(
                                  selected: working.contains(metric.key),
                                  label: Text(metric.label),
                                  onSelected: (selected) {
                                    setSheetState(() {
                                      if (selected) {
                                        working.add(metric.key);
                                      } else if (working.length > 1) {
                                        working.remove(metric.key);
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
                          onPressed: () {
                            setSheetState(() {
                              working
                                ..clear()
                                ..addAll(['pts', 'reb', 'ast', 'ts_pct']);
                            });
                          },
                          child: const Text('Reset'),
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
          );
        },
      ),
    );
    if (result == null) return;
    setState(() {
      _customMetricKeys
        ..clear()
        ..addAll(result);
      _category = 'Custom';
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
    final metrics = _category == 'Custom'
        ? _customMetricKeys.map((key) => _metricCatalog[key]!).toList()
        : (_categories[_category] ?? _categories['Basic']!);
    final standings = _buildStandings(selected, metrics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Compare any NBA regular season or playoff run from 1946-47 through 2025-26 using the local static corpus.',
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
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${_savedViews.length}/$_maxSavedViews saved'),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _activeSavedViewId,
                    decoration: const InputDecoration(
                      labelText: 'Saved views',
                      isDense: true,
                    ),
                    items: [
                      for (final view in _savedViews)
                        DropdownMenuItem(value: view.id, child: Text(view.name)),
                    ],
                    onChanged: (id) {
                      final view = _savedViews.where((item) => item.id == id).firstOrNull;
                      if (view != null) _applySavedView(view);
                    },
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => _saveCurrent(saveAs: false),
                  child: const Text('Save'),
                ),
                FilledButton(
                  onPressed: () => _saveCurrent(saveAs: true),
                  child: const Text('Save As'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Saved view actions',
                  onSelected: (value) {
                    if (value != 'delete' || _activeSavedViewId == null) return;
                    final view = _savedViews.firstWhere(
                      (item) => item.id == _activeSavedViewId,
                    );
                    _deleteSavedView(view);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete active view')),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _editMetrics,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Edit metrics'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
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
                  width: 170,
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
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _category == 'Custom',
                    label: const Text('Custom'),
                    onSelected: (_) => setState(() => _category = 'Custom'),
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
            'The ★ marker identifies the most favorable available value for each metric among every selected player. Ties receive the marker together. Percentile bars are season-relative, so cross-era mode compares each player against the league environment of that player’s selected season. Historical fields remain unavailable when that statistic was not recorded in the source era.',
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

  Map<String, dynamic> toJson() => {'season': season, 'playerId': playerId};

  factory _PlayerSlotState.fromJson(Map<String, dynamic> json) => _PlayerSlotState(
        season: json['season']?.toString() ?? '2025-26',
        playerId: json['playerId']?.toString(),
      );
}

class _SavedComparisonView {
  const _SavedComparisonView({
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
        'seasonType': seasonType,
        'basis': basis,
        'category': category,
        'lockSeasons': lockSeasons,
        'customMetricKeys': customMetricKeys,
        'slots': slots,
      };

  factory _SavedComparisonView.fromJson(Map<String, dynamic> json) =>
      _SavedComparisonView(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Saved comparison',
        seasonType: json['seasonType']?.toString() ?? 'regular',
        basis: json['basis']?.toString() ?? 'perGame',
        category: json['category']?.toString() ?? 'Basic',
        lockSeasons: json['lockSeasons'] == true,
        customMetricKeys: (json['customMetricKeys'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        slots: (json['slots'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
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
                const SizedBox(height: 10),
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
                Container(
                  height: 132,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: .22)),
                  ),
                  child: player == null
                      ? const Center(child: Text('Choose a player'))
                      : Stack(
                          children: [
                            Positioned.fill(
                              child: Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 72,
                                  color: accent.withValues(alpha: .22),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: .88),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'PLAYER IMAGE PLACEHOLDER',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                if (player != null)
                  Row(
                    children: [
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
  const _ComparisonSummary({required this.players, required this.standings});
  final List<_SelectedPlayer> players;
  final List<_PlayerStanding> standings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final leaders = standings.isEmpty
        ? const <_PlayerStanding>[]
        : standings.where((entry) => entry.bestCount == standings.first.bestCount).toList();
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
              leaders.isEmpty
                  ? 'No comparable metrics are available in this view.'
                  : leaders.length == 1
                      ? '${leaders.first.player.row.player} leads this category with ${leaders.first.bestCount} best-in-group metric${leaders.first.bestCount == 1 ? '' : 's'}.'
                      : '${leaders.map((entry) => entry.player.row.player).join(', ')} are tied for the broadest edge in this category.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final standing in standings)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: standing.player.color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${standing.player.row.player}: ${standing.bestCount} best · ${standing.tiedBestCount} tied',
                      style: TextStyle(
                        color: standing.player.color,
                        fontWeight: FontWeight.w800,
                      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 138,
                    child: Text('METRIC', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  for (final player in players)
                    SizedBox(
                      width: 165,
                      child: Text(
                        '${player.row.player} · ${player.season}',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: player.color, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const Divider(height: 22),
              for (final metric in metrics)
                _MetricGroupRow(metric: metric, players: players, engine: engine),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricGroupRow extends StatelessWidget {
  const _MetricGroupRow({
    required this.metric,
    required this.players,
    required this.engine,
  });
  final _CompareMetric metric;
  final List<_SelectedPlayer> players;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) {
    final values = [for (final player in players) metric.value(player.row)];
    final winners = metric.winnerIndexes(values);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 138,
            child: Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          for (var index = 0; index < players.length; index++)
            _MetricValueCell(
              width: 165,
              text: metric.format(values[index], engine),
              percentile: metric.percentile(players[index].row),
              winner: winners.contains(index),
              color: players[index].color,
            ),
        ],
      ),
    );
  }
}

class _MetricValueCell extends StatelessWidget {
  const _MetricValueCell({
    required this.width,
    required this.text,
    required this.percentile,
    required this.winner,
    required this.color,
  });
  final double width;
  final String text;
  final double? percentile;
  final bool winner;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: winner ? color.withValues(alpha: .14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: winner ? Border.all(color: color.withValues(alpha: .38)) : null,
          ),
          child: Column(
            children: [
              Text(
                winner ? '★ $text' : text,
                style: TextStyle(
                  fontWeight: winner ? FontWeight.w900 : FontWeight.w600,
                  color: winner ? color : null,
                ),
              ),
              if (percentile != null)
                Text(
                  '${percentile!.round()}th percentile',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      );
}

class _PercentileFingerprint extends StatelessWidget {
  const _PercentileFingerprint({required this.players, required this.metrics});
  final List<_SelectedPlayer> players;
  final List<_CompareMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final visible = metrics
        .where((metric) => players.any((player) => metric.percentile(player.row) != null))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Season-relative fingerprints',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            for (final metric in visible) ...[
              Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final player in players)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          player.row.player,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: ((metric.percentile(player.row) ?? 0).clamp(0, 100)) / 100,
                            minHeight: 8,
                            backgroundColor: player.color.withValues(alpha: .10),
                            valueColor: AlwaysStoppedAnimation(player.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          metric.percentile(player.row)?.round().toString() ?? '—',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
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

  Set<int> winnerIndexes(List<double?> values) {
    final available = <int, double>{
      for (var i = 0; i < values.length; i++)
        if (values[i] != null) i: values[i]!,
    };
    if (available.isEmpty) return const <int>{};
    final best = higherIsBetter
        ? available.values.reduce(math.max)
        : available.values.reduce(math.min);
    return {
      for (final entry in available.entries)
        if ((entry.value - best).abs() < 0.000001) entry.key,
    };
  }

  String format(double? value, NbaStatsWorkstationEngine engine) {
    if (value == null || !value.isFinite) return '—';
    if (percent) return '${(value * 100).toStringAsFixed(1)}%';
    return engine.formatValue(key, value);
  }
}

List<_PlayerStanding> _buildStandings(
  List<_SelectedPlayer> players,
  List<_CompareMetric> metrics,
) {
  final best = List<int>.filled(players.length, 0);
  final ties = List<int>.filled(players.length, 0);
  for (final metric in metrics) {
    final winners = metric.winnerIndexes([
      for (final player in players) metric.value(player.row),
    ]);
    for (final winner in winners) {
      if (winners.length == 1) {
        best[winner]++;
      } else {
        ties[winner]++;
      }
    }
  }
  final result = [
    for (var i = 0; i < players.length; i++)
      _PlayerStanding(player: players[i], bestCount: best[i], tiedBestCount: ties[i]),
  ];
  result.sort((a, b) {
    final byBest = b.bestCount.compareTo(a.bestCount);
    return byBest != 0 ? byBest : b.tiedBestCount.compareTo(a.tiedBestCount);
  });
  return result;
}

NbaStatsRow? _findRow(List<NbaStatsRow> rows, String? id) {
  if (id == null) return null;
  for (final row in rows) {
    if (row.playerId == id) return row;
  }
  return null;
}

String _whole(double? value) => value == null ? '—' : value.round().toString();

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll('%', '').trim() ?? '');
}

List<Color> _playerColors(ColorScheme colors) => [
      colors.primary,
      colors.tertiary,
      colors.secondary,
      const Color(0xFFFFB74D),
      const Color(0xFF80CBC4),
    ];

const _metricCatalog = <String, _CompareMetric>{
  'gp': _CompareMetric('gp', 'GP'),
  'min': _CompareMetric('min', 'MIN'),
  'pts': _CompareMetric('pts', 'PTS'),
  'reb': _CompareMetric('reb', 'REB'),
  'oreb': _CompareMetric('oreb', 'OREB'),
  'dreb': _CompareMetric('dreb', 'DREB'),
  'ast': _CompareMetric('ast', 'AST'),
  'stl': _CompareMetric('stl', 'STL'),
  'blk': _CompareMetric('blk', 'BLK'),
  'tov': _CompareMetric('tov', 'TOV', higherIsBetter: false),
  'pf': _CompareMetric('pf', 'PF', higherIsBetter: false),
  'fgm': _CompareMetric('fgm', 'FGM'),
  'fga': _CompareMetric('fga', 'FGA'),
  'fg_pct': _CompareMetric('fg_pct', 'FG%', percent: true),
  'two_pct': _CompareMetric('two_pct', '2P%', percent: true),
  'three_pm': _CompareMetric('three_pm', '3PM'),
  'three_pa': _CompareMetric('three_pa', '3PA'),
  'three_pct': _CompareMetric('three_pct', '3P%', percent: true),
  'ftm': _CompareMetric('ftm', 'FTM'),
  'fta': _CompareMetric('fta', 'FTA'),
  'ft_pct': _CompareMetric('ft_pct', 'FT%', percent: true),
  'efg_pct': _CompareMetric('efg_pct', 'eFG%', percent: true),
  'ts_pct': _CompareMetric('ts_pct', 'TS%', percent: true),
  'points_per_shot': _CompareMetric('points_per_shot', 'PTS/SA'),
  'ast_tov': _CompareMetric('ast_tov', 'AST/TOV'),
  'three_rate': _CompareMetric('three_rate', '3PA Rate', percent: true),
  'ft_rate': _CompareMetric('ft_rate', 'FTA Rate', percent: true),
  'stocks': _CompareMetric('stocks', 'STOCKS'),
  'defense_events': _CompareMetric('defense_events', 'DEF EVT'),
  'deflections_pg': _CompareMetric(
    'deflections_pg',
    'Deflections',
    rawAliases: ['deflections'],
  ),
  'dfg_pct': _CompareMetric(
    'dfg_pct',
    'DFG%',
    higherIsBetter: false,
    percent: true,
    rawAliases: ['defended_fg_pct'],
  ),
  'rim_dfg_pct': _CompareMetric(
    'rim_dfg_pct',
    'Rim DFG%',
    higherIsBetter: false,
    percent: true,
  ),
  'three_dfg_pct': _CompareMetric(
    'three_dfg_pct',
    '3P DFG%',
    higherIsBetter: false,
    percent: true,
  ),
  'bpm': _CompareMetric('bpm', 'BPM'),
  'plus_minus': _CompareMetric('plus_minus', '+/-'),
  'game_score_proxy': _CompareMetric('game_score_proxy', 'Production'),
};

const _customMetricGroups = <String, List<_CompareMetric>>{
  'Basic': [
    _metricCatalog['gp']!,
    _metricCatalog['min']!,
    _metricCatalog['pts']!,
    _metricCatalog['reb']!,
    _metricCatalog['ast']!,
    _metricCatalog['stl']!,
    _metricCatalog['blk']!,
    _metricCatalog['tov']!,
    _metricCatalog['pf']!,
  ],
  'Shooting & Efficiency': [
    _metricCatalog['fg_pct']!,
    _metricCatalog['two_pct']!,
    _metricCatalog['three_pm']!,
    _metricCatalog['three_pct']!,
    _metricCatalog['ft_pct']!,
    _metricCatalog['efg_pct']!,
    _metricCatalog['ts_pct']!,
    _metricCatalog['points_per_shot']!,
    _metricCatalog['three_rate']!,
    _metricCatalog['ft_rate']!,
  ],
  'Playmaking & Rebounding': [
    _metricCatalog['ast_tov']!,
    _metricCatalog['oreb']!,
    _metricCatalog['dreb']!,
  ],
  'Defense & Impact': [
    _metricCatalog['stocks']!,
    _metricCatalog['defense_events']!,
    _metricCatalog['deflections_pg']!,
    _metricCatalog['dfg_pct']!,
    _metricCatalog['rim_dfg_pct']!,
    _metricCatalog['three_dfg_pct']!,
    _metricCatalog['bpm']!,
    _metricCatalog['plus_minus']!,
    _metricCatalog['game_score_proxy']!,
  ],
};

const _categories = <String, List<_CompareMetric>>{
  'Basic': [
    _metricCatalog['pts']!,
    _metricCatalog['reb']!,
    _metricCatalog['ast']!,
    _metricCatalog['stl']!,
    _metricCatalog['blk']!,
    _metricCatalog['tov']!,
    _metricCatalog['pf']!,
  ],
  'Shooting': [
    _metricCatalog['fg_pct']!,
    _metricCatalog['two_pct']!,
    _metricCatalog['three_pm']!,
    _metricCatalog['three_pct']!,
    _metricCatalog['ft_pct']!,
    _metricCatalog['efg_pct']!,
    _metricCatalog['ts_pct']!,
    _metricCatalog['three_rate']!,
    _metricCatalog['ft_rate']!,
  ],
  'Playmaking': [
    _metricCatalog['ast']!,
    _metricCatalog['tov']!,
    _metricCatalog['ast_tov']!,
  ],
  'Rebounding': [
    _metricCatalog['reb']!,
    _metricCatalog['oreb']!,
    _metricCatalog['dreb']!,
  ],
  'Defense': [
    _metricCatalog['stl']!,
    _metricCatalog['blk']!,
    _metricCatalog['stocks']!,
    _metricCatalog['defense_events']!,
    _metricCatalog['pf']!,
    _metricCatalog['deflections_pg']!,
    _metricCatalog['dfg_pct']!,
    _metricCatalog['rim_dfg_pct']!,
    _metricCatalog['three_dfg_pct']!,
  ],
  'Impact': [
    _metricCatalog['bpm']!,
    _metricCatalog['plus_minus']!,
    _metricCatalog['game_score_proxy']!,
    _metricCatalog['ts_pct']!,
    _metricCatalog['ast_tov']!,
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

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
