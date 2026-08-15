import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_loader.dart';

Map<String, dynamic> _playerPayload(String key, String name, String teamKey) => {
      'profile': {
        'player_key': key,
        'canonical_name': name,
        'primary_position': 'G',
      },
      'summary': {
        'first_season': '2020-21',
        'last_season': '2020-21',
        'season_rows': 1,
      },
      'seasons': [
        {
          'season_id': '2020-21',
          'season_type': 'regular',
          'league_id': 'NBA',
          'team_key': teamKey,
          'team_abbreviation': 'TST',
          'games': 10,
          'pts': 200,
          'primary_source': 'test',
        },
      ],
      'awards': [
        {'season_id': '2020-21', 'award': 'Example Award', 'source': 'test'},
      ],
    };

void main() {
  const loader = NbaPlayerCareerComparisonLoader();

  test('loads two canonical careers and contexts through one boundary', () async {
    final result = await loader.load(
      leftPlayerKey: 'a',
      rightPlayerKey: 'b',
      loadPlayer: (key, seasonType) async =>
          _playerPayload(key, key == 'a' ? 'Alpha' : 'Beta', 'team-$key'),
      loadTeam: (teamKey) async => {
        'profile': {
          'canonical_name': 'Team $teamKey',
          'franchise_key': 'franchise-$teamKey',
          'franchise_name': 'Franchise $teamKey',
        },
      },
    );

    expect(result.leftCareer.playerName, 'Alpha');
    expect(result.rightCareer.playerName, 'Beta');
    expect(result.leftCareer.tenures.single.franchiseKey, 'franchise-team-a');
    expect(result.rightContext.awards.single.award, 'Example Award');
  });

  test('failed Team enrichment remains a visible career coverage gap', () async {
    final result = await loader.load(
      leftPlayerKey: 'a',
      rightPlayerKey: 'b',
      loadPlayer: (key, seasonType) async => _playerPayload(key, key, 'missing-$key'),
      loadTeam: (teamKey) async => throw StateError('missing'),
    );

    expect(result.leftCareer.missingTeamDossierKeys, ['missing-a']);
    expect(result.rightCareer.missingTeamDossierKeys, ['missing-b']);
  });

  test('season type is normalized and passed explicitly to both Player loads', () async {
    final observed = <String>[];
    await loader.load(
      leftPlayerKey: 'a',
      rightPlayerKey: 'b',
      seasonType: 'playoffs',
      loadPlayer: (key, seasonType) async {
        observed.add('$key:$seasonType');
        return _playerPayload(key, key, '');
      },
      loadTeam: (teamKey) async => const {},
    );
    expect(observed, ['a:playoffs', 'b:playoffs']);
  });

  test('missing canonical Player key is rejected before source access', () async {
    expect(
      () => loader.load(
        leftPlayerKey: '',
        rightPlayerKey: 'b',
        loadPlayer: (key, seasonType) async => _playerPayload(key, key, ''),
      ),
      throwsArgumentError,
    );
  });
}
