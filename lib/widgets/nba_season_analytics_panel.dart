import 'package:flutter/material.dart';

import '../services/nba_season_player_leader_engine.dart';
import '../services/nba_season_playoff_series_engine.dart';
import '../services/nba_season_team_distribution_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'nba_terminal_distribution_chart.dart';

const _bg = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _amber = Color(0xFFE2B866);
const _green = Color(0xFF69C99A);

typedef NbaSeasonPlayerOpenCallback = void Function(
  String playerId,
  String playerName,
);

class NbaSeasonAnalyticsPanel extends StatefulWidget {
  const NbaSeasonAnalyticsPanel({
    super.key,
    required this.seed,
    required this.seasonId,
    required this.seasonType,
    this.onOpenPlayer,
    this.onOpenTeam,
    this.onOpenGame,
  });

  final NbaTerminalSeedSnapshot seed;
  final String seasonId;
  final String seasonType;
  final NbaSeasonPlayerOpenCallback? onOpenPlayer;
  final ValueChanged<String>? onOpenTeam;
  final void Function(String gameId, String gameLabel)? onOpenGame;

  @override
  State<NbaSeasonAnalyticsPanel> createState() => _NbaSeasonAnalyticsPanelState();
}

class _NbaSeasonAnalyticsPanelState extends State<NbaSeasonAnalyticsPanel> {
  NbaSeasonLeaderMetric _leaderMetric = NbaSeasonLeaderMetric.points;
  NbaSeasonTeamDistributionMetric _teamMetric =
      NbaSeasonTeamDistributionMetric.differential;

  @override
  Widget build(BuildContext context) {
    final leaders = const NbaSeasonPlayerLeaderEngine().build(
      widget.seed,
      seasonId: widget.seasonId,
      seasonType: widget.seasonType,
      metric: _leaderMetric,
      limit: 12,
    );
    final distribution = const NbaSeasonTeamDistributionEngine().build(
      widget.seed,
      seasonId: widget.seasonId,
      seasonType: widget.seasonType,
      metric: _teamMetric,
    );
    final playoffs = const NbaSeasonPlayoffSeriesEngine().build(
      widget.seed,
      seasonId: widget.seasonId,
    );

    return Container(
      key: const ValueKey('season-analytics-workbench'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _bg, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SEASON ANALYTICS WORKBENCH',
            style: TextStyle(
              color: _amber,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Canonical season leaders, team distributions and observed playoff matchup context. Missing metrics stay missing; playoff rounds and advancement are never inferred.',
            style: TextStyle(color: _muted, fontSize: 9, height: 1.4),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              final leader = _leaders(leaders);
              final teams = _distribution(distribution);
              return compact
                  ? Column(
                      children: [
                        leader,
                        const SizedBox(height: 10),
                        teams,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leader),
                        const SizedBox(width: 10),
                        Expanded(child: teams),
                      ],
                    );
            },
          ),
          const SizedBox(height: 10),
          _playoffs(playoffs),
        ],
      ),
    );
  }

  Widget _leaders(NbaSeasonPlayerLeaderResult result) => _section(
        title: 'PLAYER LEADERS',
        trailing: DropdownButton<NbaSeasonLeaderMetric>(
          key: const ValueKey('season-leader-metric'),
          value: _leaderMetric,
          dropdownColor: _panel2,
          style: const TextStyle(color: _text, fontSize: 9),
          items: [
            for (final metric in NbaSeasonLeaderMetric.values)
              DropdownMenuItem(value: metric, child: Text(metric.label)),
          ],
          onChanged: (metric) {
            if (metric != null) setState(() => _leaderMetric = metric);
          },
        ),
        child: result.leaders.isEmpty
            ? const _Empty('No qualified player rows in this season segment.')
            : Column(
                children: [
                  for (final leader in result.leaders.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${leader.rank}',
                              style: const TextStyle(color: _muted, fontSize: 9),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              key: ValueKey('season-leader-${leader.playerId}'),
                              style: TextButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: widget.onOpenPlayer == null ||
                                      leader.playerId.trim().isEmpty
                                  ? null
                                  : () => widget.onOpenPlayer!(
                                        leader.playerId,
                                        leader.playerName,
                                      ),
                              child: Text(
                                leader.playerName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _leaderValue(leader),
                            style: const TextStyle(
                              color: _text,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(color: _line),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${result.eligiblePlayers} metric-eligible players · ${result.seasonType}',
                      style: const TextStyle(color: _muted, fontSize: 8),
                    ),
                  ),
                ],
              ),
      );

  Widget _distribution(NbaSeasonTeamDistributionResult result) => _section(
        title: 'TEAM DISTRIBUTION',
        trailing: DropdownButton<NbaSeasonTeamDistributionMetric>(
          key: const ValueKey('season-team-distribution-metric'),
          value: _teamMetric,
          dropdownColor: _panel2,
          style: const TextStyle(color: _text, fontSize: 9),
          items: [
            for (final metric in NbaSeasonTeamDistributionMetric.values)
              DropdownMenuItem(value: metric, child: Text(metric.label)),
          ],
          onChanged: (metric) {
            if (metric != null) setState(() => _teamMetric = metric);
          },
        ),
        child: result.observations.isEmpty
            ? const _Empty('No scored team rows exist in this season segment.')
            : Column(
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _chip('MEAN', result.mean),
                      _chip('MEDIAN', result.median),
                      _chip('Q1', result.lowerQuartile),
                      _chip('Q3', result.upperQuartile),
                      _chip('σ', result.standardDeviation),
                    ],
                  ),
                  const SizedBox(height: 7),
                  NbaTerminalDistributionChart(
                    points: [
                      for (final row in result.observations)
                        NbaTerminalDistributionPoint(
                          label: row.abbreviation,
                          value: row.value,
                          entityId: row.teamId,
                        ),
                    ],
                    referenceValue: result.median,
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final row in result.observations)
                        TextButton(
                          key: ValueKey('season-distribution-team-${row.teamId}'),
                          onPressed: widget.onOpenTeam == null
                              ? null
                              : () => widget.onOpenTeam!(row.teamId),
                          child: Text('${row.abbreviation} ${_teamValue(row.value)}'),
                        ),
                    ],
                  ),
                ],
              ),
      );

  Widget _playoffs(NbaSeasonPlayoffSeriesResult result) => _section(
        title: 'OBSERVED PLAYOFF MATCHUPS',
        trailing: Text(
          '${result.playoffGameCount} games · ${result.observedMatchups} matchups',
          style: const TextStyle(color: _muted, fontSize: 8),
        ),
        child: !result.available
            ? const _Empty(
                'No canonical playoff games are exposed for this season. No bracket is synthesized.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final series in result.series) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _panel2,
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TextButton(
                                key: ValueKey('season-playoff-team-${series.teamA.id}'),
                                onPressed: widget.onOpenTeam == null
                                    ? null
                                    : () => widget.onOpenTeam!(series.teamA.id),
                                child: Text(series.teamA.abbreviation),
                              ),
                              const Text('vs', style: TextStyle(color: _muted)),
                              TextButton(
                                key: ValueKey('season-playoff-team-${series.teamB.id}'),
                                onPressed: widget.onOpenTeam == null
                                    ? null
                                    : () => widget.onOpenTeam!(series.teamB.id),
                                child: Text(series.teamB.abbreviation),
                              ),
                              const Spacer(),
                              Text(
                                series.leaderLabel,
                                style: const TextStyle(
                                  color: _green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final game in series.games)
                                TextButton(
                                  key: ValueKey('season-playoff-game-${game.gameId}'),
                                  onPressed: widget.onOpenGame == null
                                      ? null
                                      : () => widget.onOpenGame!(
                                            game.gameId,
                                            game.matchupLabel,
                                          ),
                                  child: Text('${game.gameDate} · ${game.scoreLabel}'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    result.methodologyLabel,
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                ],
              ),
      );

  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _chip(String label, double? value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: _bg, border: Border.all(color: _line)),
        child: Text(
          '$label ${value == null ? '—' : _teamValue(value)}',
          style: const TextStyle(color: _text, fontSize: 8),
        ),
      );

  String _leaderValue(NbaSeasonPlayerLeader leader) {
    final value = leader.value;
    if (leader.metric == NbaSeasonLeaderMetric.trueShooting) {
      return '${(value * 100).toStringAsFixed(1)}%';
    }
    return value.toStringAsFixed(1);
  }

  String _teamValue(double value) {
    if (_teamMetric == NbaSeasonTeamDistributionMetric.winPct) {
      return value.toStringAsFixed(3);
    }
    return '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          message,
          style: const TextStyle(color: _muted, fontSize: 9),
        ),
      );
}
