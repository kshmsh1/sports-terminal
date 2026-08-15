import '../models/route_payload.dart';
import 'nba_entity_watchlist_store.dart';
import 'nba_player_career_context_engine.dart';
import 'nba_player_career_engine.dart';
import 'nba_research_context_store.dart';
import 'sports_object_router.dart';

/// Shared workflow boundary for one canonical historical NBA Player career.
class NbaPlayerCareerWorkflowService {
  const NbaPlayerCareerWorkflowService({
    NbaResearchContextStore contextStore = const NbaResearchContextStore(),
    NbaEntityWatchlistStore watchlistStore = const NbaEntityWatchlistStore(),
  })  : _contextStore = contextStore,
        _watchlistStore = watchlistStore;

  final NbaResearchContextStore _contextStore;
  final NbaEntityWatchlistStore _watchlistStore;

  RoutePayload package({
    required NbaPlayerCareerSnapshot career,
    required NbaPlayerCareerContext context,
    String targetRoute = 'Open',
    String league = 'NBA',
    String seasonType = 'regular',
  }) {
    final rows = <Map<String, dynamic>>[
      for (final season in career.seasons)
        {
          'row_type': 'career_season',
          'player_key': career.playerKey,
          'player': career.playerName,
          'season_id': season.seasonId,
          'season_type': season.seasonType,
          'league': season.leagueId,
          'team_key': season.teamKey,
          'team': season.teamName,
          'franchise_key': season.franchiseKey,
          'franchise': season.franchiseName,
          'games': season.games,
          'games_started': season.gamesStarted,
          'minutes': season.minutes,
          'points': season.points,
          'rebounds': season.rebounds,
          'assists': season.assists,
          'steals': season.steals,
          'blocks': season.blocks,
          'turnovers': season.turnovers,
          'ppg': season.pointsPerGame,
          'rpg': season.reboundsPerGame,
          'apg': season.assistsPerGame,
          'ts_pct': season.trueShootingPct,
          'per': season.playerEfficiencyRating,
          'win_shares': season.winShares,
          'bpm': season.boxPlusMinus,
          'vorp': season.valueOverReplacement,
          'synthetic_aggregate': season.syntheticAggregate,
          'source': season.source,
        },
      for (final tenure in career.tenures)
        {
          'row_type': 'team_tenure',
          'player_key': career.playerKey,
          'player': career.playerName,
          'team_key': tenure.teamKey,
          'team': tenure.teamName,
          'franchise_key': tenure.franchiseKey,
          'franchise': tenure.franchiseName,
          'first_season': tenure.firstSeason,
          'last_season': tenure.lastSeason,
          'seasons': tenure.seasons,
          'games': tenure.games,
          'points': tenure.points,
        },
      for (final award in context.awards)
        {
          'row_type': 'award',
          'player_key': career.playerKey,
          'player': career.playerName,
          'season_id': award.seasonId,
          'award': award.award,
          'result': award.result,
          'rank': award.rank,
          'votes': award.votes,
          'voting_points': award.points,
          'source': award.source,
        },
      for (final selection in context.allStarSelections)
        {
          'row_type': 'all_star',
          'player_key': career.playerKey,
          'player': career.playerName,
          'season_id': selection.seasonId,
          'selection': selection.selection,
          'conference': selection.conference,
          'starter': selection.starter,
          'source': selection.source,
        },
      for (final draft in context.draftRecords)
        {
          'row_type': 'draft',
          'player_key': career.playerKey,
          'player': career.playerName,
          'draft_year': draft.draftYear,
          'round': draft.round,
          'pick': draft.pick,
          'team_key': draft.teamKey,
          'team': draft.teamLabel,
          'source': draft.source,
        },
      for (final game in context.recentGames)
        {
          'row_type': 'recent_game',
          'player_key': career.playerKey,
          'player': career.playerName,
          'game_key': game.gameKey,
          'season_id': game.seasonId,
          'game_date': game.gameDate,
          'team_key': game.teamKey,
          'team': game.teamName,
          'opponent_team_key': game.opponentTeamKey,
          'opponent': game.opponentName,
          'points': game.points,
          'rebounds': game.rebounds,
          'assists': game.assists,
          'minutes': game.minutes,
          'home_score': game.homeScore,
          'away_score': game.awayScore,
          'source': game.source,
        },
    ];
    final readiness = !career.available || rows.isEmpty ? 'Partial' : 'Ready';
    return const SportsObjectRouter().packageRows(
      datasetId: 'nba_player_career_${career.playerKey}',
      packageId: career.playerKey,
      displayLabel: '${career.playerName} · Career',
      sourceObjectType: 'NBA Player Career',
      rows: rows,
      targetRoute: targetRoute,
      sourceSnapshot: 'historical-player-dossier',
      readinessState: readiness,
      filterSummary:
          'player=${career.playerKey}; league=${league.toUpperCase()}; season_type=$seasonType',
      rowKey: 'row_type',
      preferredColumns: const [
        'row_type',
        'player_key',
        'player',
        'season_id',
        'season_type',
        'team_key',
        'team',
        'franchise_key',
        'franchise',
        'games',
        'points',
        'rebounds',
        'assists',
        'ppg',
        'rpg',
        'apg',
        'award',
        'draft_year',
        'round',
        'pick',
        'game_key',
        'game_date',
        'source',
      ],
      metadata: {
        'playerKey': career.playerKey,
        'playerName': career.playerName,
        'nbaId': career.nbaId,
        'brefId': career.brefId,
        'careerRange': career.careerRangeLabel,
        'careerSeasonRows': career.seasons.length,
        'teamTenures': career.tenures.length,
        'teamFranchiseCoverage': career.tenureCoverageLabel,
        'teamFranchiseCoverageComplete': career.completeTeamFranchiseCoverage,
        'multiTeamAggregateSeasons': career.multiTeamAggregateSeasons.join(','),
        'careerGames': career.careerGames,
        'careerPoints': career.careerPoints,
        'careerRebounds': career.careerRebounds,
        'careerAssists': career.careerAssists,
        'awardsRows': context.awards.length,
        'allStarRows': context.allStarSelections.length,
        'draftRows': context.draftRecords.length,
        'recentGameRows': context.recentGames.length,
        'materialConflicts': career.materialConflictCount,
        'contextBoundary': context.sourceBoundaryLabel,
      },
    );
  }

  Future<NbaResearchContext> activateResearch(
    NbaPlayerCareerSnapshot career, {
    String league = 'NBA',
    String seasonType = 'regular',
  }) {
    if (!career.available) {
      throw ArgumentError('Canonical historical Player identity is required.');
    }
    final lastSeason = career.declaredLastSeason.isNotEmpty
        ? career.declaredLastSeason
        : (career.seasons.isEmpty ? '' : career.seasons.last.seasonId);
    if (lastSeason.isEmpty) {
      throw StateError(
        'Player career research requires an explicit source-backed season.',
      );
    }
    return _contextStore.activateHistorical(
      season: lastSeason,
      league: league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase(),
      seasonType: seasonType.trim().isEmpty ? 'regular' : seasonType.trim(),
      playerKey: career.playerKey,
      playerName: career.playerName,
    );
  }

  NbaEntityWatchItem watchItem(
    NbaPlayerCareerSnapshot career, {
    String league = 'NBA',
  }) {
    if (!career.available) {
      throw ArgumentError('Canonical historical Player identity is required.');
    }
    return NbaEntityWatchItem(
      kind: 'player-career',
      key: career.playerKey,
      label: career.playerName,
      subtitle: 'Historical NBA career · ${career.careerRangeLabel}',
      league: league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase(),
      seasonType: 'combined',
    );
  }

  Future<bool> isWatched(
    NbaPlayerCareerSnapshot career, {
    String league = 'NBA',
  }) =>
      _watchlistStore.contains(watchItem(career, league: league).signature);

  Future<bool> toggleWatch(
    NbaPlayerCareerSnapshot career, {
    String league = 'NBA',
  }) async {
    final item = watchItem(career, league: league);
    final next = await _watchlistStore.toggle(item);
    return next.any((candidate) => candidate.signature == item.signature);
  }
}
