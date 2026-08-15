import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaHomeDashboard extends StatefulWidget {
  const WebsiteNbaHomeDashboard({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaHomeDashboard> createState() => _WebsiteNbaHomeDashboardState();
}

class _WebsiteNbaHomeDashboardState extends State<WebsiteNbaHomeDashboard> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();
  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<NbaTerminalSeedSnapshot>? _snapshotFuture;
  List<WebsiteNbaSeason> _seasons = const [];
  String _season = '2025-26';

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
      _snapshotFuture = _api.seasonSnapshot(_season, seasonType: 'regular');
    }
    return seasons;
  }

  void _selectSeason(String season) {
    if (season == _season) return;
    setState(() {
      _season = season;
      _snapshotFuture = _api.seasonSnapshot(season, seasonType: 'regular');
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, seasonSnapshot) {
        if (seasonSnapshot.connectionState != ConnectionState.done) {
          return const _DashboardLoading();
        }
        if (seasonSnapshot.hasError || _seasons.isEmpty || _snapshotFuture == null) {
          return _DashboardError(
            error: seasonSnapshot.error,
            onRetry: () => setState(() => _seasonsFuture = _loadSeasons()),
          );
        }
        return FutureBuilder<NbaTerminalSeedSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _DashboardLoading();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _DashboardError(
                error: snapshot.error,
                onRetry: () => setState(() {
                  _snapshotFuture = _api.seasonSnapshot(_season, seasonType: 'regular');
                }),
              );
            }
            return _buildDashboard(context, snapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, NbaTerminalSeedSnapshot data) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(
      data,
      basis: NbaStatsBasis.perGame,
      seasonType: NbaStatsSeasonType.regular,
    );
    final query = _search.text.trim().toLowerCase();
    final matchingPlayers = rows.where((row) {
      if (query.isEmpty) return false;
      return '${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query);
    }).take(8).toList();
    final points = [...rows]..sort((a, b) => (b.value('pts') ?? -1).compareTo(a.value('pts') ?? -1));
    final rebounds = [...rows]..sort((a, b) => (b.value('reb') ?? -1).compareTo(a.value('reb') ?? -1));
    final assists = [...rows]..sort((a, b) => (b.value('ast') ?? -1).compareTo(a.value('ast') ?? -1));
    final teams = _teamCards(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NBA Dashboard',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Players, teams and league leaders from the canonical NBA history warehouse.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _season,
                decoration: const InputDecoration(labelText: 'Season', isDense: true),
                items: [
                  for (final season in _seasons)
                    DropdownMenuItem(value: season.id, child: Text(season.id)),
                ],
                onChanged: (value) {
                  if (value != null) _selectSeason(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search any player in this season',
          ),
        ),
        if (query.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (matchingPlayers.isEmpty)
                  const ListTile(title: Text('No matching players')),
                for (var i = 0; i < matchingPlayers.length; i++) ...[
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                    title: Text(matchingPlayers[i].player),
                    subtitle: Text('${matchingPlayers[i].team} · ${matchingPlayers[i].position}'),
                    trailing: Text('${_engine.formatValue('pts', matchingPlayers[i].value('pts'))} PPG'),
                    onTap: () => openWebsiteNbaPlayerPage(
                      context,
                      session: widget.session,
                      playerKey: matchingPlayers[i].playerId,
                      playerName: matchingPlayers[i].player,
                    ),
                  ),
                  if (i != matchingPlayers.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          'League leaders',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 900
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(width: width, child: _LeaderCard(title: 'Points', metric: 'pts', suffix: 'PPG', rows: points.take(5).toList(), session: widget.session)),
                SizedBox(width: width, child: _LeaderCard(title: 'Rebounds', metric: 'reb', suffix: 'RPG', rows: rebounds.take(5).toList(), session: widget.session)),
                SizedBox(width: width, child: _LeaderCard(title: 'Assists', metric: 'ast', suffix: 'APG', rows: assists.take(5).toList(), session: widget.session)),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        Text(
          'Teams',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 650
                    ? 3
                    : constraints.maxWidth >= 440
                        ? 2
                        : 1;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final team in teams)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => openWebsiteNbaTeamPage(
                          context,
                          session: widget.session,
                          teamKey: team.key,
                          teamName: team.name,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(child: Text(team.abbreviation.isEmpty ? '?' : team.abbreviation.substring(0, 1))),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(team.abbreviation, style: const TextStyle(fontWeight: FontWeight.w900))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(team.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text(team.record, style: TextStyle(color: colors.onSurfaceVariant)),
                            ],
                          ),
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

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({
    required this.title,
    required this.metric,
    required this.suffix,
    required this.rows,
    required this.session,
  });

  final String title;
  final String metric;
  final String suffix;
  final List<NbaStatsRow> rows;
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final engine = const NbaStatsWorkstationEngine();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++)
              InkWell(
                onTap: () => openWebsiteNbaPlayerPage(
                  context,
                  session: session,
                  playerKey: rows[i].playerId,
                  playerName: rows[i].player,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(width: 24, child: Text('${i + 1}')),
                      Expanded(child: Text(rows[i].player, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${engine.formatValue(metric, rows[i].value(metric))} $suffix'),
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

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NBA warehouse unavailable', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('The website is now looking for the canonical historical NBA warehouse through the local API rather than a generated Flutter seed. ${error ?? ''}'),
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _TeamCardData {
  const _TeamCardData({required this.key, required this.name, required this.abbreviation, required this.record});
  final String key;
  final String name;
  final String abbreviation;
  final String record;
}

List<_TeamCardData> _teamCards(NbaTerminalSeedSnapshot data) {
  final records = <String, Map<String, dynamic>>{};
  for (final row in data.teamRecords) {
    final key = (row['team_id'] ?? '').toString();
    if (key.isNotEmpty) records[key] = row;
  }
  final result = <_TeamCardData>[];
  for (final row in data.teams) {
    final key = (row['team_id'] ?? row['id'] ?? '').toString();
    if (key.isEmpty) continue;
    final record = records[key];
    final wins = _int(record?['wins']);
    final losses = _int(record?['losses']);
    result.add(_TeamCardData(
      key: key,
      name: (row['team_name'] ?? row['name'] ?? row['display_name'] ?? key).toString(),
      abbreviation: (row['team_abbreviation'] ?? row['abbreviation'] ?? '').toString(),
      record: wins == null || losses == null ? 'Season team page' : '$wins–$losses',
    ));
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}
