import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../services/nba_season_intelligence_engine.dart';
import '../services/nba_season_workflow_service.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../widgets/nba_season_analytics_panel.dart';
import '../widgets/nba_season_cross_season_panel.dart';
import '../widgets/nba_season_operations_panel.dart';
import '../widgets/nba_season_source_context_panel.dart';

const _bg = Color(0xFF090D12);
const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);

typedef NbaSeasonGameOpenCallback = void Function(
  String gameId,
  String gameLabel,
);
typedef NbaSeasonComparisonSeedLoader = Future<NbaTerminalSeedSnapshot> Function(
  String seasonId,
);
typedef NbaSeasonSourcePayloadLoader = Future<Map<String, dynamic>> Function();

class ProductNbaSeasonScreen extends StatefulWidget {
  const ProductNbaSeasonScreen({
    super.key,
    required this.seasonId,
    this.loadSeed,
    this.loadComparisonSeason,
    this.loadSourceContext,
    this.workflowService = const NbaSeasonWorkflowService(),
    this.onOpenGame,
    this.onOpenTeam,
    this.onOpenPlayer,
    this.onOpenSchedule,
  });

  final String seasonId;
  final Future<NbaTerminalSeedSnapshot> Function()? loadSeed;
  final NbaSeasonComparisonSeedLoader? loadComparisonSeason;
  final NbaSeasonSourcePayloadLoader? loadSourceContext;
  final NbaSeasonWorkflowService workflowService;
  final NbaSeasonGameOpenCallback? onOpenGame;
  final ValueChanged<String>? onOpenTeam;
  final NbaSeasonPlayerOpenCallback? onOpenPlayer;
  final VoidCallback? onOpenSchedule;

  @override
  State<ProductNbaSeasonScreen> createState() => _ProductNbaSeasonScreenState();
}

class _ProductNbaSeasonScreenState extends State<ProductNbaSeasonScreen> {
  late Future<NbaTerminalSeedSnapshot> _seedFuture;
  String _seasonType = 'All';

  @override
  void initState() {
    super.initState();
    _seedFuture = _load();
  }

  @override
  void didUpdateWidget(ProductNbaSeasonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seasonId != widget.seasonId ||
        oldWidget.loadSeed != widget.loadSeed) {
      _seedFuture = _load();
    }
  }

  Future<NbaTerminalSeedSnapshot> _load() =>
      widget.loadSeed?.call() ?? const NbaTerminalSeedRepository().load();

  void _routeSeason(
    NbaTerminalSeedSnapshot seed,
    String targetRoute,
  ) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      _notice('Shared RoutePayload state is unavailable in this shell.');
      return;
    }
    try {
      final payload = widget.workflowService.package(
        seed,
        seasonId: widget.seasonId,
        seasonType: _seasonType,
        targetRoute: targetRoute,
      );
      controller.setActivePayload(
        payload,
        origin: 'NBA Season · ${widget.seasonId} · $_seasonType',
      );
      _notice('${payload.displayLabel} routed to $targetRoute.');
    } catch (error) {
      _notice('Unable to route season: $error');
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: _seedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _Panel(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Panel(
              child: Text(
                'Season unavailable: ${snapshot.error}',
                style: const TextStyle(color: _muted),
              ),
            );
          }
          final seed = snapshot.data!;
          final season = const NbaSeasonIntelligenceEngine().build(
            seed,
            seasonId: widget.seasonId,
            seasonType: _seasonType,
          );
          return Column(
            key: ValueKey('nba-season-${widget.seasonId}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                title: '${widget.seasonId} NBA Season',
                body:
                    'Canonical season operating surface for standings, schedule/results, player leaders, team distributions, observed playoff matchup context, awards/voting, All-Star selections, draft context, date-only schedule density, cross-season benchmarking, source-backed context and persistent analyst workflows. Scheduled games never alter records, and unavailable structure is never synthesized.',
              ),
              const SizedBox(height: 12),
              _controls(seed, season),
              const SizedBox(height: 12),
              NbaSeasonAnalyticsPanel(
                seed: seed,
                seasonId: widget.seasonId,
                seasonType: _seasonType,
                onOpenPlayer: widget.onOpenPlayer,
                onOpenTeam: widget.onOpenTeam,
                onOpenGame: widget.onOpenGame,
              ),
              const SizedBox(height: 12),
              NbaSeasonOperationsPanel(
                seed: seed,
                seasonId: widget.seasonId,
                seasonType: _seasonType,
                loadContext: widget.loadSourceContext,
                onOpenPlayer: widget.onOpenPlayer,
                onOpenTeam: widget.onOpenTeam,
              ),
              const SizedBox(height: 12),
              NbaSeasonCrossSeasonPanel(
                seed: seed,
                seasonId: widget.seasonId,
                seasonType: _seasonType,
                loadHistoricalSeason: widget.loadComparisonSeason,
                onOpenTeam: widget.onOpenTeam,
              ),
              const SizedBox(height: 12),
              NbaSeasonSourceContextPanel(
                seasonId: widget.seasonId,
                seasonType: _seasonType,
                loadContext: widget.loadSourceContext,
                onOpenPlayer: widget.onOpenPlayer,
                onOpenTeam: widget.onOpenTeam,
              ),
              const SizedBox(height: 12),
              _standings(season),
              const SizedBox(height: 12),
              _games(season),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _pill(season.datasetStatus.toUpperCase(), _green),
                  _pill(
                    'VALIDATION ${season.validationStatus.toUpperCase()}',
                    _green,
                  ),
                  if (season.historicalContext) _pill('HISTORICAL', _blue),
                  if (season.usedFallbackDataset) _pill('FALLBACK', _amber),
                ],
              ),
            ],
          );
        },
      );

  Widget _controls(
    NbaTerminalSeedSnapshot seed,
    NbaSeasonIntelligenceSnapshot season,
  ) =>
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 9,
              runSpacing: 9,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  key: const ValueKey('season-type-filter'),
                  value: _seasonType,
                  dropdownColor: _panel2,
                  style: const TextStyle(color: _text, fontSize: 10),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All games')),
                    DropdownMenuItem(
                      value: 'Regular Season',
                      child: Text('Regular Season'),
                    ),
                    DropdownMenuItem(value: 'Playoffs', child: Text('Playoffs')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _seasonType = value);
                  },
                ),
                _kpi('GAMES', '${season.gameCount}'),
                _kpi('COMPLETED', '${season.completedGames}'),
                _kpi('SCHEDULED', '${season.scheduledGames}'),
                _kpi('TEAMS', '${season.teamCount}'),
                _kpi('DATES', season.dateRangeLabel),
                if (widget.onOpenSchedule != null)
                  OutlinedButton.icon(
                    key: const ValueKey('season-open-schedule'),
                    onPressed: widget.onOpenSchedule,
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('OPEN FULL SCHEDULE'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'SEASON WORKFLOWS',
              style: TextStyle(
                color: _amber,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _routeButton(seed, 'Workspace', 'season-route-workspace'),
                _routeButton(seed, 'Python Lab', 'season-route-python'),
                _routeButton(seed, 'Compare', 'season-route-compare'),
                _routeButton(seed, 'Source Audit', 'season-route-source-audit'),
                _SeasonPersistentWorkflowControls(
                  key: ValueKey('season-persistent-workflows-${widget.seasonId}-$_seasonType'),
                  seed: seed,
                  seasonId: widget.seasonId,
                  seasonType: _seasonType,
                  workflows: widget.workflowService,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _routeButton(
    NbaTerminalSeedSnapshot seed,
    String target,
    String key,
  ) =>
      OutlinedButton(
        key: ValueKey(key),
        onPressed: () => _routeSeason(seed, target),
        child: Text(target.toUpperCase()),
      );

  Widget _standings(NbaSeasonIntelligenceSnapshot season) => _Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'SEASON STANDINGS',
                style: TextStyle(
                  color: _amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
            const Divider(height: 1, color: _line),
            if (season.standings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(26),
                child: Text(
                  'No team standings can be derived in this season scope.',
                  style: TextStyle(color: _muted),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_panel2),
                  headingTextStyle: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                  dataTextStyle: const TextStyle(color: _text, fontSize: 9),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('TEAM')),
                    DataColumn(label: Text('W-L')),
                    DataColumn(label: Text('WIN%')),
                    DataColumn(label: Text('PF/G')),
                    DataColumn(label: Text('PA/G')),
                    DataColumn(label: Text('DIFF')),
                  ],
                  rows: [
                    for (var index = 0;
                        index < season.standings.length;
                        index++)
                      DataRow(cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          TextButton(
                            key: ValueKey(
                              'season-team-${season.standings[index].teamId}',
                            ),
                            onPressed: widget.onOpenTeam == null
                                ? null
                                : () => widget.onOpenTeam!(
                                      season.standings[index].teamId,
                                    ),
                            child: Text(
                              season.standings[index].abbreviation.isEmpty
                                  ? season.standings[index].teamId
                                  : season.standings[index].abbreviation,
                            ),
                          ),
                        ),
                        DataCell(Text(season.standings[index].recordLabel)),
                        DataCell(Text(
                          season.standings[index].winPct.toStringAsFixed(3),
                        )),
                        DataCell(Text(
                          season.standings[index].averagePointsFor
                              .toStringAsFixed(1),
                        )),
                        DataCell(Text(
                          season.standings[index].averagePointsAgainst
                              .toStringAsFixed(1),
                        )),
                        DataCell(Text(_signed(
                          season.standings[index].averageDifferential,
                        ))),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _games(NbaSeasonIntelligenceSnapshot season) => _Panel(
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
                      'SEASON GAME INVENTORY',
                      style: TextStyle(
                        color: _amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  Text(
                    '${season.regularSeasonGames} regular · ${season.playoffGames} playoffs',
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            if (!season.hasGames)
              const Padding(
                padding: EdgeInsets.all(26),
                child: Text(
                  'No canonical games exist in the selected season scope.',
                  style: TextStyle(color: _muted),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_panel2),
                  headingTextStyle: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                  dataTextStyle: const TextStyle(color: _text, fontSize: 9),
                  columns: const [
                    DataColumn(label: Text('DATE')),
                    DataColumn(label: Text('TYPE')),
                    DataColumn(label: Text('MATCHUP')),
                    DataColumn(label: Text('SCORE')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('GAME')),
                  ],
                  rows: [
                    for (final game in season.games.reversed.take(40))
                      DataRow(cells: [
                        DataCell(Text(
                          game.gameDate.isEmpty ? '—' : game.gameDate,
                        )),
                        DataCell(Text(
                          game.seasonType.isEmpty ? '—' : game.seasonType,
                        )),
                        DataCell(Text(game.matchupLabel)),
                        DataCell(Text(game.scoreLabel)),
                        DataCell(Text(game.status.isEmpty ? '—' : game.status)),
                        DataCell(
                          TextButton(
                            key: ValueKey('season-game-${game.gameId}'),
                            onPressed: widget.onOpenGame == null
                                ? null
                                : () => widget.onOpenGame!(
                                      game.gameId,
                                      game.matchupLabel,
                                    ),
                            child: const Text('Open'),
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _SeasonPersistentWorkflowControls extends StatefulWidget {
  const _SeasonPersistentWorkflowControls({
    super.key,
    required this.seed,
    required this.seasonId,
    required this.seasonType,
    required this.workflows,
  });

  final NbaTerminalSeedSnapshot seed;
  final String seasonId;
  final String seasonType;
  final NbaSeasonWorkflowService workflows;

  @override
  State<_SeasonPersistentWorkflowControls> createState() =>
      _SeasonPersistentWorkflowControlsState();
}

class _SeasonPersistentWorkflowControlsState
    extends State<_SeasonPersistentWorkflowControls> {
  late Future<bool> _watchedFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _watchedFuture = _loadWatched();
  }

  @override
  void didUpdateWidget(_SeasonPersistentWorkflowControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seasonId != widget.seasonId ||
        oldWidget.seasonType != widget.seasonType ||
        oldWidget.seed.assetPath != widget.seed.assetPath) {
      _watchedFuture = _loadWatched();
      _busy = false;
    }
  }

  Future<bool> _loadWatched() => widget.workflows.isWatched(
        widget.seed,
        seasonId: widget.seasonId,
        seasonType: widget.seasonType,
      );

  Future<void> _activateResearch() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final context = await widget.workflows.activateResearch(
        widget.seed,
        seasonId: widget.seasonId,
        seasonType: widget.seasonType,
      );
      if (!mounted) return;
      _notice('Season research context activated · ${context.scopeLabel}.');
    } catch (error) {
      if (mounted) _notice('Unable to activate season research context: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWatch() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final watched = await widget.workflows.toggleWatch(
        widget.seed,
        seasonId: widget.seasonId,
        seasonType: widget.seasonType,
      );
      if (!mounted) return;
      setState(() => _watchedFuture = Future.value(watched));
      _notice(
        watched
            ? 'Season added to NBA watchlist.'
            : 'Season removed from NBA watchlist.',
      );
    } catch (error) {
      if (mounted) _notice('Unable to update season watchlist: $error');
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
            key: const ValueKey('season-activate-research'),
            onPressed: _busy ? null : _activateResearch,
            icon: const Icon(Icons.manage_search_rounded, size: 15),
            label: const Text('RESEARCH CONTEXT'),
          ),
          FutureBuilder<bool>(
            future: _watchedFuture,
            builder: (context, snapshot) {
              final watched = snapshot.data == true;
              return OutlinedButton.icon(
                key: const ValueKey('season-toggle-watch'),
                onPressed: _busy ? null : _toggleWatch,
                icon: Icon(
                  watched ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 15,
                ),
                label: Text(watched ? 'UNWATCH SEASON' : 'WATCH SEASON'),
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
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NBA / SEASON',
              style: TextStyle(
                color: _amber,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(color: _muted, fontSize: 10, height: 1.45),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 8),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(color: _muted)),
            TextSpan(
              text: value,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );

Widget _pill(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );

String _signed(num value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}';

const nbaSeasonBackground = _bg;
