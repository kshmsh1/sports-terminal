import 'nba_game_player_scoring_engine.dart';
import 'nba_game_play_by_play_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Builds evidence-bounded player event profiles for one canonical game.
///
/// Profiles describe observed PBP participation, primary event categories,
/// attributable scoring, close-window scoring, and confirmed substitution
/// entries/exits. Secondary/tertiary appearances are not relabeled as assists,
/// blocks, steals, or other roles unless a future source contract exposes those
/// roles explicitly.
class NbaGamePlayerEventProfileEngine {
  const NbaGamePlayerEventProfileEngine();

  NbaGamePlayerEventProfileResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
  }) {
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: gameId);
    final scoring = const NbaGamePlayerScoringEngine().build(seed, gameId: gameId);
    final builders = <String, _PlayerProfileBuilder>{};

    NbaPbpPlayerIdentity canonicalIdentity(NbaPbpPlayerIdentity identity) {
      if (identity.isEmpty) return identity;
      final key = _normalize(identity.id.isNotEmpty ? identity.id : identity.name);
      if (key.isEmpty) return identity;
      for (final raw in seed.players) {
        final id = _text(raw, const ['player_id', 'playerId', 'person_id', 'id']);
        final name = _text(
          raw,
          const ['player_name', 'playerName', 'display_name', 'full_name', 'name'],
        );
        if (_normalize(id) == key || _normalize(name) == key) {
          return NbaPbpPlayerIdentity(
            id: id.isEmpty ? identity.id : id,
            name: name.isEmpty ? identity.name : name,
          );
        }
      }
      return identity;
    }

    _PlayerProfileBuilder builderFor(NbaPbpPlayerIdentity identity) {
      final canonical = canonicalIdentity(identity);
      final key = _normalize(canonical.id.isNotEmpty ? canonical.id : canonical.name);
      return builders.putIfAbsent(key, () => _PlayerProfileBuilder(player: canonical));
    }

    for (final event in pbp.events) {
      final unique = <String, NbaPbpPlayerIdentity>{};
      for (final participant in [
        event.player,
        event.secondaryPlayer,
        event.tertiaryPlayer,
        event.substitutionOut,
        event.substitutionIn,
      ]) {
        if (participant.isEmpty) continue;
        final canonical = canonicalIdentity(participant);
        final key = _normalize(canonical.id.isNotEmpty ? canonical.id : canonical.name);
        if (key.isNotEmpty) unique[key] = canonical;
      }

      for (final participant in unique.values) {
        final builder = builderFor(participant);
        builder.participationEvents += 1;
        if (_isObservedCloseState(event)) builder.closeWindowParticipationEvents += 1;
        if (event.team.id.trim().isNotEmpty) builder.teamIds.add(event.team.id.trim());
      }

      if (!event.player.isEmpty) {
        final primary = builderFor(event.player);
        primary.primaryEvents += 1;
        primary.categoryCounts[event.category] =
            (primary.categoryCounts[event.category] ?? 0) + 1;
        if (event.isScoringAction) primary.explicitScoringActions += 1;
        primary.lastPrimaryEvent = event;
      }

      if (!event.secondaryPlayer.isEmpty) {
        builderFor(event.secondaryPlayer).secondaryAppearances += 1;
      }
      if (!event.tertiaryPlayer.isEmpty) {
        builderFor(event.tertiaryPlayer).tertiaryAppearances += 1;
      }
      if (event.hasExplicitSubstitution) {
        if (!event.substitutionOut.isEmpty) {
          final outgoing = builderFor(event.substitutionOut);
          outgoing.confirmedSubstitutionOuts += 1;
          if (event.team.id.trim().isNotEmpty) outgoing.teamIds.add(event.team.id.trim());
        }
        if (!event.substitutionIn.isEmpty) {
          final incoming = builderFor(event.substitutionIn);
          incoming.confirmedSubstitutionIns += 1;
          if (event.team.id.trim().isNotEmpty) incoming.teamIds.add(event.team.id.trim());
        }
      }
    }

    for (final summary in scoring.players) {
      if (summary.player.isEmpty) continue;
      final builder = builderFor(summary.player);
      builder.observedPoints = summary.observedPoints;
      builder.observedScoringEvents = summary.scoringEvents;
      builder.closeWindowPoints = summary.closeWindowPoints;
      builder.closeWindowScoringEvents = summary.closeWindowScoringEvents;
      if (summary.teamId.trim().isNotEmpty) builder.teamIds.add(summary.teamId.trim());
    }

    final profiles = builders.values
        .where((builder) => builder.player.id.isNotEmpty || builder.player.name.isNotEmpty)
        .map((builder) => builder.build())
        .toList()
      ..sort((left, right) {
        final points = right.observedPoints.compareTo(left.observedPoints);
        if (points != 0) return points;
        final participation = right.participationEvents.compareTo(left.participationEvents);
        if (participation != 0) return participation;
        return left.player.label.compareTo(right.player.label);
      });

    return NbaGamePlayerEventProfileResult(
      gameId: gameId.trim(),
      profiles: List.unmodifiable(profiles),
      eventCount: pbp.eventCount,
      observedAttributedPoints: scoring.creditedPoints,
      uncreditedObservedPoints: scoring.uncreditedPoints,
      availabilityLabel: pbp.availabilityLabel,
      datasetStatus: pbp.datasetStatus,
      validationStatus: pbp.validationStatus,
      historicalContext: pbp.historicalContext,
      usedFallbackDataset: pbp.usedFallbackDataset,
    );
  }
}

class NbaGamePlayerEventProfileResult {
  const NbaGamePlayerEventProfileResult({
    required this.gameId,
    required this.profiles,
    required this.eventCount,
    required this.observedAttributedPoints,
    required this.uncreditedObservedPoints,
    required this.availabilityLabel,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final List<NbaGamePlayerEventProfile> profiles;
  final int eventCount;
  final int observedAttributedPoints;
  final int uncreditedObservedPoints;
  final String availabilityLabel;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasProfiles => profiles.isNotEmpty;

  NbaGamePlayerEventProfile? byPlayerId(String playerId) {
    final key = _normalize(playerId);
    for (final profile in profiles) {
      if (_normalize(profile.player.id) == key) return profile;
    }
    return null;
  }
}

class NbaGamePlayerEventProfile {
  const NbaGamePlayerEventProfile({
    required this.player,
    required this.teamIds,
    required this.participationEvents,
    required this.primaryEvents,
    required this.secondaryAppearances,
    required this.tertiaryAppearances,
    required this.closeWindowParticipationEvents,
    required this.explicitScoringActions,
    required this.observedPoints,
    required this.observedScoringEvents,
    required this.closeWindowPoints,
    required this.closeWindowScoringEvents,
    required this.confirmedSubstitutionIns,
    required this.confirmedSubstitutionOuts,
    required this.categoryCounts,
    required this.lastPrimaryEvent,
  });

  final NbaPbpPlayerIdentity player;
  final List<String> teamIds;
  final int participationEvents;
  final int primaryEvents;
  final int secondaryAppearances;
  final int tertiaryAppearances;
  final int closeWindowParticipationEvents;
  final int explicitScoringActions;
  final int observedPoints;
  final int observedScoringEvents;
  final int closeWindowPoints;
  final int closeWindowScoringEvents;
  final int confirmedSubstitutionIns;
  final int confirmedSubstitutionOuts;
  final Map<NbaPbpEventCategory, int> categoryCounts;
  final NbaGamePlayByPlayEvent? lastPrimaryEvent;

  int categoryCount(NbaPbpEventCategory category) => categoryCounts[category] ?? 0;
  String get teamLabel => teamIds.isEmpty ? '—' : teamIds.join(', ');
  String get substitutionLabel => '$confirmedSubstitutionIns in / $confirmedSubstitutionOuts out';
}

class _PlayerProfileBuilder {
  _PlayerProfileBuilder({required this.player});

  final NbaPbpPlayerIdentity player;
  final Set<String> teamIds = {};
  int participationEvents = 0;
  int primaryEvents = 0;
  int secondaryAppearances = 0;
  int tertiaryAppearances = 0;
  int closeWindowParticipationEvents = 0;
  int explicitScoringActions = 0;
  int observedPoints = 0;
  int observedScoringEvents = 0;
  int closeWindowPoints = 0;
  int closeWindowScoringEvents = 0;
  int confirmedSubstitutionIns = 0;
  int confirmedSubstitutionOuts = 0;
  final Map<NbaPbpEventCategory, int> categoryCounts = {};
  NbaGamePlayByPlayEvent? lastPrimaryEvent;

  NbaGamePlayerEventProfile build() => NbaGamePlayerEventProfile(
        player: player,
        teamIds: List.unmodifiable(teamIds.toList()..sort()),
        participationEvents: participationEvents,
        primaryEvents: primaryEvents,
        secondaryAppearances: secondaryAppearances,
        tertiaryAppearances: tertiaryAppearances,
        closeWindowParticipationEvents: closeWindowParticipationEvents,
        explicitScoringActions: explicitScoringActions,
        observedPoints: observedPoints,
        observedScoringEvents: observedScoringEvents,
        closeWindowPoints: closeWindowPoints,
        closeWindowScoringEvents: closeWindowScoringEvents,
        confirmedSubstitutionIns: confirmedSubstitutionIns,
        confirmedSubstitutionOuts: confirmedSubstitutionOuts,
        categoryCounts: Map.unmodifiable(categoryCounts),
        lastPrimaryEvent: lastPrimaryEvent,
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

String _text(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value == null || value is Map || value is Iterable) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != '—' && text.toLowerCase() != 'null') return text;
  }
  return '';
}
