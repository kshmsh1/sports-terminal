import 'nba_game_intelligence_engine.dart';
import 'nba_game_play_by_play_engine.dart';
import 'nba_terminal_seed_repository.dart';

export 'nba_game_play_by_play_engine.dart'
    show NbaPbpPlayerIdentity, NbaPbpTeamIdentity;

/// Extracts confirmed substitution swaps from canonical PBP events.
/// This engine intentionally does not reconstruct lineups or minutes between
/// swaps because starters and complete substitution coverage are not guaranteed.
class NbaGameSubstitutionEngine {
  const NbaGameSubstitutionEngine();

  NbaGameSubstitutionResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
  }) {
    final game = const NbaGameIntelligenceEngine().build(
      seed: seed,
      gameId: gameId,
    );
    final pbp = const NbaGamePlayByPlayEngine().build(seed, gameId: gameId);

    final swaps = <NbaGameSubstitutionSwap>[];
    var substitutionRows = 0;
    var incompleteRows = 0;

    for (final event in pbp.events) {
      if (event.category != NbaPbpEventCategory.substitution) continue;
      substitutionRows += 1;
      if (!event.hasExplicitSubstitution) {
        incompleteRows += 1;
        continue;
      }
      swaps.add(
        NbaGameSubstitutionSwap(
          sequence: event.sequence,
          period: event.period,
          periodLabel: event.periodLabel,
          clock: event.clock,
          elapsedGameSeconds: event.elapsedGameSeconds,
          team: event.team,
          playerOut: event.substitutionOut,
          playerIn: event.substitutionIn,
          description: event.description,
          sourceId: event.sourceId,
        ),
      );
    }

    final teamCounts = <String, int>{};
    for (final swap in swaps) {
      final key = swap.team.id.trim();
      if (key.isEmpty) continue;
      teamCounts[key] = (teamCounts[key] ?? 0) + 1;
    }

    return NbaGameSubstitutionResult(
      gameId: game.gameId,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      swaps: List.unmodifiable(swaps),
      substitutionRows: substitutionRows,
      incompleteSubstitutionRows: incompleteRows,
      confirmedByTeam: Map.unmodifiable(teamCounts),
      playByPlayAvailability: pbp.availabilityLabel,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }
}

class NbaGameSubstitutionResult {
  const NbaGameSubstitutionResult({
    required this.gameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.swaps,
    required this.substitutionRows,
    required this.incompleteSubstitutionRows,
    required this.confirmedByTeam,
    required this.playByPlayAvailability,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final NbaGameTeam homeTeam;
  final NbaGameTeam awayTeam;
  final List<NbaGameSubstitutionSwap> swaps;
  final int substitutionRows;
  final int incompleteSubstitutionRows;
  final Map<String, int> confirmedByTeam;
  final String playByPlayAvailability;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasConfirmedSwaps => swaps.isNotEmpty;
  bool get hasIncompleteRows => incompleteSubstitutionRows > 0;
  int get confirmedSwapCount => swaps.length;
  int confirmedForTeam(String teamId) {
    final target = teamId.trim().toUpperCase();
    for (final entry in confirmedByTeam.entries) {
      if (entry.key.trim().toUpperCase() == target) return entry.value;
    }
    return 0;
  }

  String get coverageLabel {
    if (substitutionRows == 0) return 'NO SUBSTITUTION ROWS';
    if (incompleteSubstitutionRows == 0) return 'CONFIRMED SWAPS';
    if (swaps.isEmpty) return 'SUBSTITUTION PARTICIPANTS INCOMPLETE';
    return 'PARTIAL SWAP COVERAGE';
  }
}

class NbaGameSubstitutionSwap {
  const NbaGameSubstitutionSwap({
    required this.sequence,
    required this.period,
    required this.periodLabel,
    required this.clock,
    required this.elapsedGameSeconds,
    required this.team,
    required this.playerOut,
    required this.playerIn,
    required this.description,
    required this.sourceId,
  });

  final int? sequence;
  final int? period;
  final String periodLabel;
  final String clock;
  final double? elapsedGameSeconds;
  final NbaPbpTeamIdentity team;
  final NbaPbpPlayerIdentity playerOut;
  final NbaPbpPlayerIdentity playerIn;
  final String description;
  final String sourceId;

  String get timeLabel => '${periodLabel == '—' ? '' : periodLabel} $clock'.trim();
  String get swapLabel => '${playerIn.label} IN · ${playerOut.label} OUT';
}
