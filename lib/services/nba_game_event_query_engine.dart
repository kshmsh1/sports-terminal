import 'nba_game_play_by_play_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Search/filter projection over one canonical game's play-by-play stream.
///
/// All filters operate only on fields explicitly present in the normalized PBP
/// event. `closeGameOnly` is an observed score-state filter (Q4/OT, <= 5:00,
/// absolute post-event margin <= 5), not a possession or win-probability model.
class NbaGameEventQueryEngine {
  const NbaGameEventQueryEngine();

  NbaGameEventQueryResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
    String query = '',
    NbaPbpEventCategory? category,
    String teamId = '',
    String playerId = '',
    int? period,
    bool scoringOnly = false,
    bool closeGameOnly = false,
    bool substitutionsOnly = false,
    bool ascending = true,
    int limit = 250,
  }) {
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: gameId);
    final normalizedQuery = _normalize(query);
    final normalizedTeam = _normalize(teamId);
    final normalizedPlayer = _normalize(playerId);
    final boundedLimit = limit < 1 ? 1 : limit > 1000 ? 1000 : limit;

    bool matches(NbaGamePlayByPlayEvent event) {
      if (category != null && event.category != category) return false;
      if (period != null && event.period != period) return false;
      if (scoringOnly && !event.isScoringAction) return false;
      if (substitutionsOnly && event.category != NbaPbpEventCategory.substitution) {
        return false;
      }
      if (closeGameOnly && !_isObservedCloseState(event)) return false;
      if (normalizedTeam.isNotEmpty &&
          _normalize(event.team.id) != normalizedTeam &&
          _normalize(event.team.abbreviation) != normalizedTeam) {
        return false;
      }
      if (normalizedPlayer.isNotEmpty && !_containsPlayer(event, normalizedPlayer)) {
        return false;
      }
      if (normalizedQuery.isNotEmpty && !_matchesText(event, normalizedQuery)) {
        return false;
      }
      return true;
    }

    var filtered = pbp.events.where(matches).toList(growable: false);
    if (!ascending) filtered = filtered.reversed.toList(growable: false);
    final returned = filtered.take(boundedLimit).toList(growable: false);

    final categoryCounts = <NbaPbpEventCategory, int>{};
    final periodCounts = <int, int>{};
    final teamCounts = <String, int>{};
    final playerCounts = <String, int>{};
    for (final event in pbp.events) {
      categoryCounts[event.category] = (categoryCounts[event.category] ?? 0) + 1;
      final eventPeriod = event.period;
      if (eventPeriod != null && eventPeriod > 0) {
        periodCounts[eventPeriod] = (periodCounts[eventPeriod] ?? 0) + 1;
      }
      final eventTeam = event.team.id.trim();
      if (eventTeam.isNotEmpty) {
        teamCounts[eventTeam] = (teamCounts[eventTeam] ?? 0) + 1;
      }
      final seenPlayers = <String>{};
      for (final participant in _participants(event)) {
        final participantId = participant.id.trim();
        if (participantId.isEmpty) continue;
        final normalizedId = _normalize(participantId);
        if (!seenPlayers.add(normalizedId)) continue;
        playerCounts[participantId] = (playerCounts[participantId] ?? 0) + 1;
      }
    }

    return NbaGameEventQueryResult(
      gameId: gameId.trim(),
      events: List.unmodifiable(returned),
      totalEvents: pbp.eventCount,
      matchedEvents: filtered.length,
      returnedEvents: returned.length,
      truncated: filtered.length > returned.length,
      query: query.trim(),
      category: category,
      teamId: teamId.trim(),
      playerId: playerId.trim(),
      period: period,
      scoringOnly: scoringOnly,
      closeGameOnly: closeGameOnly,
      substitutionsOnly: substitutionsOnly,
      ascending: ascending,
      limit: boundedLimit,
      categoryCounts: Map.unmodifiable(categoryCounts),
      periodCounts: Map.unmodifiable(periodCounts),
      teamCounts: Map.unmodifiable(teamCounts),
      playerCounts: Map.unmodifiable(playerCounts),
      availabilityLabel: pbp.availabilityLabel,
      datasetStatus: pbp.datasetStatus,
      validationStatus: pbp.validationStatus,
      historicalContext: pbp.historicalContext,
      usedFallbackDataset: pbp.usedFallbackDataset,
    );
  }
}

class NbaGameEventQueryResult {
  const NbaGameEventQueryResult({
    required this.gameId,
    required this.events,
    required this.totalEvents,
    required this.matchedEvents,
    required this.returnedEvents,
    required this.truncated,
    required this.query,
    required this.category,
    required this.teamId,
    required this.playerId,
    required this.period,
    required this.scoringOnly,
    required this.closeGameOnly,
    required this.substitutionsOnly,
    required this.ascending,
    required this.limit,
    required this.categoryCounts,
    required this.periodCounts,
    required this.teamCounts,
    required this.playerCounts,
    required this.availabilityLabel,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final List<NbaGamePlayByPlayEvent> events;
  final int totalEvents;
  final int matchedEvents;
  final int returnedEvents;
  final bool truncated;
  final String query;
  final NbaPbpEventCategory? category;
  final String teamId;
  final String playerId;
  final int? period;
  final bool scoringOnly;
  final bool closeGameOnly;
  final bool substitutionsOnly;
  final bool ascending;
  final int limit;
  final Map<NbaPbpEventCategory, int> categoryCounts;
  final Map<int, int> periodCounts;
  final Map<String, int> teamCounts;
  final Map<String, int> playerCounts;
  final String availabilityLabel;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasEvents => events.isNotEmpty;
  bool get hasActiveFilters =>
      query.isNotEmpty ||
      category != null ||
      teamId.isNotEmpty ||
      playerId.isNotEmpty ||
      period != null ||
      scoringOnly ||
      closeGameOnly ||
      substitutionsOnly;

  String get filterSummary {
    final parts = <String>[];
    if (query.isNotEmpty) parts.add('query="$query"');
    if (category != null) parts.add('category=${category!.name}');
    if (teamId.isNotEmpty) parts.add('team=$teamId');
    if (playerId.isNotEmpty) parts.add('player=$playerId');
    if (period != null) parts.add('period=$period');
    if (scoringOnly) parts.add('scoring');
    if (closeGameOnly) parts.add('observed-close');
    if (substitutionsOnly) parts.add('substitutions');
    return parts.isEmpty ? 'No filters' : parts.join(' · ');
  }
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

bool _containsPlayer(NbaGamePlayByPlayEvent event, String normalizedPlayer) {
  return _participants(event).any(
    (participant) =>
        _normalize(participant.id) == normalizedPlayer ||
        _normalize(participant.name) == normalizedPlayer,
  );
}

bool _matchesText(NbaGamePlayByPlayEvent event, String query) {
  final haystack = _normalize([
    event.description,
    event.actionType,
    event.subType,
    event.categoryLabel,
    event.typeLabel,
    event.team.id,
    event.team.name,
    event.team.abbreviation,
    event.player.id,
    event.player.name,
    event.secondaryPlayer.id,
    event.secondaryPlayer.name,
    event.tertiaryPlayer.id,
    event.tertiaryPlayer.name,
    event.substitutionOut.id,
    event.substitutionOut.name,
    event.substitutionIn.id,
    event.substitutionIn.name,
    event.sourceId,
  ].join(' '));
  return haystack.contains(query);
}

List<NbaPbpPlayerIdentity> _participants(NbaGamePlayByPlayEvent event) => [
      event.player,
      event.secondaryPlayer,
      event.tertiaryPlayer,
      event.substitutionOut,
      event.substitutionIn,
    ];

String _normalize(String value) => value.trim().toUpperCase();
