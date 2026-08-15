import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../services/nba_entity_intelligence_repository.dart';
import '../services/nba_player_career_analytics_engine.dart';
import '../services/nba_player_career_context_engine.dart';
import '../services/nba_player_career_engine.dart';
import '../services/nba_player_career_workflow_service.dart';
import '../widgets/nba_terminal_trend_chart.dart';

const _pcBg = Color(0xFF090D12);
const _pcPanel = Color(0xFF0F151C);
const _pcPanel2 = Color(0xFF141C25);
const _pcLine = Color(0xFF263342);
const _pcText = Color(0xFFE8EDF3);
const _pcMuted = Color(0xFF8895A5);
const _pcBlue = Color(0xFF63A9FF);
const _pcGreen = Color(0xFF69C99A);
const _pcAmber = Color(0xFFE2B866);

typedef NbaPlayerCareerPayloadLoader = Future<Map<String, dynamic>> Function(
  String seasonType,
);
typedef NbaPlayerCareerTeamDossierLoader = Future<Map<String, dynamic>> Function(
  String teamKey,
);
typedef NbaPlayerCareerGameOpenCallback = void Function(
  String gameKey,
  String gameLabel,
  String seasonId,
);

class ProductNbaPlayerCareerScreen extends StatefulWidget {
  const ProductNbaPlayerCareerScreen({
    super.key,
    required this.playerKey,
    this.playerLabel = 'NBA Player',
    this.league = 'NBA',
    this.initialSeasonType = 'regular',
    this.loadPlayer,
    this.loadTeamDossier,
    this.workflowService = const NbaPlayerCareerWorkflowService(),
    this.onOpenTeam,
    this.onOpenFranchise,
    this.onOpenSeason,
    this.onOpenGame,
  });

  final String playerKey;
  final String playerLabel;
  final String league;
  final String initialSeasonType;
  final NbaPlayerCareerPayloadLoader? loadPlayer;
  final NbaPlayerCareerTeamDossierLoader? loadTeamDossier;
  final NbaPlayerCareerWorkflowService workflowService;
  final ValueChanged<String>? onOpenTeam;
  final ValueChanged<String>? onOpenFranchise;
  final ValueChanged<String>? onOpenSeason;
  final NbaPlayerCareerGameOpenCallback? onOpenGame;

  @override
  State<ProductNbaPlayerCareerScreen> createState() =>
      _ProductNbaPlayerCareerScreenState();
}

class _LoadedPlayerCareer {
  const _LoadedPlayerCareer({
    required this.career,
    required this.context,
  });

  final NbaPlayerCareerSnapshot career;
  final NbaPlayerCareerContext context;
}

class _ProductNbaPlayerCareerScreenState
    extends State<ProductNbaPlayerCareerScreen> {
  late String _seasonType;
  NbaPlayerCareerMetric _metric = NbaPlayerCareerMetric.pointsPerGame;
  int _rollingWindow = 3;
  late Future<_LoadedPlayerCareer> _future;

  @override
  void initState() {
    super.initState();
    _seasonType = _normalizeSeasonType(widget.initialSeasonType);
    _future = _load();
  }

  @override
  void didUpdateWidget(ProductNbaPlayerCareerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerKey != widget.playerKey ||
        oldWidget.league != widget.league ||
        oldWidget.loadPlayer != widget.loadPlayer ||
        oldWidget.loadTeamDossier != widget.loadTeamDossier) {
      _future = _load();
    }
  }

  String _normalizeSeasonType(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'playoffs' ? 'playoffs' : 'regular';
  }

  Future<_LoadedPlayerCareer> _load() async {
    final repository = const NbaEntityIntelligenceRepository();
    final payload = await (widget.loadPlayer?.call(_seasonType) ??
        repository.playerDossier(
          widget.playerKey,
          league: widget.league,
          seasonType: _seasonType,
          recentGames: 50,
        ));
    final teamKeys = <String>{};
    final seasonRows = payload['seasons'];
    if (seasonRows is List) {
      for (final raw in seasonRows) {
        if (raw is! Map) continue;
        final key = raw['team_key']?.toString().trim() ?? '';
        if (key.isNotEmpty) teamKeys.add(key);
      }
    }
    final gameRows = payload['recent_games'];
    if (gameRows is List) {
      for (final raw in gameRows) {
        if (raw is! Map) continue;
        for (final field in const ['team_key', 'opponent_team_key']) {
          final key = raw[field]?.toString().trim() ?? '';
          if (key.isNotEmpty) teamKeys.add(key);
        }
      }
    }

    final teamDossiers = <String, Map<String, dynamic>>{};
    final loader = widget.loadTeamDossier ??
        (String teamKey) => repository.teamDossier(
              teamKey,
              league: widget.league,
              seasonType: 'regular',
              recentGames: 0,
            );
    for (final key in teamKeys) {
      try {
        teamDossiers[key] = await loader(key);
      } catch (_) {
        // Missing Team dossiers remain explicit career coverage gaps.
      }
    }
    final career = const NbaPlayerCareerEngine().build(
      payload,
      playerKey: widget.playerKey,
      teamDossiers: teamDossiers,
    );
    return _LoadedPlayerCareer(
      career: career,
      context: const NbaPlayerCareerContextEngine().build(payload),
    );
  }

  void _changeSeasonType(String value) {
    final normalized = _normalizeSeasonType(value);
    if (normalized == _seasonType) return;
    setState(() {
      _seasonType = normalized;
      _future = _load();
    });
  }

  void _route(_LoadedPlayerCareer loaded, String target) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      _notice('Shared RoutePayload state is unavailable in this shell.');
      return;
    }
    final payload = widget.workflowService.package(
      career: loaded.career,
      context: loaded.context,
      targetRoute: target,
      league: widget.league,
      seasonType: _seasonType,
    );
    controller.setActivePayload(
      payload,
      origin: 'NBA Player Career · ${loaded.career.playerName}',
    );
    _notice('${payload.displayLabel} routed to $target.');
  }

  void _notice(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LoadedPlayerCareer>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CareerPanel(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _CareerPanel(
              child: Text(
                'Player career unavailable: ${snapshot.error}',
                style: const TextStyle(color: _pcMuted),
              ),
            );
          }
          final loaded = snapshot.data!;
          final career = loaded.career;
          if (!career.available) {
            return const _CareerPanel(
              child: Text(
                'The historical source returned no usable canonical Player identity.',
                style: TextStyle(color: _pcMuted),
              ),
            );
          }
          final analytics = const NbaPlayerCareerAnalyticsEngine().build(
            career,
            metric: _metric,
            rollingWindow: _rollingWindow,
          );
          return Column(
            key: ValueKey('nba-player-career-${career.playerKey}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(career),
              const SizedBox(height: 12),
              _workflows(loaded),
              const SizedBox(height: 12),
              _overview(career, loaded.context),
              const SizedBox(height: 12),
              _analytics(career, analytics),
              const SizedBox(height: 12),
              _tenure(career),
              const SizedBox(height: 12),
              _seasonHistory(career),
              const SizedBox(height: 12),
              _awardsAndAllStar(loaded.context),
              const SizedBox(height: 12),
              _draft(loaded.context),
              const SizedBox(height: 12),
              _recentGames(loaded.context),
              const SizedBox(height: 12),
              _sourceBoundary(career, loaded.context),
            ],
          );
        },
      );

  Widget _hero(NbaPlayerCareerSnapshot career) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _pcPanel,
          border: Border.all(color: _pcLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NBA / HISTORICAL PLAYER CAREER',
              style: TextStyle(
                color: _pcBlue,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              career.playerName,
              style: const TextStyle(
                color: _pcText,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${career.primaryPosition.isEmpty ? 'POSITION NOT EXPOSED' : career.primaryPosition} · ${career.careerRangeLabel} · ${_seasonType.toUpperCase()}',
              style: const TextStyle(color: _pcMuted, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'Canonical career history across source-backed seasons, Team and Franchise tenure where identity is explicit, career trends, awards, All-Star rows, draft provenance, recent Games and shared analyst workflows. Multi-team stints, accolades and lineage are never reconstructed from surrounding statistics.',
              style: TextStyle(color: _pcMuted, height: 1.45),
            ),
          ],
        ),
      );

  Widget _workflows(_LoadedPlayerCareer loaded) => _CareerPanel(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              key: const ValueKey('player-career-season-type'),
              value: _seasonType,
              dropdownColor: _pcPanel2,
              style: const TextStyle(color: _pcText),
              items: const [
                DropdownMenuItem(value: 'regular', child: Text('REGULAR SEASON')),
                DropdownMenuItem(value: 'playoffs', child: Text('PLAYOFFS')),
              ],
              onChanged: (value) {
                if (value != null) _changeSeasonType(value);
              },
            ),
            _routeButton(loaded, 'Workspace', 'player-career-route-workspace'),
            _routeButton(loaded, 'Python Lab', 'player-career-route-python'),
            _routeButton(loaded, 'Compare', 'player-career-route-compare'),
            _routeButton(loaded, 'Source Audit', 'player-career-route-source-audit'),
            _PlayerCareerPersistentControls(
              career: loaded.career,
              workflows: widget.workflowService,
              league: widget.league,
              seasonType: _seasonType,
            ),
          ],
        ),
      );

  Widget _routeButton(
    _LoadedPlayerCareer loaded,
    String target,
    String key,
  ) =>
      OutlinedButton(
        key: ValueKey(key),
        onPressed: () => _route(loaded, target),
        child: Text(target.toUpperCase()),
      );

  Widget _overview(
    NbaPlayerCareerSnapshot career,
    NbaPlayerCareerContext context,
  ) =>
      _CareerPanel(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _kpi('CAREER RANGE', career.careerRangeLabel),
            _kpi('SEASON ROWS', '${career.seasons.length}'),
            _kpi('TEAM TENURES', '${career.tenures.length}'),
            _kpi('GAMES', _formatTotal(career.careerGames)),
            _kpi('POINTS', _formatTotal(career.careerPoints)),
            _kpi('REBOUNDS', _formatTotal(career.careerRebounds)),
            _kpi('ASSISTS', _formatTotal(career.careerAssists)),
            _kpi('AWARD ROWS', '${context.awards.length}'),
            _kpi('ALL-STAR ROWS', '${context.allStarSelections.length}'),
            _kpi('CONFLICTS', '${career.materialConflictCount}'),
          ],
        ),
      );

  Widget _analytics(
    NbaPlayerCareerSnapshot career,
    NbaPlayerCareerAnalyticsResult analytics,
  ) =>
      _CareerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CAREER TREND & DISTRIBUTION',
              style: TextStyle(
                color: _pcBlue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<NbaPlayerCareerMetric>(
                  key: const ValueKey('player-career-metric'),
                  value: _metric,
                  dropdownColor: _pcPanel2,
                  style: const TextStyle(color: _pcText),
                  items: [
                    for (final metric in NbaPlayerCareerMetric.values)
                      DropdownMenuItem(
                        value: metric,
                        child: Text(metric.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _metric = value);
                  },
                ),
                DropdownButton<int>(
                  key: const ValueKey('player-career-rolling-window'),
                  value: _rollingWindow,
                  dropdownColor: _pcPanel2,
                  style: const TextStyle(color: _pcText),
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2-YEAR ROLLING')),
                    DropdownMenuItem(value: 3, child: Text('3-YEAR ROLLING')),
                    DropdownMenuItem(value: 5, child: Text('5-YEAR ROLLING')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _rollingWindow = value);
                  },
                ),
                _kpi('OBSERVED', '${analytics.distribution.observed}'),
                _kpi('GAPS', '${analytics.distribution.missing}'),
                _kpi('MEAN', _formatMetric(analytics.distribution.mean)),
                _kpi('MEDIAN', _formatMetric(analytics.distribution.median)),
                _kpi(
                  'PEAK',
                  analytics.peakSeason == null
                      ? '—'
                      : '${analytics.peakSeason!.seasonId} · ${_formatMetric(analytics.peakSeason!.value)}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            NbaTerminalTrendChart(
              metricLabel: _metric.label,
              points: [
                for (final point in analytics.points)
                  NbaTerminalTrendPoint(
                    label: point.seasonId,
                    value: point.value,
                    rollingValue: point.rollingValue,
                  ),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'Observed season values only. Rolling values require a complete source-backed window; missing seasons are rendered as gaps and are not imputed.',
              style: TextStyle(color: _pcMuted, fontSize: 9, height: 1.4),
            ),
          ],
        ),
      );

  Widget _tenure(NbaPlayerCareerSnapshot career) => _CareerPanel(
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
                      'TEAM / FRANCHISE TENURE',
                      style: TextStyle(
                        color: _pcAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    career.tenureCoverageLabel,
                    style: const TextStyle(color: _pcMuted, fontSize: 8),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _pcLine),
            if (career.tenures.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No explicit Team tenure rows are available in this Player career scope.',
                  style: TextStyle(color: _pcMuted),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_pcPanel2),
                  columns: const [
                    DataColumn(label: Text('SEASONS')),
                    DataColumn(label: Text('TEAM')),
                    DataColumn(label: Text('FRANCHISE')),
                    DataColumn(label: Text('YEARS')),
                    DataColumn(label: Text('GAMES')),
                    DataColumn(label: Text('POINTS')),
                  ],
                  rows: [
                    for (final tenure in career.tenures)
                      DataRow(cells: [
                        DataCell(Text(tenure.seasonRangeLabel)),
                        DataCell(
                          TextButton(
                            key: ValueKey('career-team-${tenure.teamKey}'),
                            onPressed: widget.onOpenTeam == null
                                ? null
                                : () => widget.onOpenTeam!(tenure.teamKey),
                            child: Text(tenure.teamName),
                          ),
                        ),
                        DataCell(
                          tenure.franchiseKey.isEmpty
                              ? const Text('NOT EXPOSED')
                              : TextButton(
                                  key: ValueKey(
                                    'career-franchise-${tenure.franchiseKey}',
                                  ),
                                  onPressed: widget.onOpenFranchise == null
                                      ? null
                                      : () => widget.onOpenFranchise!(
                                            tenure.franchiseKey,
                                          ),
                                  child: Text(
                                    tenure.franchiseName.isEmpty
                                        ? tenure.franchiseKey
                                        : tenure.franchiseName,
                                  ),
                                ),
                        ),
                        DataCell(Text('${tenure.seasons}')),
                        DataCell(Text(_formatTotal(tenure.games))),
                        DataCell(Text(_formatTotal(tenure.points))),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _seasonHistory(NbaPlayerCareerSnapshot career) => _CareerPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'SEASON-BY-SEASON CAREER',
                style: TextStyle(
                  color: _pcAmber,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Divider(height: 1, color: _pcLine),
            if (career.seasons.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No source-backed season rows are exposed for this Player.',
                  style: TextStyle(color: _pcMuted),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_pcPanel2),
                  columns: const [
                    DataColumn(label: Text('SEASON')),
                    DataColumn(label: Text('TEAM')),
                    DataColumn(label: Text('GP')),
                    DataColumn(label: Text('PPG')),
                    DataColumn(label: Text('RPG')),
                    DataColumn(label: Text('APG')),
                    DataColumn(label: Text('TS%')),
                    DataColumn(label: Text('PER')),
                    DataColumn(label: Text('WS')),
                    DataColumn(label: Text('BPM')),
                    DataColumn(label: Text('VORP')),
                  ],
                  rows: [
                    for (final season in career.seasons.reversed)
                      DataRow(cells: [
                        DataCell(
                          TextButton(
                            key: ValueKey('career-season-${season.seasonId}'),
                            onPressed: widget.onOpenSeason == null
                                ? null
                                : () => widget.onOpenSeason!(season.seasonId),
                            child: Text(season.seasonId),
                          ),
                        ),
                        DataCell(
                          season.teamKey.isEmpty
                              ? Text(season.teamLabel)
                              : TextButton(
                                  onPressed: widget.onOpenTeam == null
                                      ? null
                                      : () => widget.onOpenTeam!(season.teamKey),
                                  child: Text(season.teamLabel),
                                ),
                        ),
                        DataCell(Text(_formatTotal(season.games))),
                        DataCell(Text(_formatMetric(season.pointsPerGame))),
                        DataCell(Text(_formatMetric(season.reboundsPerGame))),
                        DataCell(Text(_formatMetric(season.assistsPerGame))),
                        DataCell(Text(
                          season.trueShootingPct == null
                              ? '—'
                              : '${(season.trueShootingPct! * 100).toStringAsFixed(1)}%',
                        )),
                        DataCell(Text(_formatMetric(season.playerEfficiencyRating))),
                        DataCell(Text(_formatMetric(season.winShares))),
                        DataCell(Text(_formatMetric(season.boxPlusMinus))),
                        DataCell(Text(_formatMetric(season.valueOverReplacement))),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _awardsAndAllStar(NbaPlayerCareerContext context) => _CareerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AWARDS & ALL-STAR EVIDENCE',
              style: TextStyle(
                color: _pcAmber,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (!context.hasAwards && !context.hasAllStar)
              const Text(
                'No award or All-Star rows are attached to this canonical Player dossier.',
                style: TextStyle(color: _pcMuted),
              ),
            for (final award in context.awards.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(award.award, style: const TextStyle(color: _pcText)),
                subtitle: Text(
                  [
                    if (award.seasonId.isNotEmpty) award.seasonId,
                    if (award.result.isNotEmpty) award.result,
                    if (award.rank != null) 'rank ${award.rank!.toStringAsFixed(0)}',
                    if (award.votes != null) 'votes ${award.votes!.toStringAsFixed(0)}',
                  ].join(' · '),
                  style: const TextStyle(color: _pcMuted),
                ),
                trailing: award.seasonId.isEmpty || widget.onOpenSeason == null
                    ? null
                    : TextButton(
                        onPressed: () => widget.onOpenSeason!(award.seasonId),
                        child: const Text('SEASON'),
                      ),
              ),
            for (final selection in context.allStarSelections.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.star_rounded, color: _pcBlue, size: 18),
                title: Text(
                  selection.selection.isEmpty
                      ? 'All-Star selection'
                      : selection.selection,
                  style: const TextStyle(color: _pcText),
                ),
                subtitle: Text(
                  [
                    selection.seasonId,
                    if (selection.conference.isNotEmpty) selection.conference,
                    if (selection.starter != null)
                      selection.starter! ? 'starter' : 'non-starter',
                  ].join(' · '),
                  style: const TextStyle(color: _pcMuted),
                ),
              ),
          ],
        ),
      );

  Widget _draft(NbaPlayerCareerContext context) => _CareerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DRAFT PROVENANCE',
              style: TextStyle(
                color: _pcAmber,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (!context.hasDraft)
              const Text(
                'No canonical draft row is attached to this Player dossier.',
                style: TextStyle(color: _pcMuted),
              ),
            for (final draft in context.draftRecords)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  [
                    draft.draftYear?.toString() ?? 'YEAR NOT EXPOSED',
                    draft.round == null ? 'ROUND NOT EXPOSED' : 'Round ${draft.round}',
                    draft.pick == null ? 'PICK NOT EXPOSED' : 'Pick ${draft.pick}',
                  ].join(' · '),
                  style: const TextStyle(color: _pcText),
                ),
                subtitle: Text(
                  draft.teamLabel.isEmpty ? 'TEAM NOT EXPOSED' : draft.teamLabel,
                  style: const TextStyle(color: _pcMuted),
                ),
                trailing: draft.teamKey.isEmpty || widget.onOpenTeam == null
                    ? null
                    : TextButton(
                        key: ValueKey('career-draft-team-${draft.teamKey}'),
                        onPressed: () => widget.onOpenTeam!(draft.teamKey),
                        child: const Text('TEAM'),
                      ),
              ),
          ],
        ),
      );

  Widget _recentGames(NbaPlayerCareerContext context) => _CareerPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'RECENT SOURCE-BACKED GAMES',
                style: TextStyle(
                  color: _pcAmber,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Divider(height: 1, color: _pcLine),
            if (!context.hasGames)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No canonical Player Game rows are exposed by this dossier.',
                  style: TextStyle(color: _pcMuted),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_pcPanel2),
                  columns: const [
                    DataColumn(label: Text('DATE')),
                    DataColumn(label: Text('GAME')),
                    DataColumn(label: Text('PTS')),
                    DataColumn(label: Text('REB')),
                    DataColumn(label: Text('AST')),
                    DataColumn(label: Text('MIN')),
                  ],
                  rows: [
                    for (final game in context.recentGames)
                      DataRow(cells: [
                        DataCell(Text(game.gameDate.isEmpty ? '—' : game.gameDate)),
                        DataCell(
                          TextButton(
                            key: ValueKey('career-game-${game.gameKey}'),
                            onPressed: widget.onOpenGame == null
                                ? null
                                : () => widget.onOpenGame!(
                                      game.gameKey,
                                      game.matchupLabel,
                                      game.seasonId,
                                    ),
                            child: Text(game.matchupLabel),
                          ),
                        ),
                        DataCell(Text(_formatTotal(game.points))),
                        DataCell(Text(_formatTotal(game.rebounds))),
                        DataCell(Text(_formatTotal(game.assists))),
                        DataCell(Text(_formatMetric(game.minutes))),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _sourceBoundary(
    NbaPlayerCareerSnapshot career,
    NbaPlayerCareerContext context,
  ) =>
      _CareerPanel(
        key: const ValueKey('player-career-source-boundary'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SOURCE & IDENTITY BOUNDARY',
              style: TextStyle(
                color: _pcAmber,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Identity rows ${context.identityRows} · field-provenance rows ${context.fieldProvenanceRows} · material conflicts ${career.materialConflictCount}',
              style: const TextStyle(color: _pcMuted, height: 1.4),
            ),
            const SizedBox(height: 5),
            Text(
              'Tenure: ${career.tenureCoverageLabel}',
              style: const TextStyle(color: _pcMuted, height: 1.4),
            ),
            const SizedBox(height: 5),
            Text(
              'Context: ${context.sourceBoundaryLabel}',
              style: const TextStyle(color: _pcMuted, height: 1.4),
            ),
            if (career.multiTeamAggregateSeasons.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Multi-team aggregate seasons without explicit stint identity: ${career.multiTeamAggregateSeasons.join(', ')}. These rows remain career totals only and are not assigned to a Team or Franchise.',
                style: const TextStyle(color: _pcMuted, height: 1.4),
              ),
            ],
          ],
        ),
      );

  String _formatMetric(double? value) =>
      value == null ? '—' : value.toStringAsFixed(1);

  String _formatTotal(double? value) =>
      value == null ? '—' : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

  Widget _kpi(String label, String value) => Container(
        constraints: const BoxConstraints(minWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _pcPanel2,
          border: Border.all(color: _pcLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _pcMuted,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: _pcText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _PlayerCareerPersistentControls extends StatefulWidget {
  const _PlayerCareerPersistentControls({
    required this.career,
    required this.workflows,
    required this.league,
    required this.seasonType,
  });

  final NbaPlayerCareerSnapshot career;
  final NbaPlayerCareerWorkflowService workflows;
  final String league;
  final String seasonType;

  @override
  State<_PlayerCareerPersistentControls> createState() =>
      _PlayerCareerPersistentControlsState();
}

class _PlayerCareerPersistentControlsState
    extends State<_PlayerCareerPersistentControls> {
  late Future<bool> _watched;

  @override
  void initState() {
    super.initState();
    _watched = widget.workflows.isWatched(
      widget.career,
      league: widget.league,
    );
  }

  @override
  void didUpdateWidget(_PlayerCareerPersistentControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.career.playerKey != widget.career.playerKey ||
        oldWidget.league != widget.league) {
      _watched = widget.workflows.isWatched(
        widget.career,
        league: widget.league,
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _watched,
        builder: (context, snapshot) {
          final watched = snapshot.data ?? false;
          return Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('player-career-research'),
                onPressed: () async {
                  try {
                    await widget.workflows.activateResearch(
                      widget.career,
                      league: widget.league,
                      seasonType: widget.seasonType,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('Historical Player research context activated.')),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(content: Text('Research context unavailable: $error')),
                    );
                  }
                },
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('RESEARCH'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('player-career-watch'),
                onPressed: () async {
                  final next = await widget.workflows.toggleWatch(
                    widget.career,
                    league: widget.league,
                  );
                  if (!mounted) return;
                  setState(() => _watched = Future.value(next));
                },
                icon: Icon(
                  watched ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 16,
                ),
                label: Text(watched ? 'WATCHING' : 'WATCH'),
              ),
            ],
          );
        },
      );
}

class _CareerPanel extends StatelessWidget {
  const _CareerPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: _pcPanel,
          border: Border.all(color: _pcLine),
        ),
        child: child,
      );
}

const nbaPlayerCareerBackground = _pcBg;
