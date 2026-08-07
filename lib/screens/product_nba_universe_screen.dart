import 'package:flutter/material.dart';

import '../services/historical_nba_repository.dart';
import '../services/nba_research_context_store.dart';

const _universeBg = Color(0xFF09111C);
const _universePanel = Color(0xFF121D2B);
const _universePanel2 = Color(0xFF192638);
const _universeLine = Color(0xFF314158);
const _universeText = Color(0xFFF3F7FC);
const _universeMuted = Color(0xFF9AA8BA);
const _universeBlue = Color(0xFF65B5FF);
const _universeGold = Color(0xFFFFCB45);
const _universeGreen = Color(0xFF65E3A5);
const _universeOrange = Color(0xFFFF9A5A);

enum _UniverseEntityKind { players, teams }

class ProductNbaUniverseScreen extends StatefulWidget {
  const ProductNbaUniverseScreen({
    super.key,
    this.onOpenStats,
    this.onOpenAnalytics,
  });

  final VoidCallback? onOpenStats;
  final VoidCallback? onOpenAnalytics;

  @override
  State<ProductNbaUniverseScreen> createState() => _ProductNbaUniverseScreenState();
}

class _ProductNbaUniverseScreenState extends State<ProductNbaUniverseScreen> {
  final HistoricalNbaRepository _history = const HistoricalNbaRepository();
  final NbaResearchContextStore _contexts = const NbaResearchContextStore();
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  _UniverseEntityKind _kind = _UniverseEntityKind.players;
  String _league = 'ALL';
  bool _searching = false;
  String _error = '';
  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _selected;
  Future<Map<String, dynamic>>? _dossierFuture;
  late Future<NbaResearchContext> _contextFuture;
  late Future<List<NbaResearchContext>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _contexts.load();
    _recentFuture = _contexts.recent();
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _error = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = '';
    });
    try {
      final league = _league == 'ALL' ? '' : _league;
      final rows = _kind == _UniverseEntityKind.players
          ? await _history.searchPlayers(query, league: league, limit: 75)
          : await _history.searchTeams(query, league: league, limit: 75);
      if (!mounted) return;
      setState(() {
        _results = rows;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = const [];
        _error = error.toString();
      });
    }
  }

  void _switchKind(_UniverseEntityKind kind) {
    setState(() {
      _kind = kind;
      _results = const [];
      _selected = null;
      _dossierFuture = null;
      _error = '';
    });
    if (_query.text.trim().isNotEmpty) _search();
  }

  void _openResult(Map<String, dynamic> row) {
    setState(() {
      _selected = row;
      _dossierFuture = _kind == _UniverseEntityKind.players
          ? _loadPlayerDossier(row)
          : _loadTeamDossier(row);
    });
  }

  Future<Map<String, dynamic>> _loadPlayerDossier(
    Map<String, dynamic> row,
  ) async {
    final key = row['player_key']?.toString() ?? '';
    final profile = await _history.player(key);
    final career = await _history.career(
      key,
      league: _league == 'ALL' ? '' : _league,
      seasonType: 'regular',
    );
    Map<String, dynamic> era = const {};
    try {
      era = await _history.eraAdjusted(
        key,
        metric: 'pts',
        basis: 'per_game',
        league: _league == 'ALL' ? 'NBA' : _league,
        seasonType: 'regular',
        minGames: 10,
      );
    } catch (_) {
      era = const {};
    }
    return {
      'kind': 'player',
      'profile': profile,
      'rows': career['rows'] is List ? career['rows'] : const [],
      'season_count': career['season_count'] ?? 0,
      'era': era,
    };
  }

  Future<Map<String, dynamic>> _loadTeamDossier(
    Map<String, dynamic> row,
  ) async {
    final key = row['team_key']?.toString() ?? '';
    final payload = await _history.teamHistory(key);
    return {
      'kind': 'team',
      'profile': payload['team'] is Map ? payload['team'] : row,
      'rows': payload['rows'] is List ? payload['rows'] : const [],
    };
  }

  Future<void> _activateSeason(
    Map<String, dynamic> seasonRow, {
    String destination = 'stay',
  }) async {
    final season = seasonRow['season_id']?.toString() ?? '';
    if (season.isEmpty) return;
    final league = (seasonRow['league_id']?.toString().isNotEmpty ?? false)
        ? seasonRow['league_id'].toString()
        : (_league == 'ALL' ? 'NBA' : _league);
    final seasonType = seasonRow['season_type']?.toString() ?? 'regular';
    final selected = _selected ?? const <String, dynamic>{};
    final player = _kind == _UniverseEntityKind.players;
    final activeContext = await _contexts.activateHistorical(
      season: season,
      league: league,
      seasonType: seasonType,
      playerKey: player ? selected['player_key']?.toString() ?? '' : '',
      playerName: player ? selected['canonical_name']?.toString() ?? '' : '',
      teamKey: !player ? selected['team_key']?.toString() ?? '' : '',
      teamName: !player ? selected['canonical_name']?.toString() ?? '' : '',
    );
    if (!mounted) return;
    setState(() {
      _contextFuture = Future.value(activeContext);
      _recentFuture = _contexts.recent();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${activeContext.scopeLabel}${activeContext.entityLabel.isEmpty ? '' : ' · ${activeContext.entityLabel}'} is now the active NBA research context.',
        ),
      ),
    );
    if (destination == 'stats') widget.onOpenStats?.call();
    if (destination == 'analytics') widget.onOpenAnalytics?.call();
  }

  Future<void> _restore(NbaResearchContext context) async {
    await _contexts.restore(context);
    if (!mounted) return;
    setState(() {
      _contextFuture = _contexts.load();
      _recentFuture = _contexts.recent();
    });
  }

  Future<void> _restoreCurrent() async {
    final activeContext = await _contexts.selectCurrent();
    if (!mounted) return;
    setState(() {
      _contextFuture = Future.value(activeContext);
      _recentFuture = _contexts.recent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _universeBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1050;
          final body = desktop ? _desktopBody() : _compactBody();
          if (constraints.hasBoundedHeight) {
            return Column(
              children: [
                _header(),
                _contextStrip(),
                Expanded(child: body),
              ],
            );
          }
          return SizedBox(
            height: 900,
            child: Column(
              children: [
                _header(),
                _contextStrip(),
                Expanded(child: body),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      decoration: const BoxDecoration(
        color: _universePanel,
        border: Border(bottom: BorderSide(color: _universeLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_universeBlue, Color(0xFF8B5CF6), _universeOrange],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.public_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NBA UNIVERSE',
                  style: TextStyle(
                    color: _universeText,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Universal player and team discovery · canonical history · direct terminal context handoff',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _universeMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const _UniversePill('1946–PRESENT', _universeGold),
        ],
      ),
    );
  }

  Widget _contextStrip() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0D1725),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, color: _universeBlue, size: 16),
          const SizedBox(width: 7),
          FutureBuilder<NbaResearchContext>(
            future: _contextFuture,
            builder: (context, snapshot) {
              final active = snapshot.data;
              return Expanded(
                child: Text(
                  active == null
                      ? 'Loading active NBA research context…'
                      : 'ACTIVE CONTEXT · ${active.scopeLabel}${active.entityLabel.isEmpty ? '' : ' · ${active.entityLabel}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active?.historical == true
                        ? _universeGold
                        : _universeGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
              );
            },
          ),
          TextButton.icon(
            onPressed: _restoreCurrent,
            icon: const Icon(Icons.verified_outlined, size: 16),
            label: const Text('Current release'),
          ),
        ],
      ),
    );
  }

  Widget _desktopBody() {
    return Row(
      children: [
        SizedBox(
          width: 430,
          child: Container(
            decoration: const BoxDecoration(
              color: _universePanel,
              border: Border(right: BorderSide(color: _universeLine)),
            ),
            child: Column(
              children: [
                _searchControls(),
                Expanded(child: _resultsPanel()),
              ],
            ),
          ),
        ),
        Expanded(child: _dossierPanel()),
      ],
    );
  }

  Widget _compactBody() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _searchControls(),
        SizedBox(height: 360, child: _resultsPanel()),
        const Divider(height: 1, color: _universeLine),
        SizedBox(height: 620, child: _dossierPanel()),
      ],
    );
  }

  Widget _searchControls() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _query,
            focusNode: _queryFocus,
            onSubmitted: (_) => _search(),
            style: const TextStyle(color: _universeText),
            decoration: InputDecoration(
              hintText: _kind == _UniverseEntityKind.players
                  ? 'Search any player…'
                  : 'Search any team or abbreviation…',
              hintStyle: const TextStyle(color: _universeMuted),
              filled: true,
              fillColor: _universePanel2,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _universeLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _universeLine),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ChoiceChip(
                selected: _kind == _UniverseEntityKind.players,
                avatar: const Icon(Icons.person_search_rounded, size: 17),
                label: const Text('Players'),
                onSelected: (_) => _switchKind(_UniverseEntityKind.players),
              ),
              ChoiceChip(
                selected: _kind == _UniverseEntityKind.teams,
                avatar: const Icon(Icons.groups_rounded, size: 17),
                label: const Text('Teams'),
                onSelected: (_) => _switchKind(_UniverseEntityKind.teams),
              ),
              for (final league in const ['ALL', 'NBA', 'ABA', 'BAA'])
                ChoiceChip(
                  selected: _league == league,
                  label: Text(league),
                  onSelected: (_) {
                    setState(() => _league = league);
                    if (_query.text.trim().isNotEmpty) _search();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<NbaResearchContext>>(
            future: _recentFuture,
            builder: (context, snapshot) {
              final recent = snapshot.data ?? const <NbaResearchContext>[];
              if (recent.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECENT CONTEXTS',
                    style: TextStyle(
                      color: _universeMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 33,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recent.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final item = recent[index];
                        return ActionChip(
                          avatar: Icon(
                            item.historical
                                ? Icons.history_rounded
                                : Icons.verified_outlined,
                            size: 15,
                          ),
                          label: Text(
                            item.entityLabel.isNotEmpty
                                ? '${item.season.isEmpty ? 'Current' : item.season} · ${item.entityLabel}'
                                : item.scopeLabel,
                          ),
                          onPressed: () => _restore(item),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _resultsPanel() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return _UniverseEmpty(
        icon: Icons.cloud_off_rounded,
        title: 'Historical backend unavailable',
        body: _error,
      );
    }
    if (_query.text.trim().isEmpty) {
      return const _UniverseEmpty(
        icon: Icons.travel_explore_rounded,
        title: 'Search the NBA universe',
        body:
            'Find a player or team across canonical NBA, ABA and BAA history. Selecting a season can immediately become the active context for the rest of the terminal.',
      );
    }
    if (_results.isEmpty) {
      return const _UniverseEmpty(
        icon: Icons.search_off_rounded,
        title: 'No canonical matches',
        body: 'Try a broader name, abbreviation, or league scope.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final row = _results[index];
        return _ResultTile(
          row: row,
          kind: _kind,
          selected: identical(row, _selected),
          onTap: () => _openResult(row),
        );
      },
    );
  }

  Widget _dossierPanel() {
    final future = _dossierFuture;
    if (future == null) {
      return const _UniverseEmpty(
        icon: Icons.account_tree_rounded,
        title: 'Entity dossier',
        body:
            'Choose a player or team to open canonical identity, career/team history, source confidence and one-click season handoffs into Stats and Analytics.',
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _UniverseEmpty(
            icon: Icons.warning_amber_rounded,
            title: 'Could not load dossier',
            body: snapshot.error.toString(),
          );
        }
        final dossier = snapshot.data ?? const <String, dynamic>{};
        return dossier['kind'] == 'team'
            ? _teamDossier(dossier)
            : _playerDossier(dossier);
      },
    );
  }

  Widget _playerDossier(Map<String, dynamic> dossier) {
    final profile = _stringMap(dossier['profile']);
    final rows = _mapList(dossier['rows']);
    final era = _stringMap(dossier['era']);
    final eraRows = _mapList(era['rows']);
    final name = profile['canonical_name']?.toString() ??
        _selected?['canonical_name']?.toString() ??
        'Historical Player';
    final confidence = _number(profile['identity_confidence']);
    final sources = _int(profile['source_count']);
    final bestEra = [...eraRows]
      ..sort((a, b) =>
          (_number(b['z_score']) ?? -999).compareTo(_number(a['z_score']) ?? -999));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DossierHero(
            icon: Icons.person_rounded,
            title: name,
            subtitle: [
              if ((profile['primary_position']?.toString() ?? '').isNotEmpty)
                profile['primary_position'].toString(),
              if ((profile['active_from']?.toString() ?? '').isNotEmpty ||
                  (profile['active_to']?.toString() ?? '').isNotEmpty)
                '${profile['active_from'] ?? '—'}–${profile['active_to'] ?? '—'}',
              '${dossier['season_count'] ?? rows.length} seasons',
            ].join(' · '),
            pills: [
              if (sources > 0) '$sources SOURCES',
              if (confidence != null)
                '${(confidence * 100).toStringAsFixed(0)}% ID CONFIDENCE',
              if ((profile['nba_id']?.toString() ?? '').isNotEmpty) 'NBA ID',
              if ((profile['bref_id']?.toString() ?? '').isNotEmpty) 'BREF ID',
            ],
          ),
          const SizedBox(height: 14),
          _UniversePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _UniverseHeading(
                  'Career runway',
                  'Every canonical regular-season row. Activate any season as the shared terminal context.',
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const Text(
                    'No regular-season career rows are available for this league filter.',
                    style: TextStyle(color: _universeMuted),
                  )
                else
                  for (final row in rows.reversed.take(40))
                    _SeasonRow(
                      row: row,
                      player: true,
                      onActivate: (destination) =>
                          _activateSeason(row, destination: destination),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _UniversePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _UniverseHeading(
                  'Era-relative scoring signal',
                  'Points per game standardized against eligible players in each NBA season. This supplements raw production; it does not replace it.',
                ),
                const SizedBox(height: 10),
                if (bestEra.isEmpty)
                  const Text(
                    'No NBA era-adjusted scoring series is available for this player under the current filter.',
                    style: TextStyle(color: _universeMuted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final row in bestEra.take(10)) _EraCard(row: row),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _UniversePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _UniverseHeading(
                  'Canonical identity & trust',
                  'Cross-source identity fields used to connect historical records without pretending source conflicts do not exist.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Fact('Player key', profile['player_key']),
                    _Fact('NBA ID', profile['nba_id']),
                    _Fact('Basketball Reference', profile['bref_id']),
                    _Fact('Birth date', profile['birth_date']),
                    _Fact('Sources', profile['source_count']),
                    _Fact(
                      'Identity confidence',
                      confidence == null
                          ? null
                          : '${(confidence * 100).toStringAsFixed(1)}%',
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

  Widget _teamDossier(Map<String, dynamic> dossier) {
    final profile = _stringMap(dossier['profile']);
    final rows = _mapList(dossier['rows']);
    final name = profile['canonical_name']?.toString() ??
        _selected?['canonical_name']?.toString() ??
        'Historical Team';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DossierHero(
            icon: Icons.groups_rounded,
            title: name,
            subtitle: [
              if ((profile['abbreviation']?.toString() ?? '').isNotEmpty)
                profile['abbreviation'].toString(),
              if ((profile['league_id']?.toString() ?? '').isNotEmpty)
                profile['league_id'].toString(),
              if ((profile['active_from']?.toString() ?? '').isNotEmpty ||
                  (profile['active_to']?.toString() ?? '').isNotEmpty)
                '${profile['active_from'] ?? '—'}–${profile['active_to'] ?? '—'}',
            ].join(' · '),
            pills: [
              if ((profile['franchise_key']?.toString() ?? '').isNotEmpty)
                'FRANCHISE LINKED',
              if (_int(profile['source_count']) > 0)
                '${_int(profile['source_count'])} SOURCES',
            ],
          ),
          const SizedBox(height: 14),
          _UniversePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _UniverseHeading(
                  'Team history',
                  'Canonical season records and team production. Choose a season to synchronize this team and season across the terminal.',
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const Text(
                    'No canonical team-season rows are available for this team.',
                    style: TextStyle(color: _universeMuted),
                  )
                else
                  for (final row in rows.reversed.take(60))
                    _SeasonRow(
                      row: row,
                      player: false,
                      onActivate: (destination) =>
                          _activateSeason(row, destination: destination),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _UniversePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _UniverseHeading(
                  'Franchise identity',
                  'Team-season identity is linked to franchise lineage so relocations and historical abbreviations remain queryable without collapsing distinct team eras.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Fact('Team key', profile['team_key']),
                    _Fact('Franchise key', profile['franchise_key']),
                    _Fact('Abbreviation', profile['abbreviation']),
                    _Fact('League', profile['league_id']),
                    _Fact('NBA team ID', profile['nba_team_id']),
                    _Fact('Sources', profile['source_count']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map)
          item.map((key, value) => MapEntry(key.toString(), value)),
    ];
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.row,
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> row;
  final _UniverseEntityKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final player = kind == _UniverseEntityKind.players;
    final name = row['canonical_name']?.toString() ?? 'Unknown';
    final subtitle = player
        ? [
            if ((row['primary_position']?.toString() ?? '').isNotEmpty)
              row['primary_position'].toString(),
            if ((row['first_stat_season']?.toString() ?? '').isNotEmpty)
              '${row['first_stat_season']}–${row['last_stat_season']}',
            if (row['seasons'] != null) '${row['seasons']} seasons',
          ].join(' · ')
        : [
            if ((row['abbreviation']?.toString() ?? '').isNotEmpty)
              row['abbreviation'].toString(),
            if ((row['league_id']?.toString() ?? '').isNotEmpty)
              row['league_id'].toString(),
            if ((row['active_from']?.toString() ?? '').isNotEmpty)
              '${row['active_from']}–${row['active_to'] ?? 'present'}',
          ].join(' · ');
    return Material(
      color: selected ? const Color(0xFF203B5A) : _universePanel2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _universeBlue : _universeLine,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF26364B),
                child: Icon(
                  player ? Icons.person_rounded : Icons.groups_rounded,
                  size: 18,
                  color: selected ? _universeBlue : _universeMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _universeText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _universeMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _universeMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonRow extends StatelessWidget {
  const _SeasonRow({
    required this.row,
    required this.player,
    required this.onActivate,
  });

  final Map<String, dynamic> row;
  final bool player;
  final ValueChanged<String> onActivate;

  @override
  Widget build(BuildContext context) {
    final games = _value(row['games']);
    final wins = _value(row['wins']);
    final losses = _value(row['losses']);
    final pts = _value(row['pts']);
    final ppg = player ? _perGame(row['pts'], row['games']) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _universePanel2,
        border: Border.all(color: _universeLine),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              row['season_id']?.toString() ?? '—',
              style: const TextStyle(
                color: _universeGold,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              row['league_id']?.toString() ?? 'NBA',
              style: const TextStyle(color: _universeMuted, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              player
                  ? '${row['team_abbreviation'] ?? '—'} · $games G · ${ppg == null ? pts : '${ppg.toStringAsFixed(1)} PPG'}'
                  : '${row['team_abbreviation'] ?? '—'} · $wins–$losses · $pts PTS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _universeText, fontSize: 10),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Activate season',
            onSelected: onActivate,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'stay',
                child: Text('Set active context'),
              ),
              PopupMenuItem(
                value: 'stats',
                child: Text('Set context + open Stats'),
              ),
              PopupMenuItem(
                value: 'analytics',
                child: Text('Set context + open Analytics'),
              ),
            ],
            icon: const Icon(
              Icons.bolt_rounded,
              color: _universeBlue,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  static String _value(Object? value) {
    if (value == null) return '—';
    if (value is num) {
      if (value.toDouble() == value.roundToDouble()) return '${value.round()}';
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }

  static double? _perGame(Object? total, Object? games) {
    final t = total is num ? total.toDouble() : double.tryParse('$total');
    final g = games is num ? games.toDouble() : double.tryParse('$games');
    if (t == null || g == null || g <= 0) return null;
    return t / g;
  }
}

class _EraCard extends StatelessWidget {
  const _EraCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final z = _ProductNbaUniverseScreenState._number(row['z_score']);
    final percentile = _ProductNbaUniverseScreenState._number(row['percentile']);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _universePanel2,
        border: Border.all(color: _universeLine),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['season']?.toString() ?? '—',
            style: const TextStyle(
              color: _universeGold,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            z == null ? '—' : '${z >= 0 ? '+' : ''}${z.toStringAsFixed(2)}σ',
            style: const TextStyle(
              color: _universeText,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          Text(
            percentile == null
                ? 'era percentile unavailable'
                : '${(percentile * 100).toStringAsFixed(0)}th percentile',
            style: const TextStyle(color: _universeMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _DossierHero extends StatelessWidget {
  const _DossierHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pills,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> pills;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF15304F), Color(0xFF213A5D), Color(0xFF513521)],
        ),
        border: Border.all(color: _universeLine),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: _universeBlue, size: 28),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _universeText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _universeMuted),
                  ),
                ],
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final pill in pills)
                        _UniversePill(pill, _universeBlue),
                    ],
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

class _UniversePanel extends StatelessWidget {
  const _UniversePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _universePanel,
        border: Border.all(color: _universeLine),
        borderRadius: BorderRadius.circular(15),
      ),
      child: child,
    );
  }
}

class _UniverseHeading extends StatelessWidget {
  const _UniverseHeading(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _universeText,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: _universeMuted,
            fontSize: 10,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.toString() ?? '';
    return Container(
      width: 190,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _universePanel2,
        border: Border.all(color: _universeLine),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.isEmpty ? '—' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _universeText,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: _universeMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _UniversePill extends StatelessWidget {
  const _UniversePill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        border: Border.all(color: color.withOpacity(.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .45,
        ),
      ),
    );
  }
}

class _UniverseEmpty extends StatelessWidget {
  const _UniverseEmpty({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _universeBlue, size: 34),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _universeText,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _universeMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
