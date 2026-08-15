import 'nba_game_intelligence_engine.dart';
import 'nba_game_play_by_play_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Transparent late-game analysis built only from explicit play-by-play score
/// states. This intentionally avoids possession estimates or win probability.
///
/// Sports Terminal's observed close-game window is:
/// - fourth quarter or overtime,
/// - 5:00 or less remaining in the active period,
/// - explicit post-event score margin of five points or fewer.
class NbaGameClutchEngine {
  const NbaGameClutchEngine();

  NbaGameClutchResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
  }) {
    final game = const NbaGameIntelligenceEngine().build(
      seed: seed,
      gameId: gameId,
    );
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: gameId);

    final lateEvents = <NbaGamePlayByPlayEvent>[];
    final closeEvents = <NbaGamePlayByPlayEvent>[];
    final scoreChanges = <NbaGameClutchScoreChange>[];
    final lastTwoMinuteEvents = <NbaGamePlayByPlayEvent>[];
    final lastMinuteEvents = <NbaGamePlayByPlayEvent>[];

    int? previousHomeScore;
    int? previousAwayScore;
    int? previousCloseMargin;
    var homeClosePoints = 0;
    var awayClosePoints = 0;
    var closeLeadChanges = 0;
    var closeTies = 0;
    var priorNonTiedLeader = 0;

    for (final event in pbp.events) {
      final period = event.period;
      final remaining = event.clockSecondsRemaining;
      final isLate = period != null && period >= 4 && remaining != null && remaining <= 300;
      if (isLate) {
        lateEvents.add(event);
        if (remaining <= 120) lastTwoMinuteEvents.add(event);
        if (remaining <= 60) lastMinuteEvents.add(event);
      }

      if (!event.hasScore) continue;
      final currentHome = event.homeScore!;
      final currentAway = event.awayScore!;
      final margin = currentHome - currentAway;
      final inObservedCloseWindow = isLate && margin.abs() <= 5;

      if (inObservedCloseWindow) {
        closeEvents.add(event);

        if (margin == 0) {
          if (previousCloseMargin != null && previousCloseMargin != 0) {
            closeTies += 1;
          }
        } else {
          final leader = margin > 0 ? 1 : -1;
          if (priorNonTiedLeader != 0 && leader != priorNonTiedLeader) {
            closeLeadChanges += 1;
          }
          priorNonTiedLeader = leader;
        }
        previousCloseMargin = margin;

        if (previousHomeScore != null && previousAwayScore != null) {
          final homeDelta = currentHome - previousHomeScore;
          final awayDelta = currentAway - previousAwayScore;
          if (homeDelta >= 0 && awayDelta >= 0 && (homeDelta > 0 || awayDelta > 0)) {
            final side = homeDelta > 0 && awayDelta == 0
                ? NbaGameClutchScoringSide.home
                : awayDelta > 0 && homeDelta == 0
                    ? NbaGameClutchScoringSide.away
                    : NbaGameClutchScoringSide.unknown;
            final points = homeDelta + awayDelta;
            if (side == NbaGameClutchScoringSide.home) homeClosePoints += points;
            if (side == NbaGameClutchScoringSide.away) awayClosePoints += points;
            scoreChanges.add(
              NbaGameClutchScoreChange(
                sequence: event.sequence,
                period: event.period,
                periodLabel: event.periodLabel,
                clock: event.clock,
                side: side,
                points: points,
                homeScore: currentHome,
                awayScore: currentAway,
                margin: margin,
                player: event.player,
                team: event.team,
                description: event.description,
              ),
            );
          }
        }
      }

      previousHomeScore = currentHome;
      previousAwayScore = currentAway;
    }

    final firstClose = closeEvents.isEmpty ? null : closeEvents.first;
    final lastClose = closeEvents.isEmpty ? null : closeEvents.last;

    return NbaGameClutchResult(
      gameId: game.gameId,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      lateEvents: List.unmodifiable(lateEvents),
      closeEvents: List.unmodifiable(closeEvents),
      lastTwoMinuteEvents: List.unmodifiable(lastTwoMinuteEvents),
      lastMinuteEvents: List.unmodifiable(lastMinuteEvents),
      scoreChanges: List.unmodifiable(scoreChanges),
      homeClosePoints: homeClosePoints,
      awayClosePoints: awayClosePoints,
      closeLeadChanges: closeLeadChanges,
      closeTies: closeTies,
      firstClosePeriodLabel: firstClose?.periodLabel ?? '',
      firstCloseClock: firstClose?.clock ?? '',
      lastClosePeriodLabel: lastClose?.periodLabel ?? '',
      lastCloseClock: lastClose?.clock ?? '',
      playByPlayAvailability: pbp.availabilityLabel,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }
}

enum NbaGameClutchScoringSide { home, away, unknown }

class NbaGameClutchResult {
  const NbaGameClutchResult({
    required this.gameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.lateEvents,
    required this.closeEvents,
    required this.lastTwoMinuteEvents,
    required this.lastMinuteEvents,
    required this.scoreChanges,
    required this.homeClosePoints,
    required this.awayClosePoints,
    required this.closeLeadChanges,
    required this.closeTies,
    required this.firstClosePeriodLabel,
    required this.firstCloseClock,
    required this.lastClosePeriodLabel,
    required this.lastCloseClock,
    required this.playByPlayAvailability,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final NbaGameTeam homeTeam;
  final NbaGameTeam awayTeam;
  final List<NbaGamePlayByPlayEvent> lateEvents;
  final List<NbaGamePlayByPlayEvent> closeEvents;
  final List<NbaGamePlayByPlayEvent> lastTwoMinuteEvents;
  final List<NbaGamePlayByPlayEvent> lastMinuteEvents;
  final List<NbaGameClutchScoreChange> scoreChanges;
  final int homeClosePoints;
  final int awayClosePoints;
  final int closeLeadChanges;
  final int closeTies;
  final String firstClosePeriodLabel;
  final String firstCloseClock;
  final String lastClosePeriodLabel;
  final String lastCloseClock;
  final String playByPlayAvailability;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasLateEvents => lateEvents.isNotEmpty;
  bool get hasObservedCloseWindow => closeEvents.isNotEmpty;
  int get closeEventCount => closeEvents.length;
  int get closeScoringChangeCount => scoreChanges.length;
  int get lastTwoMinuteEventCount => lastTwoMinuteEvents.length;
  int get lastMinuteEventCount => lastMinuteEvents.length;
  String get closePointsLabel => '$awayClosePoints–$homeClosePoints';

  String get methodologyLabel =>
      'Q4/OT · ≤5:00 · explicit post-event margin ≤5';
}

class NbaGameClutchScoreChange {
  const NbaGameClutchScoreChange({
    required this.sequence,
    required this.period,
    required this.periodLabel,
    required this.clock,
    required this.side,
    required this.points,
    required this.homeScore,
    required this.awayScore,
    required this.margin,
    required this.player,
    required this.team,
    required this.description,
  });

  final int? sequence;
  final int? period;
  final String periodLabel;
  final String clock;
  final NbaGameClutchScoringSide side;
  final int points;
  final int homeScore;
  final int awayScore;
  final int margin;
  final NbaPbpPlayerIdentity player;
  final NbaPbpTeamIdentity team;
  final String description;

  String get scoreLabel => '$awayScore–$homeScore';
}
