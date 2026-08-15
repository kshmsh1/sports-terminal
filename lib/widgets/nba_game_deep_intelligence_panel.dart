import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/nba_game_analytics_engine.dart';
import '../services/nba_game_context_engine.dart';
import '../services/nba_game_intelligence_engine.dart';
import '../services/nba_game_play_by_play_engine.dart';
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

class NbaGameDeepIntelligencePanel extends StatelessWidget {
  const NbaGameDeepIntelligencePanel({
    super.key,
    required this.seed,
    required this.game,
    this.onOpenGame,
    this.onOpenTeam,
    this.onOpenPlayer,
    this.timelineLimit = 40,
  });

  final NbaTerminalSeedSnapshot seed;
  final NbaGameIntelligenceSnapshot game;
  final void Function(String gameId, String gameLabel)? onOpenGame;
  final ValueChanged<String>? onOpenTeam;
  final void Function(String playerId, String playerName)? onOpenPlayer;
  final int timelineLimit;

  @override
  Widget build(BuildContext context) {
    final analytics = const NbaGameAnalyticsEngine().build(
      seed,
      gameId: game.gameId,
    );
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: game.gameId);
    final contextData = const NbaGameContextEngine().build(
      seed,
      gameId: game.gameId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          title: 'GAME FLOW INTELLIGENCE',
          trailing: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(pbp.availabilityLabel, pbp.hasEvents ? _green : _amber),
              _pill('${pbp.eventCount} EVENTS', _blue),
              _pill('${analytics.scoreStateCount} SCORE STATES', _blue),
              if (analytics.hasScoreProgression)
                _pill(
                  analytics.completeObservedTimeline
                      ? 'OBSERVED TIMELINE COMPLETE'
                      : 'OBSERVED TIMELINE PARTIAL',
                  analytics.completeObservedTimeline ? _green : _amber,
                ),
            ],
          ),
          child: analytics.hasScoreProgression
              ? _GameFlowBody(analytics: analytics)
              : _Unavailable(
                  title: pbp.availabilityLabel == 'EVENT ROWS NOT EXPOSED'
                      ? 'Play-by-play exists upstream but event rows are not exposed in this seed.'
                      : 'No score-event timeline is available for this game.',
                  detail:
                      'Sports Terminal will not infer possession-by-possession scoring from the final box score. Period scoring and box-score analysis remain available above.',
                ),
        ),
        const SizedBox(height: 12),
        _section(
          title: 'PLAY-BY-PLAY TIMELINE',
          trailing: _pill('${pbp.periodsCovered} PERIODS', _blue),
          child: pbp.events.isEmpty
              ? _Unavailable(
                  title: 'Event feed unavailable in the active release.',
                  detail: pbp.declaredNormalizedEventCount > 0
                      ? '${pbp.declaredNormalizedEventCount} normalized events are declared by release metadata, but row-level events were not included in this client seed.'
                      : 'No row-level play-by-play events were supplied for this game.',
                )
              : _PbpTimeline(
                  events: pbp.events.take(timelineLimit).toList(growable: false),
                  totalEvents: pbp.eventCount,
                  onOpenTeam: onOpenTeam,
                  onOpenPlayer: onOpenPlayer,
                ),
        ),
        const SizedBox(height: 12),
        _section(
          title: 'MATCHUP / ENTERING CONTEXT',
          trailing: _pill(
            '${contextData.priorMeetings} PRIOR MEETINGS',
            contextData.priorMeetings > 0 ? _green : _muted,
          ),
          child: _ContextBody(
            contextData: contextData,
            onOpenGame: onOpenGame,
            onOpenTeam: onOpenTeam,
          ),
        ),
        const SizedBox(height: 12),
        _section(
          title: 'PLAYER FORM ENTERING GAME',
          trailing: _pill('LAST ${contextData.playerWindow} MAX', _blue),
          child: _PlayerFormBody(
            contextData: contextData,
            onOpenPlayer: onOpenPlayer,
          ),
        ),
      ],
    );
  }

  static Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) =>
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
        ),
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ],
        ),
      );

  static Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _GameFlowBody extends StatelessWidget {
  const _GameFlowBody({required this.analytics});

  final NbaGameAnalyticsResult analytics;

  @override
  Widget build(BuildContext context) {
    final largestRun = analytics.largestScoringRun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric('LEAD CHANGES', '${analytics.leadChanges}'),
            _metric('TIES', '${analytics.ties}'),
            _metric(
              '${analytics.homeTeam.abbreviation} MAX LEAD',
              analytics.largestHomeLead == null ? '—' : '+${analytics.largestHomeLead}',
            ),
            _metric(
              '${analytics.awayTeam.abbreviation} MAX LEAD',
              analytics.largestAwayLead == null ? '—' : '+${analytics.largestAwayLead}',
            ),
            _metric(
              'LARGEST OBSERVED RUN',
              largestRun == null ? '—' : largestRun.label(analytics),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 210,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          decoration: BoxDecoration(
            color: _panel2,
            border: Border.all(color: _line),
          ),
          child: CustomPaint(
            key: const ValueKey('game-score-margin-chart'),
            painter: _ScoreMarginPainter(
              points: analytics.scoreProgression,
              homeLabel: analytics.homeTeam.abbreviation,
              awayLabel: analytics.awayTeam.abbreviation,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          analytics.completeObservedTimeline
              ? 'Observed score margin from the supplied event feed. Zero is tied; positive values favor ${analytics.homeTeam.abbreviation}, negative values favor ${analytics.awayTeam.abbreviation}.'
              : 'Partial observed score margin. The supplied event feed does not establish a complete tip-to-final sequence, so run and lead metrics describe only observed score states.',
          style: const TextStyle(color: _muted, fontSize: 10, height: 1.4),
        ),
        if (analytics.finalScoreMismatch) ...[
          const SizedBox(height: 8),
          const Text(
            'The last observed play-by-play score does not reconcile to the canonical final score.',
            style: TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ],
    );
  }

  Widget _metric(String label, String value) => Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _panel2,
          border: Border.all(color: _line),
        ),
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
              style: const TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _PbpTimeline extends StatelessWidget {
  const _PbpTimeline({
    required this.events,
    required this.totalEvents,
    required this.onOpenTeam,
    required this.onOpenPlayer,
  });

  final List<NbaGamePlayByPlayEvent> events;
  final int totalEvents;
  final ValueChanged<String>? onOpenTeam;
  final void Function(String playerId, String playerName)? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < events.length; index++) ...[
          _event(events[index], index),
          if (index != events.length - 1) const Divider(height: 15, color: _line),
        ],
        if (events.length < totalEvents) ...[
          const SizedBox(height: 12),
          Text(
            'Showing first ${events.length} of $totalEvents canonical events.',
            style: const TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ],
    );
  }

  Widget _event(NbaGamePlayByPlayEvent event, int index) {
    final teamLabel = event.team.abbreviation.isEmpty
        ? event.team.id
        : event.team.abbreviation;
    final playerLabel = event.player.name.isEmpty ? event.player.id : event.player.name;
    return Row(
      key: ValueKey('pbp-event-${event.sequence ?? index}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${event.periodLabel} ${event.clock.isEmpty ? '' : event.clock}'.trim(),
                style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                event.scoreLabel,
                style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    event.typeLabel,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .35,
                    ),
                  ),
                  if (teamLabel.isNotEmpty)
                    _entity(
                      label: teamLabel,
                      enabled: onOpenTeam != null && event.team.id.isNotEmpty,
                      onTap: () => onOpenTeam?.call(event.team.id),
                    ),
                  if (playerLabel.isNotEmpty)
                    _entity(
                      label: playerLabel,
                      enabled: onOpenPlayer != null && event.player.id.isNotEmpty,
                      onTap: () => onOpenPlayer?.call(
                        event.player.id,
                        event.player.name,
                      ),
                    ),
                ],
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: const TextStyle(color: _text, fontSize: 10, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _entity({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: enabled ? onTap : null,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? _blue : _muted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            decoration: enabled ? TextDecoration.underline : null,
            decorationColor: _blue,
          ),
        ),
      );
}

class _ContextBody extends StatelessWidget {
  const _ContextBody({
    required this.contextData,
    required this.onOpenGame,
    required this.onOpenTeam,
  });

  final NbaGameContextResult contextData;
  final void Function(String gameId, String gameLabel)? onOpenGame;
  final ValueChanged<String>? onOpenTeam;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final home = _teamForm(contextData.homeEnteringForm, contextData.homeTeam);
            final away = _teamForm(contextData.awayEnteringForm, contextData.awayTeam);
            if (compact) {
              return Column(children: [away, const SizedBox(height: 8), home]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: away),
                const SizedBox(width: 8),
                Expanded(child: home),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'SEASON SERIES · ${contextData.awayTeam.abbreviation} ${contextData.awayPriorWins} – ${contextData.homePriorWins} ${contextData.homeTeam.abbreviation} entering game',
                style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (contextData.relatedGames.isEmpty)
          const Text(
            'No other same-season canonical meetings are available.',
            style: TextStyle(color: _muted, fontSize: 10),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final related in contextData.relatedGames)
                InkWell(
                  key: ValueKey('related-game-${related.gameId}'),
                  onTap: onOpenGame == null
                      ? null
                      : () => onOpenGame!(related.gameId, related.matchupLabel),
                  child: Container(
                    width: 190,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _panel2,
                      border: Border.all(
                        color: related.beforeFocalGame ? _line : _blue.withValues(alpha: .45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          related.beforeFocalGame ? 'PRIOR MEETING' : 'LATER MEETING',
                          style: TextStyle(
                            color: related.beforeFocalGame ? _muted : _blue,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          related.matchupLabel,
                          style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${related.gameDate.isEmpty ? '—' : related.gameDate} · ${related.scoreLabel}',
                          style: const TextStyle(color: _muted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _teamForm(NbaTeamEnteringForm form, NbaGameTeam team) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenTeam == null || team.id.isEmpty
                  ? null
                  : () => onOpenTeam!(team.id),
              child: Text(
                '${team.abbreviation} · LAST ${form.windowRequested} ENTERING',
                style: TextStyle(
                  color: onOpenTeam == null ? _text : _blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 7,
              children: [
                _datum('G', '${form.games}'),
                _datum('REC', form.recordLabel),
                _datum('STREAK', form.streakLabel),
                _datum('PF', _decimal(form.pointsForPerGame)),
                _datum('PA', _decimal(form.pointsAgainstPerGame)),
                _datum('MARGIN', _signed(form.marginPerGame)),
              ],
            ),
          ],
        ),
      );

  Widget _datum(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 9),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(color: _muted)),
            TextSpan(text: value, style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _PlayerFormBody extends StatelessWidget {
  const _PlayerFormBody({
    required this.contextData,
    required this.onOpenPlayer,
  });

  final NbaGameContextResult contextData;
  final void Function(String playerId, String playerName)? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    if (contextData.playerEnteringForms.isEmpty) {
      return const _Unavailable(
        title: 'No focal-game player rows are available.',
        detail: 'Player entering form requires canonical participants plus prior linked player game logs.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_panel2),
        headingTextStyle: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900),
        dataTextStyle: const TextStyle(color: _text, fontSize: 9),
        columnSpacing: 22,
        columns: const [
          DataColumn(label: Text('PLAYER')),
          DataColumn(label: Text('TEAM')),
          DataColumn(label: Text('G')),
          DataColumn(label: Text('PTS')),
          DataColumn(label: Text('REB')),
          DataColumn(label: Text('AST')),
          DataColumn(label: Text('+/-')),
          DataColumn(label: Text('LAST GAME')),
        ],
        rows: [
          for (final form in contextData.playerEnteringForms)
            DataRow(
              cells: [
                DataCell(
                  InkWell(
                    key: ValueKey('entering-form-player-${form.playerId}'),
                    onTap: onOpenPlayer == null
                        ? null
                        : () => onOpenPlayer!(form.playerId, form.playerName),
                    child: Text(
                      form.playerName.isEmpty ? form.playerId : form.playerName,
                      style: TextStyle(
                        color: onOpenPlayer == null ? _text : _blue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(form.teamId.isEmpty ? '—' : form.teamId)),
                DataCell(Text('${form.games}')),
                DataCell(Text(_decimal(form.pointsPerGame))),
                DataCell(Text(_decimal(form.reboundsPerGame))),
                DataCell(Text(_decimal(form.assistsPerGame))),
                DataCell(Text(_signed(form.plusMinusPerGame))),
                DataCell(Text(form.lastGameDate.isEmpty ? '—' : form.lastGameDate)),
              ],
            ),
        ],
      ),
    );
  }
}

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
            Text(
              title,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              style: const TextStyle(color: _muted, fontSize: 10, height: 1.4),
            ),
          ],
        ),
      );
}

class _ScoreMarginPainter extends CustomPainter {
  const _ScoreMarginPainter({
    required this.points,
    required this.homeLabel,
    required this.awayLabel,
  });

  final List<NbaGameScorePoint> points;
  final String homeLabel;
  final String awayLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    const left = 34.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 24.0;
    final width = math.max(1.0, size.width - left - right);
    final height = math.max(1.0, size.height - top - bottom);
    final maxAbs = math.max(
      1,
      points.fold<int>(0, (value, point) => math.max(value, point.homeMargin.abs())),
    );
    final baselineY = top + height / 2;

    final grid = Paint()
      ..color = _line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, baselineY), Offset(left + width, baselineY), grid);
    canvas.drawLine(Offset(left, top), Offset(left, top + height), grid);

    final knownElapsed = points.where((point) => point.elapsedGameSeconds != null).toList();
    final minElapsed = knownElapsed.isEmpty
        ? null
        : knownElapsed.map((point) => point.elapsedGameSeconds!).reduce(math.min);
    final maxElapsed = knownElapsed.isEmpty
        ? null
        : knownElapsed.map((point) => point.elapsedGameSeconds!).reduce(math.max);
    final useElapsed = minElapsed != null && maxElapsed != null && maxElapsed > minElapsed;

    Offset position(NbaGameScorePoint point, int index) {
      final fraction = useElapsed
          ? ((point.elapsedGameSeconds ?? minElapsed) - minElapsed) /
              (maxElapsed - minElapsed)
          : points.length == 1
              ? 0.5
              : index / (points.length - 1);
      final x = left + fraction.clamp(0.0, 1.0) * width;
      final normalizedMargin = point.homeMargin / maxAbs;
      final y = baselineY - normalizedMargin * (height / 2 - 5);
      return Offset(x, y);
    }

    final path = Path();
    for (var index = 0; index < points.length; index += 1) {
      final offset = position(points[index], index);
      if (index == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    final series = Paint()
      ..color = _blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, series);

    final dot = Paint()..color = _text;
    for (var index = 0; index < points.length; index += 1) {
      canvas.drawCircle(position(points[index], index), 2.2, dot);
    }

    _label(canvas, '+$maxAbs', Offset(2, top - 2), _green);
    _label(canvas, '0', Offset(12, baselineY - 6), _muted);
    _label(canvas, '-$maxAbs', Offset(2, top + height - 10), _amber);
    _label(canvas, homeLabel.isEmpty ? 'HOME' : homeLabel, Offset(left + 4, 0), _green);
    _label(canvas, awayLabel.isEmpty ? 'AWAY' : awayLabel, Offset(left + 4, size.height - 15), _amber);
  }

  void _label(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ScoreMarginPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.homeLabel != homeLabel ||
      oldDelegate.awayLabel != awayLabel;
}

String _decimal(num? value) => value == null ? '—' : value.toStringAsFixed(1);
String _signed(num? value) {
  if (value == null) return '—';
  final prefix = value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)}';
}
