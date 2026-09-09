import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/website_sticky_stats_table.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaTeamCompareScreen extends StatefulWidget {
  const WebsiteNbaTeamCompareScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaTeamCompareScreen> createState() =>
      _WebsiteNbaTeamCompareScreenState();
}

class _WebsiteNbaTeamCompareScreenState
    extends State<WebsiteNbaTeamCompareScreen> {
  final _api = const WebsiteNbaApiService();
  final _search = TextEditingController();

  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  final List<_SelectedTeam> _selected = [];
  List<_SelectedTeam> _suggestions = const [];
  bool _searching = false;
  int _request = 0;
  String _season = '2025-26';
  String _seasonType = 'regular';
  String _metricGroup = 'Overview';

  @override
  void initState() {
    super.initState();
    _seasonsFuture = _loadSeasons();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<WebsiteNbaSeason>> _loadSeasons() async {
    final seasons = await _api.seasons();
    if (seasons.isNotEmpty) {
      _seasons = seasons;
      _season = seasons.firstWhere(
        (item) => item.id == '2025-26',
        orElse: () => seasons.first,
      ).id;
    }
    return seasons;
  }

  Future<void> _searchTeams(String value) async {
    final query = value.trim();
    final request = ++_request;
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await _api.searchEntities(
        query,
        kinds: 'team',
        limitPerKind: 12,
      );
      if (!mounted || request != _request) return;
      final groups = result['groups'];
      final map = groups is Map ? groups : const {};
      final rows = map['teams'];
      final suggestions = <_SelectedTeam>[];
      if (rows is List) {
        for (final item in rows) {
          if (item is! Map) continue;
          final key = (item['team_key'] ?? '').toString();
          if (key.isEmpty || _selected.any((team) => team.key == key)) continue;
          suggestions.add(
            _SelectedTeam(
              key: key,
              name: (item['canonical_name'] ?? 'Team').toString(),
              abbreviation: (item['abbreviation'] ?? '').toString(),
            ),
          );
        }
      }
      setState(() {
        _suggestions = suggestions;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
    }
  }

  void _addTeam(_SelectedTeam team) {
    if (_selected.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 teams selected.')),
      );
      return;
    }
    setState(() {
      _selected.add(team);
      _search.clear();
      _suggestions = const [];
    });
  }

  void _removeTeam(String key) {
    setState(() => _selected.removeWhere((team) => team.key == key));
  }

  Future<List<_TeamCompareRow>> _loadComparison() async {
    final result = <_TeamCompareRow>[];
    for (final team in _selected) {
      final dossier = await _api.teamDossier(team.key);
      final seasons = _maps(dossier['seasons']);
      Map<String, dynamic>? match;
      for (final row in seasons) {
        if (_text(row['season_id']) != _season) continue;
        if (_normalizeSeasonType(_text(row['season_type'])) != _seasonType) continue;
        match = row;
        break;
      }
      result.add(_TeamCompareRow(team: team, row: match ?? const {}));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || _seasons.isEmpty) {
          return _CompareError(
            error: snapshot.error,
            onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
          );
        }
        return _buildPage(context);
      },
    );
  }

  Widget _buildPage(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Compare',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Compare up to four canonical NBA teams on the same season and season type using the static historical release.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 145,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('team-compare-season-$_season'),
                        initialValue: _season,
                        decoration: const InputDecoration(
                          labelText: 'Season',
                          isDense: true,
                        ),
                        items: [
                          for (final item in _seasons)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(item.id),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _season = value);
                        },
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'regular',
                          label: Text('Regular Season'),
                        ),
                        ButtonSegment(
                          value: 'playoffs',
                          label: Text('Playoffs'),
                        ),
                      ],
                      selected: {_seasonType},
                      onSelectionChanged: (value) {
                        setState(() => _seasonType = value.first);
                      },
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('team-compare-group-$_metricGroup'),
                        initialValue: _metricGroup,
                        decoration: const InputDecoration(
                          labelText: 'Metric group',
                          isDense: true,
                        ),
                        items: [
                          for (final name in _metricGroups.keys)
                            DropdownMenuItem(value: name, child: Text(name)),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _metricGroup = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 270,
                      child: TextField(
                        controller: _search,
                        enabled: _selected.length < 4,
                        onChanged: _searchTeams,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: _selected.length >= 4
                              ? 'Maximum 4 teams selected'
                              : 'Search teams to compare',
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_selected.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _selected.clear()),
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        label: const Text('Clear teams'),
                      ),
                  ],
                ),
                if (_searching) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final team in _suggestions)
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            team.abbreviation.isEmpty
                                ? team.name
                                : '${team.abbreviation} · ${team.name}',
                          ),
                          onPressed: () => _addTeam(team),
                        ),
                    ],
                  ),
                ],
                if (_selected.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final team in _selected)
                        InputChip(
                          label: Text(
                            team.abbreviation.isEmpty
                                ? team.name
                                : '${team.abbreviation} · ${team.name}',
                          ),
                          onDeleted: () => _removeTeam(team.key),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_selected.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Search for two to four teams above. Comparison stays locked to the selected season and season type so results remain directly comparable.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
              ),
            ),
          )
        else
          FutureBuilder<List<_TeamCompareRow>>(
            key: ValueKey(
              'team-compare-$_season-$_seasonType-$_metricGroup-${_selected.map((team) => team.key).join('|')}',
            ),
            future: _loadComparison(),
            builder: (context, comparison) {
              if (comparison.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (comparison.hasError) {
                return _CompareError(
                  error: comparison.error,
                  onRetry: () => setState(() {}),
                );
              }
              return _ComparisonTable(
                session: widget.session,
                rows: comparison.data ?? const [],
                metrics: _metricGroups[_metricGroup]!,
                season: _season,
                seasonType: _seasonType,
              );
            },
          ),
      ],
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.session,
    required this.rows,
    required this.metrics,
    required this.season,
    required this.seasonType,
  });

  final AppSession session;
  final List<_TeamCompareRow> rows;
  final List<_TeamMetric> metrics;
  final String season;
  final String seasonType;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = <WebsiteStickyStatsColumn>[
      const WebsiteStickyStatsColumn(label: Text('Team'), width: 210),
      for (final metric in metrics)
        WebsiteStickyStatsColumn(
          label: Text(metric.label),
          width: metric.width,
          numeric: true,
        ),
    ];
    final tableRows = <List<Widget>>[
      for (final item in rows)
        [
          InkWell(
            onTap: () => openWebsiteNbaTeamPage(
              context,
              session: session,
              teamKey: item.team.key,
              teamName: item.team.name,
            ),
            child: Text(
              item.team.abbreviation.isEmpty
                  ? item.team.name
                  : '${item.team.abbreviation} · ${item.team.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final metric in metrics)
            Text(
              _formatMetric(_metricValue(item.row, metric), metric),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
        ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$season · ${seasonType == 'playoffs' ? 'Playoffs' : 'Regular Season'}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: rows.isEmpty ? null : () => _copyCsv(context),
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: const Text('Copy CSV'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        WebsiteStickyStatsTable(
          columns: columns,
          rows: tableRows,
          firstColumnWidth: 210,
          headerHeight: 43,
          rowHeight: 44,
        ),
        if (rows.any((item) => item.row.isEmpty)) ...[
          const SizedBox(height: 10),
          Text(
            '— indicates that the selected team has no source-backed row for this exact season and season type.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Future<void> _copyCsv(BuildContext context) async {
    final lines = <String>[
      ['Team', ...metrics.map((metric) => metric.label)].join(','),
      for (final item in rows)
        [
          item.team.name,
          for (final metric in metrics)
            _formatMetric(_metricValue(item.row, metric), metric),
        ].map(_csv).join(','),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied team comparison as CSV.')),
    );
  }
}

class _SelectedTeam {
  const _SelectedTeam({
    required this.key,
    required this.name,
    required this.abbreviation,
  });
  final String key;
  final String name;
  final String abbreviation;
}

class _TeamCompareRow {
  const _TeamCompareRow({required this.team, required this.row});
  final _SelectedTeam team;
  final Map<String, dynamic> row;
}

class _TeamMetric {
  const _TeamMetric(
    this.label,
    this.keys, {
    this.width = 72,
    this.percent = false,
    this.perGame = false,
    this.signed = false,
  });

  final String label;
  final List<String> keys;
  final double width;
  final bool percent;
  final bool perGame;
  final bool signed;
}

const _metricGroups = <String, List<_TeamMetric>>{
  'Overview': [
    _TeamMetric('GP', ['games', 'gp'], width: 58),
    _TeamMetric('W', ['wins', 'w'], width: 54),
    _TeamMetric('L', ['losses', 'l'], width: 54),
    _TeamMetric('W%', ['win_pct', 'w_pct'], percent: true),
    _TeamMetric('PPG', ['points', 'pts'], perGame: true),
    _TeamMetric('RPG', ['rebounds', 'reb'], perGame: true),
    _TeamMetric('APG', ['assists', 'ast'], perGame: true),
    _TeamMetric('SPG', ['steals', 'stl'], perGame: true),
    _TeamMetric('BPG', ['blocks', 'blk'], perGame: true),
    _TeamMetric('TPG', ['turnovers', 'tov'], perGame: true),
  ],
  'Shooting': [
    _TeamMetric('FG%', ['fg_pct', 'field_goal_pct'], percent: true),
    _TeamMetric('3P%', ['fg3_pct', 'three_pct'], percent: true),
    _TeamMetric('FT%', ['ft_pct', 'free_throw_pct'], percent: true),
    _TeamMetric('FGM/G', ['fgm', 'field_goals_made'], perGame: true),
    _TeamMetric('FGA/G', ['fga', 'field_goals_attempted'], perGame: true),
    _TeamMetric('3PM/G', ['fg3m', 'three_pm'], perGame: true),
    _TeamMetric('3PA/G', ['fg3a', 'three_pa'], perGame: true),
    _TeamMetric('FTM/G', ['ftm', 'free_throws_made'], perGame: true),
    _TeamMetric('FTA/G', ['fta', 'free_throws_attempted'], perGame: true),
  ],
  'Possession': [
    _TeamMetric('AST/G', ['assists', 'ast'], perGame: true),
    _TeamMetric('TOV/G', ['turnovers', 'tov'], perGame: true),
    _TeamMetric('ORB/G', ['offensive_rebounds', 'oreb'], perGame: true),
    _TeamMetric('DRB/G', ['defensive_rebounds', 'dreb'], perGame: true),
    _TeamMetric('PF/G', ['personal_fouls', 'pf'], perGame: true),
    _TeamMetric('+/-', ['plus_minus'], perGame: true, signed: true),
  ],
  'Advanced': [
    _TeamMetric('ORtg', ['off_rating', 'offensive_rating']),
    _TeamMetric('DRtg', ['def_rating', 'defensive_rating']),
    _TeamMetric('Net', ['net_rating'], signed: true),
    _TeamMetric('Pace', ['pace']),
    _TeamMetric('TS%', ['ts_pct'], percent: true),
    _TeamMetric('eFG%', ['efg_pct'], percent: true),
    _TeamMetric('AST%', ['ast_pct'], percent: true),
    _TeamMetric('REB%', ['reb_pct'], percent: true),
    _TeamMetric('TOV%', ['tm_tov_pct', 'tov_pct'], percent: true),
    _TeamMetric('PIE', ['pie'], percent: true),
  ],
};

num? _metricValue(Map<String, dynamic> row, _TeamMetric metric) {
  num? value;
  for (final key in metric.keys) {
    value = _number(row[key]);
    if (value != null) break;
  }
  if (value == null) return null;
  if (metric.perGame) {
    final gp = _firstNumber(row, const ['games', 'gp']);
    if (gp == null || gp <= 0) return null;
    return value / gp;
  }
  return value;
}

num? _firstNumber(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = _number(row[key]);
    if (value != null) return value;
  }
  return null;
}

num? _number(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

String _formatMetric(num? value, _TeamMetric metric) {
  if (value == null) return '—';
  if (metric.percent) {
    final scaled = value.abs() <= 1.01 ? value * 100 : value;
    return '${scaled.toStringAsFixed(1)}%';
  }
  if (metric.signed && value > 0) return '+${value.toStringAsFixed(1)}';
  if (!metric.perGame && value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String _normalizeSeasonType(String value) =>
    value.toLowerCase().contains('play') ? 'playoffs' : 'regular';

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, field) => MapEntry(key.toString(), field)),
  ];
}

String _csv(String value) {
  if (!value.contains(RegExp(r'[,"\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

class _CompareError extends StatelessWidget {
  const _CompareError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team comparison unavailable',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text('${error ?? 'Static team data could not be read.'}'),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}
