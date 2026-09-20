

import 'historical_nba_repository.dart';
import 'product_local_store.dart';

class HistoricalNbaResearchRepository {
  const HistoricalNbaResearchRepository({
    ProductLocalStore store = const ProductLocalStore(),
  });

  Future<Map<String, dynamic>> summary() =>
      _get('/v2/nba/history/research/summary');

  Future<Map<String, dynamic>> playerGames(
    String playerKey, {
    String season = '',
    String seasonType = 'combined',
    int offset = 0,
    int limit = 100,
  }) =>
      _get(
        '/v2/nba/history/players/${Uri.encodeComponent(playerKey)}/games',
        query: {
          if (season.isNotEmpty) 'season': season,
          'season_type': seasonType,
          'offset': '$offset',
          'limit': '$limit',
        },
      );

  Future<Map<String, dynamic>> allTime({
    String metric = 'pts',
    String basis = 'totals',
    String mode = 'career',
    int bestN = 5,
    String league = 'NBA',
    String seasonType = 'regular',
    String seasonFrom = '',
    String seasonTo = '',
    int minSeasons = 1,
    double minGames = 0,
    int offset = 0,
    int limit = 200,
  }) =>
      _get(
        '/v2/nba/history/all-time',
        query: {
          'metric': metric,
          'basis': basis,
          'mode': mode,
          'best_n': '$bestN',
          'league': league,
          'season_type': seasonType,
          if (seasonFrom.isNotEmpty) 'season_from': seasonFrom,
          if (seasonTo.isNotEmpty) 'season_to': seasonTo,
          'min_seasons': '$minSeasons',
          'min_games': '$minGames',
          'offset': '$offset',
          'limit': '$limit',
        },
      );

  Future<Map<String, dynamic>> compare({
    required List<String> playerKeys,
    String metric = 'pts',
    String basis = 'per_game',
    String league = 'NBA',
    String seasonType = 'regular',
    double minGames = 10,
  }) =>
      _get(
        '/v2/nba/history/compare',
        query: {
          'player_keys': playerKeys.join(','),
          'metric': metric,
          'basis': basis,
          'league': league,
          'season_type': seasonType,
          'min_games': '$minGames',
        },
      );

  Future<Map<String, dynamic>> games({
    String season = '',
    String league = 'NBA',
    String seasonType = 'regular',
    String teamKey = '',
    String dateFrom = '',
    String dateTo = '',
    int offset = 0,
    int limit = 250,
  }) =>
      _get(
        '/v2/nba/history/games',
        query: {
          if (season.isNotEmpty) 'season': season,
          'league': league,
          'season_type': seasonType,
          if (teamKey.isNotEmpty) 'team_key': teamKey,
          if (dateFrom.isNotEmpty) 'date_from': dateFrom,
          if (dateTo.isNotEmpty) 'date_to': dateTo,
          'offset': '$offset',
          'limit': '$limit',
        },
      );

  Future<Map<String, dynamic>> game(String gameKey) =>
      _get('/v2/nba/history/games/${Uri.encodeComponent(gameKey)}');

  Future<Map<String, dynamic>> playByPlay(
    String gameKey, {
    int offset = 0,
    int limit = 1000,
  }) =>
      _get(
        '/v2/nba/history/games/${Uri.encodeComponent(gameKey)}/play-by-play',
        query: {'offset': '$offset', 'limit': '$limit'},
      );

  Future<Map<String, dynamic>> franchises({
    String query = '',
    String league = '',
    int limit = 200,
  }) =>
      _get(
        '/v2/nba/history/franchises',
        query: {
          if (query.isNotEmpty) 'query': query,
          if (league.isNotEmpty) 'league': league,
          'limit': '$limit',
        },
      );

  Future<Map<String, dynamic>> franchise(String franchiseKey) =>
      _get('/v2/nba/history/franchises/${Uri.encodeComponent(franchiseKey)}');

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    throw const HistoricalNbaException(
      'Legacy backend research access is disabled. Use the static NBA website repository.',
    );
  }
}
