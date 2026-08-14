import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/historical_nba_research_repository.dart';
import '../services/nba_entity_intelligence_repository.dart';
import '../services/nba_research_context_store.dart';
import '../services/nba_terminal_command_engine.dart';
import '../services/nba_terminal_repository.dart';
import '../services/nba_terminal_state_store.dart';
import '../widgets/nba_game_navigation.dart';
import 'product_analytics_suite_screen.dart';
import 'product_automation_governance_screen.dart';
import 'product_connected_data_studio_screen.dart';
import 'product_connected_network_screens.dart';
import 'product_connected_transaction_screens.dart';
import 'product_connected_workspace_screen.dart';
import 'product_content_ops_screens.dart';
import 'product_fantasy_community_screens.dart';
import 'product_front_office_registry_screen.dart';
import 'product_nba_entity_command_center_screen.dart';
import 'product_nba_historical_intelligence_screen.dart';
import 'product_nba_public_pages_screen.dart';
import 'product_nba_research_command_center_screen.dart';
import 'product_nba_stats_center_screen.dart';
import 'product_nba_universe_screen.dart';
import 'product_profile_persisted_screen.dart';
import 'product_transaction_command_center_screen.dart';

const _tBg = Color(0xFF090D12);
const _tPanel = Color(0xFF0F151C);
const _tPanel2 = Color(0xFF141C25);
const _tLine = Color(0xFF263342);
const _tText = Color(0xFFE8EDF3);
const _tMuted = Color(0xFF8895A5);
const _tGold = Color(0xFF63A9FF);
const _tBlue = Color(0xFF8BC1FF);
const _tGreen = Color(0xFF69C99A);
const _tOrange = Color(0xFFE2B866);

class ProductNbaTerminalScreen extends StatefulWidget {
  const ProductNbaTerminalScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductNbaTerminalScreen> createState() => _ProductNbaTerminalScreenState();
}

enum _TerminalDesk { command, seasons, coverage, context, completion }

class _ProductNbaTerminalScreenState extends State<ProductNbaTerminalScreen> {
  static const _engine = NbaTerminalCommandEngine();
  static const _terminal = NbaTerminalRepository();
  static const _entities = NbaEntityIntelligenceRepository();
  static const _history = HistoricalNbaResearchRepository();
  static const _contexts = NbaResearchContextStore();
  static const _stateStore = NbaTerminalStateStore();

  final TextEditingController _query = TextEditingController();
  final TextEditingController _seasonQuery = TextEditingController();

  _TerminalDesk _desk = _TerminalDesk.command;
  String _league = 'NBA';
  bool _searching = false;
  String _searchError = '';
  Map<String, dynamic> _entitySearch = const {};
  List<NbaTerminalCommandMatch> _commandMatches = const [];
  late Future<Map<String, dynamic>> _manifestFuture;
  late Future<Map<String, dynamic>> _seasonsFuture;
  late Future<NbaResearchContext> _contextFuture;
  late Future<List<NbaResearchContext>> _recentContextsFuture;
  late Future<NbaTerminalState> _terminalStateFuture;

  bool get _organizationMode => widget.session.role.canManageOrganization;

  @override
  void initState() {
    super.initState();
    _commandMatches = _engine.search('', organizationMode: _organizationMode);
    _manifestFuture = _terminal.manifest();
    _seasonsFuture = _terminal.seasons(league: _league, limit: 100);
    _contextFuture = _contexts.load();
    _recentContextsFuture = _contexts.recent();
    _terminalStateFuture = _stateStore.load();
  }

  @override
  void dispose() {
    _query.dispose();
    _seasonQuery.dispose();
    super.dispose();
  }

  void _refreshAll() {
    setState(() {
      _manifestFuture = _terminal.manifest();
      _seasonsFuture = _terminal.seasons(
        league: _league,
        query: _seasonQuery.text.trim(),
        limit: 100,
      );
      _contextFuture = _contexts.load();
      _recentContextsFuture = _contexts.recent();
      _terminalStateFuture = _stateStore.load();
    });
  }

  Future<void> _runSearch() async {
    final query = _query.text.trim();
    setState(() {
      _commandMatches = _engine.search(
        query,
        organizationMode: _organizationMode,
        limit: 20,
      );
      _searchError = '';
      _searching = query.length >= 2;
      if (query.length < 2) _entitySearch = const {};
    });
    if (query.isNotEmpty) {
      await _stateStore.recordQuery(query);
      if (mounted) {
        setState(() {
          _terminalStateFuture = _stateStore.load();
        });
      }
    }
    if (query.length < 2) return;
    try {
      final payload = await _entities.search(query, limitPerKind: 12);
      if (!mounted) return;
      setState(() {
        _entitySearch = payload;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = error.toString();
        _entitySearch = const {};
      });
    }
  }

  Future<void> _openCommand(NbaTerminalCommand command) async {
    final next = await _stateStore.recordCommand(command.id);
    if (mounted) {
      setState(() {
        _terminalStateFuture = Future.value(next);
      });
    }
    if (!mounted) return;
    switch (command.id) {
      case 'terminal':
        setState(() => _desk = _TerminalDesk.command);
        return;
      case 'stats':
        return _showTool('Stats Workstation', const ProductNbaStatsCenterScreen());
      case 'analytics':
        return _showTool('Analytics Suite', const ProductAnalyticsSuiteScreen());
      case 'history':
        return _showTool(
          'NBA Historical Intelligence',
          const ProductNbaHistoricalIntelligenceScreen(),
        );
      case 'entity':
        return _showTool(
          'NBA Entity & Season Intelligence',
          const ProductNbaEntityCommandCenterScreen(),
        );
      case 'universe':
        return _showTool('NBA Universe', const ProductNbaUniverseScreen());
      case 'research':
        return _showTool(
          'NBA Research Command Center',
          ProductNbaResearchCommandCenterScreen(session: widget.session),
        );
      case 'trade':
        return _showTool(
          'Trade Machine',
          ProductConnectedTradeMachineScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
          scroll: true,
        );
      case 'front-office':
        return _showTool(
          'Front Office',
          ProductConnectedFrontOfficeScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
          scroll: true,
        );
      case 'contracts':
        return _showTool(
          'Contracts & Assets',
          ProductFrontOfficeRegistryScreen(session: widget.session),
          scroll: true,
        );
      case 'transactions':
        return _showTool(
          'Transaction Command Center',
          ProductTransactionCommandCenterScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
          scroll: true,
        );
      case 'workspace':
        return _showTool(
          'Workspace',
          ProductConnectedWorkspaceScreen(session: widget.session),
          scroll: true,
        );
      case 'python':
        return _showTool(
          'Python Lab',
          ProductConnectedDataStudioScreen(session: widget.session),
          scroll: true,
        );
      case 'automation':
        return _showTool(
          _organizationMode ? 'Organization Control Plane' : 'Automation Center',
          ProductAutomationGovernanceScreen(session: widget.session),
          scroll: true,
        );
      case 'organization':
        if (_organizationMode) {
          return _showTool(
            'Organization Admin',
            ProductAdminOpsCenterScreen(session: widget.session),
            scroll: true,
          );
        }
        return;
      case 'trust':
        if (_organizationMode) {
          return _showTool(
            'Trust & Safety',
            ProductTrustSafetyConsoleScreen(session: widget.session),
            scroll: true,
          );
        }
        return;
      case 'community':
        return _showTool(
          'Community',
          ProductConnectedCommunityScreen(session: widget.session),
          scroll: true,
        );
      case 'messages':
        return _showTool(
          'Messages',
          ProductConnectedMessagesScreen(session: widget.session),
          scroll: true,
        );
      case 'fantasy':
        return _showTool('Fantasy War Room', const ProductFantasyWarRoomScreen(), scroll: true);
      case 'profile':
        return _showTool(
          'Profile & Preferences',
          ProductPersistedProfileScreen(session: widget.session),
          scroll: true,
        );
    }
  }

  Future<void> _showTool(String title, Widget body, {bool scroll = false}) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: _tBg,
          appBar: AppBar(
            backgroundColor: _tPanel,
            foregroundColor: Colors.white,
            title: Text(title),
            leading: IconButton(
              tooltip: 'Back to NBA Terminal',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh terminal when returning',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _refreshAll();
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          // Routed product surfaces own their scrolling and flex layout. Wrapping
          // a full-screen destination in an outer SingleChildScrollView gives its
          // Expanded/Flexible descendants unbounded height and breaks debug layout.
          body: scroll
              ? Padding(
                  padding: const EdgeInsets.all(22),
                  child: body,
                )
              : body,
        ),
      ),
    );
  }

  Future<void> _inspectEntity(String kind, Map<String, dynamic> row) async {
    final key = switch (kind) {
      'player' => row['player_key']?.toString() ?? '',
      'team' => row['team_key']?.toString() ?? '',
      'franchise' => row['franchise_key']?.toString() ?? '',
      'season' => row['season_id']?.toString() ?? '',
      'game' => row['game_key']?.toString() ?? '',
      _ => '',
    };
    if (key.isEmpty) return;
    late Future<Map<String, dynamic>> future;
    switch (kind) {
      case 'player':
        future = _entities.playerDossier(key);
      case 'team':
        future = _entities.teamDossier(key);
      case 'franchise':
        future = _entities.franchiseDossier(key);
      case 'season':
        future = _entities.seasonCommand(key, league: _league);
      case 'game':
        future = _history.game(key);
      default:
        return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: _tPanel,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
          child: FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load $kind dossier: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              return _EntityPreview(
                kind: kind,
                row: row,
                payload: snapshot.data!,
                onActivate: () async {
                  await _activateEntity(kind, row);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  if (kind == 'game' && mounted) {
                    final away = (row['away_team_name'] ??
                            row['away_team_id'] ??
                            'Away')
                        .toString();
                    final home = (row['home_team_name'] ??
                            row['home_team_id'] ??
                            'Home')
                        .toString();
                    await openNbaGamePage(
                      this.context,
                      gameId: key,
                      gameLabel: '$away @ $home',
                      onOpenTeam: (teamId) =>
                          openNbaTeamPage(this.context, teamId, teamId),
                      onOpenPlayer: (playerId, playerName) =>
                          openNbaPlayerPage(
                        this.context,
                        playerId,
                        playerName,
                      ),
                    );
                  }
                  if (kind == 'season' && mounted) {
                    await _openHistoricalSeason(row, seasonId: key);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _activateEntity(String kind, Map<String, dynamic> row) async {
    final season = (row['season_id'] ?? row['last_stat_season'] ?? row['last_season'] ?? '').toString();
    if (season.isEmpty) return;
    final league = (row['league_id'] ?? _league).toString();
    await _contexts.activateHistorical(
      season: season,
      league: league.isEmpty ? 'NBA' : league,
      seasonType: (row['season_type'] ?? 'regular').toString(),
      playerKey: kind == 'player' ? row['player_key']?.toString() ?? '' : '',
      playerName: kind == 'player'
          ? row['canonical_name']?.toString() ?? row['player_name']?.toString() ?? ''
          : '',
      teamKey: kind == 'team' ? row['team_key']?.toString() ?? '' : '',
      teamName: kind == 'team'
          ? row['canonical_name']?.toString() ?? row['team_name']?.toString() ?? ''
          : '',
      gameKey: kind == 'game' ? row['game_key']?.toString() ?? '' : '',
    );
    if (!mounted) return;
    setState(() {
      _contextFuture = _contexts.load();
      _recentContextsFuture = _contexts.recent();
    });
  }

  Future<void> _activateSeason(Map<String, dynamic> row) async {
    final season = row['season_id']?.toString() ?? '';
    if (season.isEmpty) return;
    await _contexts.activateHistorical(
      season: season,
      league: _league,
      seasonType: (row['season_type'] ?? 'regular').toString(),
    );
    if (!mounted) return;
    setState(() {
      _contextFuture = _contexts.load();
      _recentContextsFuture = _contexts.recent();
    });
    await _openHistoricalSeason(row, seasonId: season);
  }

  Future<void> _openHistoricalSeason(
    Map<String, dynamic> row, {
    required String seasonId,
  }) {
    final league = (row['league_id'] ?? _league).toString().trim();
    final seasonType = (row['season_type'] ?? 'regular').toString().trim();
    return openHistoricalNbaSeasonPage(
      context,
      seasonId: seasonId,
      league: league.isEmpty ? 'NBA' : league,
      seasonType: seasonType.isEmpty ? 'regular' : seasonType,
      onOpenTeam: (teamId) => openNbaTeamPage(context, teamId, teamId),
      onOpenPlayer: (playerId, playerName) =>
          openNbaPlayerPage(context, playerId, playerName),
    );
  }

  Future<void> _restoreContext(NbaResearchContext context) async {
    await _contexts.restore(context);
    if (!mounted) return;
    setState(() {
      _contextFuture = _contexts.load();
      _recentContextsFuture = _contexts.recent();
    });
  }

  Future<void> _toggleFavorite(NbaTerminalCommand command) async {
    final next = await _stateStore.toggleFavorite(command.id);
    if (!mounted) return;
    setState(() {
      _terminalStateFuture = Future.value(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _tBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          return Column(
            children: [
              _header(compact),
              _activeContextStrip(),
              _deskNav(),
              Expanded(
                child: switch (_desk) {
                  _TerminalDesk.command => _commandDesk(compact),
                  _TerminalDesk.seasons => _seasonDesk(),
                  _TerminalDesk.coverage => _coverageDesk(),
                  _TerminalDesk.context => _contextDesk(),
                  _TerminalDesk.completion => _completionDesk(),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(bool compact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 13),
      decoration: const BoxDecoration(
        color: _tPanel,
        border: Border(bottom: BorderSide(color: _tLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [_tBlue, _tGold]),
            ),
            child: const Icon(Icons.terminal_rounded, color: _tBg),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPORTS TERMINAL · NBA',
                  style: TextStyle(
                    color: _tText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .9,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'One command layer across ~80 years of canonical NBA data, research, modeling and front-office workflows',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _tMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const _TerminalBadge('CANONICAL HISTORY', _tGold),
            const SizedBox(width: 8),
            const _TerminalBadge('SHARED CONTEXT', _tGreen),
          ],
          IconButton(
            tooltip: 'Refresh terminal',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded, color: _tText),
          ),
        ],
      ),
    );
  }

  Widget _activeContextStrip() {
    return FutureBuilder<NbaResearchContext>(
      future: _contextFuture,
      builder: (context, snapshot) {
        final active = snapshot.data;
        return Container(
          width: double.infinity,
          color: const Color(0xFF091724),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                active?.historical == true ? Icons.history_rounded : Icons.verified_rounded,
                size: 15,
                color: active?.historical == true ? _tGold : _tGreen,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  active == null
                      ? 'Loading active NBA context…'
                      : 'ACTIVE CONTEXT · ${active.scopeLabel}${active.entityLabel.isEmpty ? '' : ' · ${active.entityLabel}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active?.historical == true ? _tGold : _tGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _desk = _TerminalDesk.context),
                child: const Text('MANAGE'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _deskNav() {
    const items = [
      (_TerminalDesk.command, 'Command', Icons.search_rounded),
      (_TerminalDesk.seasons, 'Season Index', Icons.calendar_view_month_rounded),
      (_TerminalDesk.coverage, 'Data & Coverage', Icons.dataset_rounded),
      (_TerminalDesk.context, 'Context & Recents', Icons.history_toggle_off_rounded),
      (_TerminalDesk.completion, 'Platform Map', Icons.account_tree_rounded),
    ];
    return Container(
      width: double.infinity,
      color: _tPanel,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              ChoiceChip(
                selected: _desk == items[i].$1,
                onSelected: (_) => setState(() => _desk = items[i].$1),
                avatar: Icon(items[i].$3, size: 16),
                label: Text(items[i].$2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _commandDesk(bool compact) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchBar(),
          const SizedBox(height: 14),
          FutureBuilder<NbaTerminalState>(
            future: _terminalStateFuture,
            builder: (context, snapshot) {
              final state = snapshot.data ?? const NbaTerminalState();
              return _savedCommandStrip(state);
            },
          ),
          const SizedBox(height: 14),
          if (_searchError.isNotEmpty)
            _Notice('Canonical entity search unavailable: $_searchError'),
          if (compact)
            Column(
              children: [
                _commandResults(),
                const SizedBox(height: 14),
                _entityResults(),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _commandResults()),
                const SizedBox(width: 14),
                Expanded(flex: 6, child: _entityResults()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          const Icon(Icons.terminal_rounded, color: _tGold),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _query,
              autofocus: false,
              onSubmitted: (_) => _runSearch(),
              style: const TextStyle(color: _tText, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Search terminal commands or canonical NBA entities…',
                hintStyle: TextStyle(color: _tMuted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          FilledButton.icon(
            onPressed: _runSearch,
            icon: const Icon(Icons.search_rounded, size: 17),
            label: const Text('GO'),
          ),
        ],
      ),
    );
  }

  Widget _savedCommandStrip(NbaTerminalState state) {
    final favorites = NbaTerminalCommandEngine.catalog
        .where((command) => state.favoriteCommandIds.contains(command.id))
        .toList();
    final recent = [
      for (final id in state.recentCommandIds)
        ...NbaTerminalCommandEngine.catalog.where((command) => command.id == id),
    ];
    final rows = favorites.isNotEmpty ? favorites : recent.take(7).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(color: const Color(0xFF0A1724)),
      child: Row(
        children: [
          Icon(
            favorites.isNotEmpty ? Icons.star_rounded : Icons.history_rounded,
            color: favorites.isNotEmpty ? _tGold : _tBlue,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            favorites.isNotEmpty ? 'FAVORITES' : 'RECENT COMMANDS',
            style: const TextStyle(
              color: _tMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: rows.isEmpty
                ? const Text(
                    'Run commands to build a persistent terminal working set.',
                    style: TextStyle(color: _tMuted, fontSize: 10),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final command in rows) ...[
                          ActionChip(
                            avatar: Icon(command.icon, size: 15),
                            label: Text(command.shortcut.isEmpty ? command.label : command.shortcut),
                            onPressed: () => _openCommand(command),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _commandResults() {
    return _Panel(
      title: 'TERMINAL FUNCTIONS',
      subtitle: '${_commandMatches.length} matched destinations',
      child: Column(
        children: [
          if (_commandMatches.isEmpty)
            const _EmptyState(
              icon: Icons.search_off_rounded,
              message: 'No product command matched. Try “stats”, “trade”, “history”, “player”, “python” or “workspace”.',
            )
          else
            for (final match in _commandMatches)
              _CommandRow(
                command: match.command,
                favoriteFuture: _terminalStateFuture,
                onOpen: () => _openCommand(match.command),
                onFavorite: () => _toggleFavorite(match.command),
              ),
        ],
      ),
    );
  }

  Widget _entityResults() {
    final groups = _map(_entitySearch['groups']);
    final count = _entitySearch['count'] is num ? (_entitySearch['count'] as num).toInt() : 0;
    return _Panel(
      title: 'CANONICAL OBJECTS',
      subtitle: _query.text.trim().length < 2
          ? 'Enter 2+ characters to query the historical entity graph'
          : '$count matched historical objects',
      child: Column(
        children: [
          if (_query.text.trim().length < 2)
            const _EmptyState(
              icon: Icons.hub_rounded,
              message: 'Search a player, team, franchise, season, date, game ID or abbreviation across the canonical warehouse.',
            )
          else if (_searching)
            const Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            )
          else if (count == 0)
            const _EmptyState(
              icon: Icons.manage_search_rounded,
              message: 'No canonical entity matched this query.',
            )
          else
            for (final entry in <(String, String, IconData)>[
              ('players', 'player', Icons.person_rounded),
              ('teams', 'team', Icons.groups_rounded),
              ('franchises', 'franchise', Icons.account_tree_rounded),
              ('seasons', 'season', Icons.calendar_month_rounded),
              ('games', 'game', Icons.sports_basketball_rounded),
            ])
              if (_list(groups[entry.$1]).isNotEmpty) ...[
                _GroupLabel(entry.$1.toUpperCase(), entry.$3),
                for (final row in _list(groups[entry.$1]).take(8))
                  _EntityRow(
                    kind: entry.$2,
                    row: row,
                    onTap: () => _inspectEntity(entry.$2, row),
                  ),
              ],
        ],
      ),
    );
  }

  Widget _seasonDesk() {
    return Column(
      children: [
        Container(
          color: _tPanel,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _league,
                dropdownColor: _tPanel2,
                style: const TextStyle(color: _tText, fontWeight: FontWeight.w800),
                items: const [
                  DropdownMenuItem(value: 'NBA', child: Text('NBA')),
                  DropdownMenuItem(value: 'ABA', child: Text('ABA')),
                  DropdownMenuItem(value: 'BAA', child: Text('BAA')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _league = value;
                    _seasonsFuture = _terminal.seasons(
                      league: _league,
                      query: _seasonQuery.text.trim(),
                      limit: 100,
                    );
                  });
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _seasonQuery,
                  style: const TextStyle(color: _tText),
                  decoration: const InputDecoration(
                    hintText: 'Filter season index…',
                    hintStyle: TextStyle(color: _tMuted),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => setState(() {
                    _seasonsFuture = _terminal.seasons(
                      league: _league,
                      query: _seasonQuery.text.trim(),
                      limit: 100,
                    );
                  }),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh season index',
                onPressed: () => setState(() {
                  _seasonsFuture = _terminal.seasons(
                    league: _league,
                    query: _seasonQuery.text.trim(),
                    limit: 100,
                  );
                }),
                icon: const Icon(Icons.refresh_rounded, color: _tText),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _seasonsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _ErrorState(message: 'Season index unavailable: ${snapshot.error}');
              }
              final rows = _list(snapshot.data!['rows']);
              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Container(
                    padding: const EdgeInsets.all(13),
                    decoration: _panelDecoration(),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            row['season_id']?.toString() ?? '—',
                            style: const TextStyle(
                              color: _tGold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MetricPill('Teams', row['teams']),
                              _MetricPill('Players', row['players']),
                              _MetricPill('Games', row['games']),
                              _MetricPill('Awards', row['awards']),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          key: ValueKey('terminal-open-season-${row['season_id']}'),
                          onPressed: () => _activateSeason(row),
                          icon: const Icon(Icons.calendar_view_month_rounded, size: 16),
                          label: const Text('Open Season'),
                        ),
                        IconButton(
                          tooltip: 'Inspect season',
                          onPressed: () => _inspectEntity('season', row),
                          icon: const Icon(Icons.info_outline_rounded, color: _tBlue),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _coverageDesk() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _manifestFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ErrorState(message: 'Terminal manifest unavailable: ${snapshot.error}');
        }
        final data = snapshot.data!;
        final counts = _map(data['counts']);
        final span = _map(data['season_span']);
        final sources = _list(data['sources']);
        final coverage = _list(data['coverage']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Panel(
              title: 'CANONICAL WAREHOUSE',
              subtitle: '${span['first'] ?? '—'} → ${span['last'] ?? '—'} · ${span['seasons'] ?? 0} seasons',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in counts.entries)
                    _WarehouseMetric(entry.key, entry.value),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'SOURCE REGISTRY',
              subtitle: '${sources.length} installed historical source families',
              child: Column(
                children: [
                  for (final source in sources)
                    _SourceRow(source: source),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'ERA / DOMAIN COVERAGE',
              subtitle: 'Unavailable historical fields remain unavailable; coverage is explicit rather than synthesized.',
              child: Column(
                children: [
                  for (final row in coverage)
                    _CoverageRow(row: row),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _contextDesk() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<NbaResearchContext>(
          future: _contextFuture,
          builder: (context, snapshot) {
            final active = snapshot.data;
            return _Panel(
              title: 'ACTIVE NBA CONTEXT',
              subtitle: active?.scopeLabel ?? 'Loading…',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active == null
                        ? 'Loading shared context…'
                        : active.entityLabel.isEmpty
                            ? active.scopeLabel
                            : '${active.scopeLabel} · ${active.entityLabel}',
                    style: const TextStyle(
                      color: _tText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openCommand(_engine.resolve('stats', organizationMode: _organizationMode)!),
                        icon: const Icon(Icons.table_chart_rounded),
                        label: const Text('Stats'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openCommand(_engine.resolve('analytics', organizationMode: _organizationMode)!),
                        icon: const Icon(Icons.analytics_rounded),
                        label: const Text('Analytics'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openCommand(_engine.resolve('history', organizationMode: _organizationMode)!),
                        icon: const Icon(Icons.history_edu_rounded),
                        label: const Text('Historical Intelligence'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final current = await _contexts.selectCurrent(clearEntity: true);
                          if (!mounted) return;
                          setState(() {
                            _contextFuture = Future.value(current);
                            _recentContextsFuture = _contexts.recent();
                          });
                        },
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Current release'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<NbaResearchContext>>(
          future: _recentContextsFuture,
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <NbaResearchContext>[];
            return _Panel(
              title: 'RECENT RESEARCH CONTEXTS',
              subtitle: '${rows.length} restorable contexts',
              child: Column(
                children: [
                  if (rows.isEmpty)
                    const _EmptyState(
                      icon: Icons.history_toggle_off_rounded,
                      message: 'Historical seasons and selected entities will appear here as you research them.',
                    )
                  else
                    for (final item in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.historical ? Icons.history_rounded : Icons.verified_rounded,
                          color: item.historical ? _tGold : _tGreen,
                        ),
                        title: Text(
                          item.scopeLabel,
                          style: const TextStyle(color: _tText, fontWeight: FontWeight.w800),
                        ),
                        subtitle: item.entityLabel.isEmpty
                            ? null
                            : Text(item.entityLabel, style: const TextStyle(color: _tMuted)),
                        trailing: TextButton(
                          onPressed: () => _restoreContext(item),
                          child: const Text('RESTORE'),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _completionDesk() {
    final available = NbaTerminalCommandEngine.catalog
        .where((command) => _organizationMode || !command.requiresOrganization)
        .toList();
    final groups = <String, List<NbaTerminalCommand>>{};
    for (final command in available) {
      groups.putIfAbsent(command.group, () => []).add(command);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Panel(
          title: 'NBA TERMINAL PLATFORM MAP',
          subtitle: 'The terminal is organized around one canonical data graph, shared research context and routable product functions.',
          child: Column(
            children: [
              for (final entry in groups.entries) ...[
                _GroupLabel(entry.key.toUpperCase(), Icons.account_tree_rounded),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final command in entry.value)
                      _CapabilityCard(
                        command: command,
                        onOpen: () => _openCommand(command),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _Panel(
          title: 'INTEGRATION CONTRACT',
          subtitle: 'What “complete” means for the current NBA-first platform build.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContractLine('Canonical data', 'Players, teams, franchises, seasons, games, awards, drafts and historical facts share one graph.'),
              _ContractLine('Current + historical', 'Certified current data remains isolated from canonical historical context while both are navigable through one terminal.'),
              _ContractLine('Research', 'Stats, Analytics, Historical Intelligence, Entity Intelligence and research workspaces share context.'),
              _ContractLine('Modeling', 'Routed datasets can move into spreadsheet workspaces and the bounded Python runtime.'),
              _ContractLine('Front office', 'Trade, cap, contracts, assets and transaction workflows are directly reachable from the same command layer.'),
              _ContractLine('Persistence', 'Terminal commands, favorites, research contexts, workspaces and entity watchlists persist across sessions.'),
              _ContractLine('Integrity', 'Coverage gaps, conflicts and provenance stay visible; missing-era statistics are not fabricated.'),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration({Color color = _tPanel}) => BoxDecoration(
        color: color,
        border: Border.all(color: _tLine),
        borderRadius: BorderRadius.circular(14),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _tPanel,
          border: Border.all(color: _tLine),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _tGold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: _tMuted, fontSize: 10)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.command,
    required this.favoriteFuture,
    required this.onOpen,
    required this.onFavorite,
  });

  final NbaTerminalCommand command;
  final Future<NbaTerminalState> favoriteFuture;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _tPanel2,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(command.icon, color: _tBlue, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      command.label,
                      style: const TextStyle(color: _tText, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      command.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _tMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (command.shortcut.isNotEmpty)
                _TerminalBadge(command.shortcut, _tBlue),
              FutureBuilder<NbaTerminalState>(
                future: favoriteFuture,
                builder: (context, snapshot) {
                  final selected = snapshot.data?.favoriteCommandIds.contains(command.id) == true;
                  return IconButton(
                    tooltip: selected ? 'Remove favorite' : 'Favorite command',
                    onPressed: onFavorite,
                    icon: Icon(
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
                      color: selected ? _tGold : _tMuted,
                      size: 19,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({required this.kind, required this.row, required this.onTap});

  final String kind;
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      'player' => row['canonical_name']?.toString() ?? row['player_name']?.toString() ?? 'Player',
      'team' => row['canonical_name']?.toString() ?? row['team_name']?.toString() ?? 'Team',
      'franchise' => row['canonical_name']?.toString() ?? 'Franchise',
      'season' => row['label']?.toString() ?? row['season_id']?.toString() ?? 'Season',
      'game' => '${row['away_team_name'] ?? 'Away'} @ ${row['home_team_name'] ?? 'Home'}',
      _ => kind,
    };
    final subtitle = switch (kind) {
      'player' => [row['primary_position'], row['first_stat_season'], row['last_stat_season']]
          .where((value) => value != null && value.toString().isNotEmpty)
          .join(' · '),
      'team' => [row['abbreviation'], row['franchise_name'], row['league_id']]
          .where((value) => value != null && value.toString().isNotEmpty)
          .join(' · '),
      'franchise' => '${row['first_season'] ?? ''} → ${row['last_season'] ?? ''}',
      'season' => '${row['teams'] ?? 0} teams · ${row['players'] ?? 0} players · ${row['games'] ?? 0} games',
      'game' => '${row['game_date'] ?? ''} · ${row['season_id'] ?? ''}',
      _ => '',
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: _tText, fontWeight: FontWeight.w800)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(color: _tMuted, fontSize: 10)),
      trailing: const Icon(Icons.chevron_right_rounded, color: _tBlue),
      onTap: onTap,
    );
  }
}

class _EntityPreview extends StatelessWidget {
  const _EntityPreview({
    required this.kind,
    required this.row,
    required this.payload,
    required this.onActivate,
  });

  final String kind;
  final Map<String, dynamic> row;
  final Map<String, dynamic> payload;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final profile = _map(payload['profile']);
    final summary = _map(payload['summary']);
    final title = profile['canonical_name']?.toString() ??
        profile['player_name']?.toString() ??
        _map(payload['season'])['season_id']?.toString() ??
        row['canonical_name']?.toString() ??
        row['season_id']?.toString() ??
        kind.toUpperCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: _tGold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: _tText, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: onActivate,
                icon: const Icon(Icons.bolt_rounded),
                label: Text(switch (kind) {
                  'game' => 'Open game',
                  'season' => 'Open season',
                  _ => 'Activate context',
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${kind.toUpperCase()} · canonical terminal object',
            style: const TextStyle(color: _tMuted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in summary.entries.take(12))
                _MetricPill(entry.key, entry.value),
            ],
          ),
          const SizedBox(height: 18),
          _JsonPreview(payload: payload),
        ],
      ),
    );
  }
}

class _JsonPreview extends StatelessWidget {
  const _JsonPreview({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, dynamic>>[];
    for (final entry in payload.entries) {
      if (entry.value is String || entry.value is num || entry.value is bool) rows.add(entry);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _tBg,
        border: Border.all(color: _tLine),
        borderRadius: BorderRadius.circular(10),
      ),
      child: rows.isEmpty
          ? const Text(
              'Full canonical dossier loaded. Use Entity Intelligence for the complete multi-table view.',
              style: TextStyle(color: _tMuted),
            )
          : Column(
              children: [
                for (final entry in rows.take(20))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 170,
                          child: Text(
                            entry.key,
                            style: const TextStyle(color: _tMuted, fontSize: 10),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            entry.value.toString(),
                            style: const TextStyle(color: _tText, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _WarehouseMetric extends StatelessWidget {
  const _WarehouseMetric(this.label, this.value);

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Container(
        width: 158,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _tPanel2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatCount(value),
              style: const TextStyle(color: _tText, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label.replaceAll('_', ' ').toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _tMuted, fontSize: 8, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final Map<String, dynamic> source;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.storage_rounded, color: _tBlue, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source['label']?.toString() ?? source['source_key']?.toString() ?? 'Source',
                    style: const TextStyle(color: _tText, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${source['coverage'] ?? ''} · ${source['license'] ?? ''}',
                    style: const TextStyle(color: _tMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            _MetricPill('Rows', source['row_count']),
          ],
        ),
      );
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(
                row['domain']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'DOMAIN',
                style: const TextStyle(color: _tText, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(
              width: 54,
              child: Text(
                row['league_id']?.toString() ?? '',
                style: const TextStyle(color: _tGold, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: Text(
                '${row['first_season'] ?? '—'} → ${row['last_season'] ?? '—'}',
                style: const TextStyle(color: _tMuted, fontSize: 10),
              ),
            ),
            _MetricPill('Seasons', row['seasons']),
            const SizedBox(width: 6),
            _MetricPill('Rows', row['rows']),
          ],
        ),
      );
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.command, required this.onOpen});

  final NbaTerminalCommand command;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _tPanel2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _tLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(command.icon, color: _tBlue, size: 18),
                    const Spacer(),
                    const _TerminalBadge('OPERATIONAL', _tGreen),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  command.label,
                  style: const TextStyle(color: _tText, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  command.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _tMuted, fontSize: 9, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ContractLine extends StatelessWidget {
  const _ContractLine(this.label, this.message);

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded, color: _tGreen, size: 17),
            const SizedBox(width: 8),
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(color: _tText, fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(child: Text(message, style: const TextStyle(color: _tMuted, height: 1.35))),
          ],
        ),
      );
}

class _MetricPill extends StatelessWidget {
  const _MetricPill(this.label, this.value);

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1724),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _tLine),
        ),
        child: Text(
          '$label ${_formatCount(value)}',
          style: const TextStyle(color: _tMuted, fontSize: 9, fontWeight: FontWeight.w800),
        ),
      );
}

class _TerminalBadge extends StatelessWidget {
  const _TerminalBadge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .5)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .35),
        ),
      );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label, this.icon);

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 5),
        child: Row(
          children: [
            Icon(icon, color: _tBlue, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: _tMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .55),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: _tMuted, size: 32),
            const SizedBox(height: 9),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _tMuted, height: 1.4)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1C12),
          border: Border.all(color: _tOrange),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message, style: const TextStyle(color: _tOrange, fontSize: 10)),
      );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) item.map((key, nested) => MapEntry(key.toString(), nested)),
  ];
}

String _formatCount(dynamic value) {
  if (value == null) return '—';
  final number = value is num ? value.toDouble() : double.tryParse(value.toString());
  if (number == null) return value.toString();
  if (number.abs() >= 1000000) return '${(number / 1000000).toStringAsFixed(number.abs() >= 10000000 ? 0 : 1)}M';
  if (number.abs() >= 1000) return '${(number / 1000).toStringAsFixed(number.abs() >= 10000 ? 0 : 1)}K';
  return number % 1 == 0 ? number.toStringAsFixed(0) : number.toStringAsFixed(1);
}
