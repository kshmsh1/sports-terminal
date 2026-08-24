import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/website_pagination.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaStatsScreen extends StatefulWidget {
  const WebsiteNbaStatsScreen({super.key, this.session});
  final AppSession? session;

  @override
  State<WebsiteNbaStatsScreen> createState() => _WebsiteNbaStatsScreenState();
}

class _WebsiteNbaStatsScreenState extends State<WebsiteNbaStatsScreen> {
  final _engine = const NbaStatsWorkstationEngine();
  final _api = const WebsiteNbaApiService();
  final _search = TextEditingController();
  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<NbaTerminalSeedSnapshot>? _dataFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  String _team = 'All';
  String _position = 'All';
  String _sortKey = 'pts';
  bool _descending = true;
  int _pageSize = 20;
  int? _customPageSize;
  int _page = 1;

  int get _effectivePageSize => _customPageSize ?? _pageSize;

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
      _season = seasons.firstWhere((item) => item.id == '2025-26', orElse: () => seasons.first).id;
      _dataFuture = _loadData();
    }
    return seasons;
  }

  Future<NbaTerminalSeedSnapshot> _loadData() => _api.seasonSnapshot(
        _season,
        seasonType: _seasonType == NbaStatsSeasonType.playoffs ? 'playoffs' : 'regular',
      );

  void _reload() {
    setState(() {
      _team = 'All';
      _position = 'All';
      _page = 1;
      _dataFuture = _loadData();
    });
  }

  void _resetPage() => setState(() => _page = 1);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, catalog) {
        if (catalog.connectionState != ConnectionState.done) return const _Loading();
        if (catalog.hasError || _seasons.isEmpty || _dataFuture == null) {
          return _ErrorState(error: catalog.error, onRetry: () => setState(() => _seasonsFuture = _loadSeasons()));
        }
        return FutureBuilder<NbaTerminalSeedSnapshot>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _Loading();
            if (snapshot.hasError || snapshot.data == null) return _ErrorState(error: snapshot.error, onRetry: _reload);
            return _pageBody(context, snapshot.data!);
          },
        );
      },
    );
  }

  Widget _pageBody(BuildContext context, NbaTerminalSeedSnapshot data) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(data, basis: NbaStatsBasis.perGame, seasonType: _seasonType);
    final teams = <String>{'All'};
    for (final row in rows) {
      teams.addAll(row.team.split(RegExp(r'[,/ ]+')).where((value) => value.isNotEmpty && value != '—'));
    }
    final teamValues = teams.toList()..sort();
    final query = _search.text.trim().toLowerCase();
    final visible = rows.where((row) {
      if (query.isNotEmpty && !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) return false;
      if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
      if (_position != 'All' && !_matchesPosition(row.position, _position)) return false;
      return true;
    }).toList();
    _engine.sortRows(visible, _sortKey, descending: _descending);

    final pageSize = _effectivePageSize;
    final pageCount = math.max(1, (visible.length / pageSize).ceil());
    final safePage = _page.clamp(1, pageCount);
    if (safePage != _page) _page = safePage;
    final start = (safePage - 1) * pageSize;
    final pagedRows = visible.skip(start).take(pageSize).toList();

    Widget pager() => WebsitePagination(
          totalItems: visible.length,
          pageSize: pageSize,
          currentPage: safePage,
          customPageSize: _customPageSize,
          onPageChanged: (value) => setState(() => _page = value),
          onPageSizeChanged: (value) => setState(() {
            _pageSize = value;
            _customPageSize = null;
            _page = 1;
          }),
          onCustomPageSizeChanged: (value) => setState(() {
            _customPageSize = value;
            _page = 1;
          }),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NBA Stats', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 8),
        Text('Traditional player statistics with regular season and playoff views across the historical NBA corpus.', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45)),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _season,
                      decoration: const InputDecoration(labelText: 'Season', isDense: true),
                      items: [for (final season in _seasons) DropdownMenuItem(value: season.id, child: Text(season.id))],
                      onChanged: (value) {
                        if (value == null || value == _season) return;
                        _season = value;
                        _reload();
                      },
                    ),
                  ),
                  SegmentedButton<NbaStatsSeasonType>(
                    segments: const [
                      ButtonSegment(value: NbaStatsSeasonType.regular, label: Text('Regular Season')),
                      ButtonSegment(value: NbaStatsSeasonType.playoffs, label: Text('Playoffs')),
                    ],
                    selected: {_seasonType},
                    onSelectionChanged: (value) {
                      _seasonType = value.first;
                      _reload();
                    },
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 620 ? constraints.maxWidth : 260,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => _resetPage(),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search players', isDense: true),
                    ),
                  ),
                  _Dropdown(label: 'Team', value: _team, values: teamValues, onChanged: (value) => setState(() { _team = value; _page = 1; })),
                  _Dropdown(label: 'Position', value: _position, values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'], onChanged: (value) => setState(() { _position = value; _page = 1; })),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text('${visible.length} players', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          Text('$_season · ${_seasonType == NbaStatsSeasonType.playoffs ? 'Playoffs' : 'Regular Season'}', style: TextStyle(color: colors.onSurfaceVariant)),
        ]),
        const SizedBox(height: 10),
        pager(),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 48,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 52,
              sortAscending: !_descending,
              sortColumnIndex: _sortColumnIndex(_sortKey),
              columns: [
                const DataColumn(label: Text('Player')),
                const DataColumn(label: Text('Team')),
                const DataColumn(label: Text('Pos')),
                ..._metrics.map((metric) => DataColumn(
                      numeric: true,
                      label: Text(metric.label),
                      onSort: (_, ascending) => setState(() {
                        _sortKey = metric.key;
                        _descending = !ascending;
                        _page = 1;
                      }),
                    )),
              ],
              rows: [
                for (final row in pagedRows)
                  DataRow(cells: [
                    DataCell(
                      Text(row.player, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                      onTap: widget.session == null ? null : () => openWebsiteNbaPlayerPage(context, session: widget.session!, playerKey: row.playerId, playerName: row.player),
                    ),
                    DataCell(
                      Text(row.team, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                      onTap: widget.session == null ? null : () {
                        final team = _primaryTeam(row.team);
                        if (team.isNotEmpty) openWebsiteNbaTeamPage(context, session: widget.session!, teamKey: team, teamName: team);
                      },
                    ),
                    DataCell(Text(row.position)),
                    for (final metric in _metrics) DataCell(Text(_format(row.value(metric.key), metric))),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        pager(),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 145,
        child: DropdownButtonFormField<String>(
          initialValue: values.contains(value) ? value : values.first,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item))],
          onChanged: (next) { if (next != null) onChanged(next); },
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NBA statistics are unavailable', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('Sports Terminal could not read its static NBA season file. ${error ?? ''}'),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ]),
        ),
      );
}

class _Metric {
  const _Metric(this.key, this.label, {this.percent = false, this.integer = false});
  final String key;
  final String label;
  final bool percent;
  final bool integer;
}

const _metrics = <_Metric>[
  _Metric('gp', 'GP', integer: true),
  _Metric('min', 'MPG'),
  _Metric('pts', 'PPG'),
  _Metric('reb', 'RPG'),
  _Metric('ast', 'APG'),
  _Metric('stl', 'SPG'),
  _Metric('blk', 'BPG'),
  _Metric('tov', 'TOV'),
  _Metric('pf', 'PF'),
  _Metric('fg_pct', 'FG%', percent: true),
  _Metric('three_pct', '3P%', percent: true),
  _Metric('ft_pct', 'FT%', percent: true),
];

int? _sortColumnIndex(String key) {
  final index = _metrics.indexWhere((metric) => metric.key == key);
  return index < 0 ? null : index + 3;
}

bool _matchesPosition(String value, String wanted) {
  final positions = RegExp(r'PG|SG|SF|PF|C').allMatches(value.toUpperCase()).map((match) => match.group(0)).whereType<String>().toSet();
  return positions.contains(wanted.toUpperCase());
}

String _format(double? value, _Metric metric) {
  if (value == null) return '—';
  if (metric.integer) return value.round().toString();
  if (metric.percent) return '${(value * 100).toStringAsFixed(1)}%';
  return value.toStringAsFixed(1);
}

String _primaryTeam(String value) {
  final teams = value.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—').toList();
  return teams.isEmpty ? '' : teams.first;
}
