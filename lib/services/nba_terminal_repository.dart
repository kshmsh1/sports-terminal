

import 'historical_nba_repository.dart';
import 'product_local_store.dart';

class NbaTerminalRepository {
  const NbaTerminalRepository({
    ProductLocalStore store = const ProductLocalStore(),
  });

  Future<Map<String, dynamic>> manifest() => _get('/v2/nba/terminal/manifest');

  Future<Map<String, dynamic>> seasons({
    String league = 'NBA',
    String query = '',
    int offset = 0,
    int limit = 100,
  }) =>
      _get(
        '/v2/nba/terminal/seasons',
        query: {
          'league': league,
          if (query.isNotEmpty) 'query': query,
          'offset': '$offset',
          'limit': '$limit',
        },
      );

  Future<Map<String, dynamic>> commands({String query = ''}) => _get(
        '/v2/nba/terminal/commands',
        query: {if (query.isNotEmpty) 'query': query},
      );

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    throw const HistoricalNbaException(
      'Runtime terminal API access is disabled. Use static terminal data.',
    );
  }
}
