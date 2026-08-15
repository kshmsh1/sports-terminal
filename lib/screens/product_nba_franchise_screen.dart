import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../services/nba_entity_intelligence_repository.dart';
import '../services/nba_franchise_intelligence_engine.dart';
import '../services/nba_franchise_performance_engine.dart';
import '../services/nba_franchise_player_history_engine.dart';
import '../services/nba_franchise_workflow_service.dart';
import '../widgets/nba_terminal_trend_chart.dart';

const _bg = Color(0xFF090D12);
const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);

typedef NbaFranchisePayloadLoader = Future<Map<String, dynamic>> Function();
typedef NbaFranchiseTeamDossierLoader = Future<Map<String, dynamic>> Function(String teamKey);
typedef NbaFranchisePlayerOpenCallback = void Function(String playerId, String playerName);

class ProductNbaFranchiseScreen extends StatefulWidget {
  const ProductNbaFranchiseScreen({
    super.key,
    required this.franchiseKey,
    this.league = 'NBA',
    this.loadFranchise,
    this.loadTeamDossier,
    this.workflowService = const NbaFranchiseWorkflowService(),
    this.onOpenTeam,
    this.onOpenPlayer,
    this.onOpenSeason,
  });

  final String franchiseKey;
  final String league;
  final NbaFranchisePayloadLoader? loadFranchise;
  final NbaFranchiseTeamDossierLoader? loadTeamDossier;
  final NbaFranchiseWorkflowService workflowService;
  final ValueChanged<String>? onOpenTeam;
  final NbaFranchisePlayerOpenCallback? onOpenPlayer;
  final ValueChanged<String>? onOpenSeason;

  @override
  State<ProductNbaFranchiseScreen> createState() => _ProductNbaFranchiseScreenState();
}

class _LoadedFranchise {
  const _LoadedFranchise({
    required this.franchise,
    required this.performance,
    required this.players,
  });

  final NbaFranchiseIntelligenceSnapshot franchise;
  final NbaFranchisePerformanceResult performance;
  final NbaFranchisePlayerHistoryResult players;
}

class _ProductNbaFranchiseScreenState extends State<ProductNbaFranchiseScreen> {
  late Future<_LoadedFranchise> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(ProductNbaFranchiseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.franchiseKey != widget.franchiseKey ||
        oldWidget.league != widget.league ||
        oldWidget.loadFranchise != widget.loadFranchise ||
        oldWidget.loadTeamDossier != widget.loadTeamDossier) {
      _future = _load();
    }
  }

  Future<_LoadedFranchise> _load() async {
    final repository = const NbaEntityIntelligenceRepository();
    final payload = await (widget.loadFranchise?.call() ??
        repository.franchiseDossier(widget.franchiseKey, league: widget.league));
    final franchise = const NbaFranchiseIntelligenceEngine().build(
      payload,
      franchiseKey: widget.franchiseKey,
    );
    final teamDossiers = <String, Map<String, dynamic>>{};
    final loader = widget.loadTeamDossier ??
        (String teamKey) => repository.teamDossier(
              teamKey,
              league: widget.league,
              seasonType: 'regular',
              recentGames: 0,
            );
    for (final identity in franchise.teamIdentities) {
      if (identity.teamKey.isEmpty) continue;
      try {
        teamDossiers[identity.teamKey] = await loader(identity.teamKey);
      } catch (_) {
        // Coverage remains explicit in NbaFranchisePlayerHistoryResult.
      }
    }
    final performance = const NbaFranchisePerformanceEngine().build(franchise);
    final players = const NbaFranchisePlayerHistoryEngine().build(
      franchise: franchise,
      teamDossiers: teamDossiers,
    );
    return _LoadedFranchise(
      franchise: franchise,
      performance: performance,
      players: players,
    );
  }

  void _route(_LoadedFranchise loaded, String target) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      _notice('Shared RoutePayload state is unavailable in this shell.');
      return;
    }
    final payload = widget.workflowService.package(
      franchise: loaded.franchise,
      playerHistory: loaded.players,
      targetRoute: target,
      league: widget.league,
    );
    controller.setActivePayload(
      payload,
      origin: 'NBA Franchise · ${loaded.franchise.franchiseName}',
    );
    _notice('${payload.displayLabel} routed to $target.');
  }

  void _notice(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LoadedFranchise>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _Panel(child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Panel(
              child: Text(
                'Franchise unavailable: ${snapshot.error}',
                style: const TextStyle(color: _muted),
              ),
            );
          }
          final loaded = snapshot.data!;
          final franchise = loaded.franchise;
          final performance = loaded.performance;
          if (!franchise.available) {
            return const _Panel(
              child: Text(
                'The historical source returned no usable canonical Franchise identity.',
                style: TextStyle(color: _muted),
              ),
            );
          }
          return Column(
            key: ValueKey('nba-franchise-${franchise.franchiseKey}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                title: franchise.franchiseName,
                body:
                    'Canonical franchise lineage across historical Team identities, source-backed regular-season performance, bounded player continuity, and shared analyst workflows. Relocations, championships, ownership changes, awards, draft outcomes and retired numbers are never inferred when the Franchise dossier does not expose them.',
              ),
              const SizedBox(height: 12),
              _workflowPanel(loaded),
              const SizedBox(height: 12),
              _overview(franchise, performance, loaded.players),
              const SizedBox(height: 12),
              _performanceTrend(performance),
              const SizedBox(height: 12),
              _lineage(franchise),
              const SizedBox(height: 12),
              _seasonHistory(performance),
              const SizedBox(height: 12),
              _playerHistory(loaded.players),
              const SizedBox(height: 12),
              _sourceBoundary(loaded.players),
            ],
          );
        },
      );

  Widget _workflowPanel(_LoadedFranchise loaded) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FRANCHISE WORKFLOWS',
              style: TextStyle(
                color: _amber,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _routeButton(loaded, 'Workspace', 'franchise-route-workspace'),
                _routeButton(loaded, 'Python Lab', 'franchise-route-python'),
                _routeButton(loaded, 'Compare', 'franchise-route-compare'),
                _routeButton(loaded, 'Source Audit', 'franchise-route-source-audit'),
                _FranchisePersistentControls(
                  franchise: loaded.franchise,
                  workflows: widget.workflowService,
                  league: widget.league,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _routeButton(_LoadedFranchise loaded, String target, String key) =>
      OutlinedButton(
        key: ValueKey(key),
        onPressed: () => _route(loaded, target),
        child: Text(target.toUpperCase()),
      );

  Widget _overview(
    NbaFranchiseIntelligenceSnapshot franchise,
    NbaFranchisePerformanceResult performance,
    NbaFranchisePlayerHistoryResult players,
  ) =>
      _Panel(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _kpi('CURRENT ABBR', franchise.currentAbbreviation.isEmpty ? '—' : franchise.currentAbbreviation),
            _kpi('TEAM IDENTITIES', '${franchise.teamIdentities.length}'),
            _kpi('OBSERVED SEASONS', '${performance.observedSeasons}'),
            _kpi('SEASON RANGE', franchise.seasonRangeLabel),
            _kpi('REGULAR RECORD', '${performance.totalWins}-${performance.totalLosses}'),
            _kpi('WIN%', performance.weightedWinPct == null ? '—' : performance.weightedWinPct!.toStringAsFixed(3)),
            _kpi('PLAYER ROWS', '${players.players.length}'),
          ],
        ),
      );

  Widget _performanceTrend(NbaFranchisePerformanceResult result) {
    final rolling = <double?>[];
    for (var index = 0; index < result.seasons.length; index++) {
      final start = index < 4 ? 0 : index - 4;
      final window = result.seasons
          .sublist(start, index + 1)
          .map((row) => row.winPct)
          .whereType<double>()
          .toList();
      rolling.add(window.isEmpty ? null : window.reduce((a, b) => a + b) / window.length);
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FRANCHISE WIN% HISTORY',
            style: TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          NbaTerminalTrendChart(
            metricLabel: 'REGULAR-SEASON WIN%',
            points: [
              for (var index = 0; index < result.seasons.length; index++)
                NbaTerminalTrendPoint(
                  label: result.seasons[index].seasonId,
                  value: result.seasons[index].winPct == null
                      ? null
                      : result.seasons[index].winPct! * 100,
                  rollingValue: rolling[index] == null ? null : rolling[index]! * 100,
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(result.methodologyLabel, style: const TextStyle(color: _muted, fontSize: 8, height: 1.4)),
        ],
      ),
    );
  }

  Widget _lineage(NbaFranchiseIntelligenceSnapshot franchise) => _Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'CANONICAL TEAM IDENTITY LINEAGE',
                style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            const Divider(height: 1, color: _line),
            if (!franchise.hasLineage)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No canonical team identities are exposed for this Franchise.', style: TextStyle(color: _muted)),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_panel2),
                  columns: const [
                    DataColumn(label: Text('ERA')),
                    DataColumn(label: Text('TEAM')),
                    DataColumn(label: Text('ABBR')),
                    DataColumn(label: Text('LEAGUE')),
                    DataColumn(label: Text('NBA TEAM ID')),
                    DataColumn(label: Text('SOURCES')),
                  ],
                  rows: [
                    for (final identity in franchise.teamIdentities)
                      DataRow(cells: [
                        DataCell(Text(identity.eraLabel)),
                        DataCell(
                          TextButton(
                            key: ValueKey('franchise-team-${identity.teamKey}'),
                            onPressed: widget.onOpenTeam == null || identity.teamKey.isEmpty
                                ? null
                                : () => widget.onOpenTeam!(identity.teamKey),
                            child: Text(identity.teamName.isEmpty ? identity.teamKey : identity.teamName),
                          ),
                        ),
                        DataCell(Text(identity.abbreviation.isEmpty ? '—' : identity.abbreviation)),
                        DataCell(Text(identity.leagueId.isEmpty ? '—' : identity.leagueId)),
                        DataCell(Text(identity.nbaTeamId.isEmpty ? '—' : identity.nbaTeamId)),
                        DataCell(Text(identity.sourceCount?.toString() ?? '—')),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _seasonHistory(NbaFranchisePerformanceResult result) => _Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'REGULAR-SEASON HISTORY',
                style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            const Divider(height: 1, color: _line),
            if (!result.available)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No regular-season performance rows are exposed.', style: TextStyle(color: _muted)),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_panel2),
                  columns: const [
                    DataColumn(label: Text('SEASON')),
                    DataColumn(label: Text('TEAM IDENTITY')),
                    DataColumn(label: Text('W-L')),
                    DataColumn(label: Text('WIN%')),
                  ],
                  rows: [
                    for (final season in result.seasons.reversed.take(40))
                      DataRow(cells: [
                        DataCell(
                          TextButton(
                            key: ValueKey('franchise-season-${season.seasonId}'),
                            onPressed: widget.onOpenSeason == null
                                ? null
                                : () => widget.onOpenSeason!(season.seasonId),
                            child: Text(season.seasonId),
                          ),
                        ),
                        DataCell(Text(season.teamLabels.join(' / '))),
                        DataCell(Text(season.recordLabel)),
                        DataCell(Text(season.winPct?.toStringAsFixed(3) ?? '—')),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _playerHistory(NbaFranchisePlayerHistoryResult result) => _Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'BOUNDED FRANCHISE PLAYER HISTORY',
                      style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(result.coverageLabel, style: const TextStyle(color: _muted, fontSize: 8)),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            if (result.players.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No bounded notable-player rows were exposed by the loaded Team dossiers.', style: TextStyle(color: _muted)),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_panel2),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('PLAYER')),
                    DataColumn(label: Text('SEASONS')),
                    DataColumn(label: Text('RANGE')),
                    DataColumn(label: Text('GP')),
                    DataColumn(label: Text('PTS')),
                    DataColumn(label: Text('REB')),
                    DataColumn(label: Text('AST')),
                  ],
                  rows: [
                    for (var index = 0; index < result.players.take(25).length; index++)
                      DataRow(cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          TextButton(
                            key: ValueKey('franchise-player-${result.players[index].playerKey}'),
                            onPressed: widget.onOpenPlayer == null
                                ? null
                                : () => widget.onOpenPlayer!(
                                      result.players[index].playerKey,
                                      result.players[index].playerName,
                                    ),
                            child: Text(result.players[index].playerName),
                          ),
                        ),
                        DataCell(Text('${result.players[index].seasons}')),
                        DataCell(Text(_range(result.players[index].firstSeason, result.players[index].lastSeason))),
                        DataCell(Text('${result.players[index].games}')),
                        DataCell(Text('${result.players[index].points}')),
                        DataCell(Text('${result.players[index].rebounds}')),
                        DataCell(Text('${result.players[index].assists}')),
                      ]),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(result.methodologyLabel, style: const TextStyle(color: _muted, fontSize: 8, height: 1.4)),
            ),
          ],
        ),
      );

  Widget _sourceBoundary(NbaFranchisePlayerHistoryResult players) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FRANCHISE SOURCE BOUNDARY',
              style: TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              players.completeAcrossRequestedIdentities
                  ? 'All requested canonical Team dossiers loaded for the bounded player-history projection.'
                  : '${players.missingTeamDossiers} canonical Team dossier(s) did not load; player-history coverage is partial.',
              style: const TextStyle(color: _text, fontSize: 9),
            ),
            const SizedBox(height: 6),
            const Text(
              'Franchise-scoped award attribution, draft outcome mapping, championship counts, ownership history, relocation reasons, retired numbers and venue history are not exposed by the current Franchise dossier. Sports Terminal leaves those surfaces unavailable instead of joining them through ambiguous inference.',
              key: ValueKey('franchise-source-boundary'),
              style: TextStyle(color: _muted, fontSize: 9, height: 1.45),
            ),
          ],
        ),
      );
}

class _FranchisePersistentControls extends StatefulWidget {
  const _FranchisePersistentControls({
    required this.franchise,
    required this.workflows,
    required this.league,
  });

  final NbaFranchiseIntelligenceSnapshot franchise;
  final NbaFranchiseWorkflowService workflows;
  final String league;

  @override
  State<_FranchisePersistentControls> createState() => _FranchisePersistentControlsState();
}

class _FranchisePersistentControlsState extends State<_FranchisePersistentControls> {
  late Future<bool> _watchedFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _watchedFuture = widget.workflows.isWatched(widget.franchise, league: widget.league);
  }

  @override
  void didUpdateWidget(_FranchisePersistentControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.franchise.franchiseKey != widget.franchise.franchiseKey ||
        oldWidget.league != widget.league) {
      _watchedFuture = widget.workflows.isWatched(widget.franchise, league: widget.league);
      _busy = false;
    }
  }

  Future<void> _research() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final context = await widget.workflows.activateResearch(widget.franchise, league: widget.league);
      if (mounted) _notice('Franchise research scope activated · ${context.scopeLabel}.');
    } catch (error) {
      if (mounted) _notice('Unable to activate franchise research: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWatch() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final watched = await widget.workflows.toggleWatch(widget.franchise, league: widget.league);
      if (!mounted) return;
      setState(() => _watchedFuture = Future.value(watched));
      _notice(watched ? 'Franchise added to NBA watchlist.' : 'Franchise removed from NBA watchlist.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('franchise-activate-research'),
            onPressed: _busy ? null : _research,
            icon: const Icon(Icons.manage_search_rounded, size: 15),
            label: const Text('RESEARCH LATEST SEASON'),
          ),
          FutureBuilder<bool>(
            future: _watchedFuture,
            builder: (context, snapshot) {
              final watched = snapshot.data == true;
              return OutlinedButton.icon(
                key: const ValueKey('franchise-toggle-watch'),
                onPressed: _busy ? null : _toggleWatch,
                icon: Icon(watched ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 15),
                label: Text(watched ? 'UNWATCH FRANCHISE' : 'WATCH FRANCHISE'),
              );
            },
          ),
        ],
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NBA / FRANCHISE',
              style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8),
            ),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(color: _text, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: _muted, fontSize: 10, height: 1.45)),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: child,
      );
}

Widget _kpi(String label, String value) => Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );

String _range(String first, String last) {
  if (first.isEmpty && last.isEmpty) return '—';
  if (first.isEmpty) return last;
  if (last.isEmpty || first == last) return first;
  return '$first → $last';
}

const nbaFranchiseBackground = _bg;
