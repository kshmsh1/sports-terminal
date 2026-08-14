import 'nba_game_intelligence_engine.dart';
import 'nba_game_player_scoring_engine.dart';
import 'nba_game_play_by_play_engine.dart';
import 'nba_game_substitution_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Builds explicit team-side event profiles for one canonical game.
///
/// Team event counts use only events with a canonical event team. Observed score
/// deltas come from explicit score states and are kept separate from points that
/// can be attributed to a specific player. This makes event-feed coverage gaps
/// visible instead of silently converting them into player credit.
class NbaGameTeamEventProfileEngine {
  const NbaGameTeamEventProfileEngine();

  NbaGameTeamEventProfileResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
  }) {
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: gameId);
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: gameId);
    final scoring = const NbaGamePlayerScoringEngine().build(seed, gameId: gameId);
    final substitutions = const NbaGameSubstitutionEngine().build(seed, gameId: gameId);

    final builders = <String, _TeamProfileBuilder>{};
    void register(NbaGameTeam team, NbaObservedScoringSide side) {
      final key = _normalize(team.id);
      if (key.isEmpty) return;
      builders[key] = _TeamProfileBuilder(team: team, side: side);
    }

    register(game.awayTeam, NbaObservedScoringSide.away);
    register(game.homeTeam, NbaObservedScoringSide.home);

    _TeamProfileBuilder? builderFor(String teamId) => builders[_normalize(teamId)];

    for (final event in pbp.events) {
      final builder = builderFor(event.team.id);
      if (builder == null) continue;
      builder.explicitTeamEvents += 1;
      builder.categoryCounts[event.category] =
          (builder.categoryCounts[event.category] ?? 0) + 1;
      if (event.period != null && event.period! > 0) {
        builder.periodEventCounts[event.period!] =
            (builder.periodEventCounts[event.period!] ?? 0) + 1;
      }
      if (_isObservedCloseState(event)) builder.closeWindowEvents += 1;
      if (!event.player.isEmpty) builder.primaryPlayerEvents += 1;
      builder.lastTeamEvent = event;
    }

    for (final score in scoring.creditedScores) {
      final builder = builderFor(score.teamId);
      if (builder == null) continue;
      builder.creditedPlayerPoints += score.points;
      builder.creditedScoringEvents += 1;
      if (score.closeWindow) {
        builder.creditedClosePoints += score.points;
        builder.creditedCloseScoringEvents += 1;
      }
    }

    for (final builder in builders.values) {
      builder.observedScoreDeltaPoints = switch (builder.side) {
        NbaObservedScoringSide.home => scoring.observedHomePoints,
        NbaObservedScoringSide.away => scoring.observedAwayPoints,
        NbaObservedScoringSide.unknown => 0,
      };
      builder.confirmedSubstitutions = substitutions.confirmedForTeam(builder.team.id);
    }

    final profiles = builders.values.map((builder) => builder.build()).toList()
      ..sort((left, right) {
        final side = left.side.index.compareTo(right.side.index);
        if (side != 0) return side;
        return left.team.abbreviation.compareTo(right.team.abbreviation);
      });

    final unattributedEventCount = pbp.events.where((event) => event.team.id.trim().isEmpty).length;

    return NbaGameTeamEventProfileResult(
      gameId: game.gameId,
      profiles: List.unmodifiable(profiles),
      eventCount: pbp.eventCount,
      unattributedEventCount: unattributedEventCount,
      uncreditedObservedPoints: scoring.uncreditedPoints,
      incompleteSubstitutionRows: substitutions.incompleteSubstitutionRows,
      availabilityLabel: pbp.availabilityLabel,
      datasetStatus: pbp.datasetStatus,
      validationStatus: pbp.validationStatus,
      historicalContext: pbp.historicalContext,
      usedFallbackDataset: pbp.usedFallbackDataset,
    );
  }
}

class NbaGameTeamEventProfileResult {
  const NbaGameTeamEventProfileResult({
    required this.gameId,
    required this.profiles,
    required this.eventCount,
    required this.unattributedEventCount,
    required this.uncreditedObservedPoints,
    required this.incompleteSubstitutionRows,
    required this.availabilityLabel,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final List<NbaGameTeamEventProfile> profiles;
  final int eventCount;
  final int unattributedEventCount;
  final int uncreditedObservedPoints;
  final int incompleteSubstitutionRows;
  final String availabilityLabel;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasProfiles => profiles.isNotEmpty;

  NbaGameTeamEventProfile? byTeamId(String teamId) {
    final key = _normalize(teamId);
    for (final profile in profiles) {
      if (_normalize(profile.team.id) == key) return profile;
    }
    return null;
  }
}

class NbaGameTeamEventProfile {
  const NbaGameTeamEventProfile({
    required this.team,
    required this.side,
    required this.explicitTeamEvents,
    required this.primaryPlayerEvents,
    required this.closeWindowEvents,
    required this.observedScoreDeltaPoints,
    required this.creditedPlayerPoints,
    required this.creditedScoringEvents,
    required this.creditedClosePoints,
    required this.creditedCloseScoringEvents,
    required this.confirmedSubstitutions,
    required this.categoryCounts,
    required this.periodEventCounts,
    required this.lastTeamEvent,
  });

  final NbaGameTeam team;
  final NbaObservedScoringSide side;
  final int explicitTeamEvents;
  final int primaryPlayerEvents;
  final int closeWindowEvents;
  final int observedScoreDeltaPoints;
  final int creditedPlayerPoints;
  final int creditedScoringEvents;
  final int creditedClosePoints;
  final int creditedCloseScoringEvents;
  final int confirmedSubstitutions;
  final Map<NbaPbpEventCategory, int> categoryCounts;
  final Map<int, int> periodEventCounts;
  final NbaGamePlayByPlayEvent? lastTeamEvent;

  int get uncreditedTeamObservedPoints =>
      observedScoreDeltaPoints > creditedPlayerPoints
          ? observedScoreDeltaPoints - creditedPlayerPoints
          : 0;
  int categoryCount(NbaPbpEventCategory category) => categoryCounts[category] ?? 0;
  int periodCount(int period) => periodEventCounts[period] ?? 0;
}

class _TeamProfileBuilder {
  _TeamProfileBuilder({required this.team, required this.side});

  final NbaGameTeam team;
  final NbaObservedScoringSide side;
  int explicitTeamEvents = 0;
  int primaryPlayerEvents = 0;
  int closeWindowEvents = 0;
  int observedScoreDeltaPoints = 0;
  int creditedPlayerPoints = 0;
  int creditedScoringEvents = 0;
  int creditedClosePoints = 0;
  int creditedCloseScoringEvents = 0;
  int confirmedSubstitutions = 0;
  final Map<NbaPbpEventCategory, int> categoryCounts = {};
  final Map<int, int> periodEventCounts = {};
  NbaGamePlayByPlayEvent? lastTeamEvent;

  NbaGameTeamEventProfile build() => NbaGameTeamEventProfile(
        team: team,
        side: side,
        explicitTeamEvents: explicitTeamEvents,
        primaryPlayerEvents: primaryPlayerEvents,
        closeWindowEvents: closeWindowEvents,
        observedScoreDeltaPoints: observedScoreDeltaPoints,
        creditedPlayerPoints: creditedPlayerPoints,
        creditedScoringEvents: creditedScoringEvents,
        creditedClosePoints: creditedClosePoints,
        creditedCloseScoringEvents: creditedCloseScoringEvents,
        confirmedSubstitutions: confirmedSubstitutions,
        categoryCounts: Map.unmodifiable(categoryCounts),
        periodEventCounts: Map.unmodifiable(periodEventCounts),
        lastTeamEvent: lastTeamEvent,
      );
}

bool _isObservedCloseState(NbaGamePlayByPlayEvent event) {
  final period = event.period;
  final remaining = event.clockSecondsRemaining;
  final margin = event.margin;
  return period != null &&
      period >= 4 &&
      remaining != null &&
      remaining <= 300 &&
      margin != null &&
      margin.abs() <= 5;
}

String _normalize(String value) => value.trim().toUpperCase();
