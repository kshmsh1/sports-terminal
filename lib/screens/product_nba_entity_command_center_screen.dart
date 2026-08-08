import 'package:flutter/material.dart';

import '../services/nba_entity_intelligence_repository.dart';
import '../services/nba_entity_watchlist_store.dart';
import '../services/nba_research_context_store.dart';

const _bg = Color(0xFF08111C);
const _panel = Color(0xFF111D2A);
const _panel2 = Color(0xFF192738);
const _line = Color(0xFF314257);
const _text = Color(0xFFF4F7FB);
const _muted = Color(0xFF9EABBA);
const _gold = Color(0xFFFFCB45);
const _blue = Color(0xFF66B5FF);
const _green = Color(0xFF65E3A5);
const _red = Color(0xFFFF7B7B);

enum _EntityDeskTab { search, watchlist, season }

class ProductNbaEntityCommandCenterScreen extends StatefulWidget {
  const ProductNbaEntityCommandCenterScreen({
    super.key,
    this.onOpenStats,
    this.onOpenAnalytics,
    this.onOpenHistoricalIntelligence,
  });

  final VoidCallback? onOpenStats;
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onOpenHistoricalIntelligence;

  @override
  State<ProductNbaEntityCommandCenterScreen> createState() =>
      _ProductNbaEntityCommandCenterScreenState();
}

class _ProductNbaEntityCommandCenterScreenState
    extends State<ProductNbaEntityCommandCenterScreen> {
  final NbaEntityIntelligenceRepository _repository =
      const NbaEntityIntelligenceRepository();
  final NbaEntityWatchlistStore _watchlist = const NbaEntityWatchlistStore();
  final NbaResearchContextStore _contexts = const NbaResearchContextStore();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _seasonController =
      TextEditingController(text: '2024-25');

  _EntityDeskTab _tab = _EntityDeskTab.search;
  String _league = 'ALL';
  String _seasonLeague = 'NBA';
  String _seasonType = 'regular';
  bool _searching = false;
  String _searchError = '';
  Map<String, dynamic> _searchPayload = const {};
  String _selectedKind = '';
  Map<String, dynamic>? _selectedRow;
  Future<Map<String, dynamic>>? _dossierFuture;
  late Future<List<NbaEntityWatchItem>> _watchlistFuture;
  late Future<NbaResearchContext> _contextFuture;
  late Future<Map<String, dynamic>> _seasonFuture;

  @override
  void initState() {
    super.initState();
    _watchlistFuture = _watchlist.load();
    _contextFuture = _contexts.load();
    _seasonFuture = _loadSeason();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _seasonController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadSeason() => _repository.seasonCommand(
        _seasonController.text.trim(),
        league: _seasonLeague,
        seasonType: _seasonType,
      );

  void _refreshSeason() {
    setState(() {
      _seasonFuture = _loadSeason();
    });
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchPayload = const {};
        _searchError = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = '';
    });
    try {
      final payload = await _repository.search(query, league: _league);
      if (!mounted) return;
      setState(() {
        _searchPayload = payload;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchPayload = const {};
        _searchError = error.toString();
      });
    }
  }

  Future<void> _openEntity(String kind, Map<String, dynamic> row) async {
    final normalized = kind.toLowerCase();
    final Future<Map<String, dynamic>> future;
    switch (normalized) {
      case 'player':
        future = _repository.playerDossier(
          row['player_key']?.toString() ?? '',
          league: _league,
        );
      case 'team':
        future = _repository.teamDossier(
          row['team_key']?.toString() ?? '',
          league: _league,
        );
      case 'franchise':
        future = _repository.franchiseDossier(
          row['franchise_key']?.toString() ?? '',
          league: _league,
        );
      case 'season':
        future = _repository.seasonCommand(
          row['season_id']?.toString() ?? '',
          league: _league == 'ALL' ? 'NBA' : _league,
        );
      default:
        future = Future.value({'kind': normalized, 'profile': row});
    }
    setState(() {
      _selectedKind = normalized;
      _selectedRow = row;
      _dossierFuture = future;
    });
  }

  Future<void> _activateHistorical({
    required String season,
    required String league,
    required String seasonType,
    String playerKey = '',
    String playerName = '',
    String teamKey = '',
    String teamName = '',
    String gameKey = '',
    String destination = '',
  }) async {
    if (season.trim().isEmpty) return;
    final active = await _contexts.activateHistorical(
      season: season,
      league: league.isEmpty ? 'NBA' : league,
      seasonType: seasonType.isEmpty ? 'regular' : seasonType,
      playerKey: playerKey,
      playerName: playerName,
      teamKey: teamKey,
      teamName: teamName,
      gameKey: gameKey,
    );
    if (!mounted) return;
    setState(() {
      _contextFuture = Future.value(active);
    });
    if (destination == 'stats') widget.onOpenStats?.call();
    if (destination == 'analytics') widget.onOpenAnalytics?.call();
    if (destination == 'history') widget.onOpenHistoricalIntelligence?.call();
  }

  Future<void> _toggleWatch(String kind, Map<String, dynamic> row) async {
    final item = _watchItem(kind, row);
    await _watchlist.toggle(item);
    if (!mounted) return;
    setState(() {
        _watchlistFuture = _watchlist.load();
      });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.label} watchlist updated.')),
    );
  }

  NbaEntityWatchItem _watchItem(String kind, Map<String, dynamic> row) {
    final normalized = kind.toLowerCase();
    if (normalized == 'player') {
      return NbaEntityWatchItem(
        kind: normalized,
        key: row['player_key']?.toString() ?? '',
        label: row['canonical_name']?.toString() ??
            row['player_name']?.toString() ??
            'Player',
        subtitle: [
          row['primary_position']?.toString() ?? '',
          if (row['first_stat_season'] != null || row['last_stat_season'] != null)
            '${row['first_stat_season'] ?? '?'}–${row['last_stat_season'] ?? '?'}',
        ].where((item) => item.isNotEmpty).join(' · '),
        league: _league == 'ALL' ? 'NBA' : _league,
      );
    }
    if (normalized == 'team') {
      return NbaEntityWatchItem(
        kind: normalized,
        key: row['team_key']?.toString() ?? '',
        label: row['canonical_name']?.toString() ??
            row['team_name']?.toString() ??
            'Team',
        subtitle: row['franchise_name']?.toString() ??
            row['abbreviation']?.toString() ??
            '',
        league: row['league_id']?.toString() ??
            (_league == 'ALL' ? 'NBA' : _league),
      );
    }
    if (normalized == 'franchise') {
      return NbaEntityWatchItem(
        kind: normalized,
        key: row['franchise_key']?.toString() ?? '',
        label: row['canonical_name']?.toString() ?? 'Franchise',
        subtitle: '${row['first_season'] ?? '?'}–${row['last_season'] ?? '?'}',
        league: _league == 'ALL' ? 'NBA' : _league,
      );
    }
    if (normalized == 'season') {
      final season = row['season_id']?.toString() ?? '';
      return NbaEntityWatchItem(
        kind: normalized,
        key: season,
        label: row['label']?.toString() ?? season,
        subtitle: _league == 'ALL' ? 'NBA' : _league,
        season: season,
        league: _league == 'ALL' ? 'NBA' : _league,
      );
    }
    final season = row['season_id']?.toString() ?? '';
    return NbaEntityWatchItem(
      kind: 'game',
      key: row['game_key']?.toString() ?? '',
      label: '${row['away_team_name'] ?? 'Away'} @ ${row['home_team_name'] ?? 'Home'}',
      subtitle: '${row['game_date'] ?? ''} · $season',
      season: season,
      league: row['league_id']?.toString() ?? 'NBA',
      seasonType: row['season_type']?.toString() ?? 'regular',
    );
  }

  Future<void> _openWatchItem(NbaEntityWatchItem item) async {
    if (item.kind == 'season') {
      _seasonController.text = item.season.isNotEmpty ? item.season : item.key;
      setState(() {
        _seasonLeague = item.league;
        _seasonType = item.seasonType;
        _tab = _EntityDeskTab.season;
        _seasonFuture = _loadSeason();
      });
      return;
    }
    if (item.kind == 'game') {
      await _activateHistorical(
        season: item.season,
        league: item.league,
        seasonType: item.seasonType,
        gameKey: item.key,
        destination: 'history',
      );
      return;
    }
    setState(() => _tab = _EntityDeskTab.search);
    if (item.kind == 'player') {
      await _openEntity('player', {
        'player_key': item.key,
        'canonical_name': item.label,
      });
      return;
    }
    if (item.kind == 'team') {
      await _openEntity('team', {
        'team_key': item.key,
        'canonical_name': item.label,
      });
      return;
    }
    if (item.kind == 'franchise') {
      await _openEntity('franchise', {
        'franchise_key': item.key,
        'canonical_name': item.label,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final height = constraints.hasBoundedHeight ? constraints.maxHeight : 960.0;
          return SizedBox(
            height: height,
            child: Column(
              children: [
                _header(compact),
                _contextBar(compact),
                _tabBar(),
                Expanded(
                  child: switch (_tab) {
                    _EntityDeskTab.search => _searchDesk(compact),
                    _EntityDeskTab.watchlist => _watchlistDesk(),
                    _EntityDeskTab.season => _seasonDesk(),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(bool compact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_blue, _gold]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub_rounded, color: _bg),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NBA ENTITY & SEASON INTELLIGENCE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Canonical dossiers · season command · honors · draft · watchlist · terminal context',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (!compact)
            const _Pill(label: 'CANONICAL ENTITY GRAPH', color: _gold),
        ],
      ),
    );
  }

  Widget _contextBar(bool compact) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0B1724),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: FutureBuilder<NbaResearchContext>(
        future: _contextFuture,
        builder: (context, snapshot) {
          final active = snapshot.data;
          return Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 15, color: _blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  active == null
                      ? 'Loading shared NBA context…'
                      : 'ACTIVE · ${active.scopeLabel}${active.entityLabel.isEmpty ? '' : ' · ${active.entityLabel}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active?.historical == true ? _gold : _green,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!compact)
                TextButton.icon(
                  onPressed: widget.onOpenHistoricalIntelligence,
                  icon: const Icon(Icons.history_edu_rounded, size: 15),
                  label: const Text('Historical Intelligence'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      width: double.infinity,
      color: _panel,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabChip(_EntityDeskTab.search, 'Entity Search', Icons.manage_search_rounded),
            const SizedBox(width: 7),
            _tabChip(_EntityDeskTab.watchlist, 'Watchlist', Icons.push_pin_rounded),
            const SizedBox(width: 7),
            _tabChip(_EntityDeskTab.season, 'Season Desk', Icons.calendar_view_month_rounded),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(_EntityDeskTab tab, String label, IconData icon) => ChoiceChip(
        selected: _tab == tab,
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onSelected: (_) => setState(() => _tab = tab),
      );

  Widget _searchDesk(bool compact) {
    final search = _searchPane();
    final dossier = _dossierPane();
    if (compact) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: 500, child: search),
          const Divider(height: 1, color: _line),
          SizedBox(height: 760, child: dossier),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 430, child: search),
        const VerticalDivider(width: 1, color: _line),
        Expanded(child: dossier),
      ],
    );
  }

  Widget _searchPane() {
    final groups = _map(_searchPayload['groups']);
    return Container(
      color: _panel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(color: _text),
                  decoration: InputDecoration(
                    hintText: 'Search player, team, franchise, season or game…',
                    hintStyle: const TextStyle(color: _muted),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    filled: true,
                    fillColor: _panel2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final league in const ['ALL', 'NBA', 'ABA', 'BAA'])
                      ChoiceChip(
                        selected: _league == league,
                        label: Text(league),
                        onSelected: (_) {
                          setState(() => _league = league);
                          if (_searchController.text.trim().isNotEmpty) _search();
                        },
                      ),
                  ],
                ),
                if (_searching) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                if (_searchError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _searchError,
                    style: const TextStyle(color: _red, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Expanded(
            child: groups.isEmpty
                ? const _Empty(
                    icon: Icons.manage_search_rounded,
                    title: 'Search the canonical NBA graph',
                    detail:
                        'One query spans players, teams, franchise lineages, seasons and historical games.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(9),
                    children: [
                      _resultGroup('PLAYERS', 'player', _list(groups['players'])),
                      _resultGroup('TEAMS', 'team', _list(groups['teams'])),
                      _resultGroup(
                        'FRANCHISES',
                        'franchise',
                        _list(groups['franchises']),
                      ),
                      _resultGroup('SEASONS', 'season', _list(groups['seasons'])),
                      _resultGroup('GAMES', 'game', _list(groups['games'])),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _resultGroup(
    String title,
    String kind,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 5, 5, 3),
            child: Text(
              '$title · ${rows.length}',
              style: const TextStyle(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ),
          for (final row in rows)
            _EntitySearchTile(
              kind: kind,
              row: row,
              onOpen: () => _openEntity(kind, row),
              onWatch: () => _toggleWatch(kind, row),
            ),
        ],
      ),
    );
  }

  Widget _dossierPane() {
    final future = _dossierFuture;
    if (_selectedRow == null || future == null) {
      return const _Empty(
        icon: Icons.badge_outlined,
        title: 'Open an NBA object',
        detail:
            'Select a result to load its canonical dossier, source-aware history and terminal handoffs.',
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Empty(
            icon: Icons.error_outline_rounded,
            title: 'Dossier unavailable',
            detail: snapshot.error.toString(),
          );
        }
        final payload = snapshot.data ?? const <String, dynamic>{};
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _dossierTitle(payload),
            const SizedBox(height: 11),
            if (_selectedKind == 'player') _playerDossier(payload),
            if (_selectedKind == 'team') _teamDossier(payload),
            if (_selectedKind == 'franchise') _franchiseDossier(payload),
            if (_selectedKind == 'season') _seasonSummary(payload, compact: true),
            if (_selectedKind == 'game') _gameDossier(_selectedRow ?? const {}),
          ],
        );
      },
    );
  }

  Widget _dossierTitle(Map<String, dynamic> payload) {
    final profile = _map(payload['profile']);
    final row = _selectedRow ?? const <String, dynamic>{};
    final label = profile['canonical_name']?.toString() ??
        row['canonical_name']?.toString() ??
        row['player_name']?.toString() ??
        row['label']?.toString() ??
        row['season_id']?.toString() ??
        '${row['away_team_name'] ?? ''} @ ${row['home_team_name'] ?? ''}';
    return _Box(
      child: Row(
        children: [
          Icon(_kindIcon(_selectedKind), color: _gold, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedKind.toUpperCase(),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Toggle watchlist',
            onPressed: () => _toggleWatch(_selectedKind, row),
            icon: const Icon(Icons.push_pin_outlined),
          ),
        ],
      ),
    );
  }

  Widget _playerDossier(Map<String, dynamic> payload) {
    final profile = _map(payload['profile']);
    final summary = _map(payload['summary']);
    final seasons = _list(payload['seasons']);
    final awards = _list(payload['awards']);
    final allStar = _list(payload['all_star']);
    final draft = _list(payload['draft']);
    final conflicts = _list(payload['conflicts']);
    return Column(
      children: [
        _metricRow({
          'Season rows': summary['season_rows'],
          'Awards': summary['awards'],
          'All-Star': summary['all_star_selections'],
          'Sources': profile['source_count'],
          'Conflicts': summary['material_conflicts'],
        }),
        const SizedBox(height: 11),
        _section(
          'CAREER SEASONS',
          seasons.isEmpty
              ? const [Text('No canonical player-season rows.', style: TextStyle(color: _muted))]
              : [
                  _table(
                    const ['Season', 'Lg', 'Team', 'G', 'PTS', 'REB', 'AST', 'TS%', 'WS', 'BPM'],
                    [
                      for (final row in seasons)
                        [
                          _seasonLink(
                            row['season_id'],
                            () => _activateHistorical(
                              season: row['season_id']?.toString() ?? '',
                              league: row['league_id']?.toString() ?? 'NBA',
                              seasonType: row['season_type']?.toString() ?? 'regular',
                              playerKey: profile['player_key']?.toString() ?? '',
                              playerName: profile['canonical_name']?.toString() ?? '',
                              destination: 'stats',
                            ),
                          ),
                          _cell(row['league_id']),
                          _cell(row['team_abbreviation']),
                          _cell(row['games']),
                          _cell(row['pts']),
                          _cell(row['reb']),
                          _cell(row['ast']),
                          _percent(row['ts_pct']),
                          _cell(row['ws']),
                          _cell(row['bpm']),
                        ],
                    ],
                  ),
                ],
        ),
        const SizedBox(height: 11),
        _section(
          'HONORS & DRAFT',
          [
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final row in awards.take(30))
                  _Info('${row['season_id'] ?? ''} · ${row['award'] ?? 'Award'}'),
                for (final row in allStar.take(30))
                  _Info('${row['season_id'] ?? ''} · All-Star'),
                for (final row in draft)
                  _Info(
                    'Draft ${row['draft_year'] ?? ''} · Pick ${_fmt(row['pick_number'])} · ${row['drafting_team_text'] ?? ''}',
                  ),
                if (awards.isEmpty && allStar.isEmpty && draft.isEmpty)
                  const Text(
                    'No canonical awards, All-Star or draft rows available.',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 11),
        _Box(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                conflicts.isEmpty ? Icons.verified_outlined : Icons.warning_amber_rounded,
                color: conflicts.isEmpty ? _green : _gold,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  conflicts.isEmpty
                      ? 'No material canonical player conflicts are currently recorded. Missing-era fields remain explicitly missing.'
                      : '${conflicts.length} material canonical player conflicts are preserved for review rather than silently overwritten.',
                  style: const TextStyle(color: _muted, fontSize: 10, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teamDossier(Map<String, dynamic> payload) {
    final profile = _map(payload['profile']);
    final franchise = _map(payload['franchise']);
    final summary = _map(payload['summary']);
    final seasons = _list(payload['seasons']);
    final players = _list(payload['notable_players']);
    return Column(
      children: [
        _metricRow({
          'Seasons': summary['seasons'],
          'First': summary['first_season'],
          'Last': summary['last_season'],
          'Sources': profile['source_count'],
          'Conflicts': summary['material_conflicts'],
        }),
        const SizedBox(height: 11),
        if (franchise.isNotEmpty) ...[
          _section(
            'FRANCHISE IDENTITY',
            [
              _keyValues({
                'Franchise': franchise['canonical_name'],
                'Current abbreviation': franchise['current_abbreviation'],
                'Franchise key': franchise['franchise_key'],
              }),
            ],
          ),
          const SizedBox(height: 11),
        ],
        _section(
          'TEAM-SEASON HISTORY',
          seasons.isEmpty
              ? const [Text('No canonical team-season rows.', style: TextStyle(color: _muted))]
              : [
                  _table(
                    const ['Season', 'Lg', 'W', 'L', 'Win%', 'PTS', 'Opp PTS', 'SRS', 'Net Rtg'],
                    [
                      for (final row in seasons)
                        [
                          _seasonLink(
                            row['season_id'],
                            () => _activateHistorical(
                              season: row['season_id']?.toString() ?? '',
                              league: row['league_id']?.toString() ?? 'NBA',
                              seasonType: row['season_type']?.toString() ?? 'regular',
                              teamKey: profile['team_key']?.toString() ?? '',
                              teamName: profile['canonical_name']?.toString() ?? '',
                              destination: 'analytics',
                            ),
                          ),
                          _cell(row['league_id']),
                          _cell(row['wins']),
                          _cell(row['losses']),
                          _percent(row['win_pct']),
                          _cell(row['pts']),
                          _cell(row['opp_pts']),
                          _cell(row['srs']),
                          _cell(row['net_rtg']),
                        ],
                    ],
                  ),
                ],
        ),
        const SizedBox(height: 11),
        _section(
          'LONG-TENURE / HIGH-VOLUME PLAYERS',
          players.isEmpty
              ? const [Text('No linked player-season rows.', style: TextStyle(color: _muted))]
              : [
                  _table(
                    const ['Player', 'Seasons', 'Games', 'PTS', 'REB', 'AST', 'First', 'Last'],
                    [
                      for (final row in players.take(30))
                        [
                          _cell(row['player_name']),
                          _cell(row['seasons']),
                          _cell(row['games']),
                          _cell(row['pts']),
                          _cell(row['reb']),
                          _cell(row['ast']),
                          _cell(row['first_season']),
                          _cell(row['last_season']),
                        ],
                    ],
                  ),
                ],
        ),
      ],
    );
  }

  Widget _franchiseDossier(Map<String, dynamic> payload) {
    final summary = _map(payload['summary']);
    final identities = _list(payload['team_identities']);
    final seasons = _list(payload['seasons']);
    return Column(
      children: [
        _metricRow({
          'Team identities': summary['team_identities'],
          'Seasons': summary['seasons'],
          'First': summary['first_season'],
          'Last': summary['last_season'],
        }),
        const SizedBox(height: 11),
        _section(
          'FRANCHISE LINEAGE',
          [
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final row in identities)
                  _Info(
                    '${row['canonical_name'] ?? ''} · ${row['abbreviation'] ?? ''} · ${row['active_from'] ?? '?'}–${row['active_to'] ?? '?'}',
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 11),
        _section(
          'FRANCHISE SEASONS',
          seasons.isEmpty
              ? const [Text('No canonical franchise seasons.', style: TextStyle(color: _muted))]
              : [
                  _table(
                    const ['Season', 'Identity', 'Lg', 'W', 'L', 'Win%', 'SRS', 'Net Rtg'],
                    [
                      for (final row in seasons)
                        [
                          _seasonLink(
                            row['season_id'],
                            () => _activateHistorical(
                              season: row['season_id']?.toString() ?? '',
                              league: row['league_id']?.toString() ?? 'NBA',
                              seasonType: row['season_type']?.toString() ?? 'regular',
                              teamKey: row['team_key']?.toString() ?? '',
                              teamName: row['canonical_team_name']?.toString() ?? '',
                              destination: 'analytics',
                            ),
                          ),
                          _cell(row['canonical_team_name']),
                          _cell(row['league_id']),
                          _cell(row['wins']),
                          _cell(row['losses']),
                          _percent(row['win_pct']),
                          _cell(row['srs']),
                          _cell(row['net_rtg']),
                        ],
                    ],
                  ),
                ],
        ),
      ],
    );
  }

  Widget _gameDossier(Map<String, dynamic> row) {
    final item = _watchItem('game', row);
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          _keyValues({
            'Date': row['game_date'],
            'Season': row['season_id'],
            'League': row['league_id'],
            'Segment': row['season_type'],
            'Away score': row['away_score'],
            'Home score': row['home_score'],
            'Game key': row['game_key'],
          }),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _activateHistorical(
              season: item.season,
              league: item.league,
              seasonType: item.seasonType,
              gameKey: item.key,
              destination: 'history',
            ),
            icon: const Icon(Icons.history_edu_rounded),
            label: const Text('Activate game & open Historical Intelligence'),
          ),
        ],
      ),
    );
  }

  Widget _watchlistDesk() {
    return FutureBuilder<List<NbaEntityWatchItem>>(
      future: _watchlistFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <NbaEntityWatchItem>[];
        if (items.isEmpty) {
          return const _Empty(
            icon: Icons.push_pin_outlined,
            title: 'No watched NBA objects',
            detail:
                'Pin players, teams, franchises, seasons and games from Entity Search to build a persistent working set.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _Box(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENTITY WATCHLIST',
                          style: TextStyle(color: _text, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Persistent local working set · up to 100 canonical objects',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _watchlist.clear();
                      if (!mounted) return;
                      setState(() {
        _watchlistFuture = _watchlist.load();
      });
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            for (final item in items)
              Card(
                color: _panel,
                child: ListTile(
                  leading: Icon(_kindIcon(item.kind), color: _gold),
                  title: Text(
                    item.label,
                    style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [
                      item.kind.toUpperCase(),
                      item.subtitle,
                      if (item.season.isNotEmpty) item.season,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                  onTap: () => _openWatchItem(item),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    onPressed: () async {
                      await _watchlist.remove(item.signature);
                      if (!mounted) return;
                      setState(() {
        _watchlistFuture = _watchlist.load();
      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _seasonDesk() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: _panel,
          padding: const EdgeInsets.all(11),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _seasonController,
                  onSubmitted: (_) => _refreshSeason(),
                  style: const TextStyle(color: _text),
                  decoration: const InputDecoration(
                    labelText: 'Season',
                    hintText: '1995-96',
                    isDense: true,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _seasonLeague,
                items: const [
                  DropdownMenuItem(value: 'NBA', child: Text('NBA')),
                  DropdownMenuItem(value: 'ABA', child: Text('ABA')),
                  DropdownMenuItem(value: 'BAA', child: Text('BAA')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _seasonLeague = value);
                  _refreshSeason();
                },
              ),
              DropdownButton<String>(
                value: _seasonType,
                items: const [
                  DropdownMenuItem(value: 'regular', child: Text('Regular')),
                  DropdownMenuItem(value: 'playoffs', child: Text('Playoffs')),
                  DropdownMenuItem(value: 'combined', child: Text('Combined')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _seasonType = value);
                  _refreshSeason();
                },
              ),
              FilledButton.icon(
                onPressed: _refreshSeason,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Load'),
              ),
              OutlinedButton.icon(
                onPressed: () => _activateHistorical(
                  season: _seasonController.text.trim(),
                  league: _seasonLeague,
                  seasonType: _seasonType,
                  destination: 'stats',
                ),
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('Stats'),
              ),
              OutlinedButton.icon(
                onPressed: () => _activateHistorical(
                  season: _seasonController.text.trim(),
                  league: _seasonLeague,
                  seasonType: _seasonType,
                  destination: 'analytics',
                ),
                icon: const Icon(Icons.analytics_outlined, size: 16),
                label: const Text('Analytics'),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _line),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _seasonFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Empty(
                  icon: Icons.error_outline_rounded,
                  title: 'Season command unavailable',
                  detail: snapshot.error.toString(),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(14),
                children: [_seasonSummary(snapshot.data ?? const {})],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _seasonSummary(
    Map<String, dynamic> payload, {
    bool compact = false,
  }) {
    final season = _map(payload['season']);
    final summary = _map(payload['summary']);
    final teams = _list(payload['teams']);
    final leaders = _map(payload['leaders']);
    final awards = _list(payload['awards']);
    final allStar = _list(payload['all_star']);
    final draft = _list(payload['draft']);
    final coverage = _list(payload['coverage']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Box(
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: _gold, size: 30),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${season['label'] ?? season['season_id'] ?? _seasonController.text} · ${payload['league'] ?? _seasonLeague}',
                      style: const TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${payload['season_type'] ?? _seasonType} · canonical historical season command',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (compact)
                IconButton(
                  tooltip: 'Open Season Desk',
                  onPressed: () {
                    _seasonController.text = season['season_id']?.toString() ?? '';
                    setState(() {
                      _seasonLeague = payload['league']?.toString() ?? 'NBA';
                      _seasonType = payload['season_type']?.toString() ?? 'regular';
                      _seasonFuture = Future.value(payload);
                      _tab = _EntityDeskTab.season;
                    });
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _metricRow({
          'Teams': summary['teams'],
          'Players': summary['players'],
          'Games': summary['games'],
          'Awards': summary['award_rows'],
          'All-Star': summary['all_star_rows'],
          'Coverage': summary['coverage_domains'],
        }),
        const SizedBox(height: 11),
        _section(
          'TEAM TABLE',
          teams.isEmpty
              ? const [Text('No canonical team-season rows.', style: TextStyle(color: _muted))]
              : [
                  _table(
                    const ['#', 'Team', 'W', 'L', 'Win%', 'PTS', 'Opp PTS', 'Pace', 'ORtg', 'DRtg', 'Net', 'SRS'],
                    [
                      for (final row in teams)
                        [
                          _cell(row['rank']),
                          _cell(row['canonical_team_name'] ?? row['team_name'] ?? row['team_abbreviation']),
                          _cell(row['wins']),
                          _cell(row['losses']),
                          _percent(row['win_pct']),
                          _cell(row['pts']),
                          _cell(row['opp_pts']),
                          _cell(row['pace']),
                          _cell(row['ortg']),
                          _cell(row['drtg']),
                          _cell(row['net_rtg']),
                          _cell(row['srs']),
                        ],
                    ],
                  ),
                ],
        ),
        const SizedBox(height: 11),
        _section(
          'LEAGUE LEADERS',
          [
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final metric in const ['pts', 'reb', 'ast', 'stl', 'blk', 'ws', 'bpm'])
                  _LeaderCard(metric: metric, rows: _list(leaders[metric])),
              ],
            ),
          ],
        ),
        const SizedBox(height: 11),
        _section(
          'HONORS · ALL-STAR · DRAFT',
          [
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final row in awards.take(40))
                  _Info('${row['award'] ?? 'Award'} · ${row['player_name'] ?? ''}'),
                for (final row in allStar.take(40))
                  _Info('All-Star · ${row['player_name'] ?? ''}'),
                for (final row in draft.take(30))
                  _Info('Draft #${_fmt(row['pick_number'])} · ${row['player_name'] ?? ''}'),
                if (awards.isEmpty && allStar.isEmpty && draft.isEmpty)
                  const Text(
                    'No honors/draft rows are available for this season in the current source set.',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 11),
        _section(
          'DATA COVERAGE',
          [
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final row in coverage)
                  _Info(
                    '${row['domain'] ?? ''} · ${row['row_count'] ?? 0} rows · ${row['source_count'] ?? 0} sources',
                  ),
                if (coverage.isEmpty)
                  const Text('No coverage rows.', style: TextStyle(color: _muted, fontSize: 10)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricRow(Map<String, dynamic> metrics) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in metrics.entries)
          Container(
            constraints: const BoxConstraints(minWidth: 105),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _panel,
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmt(entry.value),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => _Box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _gold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 9),
            ...children,
          ],
        ),
      );

  Widget _table(List<String> headers, List<List<Widget>> rows) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 40,
          columns: [for (final header in headers) DataColumn(label: Text(header))],
          rows: [
            for (final row in rows)
              DataRow(cells: [for (final widget in row) DataCell(widget)]),
          ],
        ),
      );

  Widget _keyValues(Map<String, dynamic> values) => Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final entry in values.entries)
            SizedBox(
              width: 240,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      entry.key,
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _fmt(entry.value),
                      style: const TextStyle(
                        color: _text,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _seasonLink(dynamic value, VoidCallback onPressed) => TextButton(
        onPressed: onPressed,
        child: Text(value?.toString() ?? '—'),
      );

  static Widget _cell(dynamic value) => Text(
        _fmt(value),
        style: const TextStyle(color: _text, fontSize: 10),
      );

  static Widget _percent(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return Text(
      parsed == null ? '—' : '${(parsed * 100).toStringAsFixed(1)}%',
      style: const TextStyle(color: _text, fontSize: 10),
    );
  }

  static String _fmt(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';
    if (value is double) {
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.abs() >= 100
          ? value.toStringAsFixed(1)
          : value.toStringAsFixed(2);
    }
    return value.toString();
  }

  static IconData _kindIcon(String kind) => switch (kind) {
        'player' => Icons.person_rounded,
        'team' => Icons.groups_rounded,
        'franchise' => Icons.account_tree_rounded,
        'season' => Icons.calendar_month_rounded,
        'game' => Icons.sports_basketball_rounded,
        _ => Icons.badge_outlined,
      };

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : const {};

  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? [
          for (final item in value)
            if (item is Map)
              item.map((key, entry) => MapEntry(key.toString(), entry)),
        ]
      : const [];
}

class _EntitySearchTile extends StatelessWidget {
  const _EntitySearchTile({
    required this.kind,
    required this.row,
    required this.onOpen,
    required this.onWatch,
  });

  final String kind;
  final Map<String, dynamic> row;
  final VoidCallback onOpen;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      'player' => row['canonical_name']?.toString() ?? 'Player',
      'team' => row['canonical_name']?.toString() ?? 'Team',
      'franchise' => row['canonical_name']?.toString() ?? 'Franchise',
      'season' => row['label']?.toString() ?? row['season_id']?.toString() ?? 'Season',
      'game' => '${row['away_team_name'] ?? 'Away'} @ ${row['home_team_name'] ?? 'Home'}',
      _ => kind,
    };
    final subtitle = switch (kind) {
      'player' => '${row['primary_position'] ?? ''} · ${row['first_stat_season'] ?? '?'}–${row['last_stat_season'] ?? '?'}',
      'team' => '${row['abbreviation'] ?? ''} · ${row['franchise_name'] ?? ''}',
      'franchise' => '${row['first_season'] ?? '?'}–${row['last_season'] ?? '?'} · ${row['team_identities'] ?? 0} identities',
      'season' => '${row['teams'] ?? 0} teams · ${row['players'] ?? 0} players · ${row['games'] ?? 0} games',
      'game' => '${row['game_date'] ?? ''} · ${row['season_id'] ?? ''} · ${row['away_score'] ?? '—'}–${row['home_score'] ?? '—'}',
      _ => '',
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: _panel2,
      child: ListTile(
        dense: true,
        leading: Icon(
          _ProductNbaEntityCommandCenterScreenState._kindIcon(kind),
          color: _blue,
          size: 19,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _text,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 9),
        ),
        onTap: onOpen,
        trailing: IconButton(
          tooltip: 'Watch',
          onPressed: onWatch,
          icon: const Icon(Icons.push_pin_outlined, size: 17),
        ),
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.metric, required this.rows});

  final String metric;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Container(
        width: 270,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _panel2,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.toUpperCase(),
              style: const TextStyle(
                color: _gold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            for (final row in rows.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${row['rank'] ?? ''}',
                        style: const TextStyle(color: _muted, fontSize: 9),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${row['player_name'] ?? ''} · ${row['team_abbreviation'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _ProductNbaEntityCommandCenterScreenState._fmt(row['value']),
                      style: const TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            if (rows.isEmpty)
              const Text('No eligible values.', style: TextStyle(color: _muted, fontSize: 9)),
          ],
        ),
      );
}

class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );
}

class _Info extends StatelessWidget {
  const _Info(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _panel2,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _text,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: _muted),
                const SizedBox(height: 11),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
