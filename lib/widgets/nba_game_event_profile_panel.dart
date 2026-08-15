import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/nba_game_intelligence_engine.dart';
import '../services/nba_game_player_event_profile_engine.dart';
import '../services/nba_game_play_by_play_engine.dart';
import '../services/nba_game_segment_engine.dart';
import '../services/nba_game_team_event_profile_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);

/// Cross-event player/team profiles plus a compact observed segment chart.
/// Every metric is a count or score delta from explicit canonical event rows.
class NbaGameEventProfilePanel extends StatelessWidget {
  const NbaGameEventProfilePanel({
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
    final players = const NbaGamePlayerEventProfileEngine().build(seed, gameId: game.gameId);
    final teams = const NbaGameTeamEventProfileEngine().build(seed, gameId: game.gameId);
    final segments = const NbaGameSegmentEngine().build(seed, gameId: game.gameId);

    return Column(
      key: ValueKey('game-event-profiles-${game.gameId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          key: const ValueKey('game-segment-visualization'),
          title: 'SEGMENT SCORING VISUALIZATION',
          trailing: _pill('${segments.eventCount} EVENTS', _blue),
          child: segments.segments.any((segment) => segment.hasScoreStates)
              ? _SegmentVisualization(segments: segments)
              : const _Unavailable(
                  title: 'No segment score-state visualization is available.',
                  detail: 'The chart requires row-level score states; period totals are not substituted for missing play-by-play.',
                ),
        ),
        const SizedBox(height: 12),
        _section(
          key: const ValueKey('game-team-event-profiles'),
          title: 'TEAM EVENT PROFILES',
          trailing: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill('${teams.unattributedEventCount} TEAM-UNATTRIBUTED EVENTS',
                  teams.unattributedEventCount == 0 ? _green : _amber),
              _pill('${teams.uncreditedObservedPoints} PLAYER-UNCREDITED PTS',
                  teams.uncreditedObservedPoints == 0 ? _green : _amber),
            ],
          ),
          child: _TeamProfiles(result: teams, onOpenTeam: onOpenTeam),
        ),
        const SizedBox(height: 12),
        _section(
          key: const ValueKey('game-player-event-profiles'),
          title: 'PLAYER EVENT PROFILES',
          trailing: _pill('${players.profiles.length} OBSERVED PLAYERS', _blue),
          child: _PlayerProfiles(result: players, onOpenPlayer: onOpenPlayer),
        ),
      ],
    );
  }
}

class _SegmentVisualization extends StatelessWidget {
  const _SegmentVisualization({required this.segments});

  final NbaGameSegmentResult segments;

  @override
  Widget build(BuildContext context) {
    final visible = segments.segments.where((segment) => segment.hasScoreStates).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const ValueKey('game-segment-observed-points-chart'),
          height: math.max(150, visible.length * 34).toDouble(),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
          child: CustomPaint(
            painter: _SegmentBarPainter(
              segments: visible,
              awayLabel: segments.awayTeam.abbreviation,
              homeLabel: segments.homeTeam.abbreviation,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _legend(segments.awayTeam.abbreviation.isEmpty ? 'AWAY' : segments.awayTeam.abbreviation, _amber),
            _legend(segments.homeTeam.abbreviation.isEmpty ? 'HOME' : segments.homeTeam.abbreviation, _green),
            const Text(
              'Bars show observed score deltas within each supplied event segment.',
              style: TextStyle(color: _muted, fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final segment in visible)
              Container(
                width: 188,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(segment.label,
                        style: const TextStyle(color: _text, fontSize: 9, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '${segment.observedPointsLabel} observed · ${segment.eventCount} events · ${segment.boundaryComplete ? 'complete boundary' : 'partial boundary'}',
                      style: TextStyle(
                        color: segment.boundaryComplete ? _muted : _amber,
                        fontSize: 8,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TeamProfiles extends StatelessWidget {
  const _TeamProfiles({required this.result, required this.onOpenTeam});

  final NbaGameTeamEventProfileResult result;
  final ValueChanged<String>? onOpenTeam;

  @override
  Widget build(BuildContext context) {
    if (!result.hasProfiles) {
      return const _Unavailable(
        title: 'No canonical team profiles are available.',
        detail: 'Team event profiles require a canonical game identity even when row-level event coverage is empty.',
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_panel2),
        headingTextStyle: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900),
        dataTextStyle: const TextStyle(color: _text, fontSize: 9),
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('TEAM')),
          DataColumn(label: Text('TEAM EVENTS')),
          DataColumn(label: Text('CLOSE EVENTS')),
          DataColumn(label: Text('OBS SCORE Δ')),
          DataColumn(label: Text('PLAYER CREDIT')),
          DataColumn(label: Text('UNCREDITED')),
          DataColumn(label: Text('MADE FG')),
          DataColumn(label: Text('MISS FG')),
          DataColumn(label: Text('TO')),
          DataColumn(label: Text('FOUL')),
          DataColumn(label: Text('SUBS')),
        ],
        rows: [
          for (final profile in result.profiles)
            DataRow(
              cells: [
                DataCell(
                  InkWell(
                    key: ValueKey('team-event-profile-${profile.team.id}'),
                    onTap: onOpenTeam == null || profile.team.id.isEmpty
                        ? null
                        : () => onOpenTeam!(profile.team.id),
                    child: Text(
                      profile.team.abbreviation.isEmpty ? profile.team.id : profile.team.abbreviation,
                      style: TextStyle(
                        color: onOpenTeam == null ? _text : _blue,
                        fontWeight: FontWeight.w900,
                        decoration: onOpenTeam == null ? null : TextDecoration.underline,
                        decorationColor: _blue,
                      ),
                    ),
                  ),
                ),
                DataCell(Text('${profile.explicitTeamEvents}')),
                DataCell(Text('${profile.closeWindowEvents}')),
                DataCell(Text('${profile.observedScoreDeltaPoints}')),
                DataCell(Text('${profile.creditedPlayerPoints}')),
                DataCell(Text('${profile.uncreditedTeamObservedPoints}')),
                DataCell(Text('${profile.categoryCount(NbaPbpEventCategory.madeFieldGoal)}')),
                DataCell(Text('${profile.categoryCount(NbaPbpEventCategory.missedFieldGoal)}')),
                DataCell(Text('${profile.categoryCount(NbaPbpEventCategory.turnover)}')),
                DataCell(Text('${profile.categoryCount(NbaPbpEventCategory.foul)}')),
                DataCell(Text('${profile.confirmedSubstitutions}')),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlayerProfiles extends StatelessWidget {
  const _PlayerProfiles({required this.result, required this.onOpenPlayer});

  final NbaGamePlayerEventProfileResult result;
  final void Function(String playerId, String playerName)? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    if (!result.hasProfiles) {
      return const _Unavailable(
        title: 'No player event profiles are available.',
        detail: 'Sports Terminal does not manufacture player event participation from the box score when row-level PBP is absent.',
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_panel2),
        headingTextStyle: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900),
        dataTextStyle: const TextStyle(color: _text, fontSize: 9),
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('PLAYER')),
          DataColumn(label: Text('TEAM')),
          DataColumn(label: Text('EVENTS')),
          DataColumn(label: Text('PRIMARY')),
          DataColumn(label: Text('SECONDARY')),
          DataColumn(label: Text('CLOSE EVENTS')),
          DataColumn(label: Text('OBS PTS')),
          DataColumn(label: Text('CLOSE PTS')),
          DataColumn(label: Text('MADE FG')),
          DataColumn(label: Text('MISS FG')),
          DataColumn(label: Text('TO')),
          DataColumn(label: Text('REB')),
          DataColumn(label: Text('SUB IN/OUT')),
        ],
        rows: [
          for (final profile in result.profiles)
            DataRow(
              cells: [
                DataCell(
                  InkWell(
                    key: ValueKey('player-event-profile-${profile.player.id}'),
                    onTap: onOpenPlayer == null || profile.player.id.isEmpty
                        ? null
                        : () => onOpenPlayer!(profile.player.id, profile.player.label),
                    child: Text(
                      profile.player.label,
                      style: TextStyle(
                        color: onOpenPlayer == null ? _text : _blue,
                        fontWeight: FontWeight.w900,
                        decoration: onOpenPlayer == null ? null : TextDecoration.underline,
                        decorationColor: _blue,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(profile.teamLabel)),
                DataCell(Text('${profile.participationEvents}')),
                DataCell(Text('${profile.primaryEvents}')),
                DataCell(Text('${profile.secondaryAppearances}')),
                DataCell(Text('${profile.closeWindowParticipationEvents}')),
                DataCell(Text('${profile.observedPoints}')),
                DataCell(Text('${profile.closeWindowPoints}')),
                DataCell(Text('${profile.categoryCount(NbaPbpEventCategory.madeFieldGoal)}')),
                DataCell(Text('${profile.categoryCount(NbaPbpEventCategory.missedFieldGoal)}')),
                DataCell(Text('${profile.categoryCount(NbaPbpEventCategory.turnover)}')),
                DataCell(Text('${profile.categoryCount(NbaPbpEventCategory.rebound)}')),
                DataCell(Text('${profile.confirmedSubstitutionIns}/${profile.confirmedSubstitutionOuts}')),
              ],
            ),
        ],
      ),
    );
  }
}

class _SegmentBarPainter extends CustomPainter {
  const _SegmentBarPainter({
    required this.segments,
    required this.awayLabel,
    required this.homeLabel,
  });

  final List<NbaGameSegment> segments;
  final String awayLabel;
  final String homeLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty || size.width <= 0 || size.height <= 0) return;
    const labelWidth = 76.0;
    const right = 8.0;
    const top = 8.0;
    const gap = 4.0;
    final rowHeight = (size.height - top * 2) / segments.length;
    final usable = math.max(1.0, size.width - labelWidth - right);
    final maxPoints = math.max(
      1,
      segments.fold<int>(0, (current, segment) {
        return math.max(current, math.max(segment.homeObservedPoints, segment.awayObservedPoints));
      }),
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final background = Paint()..color = _line.withValues(alpha: .35);
    final awayPaint = Paint()..color = _amber.withValues(alpha: .82);
    final homePaint = Paint()..color = _green.withValues(alpha: .82);

    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final y = top + index * rowHeight;
      final barHeight = math.max(4.0, (rowHeight - gap * 3) / 2);
      _paintText(textPainter, canvas, segment.label, const Offset(0, 0) + Offset(0, y + 2), _muted, 8);
      canvas.drawRect(Rect.fromLTWH(labelWidth, y, usable, barHeight), background);
      canvas.drawRect(Rect.fromLTWH(labelWidth, y + barHeight + gap, usable, barHeight), background);
      canvas.drawRect(
        Rect.fromLTWH(labelWidth, y, usable * segment.awayObservedPoints / maxPoints, barHeight),
        awayPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          labelWidth,
          y + barHeight + gap,
          usable * segment.homeObservedPoints / maxPoints,
          barHeight,
        ),
        homePaint,
      );
      _paintText(
        textPainter,
        canvas,
        '${segment.awayObservedPoints}',
        Offset(labelWidth + 3, y - 1),
        _text,
        7,
      );
      _paintText(
        textPainter,
        canvas,
        '${segment.homeObservedPoints}',
        Offset(labelWidth + 3, y + barHeight + gap - 1),
        _text,
        7,
      );
    }
  }

  void _paintText(
    TextPainter painter,
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize,
  ) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w800),
    );
    painter.layout(maxWidth: 72);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SegmentBarPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.awayLabel != awayLabel ||
      oldDelegate.homeLabel != homeLabel;
}

Widget _section({required Key key, required String title, required Widget child, Widget? trailing}) =>
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
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );

Widget _legend(String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w800)),
      ],
    );

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 9, height: 1.4)),
          ],
        ),
      );
}
