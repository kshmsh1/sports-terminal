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
      appBar: AppBar(
        title: const Text('Sports Terminal'),
      ),
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
          return _PlayerBody(
            session: widget.session,
            playerKey: widget.playerKey,
            fallbackName: widget.playerName,
            data: snapshot.data!,
          );
        },
      ),
    );
  }
}

class _PlayerBody extends StatelessWidget {
  const _PlayerBody({
    required this.session,
    required this.playerKey,
    required this.fallbackName,
    required this.data,
  });

  final AppSession session;
  final String playerKey;
  final String fallbackName;
  final _PlayerPageData data;

  @override
  Widget build(BuildContext context) {
    final dossier = data.dossier;
    final profile = _map(dossier['profile']);
    final name = _text(profile['canonical_name'], fallbackName);
    final position = _text(profile['primary_position']);
    final seasons = _maps(dossier['seasons']);
    final awards = _maps(dossier['awards']);
    final allStar = _maps(dossier['all_star']);
    final draft = _maps(dossier['draft']);
    final games = _maps(dossier['recent_games']);
    final contracts = _playerContracts(data.registry, playerKey, name);
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
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
                [position, _text(profile['height']), _text(profile['weight'])]
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              _SummaryCards(items: [
                _SummaryItem('NBA seasons', '${_uniqueSeasons(seasons)}'),
                _SummaryItem('Awards', '${awards.length}'),
                _SummaryItem('All-Star', '${allStar.length}'),
                _SummaryItem('Recent games', '${games.length}'),
              ]),
              const SizedBox(height: 26),
              const _SectionTitle('Career statistics'),
              const SizedBox(height: 10),
              _PlayerCareerTable(rows: seasons),
              const SizedBox(height: 28),
              const _SectionTitle('Contract'),
              const SizedBox(height: 10),
              _ContractSection(contracts: contracts),
              const SizedBox(height: 28),
              const _SectionTitle('Awards & honors'),
              const SizedBox(height: 10),
              _AwardsSection(awards: awards, allStar: allStar, draft: draft),
              const SizedBox(height: 28),
              const _SectionTitle('Recent games'),
              const SizedBox(height: 10),
              _RecentGames(rows: games),
            ],
          ),
        ),
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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final resolved = await _api.resolveTeamKey(widget.teamKey);
    if (resolved == null || resolved.isEmpty) {
      throw WebsiteNbaApiException('Team ${widget.teamName} was not found in the canonical NBA warehouse.');
    }
    return _api.teamDossier(resolved);
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
              onRetry: () => setState(() => _future = _load()),
            );
          }
          return _TeamBody(session: widget.session, dossier: snapshot.data!);
        },
      ),
    );
  }
}

class _TeamBody extends StatelessWidget {
  const _TeamBody({required this.session, required this.dossier});

  final AppSession session;
  final Map<String, dynamic> dossier;

  @override
  Widget build(BuildContext context) {
    final profile = _map(dossier['profile']);
    final franchise = _map(dossier['franchise']);
    final seasons = _maps(dossier['seasons']);
    final games = _maps(dossier['recent_games']);
    final players = _maps(dossier['notable_players']);
    final colors = Theme.of(context).colorScheme;
    final name = _text(profile['canonical_name'], 'NBA Team');
    final abbreviation = _text(profile['abbreviation']);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
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
                [abbreviation, _text(franchise['canonical_name'])]
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              _SummaryCards(items: [
                _SummaryItem('Seasons', '${seasons.length}'),
                _SummaryItem('Recent games', '${games.length}'),
                _SummaryItem('Players', '${players.length}'),
                _SummaryItem('Franchise', _text(franchise['canonical_name'], '—')),
              ]),
              const SizedBox(height: 26),
              const _SectionTitle('Season history'),
              const SizedBox(height: 10),
              _TeamSeasonTable(rows: seasons),
              const SizedBox(height: 28),
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
                          child: Text('No player history is available for this team yet.'),
                        ),
                      ),
                    for (var i = 0; i < players.length; i++) ...[
                      ListTile(
                        title: Text(_text(players[i]['player_name'], _text(players[i]['canonical_name'], 'Player'))),
                        subtitle: Text(_text(players[i]['season_id'])),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          final key = _text(players[i]['player_key']);
                          if (key.isEmpty) return;
                          openWebsiteNbaPlayerPage(
                            context,
                            session: session,
                            playerKey: key,
                            playerName: _text(players[i]['player_name'], 'Player'),
                          );
                        },
                      ),
                      if (i != players.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Recent games'),
              const SizedBox(height: 10),
              _TeamGames(rows: games),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerCareerTable extends StatelessWidget {
  const _PlayerCareerTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final ordered = [...rows]
      ..sort((a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Season')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Team')),
            DataColumn(numeric: true, label: Text('GP')),
            DataColumn(numeric: true, label: Text('PPG')),
            DataColumn(numeric: true, label: Text('RPG')),
            DataColumn(numeric: true, label: Text('APG')),
            DataColumn(numeric: true, label: Text('TS%')),
            DataColumn(numeric: true, label: Text('PER')),
            DataColumn(numeric: true, label: Text('BPM')),
            DataColumn(numeric: true, label: Text('VORP')),
          ],
          rows: [
            for (final row in ordered)
              DataRow(cells: [
                DataCell(Text(_text(row['season_id']))),
                DataCell(Text(_segment(row['season_type']))),
                DataCell(Text(_text(row['team_abbreviation'], '—'))),
                DataCell(Text(_whole(row['games']))),
                DataCell(Text(_perGame(row['pts'], row['games']))),
                DataCell(Text(_perGame(row['reb'], row['games']))),
                DataCell(Text(_perGame(row['ast'], row['games']))),
                DataCell(Text(_pct(row['ts_pct']))),
                DataCell(Text(_decimal(row['per']))),
                DataCell(Text(_signed(row['bpm']))),
                DataCell(Text(_decimal(row['vorp']))),
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
    final ordered = [...rows]
      ..sort((a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])));
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
              DataRow(cells: [
                DataCell(Text(_text(row['season_id']))),
                DataCell(Text(_whole(row['wins']))),
                DataCell(Text(_whole(row['losses']))),
                DataCell(Text(_pct(row['win_pct']))),
                DataCell(Text(_decimal(row['ortg']))),
                DataCell(Text(_decimal(row['drtg']))),
                DataCell(Text(_signed(row['net_rtg']))),
                DataCell(Text(_decimal(row['pace']))),
                DataCell(Text(_signed(row['srs']))),
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No registered contract record is currently available for this player. Historical statistics remain independent of contract-data availability.'),
        ),
      );
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_text(item['team_id'])} · ${_text(item['season'])}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(_text(item['source_status'], 'unknown')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final year in _maps(item['years']))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          SizedBox(width: 90, child: Text(_text(year['season']))),
                          SizedBox(width: 130, child: Text(_money(year['salary']))),
                          Text('${_money(year['guaranteed_amount'])} guaranteed'),
                        ],
                      ),
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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (draft.isNotEmpty)
                Text(
                  'Draft: ${_text(draft.first['draft_year'])} · ${_text(draft.first['round_text'])} · pick ${_text(draft.first['pick_number'])} · ${_text(draft.first['drafting_team_text'])}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (draft.isNotEmpty) const SizedBox(height: 14),
              Text('All-Star selections: ${allStar.length}'),
              const SizedBox(height: 14),
              if (awards.isEmpty)
                const Text('No award rows are available.')
              else
                for (final award in awards.take(60))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text('${_text(award['season_id'])} · ${_text(award['award'])}${award['winner'] == true ? ' · Winner' : ''}'),
                  ),
            ],
          ),
        ),
      );
}

class _RecentGames extends StatelessWidget {
  const _RecentGames({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Team')),
              DataColumn(label: Text('Opponent')),
              DataColumn(numeric: true, label: Text('MIN')),
              DataColumn(numeric: true, label: Text('PTS')),
              DataColumn(numeric: true, label: Text('REB')),
              DataColumn(numeric: true, label: Text('AST')),
            ],
            rows: [
              for (final row in rows)
                DataRow(cells: [
                  DataCell(Text(_text(row['game_date']))),
                  DataCell(Text(_text(row['team_abbreviation'], _text(row['team_name'])))),
                  DataCell(Text(_text(row['opponent_abbreviation'], _text(row['opponent_name'])))),
                  DataCell(Text(_decimal(row['minutes']))),
                  DataCell(Text(_whole(row['pts']))),
                  DataCell(Text(_whole(row['reb']))),
                  DataCell(Text(_whole(row['ast']))),
                ]),
            ],
          ),
        ),
      );
}

class _TeamGames extends StatelessWidget {
  const _TeamGames({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            if (rows.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text('No recent games are available.')),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      );
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
                  Text('This canonical NBA page could not be loaded from the local warehouse. ${error ?? ''}'),
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
    final nameMatch = _text(record['player_name']).toLowerCase() == playerName.toLowerCase();
    if (!idMatch && !nameMatch) continue;
    result.add({
      ...record,
      'source_status': wrapper['source_status'],
      'updated_at': wrapper['updated_at'],
    });
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
  return text.isEmpty || text == 'null' ? fallback : text;
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _whole(Object? value) {
  final number = _num(value);
  return number == null ? '—' : number.round().toString();
}

String _decimal(Object? value, [int digits = 1]) {
  final number = _num(value);
  return number == null ? '—' : number.toStringAsFixed(digits);
}

String _signed(Object? value) {
  final number = _num(value);
  if (number == null) return '—';
  return '${number >= 0 ? '+' : ''}${number.toStringAsFixed(1)}';
}

String _pct(Object? value) {
  final number = _num(value);
  if (number == null) return '—';
  final scaled = number.abs() <= 1.5 ? number * 100 : number;
  return '${scaled.toStringAsFixed(1)}%';
}

String _perGame(Object? total, Object? games) {
  final numerator = _num(total);
  final denominator = _num(games);
  if (numerator == null || denominator == null || denominator <= 0) return '—';
  return (numerator / denominator).toStringAsFixed(1);
}

String _money(Object? value) {
  final number = _num(value);
  if (number == null) return '—';
  if (number.abs() >= 1000000) return '\$${(number / 1000000).toStringAsFixed(1)}M';
  if (number.abs() >= 1000) return '\$${(number / 1000).toStringAsFixed(0)}K';
  return '\$${number.toStringAsFixed(0)}';
}

String _segment(Object? value) {
  final text = _text(value).toLowerCase();
  if (text.contains('playoff')) return 'Playoffs';
  if (text.contains('regular')) return 'Regular';
  return text.isEmpty ? '—' : text;
}

int _uniqueSeasons(List<Map<String, dynamic>> rows) =>
    rows.map((row) => _text(row['season_id'])).where((value) => value.isNotEmpty).toSet().length;
