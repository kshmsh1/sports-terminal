import 'nba_game_intelligence_engine.dart';
import 'nba_game_play_by_play_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Attributes observed score deltas to players only when a canonical scoring
/// event and a primary player are both explicit. Unattributable score changes
/// remain visible instead of being assigned heuristically.
class NbaGamePlayerScoringEngine {
  const NbaGamePlayerScoringEngine();

  NbaGamePlayerScoringResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
  }) {
    final game = const NbaGameIntelligenceEngine().build(
      seed: seed,
      gameId: gameId,
    );
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: gameId);

    final playerTeamById = <String, String>{};
    for (final line in game.playerLines) {
      if (line.playerId.trim().isNotEmpty && line.teamId.trim().isNotEmpty) {
        playerTeamById[_normalize(line.playerId)] = line.teamId;
      }
    }
    for (final raw in seed.players) {
      final id = _text(raw, const ['player_id', 'playerId', 'person_id', 'id']);
      final teamId = _text(raw, const ['team_id', 'teamId', 'current_team_id']);
      if (id.isNotEmpty && teamId.isNotEmpty) {
        playerTeamById.putIfAbsent(_normalize(id), () => teamId);
      }
    }

    final credited = <NbaObservedPlayerScore>[];
    final uncredited = <NbaUncreditedScoreChange>[];
    final builders = <String, _PlayerScoringBuilder>{};
    int? previousHome;
    int? previousAway;
    var observedHomePoints = 0;
    var observedAwayPoints = 0;

    for (final event in pbp.events) {
      if (!event.hasScore) continue;
      if (previousHome == null || previousAway == null) {
        previousHome = event.homeScore;
        previousAway = event.awayScore;
        continue;
      }

      final homeDelta = event.homeScore! - previousHome;
      final awayDelta = event.awayScore! - previousAway;
      previousHome = event.homeScore;
      previousAway = event.awayScore;

      if (homeDelta < 0 || awayDelta < 0 || (homeDelta == 0 && awayDelta == 0)) {
        continue;
      }
      if (homeDelta > 0) observedHomePoints += homeDelta;
      if (awayDelta > 0) observedAwayPoints += awayDelta;

      final side = homeDelta > 0 && awayDelta == 0
          ? NbaObservedScoringSide.home
          : awayDelta > 0 && homeDelta == 0
              ? NbaObservedScoringSide.away
              : NbaObservedScoringSide.unknown;
      final points = homeDelta + awayDelta;
      final expectedTeamId = side == NbaObservedScoringSide.home
          ? game.homeTeam.id
          : side == NbaObservedScoringSide.away
              ? game.awayTeam.id
              : '';
      final player = event.player;
      final playerTeamId = playerTeamById[_normalize(player.id)] ?? '';
      final eventTeamId = event.team.id;
      final teamEvidence = eventTeamId.isNotEmpty ? eventTeamId : playerTeamId;
      final teamConfirmed = expectedTeamId.isNotEmpty &&
          teamEvidence.isNotEmpty &&
          _normalize(expectedTeamId) == _normalize(teamEvidence);
      final canCredit = side != NbaObservedScoringSide.unknown &&
          points > 0 &&
          event.isScoringAction &&
          !player.isEmpty &&
          (teamEvidence.isEmpty || teamConfirmed);

      if (!canCredit) {
        uncredited.add(
          NbaUncreditedScoreChange(
            sequence: event.sequence,
            periodLabel: event.periodLabel,
            clock: event.clock,
            side: side,
            points: points,
            homeScore: event.homeScore!,
            awayScore: event.awayScore!,
            reason: _uncreditedReason(
              event: event,
              side: side,
              teamEvidence: teamEvidence,
              teamConfirmed: teamConfirmed,
            ),
            description: event.description,
          ),
        );
        continue;
      }

      final inCloseWindow = event.period != null &&
          event.period! >= 4 &&
          event.clockSecondsRemaining != null &&
          event.clockSecondsRemaining! <= 300 &&
          event.margin != null &&
          event.margin!.abs() <= 5;
      final score = NbaObservedPlayerScore(
        player: player,
        teamId: expectedTeamId,
        side: side,
        sequence: event.sequence,
        period: event.period,
        periodLabel: event.periodLabel,
        clock: event.clock,
        points: points,
        homeScore: event.homeScore!,
        awayScore: event.awayScore!,
        closeWindow: inCloseWindow,
        teamConfirmed: teamConfirmed,
        description: event.description,
      );
      credited.add(score);
      final key = _normalize(player.id.isNotEmpty ? player.id : player.label);
      final builder = builders.putIfAbsent(
        key,
        () => _PlayerScoringBuilder(
          player: player,
          teamId: expectedTeamId,
          side: side,
        ),
      );
      builder.points += points;
      builder.scoringEvents += 1;
      if (inCloseWindow) {
        builder.closeWindowPoints += points;
        builder.closeWindowScoringEvents += 1;
      }
      builder.lastScore = score;
      if (points > builder.largestSingleChange) builder.largestSingleChange = points;
    }

    final players = builders.values.map((builder) => builder.build()).toList()
      ..sort((left, right) {
        final points = right.observedPoints.compareTo(left.observedPoints);
        if (points != 0) return points;
        final events = right.scoringEvents.compareTo(left.scoringEvents);
        if (events != 0) return events;
        return left.player.label.compareTo(right.player.label);
      });

    return NbaGamePlayerScoringResult(
      gameId: game.gameId,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      players: List.unmodifiable(players),
      creditedScores: List.unmodifiable(credited),
      uncreditedScoreChanges: List.unmodifiable(uncredited),
      observedHomePoints: observedHomePoints,
      observedAwayPoints: observedAwayPoints,
      playByPlayAvailability: pbp.availabilityLabel,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }
}

enum NbaObservedScoringSide { home, away, unknown }

class NbaGamePlayerScoringResult {
  const NbaGamePlayerScoringResult({
    required this.gameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.players,
    required this.creditedScores,
    required this.uncreditedScoreChanges,
    required this.observedHomePoints,
    required this.observedAwayPoints,
    required this.playByPlayAvailability,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final NbaGameTeam homeTeam;
  final NbaGameTeam awayTeam;
  final List<NbaObservedPlayerScoringSummary> players;
  final List<NbaObservedPlayerScore> creditedScores;
  final List<NbaUncreditedScoreChange> uncreditedScoreChanges;
  final int observedHomePoints;
  final int observedAwayPoints;
  final String playByPlayAvailability;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasObservedScoring => creditedScores.isNotEmpty || uncreditedScoreChanges.isNotEmpty;
  int get creditedPoints => creditedScores.fold(0, (sum, event) => sum + event.points);
  int get uncreditedPoints =>
      uncreditedScoreChanges.fold(0, (sum, event) => sum + event.points);
  int get observedPoints => observedHomePoints + observedAwayPoints;
  bool get fullyAttributed => hasObservedScoring && uncreditedPoints == 0;
}

class NbaObservedPlayerScoringSummary {
  const NbaObservedPlayerScoringSummary({
    required this.player,
    required this.teamId,
    required this.side,
    required this.observedPoints,
    required this.scoringEvents,
    required this.closeWindowPoints,
    required this.closeWindowScoringEvents,
    required this.largestSingleChange,
    required this.lastScore,
  });

  final NbaPbpPlayerIdentity player;
  final String teamId;
  final NbaObservedScoringSide side;
  final int observedPoints;
  final int scoringEvents;
  final int closeWindowPoints;
  final int closeWindowScoringEvents;
  final int largestSingleChange;
  final NbaObservedPlayerScore? lastScore;
}

class NbaObservedPlayerScore {
  const NbaObservedPlayerScore({
    required this.player,
    required this.teamId,
    required this.side,
    required this.sequence,
    required this.period,
    required this.periodLabel,
    required this.clock,
    required this.points,
    required this.homeScore,
    required this.awayScore,
    required this.closeWindow,
    required this.teamConfirmed,
    required this.description,
  });

  final NbaPbpPlayerIdentity player;
  final String teamId;
  final NbaObservedScoringSide side;
  final int? sequence;
  final int? period;
  final String periodLabel;
  final String clock;
  final int points;
  final int homeScore;
  final int awayScore;
  final bool closeWindow;
  final bool teamConfirmed;
  final String description;

  String get scoreLabel => '$awayScore–$homeScore';
}

class NbaUncreditedScoreChange {
  const NbaUncreditedScoreChange({
    required this.sequence,
    required this.periodLabel,
    required this.clock,
    required this.side,
    required this.points,
    required this.homeScore,
    required this.awayScore,
    required this.reason,
    required this.description,
  });

  final int? sequence;
  final String periodLabel;
  final String clock;
  final NbaObservedScoringSide side;
  final int points;
  final int homeScore;
  final int awayScore;
  final String reason;
  final String description;

  String get scoreLabel => '$awayScore–$homeScore';
}

class _PlayerScoringBuilder {
  _PlayerScoringBuilder({
    required this.player,
    required this.teamId,
    required this.side,
  });

  final NbaPbpPlayerIdentity player;
  final String teamId;
  final NbaObservedScoringSide side;
  int points = 0;
  int scoringEvents = 0;
  int closeWindowPoints = 0;
  int closeWindowScoringEvents = 0;
  int largestSingleChange = 0;
  NbaObservedPlayerScore? lastScore;

  NbaObservedPlayerScoringSummary build() => NbaObservedPlayerScoringSummary(
        player: player,
        teamId: teamId,
        side: side,
        observedPoints: points,
        scoringEvents: scoringEvents,
        closeWindowPoints: closeWindowPoints,
        closeWindowScoringEvents: closeWindowScoringEvents,
        largestSingleChange: largestSingleChange,
        lastScore: lastScore,
      );
}

String _uncreditedReason({
  required NbaGamePlayByPlayEvent event,
  required NbaObservedScoringSide side,
  required String teamEvidence,
  required bool teamConfirmed,
}) {
  if (side == NbaObservedScoringSide.unknown) return 'simultaneous-or-ambiguous-score-change';
  if (!event.isScoringAction) return 'score-change-without-explicit-scoring-action';
  if (event.player.isEmpty) return 'scoring-player-not-exposed';
  if (teamEvidence.isNotEmpty && !teamConfirmed) return 'scoring-team-conflicts-with-score-delta';
  return 'insufficient-attribution-evidence';
}

String _normalize(String value) => value.trim().toUpperCase();

String _text(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value == null || value is Map || value is Iterable) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != '—' && text.toLowerCase() != 'null') return text;
  }
  return '';
}
