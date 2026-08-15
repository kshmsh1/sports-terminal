import 'nba_game_intelligence_engine.dart';
import 'nba_game_play_by_play_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Transparent game-flow analytics derived only from explicit canonical game
/// and play-by-play score states. No win probability or modeled estimates are
/// produced here.
class NbaGameAnalyticsEngine {
  const NbaGameAnalyticsEngine();

  NbaGameAnalyticsResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
  }) {
    final game = const NbaGameIntelligenceEngine().build(
      seed: seed,
      gameId: gameId,
    );
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: gameId);

    final scoreStates = <NbaGameScorePoint>[];
    NbaGamePlayByPlayEvent? previousScoreEvent;
    for (final event in pbp.events) {
      if (!event.hasScore) continue;
      if (previousScoreEvent != null &&
          previousScoreEvent.homeScore == event.homeScore &&
          previousScoreEvent.awayScore == event.awayScore) {
        continue;
      }
      scoreStates.add(
        NbaGameScorePoint(
          sequence: event.sequence,
          period: event.period,
          periodLabel: event.periodLabel,
          clock: event.clock,
          elapsedGameSeconds: event.elapsedGameSeconds,
          homeScore: event.homeScore!,
          awayScore: event.awayScore!,
          homeMargin: event.margin!,
          description: event.description,
        ),
      );
      previousScoreEvent = event;
    }

    var leadChanges = 0;
    var ties = 0;
    var largestHomeLead = 0;
    var largestAwayLead = 0;
    var lastNonTiedLeader = 0;
    var previousMargin = 0;
    var hasPrevious = false;
    for (final point in scoreStates) {
      final margin = point.homeMargin;
      if (margin > largestHomeLead) largestHomeLead = margin;
      if (-margin > largestAwayLead) largestAwayLead = -margin;

      if (margin == 0) {
        if (hasPrevious && previousMargin != 0) ties += 1;
      } else {
        final leader = margin > 0 ? 1 : -1;
        if (lastNonTiedLeader != 0 && leader != lastNonTiedLeader) {
          leadChanges += 1;
        }
        lastNonTiedLeader = leader;
      }
      previousMargin = margin;
      hasPrevious = true;
    }

    final runs = _scoringRuns(scoreStates);
    final largestRun = runs.isEmpty
        ? null
        : runs.reduce((left, right) => left.points >= right.points ? left : right);
    final first = scoreStates.isEmpty ? null : scoreStates.first;
    final last = scoreStates.isEmpty ? null : scoreStates.last;
    final startsAtKnownBaseline = first != null &&
        first.homeScore == 0 &&
        first.awayScore == 0 &&
        first.period == 1;
    final matchesFinalScore = last != null &&
        game.homeScore != null &&
        game.awayScore != null &&
        last.homeScore == game.homeScore &&
        last.awayScore == game.awayScore;

    return NbaGameAnalyticsResult(
      gameId: game.gameId,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      homeScore: game.homeScore,
      awayScore: game.awayScore,
      scoreProgression: List.unmodifiable(scoreStates),
      scoringRuns: List.unmodifiable(runs),
      leadChanges: leadChanges,
      ties: ties,
      largestHomeLead: scoreStates.isEmpty ? null : largestHomeLead,
      largestAwayLead: scoreStates.isEmpty ? null : largestAwayLead,
      largestScoringRun: largestRun,
      startsAtKnownBaseline: startsAtKnownBaseline,
      matchesFinalScore: matchesFinalScore,
      playByPlayAvailability: pbp.availabilityLabel,
      sourceEventCount: pbp.eventCount,
      scoreStateCount: scoreStates.length,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }

  List<NbaGameScoringRun> _scoringRuns(List<NbaGameScorePoint> states) {
    if (states.length < 2) return const [];

    final runs = <NbaGameScoringRun>[];
    _RunBuilder? active;
    for (var index = 1; index < states.length; index += 1) {
      final previous = states[index - 1];
      final current = states[index];
      final homeDelta = current.homeScore - previous.homeScore;
      final awayDelta = current.awayScore - previous.awayScore;
      if (homeDelta < 0 || awayDelta < 0) {
        active = null;
        continue;
      }
      if (homeDelta == 0 && awayDelta == 0) continue;

      final scoringSide = homeDelta > 0 && awayDelta == 0
          ? NbaGameScoringSide.home
          : awayDelta > 0 && homeDelta == 0
              ? NbaGameScoringSide.away
              : NbaGameScoringSide.unknown;
      final points = homeDelta + awayDelta;
      if (scoringSide == NbaGameScoringSide.unknown) {
        active = null;
        continue;
      }

      if (active == null || active.side != scoringSide) {
        if (active != null) runs.add(active.build());
        active = _RunBuilder(
          side: scoringSide,
          points: points,
          start: previous,
          end: current,
        );
      } else {
        active.points += points;
        active.end = current;
      }
    }
    if (active != null) runs.add(active.build());
    return runs;
  }
}

class NbaGameAnalyticsResult {
  const NbaGameAnalyticsResult({
    required this.gameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.scoreProgression,
    required this.scoringRuns,
    required this.leadChanges,
    required this.ties,
    required this.largestHomeLead,
    required this.largestAwayLead,
    required this.largestScoringRun,
    required this.startsAtKnownBaseline,
    required this.matchesFinalScore,
    required this.playByPlayAvailability,
    required this.sourceEventCount,
    required this.scoreStateCount,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final NbaGameTeam homeTeam;
  final NbaGameTeam awayTeam;
  final int? homeScore;
  final int? awayScore;
  final List<NbaGameScorePoint> scoreProgression;
  final List<NbaGameScoringRun> scoringRuns;
  final int leadChanges;
  final int ties;
  final int? largestHomeLead;
  final int? largestAwayLead;
  final NbaGameScoringRun? largestScoringRun;
  final bool startsAtKnownBaseline;
  final bool matchesFinalScore;
  final String playByPlayAvailability;
  final int sourceEventCount;
  final int scoreStateCount;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasScoreProgression => scoreProgression.isNotEmpty;
  bool get completeObservedTimeline =>
      startsAtKnownBaseline && (homeScore == null || awayScore == null || matchesFinalScore);
  bool get finalScoreMismatch =>
      scoreProgression.isNotEmpty && homeScore != null && awayScore != null && !matchesFinalScore;
}

class NbaGameScorePoint {
  const NbaGameScorePoint({
    required this.sequence,
    required this.period,
    required this.periodLabel,
    required this.clock,
    required this.elapsedGameSeconds,
    required this.homeScore,
    required this.awayScore,
    required this.homeMargin,
    required this.description,
  });

  final int? sequence;
  final int? period;
  final String periodLabel;
  final String clock;
  final double? elapsedGameSeconds;
  final int homeScore;
  final int awayScore;
  final int homeMargin;
  final String description;

  String get scoreLabel => '$awayScore–$homeScore';
}

enum NbaGameScoringSide { home, away, unknown }

class NbaGameScoringRun {
  const NbaGameScoringRun({
    required this.side,
    required this.points,
    required this.start,
    required this.end,
  });

  final NbaGameScoringSide side;
  final int points;
  final NbaGameScorePoint start;
  final NbaGameScorePoint end;

  String label(NbaGameAnalyticsResult analytics) {
    final team = side == NbaGameScoringSide.home
        ? analytics.homeTeam.abbreviation
        : analytics.awayTeam.abbreviation;
    return '${team.isEmpty ? side.name.toUpperCase() : team} $points–0';
  }
}

class _RunBuilder {
  _RunBuilder({
    required this.side,
    required this.points,
    required this.start,
    required this.end,
  });

  final NbaGameScoringSide side;
  int points;
  final NbaGameScorePoint start;
  NbaGameScorePoint end;

  NbaGameScoringRun build() => NbaGameScoringRun(
        side: side,
        points: points,
        start: start,
        end: end,
      );
}
