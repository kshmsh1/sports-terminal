import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaTeamComparisonScreen extends StatefulWidget {
  const WebsiteNbaTeamComparisonScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaTeamComparisonScreen> createState() =>
      _WebsiteNbaTeamComparisonScreenState();
}

class _WebsiteNbaTeamComparisonScreenState
    extends State<WebsiteNbaTeamComparisonScreen> {
  static const _savedViewsKey = 'nba_team_compare_saved_views_v1';
  static const _maxTeams = 5;
  static const _maxSavedViews = 8;
  final _api = const WebsiteNbaApiService();
  final List<_TeamSlot> _slots = [
    _TeamSlot(season: '2025-26'),
    _TeamSlot(season: '2025-26'),
  ];

  List<WebsiteNbaSeason> _seasons = const [];
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  String _category = 'Overview';
  bool _lockSeasons = true;
  final List<_SavedTeamView> _savedViews = [];
  String? _activeSavedViewId;
  late Future<_TeamComparisonData> _future;

  @override
  void initState() {
    super.initState();
    _future = _initialize();
  }

  Future<_TeamComparisonData> _initialize() async {
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

  Future<_TeamComparisonData> _loadData() async {
    final rowsBySeason = <String, List<_TeamRow>>{};
    for (final season in _slots.map((slot) => slot.season).toSet()) {
      final snapshot = await _api.seasonSnapshot(
        season,
        seasonType:
            _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
      );
      rowsBySeason[season] = _teamRows(snapshot);
    }

    for (var index = 0; index < _slots.length; index++) {
      final slot = _slots[index];
      final rows = rowsBySeason[slot.season] ?? const <_TeamRow>[];
      if (rows.isEmpty) {
        slot.teamKey = null;
        continue;
      }
      if (!rows.any((row) => row.teamKey == slot.teamKey)) {
        final used = <String>{
          for (var other = 0; other < _slots.length; other++)
            if (other != index && _slots[other].season == slot.season)
              if (_slots[other].teamKey != null) _slots[other].teamKey!,
        };
        slot.teamKey = rows
            .firstWhere(
              (row) => !used.contains(row.teamKey),
              orElse: () => rows.first,
            )
            .teamKey;
      }
    }
    return _TeamComparisonData(rowsBySeason);
  }

  void _reload() => setState(() => _future = _loadData());

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
                (item) => _SavedTeamView.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              ),
        );
    } catch (_) {
      // Saved comparison views are local convenience state only.
    }
  }

  Future<void> _persistSavedViews() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedViewsKey,
      jsonEncode([for (final view in _savedViews) view.toJson()]),
    );
  }

  _SavedTeamView _captureView({required String id, required String name}) =>
      _SavedTeamView(
        id: id,
        name: name,
        seasonType: _seasonType.name,
        category: _category,
        lockSeasons: _lockSeasons,
        slots: [
          for (final slot in _slots)
            _SavedTeamSlot(season: slot.season, teamKey: slot.teamKey ?? ''),
        ],
      );

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
        const SnackBar(content: Text('You can save up to 8 team comparisons.')),
      );
      return;
    }
    final controller = TextEditingController(
      text: 'Team Comparison ${_savedViews.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save team comparison'),
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

  void _applySavedView(_SavedTeamView view) {
    setState(() {
      _seasonType = NbaStatsSeasonType.values.firstWhere(
        (value) => value.name == view.seasonType,
        orElse: () => NbaStatsSeasonType.regular,
      );
      _category = _teamCategories.containsKey(view.category)
          ? view.category
          : 'Overview';
      _lockSeasons = view.lockSeasons;
      _slots
        ..clear()
        ..addAll(
          view.slots
              .take(_maxTeams)
              .map(
                (slot) => _TeamSlot(
                  season: slot.season,
                  teamKey: slot.teamKey.isEmpty ? null : slot.teamKey,
                ),
              ),
        );
      while (_slots.length < 2) {
        _slots.add(_TeamSlot(season: _seasons.isEmpty ? '2025-26' : _seasons.first.id));
      }
      _activeSavedViewId = view.id;
      _future = _loadData();
    });
  }

  Future<void> _deleteSavedView(_SavedTeamView view) async {
    _savedViews.removeWhere((item) => item.id == view.id);
    if (_activeSavedViewId == view.id) _activeSavedViewId = null;
    await _persistSavedViews();
    if (mounted) setState(() {});
  }

  void _setSeason(int index, String season) {
    if (_lockSeasons) {
      for (final slot in _slots) {
        slot
          ..season = season
          ..teamKey = null;
      }
    } else {
      _slots[index]
        ..season = season
        ..teamKey = null;
    }
    _reload();
  }

  void _addTeam() {
    if (_slots.length >= _maxTeams) return;
    setState(() {
      _slots.add(_TeamSlot(season: _slots.last.season));
      _future = _loadData();
    });
  }

  void _removeTeam(int index) {
    if (_slots.length <= 2) return;
    setState(() {
      _slots.removeAt(index);
      _future = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TeamComparisonData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 460,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _TeamError(error: snapshot.error, onRetry: _reload);
        }
        return _buildPage(context, snapshot.data!);
      },
    );
  }

  Widget _buildPage(BuildContext context, _TeamComparisonData data) {
    final colors = Theme.of(context).colorScheme;
    final palette = <Color>[
      colors.primary,
      colors.tertiary,
      colors.secondary,
      const Color(0xFFFFB74D),
      const Color(0xFF80CBC4),
    ];
    final selected = <_SelectedTeam>[];
    for (var index = 0; index < _slots.length; index++) {
      final slot = _slots[index];
      final row = _findTeam(data.rowsBySeason[slot.season], slot.teamKey);
      if (row != null) {
        selected.add(
          _SelectedTeam(row: row, season: slot.season, color: palette[index]),
        );
      }
    }
    final metrics = [
      for (final key in _teamCategories[_category] ?? const <String>[])
        if (_teamMetricCatalog[key] != null) _teamMetricCatalog[key]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Team Comparison Lab',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
            const Chip(
              avatar: Icon(Icons.storage_rounded, size: 17),
              label: Text('Static team history'),
            ),
            FilledButton.icon(
              onPressed: _slots.length < _maxTeams ? _addTeam : null,
              icon: const Icon(Icons.group_add_rounded),
              label: Text(_slots.length < _maxTeams ? 'Add team' : '5 teams max'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Compare team seasons and playoff runs across eras using results, shooting, rebounding, playmaking and efficiency.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
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
                      slot.teamKey = null;
                    }
                    _reload();
                  },
                ),
                FilterChip(
                  selected: _lockSeasons,
                  avatar: Icon(
                    _lockSeasons ? Icons.link_rounded : Icons.link_off_rounded,
                    size: 18,
                  ),
                  label: Text(_lockSeasons ? 'Seasons linked' : 'Cross-era mode'),
                  onSelected: (value) {
                    setState(() {
                      _lockSeasons = value;
                      if (value && _slots.isNotEmpty) {
                        final season = _slots.first.season;
                        for (final slot in _slots) {
                          slot
                            ..season = season
                            ..teamKey = null;
                        }
                        _future = _loadData();
                      }
                    });
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveCurrent(saveAs: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveCurrent(saveAs: true),
                  icon: const Icon(Icons.save_as_outlined),
                  label: const Text('Save As'),
                ),
              ],
            ),
          ),
        ),
        if (_savedViews.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final view in _savedViews)
                InputChip(
                  selected: view.id == _activeSavedViewId,
                  label: Text(view.name),
                  onPressed: () => _applySavedView(view),
                  onDeleted: () => _deleteSavedView(view),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < _slots.length; index++) ...[
                SizedBox(
                  width: 280,
                  child: _TeamSelectorCard(
                    label: 'Team ${String.fromCharCode(65 + index)}',
                    accent: palette[index],
                    season: _slots[index].season,
                    seasons: _seasons,
                    rows: data.rowsBySeason[_slots[index].season] ??
                        const <_TeamRow>[],
                    teamKey: _slots[index].teamKey,
                    canRemove: _slots.length > 2,
                    onSeason: (value) => _setSeason(index, value),
                    onTeam: (value) =>
                        setState(() => _slots[index].teamKey = value),
                    onRemove: () => _removeTeam(index),
                    onOpen: () {
                      final row = _findTeam(
                        data.rowsBySeason[_slots[index].season],
                        _slots[index].teamKey,
                      );
                      if (row == null) return;
                      openWebsiteNbaTeamPage(
                        context,
                        session: widget.session,
                        teamKey: row.teamKey,
                        teamName: row.name,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in _teamCategories.keys)
                ChoiceChip(
                  selected: _category == category,
                  label: Text(category),
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _TeamMetricTable(players: selected, metrics: metrics),
          const SizedBox(height: 12),
          Text(
            '★ marks the most favorable available value among the selected teams. Lower defensive rating, turnovers, fouls and opponent scoring are treated as better.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _TeamSelectorCard extends StatelessWidget {
  const _TeamSelectorCard({
    required this.label,
    required this.accent,
    required this.season,
    required this.seasons,
    required this.rows,
    required this.teamKey,
    required this.canRemove,
    required this.onSeason,
    required this.onTeam,
    required this.onRemove,
    required this.onOpen,
  });

  final String label;
  final Color accent;
  final String season;
  final List<WebsiteNbaSeason> seasons;
  final List<_TeamRow> rows;
  final String? teamKey;
  final bool canRemove;
  final ValueChanged<String> onSeason;
  final ValueChanged<String> onTeam;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final team = _findTeam(rows, teamKey);
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
                      ),
                    ),
                    const Spacer(),
                    if (canRemove)
                      IconButton(
                        tooltip: 'Remove team',
                        onPressed: onRemove,
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
                DropdownButtonFormField<String>(
                  key: ValueKey('$label-$season-$teamKey'),
                  initialValue: teamKey,
                  decoration: const InputDecoration(
                    labelText: 'Team',
                    isDense: true,
                  ),
                  items: [
                    for (final row in rows)
                      DropdownMenuItem(
                        value: row.teamKey,
                        child: Text('${row.name} (${row.abbreviation})'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onTeam(value);
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  height: 96,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shield_outlined, size: 48, color: accent),
                ),
                const SizedBox(height: 12),
                if (team != null) ...[
                  Text(
                    team.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${team.wins.round()}-${team.losses.round()} · ${(team.winPct * 100).toStringAsFixed(1)}%',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Open canonical team page',
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

class _TeamMetricTable extends StatelessWidget {
  const _TeamMetricTable({required this.players, required this.metrics});
  final List<_SelectedTeam> players;
  final List<_TeamMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final width = math.max(
      180.0 + 170.0 * players.length,
      MediaQuery.sizeOf(context).width - 90,
    );
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: width,
          child: Table(
            columnWidths: {
              0: const FixedColumnWidth(150),
              for (var index = 0; index < players.length; index++)
                index + 1: const FlexColumnWidth(),
            },
            children: [
              TableRow(
                children: [
                  const _TeamCell('METRIC', bold: true),
                  for (final team in players)
                    _TeamCell(
                      '${team.row.abbreviation}\n${team.season}',
                      bold: true,
                      color: team.color,
                    ),
                ],
              ),
              for (final metric in metrics) _row(context, metric),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _row(BuildContext context, _TeamMetric metric) {
    final values = [for (final team in players) metric.value(team.row)];
    final winners = metric.winners(values);
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      children: [
        _TeamCell(metric.label, bold: true),
        for (var index = 0; index < players.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                  metric.format(values[index]),
                  style: TextStyle(
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

class _TeamCell extends StatelessWidget {
  const _TeamCell(this.text, {this.bold = false, this.color});
  final String text;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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

class _TeamError extends StatelessWidget {
  const _TeamError({required this.error, required this.onRetry});
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
                'Team comparison data unavailable',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('${error ?? 'Static team data is not available.'}'),
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

class _SavedTeamSlot {
  const _SavedTeamSlot({required this.season, required this.teamKey});

  final String season;
  final String teamKey;

  factory _SavedTeamSlot.fromJson(Map<String, dynamic> json) => _SavedTeamSlot(
        season: json['season']?.toString() ?? '2025-26',
        teamKey: json['teamKey']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'season': season,
        'teamKey': teamKey,
      };
}

class _SavedTeamView {
  const _SavedTeamView({
    required this.id,
    required this.name,
    required this.seasonType,
    required this.category,
    required this.lockSeasons,
    required this.slots,
  });

  final String id;
  final String name;
  final String seasonType;
  final String category;
  final bool lockSeasons;
  final List<_SavedTeamSlot> slots;

  factory _SavedTeamView.fromJson(Map<String, dynamic> json) => _SavedTeamView(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Saved comparison',
        seasonType: json['seasonType']?.toString() ?? 'regular',
        category: json['category']?.toString() ?? 'Overview',
        lockSeasons: json['lockSeasons'] == true,
        slots: [
          for (final item in (json['slots'] is List ? json['slots'] as List : const []))
            if (item is Map)
              _SavedTeamSlot.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seasonType': seasonType,
        'category': category,
        'lockSeasons': lockSeasons,
        'slots': [for (final slot in slots) slot.toJson()],
      };
}

class _TeamSlot {
  _TeamSlot({required this.season, this.teamKey});
  String season;
  String? teamKey;
}

class _TeamComparisonData {
  const _TeamComparisonData(this.rowsBySeason);
  final Map<String, List<_TeamRow>> rowsBySeason;
}

class _SelectedTeam {
  const _SelectedTeam({
    required this.row,
    required this.season,
    required this.color,
  });
  final _TeamRow row;
  final String season;
  final Color color;
}

class _TeamRow {
  const _TeamRow({
    required this.teamKey,
    required this.name,
    required this.abbreviation,
    required this.values,
  });

  final String teamKey;
  final String name;
  final String abbreviation;
  final Map<String, double> values;

  double get wins => values['wins'] ?? 0;
  double get losses => values['losses'] ?? 0;
  double get winPct {
    final games = wins + losses;
    return games <= 0 ? 0 : wins / games;
  }
}

class _TeamMetric {
  const _TeamMetric(
    this.key,
    this.label, {
    this.higherIsBetter = true,
    this.percent = false,
  });

  final String key;
  final String label;
  final bool higherIsBetter;
  final bool percent;

  double? value(_TeamRow row) => row.values[key];

  Set<int> winners(List<double?> values) {
    final available = <int, double>{
      for (var index = 0; index < values.length; index++)
        if (values[index] != null) index: values[index]!,
    };
    if (available.isEmpty) return const {};
    final best = higherIsBetter
        ? available.values.reduce(math.max)
        : available.values.reduce(math.min);
    return {
      for (final item in available.entries)
        if ((item.value - best).abs() < .000001) item.key,
    };
  }

  String format(double? value) {
    if (value == null || !value.isFinite) return '—';
    if (percent) return '${(value * 100).toStringAsFixed(1)}%';
    return value.toStringAsFixed(1);
  }
}

List<_TeamRow> _teamRows(NbaTerminalSeedSnapshot snapshot) {
  final logsByTeam = <String, List<Map<String, dynamic>>>{};
  for (final log in snapshot.teamGameLogs) {
    final key = _text(log['team_id']);
    if (key.isEmpty) continue;
    logsByTeam.putIfAbsent(key, () => []).add(log);
  }

  final rows = <_TeamRow>[];
  for (final record in snapshot.teamRecords) {
    final key = _text(record['team_id']);
    if (key.isEmpty) continue;
    final games = _num(record['games']) ?? 0;
    final wins = _num(record['wins']) ?? 0;
    final losses = _num(record['losses']) ?? math.max(0, games - wins);
    final logs = logsByTeam[key] ?? const <Map<String, dynamic>>[];
    final totals = <String, double>{};
    for (final log in logs) {
      for (final field in _teamLogFields) {
        totals[field] = (totals[field] ?? 0) + (_num(log[field]) ?? 0);
      }
    }
    final denom = logs.isNotEmpty ? logs.length.toDouble() : (games > 0 ? games : 1);
    final fgm = totals['field_goals_made'] ?? 0;
    final fga = totals['field_goal_attempts'] ?? 0;
    final threes = totals['three_pointers_made'] ?? 0;
    final threeA = totals['three_point_attempts'] ?? 0;
    final ftm = totals['free_throws_made'] ?? 0;
    final fta = totals['free_throw_attempts'] ?? 0;
    final pts = totals['points'] ?? (_num(record['points']) ?? 0);
    final oppPts = totals['opponent_points'] ?? (_num(record['opponent_points']) ?? 0);

    final values = <String, double>{
      'games': games,
      'wins': wins,
      'losses': losses,
      'win_pct': games > 0 ? wins / games : 0,
      if (_num(record['pace']) != null) 'pace': _num(record['pace'])!,
      if (_num(record['offensive_rating']) != null)
        'ortg': _num(record['offensive_rating'])!,
      if (_num(record['defensive_rating']) != null)
        'drtg': _num(record['defensive_rating'])!,
      if (_num(record['net_rating']) != null)
        'net_rtg': _num(record['net_rating'])!,
      if (_num(record['srs']) != null) 'srs': _num(record['srs'])!,
      'ppg': pts / denom,
      'opp_ppg': oppPts / denom,
      'point_diff': (pts - oppPts) / denom,
      'fg_pct': fga > 0 ? fgm / fga : 0,
      'three_pct': threeA > 0 ? threes / threeA : 0,
      'ft_pct': fta > 0 ? ftm / fta : 0,
      'efg_pct': fga > 0 ? (fgm + .5 * threes) / fga : 0,
      'ts_pct': (fga + .44 * fta) > 0 ? pts / (2 * (fga + .44 * fta)) : 0,
      for (final field in _teamLogFields)
        '${field}_pg': (totals[field] ?? 0) / denom,
    };

    rows.add(
      _TeamRow(
        teamKey: key,
        name: _text(record['team_name'], key),
        abbreviation: _text(record['team_abbreviation'], key),
        values: values,
      ),
    );
  }
  rows.sort((a, b) => a.name.compareTo(b.name));
  return rows;
}

_TeamRow? _findTeam(List<_TeamRow>? rows, String? key) {
  if (rows == null || key == null) return null;
  for (final row in rows) {
    if (row.teamKey == key) return row;
  }
  return null;
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}

const _teamLogFields = <String>[
  'points',
  'opponent_points',
  'field_goals_made',
  'field_goal_attempts',
  'three_pointers_made',
  'three_point_attempts',
  'free_throws_made',
  'free_throw_attempts',
  'offensive_rebounds',
  'defensive_rebounds',
  'rebounds',
  'assists',
  'steals',
  'blocks',
  'turnovers',
  'personal_fouls',
];

final Map<String, _TeamMetric> _teamMetricCatalog = {
  'wins': const _TeamMetric('wins', 'Wins'),
  'losses': const _TeamMetric('losses', 'Losses', higherIsBetter: false),
  'win_pct': const _TeamMetric('win_pct', 'Win%', percent: true),
  'ppg': const _TeamMetric('ppg', 'PTS/G'),
  'opp_ppg': const _TeamMetric('opp_ppg', 'Opp PTS/G', higherIsBetter: false),
  'point_diff': const _TeamMetric('point_diff', 'Point Diff'),
  'pace': const _TeamMetric('pace', 'Pace'),
  'ortg': const _TeamMetric('ortg', 'Off Rtg'),
  'drtg': const _TeamMetric('drtg', 'Def Rtg', higherIsBetter: false),
  'net_rtg': const _TeamMetric('net_rtg', 'Net Rtg'),
  'srs': const _TeamMetric('srs', 'SRS'),
  'fg_pct': const _TeamMetric('fg_pct', 'FG%', percent: true),
  'three_pct': const _TeamMetric('three_pct', '3P%', percent: true),
  'ft_pct': const _TeamMetric('ft_pct', 'FT%', percent: true),
  'efg_pct': const _TeamMetric('efg_pct', 'eFG%', percent: true),
  'ts_pct': const _TeamMetric('ts_pct', 'TS%', percent: true),
  'assists_pg': const _TeamMetric('assists_pg', 'AST/G'),
  'turnovers_pg': const _TeamMetric('turnovers_pg', 'TOV/G', higherIsBetter: false),
  'rebounds_pg': const _TeamMetric('rebounds_pg', 'REB/G'),
  'offensive_rebounds_pg': const _TeamMetric('offensive_rebounds_pg', 'OREB/G'),
  'defensive_rebounds_pg': const _TeamMetric('defensive_rebounds_pg', 'DREB/G'),
  'steals_pg': const _TeamMetric('steals_pg', 'STL/G'),
  'blocks_pg': const _TeamMetric('blocks_pg', 'BLK/G'),
  'personal_fouls_pg': const _TeamMetric('personal_fouls_pg', 'PF/G', higherIsBetter: false),
};

final Map<String, List<String>> _teamCategories = {
  'Overview': ['wins', 'losses', 'win_pct', 'ppg', 'opp_ppg', 'point_diff', 'srs'],
  'Offense': ['ppg', 'ortg', 'pace', 'ts_pct', 'efg_pct', 'assists_pg', 'turnovers_pg'],
  'Shooting': ['fg_pct', 'three_pct', 'ft_pct', 'efg_pct', 'ts_pct'],
  'Playmaking': ['assists_pg', 'turnovers_pg'],
  'Rebounding': ['rebounds_pg', 'offensive_rebounds_pg', 'defensive_rebounds_pg'],
  'Defense': ['opp_ppg', 'drtg', 'steals_pg', 'blocks_pg', 'personal_fouls_pg'],
  'Impact': ['win_pct', 'point_diff', 'ortg', 'drtg', 'net_rtg', 'srs'],
};
