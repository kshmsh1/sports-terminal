import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_player_profile_presentation.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stat_display_format.dart';
import '../services/front_office_registry_service.dart';
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
  final _frontOffice = const FrontOfficeRegistryService();
  late Future<_PlayerPageData> _future;
  String _segment = 'regular';
  String _advancedCategory = 'Shooting & Efficiency';
  final Set<String> _expandedAdvancedMetrics = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlayerPageData> _load() async {
    final dossier = await _api.playerDossier(widget.playerKey);
    FrontOfficeRegistrySnapshot? registry;
    try {
      registry = await _frontOffice.load(
        session: widget.session,
        season: '2025-26',
      );
    } catch (_) {
      registry = null;
    }
    final current = await const NbaTradeContractRepository().load();
    return _PlayerPageData(
      dossier: dossier, registry: registry, currentContracts: current,
    );
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
            final contracts = _playerContracts(
              data.registry, widget.playerKey, name,
            );
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
                      _PlayerCareerTable(rows: selectedRows),
                      const SizedBox(height: 30),
                      const _SectionTitle('Advanced statistics'),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final category in _advancedCategories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(category.name),
                                  selected: _advancedCategory == category.name,
                                  onSelected: (_) => setState(
                                    () => _advancedCategory = category.name,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PlayerAdvancedTable(
                        rows: selectedRows,
                        category: _advancedCategories.firstWhere(
                          (item) => item.name == _advancedCategory,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const _SectionTitle('Contract'),
                      const SizedBox(height: 10),
                      _ContractSection(
                        contracts: contracts,
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

class _PlayerCareerTable extends StatelessWidget {
  const _PlayerCareerTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final ordered = [...rows]
      ..sort(
        (a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])),
      );
    if (ordered.isEmpty) {
      return const _EmptyCard(
        'No source-backed statistics are available for this segment.',
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Season')),
            DataColumn(label: Text('Team')),
            DataColumn(label: Text('Pos')),
            DataColumn(numeric: true, label: Text('GP')),
            DataColumn(numeric: true, label: Text('MPG')),
            DataColumn(numeric: true, label: Text('PPG')),
            DataColumn(numeric: true, label: Text('RPG')),
            DataColumn(numeric: true, label: Text('APG')),
            DataColumn(numeric: true, label: Text('SPG')),
            DataColumn(numeric: true, label: Text('BPG')),
            DataColumn(numeric: true, label: Text('TPG')),
            DataColumn(numeric: true, label: Text('PF')),
            DataColumn(numeric: true, label: Text('FG%')),
            DataColumn(numeric: true, label: Text('3PM')),
            DataColumn(numeric: true, label: Text('3PA')),
            DataColumn(numeric: true, label: Text('3P%')),
            DataColumn(numeric: true, label: Text('FT%')),
            DataColumn(numeric: true, label: Text('TS%')),
            DataColumn(numeric: true, label: Text('PER')),
            DataColumn(numeric: true, label: Text('BPM')),
            DataColumn(numeric: true, label: Text('VORP')),
          ],
          rows: [
            for (final row in ordered)
              DataRow(
                cells: [
                  DataCell(Text(_text(row['season_id']))),
                  DataCell(Text(_text(row['team_abbreviation'], '—'))),
                  DataCell(
                    Text(
                      _text(
                        row['positions'],
                        _textAny(
                          row,
                          const ['position', 'pos'],
                          fallback: '—',
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(_whole(row['games']))),
                  DataCell(Text(_perGameAny(row, const ['minutes', 'min']))),
                  DataCell(Text(_perGameAny(row, const ['pts', 'points']))),
                  DataCell(Text(_perGameAny(row, const ['reb', 'rebounds']))),
                  DataCell(Text(_perGameAny(row, const ['ast', 'assists']))),
                  DataCell(Text(_perGameAny(row, const ['stl', 'steals']))),
                  DataCell(Text(_perGameAny(row, const ['blk', 'blocks']))),
                  DataCell(Text(_perGameAny(row, const ['tov', 'turnovers']))),
                  DataCell(Text(_perGameAny(row, const ['pf', 'personal_fouls']))),
                  _heatDataCell(
                    row,
                    const ['fg_pct', 'field_goal_percentage'],
                    NbaPercentageHeatMetric.fieldGoal,
                  ),
                  DataCell(
                    Text(
                      _perGameAny(
                        row,
                        const ['three_pm', 'three_pointers_made', 'fg3m'],
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      _perGameAny(
                        row,
                        const ['three_pa', 'three_point_attempts', 'fg3a'],
                      ),
                    ),
                  ),
                  _heatDataCell(
                    row,
                    const ['three_pct', 'fg3_pct', 'three_point_percentage'],
                    NbaPercentageHeatMetric.threePoint,
                  ),
                  _heatDataCell(
                    row,
                    const ['ft_pct', 'free_throw_percentage'],
                    NbaPercentageHeatMetric.freeThrow,
                  ),
                  DataCell(Text(_pctAny(row, const ['ts_pct']))),
                  DataCell(Text(_decimalAny(row, const ['per']))),
                  DataCell(Text(_signedAny(row, const ['bpm']))),
                  DataCell(Text(_decimalAny(row, const ['vorp']))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerAdvancedTable extends StatelessWidget {
  const _PlayerAdvancedTable({required this.rows, required this.category});
  final List<Map<String, dynamic>> rows;
  final _AdvancedCategory category;

  @override
  Widget build(BuildContext context) {
    final ordered = [...rows]
      ..sort(
        (a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])),
      );
    final available = category.metrics
        .where(
          (metric) => ordered.any(
            (row) => _numberAny(row, metric.keys) != null,
          ),
        )
        .toList();
    if (ordered.isEmpty || available.isEmpty) {
      return _EmptyCard(
        '${category.name} metrics are not source-backed for this player/segment in the active historical release.',
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Season')),
            const DataColumn(label: Text('Team')),
            const DataColumn(label: Text('Pos')),
            for (final metric in available)
              DataColumn(numeric: true, label: Text(metric.label)),
          ],
          rows: [
            for (final row in ordered)
              DataRow(
                cells: [
                  DataCell(Text(_text(row['season_id']))),
                  DataCell(Text(_text(row['team_abbreviation'], '—'))),
                  DataCell(
                    Text(
                      _text(
                        row['positions'],
                        _textAny(
                          row,
                          const ['position', 'pos'],
                          fallback: '—',
                        ),
                      ),
                    ),
                  ),
                  for (final metric in available)
                    _advancedDataCell(row, metric),
                ],
              ),
          ],
        ),
      ),
    );
  }
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
    required this.contracts,
    required this.current,
    required this.asOf,
  });
  final List<Map<String, dynamic>> contracts;
  final NbaTradeContract? current;
  final String asOf;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final contract = current;
    if (contract == null) {
      return _EmptyCard(
        '2026–27 contract information is not present in Arcside’s published '
        'salary reference for this player. ${contracts.isEmpty
            ? 'No earlier registered contract is available either.'
            : 'Earlier registry records are not shown as current contracts.'}',
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
    required this.dossier, required this.registry, required this.currentContracts,
  });
  final Map<String, dynamic> dossier;
  final FrontOfficeRegistrySnapshot? registry;
  final NbaTradeContractSnapshot currentContracts;
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value);
  final String label;
  final String value;
}

class _AdvancedCategory {
  const _AdvancedCategory(this.name, this.metrics);
  final String name;
  final List<_AdvancedMetric> metrics;
}

class _AdvancedMetric {
  const _AdvancedMetric(
    this.label,
    this.keys, {
    this.percent = false,
    this.signed = false,
    this.perGame = false,
    this.heatMetric,
  });
  final String label;
  final List<String> keys;
  final bool percent;
  final bool signed;
  final bool perGame;
  final NbaPercentageHeatMetric? heatMetric;
}

const _advancedCategories = <_AdvancedCategory>[
  _AdvancedCategory(
    'Shooting & Efficiency',
    [
      _AdvancedMetric('PPG', ['pts', 'points'], perGame: true),
      _AdvancedMetric(
        'FG%',
        ['fg_pct', 'field_goal_percentage'],
        percent: true,
        heatMetric: NbaPercentageHeatMetric.fieldGoal,
      ),
      _AdvancedMetric(
        '3PM',
        ['three_pm', 'three_pointers_made', 'fg3m'],
        perGame: true,
      ),
      _AdvancedMetric(
        '3PA',
        ['three_pa', 'three_point_attempts', 'fg3a'],
        perGame: true,
      ),
      _AdvancedMetric(
        '3P%',
        ['three_pct', 'fg3_pct', 'three_point_percentage'],
        percent: true,
        heatMetric: NbaPercentageHeatMetric.threePoint,
      ),
      _AdvancedMetric(
        'FT%',
        ['ft_pct', 'free_throw_percentage'],
        percent: true,
        heatMetric: NbaPercentageHeatMetric.freeThrow,
      ),
      _AdvancedMetric('eFG%', ['efg_pct'], percent: true),
      _AdvancedMetric('TS%', ['ts_pct'], percent: true),
      _AdvancedMetric('PER', ['per']),
      _AdvancedMetric('USG%', ['usg_pct'], percent: true),
    ],
  ),
  _AdvancedCategory(
    'Defense',
    [
      _AdvancedMetric('SPG', ['stl', 'steals'], perGame: true),
      _AdvancedMetric('BPG', ['blk', 'blocks'], perGame: true),
      _AdvancedMetric(
        'DFG%',
        ['dfg_pct', 'd_fg_pct'],
        percent: true,
        heatMetric: NbaPercentageHeatMetric.defensiveFieldGoal,
      ),
      _AdvancedMetric(
        'Rim DFG%',
        ['rim_dfg_pct', 'lt6_dfg_pct'],
        percent: true,
        heatMetric: NbaPercentageHeatMetric.rimDefensiveFieldGoal,
      ),
      _AdvancedMetric(
        '3P DFG%',
        ['three_dfg_pct', 'three_point_dfg_pct'],
        percent: true,
        heatMetric: NbaPercentageHeatMetric.threePointDefensiveFieldGoal,
      ),
      _AdvancedMetric('DBPM', ['dbpm'], signed: true),
      _AdvancedMetric('DRtg', ['drtg']),
    ],
  ),
  _AdvancedCategory(
    'Impact',
    [
      _AdvancedMetric('PER', ['per']),
      _AdvancedMetric('WS', ['ws']),
      _AdvancedMetric('WS/48', ['ws48']),
      _AdvancedMetric('OBPM', ['obpm'], signed: true),
      _AdvancedMetric('DBPM', ['dbpm'], signed: true),
      _AdvancedMetric('BPM', ['bpm'], signed: true),
      _AdvancedMetric('VORP', ['vorp']),
    ],
  ),
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

DataCell _advancedDataCell(
  Map<String, dynamic> row,
  _AdvancedMetric metric,
) {
  final value = _numberAny(row, metric.keys);
  final text = _formatAdvanced(row, metric);
  if (metric.heatMetric == null) return DataCell(Text(text));
  return DataCell(
    NbaPercentageHeatCell(
      metric: metric.heatMetric!,
      value: value,
      child: Text(text),
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

List<Map<String, dynamic>> _playerContracts(
  FrontOfficeRegistrySnapshot? registry,
  String playerKey,
  String playerName,
) {
  if (registry == null) return const [];
  final result = <Map<String, dynamic>>[];
  for (final wrapper in registry.contracts) {
    final record = _map(wrapper['record']);
    final idMatch = _text(record['player_id']) == playerKey;
    final nameMatch = _text(record['player_name']).toLowerCase() ==
        playerName.toLowerCase();
    if (idMatch || nameMatch) result.add(record);
  }
  return result;
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
String _formatAdvanced(Map<String, dynamic> row, _AdvancedMetric metric) {
  if (metric.perGame) return _perGameAny(row, metric.keys);
  final value = _numberAny(row, metric.keys);
  if (value == null) return '—';
  if (metric.percent) return _pct(value);
  if (metric.signed) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  }
  return value.toStringAsFixed(1);
}
