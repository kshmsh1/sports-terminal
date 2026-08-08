import 'package:flutter/material.dart';

import '../services/historical_nba_research_repository.dart';
import '../services/nba_entity_intelligence_repository.dart';
import '../services/nba_entity_watchlist_store.dart';
import '../services/nba_research_context_store.dart';

const _ecBg = Color(0xFF08111C);
const _ecPanel = Color(0xFF111D2A);
const _ecPanel2 = Color(0xFF192738);
const _ecLine = Color(0xFF314257);
const _ecText = Color(0xFFF4F7FB);
const _ecMuted = Color(0xFF9EABBA);
const _ecGold = Color(0xFFFFCB45);
const _ecBlue = Color(0xFF66B5FF);
const _ecGreen = Color(0xFF65E3A5);
const _ecOrange = Color(0xFFFF9A5A);
const _ecRed = Color(0xFFFF7B7B);

enum _EntityDeskTab { discover, watchlist, seasonDesk }

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
  final NbaEntityIntelligenceRepository _entities =
      const NbaEntityIntelligenceRepository();
  final NbaEntityWatchlistStore _watchStore = const NbaEntityWatchlistStore();
  final NbaResearchContextStore _contexts = const NbaResearchContextStore();
  final HistoricalNbaResearchRepository _research =
      const HistoricalNbaResearchRepository();
  final TextEditingController _searchController = TextEditingController();

  _EntityDeskTab _tab = _EntityDeskTab.discover;
  String _league = 'ALL';
  bool _searching = false;
  String _searchError = '';
  Map<String, dynamic> _searchPayload = const {};
  Map<String, dynamic>? _selected;
  String _selectedKind = '';
  Future<Map<String, dynamic>>? _dossierFuture;
  late Future<NbaResearchContext> _contextFuture;
  late Future<List<NbaEntityWatchItem>> _watchFuture;

  String _season = '2024-25';
  String _seasonLeague = 'NBA';
  String _seasonType = 'regular';
  Future<Map<String, dynamic>>? _seasonFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _contexts.load();
    _watchFuture = _watchStore.load();
    _seasonFuture = _entities.seasonCommand(
      _season,
      league: _seasonLeague,
      seasonType: _seasonType,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final payload = await _entities.search(query, league: _league);
      if (!mounted) return;
      setState(() {
        _searchPayload = payload;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = error.toString();
        _searchPayload = const {};
      });
    }
  }

  Future<void> _openEntity(String kind, Map<String, dynamic> row) async {
    final normalized = kind.toLowerCase();
    setState(() {
      _selectedKind = normalized;
      _selected = row;
      _dossierFuture = switch (normalized) {
        'player' => _entities.playerDossier(
            row['player_key']?.toString() ?? '',
            league: _league,
          ),
        'team' => _entities.teamDossier(
            row['team_key']?.toString() ?? '',
            league: _league,
          ),
        'franchise' => _entities.franchiseDossier(
            row['franchise_key']?.toString() ?? '',
            league: _league,
          ),
        'season' => _entities.seasonCommand(
            row['season_id']?.toString() ?? '',
            league: _league == 'ALL' ? 'NBA' : _league,
          ),
        _ => Future.value({'kind': normalized, 'profile': row}),
      };
    });
  }

  Future<void> _pinSelected() async {
    final row = _selected;
    if (row == null || _selectedKind.isEmpty) return;
    final item = _watchItemFor(_selectedKind, row);
    await _watchStore.toggle(item);
    if (!mounted) return;
    setState(() => _watchFuture = _watchStore.load());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.label} watchlist status updated.')),
    );
  }

  NbaEntityWatchItem _watchItemFor(String kind, Map<String, dynamic> row) {
    switch (kind) {
      case 'player':
        return NbaEntityWatchItem(
          kind: kind,
          key: row['player_key']?.toString() ?? '',
          label: row['canonical_name']?.toString() ?? row['player_name']?.toString() ?? 'Player',
          subtitle: [
            row['primary_position']?.toString() ?? '',
            if (row['first_stat_season'] != null && row['last_stat_season'] != null)
              '${row['first_stat_season']}–${row['last_stat_season']}',
          ].where((value) => value.isNotEmpty).join(' · '),
          league: _league == 'ALL' ? 'NBA' : _league,
        );
      case 'team':
        return NbaEntityWatchItem(
          kind: kind,
          key: row['team_key']?.toString() ?? '',
          label: row['canonical_name']?.toString() ?? row['team_name']?.toString() ?? 'Team',
          subtitle: row['franchise_name']?.toString() ?? row['abbreviation']?.toString() ?? '',
          league: row['league_id']?.toString() ?? (_league == 'ALL' ? 'NBA' : _league),
        );
      case 'franchise':
        return NbaEntityWatchItem(
          kind: kind,
          key: row['franchise_key']?.toString() ?? '',
          label: row['canonical_name']?.toString() ?? 'Franchise',
          subtitle: '${row['first_season'] ?? ''}–${row['last_season'] ?? ''}',
          league: _league == 'ALL' ? 'NBA' : _league,
        );
      case 'season':
        return NbaEntityWatchItem(
          kind: kind,
          key: row['season_id']?.toString() ?? '',
          label: row['label']?.toString() ?? row['season_id']?.toString() ?? 'Season',
          subtitle: _league == 'ALL' ? 'NBA' : _league,
          season: row['season_id']?.toString() ?? '',
          league: _league == 'ALL' ? 'NBA' : _league,
        );
      case 'game':
        return NbaEntityWatchItem(
          kind: kind,
          key: row['game_key']?.toString() ?? '',
          label: '${row['away_team_name'] ?? 'Away'} @ ${row['home_team_name'] ?? 'Home'}',
          subtitle: '${row['game_date'] ?? ''} · ${row['season_id'] ?? ''}',
          season: row['season_id']?.toString() ?? '',
          league: row['league_id']?.toString() ?? 'NBA',
          seasonType: row['season_type']?.toString() ?? 'regular',
        );
      default:
        return NbaEntityWatchItem(kind: kind, key: kind, label: kind);
    }
  }

  Future<void> _openWatchItem(NbaEntityWatchItem item) async {
    setState(() => _tab = _EntityDeskTab.discover);
    switch (item.kind) {
      case 'player':
        await _openEntity('player', {'player_key': item.key, 'canonical_name': item.label});
      case 'team':
        await _openEntity('team', {'team_key': item.key, 'canonical_name': item.label});
      case 'franchise':
        await _openEntity('franchise', {'franchise_key': item.key, 'canonical_name': item.label});
      case 'season':
        setState(() {
          _season = item.season.isNotEmpty ? item.season : item.key;
          _seasonLeague = item.league;
          _seasonType = item.seasonType;
          _tab = _EntityDeskTab.seasonDesk;
          _seasonFuture = _entities.seasonCommand(
            _season,
            league: _seasonLeague,
            seasonType: _seasonType,
          );
        });
      case 'game':
        await _activateGame(item);
    }
  }

  Future<void> _activateGame(NbaEntityWatchItem item) async {
    if (item.season.isEmpty) return;
    final active = await _contexts.activateHistorical(
      season: item.season,
      league: item.league,
      seasonType: item.seasonType,
      gameKey: item.key,
    );
    if (!mounted) return;
    setState(() => _contextFuture = Future.value(active));
    widget.onOpenHistoricalIntelligence?.call();
  }

  Future<void> _activateSeason({String destination = 'stay'}) async {
    final active = await _contexts.activateHistorical(
      season: _season,
      league: _seasonLeague,
      seasonType: _seasonType,
    );
    if (!mounted) return;
    setState(() => _contextFuture = Future.value(active));
    if (destination == 'stats') widget.onOpenStats?.call();
    if (destination == 'analytics') widget.onOpenAnalytics?.call();
  }

  Future<void> _activateDossierSeason(
    String season,
    String league,
    String seasonType, {
    String playerKey = '',
    String playerName = '',
    String teamKey = '',
    String teamName = '',
    String destination = 'stay',
  }) async {
    final active = await _contexts.activateHistorical(
      season: season,
      league: league.isEmpty ? 'NBA' : league,
      seasonType: seasonType.isEmpty ? 'regular' : seasonType,
      playerKey: playerKey,
      playerName: playerName,
      teamKey: teamKey,
      teamName: teamName,
    );
    if (!mounted) return;
    setState(() => _contextFuture = Future.value(active));
    if (destination == 'stats') widget.onOpenStats?.call();
    if (destination == 'analytics') widget.onOpenAnalytics?.call();
  }

  void _reloadSeason() {
    setState(() {
      _seasonFuture = _entities.seasonCommand(
        _season,
        league: _seasonLeague,
        seasonType: _seasonType,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _ecBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final height = constraints.hasBoundedHeight ? constraints.maxHeight : 980.0;
          return SizedBox(
            height: height,
            child: Column(
              children: [
                _header(compact),
                _contextStrip(),
                _tabs(),
                Expanded(
                  child: switch (_tab) {
                    _EntityDeskTab.discover => _discoverDesk(compact),
                    _EntityDeskTab.watchlist => _watchlistDesk(),
                    _EntityDeskTab.seasonDesk => _seasonDesk(),
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
        color: _ecPanel,
        border: Border(bottom: BorderSide(color: _ecLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_ecBlue, _ecGold]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub_rounded, color: Color(0xFF08111C)),
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
                    color: _ecText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Players · teams · franchises · seasons · games · honors · drafts · persistent watchlist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _ecMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (!compact) const _Tag('CANONICAL ENTITY GRAPH', _ecGold),
        ],
      ),
    );
  }

  Widget _contextStrip() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0B1724),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: FutureBuilder<NbaResearchContext>(
        future: _contextFuture,
        builder: (context, snapshot) {
          final active = snapshot.data;
          return Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 15, color: _ecBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  active == null
                      ? 'Loading shared NBA context…'
                      : 'ACTIVE · ${active.scopeLabel}${active.entityLabel.isEmpty ? '' : ' · ${active.entityLabel}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active?.historical == true ? _ecGold : _ecGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),
              ),
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

  Widget _tabs() {
    return Container(
      width: double.infinity,
      color: _ecPanel,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabButton(_EntityDeskTab.discover, 'Entity Search', Icons.manage_search_rounded),
            const SizedBox(width: 7),
            _tabButton(_EntityDeskTab.watchlist, 'Watchlist', Icons.push_pin_rounded),
            const SizedBox(width: 7),
            _tabButton(_EntityDeskTab.seasonDesk, 'Season Desk', Icons.calendar_view_month_rounded),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(_EntityDeskTab tab, String label, IconData icon) {
    return ChoiceChip(
      selected: _tab == tab,
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onSelected: (_) => setState(() => _tab = tab),
    );
  }

  Widget _discoverDesk(bool compact) {
    if (compact) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: 500, child: _searchPanel()),
          const Divider(height: 1, color: _ecLine),
          SizedBox(height: 720, child: _dossierPanel()),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 430, child: _searchPanel()),
        const VerticalDivider(width: 1, color: _ecLine),
        Expanded(child: _dossierPanel()),
      ],
    );
  }

  Widget _searchPanel() {
    final groups = _map(_searchPayload['groups']);
    return Container(
      color: _ecPanel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(color: _ecText),
                  decoration: InputDecoration(
                    hintText: 'Search player, team, franchise, season or game…',
                    hintStyle: const TextStyle(color: _ecMuted),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    filled: true,
                    fillColor: _ecPanel2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 9),
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
                  const SizedBox(height: 9),
                  Text(_searchError, style: const TextStyle(color: _ecRed, fontSize: 10)),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _ecLine),
          Expanded(
            child: groups.isEmpty
                ? const _EmptyState(
                    icon: Icons.manage_search_rounded,
                    title: 'Search the canonical NBA entity graph',
                    detail: 'One search spans players, teams, franchises, seasons and historical games.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                    children: [
                      _resultGroup('PLAYERS', 'player', _list(groups['players'])),
                      _resultGroup('TEAMS', 'team', _list(groups['teams'])),
                      _resultGroup('FRANCHISES', 'franchise', _list(groups['franchises'])),
                      _resultGroup('SEASONS', 'season', _list(groups['seasons'])),
                      _resultGroup('GAMES', 'game', _list(groups['games'])),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _resultGroup(String title, String kind, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: Text(
              '$title · ${rows.length}',
              style: const TextStyle(
                color: _ecMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ),
          for (final row in rows)
            _ResultTile(
              kind: kind,
              row: row,
              selected: identical(_selected, row),
              onTap: () => _openEntity(kind, row),
            ),
        ],
      ),
    );
  }

  Widget _dossierPanel() {
    if (_selected == null || _dossierFuture == null) {
      return const _EmptyState(
        icon: Icons.badge_outlined,
        title: 'Select an entity',
        detail: 'Open a canonical dossier, pin it to the watchlist, or make one of its seasons the shared terminal context.',
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _dossierFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Dossier unavailable',
            detail: snapshot.error.toString(),
          );
        }
        final payload = snapshot.data ?? const {};
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _dossierHeader(payload),
            const SizedBox(height: 12),
            if (_selectedKind == 'player') _playerDossier(payload),
            if (_selectedKind == 'team') _teamDossier(payload),
            if (_selectedKind == 'franchise') _franchiseDossier(payload),
            if (_selectedKind == 'season') _seasonSnapshot(payload),
            if (_selectedKind == 'game') _gameSnapshot(_selected ?? const {}),
          ],
        );
      },
    );
  }

  Widget _dossierHeader(Map<String, dynamic> payload) {
    final profile = _map(payload['profile']);
    final selected = _selected ?? const <String, dynamic>{};
    final label = profile['canonical_name']?.toString() ??
        selected['canonical_name']?.toString() ??
        selected['player_name']?.toString() ??
        selected['label']?.toString() ??
        selected['season_id']?.toString() ??
        'Historical entity';
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x223BA7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ecLine),
            ),
            child: Icon(_kindIcon(_selectedKind), color: _ecGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _ecText, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _selectedKind.toUpperCase(),
                  style: const TextStyle(color: _ecMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _pinSelected,
            icon: const Icon(Icons.push_pin_outlined, size: 16),
            label: const Text('Watch'),
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
    final games = _list(payload['recent_games']);
    final conflicts = _list(payload['conflicts']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricStrip({
          'Seasons': summary['season_rows'],
          'Awards': summary['awards'],
          'All-Star': summary['all_star_selections'],
          'Sources': profile['source_count'],
          'Conflicts': summary['material_conflicts'],
        }),
        const SizedBox(height: 12),
        _section('CAREER SEASONS', seasons.isEmpty ? const [_muted('No canonical season rows.')] : [
          _horizontalTable(
            headers: const ['Season', 'Lg', 'Team', 'G', 'PTS', 'REB', 'AST', 'TS%', 'WS', 'BPM'],
            rows: [
              for (final row in seasons)
                [
                  _seasonAction(
                    row['season_id']?.toString() ?? '',
                    () => _activateDossierSeason(
                      row['season_id']?.toString() ?? '',
                      row['league_id']?.toString() ?? 'NBA',
                      row['season_type']?.toString() ?? 'regular',
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
                  _pctCell(row['ts_pct']),
                  _cell(row['ws']),
                  _cell(row['bpm']),
                ],
            ],
          ),
        ]),
        const SizedBox(height: 12),
        _section('HONORS & DRAFT', [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final row in awards.take(24))
                _InfoChip('${row['season_id'] ?? ''} · ${row['award'] ?? 'Award'}'),
              for (final row in allStar.take(24))
                _InfoChip('${row['season_id'] ?? ''} · All-Star'),
              for (final row in draft)
                _InfoChip('Draft ${row['draft_year'] ?? ''} · Pick ${_fmt(row['pick_number'])} · ${row['drafting_team_text'] ?? ''}'),
              if (awards.isEmpty && allStar.isEmpty && draft.isEmpty)
                _muted('No canonical awards, All-Star or draft rows are available for this player.'),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        _section('RECENT AVAILABLE GAME LOG', [
          if (games.isEmpty)
            _muted('No canonical player-game coverage is available in the current warehouse.')
          else
            _horizontalTable(
              headers: const ['Date', 'Season', 'Team', 'Opponent', 'MIN', 'PTS', 'REB', 'AST'],
              rows: [
                for (final row in games)
                  [
                    _cell(row['game_date']),
                    _cell(row['season_id']),
                    _cell(row['team_abbreviation']),
                    _cell(row['opponent_abbreviation']),
                    _cell(row['minutes']),
                    _cell(row['pts']),
                    _cell(row['reb']),
                    _cell(row['ast']),
                  ],
              ],
            ),
        ]),
        const SizedBox(height: 12),
        _coverageNote(conflicts.length),
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
        _metricStrip({
          'Seasons': summary['seasons'],
          'First': summary['first_season'],
          'Last': summary['last_season'],
          'Sources': profile['source_count'],
          'Conflicts': summary['material_conflicts'],
        }),
        const SizedBox(height: 12),
        if (franchise.isNotEmpty)
          _section('FRANCHISE', [
            _keyValueGrid({
              'Canonical franchise': franchise['canonical_name'],
              'Current abbreviation': franchise['current_abbreviation'],
              'Franchise key': franchise['franchise_key'],
            }),
          ]),
        if (franchise.isNotEmpty) const SizedBox(height: 12),
        _section('TEAM-SEASON HISTORY', [
          if (seasons.isEmpty)
            _muted('No canonical team-season rows.')
          else
            _horizontalTable(
              headers: const ['Season', 'Lg', 'G', 'W', 'L', 'Win%', 'PTS', 'Opp PTS', 'SRS', 'Net Rtg'],
              rows: [
                for (final row in seasons)
                  [
                    _seasonAction(
                      row['season_id']?.toString() ?? '',
                      () => _activateDossierSeason(
                        row['season_id']?.toString() ?? '',
                        row['league_id']?.toString() ?? 'NBA',
                        row['season_type']?.toString() ?? 'regular',
                        teamKey: profile['team_key']?.toString() ?? '',
                        teamName: profile['canonical_name']?.toString() ?? '',
                        destination: 'analytics',
                      ),
                    ),
                    _cell(row['league_id']),
                    _cell(row['games']),
                    _cell(row['wins']),
                    _cell(row['losses']),
                    _pctCell(row['win_pct']),
                    _cell(row['pts']),
                    _cell(row['opp_pts']),
                    _cell(row['srs']),
                    _cell(row['net_rtg']),
                  ],
              ],
            ),
        ]),
        const SizedBox(height: 12),
        _section('LONG-TENURE / HIGH-VOLUME PLAYERS', [
          if (players.isEmpty)
            _muted('No canonical player-season rows linked to this team identity.')
          else
            _horizontalTable(
              headers: const ['Player', 'Seasons', 'Games', 'PTS', 'REB', 'AST', 'First', 'Last'],
              rows: [
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
        ]),
      ],
    );
  }

  Widget _franchiseDossier(Map<String, dynamic> payload) {
    final summary = _map(payload['summary']);
    final identities = _list(payload['team_identities']);
    final seasons = _list(payload['seasons']);
    return Column(
      children: [
        _metricStrip({
          'Team identities': summary['team_identities'],
          'Seasons': summary['seasons'],
          'First': summary['first_season'],
          'Last': summary['last_season'],
        }),
        const SizedBox(height: 12),
        _section('LINEAGE', [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final row in identities)
                _InfoChip('${row['canonical_name'] ?? ''} · ${row['abbreviation'] ?? ''} · ${row['active_from'] ?? '?'}–${row['active_to'] ?? '?'}'),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        _section('FRANCHISE SEASON HISTORY', [
          if (seasons.isEmpty)
            _muted('No linked canonical team-season rows.')
          else
            _horizontalTable(
              headers: const ['Season', 'Identity', 'Lg', 'W', 'L', 'Win%', 'SRS', 'Net Rtg'],
              rows: [
                for (final row in seasons)
                  [
                    _seasonAction(
                      row['season_id']?.toString() ?? '',
                      () => _activateDossierSeason(
                        row['season_id']?.toString() ?? '',
                        row['league_id']?.toString() ?? 'NBA',
                        row['season_type']?.toString() ?? 'regular',
                        teamKey: row['team_key']?.toString() ?? '',
                        teamName: row['canonical_team_name']?.toString() ?? '',
                        destination: 'analytics',
                      ),
                    ),
                    _cell(row['canonical_team_name']),
                    _cell(row['league_id']),
                    _cell(row['wins']),
                    _cell(row['losses']),
                    _pctCell(row['win_pct']),
                    _cell(row['srs']),
                    _cell(row['net_rtg']),
                  ],
              ],
            ),
        ]),
      ],
    );
  }

  Widget _seasonSnapshot(Map<String, dynamic> payload) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seasonSummaryBody(payload),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            final season = _map(payload['season'])['season_id']?.toString() ?? '';
            if (season.isEmpty) return;
            setState(() {
              _season = season;
              _seasonLeague = payload['league']?.toString() ?? 'NBA';
              _seasonType = payload['season_type']?.toString() ?? 'regular';
              _seasonFuture = Future.value(payload);
              _tab = _EntityDeskTab.seasonDesk;
            });
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open full Season Desk'),
        ),
      ],
    );
  }

  Widget _gameSnapshot(Map<String, dynamic> row) {
    final item = _watchItemFor('game', row);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: const TextStyle(color: _ecText, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          _keyValueGrid({
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
            onPressed: () => _activateGame(item),
            icon: const Icon(Icons.history_edu_rounded),
            label: const Text('Activate game & open Historical Intelligence'),
          ),
        ],
      ),
    );
  }

  Widget _watchlistDesk() {
    return FutureBuilder<List<NbaEntityWatchItem>>(
      future: _watchFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <NbaEntityWatchItem>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.push_pin_outlined,
            title: 'No watched NBA objects yet',
            detail: 'Pin players, teams, franchises, seasons and games from Entity Search to build a persistent research set.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _Panel(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ENTITY WATCHLIST', style: TextStyle(color: _ecText, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text('Persistent local working set · up to 100 canonical objects', style: TextStyle(color: _ecMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _watchStore.clear();
                      if (!mounted) return;
                      setState(() => _watchFuture = _watchStore.load());
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final item in items)
              Card(
                color: _ecPanel,
                child: ListTile(
                  leading: Icon(_kindIcon(item.kind), color: _ecGold),
                  title: Text(item.label, style: const TextStyle(color: _ecText, fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    [item.kind.toUpperCase(), item.subtitle, if (item.season.isNotEmpty) item.season]
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(color: _ecMuted, fontSize: 10),
                  ),
                  onTap: () => _openWatchItem(item),
                  trailing: IconButton(
                    tooltip: 'Remove from watchlist',
                    onPressed: () async {
                      await _watchStore.remove(item.signature);
                      if (!mounted) return;
                      setState(() => _watchFuture = _watchStore.load());
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
          color: _ecPanel,
          padding: const EdgeInsets.all(11),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: _season,
                  style: const TextStyle(color: _ecText),
                  decoration: const InputDecoration(labelText: 'Season', isDense: true),
                  onChanged: (value) => _season = value.trim(),
                  onFieldSubmitted: (_) => _reloadSeason(),
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
                  _reloadSeason();
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
                  _reloadSeason();
                },
              ),
              FilledButton.icon(
                onPressed: _reloadSeason,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Load'),
              ),
              OutlinedButton.icon(
                onPressed: () => _activateSeason(destination: 'stats'),
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('Open in Stats'),
              ),
              OutlinedButton.icon(
                onPressed: () => _activateSeason(destination: 'analytics'),
                icon: const Icon(Icons.analytics_outlined, size: 16),
                label: const Text('Open in Analytics'),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _ecLine),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _seasonFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Season command unavailable',
                  detail: snapshot.error.toString(),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(14),
                children: [_seasonSummaryBody(snapshot.data ?? const {})],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _seasonSummaryBody(Map<String, dynamic> payload) {
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
        _Panel(
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: _ecGold, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${season['label'] ?? season['season_id'] ?? _season} · ${payload['league'] ?? _seasonLeague}',
                      style: const TextStyle(color: _ecText, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${payload['season_type'] ?? _seasonType} · canonical historical season command',
                      style: const TextStyle(color: _ecMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _metricStrip({
          'Teams': summary['teams'],
          'Players': summary['players'],
          'Games': summary['games'],
          'Awards': summary['award_rows'],
          'All-Star': summary['all_star_rows'],
          'Coverage': summary['coverage_domains'],
        }),
        const SizedBox(height: 12),
        _section('TEAM TABLE', [
          if (teams.isEmpty)
            _muted('No canonical team-season rows are available for this league/segment.')
          else
            _horizontalTable(
              headers: const ['#', 'Team', 'W', 'L', 'Win%', 'PTS', 'Opp PTS', 'Pace', 'ORtg', 'DRtg', 'Net', 'SRS'],
              rows: [
                for (final row in teams)
                  [
                    _cell(row['rank']),
                    _cell(row['canonical_team_name'] ?? row['team_name'] ?? row['team_abbreviation']),
                    _cell(row['wins']),
                    _cell(row['losses']),
                    _pctCell(row['win_pct']),
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
        ]),
        const SizedBox(height: 12),
        _section('LEAGUE LEADERS', [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final metric in const ['pts', 'reb', 'ast', 'stl', 'blk', 'ws', 'bpm'])
                _leaderCard(metric, _list(leaders[metric])),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        _section('HONORS · ALL-STAR · DRAFT', [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final row in awards.take(40))
                _InfoChip('${row['award'] ?? 'Award'} · ${row['player_name'] ?? ''}'),
              for (final row in allStar.take(40))
                _InfoChip('All-Star · ${row['player_name'] ?? ''}'),
              for (final row in draft.take(30))
                _InfoChip('Draft #${_fmt(row['pick_number'])} · ${row['player_name'] ?? ''}'),
              if (awards.isEmpty && allStar.isEmpty && draft.isEmpty)
                _muted('No honors/draft rows are available for this historical season in the current source set.'),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        _section('DATA COVERAGE', [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final row in coverage)
                _InfoChip('${row['domain'] ?? ''} · ${row['row_count'] ?? 0} rows · ${row['source_count'] ?? 0} sources'),
              if (coverage.isEmpty)
                _muted('No canonical coverage rows are available for this season/league.'),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _leaderCard(String metric, List<Map<String, dynamic>> rows) {
    return Container(
      width: 270,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _ecPanel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ecLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.toUpperCase(), style: const TextStyle(color: _ecGold, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          for (final row in rows.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text('${row['rank'] ?? ''}', style: const TextStyle(color: _ecMuted, fontSize: 9))),
                  Expanded(
                    child: Text(
                      '${row['player_name'] ?? ''} · ${row['team_abbreviation'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ecText, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(_fmt(row['value']), style: const TextStyle(color: _ecGreen, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          if (rows.isEmpty) _muted('No eligible values.'),
        ],
      ),
    );
  }

  Widget _metricStrip(Map<String, dynamic> metrics) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in metrics.entries)
          Container(
            constraints: const BoxConstraints(minWidth: 110),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _ecPanel,
              border: Border.all(color: _ecLine),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key.toUpperCase(), style: const TextStyle(color: _ecMuted, fontSize: 8, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(_fmt(entry.value), style: const TextStyle(color: _ecText, fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _ecGold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _horizontalTable({required List<String> headers, required List<List<Widget>> rows}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 34,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 40,
        columns: [for (final header in headers) DataColumn(label: Text(header))],
        rows: [
          for (final row in rows)
            DataRow(cells: [for (final cell in row) DataCell(cell)]),
        ],
      ),
    );
  }

  Widget _keyValueGrid(Map<String, dynamic> values) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final entry in values.entries)
          SizedBox(
            width: 230,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 105, child: Text(entry.key, style: const TextStyle(color: _ecMuted, fontSize: 9))),
                Expanded(child: Text(_fmt(entry.value), style: const TextStyle(color: _ecText, fontSize: 10, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _coverageNote(int conflicts) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(conflicts > 0 ? Icons.warning_amber_rounded : Icons.verified_outlined, color: conflicts > 0 ? _ecOrange : _ecGreen, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              conflicts > 0
                  ? '$conflicts material canonical identity conflicts are preserved for review. Source disagreements are not silently discarded.'
                  : 'No material canonical identity conflicts are currently recorded for this entity. Missing-era fields still remain explicitly missing.',
              style: const TextStyle(color: _ecMuted, fontSize: 10, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _muted(String text) => Text(text, style: const TextStyle(color: _ecMuted, fontSize: 10));
  static Widget _cell(dynamic value) => Text(_fmt(value), style: const TextStyle(color: _ecText, fontSize: 10));
  static Widget _pctCell(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
    return Text(number == null ? '—' : '${(number * 100).toStringAsFixed(1)}%', style: const TextStyle(color: _ecText, fontSize: 10));
  }

  Widget _seasonAction(String season, VoidCallback onTap) => TextButton(
        onPressed: season.isEmpty ? null : onTap,
        child: Text(season.isEmpty ? '—' : season),
      );

  static String _fmt(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';
    if (value is double) {
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.abs() >= 100 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
    }
    if (value is num) return value.toString();
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

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.kind,
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final String kind;
  final Map<String, dynamic> row;
  final bool selected;
  final VoidCallback onTap;

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
      color: selected ? const Color(0xFF22354A) : _ecPanel2,
      child: ListTile(
        dense: true,
        leading: Icon(_ProductNbaEntityCommandCenterScreenState._kindIcon(kind), color: selected ? _ecGold : _ecBlue, size: 19),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ecText, fontSize: 11, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ecMuted, fontSize: 9)),
        onTap: onTap,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _ecPanel,
          border: Border.all(color: _ecLine),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _ecPanel2,
          border: Border.all(color: _ecLine),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: const TextStyle(color: _ecText, fontSize: 9, fontWeight: FontWeight.w700)),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
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
        child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .6)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.detail});
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
                Icon(icon, size: 44, color: _ecMuted),
                const SizedBox(height: 12),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _ecText, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _ecMuted, fontSize: 10, height: 1.4)),
              ],
            ),
          ),
        ),
      );
}
