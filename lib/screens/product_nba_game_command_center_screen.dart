import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../services/nba_game_intelligence_engine.dart';
import '../services/nba_game_workflow_service.dart';
import '../services/nba_terminal_seed_repository.dart';

const _bg = Color(0xFF090D12);
const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);
const _red = Color(0xFFE57D7D);

typedef NbaGamePlayerOpenCallback = void Function(
  String playerId,
  String playerName,
);

class ProductNbaGameCommandCenterScreen extends StatefulWidget {
  const ProductNbaGameCommandCenterScreen({
    super.key,
    required this.gameId,
    this.loadSeed,
    this.onOpenTeam,
    this.onOpenPlayer,
  });

  final String gameId;
  final Future<NbaTerminalSeedSnapshot> Function()? loadSeed;
  final ValueChanged<String>? onOpenTeam;
  final NbaGamePlayerOpenCallback? onOpenPlayer;

  @override
  State<ProductNbaGameCommandCenterScreen> createState() =>
      _ProductNbaGameCommandCenterScreenState();
}

class _ProductNbaGameCommandCenterScreenState
    extends State<ProductNbaGameCommandCenterScreen> {
  final NbaGameIntelligenceEngine _engine = const NbaGameIntelligenceEngine();
  late Future<NbaTerminalSeedSnapshot> _seedFuture;

  @override
  void initState() {
    super.initState();
    _seedFuture = _load();
  }

  @override
  void didUpdateWidget(ProductNbaGameCommandCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId || oldWidget.loadSeed != widget.loadSeed) {
      _seedFuture = _load();
    }
  }

  Future<NbaTerminalSeedSnapshot> _load() =>
      widget.loadSeed?.call() ?? const NbaTerminalSeedRepository().load();

  void _refresh() {
    setState(() => _seedFuture = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: _seedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StatePanel(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _StatePanel(
            child: _ErrorState(
              title: 'Game data unavailable',
              detail: '${snapshot.error ?? 'The active NBA dataset could not be loaded.'}',
              onRetry: _refresh,
            ),
          );
        }

        NbaGameIntelligenceSnapshot game;
        try {
          game = _engine.build(seed: snapshot.data!, gameId: widget.gameId);
        } on NbaGameNotFoundException catch (error) {
          return _StatePanel(
            child: _ErrorState(
              title: 'Game outside active scope',
              detail: error.toString(),
              onRetry: _refresh,
            ),
          );
        } catch (error) {
          return _StatePanel(
            child: _ErrorState(
              title: 'Game intelligence could not be assembled',
              detail: '$error',
              onRetry: _refresh,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GameHero(
              game: game,
              onOpenTeam: widget.onOpenTeam,
            ),
            const SizedBox(height: 12),
            _GameWorkflowPanel(game: game),
            const SizedBox(height: 12),
            _CoveragePanel(game: game),
            if (game.integrityIssues.isNotEmpty) ...[
              const SizedBox(height: 12),
              _IntegrityPanel(issues: game.integrityIssues),
            ],
            const SizedBox(height: 12),
            _TeamComparisonPanel(game: game),
            if (game.periods.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PeriodPanel(game: game),
            ],
            const SizedBox(height: 12),
            _PlayerBoxScorePanel(
              game: game,
              onOpenPlayer: widget.onOpenPlayer,
            ),
            const SizedBox(height: 12),
            _ProvenancePanel(game: game),
          ],
        );
      },
    );
  }
}

class _GameWorkflowPanel extends StatefulWidget {
  const _GameWorkflowPanel({required this.game});

  final NbaGameIntelligenceSnapshot game;

  @override
  State<_GameWorkflowPanel> createState() => _GameWorkflowPanelState();
}

class _GameWorkflowPanelState extends State<_GameWorkflowPanel> {
  static const _workflows = NbaGameWorkflowService();
  late Future<bool> _watchedFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _watchedFuture = _workflows.isWatched(widget.game);
  }

  @override
  void didUpdateWidget(_GameWorkflowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.gameId != widget.game.gameId) {
      _watchedFuture = _workflows.isWatched(widget.game);
      _busy = false;
    }
  }

  void _route(String target) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      _notice('Shared RoutePayload state is unavailable in this shell.');
      return;
    }
    try {
      final payload = _workflows.route(
        controller,
        game: widget.game,
        targetRoute: target,
      );
      _notice('${payload.displayLabel} routed to $target.');
    } catch (error) {
      _notice('Unable to route game: $error');
    }
  }

  Future<void> _activateResearch() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final context = await _workflows.activateResearch(widget.game);
      if (!mounted) return;
      _notice(
        'Research context activated · ${context.scopeLabel}${context.entityLabel.isEmpty ? '' : ' · ${context.entityLabel}'}.',
      );
    } catch (error) {
      if (mounted) _notice('Unable to activate research context: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWatch() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final watched = await _workflows.toggleWatch(widget.game);
      if (!mounted) return;
      setState(() => _watchedFuture = Future.value(watched));
      _notice(watched ? 'Game added to NBA watchlist.' : 'Game removed from NBA watchlist.');
    } catch (error) {
      if (mounted) _notice('Unable to update watchlist: $error');
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
  Widget build(BuildContext context) {
    return _Panel(
      title: 'GAME WORKFLOWS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Publish this canonical game into shared terminal state, activate it as the current research object, or persist it in the cross-NBA entity watchlist.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('game-route-workspace'),
                onPressed: () => _route('Workspace'),
                icon: const Icon(Icons.grid_on_rounded, size: 17),
                label: const Text('Workspace'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('game-route-python'),
                onPressed: () => _route('Python Lab'),
                icon: const Icon(Icons.code_rounded, size: 17),
                label: const Text('Python Lab'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('game-route-compare'),
                onPressed: () => _route('Compare'),
                icon: const Icon(Icons.compare_arrows_rounded, size: 17),
                label: const Text('Compare'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('game-route-source-audit'),
                onPressed: () => _route('Source Audit'),
                icon: const Icon(Icons.fact_check_outlined, size: 17),
                label: const Text('Source Audit'),
              ),
              FilledButton.icon(
                key: const ValueKey('game-activate-research'),
                onPressed: _busy ? null : _activateResearch,
                icon: const Icon(Icons.bolt_rounded, size: 17),
                label: const Text('Activate research context'),
              ),
              FutureBuilder<bool>(
                future: _watchedFuture,
                builder: (context, snapshot) {
                  final watched = snapshot.data == true;
                  return OutlinedButton.icon(
                    key: const ValueKey('game-toggle-watch'),
                    onPressed: _busy ? null : _toggleWatch,
                    icon: Icon(
                      watched ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 17,
                    ),
                    label: Text(watched ? 'Watching' : 'Watch game'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameHero extends StatelessWidget {
  const _GameHero({required this.game, required this.onOpenTeam});

  final NbaGameIntelligenceSnapshot game;
  final ValueChanged<String>? onOpenTeam;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'NBA / GAME COMMAND CENTER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (game.status.isNotEmpty) ...[
                const SizedBox(width: 10),
                _Pill(
                  label: game.status.toUpperCase(),
                  color: _amber,
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 860;
              final away = _TeamScore(
                team: game.awayTeam,
                score: game.awayScore,
                winner: game.winnerTeamId == game.awayTeam.id,
                onOpen: onOpenTeam,
              );
              final home = _TeamScore(
                team: game.homeTeam,
                score: game.homeScore,
                winner: game.winnerTeamId == game.homeTeam.id,
                onOpen: onOpenTeam,
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    away,
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Text(
                          'AT',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    home,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: away),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'AT',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(child: home),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (game.gameDate.isNotEmpty) _Meta(Icons.calendar_today_rounded, game.gameDate),
              if (game.seasonId.isNotEmpty) _Meta(Icons.event_note_rounded, game.seasonId),
              if (game.seasonType.isNotEmpty) _Meta(Icons.category_outlined, game.seasonType),
              if (game.arena case final arena?) _Meta(Icons.stadium_outlined, arena),
              if (game.city case final city?) _Meta(Icons.location_on_outlined, city),
              _Meta(Icons.tag_rounded, game.gameId),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.team,
    required this.score,
    required this.winner,
    required this.onOpen,
  });

  final NbaGameTeam team;
  final int? score;
  final bool winner;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          team.abbreviation.isEmpty ? '—' : team.abbreviation,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: winner ? _green : _text,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          team.name.isEmpty ? 'Unknown team' : team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
        ),
      ],
    );
    return Row(
      children: [
        Expanded(
          child: onOpen == null || team.id.isEmpty
              ? content
              : InkWell(
                  onTap: () => onOpen!(team.id),
                  child: content,
                ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 0,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              score?.toString() ?? '—',
              style: TextStyle(
                color: winner ? _green : _text,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.game});
  final NbaGameIntelligenceSnapshot game;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'DATA COVERAGE',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CoveragePill('Scoreboard', game.coverage.scoreboard),
            _CoveragePill('Team box', game.coverage.teamBoxScore),
            _CoveragePill('Player box', game.coverage.playerBoxScore),
            _CoveragePill('Period scoring', game.coverage.periodScoring),
            _CoveragePill('Source metadata', game.coverage.sourceMetadata),
            if (game.coverage.usedCompatibilityJoin)
              const _Pill(label: 'COMPATIBILITY JOIN', color: _amber),
          ],
        ),
      );
}

class _IntegrityPanel extends StatelessWidget {
  const _IntegrityPanel({required this.issues});
  final List<NbaGameIntegrityIssue> issues;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'INTEGRITY',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      issue.severity == NbaGameIntegritySeverity.blocking
                          ? Icons.error_rounded
                          : Icons.warning_amber_rounded,
                      size: 17,
                      color: issue.severity == NbaGameIntegritySeverity.blocking
                          ? _red
                          : _amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issue.code.replaceAll('-', ' '),
                        style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _TeamComparisonPanel extends StatelessWidget {
  const _TeamComparisonPanel({required this.game});
  final NbaGameIntelligenceSnapshot game;

  @override
  Widget build(BuildContext context) {
    final away = game.awayTeamLine;
    final home = game.homeTeamLine;
    if (away == null || home == null) {
      return const _Panel(
        title: 'TEAM COMPARISON',
        child: _Unavailable(
          'A complete two-team box score is not available in the active dataset.',
        ),
      );
    }
    return _Panel(
      title: 'TEAM COMPARISON',
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 840,
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(220),
              1: FixedColumnWidth(110),
              2: FixedColumnWidth(110),
            },
            border: const TableBorder(
              horizontalInside: BorderSide(color: _line, width: .5),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _panel2),
                children: [
                  const _TableHead('METRIC'),
                  _TableHead(game.awayTeam.abbreviation),
                  _TableHead(game.homeTeam.abbreviation),
                ],
              ),
              _metricRow('PTS', away.points, home.points),
              _metricRow('REB', away.rebounds, home.rebounds),
              _metricRow('AST', away.assists, home.assists),
              _metricRow('STL', away.steals, home.steals),
              _metricRow('BLK', away.blocks, home.blocks),
              _metricRow('TOV', away.turnovers, home.turnovers),
              _metricRow('FG', _madeAttempted(away.fieldGoalsMade, away.fieldGoalsAttempted), _madeAttempted(home.fieldGoalsMade, home.fieldGoalsAttempted)),
              _metricRow('3PT', _madeAttempted(away.threePointersMade, away.threePointersAttempted), _madeAttempted(home.threePointersMade, home.threePointersAttempted)),
              _metricRow('FT', _madeAttempted(away.freeThrowsMade, away.freeThrowsAttempted), _madeAttempted(home.freeThrowsMade, home.freeThrowsAttempted)),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _metricRow(String label, Object? away, Object? home) => TableRow(
        children: [
          _TableCell(label, strong: true),
          _TableCell('${away ?? '—'}'),
          _TableCell('${home ?? '—'}'),
        ],
      );
}

class _PeriodPanel extends StatelessWidget {
  const _PeriodPanel({required this.game});
  final NbaGameIntelligenceSnapshot game;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'PERIOD SCORING',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final period in game.periods)
              Container(
                width: 116,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _panel2,
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.label,
                      style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${game.awayTeam.abbreviation} ${period.awayScore ?? '—'}',
                      style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${game.homeTeam.abbreviation} ${period.homeScore ?? '—'}',
                      style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _PlayerBoxScorePanel extends StatelessWidget {
  const _PlayerBoxScorePanel({required this.game, required this.onOpenPlayer});

  final NbaGameIntelligenceSnapshot game;
  final NbaGamePlayerOpenCallback? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    if (game.playerLines.isEmpty) {
      return const _Panel(
        title: 'PLAYER BOX SCORE',
        child: _Unavailable(
          'Player game lines are not available for this game in the active dataset.',
        ),
      );
    }
    return _Panel(
      title: 'PLAYER BOX SCORE',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _PlayerTeamTable(
            team: game.awayTeam,
            lines: game.awayPlayers,
            onOpenPlayer: onOpenPlayer,
          ),
          const Divider(height: 1, color: _line),
          _PlayerTeamTable(
            team: game.homeTeam,
            lines: game.homePlayers,
            onOpenPlayer: onOpenPlayer,
          ),
        ],
      ),
    );
  }
}

class _PlayerTeamTable extends StatelessWidget {
  const _PlayerTeamTable({
    required this.team,
    required this.lines,
    required this.onOpenPlayer,
  });

  final NbaGameTeam team;
  final List<NbaGamePlayerLine> lines;
  final NbaGamePlayerOpenCallback? onOpenPlayer;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1050,
          child: Table(
            columnWidths: const {0: FixedColumnWidth(210)},
            border: const TableBorder(
              horizontalInside: BorderSide(color: _line, width: .5),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _panel2),
                children: const [
                  _TableHead('PLAYER'),
                  _TableHead('MIN'),
                  _TableHead('PTS'),
                  _TableHead('REB'),
                  _TableHead('AST'),
                  _TableHead('STL'),
                  _TableHead('BLK'),
                  _TableHead('TOV'),
                  _TableHead('FG'),
                  _TableHead('3PT'),
                  _TableHead('FT'),
                  _TableHead('+/-'),
                ],
              ),
              for (final line in lines)
                TableRow(
                  children: [
                    _PlayerCell(line: line, onOpenPlayer: onOpenPlayer),
                    _TableCell(line.minutes.isEmpty ? '—' : line.minutes),
                    _TableCell('${line.points ?? '—'}'),
                    _TableCell('${line.rebounds ?? '—'}'),
                    _TableCell('${line.assists ?? '—'}'),
                    _TableCell('${line.steals ?? '—'}'),
                    _TableCell('${line.blocks ?? '—'}'),
                    _TableCell('${line.turnovers ?? '—'}'),
                    _TableCell(_madeAttempted(line.fieldGoalsMade, line.fieldGoalsAttempted)),
                    _TableCell(_madeAttempted(line.threePointersMade, line.threePointersAttempted)),
                    _TableCell(_madeAttempted(line.freeThrowsMade, line.freeThrowsAttempted)),
                    _TableCell(line.plusMinus == null ? '—' : _signed(line.plusMinus!)),
                  ],
                ),
            ],
          ),
        ),
      );
}

class _PlayerCell extends StatelessWidget {
  const _PlayerCell({required this.line, required this.onOpenPlayer});
  final NbaGamePlayerLine line;
  final NbaGamePlayerOpenCallback? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    final label = line.playerName.isEmpty ? line.playerId : line.playerName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: onOpenPlayer == null || line.playerId.isEmpty
          ? Text(label, style: const TextStyle(color: _text, fontWeight: FontWeight.w800))
          : InkWell(
              onTap: () => onOpenPlayer!(line.playerId, label),
              child: Text(label, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900)),
            ),
    );
  }
}

class _ProvenancePanel extends StatelessWidget {
  const _ProvenancePanel({required this.game});
  final NbaGameIntelligenceSnapshot game;

  @override
  Widget build(BuildContext context) {
    final provenance = game.provenance;
    return _Panel(
      title: 'SOURCE & PROVENANCE',
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          _ProvenanceItem('Dataset', provenance.datasetStatus),
          _ProvenanceItem('Validation', provenance.validationStatus),
          _ProvenanceItem('Release', provenance.releaseId ?? '—'),
          _ProvenanceItem('Version', provenance.releaseVersion ?? '—'),
          _ProvenanceItem('Asset path', provenance.assetPath.isEmpty ? '—' : provenance.assetPath),
          _ProvenanceItem('Sources', provenance.sourceIds.isEmpty ? '—' : provenance.sourceIds.join(', ')),
          _ProvenanceItem('As of', provenance.asOfValues.isEmpty ? '—' : provenance.asOfValues.join(', ')),
          _ProvenanceItem('Context', provenance.historicalContext ? 'Historical' : 'Current'),
          if (provenance.usedFallbackDataset)
            const _Pill(label: 'FALLBACK DATASET', color: _amber),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.padding = const EdgeInsets.all(14)});
  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
              child: Text(
                title,
                style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7),
              ),
            ),
            const Divider(height: 1, color: _line),
            Padding(padding: padding, child: child),
          ],
        ),
      );
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 320),
        color: _bg,
        padding: const EdgeInsets.all(22),
        child: child,
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.detail, required this.onRetry});
  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_basketball_outlined, size: 42, color: _muted),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _CoveragePill extends StatelessWidget {
  const _CoveragePill(this.label, this.available);
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) => _Pill(
        label: '${available ? 'AVAILABLE' : 'UNAVAILABLE'} · ${label.toUpperCase()}',
        color: available ? _green : _muted,
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _muted),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _muted, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: _muted, height: 1.4))),
        ],
      );
}

class _ProvenanceItem extends StatelessWidget {
  const _ProvenanceItem(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _TableHead extends StatelessWidget {
  const _TableHead(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w900)),
      );
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.label, {this.strong = false});
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(label, style: TextStyle(color: _text, fontSize: 11, fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
      );
}

String _madeAttempted(int? made, int? attempted) {
  if (made == null && attempted == null) return '—';
  return '${made ?? '—'}-${attempted ?? '—'}';
}

String _signed(num value) => value > 0 ? '+$value' : '$value';
