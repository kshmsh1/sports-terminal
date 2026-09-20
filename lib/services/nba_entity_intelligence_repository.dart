

import 'historical_nba_repository.dart';
import 'product_local_store.dart';

class NbaEntityIntelligenceRepository {
  const NbaEntityIntelligenceRepository({
    ProductLocalStore store = const ProductLocalStore(),
  });

  Future<Map<String, dynamic>> search(
    String query, {
    String league = '',
    Set<String> kinds = const {'player', 'team', 'franchise', 'season', 'game'},
    int limitPerKind = 20,
  }) =>
      _get(
        '/v2/nba/history/entities/search',
        query: {
          'query': query,
          if (league.isNotEmpty && league != 'ALL') 'league': league,
          'kinds': kinds.join(','),
          'limit_per_kind': '$limitPerKind',
        },
      );

  Future<Map<String, dynamic>> playerDossier(
    String playerKey, {
    String league = '',
    String seasonType = 'combined',
    int recentGames = 25,
  }) =>
      _get(
        '/v2/nba/history/players/${Uri.encodeComponent(playerKey)}/dossier',
        query: {
          if (league.isNotEmpty && league != 'ALL') 'league': league,
          'season_type': seasonType,
          'recent_games': '$recentGames',
        },
      );

  Future<Map<String, dynamic>> teamDossier(
    String teamKey, {
    String league = '',
    String seasonType = 'regular',
    int recentGames = 25,
  }) =>
      _get(
        '/v2/nba/history/teams/${Uri.encodeComponent(teamKey)}/dossier',
        query: {
          if (league.isNotEmpty && league != 'ALL') 'league': league,
          'season_type': seasonType,
          'recent_games': '$recentGames',
        },
      );

  Future<Map<String, dynamic>> franchiseDossier(
    String franchiseKey, {
    String league = '',
  }) =>
      _get(
        '/v2/nba/history/franchises/${Uri.encodeComponent(franchiseKey)}/dossier',
        query: {
          if (league.isNotEmpty && league != 'ALL') 'league': league,
        },
      );

  Future<Map<String, dynamic>> seasonCommand(
    String season, {
    String league = 'NBA',
    String seasonType = 'regular',
    int leaderLimit = 10,
  }) =>
      _get(
        '/v2/nba/history/seasons/${Uri.encodeComponent(season)}/command',
        query: {
          'league': league,
          'season_type': seasonType,
          'leader_limit': '$leaderLimit',
        },
      );

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    throw const HistoricalNbaException(
      'Runtime entity API access is disabled. Use static entity intelligence data.',
    );
  }
}
