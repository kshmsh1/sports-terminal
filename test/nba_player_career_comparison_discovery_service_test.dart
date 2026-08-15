import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_discovery_service.dart';

void main() {
  const service = NbaPlayerCareerComparisonDiscoveryService();

  test('search projects only usable canonical Player candidates', () async {
    final rows = await service.search(
      'alpha',
      loader: (query, league) async => {
        'groups': {
          'players': [
            {
              'player_key': 'alpha-key',
              'canonical_name': 'Alpha Player',
              'nba_id': '101',
              'league_id': league,
              'last_stat_season': '2023-24',
              'primary_position': 'G',
            },
            {'player_key': '', 'canonical_name': 'Broken'},
            {'player_key': 'alpha-key', 'canonical_name': 'Duplicate'},
          ],
        },
      },
    );
    expect(rows, hasLength(1));
    expect(rows.single.playerKey, 'alpha-key');
    expect(rows.single.leagueId, 'NBA');
  });

  test('queries shorter than two characters do not call source', () async {
    var called = false;
    final rows = await service.search(
      'a',
      loader: (query, league) async {
        called = true;
        return const {};
      },
    );
    expect(rows, isEmpty);
    expect(called, isFalse);
  });

  test('exact match prioritizes canonical key then NBA id then exact name', () {
    const candidates = [
      NbaPlayerCareerComparisonCandidate(
        playerKey: 'a',
        playerName: 'Same Name',
        nbaId: '1',
        leagueId: 'NBA',
        lastSeason: '',
        position: '',
      ),
      NbaPlayerCareerComparisonCandidate(
        playerKey: 'b',
        playerName: 'Beta',
        nbaId: '2',
        leagueId: 'NBA',
        lastSeason: '',
        position: '',
      ),
    ];
    expect(service.exactMatch(candidates, playerKey: 'b')?.nbaId, '2');
    expect(service.exactMatch(candidates, nbaId: '1')?.playerKey, 'a');
    expect(service.exactMatch(candidates, playerName: 'beta')?.playerKey, 'b');
  });

  test('no exact identity evidence stays unresolved', () {
    const candidates = [
      NbaPlayerCareerComparisonCandidate(
        playerKey: 'a',
        playerName: 'Alpha',
        nbaId: '1',
        leagueId: 'NBA',
        lastSeason: '',
        position: '',
      ),
    ];
    expect(service.exactMatch(candidates, playerName: 'Al'), isNull);
  });
}
