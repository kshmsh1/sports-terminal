import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/front_office_registry_service.dart';
import '../services/website_nba_api_service.dart';

Future<void> openWebsiteNbaPlayerPage(
  BuildContext context, {
  required AppSession session,
  required String playerKey,
  required String playerName,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(name: '/nba/players/${Uri.encodeComponent(playerKey)}'),
      builder: (_) => WebsiteNbaPlayerPage(
        session: session,
        playerKey: playerKey,
        playerName: playerName,
      ),
    ),
  );
}

Future<void> openWebsiteNbaTeamPage(
  BuildContext context, {
  required AppSession session,
  required String teamKey,
  required String teamName,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(name: '/nba/teams/${Uri.encodeComponent(teamKey)}'),
      builder: (_) => WebsiteNbaTeamPage(
        session: session,
        teamKey: teamKey,
        teamName: teamName,
      ),
    ),
  );
}

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
  String _advancedCategory = 'Overview';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlayerPageData> _load() async {
    final dossier = await _api.playerDossier(widget.playerKey);
    FrontOfficeRegistrySnapshot? registry;
    try {
      registry = await _frontOffice.load(session: widget.session, season: '2025-26');
    } catch (_) {
      registry = null;
    }
    return _PlayerPageData(dossier: dossier, registry: registry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sports Terminal')),
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
          final positions = _text(profile['positions'], _text(profile['primary_position']));
          final awards = _maps(dossier['awards']);
          final allStar = _maps(dossier['all_star']);
          final games = _maps(dossier['recent_games']);
          final draft = _maps(dossier['draft']);
          final contracts = _playerContracts(data.registry, widget.playerKey, name);

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
                    if (positions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        positions,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _SummaryCards(items: [
                      _SummaryItem('NBA seasons', '${_uniqueSeasons(regular)}'),
                      _SummaryItem('Playoff seasons', '${_uniqueSeasons(playoffs)}'),
                      _SummaryItem('All-Star', '${_uniqueAllStarYears(allStar)}'),
                      _SummaryItem('Recent games', '${games.length}'),
                    ]),
                    const SizedBox(height: 30),
                    _SectionHeader(
                      title: 'Career statistics',
                      trailing: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'regular', label: Text('Regular Season')),
                          ButtonSegment(value: 'playoffs', label: Text('Playoffs')),
                        ],
                        selected: {_segment},
                        onSelectionChanged: (value) => setState(() => _segment = value.first),
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
                                onSelected: (_) => setState(() => _advancedCategory = category.name),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PlayerAdvancedTable(
                      rows: selectedRows,
                      category: _advancedCategories.firstWhere((item) => item.name == _advancedCategory),
                    ),
                    const SizedBox(height: 30),
                    const _SectionTitle('Contract'),
                    const SizedBox(height: 10),
                    _ContractSection(contracts: contracts),
                    const SizedBox(height: 30),
                    const _SectionTitle('Awards & honors'),
                    const SizedBox(height: 10),
                    _AwardsSection(awards: awards, allStar: allStar, draft: draft),
                    const SizedBox(height: 30),
                    const _SectionTitle('Recent games'),
                    const SizedBox(height: 10),
                    _RecentGames(rows: games),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sports Terminal')),
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
              onRetry: () => setState(() => _future = _api.teamDossier(widget.teamKey)),
            );
          }
          final dossier = snapshot.data!;
          final profile = _map(dossier['profile']);
          final franchise = _map(dossier['franchise']);
          final allSeasons = _maps(dossier['seasons']);
          final seasons = allSeasons.where((row) => _text(row['season_type'], 'regular') == _segment).toList();
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
                    Text(name, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
                    const SizedBox(height: 6),
                    Text(
                      [abbreviation, _text(franchise['canonical_name'])].where((value) => value.isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 22),
                    _SummaryCards(items: [
                      _SummaryItem('NBA seasons', '${_uniqueSeasons(allSeasons)}'),
                      _SummaryItem('Recent games', '${games.length}'),
                      _SummaryItem('Players', '${players.length}'),
                      _SummaryItem('Franchise', _text(franchise['canonical_name'], '—')),
                    ]),
                    const SizedBox(height: 30),
                    _SectionHeader(
                      title: 'Season history',
                      trailing: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'regular', label: Text('Regular Season')),
                          ButtonSegment(value: 'playoffs', label: Text('Playoffs')),
                        ],
                        selected: {_segment},
                        onSelectionChanged: (value) => setState(() => _segment = value.first),
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
                            const Padding(padding: EdgeInsets.all(20), child: Align(alignment: Alignment.centerLeft, child: Text('No source-backed player history is available for this team.'))),
                          for (var i = 0; i < players.length; i++) ...[
                            ListTile(
                              title: Text(_text(players[i]['player_name'], 'Player')),
                              subtitle: Text('${_text(players[i]['first_season'])} – ${_text(players[i]['last_season'])}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                final key = _text(players[i]['player_key']);
                                if (key.isEmpty) return;
                                openWebsiteNbaPlayerPage(context, session: widget.session, playerKey: key, playerName: _text(players[i]['player_name'], 'Player'));
                              },
                            ),
                            if (i != players.length - 1) const Divider(height: 1),
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
}

class _PlayerCareerTable extends StatelessWidget {
  const _PlayerCareerTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final ordered = [...rows]..sort((a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])));
    if (ordered.isEmpty) return const _EmptyCard('No source-backed statistics are available for this segment.');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Season')), DataColumn(label: Text('Team')), DataColumn(label: Text('Pos')),
            DataColumn(numeric: true, label: Text('GP')), DataColumn(numeric: true, label: Text('MPG')),
            DataColumn(numeric: true, label: Text('PPG')), DataColumn(numeric: true, label: Text('RPG')),
            DataColumn(numeric: true, label: Text('APG')), DataColumn(numeric: true, label: Text('SPG')),
            DataColumn(numeric: true, label: Text('BPG')), DataColumn(numeric: true, label: Text('TOV')),
            DataColumn(numeric: true, label: Text('PF')), DataColumn(numeric: true, label: Text('FG%')),
            DataColumn(numeric: true, label: Text('3P%')), DataColumn(numeric: true, label: Text('FT%')),
            DataColumn(numeric: true, label: Text('TS%')), DataColumn(numeric: true, label: Text('PER')),
            DataColumn(numeric: true, label: Text('BPM')), DataColumn(numeric: true, label: Text('VORP')),
          ],
          rows: [
            for (final row in ordered)
              DataRow(cells: [
                DataCell(Text(_text(row['season_id']))), DataCell(Text(_text(row['team_abbreviation'], '—'))),
                DataCell(Text(_text(row['positions'], _textAny(row, const ['position', 'pos'], fallback: '—')))),
                DataCell(Text(_whole(row['games']))), DataCell(Text(_perGameAny(row, const ['minutes', 'min']))),
                DataCell(Text(_perGameAny(row, const ['pts', 'points']))), DataCell(Text(_perGameAny(row, const ['reb', 'rebounds']))),
                DataCell(Text(_perGameAny(row, const ['ast', 'assists']))), DataCell(Text(_perGameAny(row, const ['stl', 'steals']))),
                DataCell(Text(_perGameAny(row, const ['blk', 'blocks']))), DataCell(Text(_perGameAny(row, const ['tov', 'turnovers']))),
                DataCell(Text(_perGameAny(row, const ['pf', 'personal_fouls']))), DataCell(Text(_pctAny(row, const ['fg_pct']))),
                DataCell(Text(_pctAny(row, const ['three_pct', 'fg3_pct']))), DataCell(Text(_pctAny(row, const ['ft_pct']))),
                DataCell(Text(_pctAny(row, const ['ts_pct']))), DataCell(Text(_decimalAny(row, const ['per']))),
                DataCell(Text(_signedAny(row, const ['bpm']))), DataCell(Text(_decimalAny(row, const ['vorp']))),
              ]),
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
    final ordered = [...rows]..sort((a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])));
    final available = category.metrics.where((metric) => ordered.any((row) => _numberAny(row, metric.keys) != null)).toList();
    if (ordered.isEmpty || available.isEmpty) {
      return _EmptyCard('${category.name} metrics are not source-backed for this player/segment in the active historical release.');
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Season')), const DataColumn(label: Text('Team')), const DataColumn(label: Text('Pos')),
            for (final metric in available) DataColumn(numeric: true, label: Text(metric.label)),
          ],
          rows: [
            for (final row in ordered)
              DataRow(cells: [
                DataCell(Text(_text(row['season_id']))), DataCell(Text(_text(row['team_abbreviation'], '—'))),
                DataCell(Text(_text(row['positions'], _textAny(row, const ['position', 'pos'], fallback: '—')))),
                for (final metric in available) DataCell(Text(_formatAdvanced(row, metric))),
              ]),
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
    final ordered = [...rows]..sort((a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])));
    if (ordered.isEmpty) return const _EmptyCard('No source-backed season rows are available.');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Season')), DataColumn(numeric: true, label: Text('W')),
            DataColumn(numeric: true, label: Text('L')), DataColumn(numeric: true, label: Text('Win%')),
            DataColumn(numeric: true, label: Text('ORtg')), DataColumn(numeric: true, label: Text('DRtg')),
            DataColumn(numeric: true, label: Text('Net')), DataColumn(numeric: true, label: Text('Pace')),
            DataColumn(numeric: true, label: Text('SRS')),
          ],
          rows: [
            for (final row in ordered)
              DataRow(cells: [
                DataCell(Text(_text(row['season_id']))), DataCell(Text(_whole(row['wins']))), DataCell(Text(_whole(row['losses']))),
                DataCell(Text(_pct(row['win_pct']))), DataCell(Text(_decimalAny(row, const ['ortg']))),
                DataCell(Text(_decimalAny(row, const ['drtg']))), DataCell(Text(_signedAny(row, const ['net_rtg']))),
                DataCell(Text(_decimalAny(row, const ['pace']))), DataCell(Text(_signedAny(row, const ['srs']))),
              ]),
          ],
        ),
      ),
    );
  }
}

class _ContractSection extends StatelessWidget {
  const _ContractSection({required this.contracts});
  final List<Map<String, dynamic>> contracts;

  @override
  Widget build(BuildContext context) {
    if (contracts.isEmpty) {
      return const _EmptyCard('No registered contract record is currently available for this player. Historical statistics remain independent of contract-data availability.');
    }
    return Column(
      children: [
        for (final item in contracts)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_text(item['team_id'])} · ${_text(item['season'])}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  for (final year in _maps(item['years']))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${_text(year['season'])} · ${_money(year['salary'])} · ${_money(year['guaranteed_amount'])} guaranteed'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AwardsSection extends StatelessWidget {
  const _AwardsSection({required this.awards, required this.allStar, required this.draft});
  final List<Map<String, dynamic>> awards;
  final List<Map<String, dynamic>> allStar;
  final List<Map<String, dynamic>> draft;

  @override
  Widget build(BuildContext context) {
    final honors = _buildHonors(awards, allStar);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (draft.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Draft: ${_text(draft.first['draft_year'])} · ${_text(draft.first['round_text'])} · pick ${_text(draft.first['pick_number'])} · ${_text(draft.first['drafting_team_text'])}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 650 ? 2 : 1;
            final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final group in _honorColumns)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final label in group)
                              if (honors.containsKey(label)) ...[
                                _HonorItem(label: label, value: honors[label]!),
                                const SizedBox(height: 14),
                              ],
                            if (!group.any(honors.containsKey))
                              Text('No source-backed honors in this group.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HonorItem extends StatelessWidget {
  const _HonorItem({required this.label, required this.value});
  final String label;
  final _HonorValue value;

  @override
  Widget build(BuildContext context) {
    final countOnly = const {'Player of the Week', 'Player of the Month', 'Defensive Player of the Month'}.contains(label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value.count > 1 ? '$label (${value.count}x)' : label, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (!countOnly && value.years.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(value.years.join(', '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _RecentGames extends StatelessWidget {
  const _RecentGames({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _EmptyCard('No source-backed recent game rows are available for this player.');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')), DataColumn(label: Text('Team')), DataColumn(label: Text('Opponent')),
            DataColumn(numeric: true, label: Text('MIN')), DataColumn(numeric: true, label: Text('PTS')),
            DataColumn(numeric: true, label: Text('REB')), DataColumn(numeric: true, label: Text('AST')),
            DataColumn(numeric: true, label: Text('STL')), DataColumn(numeric: true, label: Text('BLK')),
          ],
          rows: [
            for (final row in rows)
              DataRow(cells: [
                DataCell(Text(_text(row['game_date']))), DataCell(Text(_text(row['team_abbreviation'], _text(row['team_name'])))),
                DataCell(Text(_text(row['opponent_abbreviation'], _text(row['opponent_name'])))), DataCell(Text(_decimalAny(row, const ['minutes', 'min']))),
                DataCell(Text(_wholeAny(row, const ['pts', 'points']))), DataCell(Text(_wholeAny(row, const ['reb', 'rebounds']))),
                DataCell(Text(_wholeAny(row, const ['ast', 'assists']))), DataCell(Text(_wholeAny(row, const ['stl', 'steals']))),
                DataCell(Text(_wholeAny(row, const ['blk', 'blocks']))),
              ]),
          ],
        ),
      ),
    );
  }
}

class _TeamGames extends StatelessWidget {
  const _TeamGames({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const _EmptyCard('No source-backed recent game rows are available for this team.')
      : Card(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                ListTile(
                  title: Text('${_text(rows[i]['away_team_name'])} at ${_text(rows[i]['home_team_name'])}'),
                  subtitle: Text(_text(rows[i]['game_date'])),
                  trailing: Text('${_whole(rows[i]['away_score'])} – ${_whole(rows[i]['home_score'])}'),
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
          final width = constraints.maxWidth >= 800 ? (constraints.maxWidth - 36) / 4 : constraints.maxWidth >= 480 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
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
                          Text(item.label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          Text(item.value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
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
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          trailing,
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Align(alignment: Alignment.centerLeft, child: Text(message))));
}

class _EntityError extends StatelessWidget {
  const _EntityError({required this.title, required this.error, required this.onRetry});
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
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text('This static NBA page could not be loaded from the local historical release. ${error ?? ''}'),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PlayerPageData {
  const _PlayerPageData({required this.dossier, required this.registry});
  final Map<String, dynamic> dossier;
  final FrontOfficeRegistrySnapshot? registry;
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
  const _AdvancedMetric(this.label, this.keys, {this.percent = false, this.signed = false, this.perGame = false});
  final String label;
  final List<String> keys;
  final bool percent;
  final bool signed;
  final bool perGame;
}

const _advancedCategories = <_AdvancedCategory>[
  _AdvancedCategory('Overview', [
    _AdvancedMetric('PER', ['per']), _AdvancedMetric('TS%', ['ts_pct'], percent: true),
    _AdvancedMetric('USG%', ['usg_pct'], percent: true), _AdvancedMetric('WS', ['ws']),
    _AdvancedMetric('WS/48', ['ws48']), _AdvancedMetric('BPM', ['bpm'], signed: true), _AdvancedMetric('VORP', ['vorp']),
  ]),
  _AdvancedCategory('Shooting & Efficiency', [
    _AdvancedMetric('PPG', ['pts', 'points'], perGame: true), _AdvancedMetric('FG%', ['fg_pct'], percent: true),
    _AdvancedMetric('2P%', ['two_pct', 'fg2_pct'], percent: true), _AdvancedMetric('3P%', ['three_pct', 'fg3_pct'], percent: true),
    _AdvancedMetric('FT%', ['ft_pct'], percent: true), _AdvancedMetric('eFG%', ['efg_pct'], percent: true), _AdvancedMetric('TS%', ['ts_pct'], percent: true),
  ]),
  _AdvancedCategory('Playmaking & Creation', [
    _AdvancedMetric('APG', ['ast', 'assists'], perGame: true), _AdvancedMetric('TOV', ['tov', 'turnovers'], perGame: true),
    _AdvancedMetric('AST/TOV', ['ast_tov']), _AdvancedMetric('USG%', ['usg_pct'], percent: true), _AdvancedMetric('ORtg', ['ortg']),
  ]),
  _AdvancedCategory('Defense', [
    _AdvancedMetric('SPG', ['stl', 'steals'], perGame: true), _AdvancedMetric('BPG', ['blk', 'blocks'], perGame: true),
    _AdvancedMetric('DREB', ['dreb'], perGame: true), _AdvancedMetric('DBPM', ['dbpm'], signed: true), _AdvancedMetric('DRtg', ['drtg']),
  ]),
  _AdvancedCategory('Rebounding', [
    _AdvancedMetric('OREB', ['oreb'], perGame: true), _AdvancedMetric('DREB', ['dreb'], perGame: true),
    _AdvancedMetric('RPG', ['reb', 'rebounds'], perGame: true), _AdvancedMetric('ORB%', ['orb_pct'], percent: true),
    _AdvancedMetric('DRB%', ['drb_pct'], percent: true), _AdvancedMetric('TRB%', ['trb_pct'], percent: true),
  ]),
  _AdvancedCategory('Impact', [
    _AdvancedMetric('PER', ['per']), _AdvancedMetric('WS', ['ws']), _AdvancedMetric('WS/48', ['ws48']),
    _AdvancedMetric('OBPM', ['obpm'], signed: true), _AdvancedMetric('DBPM', ['dbpm'], signed: true),
    _AdvancedMetric('BPM', ['bpm'], signed: true), _AdvancedMetric('VORP', ['vorp']),
  ]),
];

const _honorColumns = <List<String>>[
  ['Champion', 'Finals MVP', 'Conference Finals MVP', 'First-Team All-NBA', 'Second-Team All-NBA', 'Third-Team All-NBA', 'All-Star'],
  ['MVP', 'DPOY', 'First-Team All-Defense', 'Second-Team All-Defense', 'Rookie of the Year', 'First-Team All-Rookie', 'Second-Team All-Rookie'],
  ['Sixth Man of the Year', 'Most Improved Player', 'Clutch Player of the Year', 'Player of the Week', 'Player of the Month', 'Defensive Player of the Month'],
  ['NBA Cup Champion', 'NBA Cup MVP', 'Scoring Leader', 'Rebounding Leader', 'Assists Leader', 'Steals Leader', 'Blocks Leader', '3PM Leader'],
];

class _HonorValue {
  _HonorValue(this.years);
  final List<int> years;
  int get count => years.length;
}

Map<String, _HonorValue> _buildHonors(List<Map<String, dynamic>> awards, List<Map<String, dynamic>> allStar) {
  final grouped = <String, Set<int>>{};
  void add(String label, int? year) {
    if (year == null) return;
    grouped.putIfAbsent(label, () => <int>{}).add(year);
  }
  for (final row in allStar) {
    add('All-Star', _honorYear(row));
  }
  for (final row in awards) {
    if (!_earnedAward(row)) continue;
    final label = _honorLabel(row);
    if (label != null) add(label, _honorYear(row));
  }
  return {
    for (final entry in grouped.entries)
      entry.key: _HonorValue(entry.value.toList()..sort()),
  };
}

bool _earnedAward(Map<String, dynamic> row) {
  if (row['winner'] == true || row['selected'] == true) return true;
  final status = '${row['result'] ?? ''} ${row['status'] ?? ''} ${row['selection'] ?? ''}'.toLowerCase();
  if (status.contains('winner') || status.contains('selected')) return true;
  final award = _text(row['award']).toLowerCase();
  final tier = '${row['team'] ?? ''} ${row['team_level'] ?? ''} ${row['selection_team'] ?? ''}'.toLowerCase();
  return (award.contains('all-nba') || award.contains('all_nba') || award.contains('all-defense') || award.contains('all_defense') || award.contains('all-rookie') || award.contains('all_rookie')) && tier.isNotEmpty;
}

String? _honorLabel(Map<String, dynamic> row) {
  final raw = '${row['award'] ?? ''} ${row['award_name'] ?? ''}'.toLowerCase().replaceAll('_', ' ');
  final tier = '${row['team'] ?? ''} ${row['team_level'] ?? ''} ${row['selection_team'] ?? ''} $raw'.toLowerCase();
  bool has(String value) => raw.contains(value);
  String? teamLabel(String family) {
    if (tier.contains('first') || RegExp(r'(^|\D)1(st)?(\D|$)').hasMatch(tier)) return 'First-Team $family';
    if (tier.contains('second') || RegExp(r'(^|\D)2(nd)?(\D|$)').hasMatch(tier)) return 'Second-Team $family';
    if (tier.contains('third') || RegExp(r'(^|\D)3(rd)?(\D|$)').hasMatch(tier)) return 'Third-Team $family';
    return null;
  }
  if (has('cup') && has('mvp')) return 'NBA Cup MVP';
  if (has('cup') && has('champ')) return 'NBA Cup Champion';
  if (has('conference') && has('final') && has('mvp')) return 'Conference Finals MVP';
  if (has('final') && has('mvp')) return 'Finals MVP';
  if (has('champion')) return 'Champion';
  if (has('all nba') || has('all-nba')) return teamLabel('All-NBA');
  if (has('all defense') || has('all-defense')) return teamLabel('All-Defense');
  if (has('all rookie') || has('all-rookie')) return teamLabel('All-Rookie');
  if (has('defensive player') && has('month')) return 'Defensive Player of the Month';
  if (has('player of the month')) return 'Player of the Month';
  if (has('player of the week')) return 'Player of the Week';
  if (has('sixth') && has('man')) return 'Sixth Man of the Year';
  if (has('most improved') || has('mip')) return 'Most Improved Player';
  if (has('clutch')) return 'Clutch Player of the Year';
  if (has('rookie') && has('year')) return 'Rookie of the Year';
  if (has('defensive player') || has('dpoy')) return 'DPOY';
  if (has('mvp')) return 'MVP';
  if (has('scoring') && has('leader')) return 'Scoring Leader';
  if (has('rebound') && has('leader')) return 'Rebounding Leader';
  if (has('assist') && has('leader')) return 'Assists Leader';
  if (has('steal') && has('leader')) return 'Steals Leader';
  if (has('block') && has('leader')) return 'Blocks Leader';
  if ((has('3pm') || has('three')) && has('leader')) return '3PM Leader';
  return null;
}

int? _honorYear(Map<String, dynamic> row) {
  final direct = _int(row['year']);
  if (direct != null && direct >= 1947 && direct <= 2026) return direct;
  final season = _text(row['season_id']);
  final match = RegExp(r'^(\d{4})').firstMatch(season);
  final start = match == null ? null : int.tryParse(match.group(1)!);
  return start == null ? null : start + 1;
}

int _uniqueAllStarYears(List<Map<String, dynamic>> rows) => rows.map(_honorYear).whereType<int>().toSet().length;
int _uniqueSeasons(List<Map<String, dynamic>> rows) => rows.map((row) => _text(row['season_id'])).where((value) => value.isNotEmpty).toSet().length;

List<Map<String, dynamic>> _playerContracts(FrontOfficeRegistrySnapshot? registry, String playerKey, String playerName) {
  if (registry == null) return const [];
  final result = <Map<String, dynamic>>[];
  for (final wrapper in registry.contracts) {
    final record = _map(wrapper['record']);
    final idMatch = _text(record['player_id']) == playerKey;
    final nameMatch = _text(record['player_name']).toLowerCase() == playerName.toLowerCase();
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
  return [for (final item in value) if (item is Map) _map(item)];
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

String _textAny(Map<String, dynamic> row, List<String> keys, {String fallback = ''}) {
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
String _wholeAny(Map<String, dynamic> row, List<String> keys) => _numberAny(row, keys)?.round().toString() ?? '—';
String _decimal(Object? value) => _number(value)?.toStringAsFixed(1) ?? '—';
String _decimalAny(Map<String, dynamic> row, List<String> keys) => _numberAny(row, keys)?.toStringAsFixed(1) ?? '—';
String _signedAny(Map<String, dynamic> row, List<String> keys) {
  final value = _numberAny(row, keys);
  return value == null ? '—' : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
}
String _pct(Object? value) {
  final number = _number(value);
  if (number == null) return '—';
  return '${((number.abs() <= 1.5 ? number * 100 : number)).toStringAsFixed(1)}%';
}
String _pctAny(Map<String, dynamic> row, List<String> keys) {
  final value = _numberAny(row, keys);
  return _pct(value);
}
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
  if (metric.signed) return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  return value.toStringAsFixed(1);
}
