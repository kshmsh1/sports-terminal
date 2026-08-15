import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sports_terminal/services/website_nba_static_repository.dart';

void main() {
  test('historical website data resolves from static files only', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.path);
      final path = request.url.path;
      if (path.endsWith('/data/nba_static/manifest.json')) {
        return _json({
          'contract': 'sports-terminal-static-nba-website-v2',
          'runtime': {
            'historical_http_api_required': false,
            'sqlite_required_by_browser': false,
          },
        });
      }
      if (path.endsWith('/data/nba_static/seasons.json')) {
        return _json([
          {
            'season_id': '2025-26',
            'label': '2025-26',
            'start_year': 2025,
            'players': 2,
            'teams': 2,
            'games': 1,
          },
          {
            'season_id': '1946-47',
            'label': '1946-47',
            'start_year': 1946,
            'players': 1,
            'teams': 1,
            'games': 1,
          },
        ]);
      }
      if (path.endsWith('/data/nba_static/seasons/2025-26/regular.json')) {
        return _json({
          'manifest': {'season': '2025-26'},
          'teams': [
            {'team_id': 'team:bos', 'team_abbreviation': 'BOS', 'team_name': 'Boston Celtics'},
          ],
          'players': [
            {'player_id': 'player:tatum', 'display_name': 'Jayson Tatum', 'team_id': 'team:bos'},
          ],
          'games': [],
          'team_records': [],
          'team_game_logs': [],
          'player_season_totals': [
            {'player_id': 'player:tatum', 'points': 1800, 'games': 72},
          ],
          'player_leaders': {},
          'player_game_highs': {},
          'player_game_logs_top': [],
          'search_index': [],
          'data_dictionary': {},
          'validation_report': {'status': 'pass'},
          'asset_manifest': null,
          'standings': [],
          'play_by_play': [],
          'launch_config': {'datasetStatus': 'historical-canonical'},
          'asset_path': 'static://nba/2025-26/regular',
        });
      }
      if (path.endsWith('/data/nba_static/players/index.json')) {
        return _json([
          {
            'player_key': 'player:tatum',
            'canonical_name': 'Jayson Tatum',
            'primary_position': 'SF',
            'bref_id': 'tatumja01',
            'file': 'players/tatum.json',
          },
        ]);
      }
      if (path.endsWith('/data/nba_static/teams/index.json')) {
        return _json([
          {
            'team_key': 'team:bos',
            'canonical_name': 'Boston Celtics',
            'abbreviation': 'BOS',
            'file': 'teams/bos.json',
          },
        ]);
      }
      if (path.endsWith('/data/nba_static/games/index.json')) {
        return _json([
          {
            'game_key': 'game:1',
            'nba_game_id': '001',
            'season_id': '2025-26',
            'file': 'games/2025-26/game1.json',
            'pbp_file': 'pbp/2025-26/game1.json',
          },
        ]);
      }
      if (path.endsWith('/data/nba_static/players/tatum.json')) {
        return _json({
          'kind': 'player',
          'profile': {'player_key': 'player:tatum', 'canonical_name': 'Jayson Tatum'},
          'regular_seasons': [],
          'playoff_seasons': [],
          'awards': [],
          'all_star': [],
          'draft': [],
          'recent_games': [],
        });
      }
      if (path.endsWith('/data/nba_static/teams/bos.json')) {
        return _json({
          'kind': 'team',
          'profile': {'team_key': 'team:bos', 'canonical_name': 'Boston Celtics', 'abbreviation': 'BOS'},
          'seasons': [],
          'recent_games': [],
          'notable_players': [],
        });
      }
      if (path.endsWith('/data/nba_static/games/2025-26/game1.json')) {
        return _json({
          'contract': 'sports-terminal-static-game-v1',
          'game': {'game_key': 'game:1', 'home_score': 110, 'away_score': 104},
          'teams': [],
          'players': [],
        });
      }
      if (path.endsWith('/data/nba_static/pbp/2025-26/game1.json')) {
        return _json({
          'contract': 'sports-terminal-static-pbp-v1',
          'game_key': 'game:1',
          'rows': [
            {'game_key': 'game:1', 'period': 1, 'event_number': 1, 'description': 'Tip'},
          ],
        });
      }
      return http.Response('not found', 404);
    });

    final repository = WebsiteNbaStaticRepository(client: client);
    final manifest = await repository.manifest();
    expect(manifest['contract'], 'sports-terminal-static-nba-website-v2');

    final seasons = await repository.seasons();
    expect(seasons.first.id, '2025-26');
    expect(seasons.last.id, '1946-47');

    final snapshot = await repository.seasonSnapshot('2025-26');
    expect(snapshot.players.single['display_name'], 'Jayson Tatum');
    expect(snapshot.playerSeasonTotals.single['points'], 1800);

    final playerSearch = await repository.searchEntities('Tatum', kinds: 'player');
    expect((playerSearch['groups'] as Map)['players'], hasLength(1));
    final teamSearch = await repository.searchEntities('BOS', kinds: 'team');
    expect((teamSearch['groups'] as Map)['teams'], hasLength(1));

    final player = await repository.playerDossier('player:tatum');
    expect((player['profile'] as Map)['canonical_name'], 'Jayson Tatum');
    final team = await repository.teamDossier('BOS');
    expect((team['profile'] as Map)['canonical_name'], 'Boston Celtics');

    final game = await repository.gameDetail('game:1');
    expect((game['game'] as Map)['home_score'], 110);
    final pbp = await repository.gamePlayByPlay('001');
    expect(pbp, hasLength(1));
    expect(pbp.single['description'], 'Tip');

    expect(requested, isNot(contains(predicate<String>((path) => path.contains('/v2/nba/history/')))));
    expect(requested, everyElement(contains('/data/nba_static/')));
  });

  test('static repository caches indexes and season shards', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      if (request.url.path.endsWith('/seasons.json')) {
        return _json([
          {'season_id': '2025-26', 'start_year': 2025},
        ]);
      }
      if (request.url.path.endsWith('/seasons/2025-26/regular.json')) {
        return _json({
          'manifest': {},
          'teams': [],
          'players': [],
          'games': [],
          'team_records': [],
          'team_game_logs': [],
          'player_season_totals': [],
          'player_leaders': {},
          'player_game_highs': {},
          'player_game_logs_top': [],
          'search_index': [],
          'data_dictionary': {},
        });
      }
      return http.Response('not found', 404);
    });
    final repository = WebsiteNbaStaticRepository(client: client);
    await repository.seasons();
    await repository.seasons();
    await repository.seasonSnapshot('2025-26');
    await repository.seasonSnapshot('2025-26');
    expect(calls, 2);
  });
}

http.Response _json(Object value) => http.Response(
      jsonEncode(value),
      200,
      headers: const {'content-type': 'application/json'},
    );
