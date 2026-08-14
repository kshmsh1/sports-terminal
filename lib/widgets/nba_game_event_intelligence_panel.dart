import 'package:flutter/material.dart';

import '../services/nba_game_clutch_engine.dart';
import '../services/nba_game_intelligence_engine.dart';
import '../services/nba_game_player_scoring_engine.dart';
import '../services/nba_game_segment_engine.dart';
import '../services/nba_game_substitution_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);
const _red = Color(0xFFE57D7D);

/// Evidence-bounded event intelligence for a canonical NBA game.
///
/// This panel deliberately avoids win probability, possession estimates, and
/// lineup reconstruction. Every number shown is derived from explicit PBP score
/// states, structured scoring actors, or confirmed substitution participants.
class NbaGameEventIntelligencePanel extends StatelessWidget {
  const NbaGameEventIntelligencePanel({
    super.key,
    required this.seed,
    required this.game,
    this.onOpenTeam,
    this.onOpenPlayer,
  });

  final NbaTerminalSeedSnapshot seed;
  final NbaGameIntelligenceSnapshot game;
  final ValueChanged<String>? onOpenTeam;
  final void Function(String playerId, String playerName)? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    final clutch = const NbaGameClutchEngine().build(seed, gameId: game.gameId);
    final segments = const NbaGameSegmentEngine().build(seed, gameId: game.gameId);
    final scoring = const NbaGamePlayerScoringEngine().build(seed, gameId: game.gameId);
    final substitutions =
        const NbaGameSubstitutionEngine().build(seed, gameId: game.gameId);

    return Column(
      key: ValueKey('game-event-intelligence-${game.gameId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          key: const ValueKey('game-clutch-observatory'),
          title: 'LATE-GAME / CLUTCH OBSERVATORY',
          trailing: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(clutch.methodologyLabel.toUpperCase(), _blue),
              _pill('${clutch.closeEventCount} CLOSE EVENTS',
                  clutch.hasObservedCloseWindow ? _green : _muted),
            ],
          ),
          child: _ClutchBody(clutch: clutch),
        ),
        const SizedBox(height: 12),
        _section(
          key: const ValueKey('game-segment-matrix'),
          title: 'GAME SEGMENT MATRIX',
          trailing: _pill('${segments.eventCount} SOURCE EVENTS', _blue),
          child: _SegmentBody(segments: segments),
        ),
        const SizedBox(height: 12),
        _section(
          key: const ValueKey('game-player-scoring-ledger'),
          title: 'OBSERVED PLAYER SCORING LEDGER',
          trailing: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill('${scoring.creditedPoints} CREDITED PTS', _green),
              _pill(
                '${scoring.uncreditedPoints} UNCREDITED PTS',
                scoring.uncreditedPoints == 0 ? _muted : _amber,
              ),
            ],
          ),
          child: _PlayerScoringBody(
            scoring: scoring,
            onOpenPlayer: onOpenPlayer,
          ),
        ),
        const SizedBox(height: 12),
        _section(
          key: const ValueKey('game-substitution-ledger'),
          title: 'CONFIRMED SUBSTITUTION LEDGER',
          trailing: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(substitutions.coverageLabel, substitutions.hasConfirmedSwaps ? _green : _amber),
              _pill('${substitutions.confirmedSwapCount} CONFIRMED', _blue),
            ],
          ),
          child: _SubstitutionBody(
            substitutions: substitutions,
            onOpenTeam: onOpenTeam,
            onOpenPlayer: onOpenPlayer,
          ),
        ),
      ],
    );
  }
}

class _ClutchBody extends StatelessWidget {
  const _ClutchBody({required this.clutch});

  final NbaGameClutchResult clutch;

  @override
  Widget build(BuildContext context) {
    if (!clutch.hasLateEvents) {
      return const _Unavailable(
        title: 'No fourth-quarter/overtime late-game events are exposed.',
        detail:
            'Late-game intelligence requires row-level play-by-play with period and clock data. No late-game state is inferred from the final box score.',
      );
    }
    if (!clutch.hasObservedCloseWindow) {
      return _Unavailable(
        title: 'Late-game events exist, but no observed close-game state qualifies.',
        detail:
            '${clutch.methodologyLabel}. Events outside that explicit score-state definition are not relabeled as clutch.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric('OBSERVED CLOSE PTS', clutch.closePointsLabel),
            _metric('CLOSE SCORE CHANGES', '${clutch.closeScoringChangeCount}'),
            _metric('LEAD CHANGES', '${clutch.closeLeadChanges}'),
            _metric('TIES', '${clutch.closeTies}'),
            _metric('LAST 2:00 EVENTS', '${clutch.lastTwoMinuteEventCount}'),
            _metric('LAST 1:00 EVENTS', '${clutch.lastMinuteEventCount}'),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Observed window: ${clutch.firstClosePeriodLabel} ${clutch.firstCloseClock} → ${clutch.lastClosePeriodLabel} ${clutch.lastCloseClock}. '
          'Points are score deltas observed while the post-event state remained within five points.',
          style: const TextStyle(color: _muted, fontSize: 10, height: 1.4),
        ),
        if (clutch.scoreChanges.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_panel2),
              headingTextStyle:
                  const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900),
              dataTextStyle: const TextStyle(color: _text, fontSize: 9),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('TIME')),
                DataColumn(label: Text('TEAM')),
                DataColumn(label: Text('PTS')),
                DataColumn(label: Text('SCORE')),
                DataColumn(label: Text('PLAYER')),
                DataColumn(label: Text('EVENT')),
              ],
              rows: [
                for (final change in clutch.scoreChanges)
                  DataRow(
                    cells: [
                      DataCell(Text('${change.periodLabel} ${change.clock}'.trim())),
                      DataCell(Text(change.team.abbreviation.isEmpty ? '—' : change.team.abbreviation)),
                      DataCell(Text('+${change.points}')),
                      DataCell(Text(change.scoreLabel)),
                      DataCell(Text(change.player.label.isEmpty ? '—' : change.player.label)),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: Text(
                            change.description.isEmpty ? '—' : change.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SegmentBody extends StatelessWidget {
  const _SegmentBody({required this.segments});

  final NbaGameSegmentResult segments;

  @override
  Widget build(BuildContext context) {
    if (segments.eventCount == 0) {
      return const _Unavailable(
        title: 'No row-level event segments are available.',
        detail:
            'Sports Terminal leaves segment scoring and boundary coverage unavailable rather than deriving them from final or period totals.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_panel2),
        headingTextStyle:
            const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900),
        dataTextStyle: const TextStyle(color: _text, fontSize: 9),
        columnSpacing: 22,
        columns: const [
          DataColumn(label: Text('SEGMENT')),
          DataColumn(label: Text('EVENTS')),
          DataColumn(label: Text('SCORE STATES')),
          DataColumn(label: Text('OBS PTS')),
          DataColumn(label: Text('START')),
          DataColumn(label: Text('END')),
          DataColumn(label: Text('LEAD CHG')),
          DataColumn(label: Text('TIES')),
          DataColumn(label: Text('BOUNDARY')),
        ],
        rows: [
          for (final segment in segments.segments)
            DataRow(
              key: ValueKey('game-segment-${segment.key}'),
              cells: [
                DataCell(
                  Text(
                    segment.label,
                    style: const TextStyle(color: _blue, fontWeight: FontWeight.w900),
                  ),
                ),
                DataCell(Text('${segment.eventCount}')),
                DataCell(Text('${segment.scoreStateCount}')),
                DataCell(Text(segment.observedPointsLabel)),
                DataCell(Text(segment.startScoreLabel)),
                DataCell(Text(segment.endScoreLabel)),
                DataCell(Text('${segment.leadChanges}')),
                DataCell(Text('${segment.ties}')),
                DataCell(
                  Text(
                    segment.boundaryComplete
                        ? 'COMPLETE'
                        : segment.hasEvents
                            ? 'PARTIAL'
                            : 'NO ROWS',
                    style: TextStyle(
                      color: segment.boundaryComplete
                          ? _green
                          : segment.hasEvents
                              ? _amber
                              : _muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlayerScoringBody extends StatelessWidget {
  const _PlayerScoringBody({required this.scoring, required this.onOpenPlayer});

  final NbaGamePlayerScoringResult scoring;
  final void Function(String playerId, String playerName)? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    if (!scoring.hasObservedScoring) {
      return const _Unavailable(
        title: 'No attributable score-change stream is available.',
        detail:
            'Player scoring attribution requires consecutive explicit score states plus a canonical scoring action. Box-score points are not backfilled into this event ledger.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scoring.players.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_panel2),
              headingTextStyle:
                  const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900),
              dataTextStyle: const TextStyle(color: _text, fontSize: 9),
              columnSpacing: 22,
              columns: const [
                DataColumn(label: Text('PLAYER')),
                DataColumn(label: Text('TEAM')),
                DataColumn(label: Text('OBS PTS')),
                DataColumn(label: Text('SCORING EVENTS')),
                DataColumn(label: Text('CLOSE PTS')),
                DataColumn(label: Text('MAX CHANGE')),
                DataColumn(label: Text('LAST SCORE')),
              ],
              rows: [
                for (final player in scoring.players)
                  DataRow(
                    cells: [
                      DataCell(
                        InkWell(
                          key: ValueKey('event-scoring-player-${player.player.id}'),
                          onTap: onOpenPlayer == null || player.player.id.isEmpty
                              ? null
                              : () => onOpenPlayer!(player.player.id, player.player.label),
                          child: Text(
                            player.player.label,
                            style: TextStyle(
                              color: onOpenPlayer == null ? _text : _blue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(player.teamId.isEmpty ? '—' : player.teamId)),
                      DataCell(Text('${player.observedPoints}')),
                      DataCell(Text('${player.scoringEvents}')),
                      DataCell(Text('${player.closeWindowPoints}')),
                      DataCell(Text('+${player.largestSingleChange}')),
                      DataCell(Text(player.lastScore?.scoreLabel ?? '—')),
                    ],
                  ),
              ],
            ),
          ),
        if (scoring.uncreditedScoreChanges.isNotEmpty) ...[
          if (scoring.players.isNotEmpty) const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: .07),
              border: Border.all(color: _amber.withValues(alpha: .35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${scoring.uncreditedPoints} observed points remain uncredited',
                  style: const TextStyle(color: _amber, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  scoring.uncreditedScoreChanges
                      .take(4)
                      .map((row) => '${row.periodLabel} ${row.clock} · +${row.points} · ${row.reason}')
                      .join('\n'),
                  style: const TextStyle(color: _muted, fontSize: 9, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SubstitutionBody extends StatelessWidget {
  const _SubstitutionBody({
    required this.substitutions,
    required this.onOpenTeam,
    required this.onOpenPlayer,
  });

  final NbaGameSubstitutionResult substitutions;
  final ValueChanged<String>? onOpenTeam;
  final void Function(String playerId, String playerName)? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: .06),
            border: Border.all(color: _amber.withValues(alpha: .3)),
          ),
          child: const Text(
            'Confirmed swaps only. This ledger does not claim five-man lineup reconstruction, stint minutes, or on/off metrics unless a future source contract proves complete starters and substitution coverage.',
            style: TextStyle(color: _amber, fontSize: 9, height: 1.4, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        if (!substitutions.hasConfirmedSwaps)
          _Unavailable(
            title: substitutions.coverageLabel,
            detail: substitutions.substitutionRows == 0
                ? 'No structured substitution events were supplied for this game.'
                : '${substitutions.incompleteSubstitutionRows} substitution rows lack both explicit outgoing and incoming participants.',
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric(
                '${substitutions.awayTeam.abbreviation} CONFIRMED',
                '${substitutions.confirmedForTeam(substitutions.awayTeam.id)}',
              ),
              _metric(
                '${substitutions.homeTeam.abbreviation} CONFIRMED',
                '${substitutions.confirmedForTeam(substitutions.homeTeam.id)}',
              ),
              _metric('INCOMPLETE ROWS', '${substitutions.incompleteSubstitutionRows}'),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < substitutions.swaps.length; index++) ...[
            _swap(substitutions.swaps[index], index),
            if (index != substitutions.swaps.length - 1)
              const Divider(height: 15, color: _line),
          ],
        ],
      ],
    );
  }

  Widget _swap(NbaGameSubstitutionSwap swap, int index) => Row(
        key: ValueKey('confirmed-substitution-${swap.sequence ?? index}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              swap.timeLabel.isEmpty ? '—' : swap.timeLabel,
              style: const TextStyle(color: _blue, fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (swap.team.id.isNotEmpty)
                  InkWell(
                    onTap: onOpenTeam == null ? null : () => onOpenTeam!(swap.team.id),
                    child: Text(
                      swap.team.abbreviation.isEmpty ? swap.team.id : swap.team.abbreviation,
                      style: TextStyle(
                        color: onOpenTeam == null ? _muted : _blue,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                _playerLink(swap.playerIn, suffix: ' IN'),
                _playerLink(swap.playerOut, suffix: ' OUT'),
                if (swap.description.isNotEmpty)
                  Text(
                    swap.description,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _playerLink(NbaPbpPlayerIdentity player, {required String suffix}) => InkWell(
        onTap: onOpenPlayer == null || player.id.isEmpty
            ? null
            : () => onOpenPlayer!(player.id, player.label),
        child: Text(
          '${player.label}$suffix',
          style: TextStyle(
            color: onOpenPlayer == null ? _text : _blue,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

Widget _section({
  required Key key,
  required String title,
  required Widget child,
  Widget? trailing,
}) =>
    Container(
      key: key,
      width: double.infinity,
      decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Flexible(child: trailing),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
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

Widget _metric(String label, String value) => Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 10, height: 1.4)),
          ],
        ),
      );
}
