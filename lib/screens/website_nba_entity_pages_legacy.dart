import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_player_profile_presentation.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stat_display_format.dart';
import '../services/website_nba_api_service.dart';
import '../widgets/nba_percentage_heat_cell.dart';

Future<void> openWebsiteNbaPlayerPage(
  BuildContext context, {
  required AppSession session,
  required String playerKey,
  required String playerName,
}) => Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(
          name: '/nba/players/${Uri.encodeComponent(playerKey)}',
        ),
        builder: (_) => WebsiteNbaPlayerPage(
          session: session,
          playerKey: playerKey,
          playerName: playerName,
        ),
      ),
    );

Future<void> openWebsiteNbaTeamPage(
  BuildContext context, {
  required AppSession session,
  required String teamKey,
  required String teamName,
}) => Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(
          name: '/nba/teams/${Uri.encodeComponent(teamKey)}',
        ),
        builder: (_) => WebsiteNbaTeamPage(
          session: session,
          teamKey: teamKey,
          teamName: teamName,
        ),
      ),
    );

class WebsiteNbaPlayerPage extends StatefulWidget {
  const WebsiteNbaPlayerPage({
    super.key,
    required this.session,
    required this.playerKey,
    required this.playerName,
  });

  final AppSession session;
  final String playerKey;
  final String playerName;

  @override
  State<WebsiteNbaPlayerPage> createState() => _WebsiteNbaPlayerPageState();
}

class _WebsiteNbaPlayerPageState extends State<WebsiteNbaPlayerPage> {
  final _api = const WebsiteNbaApiService();
  late Future<_PlayerPageData> _future;
  String _segment = 'regular';
  String _advancedCategory = 'Efficiency';
  final Set<String> _expandedCareerMetrics = {};
  final Set<String> _expandedAdvancedMetrics = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlayerPageData> _load() async {
    final dossier = await _api.playerDossier(widget.playerKey);
    final current = await const NbaTradeContractRepository().load();
    return _PlayerPageData(dossier: dossier, currentContracts: current);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Arcside')),
        body: FutureBuilder<_PlayerPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _EntityError(
                title: widget.playerName,
                error: snapshot.error,
                onRetry: () => setState(() => _future = _load()),
              );
            }
            final data = snapshot.data!;
            final dossier = data.dossier;
            final profile = _map(dossier['profile']);
            final regular = _maps(dossier['regular_seasons']);
            final playoffs = _maps(dossier['playoff_seasons']);
            final selectedRows = _segment == 'playoffs' ? playoffs : regular;
            final name = _text(profile['canonical_name'], widget.playerName);
            final positions = nbaOrderedPositions(_text(
              profile['positions'],
              _text(profile['primary_position']),
            ));
            final awards = _maps(dossier['awards']);
            final allStar = _maps(dossier['all_star']);
            final draft = _maps(dossier['draft']);
            final normalizedName = name.toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'), '',
            );
            final currentMatches = data.currentContracts.records.where((item) =>
              item.player.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ==
                  normalizedName && item.salaryFor('2026-27') > 0,
            );
            final current = currentMatches.isEmpty ? null : currentMatches.first;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 72),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1780),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                      ),
                      if (positions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          positions,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SummaryCards(
                        items: [
                          _SummaryItem('NBA seasons', '${_uniqueSeasons(regular)}'),
                          _SummaryItem(
                            'Playoff seasons',
                            '${_uniqueSeasons(playoffs)}',
                          ),
                          _SummaryItem('All-Star selections', '${_uniqueAllStarYears(allStar)}'),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _SectionHeader(
                        title: 'Career statistics',
                        trailing: SegmentedButton<String>(
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
                          selected: {_segment},
                          onSelectionChanged: (value) =>
                              setState(() => _segment = value.first),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PlayerCareerTable(
                        rows: selectedRows,
                        expanded: _expandedCareerMetrics,
                        onExpand: (key) => setState(() {
                          if (!_expandedCareerMetrics.add(key)) {
                            _expandedCareerMetrics.remove(key);
                          }
                        }),
                      ),
                      const SizedBox(height: 30),
                      const _SectionTitle('Advanced statistics'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final family in _advancedCategories)
                            ChoiceChip(
                              label: Text(family.label),
                              selected: _advancedCategory == family.label,
                              onSelected: (_) => setState(() {
                                _advancedCategory = family.label;
                                _expandedAdvancedMetrics.clear();
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PlayerAdvancedTable(
                        rows: selectedRows,
                        family: _advancedCategories.firstWhere(
                          (item) => item.label == _advancedCategory,
                        ),
                        expanded: _expandedAdvancedMetrics,
                        onExpand: (key) => setState(() {
                          if (!_expandedAdvancedMetrics.add(key)) {
                            _expandedAdvancedMetrics.remove(key);
                          }
                        }),
                      ),
                      const SizedBox(height: 30),
                      const _SectionTitle('Contract'),
                      const SizedBox(height: 10),
                      _ContractSection(
                        current: current,
                        asOf: data.currentContracts.asOf,
                      ),
                      const SizedBox(height: 30),
                      const _SectionTitle('Awards & context'),
                      const SizedBox(height: 10),
                      _AwardsSection(
                        awards: awards,
                        allStar: allStar,
                        draft: draft,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class WebsiteNbaTeamPage extends StatefulWidget {
  const WebsiteNbaTeamPage({
    super.key,
    required this.session,
    required this.teamKey,
    required this.teamName,
  });

  final AppSession session;
  final String teamKey;
  final String teamName;

  @override
  State<WebsiteNbaTeamPage> createState() => _WebsiteNbaTeamPageState();
}

class _WebsiteNbaTeamPageState extends State<WebsiteNbaTeamPage> {
  final _api = const WebsiteNbaApiService();
  late Future<Map<String, dynamic>> _future;
  String _segment = 'regular';

  @override
  void initState() {
    super.initState();
    _future = _api.teamDossier(widget.teamKey);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Arcside')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _EntityError(
                title: widget.teamName,
                error: snapshot.error,
                onRetry: () => setState(
                  () => _future = _api.teamDossier(widget.teamKey),
                ),
              );
            }
            final dossier = snapshot.data!;
            final profile = _map(dossier['profile']);
            final franchise = _map(dossier['franchise']);
            final allSeasons = _maps(dossier['seasons']);
            final seasons = allSeasons
                .where(
                  (row) => _text(row['season_type'], 'regular') == _segment,
                )
                .toList();
            final games = _maps(dossier['recent_games']);
            final players = _maps(dossier['notable_players']);
            final name = _text(profile['canonical_name'], widget.teamName);
            final abbreviation = _text(profile['abbreviation']);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 72),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          abbreviation,
                          _text(franchise['canonical_name']),
                        ].where((value) => value.isNotEmpty).join(' · '),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 22),
                      _SummaryCards(
                        items: [
                          _SummaryItem(
                            'NBA seasons',
                            '${_uniqueSeasons(allSeasons)}',
                          ),
                          _SummaryItem('Recent games', '${games.length}'),
                          _SummaryItem('Players', '${players.length}'),
                          _SummaryItem(
                            'Franchise',
                            _text(franchise['canonical_name'], '—'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _SectionHeader(
                        title: 'Season history',
                        trailing: SegmentedButton<String>(
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
                          selected: {_segment},
                          onSelectionChanged: (value) =>
                              setState(() => _segment = value.first),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _TeamSeasonTable(rows: seasons),
                      const SizedBox(height: 30),
                      const _SectionTitle('Notable players'),
                      const SizedBox(height: 10),
                      Card(
                        child: Column(
                          children: [
                            if (players.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No source-backed player history is available for this team.',
                                  ),
                                ),
                              ),
                            for (var i = 0; i < players.length; i++) ...[
                              ListTile(
                                title: Text(
                                  _text(players[i]['player_name'], 'Player'),
                                ),
                                subtitle: Text(
                                  '${_text(players[i]['first_season'])} – ${_text(players[i]['last_season'])}',
                                ),
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                                onTap: () {
                                  final key = _text(players[i]['player_key']);
                                  if (key.isEmpty) return;
                                  openWebsiteNbaPlayerPage(
                                    context,
                                    session: widget.session,
                                    playerKey: key,
                                    playerName: _text(
                                      players[i]['player_name'],
                                      'Player',
                                    ),
                                  );
                                },
                              ),
                              if (i != players.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const _SectionTitle('Recent games'),
                      const SizedBox(height: 10),
                      _TeamGames(rows: games),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

/// Player career and Advanced Stats share the same compact, expandable table.
class _PlayerCareerTable extends StatelessWidget {
  const _PlayerCareerTable({
    required this.rows, required this.expanded, required this.onExpand,
  });
  final List<Map<String, dynamic>> rows;
  final Set<String> expanded;
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) => _SeasonMetricTable(
    rows: rows,
    family: nbaTerminalFamily('basic'),
    expanded: expanded,
    onExpand: onExpand,
  );
}

class _PlayerAdvancedTable extends StatelessWidget {
  const _PlayerAdvancedTable({
    required this.rows, required this.family,
    required this.expanded, required this.onExpand,
  });
  final List<Map<String, dynamic>> rows;
  final NbaTerminalStatFamily family;
  final Set<String> expanded;
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) => _SeasonMetricTable(
    rows: rows, family: family, expanded: expanded, onExpand: onExpand,
  );
}

class _SeasonMetricTable extends StatelessWidget {
  const _SeasonMetricTable({
    required this.rows,
    required this.family,
    required this.expanded,
    required this.onExpand,
  });
  final List<Map<String, dynamic>> rows;
  final NbaTerminalStatFamily family;
  final Set<String> expanded;
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) {
    final ordered = [...rows]
      ..sort((a, b) =>
          _text(b['season_id']).compareTo(_text(a['season_id'])));
    final keys = nbaVisibleMetricKeys(family, expanded);
    final metrics = [
      for (final key in keys)
        if (nbaTerminalMetricByKey[key] case final NbaTerminalMetric metric)
          if (ordered.any((row) =>
              _seasonSourceValue(row, metric) != null))
            metric,
    ];
    if (ordered.isEmpty || metrics.isEmpty) {
      return _EmptyCard(
        '${family.label} has no published source-backed fields '
        'for these player seasons. Missing historical statistics '
        'are not reconstructed.',
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 19,
          horizontalMargin: 12,
          headingRowHeight: 38,
          dataRowMinHeight: 35,
          dataRowMaxHeight: 38,
          headingTextStyle: TextStyle(
            fontSize: 11, color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
          dataTextStyle: TextStyle(fontSize: 11.5,
            color: colors.onSurface),
          columns: [
            const DataColumn(label: Text('Season')),
            const DataColumn(label: Text('Team')),
            const DataColumn(label: Text('Pos')),
            for (final metric in metrics)
              DataColumn(
                numeric: metric.format != NbaTerminalMetricFormat.feetInches,
                label: InkWell(
                  onTap: _isExpandable(metric)
                      ? () => onExpand(metric.key) : null,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_isExpandable(metric)) ...[
                      Icon(expanded.contains(metric.key)
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.chevron_right_rounded, size: 14),
                      const SizedBox(width: 2),
                    ],
                    Text(_playerTableMetricLabel(metric)),
                  ]),
                ),
              ),
          ],
          rows: [
            for (final row in ordered)
              DataRow(cells: [
                DataCell(Text(_text(row['season_id']))),
                DataCell(Text(_text(row['team_abbreviation'], '—'))),
                DataCell(Text(nbaOrderedPositions(_textAny(row,
                  const ['positions', 'position', 'pos'], fallback: '—')))),
                for (final metric in metrics)
                  _playerProfileMetricCell(row, metric),
              ]),
          ],
        ),
      ),
    );
  }

  bool _isExpandable(NbaTerminalMetric metric) =>
      (family.expansionOverrides[metric.key] ?? metric.children).isNotEmpty;
}

DataCell _playerProfileMetricCell(
    Map<String, dynamic> row, NbaTerminalMetric metric) {
  final value = _seasonSourceValue(row, metric);
  final text = _formatSeasonMetric(metric, value);
  final heat = switch (metric.key) {
    'fg_pct' => NbaPercentageHeatMetric.fieldGoal,
    'three_pct' => NbaPercentageHeatMetric.threePoint,
    'ft_pct' => NbaPercentageHeatMetric.freeThrow,
    _ => null,
  };
  if (heat == null) return DataCell(Text(text));
  return DataCell(NbaPercentageHeatCell(
      metric: heat, value: value, child: Text(text)));
}

/// Only read source-provided fields. Season counting values are stored as
/// totals in canonical player-season rows, so divide by actual source GP.
double? _seasonSourceValue(
    Map<String, dynamic> row, NbaTerminalMetric metric) {
  const counting = <String, List<String>>{
    'mpg': ['minutes', 'min'], 'ppg': ['pts', 'points'],
    'rpg': ['reb', 'rebounds'], 'apg': ['ast', 'assists'],
    'spg': ['stl', 'steals'], 'bpg': ['blk', 'blocks'],
    'tpg': ['tov', 'turnovers'], 'pf': ['pf', 'personal_fouls'],
    'oreb': ['oreb', 'offensive_rebounds'],
    'dreb': ['dreb', 'defensive_rebounds'],
    'fgm': ['fgm', 'field_goals_made'],
    'fga': ['fga', 'field_goal_attempts'],
    'three_pm': ['three_pm', 'three_pointers_made', 'fg3m'],
    'three_pa': ['three_pa', 'three_point_attempts', 'fg3a'],
    'ftm': ['ftm', 'free_throws_made'],
    'fta': ['fta', 'free_throw_attempts'],
  };
  if (metric.key == 'gp') return _numberAny(row, const ['games', 'gp']);
  final totalKeys = counting[metric.key];
  if (totalKeys != null) {
    final games = _numberAny(row, const ['games', 'gp']);
    final amount = _numberAny(row, totalKeys);
    if (games == null || games <= 0 || amount == null) return null;
    return amount / games;
  }
  return _numberAny(row, [
    ...metric.rawAliases,
    metric.key,
    if (metric.engineKey case final String engineKey) engineKey,
  ]);
}

String _formatSeasonMetric(NbaTerminalMetric metric, double? value) {
  if (value == null || !value.isFinite) return '—';
  switch (metric.format) {
    case NbaTerminalMetricFormat.integer:
      return value.round().toString();
    case NbaTerminalMetricFormat.percent:
      return _pct(value);
    case NbaTerminalMetricFormat.signed:
      return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(metric.decimals)}';
    case NbaTerminalMetricFormat.feetInches:
      return nbaFormatFeetInches(value);
    case NbaTerminalMetricFormat.inches:
      return '${value.toStringAsFixed(1)} in';
    case NbaTerminalMetricFormat.pounds:
      return '${value.toStringAsFixed(0)} lb';
    case NbaTerminalMetricFormat.seconds:
      return '${value.toStringAsFixed(metric.decimals)}s';
    case NbaTerminalMetricFormat.decimal:
      return value.toStringAsFixed(metric.decimals);
  }
}

String _playerTableMetricLabel(NbaTerminalMetric metric) {
  final label = metric.shortLabel;
  if (label == label.toUpperCase() &&
      label.replaceAll(RegExp(r'[^A-Z]'), '').length > 5 &&
      !label.contains('%')) {
    return metric.label;
  }
  return label;
}

class _TeamSeasonTable extends StatelessWidget {
  const _TeamSeasonTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final ordered = [...rows]
      ..sort(
        (a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])),
      );
    if (ordered.isEmpty) {
      return const _EmptyCard('No source-backed season rows are available.');
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Season')),
            DataColumn(numeric: true, label: Text('W')),
            DataColumn(numeric: true, label: Text('L')),
            DataColumn(numeric: true, label: Text('Win%')),
            DataColumn(numeric: true, label: Text('ORtg')),
            DataColumn(numeric: true, label: Text('DRtg')),
            DataColumn(numeric: true, label: Text('Net')),
            DataColumn(numeric: true, label: Text('Pace')),
            DataColumn(numeric: true, label: Text('SRS')),
          ],
          rows: [
            for (final row in ordered)
              DataRow(
                cells: [
                  DataCell(Text(_text(row['season_id']))),
                  DataCell(Text(_whole(row['wins']))),
                  DataCell(Text(_whole(row['losses']))),
                  DataCell(Text(_pct(row['win_pct']))),
                  DataCell(Text(_decimalAny(row, const ['ortg']))),
                  DataCell(Text(_decimalAny(row, const ['drtg']))),
                  DataCell(Text(_signedAny(row, const ['net_rtg']))),
                  DataCell(Text(_decimalAny(row, const ['pace']))),
                  DataCell(Text(_signedAny(row, const ['srs']))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ContractSection extends StatelessWidget {
  const _ContractSection({
    required this.current,
    required this.asOf,
  });
  final NbaTradeContract? current;
  final String asOf;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final contract = current;
    if (contract == null) {
      return const _EmptyCard(
        '2026–27 contract information is not present in Arcside’s '
        'published salary reference for this player. '
        'No earlier contract is presented as current.',
      );
    }
    final salary = contract.salaryFor('2026-27');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colors.outlineVariant),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 28,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ContractDatum('Season', '2026–27'),
              _ContractDatum('Team', contract.team),
              _ContractDatum('2026–27 salary', _money(salary)),
              if (contract.guaranteed != null)
                _ContractDatum('Recorded guarantee',
                    _money(contract.guaranteed)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Arcside salary reference · as of $asOf · ${contract.sourceLabel}. '
            'This is a dated salary snapshot, not a live contract verification.',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ContractDatum extends StatelessWidget {
  const _ContractDatum(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 5),
      Text(value, style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800)),
    ],
  );
}

class _AwardsSection extends StatelessWidget {
  const _AwardsSection({
    required this.awards,
    required this.allStar,
    required this.draft,
  });
  final List<Map<String, dynamic>> awards;
  final List<Map<String, dynamic>> allStar;
  final List<Map<String, dynamic>> draft;

  @override
  Widget build(BuildContext context) {
    final groups = nbaGroupPlayerHonors(awards, allStar);
    if (groups.isEmpty && draft.isEmpty) {
      return const _EmptyCard(
        'No verified individual honors or draft information is present '
        'in the published Arcside historical data.',
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (draft.isNotEmpty) ...[
          Text(
            'Draft · ${_text(draft.first['draft_year'])} · '
            'Round ${_text(draft.first['round_text'])} · '
            'Pick ${_text(draft.first['pick_number'])} · '
            '${_text(draft.first['drafting_team_text'])}',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(builder: (context, constraints) {
          const gap = 20.0;
          final columns = constraints.maxWidth >= 1000 ? 4
              : constraints.maxWidth >= 620 ? 2 : 1;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: 24,
            children: [
              for (final group in groups)
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.title,
                        style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w900)),
                      const SizedBox(height: 7),
                      Text(group.summary,
                        style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 12,
                          height: 1.45)),
                    ],
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _TeamGames extends StatelessWidget {
  const _TeamGames({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const _EmptyCard(
          'No source-backed recent game rows are available for this team.',
        )
      : Card(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                ListTile(
                  title: Text(
                    '${_text(rows[i]['away_team_name'])} at ${_text(rows[i]['home_team_name'])}',
                  ),
                  subtitle: Text(_text(rows[i]['game_date'])),
                  trailing: Text(
                    '${_whole(rows[i]['away_score'])} – ${_whole(rows[i]['home_score'])}',
                  ),
                ),
                if (i != rows.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.items});
  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 800
              ? (constraints.maxWidth - 36) / 4
              : constraints.maxWidth >= 480
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.value,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          trailing,
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.w900),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(message),
          ),
        ),
      );
}

class _EntityError extends StatelessWidget {
  const _EntityError({
    required this.title,
    required this.error,
    required this.onRetry,
  });
  final String title;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This static NBA page could not be loaded from the local historical release. ${error ?? ''}',
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PlayerPageData {
  const _PlayerPageData({
    required this.dossier, required this.currentContracts,
  });
  final Map<String, dynamic> dossier;
  final NbaTradeContractSnapshot currentContracts;
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value);
  final String label;
  final String value;
}

final List<NbaTerminalStatFamily> _advancedCategories = [
  for (final family in nbaTerminalStatFamilies)
    if (family.id != 'basic') family,
];

DataCell _heatDataCell(
  Map<String, dynamic> row,
  List<String> keys,
  NbaPercentageHeatMetric metric,
) {
  final value = _numberAny(row, keys);
  return DataCell(
    NbaPercentageHeatCell(
      metric: metric,
      value: value,
      child: Text(_pct(value)),
    ),
  );
}

int _uniqueAllStarYears(List<Map<String, dynamic>> rows) => rows
    .map(_honorYear)
    .whereType<int>()
    .toSet()
    .length;

int _uniqueSeasons(List<Map<String, dynamic>> rows) => rows
    .map((row) => _text(row['season_id']))
    .where((value) => value.isNotEmpty)
    .toSet()
    .length;

int? _honorYear(Map<String, dynamic> row) {
  final direct = _int(row['year']);
  if (direct != null && direct >= 1947 && direct <= 2100) return direct;
  final match = RegExp(r'^(\d{4})').firstMatch(_text(row['season_id']));
  final start = match == null ? null : int.tryParse(match.group(1)!);
  return start == null ? null : start + 1;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _map(item),
  ];
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

String _textAny(
  Map<String, dynamic> row,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = _text(row[key]);
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

double? _numberAny(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = _number(row[key]);
    if (value != null) return value;
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

String _whole(Object? value) => _number(value)?.round().toString() ?? '—';
String _wholeAny(Map<String, dynamic> row, List<String> keys) =>
    _numberAny(row, keys)?.round().toString() ?? '—';
String _decimalAny(Map<String, dynamic> row, List<String> keys) =>
    _numberAny(row, keys)?.toStringAsFixed(1) ?? '—';
String _signedAny(Map<String, dynamic> row, List<String> keys) {
  final value = _numberAny(row, keys);
  return value == null
      ? '—'
      : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
}
String _pct(Object? value) {
  final number = _number(value);
  if (number == null) return '—';
  return '${(number.abs() <= 1.5 ? number * 100 : number).toStringAsFixed(1)}%';
}
String _pctAny(Map<String, dynamic> row, List<String> keys) =>
    _pct(_numberAny(row, keys));
String _perGameAny(Map<String, dynamic> row, List<String> keys) {
  final games = _number(row['games']);
  final total = _numberAny(row, keys);
  if (games == null || games <= 0 || total == null) return '—';
  return (total / games).toStringAsFixed(1);
}
String _money(Object? value) {
  final number = _number(value);
  if (number == null) return '—';
  return '\$${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
}
