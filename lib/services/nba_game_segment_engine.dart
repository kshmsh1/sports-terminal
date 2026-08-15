import 'nba_game_intelligence_engine.dart';
import 'nba_game_play_by_play_engine.dart';
import 'nba_terminal_seed_repository.dart';

class NbaGameSegmentEngine {
  const NbaGameSegmentEngine();

  NbaGameSegmentResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
  }) {
    final game = const NbaGameIntelligenceEngine().build(
      seed: seed,
      gameId: gameId,
    );
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: gameId);
    final contexts = _scoreContexts(pbp.events);
    final segments = <NbaGameSegment>[];

    final periods = <int>{
      for (final event in pbp.events)
        if (event.period != null && event.period! > 0) event.period!,
    }.toList()
      ..sort();

    for (final period in periods) {
      segments.add(
        _summarize(
          game,
          contexts.where((item) => item.event.period == period).toList(growable: false),
          type: NbaGameSegmentType.period,
          key: 'period-$period',
          label: period <= 4 ? 'Q$period' : 'OT${period - 4}',
          boundarySeconds: period <= 4 ? 720 : 300,
        ),
      );
    }

    for (final window in const [300, 120, 60]) {
      final label = window == 300
          ? 'FINAL 5:00'
          : window == 120
              ? 'FINAL 2:00'
              : 'FINAL 1:00';
      final type = window == 300
          ? NbaGameSegmentType.finalFive
          : window == 120
              ? NbaGameSegmentType.finalTwo
              : NbaGameSegmentType.finalOne;
      final selected = contexts.where((item) {
        final period = item.event.period;
        final remaining = item.event.clockSecondsRemaining;
        return period != null &&
            period >= 4 &&
            remaining != null &&
            remaining <= window;
      }).toList(growable: false);
      segments.add(
        _summarize(
          game,
          selected,
          type: type,
          key: 'late-$window',
          label: label,
          boundarySeconds: window.toDouble(),
        ),
      );
    }

    return NbaGameSegmentResult(
      gameId: game.gameId,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      segments: List.unmodifiable(segments),
      playByPlayAvailability: pbp.availabilityLabel,
      eventCount: pbp.eventCount,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }

  NbaGameSegment _summarize(
    NbaGameIntelligenceSnapshot game,
    List<_EventScoreContext> items, {
    required NbaGameSegmentType type,
    required String key,
    required String label,
    required double boundarySeconds,
  }) {
    var homePoints = 0;
    var awayPoints = 0;
    var scoreChanges = 0;
    var scoreStates = 0;
    var leadChanges = 0;
    var ties = 0;
    var lastNonTiedLeader = 0;
    int? previousMargin;

    for (final item in items) {
      final event = item.event;
      if (event.hasScore) {
        scoreStates += 1;
        final margin = event.margin!;
        if (margin == 0) {
          if (previousMargin != null && previousMargin != 0) ties += 1;
        } else {
          final leader = margin > 0 ? 1 : -1;
          if (lastNonTiedLeader != 0 && leader != lastNonTiedLeader) leadChanges += 1;
          lastNonTiedLeader = leader;
        }
        previousMargin = margin;
      }

      final homeDelta = item.homeDelta;
      final awayDelta = item.awayDelta;
      if (homeDelta == null || awayDelta == null) continue;
      if (homeDelta < 0 || awayDelta < 0 || (homeDelta == 0 && awayDelta == 0)) continue;
      homePoints += homeDelta;
      awayPoints += awayDelta;
      scoreChanges += 1;
    }

    final first = items.isEmpty ? null : items.first;
    final last = items.isEmpty ? null : items.last;
    final firstScore = items.where((item) => item.event.hasScore).firstOrNull;
    final lastScore = items.where((item) => item.event.hasScore).lastOrNull;
    final startsAtBoundary = items.any((item) {
      final remaining = item.event.clockSecondsRemaining;
      if (remaining == null) return false;
      return (remaining - boundarySeconds).abs() < .01 ||
          item.event.category == NbaPbpEventCategory.periodStart;
    });
    final endsAtBoundary = items.any((item) {
      final remaining = item.event.clockSecondsRemaining;
      if (remaining != null && remaining.abs() < .01) return true;
      return item.event.category == NbaPbpEventCategory.periodEnd;
    });

    return NbaGameSegment(
      key: key,
      label: label,
      type: type,
      eventCount: items.length,
      scoreStateCount: scoreStates,
      scoreChangeCount: scoreChanges,
      homeObservedPoints: homePoints,
      awayObservedPoints: awayPoints,
      leadChanges: leadChanges,
      ties: ties,
      firstPeriodLabel: first?.event.periodLabel ?? '',
      firstClock: first?.event.clock ?? '',
      lastPeriodLabel: last?.event.periodLabel ?? '',
      lastClock: last?.event.clock ?? '',
      startHomeScore: firstScore?.preHomeScore ?? firstScore?.event.homeScore,
      startAwayScore: firstScore?.preAwayScore ?? firstScore?.event.awayScore,
      endHomeScore: lastScore?.event.homeScore,
      endAwayScore: lastScore?.event.awayScore,
      startsAtBoundary: startsAtBoundary,
      endsAtBoundary: endsAtBoundary,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
    );
  }

  List<_EventScoreContext> _scoreContexts(List<NbaGamePlayByPlayEvent> events) {
    final output = <_EventScoreContext>[];
    int? previousHome;
    int? previousAway;
    for (final event in events) {
      final preHome = previousHome;
      final preAway = previousAway;
      int? homeDelta;
      int? awayDelta;
      if (event.hasScore && previousHome != null && previousAway != null) {
        homeDelta = event.homeScore! - previousHome;
        awayDelta = event.awayScore! - previousAway;
      }
      output.add(
        _EventScoreContext(
          event: event,
          preHomeScore: preHome,
          preAwayScore: preAway,
          homeDelta: homeDelta,
          awayDelta: awayDelta,
        ),
      );
      if (event.hasScore) {
        previousHome = event.homeScore;
        previousAway = event.awayScore;
      }
    }
    return output;
  }
}

enum NbaGameSegmentType { period, finalFive, finalTwo, finalOne }

class NbaGameSegmentResult {
  const NbaGameSegmentResult({
    required this.gameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.segments,
    required this.playByPlayAvailability,
    required this.eventCount,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final NbaGameTeam homeTeam;
  final NbaGameTeam awayTeam;
  final List<NbaGameSegment> segments;
  final String playByPlayAvailability;
  final int eventCount;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  List<NbaGameSegment> get periodSegments =>
      segments.where((segment) => segment.type == NbaGameSegmentType.period).toList(growable: false);
  List<NbaGameSegment> get lateSegments =>
      segments.where((segment) => segment.type != NbaGameSegmentType.period).toList(growable: false);
}

class NbaGameSegment {
  const NbaGameSegment({
    required this.key,
    required this.label,
    required this.type,
    required this.eventCount,
    required this.scoreStateCount,
    required this.scoreChangeCount,
    required this.homeObservedPoints,
    required this.awayObservedPoints,
    required this.leadChanges,
    required this.ties,
    required this.firstPeriodLabel,
    required this.firstClock,
    required this.lastPeriodLabel,
    required this.lastClock,
    required this.startHomeScore,
    required this.startAwayScore,
    required this.endHomeScore,
    required this.endAwayScore,
    required this.startsAtBoundary,
    required this.endsAtBoundary,
    required this.homeTeam,
    required this.awayTeam,
  });

  final String key;
  final String label;
  final NbaGameSegmentType type;
  final int eventCount;
  final int scoreStateCount;
  final int scoreChangeCount;
  final int homeObservedPoints;
  final int awayObservedPoints;
  final int leadChanges;
  final int ties;
  final String firstPeriodLabel;
  final String firstClock;
  final String lastPeriodLabel;
  final String lastClock;
  final int? startHomeScore;
  final int? startAwayScore;
  final int? endHomeScore;
  final int? endAwayScore;
  final bool startsAtBoundary;
  final bool endsAtBoundary;
  final NbaGameTeam homeTeam;
  final NbaGameTeam awayTeam;

  bool get hasEvents => eventCount > 0;
  bool get hasScoreStates => scoreStateCount > 0;
  bool get boundaryComplete => startsAtBoundary && endsAtBoundary;
  String get observedPointsLabel => '$awayObservedPoints–$homeObservedPoints';
  String get startScoreLabel => startHomeScore == null || startAwayScore == null
      ? '—'
      : '$startAwayScore–$startHomeScore';
  String get endScoreLabel => endHomeScore == null || endAwayScore == null
      ? '—'
      : '$endAwayScore–$endHomeScore';
}

class _EventScoreContext {
  const _EventScoreContext({
    required this.event,
    required this.preHomeScore,
    required this.preAwayScore,
    required this.homeDelta,
    required this.awayDelta,
  });

  final NbaGamePlayByPlayEvent event;
  final int? preHomeScore;
  final int? preAwayScore;
  final int? homeDelta;
  final int? awayDelta;
}

extension _IterableFirstLastOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  T? get lastOrNull {
    T? value;
    var found = false;
    for (final item in this) {
      value = item;
      found = true;
    }
    return found ? value : null;
  }
}
