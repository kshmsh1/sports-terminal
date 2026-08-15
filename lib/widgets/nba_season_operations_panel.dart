import 'package:flutter/material.dart';

import '../services/nba_entity_intelligence_repository.dart';
import '../services/nba_season_all_star_engine.dart';
import '../services/nba_season_awards_voting_engine.dart';
import '../services/nba_season_draft_class_engine.dart';
import '../services/nba_season_leader_matrix_engine.dart';
import '../services/nba_season_player_leader_engine.dart';
import '../services/nba_season_rest_density_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _bg = Color(0xFF0F151C);
const _panel = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _amber = Color(0xFFE2B866);
const _green = Color(0xFF69C99A);

typedef NbaSeasonOperationsContextLoader = Future<Map<String, dynamic>> Function();

class NbaSeasonOperationsPanel extends StatefulWidget {
  const NbaSeasonOperationsPanel({
    super.key,
    required this.seed,
    required this.seasonId,
    required this.seasonType,
    this.league = 'NBA',
    this.loadContext,
    this.onOpenPlayer,
    this.onOpenTeam,
  });

  final NbaTerminalSeedSnapshot seed;
  final String seasonId;
  final String seasonType;
  final String league;
  final NbaSeasonOperationsContextLoader? loadContext;
  final void Function(String playerId, String playerName)? onOpenPlayer;
  final ValueChanged<String>? onOpenTeam;

  @override
  State<NbaSeasonOperationsPanel> createState() =>
      _NbaSeasonOperationsPanelState();
}

class _NbaSeasonOperationsPanelState extends State<NbaSeasonOperationsPanel> {
  late Future<Map<String, dynamic>> _contextFuture;
  int _topPerMetric = 5;
  double _minimumGames = 0;

  @override
  void initState() {
    super.initState();
    _contextFuture = _loadContext();
  }

  @override
  void didUpdateWidget(NbaSeasonOperationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seasonId != widget.seasonId ||
        oldWidget.seasonType != widget.seasonType ||
        oldWidget.league != widget.league ||
        oldWidget.loadContext != widget.loadContext) {
      _contextFuture = _loadContext();
    }
  }

  Future<Map<String, dynamic>> _loadContext() => widget.loadContext?.call() ??
      const NbaEntityIntelligenceRepository().seasonCommand(
        widget.seasonId,
        league: widget.league,
        seasonType: _apiSeasonType(widget.seasonType),
        leaderLimit: 25,
      );

  @override
  Widget build(BuildContext context) {
    final leaders = const NbaSeasonLeaderMatrixEngine().build(
      widget.seed,
      seasonId: widget.seasonId,
      seasonType: widget.seasonType,
      metrics: const [
        NbaSeasonLeaderMetric.points,
        NbaSeasonLeaderMetric.rebounds,
        NbaSeasonLeaderMetric.assists,
        NbaSeasonLeaderMetric.steals,
        NbaSeasonLeaderMetric.blocks,
        NbaSeasonLeaderMetric.trueShooting,
      ],
      topPerMetric: 5,
    );
    final filteredLeaders = const NbaSeasonLeaderMatrixEngine().build(
      widget.seed,
      seasonId: widget.seasonId,
      seasonType: widget.seasonType,
      metrics: const [
        NbaSeasonLeaderMetric.points,
        NbaSeasonLeaderMetric.rebounds,
        NbaSeasonLeaderMetric.assists,
        NbaSeasonLeaderMetric.steals,
        NbaSeasonLeaderMetric.blocks,
        NbaSeasonLeaderMetric.trueShooting,
      ],
      topPerMetric: 25,
    );
    final selectedLeaders = _topPerMetric == 5 && _minimumGames == 0
        ? leaders
        : const NbaSeasonLeaderMatrixEngine().build(
            widget.seed,
            seasonId: widget.seasonId,
            seasonType: widget.seasonType,
            metrics: [
              NbaSeasonLeaderMetric.points,
              NbaSeasonLeaderMetric.rebounds,
              NbaSeasonLeaderMetric.assists,
              NbaSeasonLeaderMetric.steals,
              NbaSeasonLeaderMetric.blocks,
              NbaSeasonLeaderMetric.trueShooting,
            ],
            topPerMetric: 5,
          );
    // Rebuild with interactive controls only when they differ from the defaults.
    final matrix = _topPerMetric == 5 && _minimumGames == 0
        ? selectedLeaders
        : NbaSeasonLeaderMatrixEngine().build(
            widget.seed,
            seasonId: widget.seasonId,
            seasonType: widget.seasonType,
            metrics: const [
              NbaSeasonLeaderMetric.points,
              NbaSeasonLeaderMetric.rebounds,
              NbaSeasonLeaderMetric.assists,
              NbaSeasonLeaderMetric.steals,
              NbaSeasonLeaderMetric.blocks,
              NbaSeasonLeaderMetric.trueShooting,
            ],
            topPerMetric: _topPerMetric,
            minimumGames: _minimumGames,
          );
    final rest = const NbaSeasonRestDensityEngine().build(
      widget.seed,
      seasonId: widget.seasonId,
      seasonType: widget.seasonType,
    );

    // Keep this explicit reference so tests/audits can verify that larger top-N
    // source support exists without silently changing the selected matrix.
    final availableLeaderField = filteredLeaders.players.length;

    return Container(
      key: const ValueKey('season-operations-workbench'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _bg, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SEASON OPERATIONS INTELLIGENCE',
            style: TextStyle(
              color: _amber,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'League leaders, source-backed awards/voting, All-Star selections, draft context, and date-only schedule density. No transaction inference, fatigue model, travel model, or synthetic award outcome is introduced.',
            style: TextStyle(color: _muted, fontSize: 9, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _chip('LEADER FIELD', '$availableLeaderField'),
              _chip('TEAMS WITH DATES', '${rest.teams.where((team) => team.datedGames > 0).length}'),
              _chip('B2B OCCURRENCES', '${rest.backToBackOccurrences}'),
              _chip('MAX GAMES / 7D', '${rest.maxObservedGamesInSevenDays}'),
            ],
          ),
          const SizedBox(height: 10),
          _leaderMatrix(matrix),
          const SizedBox(height: 10),
          _restDensity(rest),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _contextFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _section(
                  'SOURCE-BACKED OPERATIONS CONTEXT',
                  Text(
                    'Canonical Season awards / All-Star / draft context is unavailable: ${snapshot.error}',
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                );
              }
              final payload = snapshot.data!;
              final awards = const NbaSeasonAwardsVotingEngine().build(
                payload,
                seasonId: widget.seasonId,
              );
              final allStar = const NbaSeasonAllStarEngine().build(
                payload,
                seasonId: widget.seasonId,
              );
              final draft = const NbaSeasonDraftClassEngine().build(
                payload,
                seasonId: widget.seasonId,
              );
              return LayoutBuilder(builder: (context, constraints) {
                final first = _awards(awards);
                final second = _allStar(allStar);
                final third = _draft(draft);
                if (constraints.maxWidth < 1100) {
                  return Column(
                    children: [
                      first,
                      const SizedBox(height: 10),
                      second,
                      const SizedBox(height: 10),
                      third,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: first),
                    const SizedBox(width: 10),
                    Expanded(child: second),
                    const SizedBox(width: 10),
                    Expanded(child: third),
                  ],
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _leaderMatrix(NbaSeasonLeaderMatrixResult result) => _section(
        'MULTI-METRIC LEADER MATRIX',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<int>(
                  key: const ValueKey('season-leader-top-n'),
                  value: _topPerMetric,
                  dropdownColor: _panel,
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('Top 3')),
                    DropdownMenuItem(value: 5, child: Text('Top 5')),
                    DropdownMenuItem(value: 10, child: Text('Top 10')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _topPerMetric = value);
                  },
                ),
                DropdownButton<double>(
                  key: const ValueKey('season-leader-min-games'),
                  value: _minimumGames,
                  dropdownColor: _panel,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('No GP minimum')),
                    DropdownMenuItem(value: 10, child: Text('10+ GP')),
                    DropdownMenuItem(value: 20, child: Text('20+ GP')),
                    DropdownMenuItem(value: 40, child: Text('40+ GP')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _minimumGames = value);
                  },
                ),
                _chip('PLAYERS', '${result.players.length}'),
                _chip('METRICS', '${result.metricCount}'),
              ],
            ),
            const SizedBox(height: 8),
            if (!result.hasLeaders)
              const Text(
                'No players satisfy the selected metric and games-played evidence requirements.',
                style: TextStyle(color: _muted, fontSize: 9),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_bg),
                  headingTextStyle: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                  dataTextStyle: const TextStyle(color: _text, fontSize: 9),
                  columns: [
                    const DataColumn(label: Text('PLAYER')),
                    const DataColumn(label: Text('TEAM')),
                    const DataColumn(label: Text('GP')),
                    for (final column in result.columns)
                      DataColumn(label: Text(column.metric.label)),
                  ],
                  rows: [
                    for (final player in result.players)
                      DataRow(cells: [
                        DataCell(
                          TextButton(
                            key: ValueKey('season-operations-player-${player.playerId}'),
                            onPressed: widget.onOpenPlayer == null || player.playerId.isEmpty
                                ? null
                                : () => widget.onOpenPlayer!(
                                      player.playerId,
                                      player.playerName,
                                    ),
                            child: Text(player.playerName),
                          ),
                        ),
                        DataCell(Text(player.teamLabel)),
                        DataCell(Text(_number(player.games))),
                        for (final column in result.columns)
                          DataCell(_leaderCell(player.cells[column.metric])),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _leaderCell(NbaSeasonLeaderMatrixCell? cell) {
    if (cell == null) return const Text('—', style: TextStyle(color: _muted));
    final value = cell.metric == NbaSeasonLeaderMetric.trueShooting
        ? '${(cell.value * 100).toStringAsFixed(1)}%'
        : cell.value.toStringAsFixed(1);
    return Text('#${cell.rank} · $value');
  }

  Widget _restDensity(NbaSeasonRestDensityResult result) => _section(
        'DATE-ONLY REST + SCHEDULE DENSITY',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calendar spacing only. Scheduled games with explicit dates are included; undated rows remain coverage gaps.',
              style: TextStyle(color: _muted, fontSize: 8, height: 1.4),
            ),
            const SizedBox(height: 7),
            if (!result.hasTeams)
              const Text(
                'No canonical team schedules exist in this Season scope.',
                style: TextStyle(color: _muted, fontSize: 9),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_bg),
                  headingTextStyle: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                  dataTextStyle: const TextStyle(color: _text, fontSize: 9),
                  columns: const [
                    DataColumn(label: Text('TEAM')),
                    DataColumn(label: Text('DATED')),
                    DataColumn(label: Text('UNDATED')),
                    DataColumn(label: Text('B2B')),
                    DataColumn(label: Text('1D REST')),
                    DataColumn(label: Text('AVG REST')),
                    DataColumn(label: Text('MAX / 7D')),
                    DataColumn(label: Text('4+ / 6D WINDOWS')),
                  ],
                  rows: [
                    for (final team in result.teams)
                      DataRow(cells: [
                        DataCell(
                          TextButton(
                            key: ValueKey('season-rest-team-${team.teamId}'),
                            onPressed: widget.onOpenTeam == null || team.teamId.isEmpty
                                ? null
                                : () => widget.onOpenTeam!(team.teamId),
                            child: Text(
                              team.abbreviation.isEmpty ? team.teamId : team.abbreviation,
                            ),
                          ),
                        ),
                        DataCell(Text('${team.datedGames}')),
                        DataCell(Text('${team.undatedGames}')),
                        DataCell(Text('${team.backToBacks}')),
                        DataCell(Text('${team.oneDayRestOccurrences}')),
                        DataCell(Text(team.averageRestDays?.toStringAsFixed(1) ?? '—')),
                        DataCell(Text('${team.maxGamesInSevenDays}')),
                        DataCell(Text('${team.fourPlusInSixDayWindows}')),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _awards(NbaSeasonAwardsVotingResult result) => _section(
        'AWARDS + VOTING',
        result.hasAwards
            ? Column(
                children: [
                  for (final award in result.awards.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            award.award,
                            style: const TextStyle(
                              color: _blue,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          for (final row in award.rows.take(5))
                            _playerRow(
                              row.playerId,
                              row.playerName,
                              '${row.winner ? 'WINNER' : row.rankLabel}${row.votePoints == null ? '' : ' · ${row.votePoints!.toStringAsFixed(1)} vote pts'}',
                            ),
                        ],
                      ),
                    ),
                ],
              )
            : const Text(
                'No canonical award rows are exposed for this Season.',
                style: TextStyle(color: _muted, fontSize: 9),
              ),
      );

  Widget _allStar(NbaSeasonAllStarResult result) => _section(
        'ALL-STAR SELECTIONS',
        result.hasRows
            ? Column(
                children: [
                  for (final row in result.rows.take(14))
                    _playerRow(
                      row.playerId,
                      row.playerName,
                      [
                        row.statusLabel,
                        if (row.teamLabel.isNotEmpty) row.teamLabel,
                        if (row.rosterLabel.isNotEmpty) row.rosterLabel,
                        if (row.selectionType.isNotEmpty) row.selectionType,
                      ].join(' · '),
                    ),
                ],
              )
            : const Text(
                'No canonical All-Star selection rows are exposed for this Season.',
                style: TextStyle(color: _muted, fontSize: 9),
              ),
      );

  Widget _draft(NbaSeasonDraftClassResult result) => _section(
        'DRAFT CLASS CONTEXT',
        result.hasRows
            ? Column(
                children: [
                  for (final row in result.rows.take(16))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              '${row.draftYear ?? '—'} ${row.pickLabel}',
                              style: const TextStyle(color: _muted, fontSize: 8),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: widget.onOpenPlayer == null || row.playerId.isEmpty
                                  ? null
                                  : () => widget.onOpenPlayer!(row.playerId, row.playerName),
                              child: Text(
                                row.playerName.isEmpty ? row.playerId : row.playerName,
                                style: TextStyle(
                                  color: widget.onOpenPlayer == null || row.playerId.isEmpty
                                      ? _text
                                      : _blue,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if (row.teamId.isNotEmpty)
                            TextButton(
                              onPressed: widget.onOpenTeam == null
                                  ? null
                                  : () => widget.onOpenTeam!(row.teamId),
                              child: Text(
                                row.teamLabel.isEmpty ? row.teamId : row.teamLabel,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              )
            : const Text(
                'No canonical draft rows are exposed for this Season context.',
                style: TextStyle(color: _muted, fontSize: 9),
              ),
      );

  Widget _playerRow(String playerId, String playerName, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onOpenPlayer == null || playerId.isEmpty
                    ? null
                    : () => widget.onOpenPlayer!(playerId, playerName),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName.isEmpty ? playerId : playerName,
                      style: TextStyle(
                        color: widget.onOpenPlayer == null || playerId.isEmpty
                            ? _text
                            : _blue,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(color: _muted, fontSize: 8),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _section(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _blue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _chip(String label, String value, [Color color = _green]) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: Text(
          '$label $value',
          style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800),
        ),
      );

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

String _apiSeasonType(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('playoff')) return 'playoffs';
  if (normalized == 'all' || normalized.contains('combined')) return 'combined';
  return 'regular';
}
