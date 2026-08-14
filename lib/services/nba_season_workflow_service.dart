import '../models/route_payload.dart';
import 'nba_season_intelligence_engine.dart';
import 'nba_terminal_seed_repository.dart';
import 'sports_object_router.dart';

/// Packages one canonical Season into the shared RoutePayload contract.
///
/// The payload contains scored-game-derived team standings plus season coverage
/// metadata. It does not inject standings from another source or backfill
/// unavailable team rows merely to make the package complete.
class NbaSeasonWorkflowService {
  const NbaSeasonWorkflowService();

  RoutePayload package(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'All',
    String targetRoute = 'Open',
  }) {
    final season = const NbaSeasonIntelligenceEngine().build(
      seed,
      seasonId: seasonId,
      seasonType: seasonType,
    );
    final rows = [
      for (var index = 0; index < season.standings.length; index++)
        {
          'season_id': season.seasonId,
          'season_type': season.seasonType,
          'rank': index + 1,
          'team_id': season.standings[index].teamId,
          'team': season.standings[index].teamName,
          'abbreviation': season.standings[index].abbreviation,
          'games': season.standings[index].games,
          'wins': season.standings[index].wins,
          'losses': season.standings[index].losses,
          'ties': season.standings[index].ties,
          'win_pct': season.standings[index].winPct,
          'points_for_per_game': season.standings[index].averagePointsFor,
          'points_against_per_game': season.standings[index].averagePointsAgainst,
          'average_differential': season.standings[index].averageDifferential,
        },
    ];
    final readiness = !season.hasGames
        ? 'Partial'
        : rows.isEmpty
            ? 'Partial'
            : 'Ready';
    final sourceSnapshot = seed.assetPath.trim().isEmpty
        ? seed.datasetStatus
        : seed.assetPath;

    return const SportsObjectRouter().packageRows(
      datasetId: 'nba_season_${season.seasonId}',
      packageId: season.seasonId,
      displayLabel: '${season.seasonId} NBA Season · ${season.seasonType}',
      sourceObjectType: 'NBA Season',
      rows: rows,
      targetRoute: targetRoute,
      sourceSnapshot: sourceSnapshot,
      readinessState: readiness,
      filterSummary: 'season=${season.seasonId}; season_type=${season.seasonType}',
      rowKey: 'team_id',
      preferredColumns: const [
        'season_id',
        'season_type',
        'rank',
        'team_id',
        'team',
        'abbreviation',
        'games',
        'wins',
        'losses',
        'ties',
        'win_pct',
        'points_for_per_game',
        'points_against_per_game',
        'average_differential',
      ],
      metadata: {
        'seasonId': season.seasonId,
        'seasonType': season.seasonType,
        'gameCount': season.gameCount,
        'completedGames': season.completedGames,
        'scheduledGames': season.scheduledGames,
        'regularSeasonGames': season.regularSeasonGames,
        'playoffGames': season.playoffGames,
        'teamCount': season.teamCount,
        'dateRange': season.dateRangeLabel,
        'historicalContext': season.historicalContext,
        'datasetStatus': season.datasetStatus,
        'validationStatus': season.validationStatus,
        'usedFallbackDataset': season.usedFallbackDataset,
      },
    );
  }
}
