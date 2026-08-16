import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/website_nba_api_service.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaHomeDashboard extends StatefulWidget {
  const WebsiteNbaHomeDashboard({super.key, required this.session});
  final AppSession session;

  @override
  State<WebsiteNbaHomeDashboard> createState() => _WebsiteNbaHomeDashboardState();
}

class _WebsiteNbaHomeDashboardState extends State<WebsiteNbaHomeDashboard> {
  final _data = const WebsiteNbaApiService();
  final _search = TextEditingController();
  late Future<List<WebsiteNbaSeason>> _seasonsFuture;
  Future<Map<String, dynamic>>? _dashboardFuture;
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
    final seasons = await _data.seasons();
    if (seasons.isNotEmpty) {
      _seasons = seasons;
      _season = seasons.firstWhere((item) => item.id == '2025-26', orElse: () => seasons.first).id;
      _dashboardFuture = _data.seasonDashboard(_season);
    }
    return seasons;
  }

  void _selectSeason(String season) {
    if (season == _season) return;
    setState(() {
      _season = season;
      _search.clear();
      _dashboardFuture = _data.seasonDashboard(season);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WebsiteNbaSeason>>(
      future: _seasonsFuture,
      builder: (context, seasonSnapshot) {
        if (seasonSnapshot.connectionState != ConnectionState.done) return const _DashboardLoading();
        if (seasonSnapshot.hasError || _seasons.isEmpty || _dashboardFuture == null) {
          return _DashboardError(error: seasonSnapshot.error, onRetry: () => setState(() => _seasonsFuture = _loadSeasons()));
        }
        return FutureBuilder<Map<String, dynamic>>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _DashboardLoading();
            if (snapshot.hasError || snapshot.data == null) {
              return _DashboardError(error: snapshot.error, onRetry: () => setState(() => _dashboardFuture = _data.seasonDashboard(_season)));
            }
            return _buildDashboard(context, snapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, Map<String, dynamic> data) {
    final colors = Theme.of(context).colorScheme;
    final players = _maps(data['players']);
    final teams = _teamCards(data);
    final leaders = _map(data['leaders']);
    final teamLeaders = _map(data['team_leaders']);
    final recentGames = _maps(data['recent_games']);
    final query = _search.text.trim().toLowerCase();
    final matchingPlayers = query.isEmpty
        ? const <Map<String, dynamic>>[]
        : players.where((row) => '${_text(row['player_name'])} ${_text(row['team'])} ${_text(row['position'])}'.toLowerCase().contains(query)).take(8).toList();

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
                  Text('NBA Dashboard', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
                  const SizedBox(height: 7),
                  Text('Players, teams, league leaders and recent results from the static NBA historical release.', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _season,
                decoration: const InputDecoration(labelText: 'Season', isDense: true),
                items: [for (final season in _seasons) DropdownMenuItem(value: season.id, child: Text(season.id))],
                onChanged: (value) { if (value != null) _selectSeason(value); },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search players in this season')),
        if (query.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (matchingPlayers.isEmpty) const ListTile(title: Text('No matching players')),
                for (var i = 0; i < matchingPlayers.length; i++) ...[
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                    title: Text(_text(matchingPlayers[i]['player_name'], 'Player')),
                    subtitle: Text([_text(matchingPlayers[i]['team']), _text(matchingPlayers[i]['position'])].where((value) => value.isNotEmpty).join(' · ')),
                    trailing: Text('${_decimal(matchingPlayers[i]['ppg'])} PPG'),
                    onTap: () => openWebsiteNbaPlayerPage(context, session: widget.session, playerKey: _text(matchingPlayers[i]['player_id']), playerName: _text(matchingPlayers[i]['player_name'], 'Player')),
                  ),
                  if (i != matchingPlayers.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 30),
        _SectionTitle('Player leaders · Top 10'),
        const SizedBox(height: 12),
        _LeaderGrid(
          specs: _leaderSpecs,
          source: leaders,
          builder: (spec, rows) => _PlayerLeaderCard(title: spec.label, suffix: spec.suffix, rows: rows, session: widget.session),
        ),
        const SizedBox(height: 34),
        _SectionTitle('Team leaders · Top 10'),
        const SizedBox(height: 12),
        _LeaderGrid(
          specs: _leaderSpecs,
          source: teamLeaders,
          builder: (spec, rows) => _TeamLeaderCard(title: spec.label, suffix: spec.suffix, rows: rows, session: widget.session),
        ),
        const SizedBox(height: 34),
        _SectionTitle('Teams'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 650 ? 3 : constraints.maxWidth >= 440 ? 2 : 1;
            final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final team in teams)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => openWebsiteNbaTeamPage(context, session: widget.session, teamKey: team.key, teamName: team.name),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(child: Text(team.abbreviation.isEmpty ? '?' : team.abbreviation.substring(0, 1))),
                                const SizedBox(width: 10),
                                Expanded(child: Text(team.abbreviation, style: const TextStyle(fontWeight: FontWeight.w900))),
                              ]),
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
        if (recentGames.isNotEmpty) ...[
          const SizedBox(height: 34),
          _SectionTitle('Recent results'),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < recentGames.length; i++) ...[
                  ListTile(
                    title: Text('${_text(recentGames[i]['away_team_name'], _text(recentGames[i]['away_team']))} at ${_text(recentGames[i]['home_team_name'], _text(recentGames[i]['home_team']))}'),
                    subtitle: Text(_text(recentGames[i]['game_date'])),
                    trailing: Text('${_whole(recentGames[i]['away_score'])} – ${_whole(recentGames[i]['home_score'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (i != recentGames.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LeaderGrid extends StatelessWidget {
  const _LeaderGrid({required this.specs, required this.source, required this.builder});
  final List<_LeaderSpec> specs;
  final Map<String, dynamic> source;
  final Widget Function(_LeaderSpec spec, List<Map<String, dynamic>> rows) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1080 ? 3 : constraints.maxWidth >= 720 ? 2 : 1;
          final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final spec in specs) SizedBox(width: width, child: builder(spec, _maps(source[spec.key])))],
          );
        },
      );
}

class _PlayerLeaderCard extends StatelessWidget {
  const _PlayerLeaderCard({required this.title, required this.suffix, required this.rows, required this.session});
  final String title;
  final String suffix;
  final List<Map<String, dynamic>> rows;
  final AppSession session;

  @override
  Widget build(BuildContext context) => _LeaderCardShell(
        title: title,
        children: [
          if (rows.isEmpty) const Text('No source-backed leaders available.'),
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: () => openWebsiteNbaPlayerPage(context, session: session, playerKey: _text(rows[i]['player_id']), playerName: _text(rows[i]['player_name'], 'Player')),
              child: _LeaderRow(rank: i + 1, name: _text(rows[i]['player_name'], 'Player'), value: '${_decimal(rows[i]['value'])} $suffix'),
            ),
        ],
      );
}

class _TeamLeaderCard extends StatelessWidget {
  const _TeamLeaderCard({required this.title, required this.suffix, required this.rows, required this.session});
  final String title;
  final String suffix;
  final List<Map<String, dynamic>> rows;
  final AppSession session;

  @override
  Widget build(BuildContext context) => _LeaderCardShell(
        title: title,
        children: [
          if (rows.isEmpty) const Text('No source-backed leaders available.'),
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: () => openWebsiteNbaTeamPage(
                context,
                session: session,
                teamKey: _text(rows[i]['team_key'], _text(rows[i]['team_id'])),
                teamName: _text(rows[i]['team_name'], _text(rows[i]['team'], 'Team')),
              ),
              child: _LeaderRow(
                rank: i + 1,
                name: _text(rows[i]['team_name'], _text(rows[i]['team'], 'Team')),
                value: '${_decimal(rows[i]['value'])} $suffix',
              ),
            ),
        ],
      );
}

class _LeaderCardShell extends StatelessWidget {
  const _LeaderCardShell({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.rank, required this.name, required this.value});
  final int rank;
  final String name;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 26, child: Text('$rank')),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Text(value),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900));
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Static NBA data is unavailable', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('The website could not read its precompiled historical NBA files. No runtime NBA API is required. ${error ?? ''}'),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ]),
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

class _LeaderSpec {
  const _LeaderSpec(this.key, this.label, this.suffix);
  final String key;
  final String label;
  final String suffix;
}

const _leaderSpecs = <_LeaderSpec>[
  _LeaderSpec('points', 'Points', 'PPG'),
  _LeaderSpec('rebounds', 'Rebounds', 'RPG'),
  _LeaderSpec('assists', 'Assists', 'APG'),
  _LeaderSpec('steals', 'Steals', 'SPG'),
  _LeaderSpec('blocks', 'Blocks', 'BPG'),
  _LeaderSpec('turnovers', 'Turnovers', 'TPG'),
  _LeaderSpec('personal_fouls', 'Personal Fouls', 'PF/G'),
  _LeaderSpec('field_goals_made', 'Field Goals Made', 'FGM/G'),
  _LeaderSpec('three_pointers_made', 'Three-Pointers Made', '3PM/G'),
  _LeaderSpec('free_throws_made', 'Free Throws Made', 'FTM/G'),
];

List<_TeamCardData> _teamCards(Map<String, dynamic> data) {
  final records = <String, Map<String, dynamic>>{};
  for (final row in _maps(data['team_records'])) {
    final key = _text(row['team_id'], _text(row['team_key']));
    if (key.isNotEmpty) records[key] = row;
  }
  final result = <_TeamCardData>[];
  for (final row in _maps(data['teams'])) {
    final key = _text(row['team_id'], _text(row['team_key'], _text(row['id'])));
    if (key.isEmpty) continue;
    final record = records[key];
    final wins = _int(record?['wins']);
    final losses = _int(record?['losses']);
    result.add(_TeamCardData(
      key: key,
      name: _text(row['team_name'], _text(row['name'], key)),
      abbreviation: _text(row['abbreviation'], _text(row['team_abbreviation'])),
      record: wins == null || losses == null ? 'Team page' : '$wins–$losses',
    ));
  }
  result.sort((a, b) => a.name.compareTo(b.name));
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

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

String _decimal(Object? value) => _number(value)?.toStringAsFixed(1) ?? '—';
String _whole(Object? value) => _number(value)?.round().toString() ?? '—';
