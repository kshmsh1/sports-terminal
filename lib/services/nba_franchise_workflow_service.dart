import '../models/route_payload.dart';
import 'nba_entity_watchlist_store.dart';
import 'nba_franchise_intelligence_engine.dart';
import 'nba_franchise_performance_engine.dart';
import 'nba_franchise_player_history_engine.dart';
import 'nba_research_context_store.dart';
import 'sports_object_router.dart';

/// Packages one canonical historical NBA Franchise into shared terminal state
/// and coordinates its persistent watch/research workflows.
class NbaFranchiseWorkflowService {
  const NbaFranchiseWorkflowService({
    NbaResearchContextStore contextStore = const NbaResearchContextStore(),
    NbaEntityWatchlistStore watchlistStore = const NbaEntityWatchlistStore(),
  })  : _contextStore = contextStore,
        _watchlistStore = watchlistStore;

  final NbaResearchContextStore _contextStore;
  final NbaEntityWatchlistStore _watchlistStore;

  RoutePayload package({
    required NbaFranchiseIntelligenceSnapshot franchise,
    required NbaFranchisePlayerHistoryResult playerHistory,
    String targetRoute = 'Open',
    String league = 'NBA',
  }) {
    final performance = const NbaFranchisePerformanceEngine().build(franchise);
    final rows = <Map<String, dynamic>>[
      for (final identity in franchise.teamIdentities)
        {
          'row_type': 'team_identity',
          'franchise_key': franchise.franchiseKey,
          'franchise': franchise.franchiseName,
          'team_key': identity.teamKey,
          'team': identity.teamName,
          'abbreviation': identity.abbreviation,
          'league': identity.leagueId,
          'active_from': identity.activeFrom,
          'active_to': identity.activeTo,
          'nba_team_id': identity.nbaTeamId,
          'source_count': identity.sourceCount,
        },
      for (final season in performance.seasons)
        {
          'row_type': 'season',
          'franchise_key': franchise.franchiseKey,
          'franchise': franchise.franchiseName,
          'season_id': season.seasonId,
          'team_keys': season.teamKeys.join(','),
          'team_labels': season.teamLabels.join(' / '),
          'wins': season.wins,
          'losses': season.losses,
          'win_pct': season.winPct,
        },
      for (var index = 0; index < playerHistory.players.length; index++)
        {
          'row_type': 'player_history',
          'franchise_key': franchise.franchiseKey,
          'franchise': franchise.franchiseName,
          'rank': index + 1,
          'player_key': playerHistory.players[index].playerKey,
          'player': playerHistory.players[index].playerName,
          'team_keys': playerHistory.players[index].teamKeys.join(','),
          'first_season': playerHistory.players[index].firstSeason,
          'last_season': playerHistory.players[index].lastSeason,
          'seasons': playerHistory.players[index].seasons,
          'games': playerHistory.players[index].games,
          'points': playerHistory.players[index].points,
          'rebounds': playerHistory.players[index].rebounds,
          'assists': playerHistory.players[index].assists,
        },
    ];
    final readiness = !franchise.available || rows.isEmpty ? 'Partial' : 'Ready';
    return const SportsObjectRouter().packageRows(
      datasetId: 'nba_franchise_${franchise.franchiseKey}',
      packageId: franchise.franchiseKey,
      displayLabel: '${franchise.franchiseName} · Franchise',
      sourceObjectType: 'NBA Franchise',
      rows: rows,
      targetRoute: targetRoute,
      sourceSnapshot: 'historical-franchise-dossier',
      readinessState: readiness,
      filterSummary: 'franchise=${franchise.franchiseKey}; league=${league.toUpperCase()}',
      rowKey: 'row_type',
      preferredColumns: const [
        'row_type',
        'franchise_key',
        'franchise',
        'team_key',
        'team',
        'abbreviation',
        'active_from',
        'active_to',
        'season_id',
        'wins',
        'losses',
        'win_pct',
        'rank',
        'player_key',
        'player',
        'games',
        'points',
        'rebounds',
        'assists',
      ],
      metadata: {
        'franchiseKey': franchise.franchiseKey,
        'franchiseName': franchise.franchiseName,
        'currentAbbreviation': franchise.currentAbbreviation,
        'seasonRange': franchise.seasonRangeLabel,
        'teamIdentityRows': franchise.teamIdentities.length,
        'regularSeasonRows': performance.seasons.length,
        'playerHistoryRows': playerHistory.players.length,
        'playerHistoryCoverage': playerHistory.coverageLabel,
        'playerHistoryCompleteAcrossRequestedIdentities':
            playerHistory.completeAcrossRequestedIdentities,
        'totalWins': performance.totalWins,
        'totalLosses': performance.totalLosses,
        'weightedWinPct': performance.weightedWinPct,
        'awardsMapping': 'not-exposed-at-franchise-scope',
        'draftMapping': 'not-exposed-at-franchise-scope',
      },
    );
  }

  Future<NbaResearchContext> activateResearch(
    NbaFranchiseIntelligenceSnapshot franchise, {
    String league = 'NBA',
  }) {
    if (!franchise.available) {
      throw ArgumentError('Canonical Franchise identity is required.');
    }
    if (franchise.lastSeason.isEmpty) {
      throw StateError(
        'Franchise research requires an explicit source-backed season; no last season is exposed.',
      );
    }
    return _contextStore.activateHistorical(
      season: franchise.lastSeason,
      league: league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase(),
      seasonType: 'regular',
    );
  }

  NbaEntityWatchItem watchItem(
    NbaFranchiseIntelligenceSnapshot franchise, {
    String league = 'NBA',
  }) {
    if (!franchise.available) {
      throw ArgumentError('Canonical Franchise identity is required.');
    }
    final normalizedLeague =
        league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase();
    return NbaEntityWatchItem(
      kind: 'franchise',
      key: franchise.franchiseKey,
      label: franchise.franchiseName,
      subtitle: franchise.lastSeason.isEmpty
          ? 'Canonical historical NBA franchise'
          : 'Canonical historical franchise · through ${franchise.lastSeason}',
      league: normalizedLeague,
      seasonType: 'combined',
    );
  }

  Future<bool> isWatched(
    NbaFranchiseIntelligenceSnapshot franchise, {
    String league = 'NBA',
  }) =>
      _watchlistStore.contains(watchItem(franchise, league: league).signature);

  Future<bool> toggleWatch(
    NbaFranchiseIntelligenceSnapshot franchise, {
    String league = 'NBA',
  }) async {
    final item = watchItem(franchise, league: league);
    final next = await _watchlistStore.toggle(item);
    return next.any((candidate) => candidate.signature == item.signature);
  }
}
