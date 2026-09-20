

import 'product_local_store.dart';

class NbaAwardsRepository {
  const NbaAwardsRepository({
    ProductLocalStore store = const ProductLocalStore(),
  });

  Future<Map<String, dynamic>> catalog({String league = 'NBA'}) => _get(
        '/v2/nba/awards/catalog',
        query: {'league': league},
      );

  Future<Map<String, dynamic>> history(
    String awardKey, {
    String league = 'NBA',
    String season = '',
    bool winnerOnly = false,
    int offset = 0,
    int limit = 500,
  }) =>
      _get(
        '/v2/nba/awards/history/${Uri.encodeComponent(awardKey)}',
        query: {
          'league': league,
          if (season.isNotEmpty) 'season': season,
          'winner_only': winnerOnly.toString(),
          'offset': offset.toString(),
          'limit': limit.toString(),
        },
      );

  Future<Map<String, dynamic>> season(
    String seasonId, {
    String league = 'NBA',
  }) =>
      _get(
        '/v2/nba/awards/season/${Uri.encodeComponent(seasonId)}',
        query: {'league': league},
      );

  Future<Map<String, dynamic>> player(
    String playerKey, {
    String league = '',
  }) =>
      _get(
        '/v2/nba/awards/player/${Uri.encodeComponent(playerKey)}',
        query: {if (league.isNotEmpty) 'league': league},
      );

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    throw const NbaAwardsException(
      'Runtime awards API access is disabled. Awards must be materialized into the static corpus.',
    );
  }
}

class NbaAwardsException implements Exception {
  const NbaAwardsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
