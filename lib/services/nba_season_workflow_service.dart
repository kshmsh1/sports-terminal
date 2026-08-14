import '../models/route_payload.dart';
import 'nba_entity_watchlist_store.dart';
import 'nba_research_context_store.dart';
import 'nba_season_intelligence_engine.dart';
import 'nba_terminal_seed_repository.dart';
import 'sports_object_router.dart';

/// Coordinates shared workflow actions for one canonical NBA Season.
///
/// The season projection remains owned by [NbaSeasonIntelligenceEngine]. This
/// service only packages it for shared RoutePayload state, activates the exact
/// research scope, and creates a canonical persistent watchlist identity.
class NbaSeasonWorkflowService {
  const NbaSeasonWorkflowService({
    NbaResearchContextStore contextStore = const NbaResearchContextStore(),
    NbaEntityWatchlistStore watchlistStore = const NbaEntityWatchlistStore(),
  })  : _contextStore = contextStore,
        _watchlistStore = watchlistStore;

  final NbaResearchContextStore _contextStore;
  final NbaEntityWatchlistStore _watchlistStore;

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

  Future<NbaResearchContext> activateResearch(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'All',
    String league = 'NBA',
  }) {
    final normalizedSeason = seasonId.trim();
    if (normalizedSeason.isEmpty) {
      throw ArgumentError.value(seasonId, 'seasonId', 'Season is required.');
    }
    if (seed.isHistorical) {
      return _contextStore.activateHistorical(
        season: normalizedSeason,
        league: league,
        seasonType: _normalizedSeasonType(seasonType),
      );
    }
    return _contextStore.selectCurrent(clearEntity: true);
  }

  NbaEntityWatchItem watchItem(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'All',
    String league = 'NBA',
  }) {
    final normalizedSeason = seasonId.trim();
    if (normalizedSeason.isEmpty) {
      throw ArgumentError.value(seasonId, 'seasonId', 'Season is required.');
    }
    final normalizedLeague = league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase();
    final normalizedType = _normalizedSeasonType(seasonType);
    return NbaEntityWatchItem(
      kind: 'season',
      key: normalizedSeason,
      label: '$normalizedSeason $normalizedLeague Season',
      subtitle: seed.isHistorical
          ? 'Historical canonical season · ${_seasonTypeLabel(normalizedType)}'
          : 'Certified current release · ${_seasonTypeLabel(normalizedType)}',
      season: normalizedSeason,
      league: normalizedLeague,
      seasonType: normalizedType,
    );
  }

  Future<bool> isWatched(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'All',
    String league = 'NBA',
  }) =>
      _watchlistStore.contains(
        watchItem(
          seed,
          seasonId: seasonId,
          seasonType: seasonType,
          league: league,
        ).signature,
      );

  Future<bool> toggleWatch(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'All',
    String league = 'NBA',
  }) async {
    final item = watchItem(
      seed,
      seasonId: seasonId,
      seasonType: seasonType,
      league: league,
    );
    final next = await _watchlistStore.toggle(item);
    return next.any((candidate) => candidate.signature == item.signature);
  }

  String _normalizedSeasonType(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    if (normalized.contains('playoff') || normalized.contains('postseason')) {
      return 'playoffs';
    }
    if (normalized == 'all' || normalized.contains('combined')) return 'combined';
    if (normalized.contains('preseason')) return 'preseason';
    if (normalized.contains('all_star') || normalized.contains('all star')) {
      return 'all_star';
    }
    return 'regular';
  }

  String _seasonTypeLabel(String value) => switch (value) {
        'playoffs' => 'Playoffs',
        'combined' => 'Regular + Playoffs',
        'preseason' => 'Preseason',
        'all_star' => 'All-Star',
        _ => 'Regular Season',
      };
}
