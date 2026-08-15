import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_franchise_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_franchise_player_history_engine.dart';

void main() {
  test('aggregates bounded notable-player rows across franchise team identities', () {
    final franchise = _franchise(['alpha_old', 'alpha_new']);
    final result = const NbaFranchisePlayerHistoryEngine().build(
      franchise: franchise,
      teamDossiers: {
        'alpha_old': {
          'notable_players': [
            {
              'player_key': 'p1',
              'player_name': 'Player One',
              'seasons': 4,
              'games': 300,
              'pts': 6000,
              'reb': 1200,
              'ast': 1500,
              'first_season': '1996-97',
              'last_season': '1999-00',
            },
          ],
        },
        'alpha_new': {
          'notable_players': [
            {
              'player_key': 'p1',
              'player_name': 'Player One',
              'seasons': 2,
              'games': 150,
              'pts': 3300,
              'reb': 700,
              'ast': 900,
              'first_season': '2000-01',
              'last_season': '2001-02',
            },
            {
              'player_key': 'p2',
              'player_name': 'Player Two',
              'seasons': 3,
              'games': 240,
              'pts': 5100,
              'reb': 2000,
              'ast': 500,
              'first_season': '2002-03',
              'last_season': '2004-05',
            },
          ],
        },
      },
    );

    expect(result.available, isTrue);
    expect(result.completeAcrossRequestedIdentities, isTrue);
    expect(result.loadedTeamDossiers, 2);
    expect(result.sourceRows, 3);
    expect(result.players.map((row) => row.playerKey), ['p1', 'p2']);
    expect(result.players.first.games, 450);
    expect(result.players.first.points, 9300);
    expect(result.players.first.teamKeys, ['alpha_new', 'alpha_old']);
    expect(result.players.first.firstSeason, '1996-97');
    expect(result.players.first.lastSeason, '2001-02');
  });

  test('missing team dossiers remain explicit coverage gaps', () {
    final result = const NbaFranchisePlayerHistoryEngine().build(
      franchise: _franchise(['alpha_old', 'alpha_new']),
      teamDossiers: {
        'alpha_new': {
          'notable_players': [
            {
              'player_key': 'p2',
              'player_name': 'Player Two',
              'games': 100,
              'pts': 2000,
            },
          ],
        },
      },
    );

    expect(result.loadedTeamDossiers, 1);
    expect(result.missingTeamDossiers, 1);
    expect(result.completeAcrossRequestedIdentities, isFalse);
    expect(result.coverageLabel, contains('1/2 team dossiers loaded'));
  });

  test('malformed player rows are discarded rather than fabricated', () {
    final result = const NbaFranchisePlayerHistoryEngine().build(
      franchise: _franchise(['alpha']),
      teamDossiers: {
        'alpha': {
          'notable_players': [
            const {},
            {'player_key': 'p1'},
            {'player_name': 'Nameless Key'},
          ],
        },
      },
    );

    expect(result.players, isEmpty);
    expect(result.sourceRows, 0);
    expect(result.available, isTrue);
  });
}

NbaFranchiseIntelligenceSnapshot _franchise(List<String> teamKeys) {
  return NbaFranchiseIntelligenceSnapshot(
    franchiseKey: 'fr_alpha',
    franchiseName: 'Alpha Franchise',
    currentAbbreviation: 'ALP',
    sourceCount: 1,
    teamIdentities: [
      for (final key in teamKeys)
        NbaFranchiseTeamIdentity(
          teamKey: key,
          teamName: key,
          abbreviation: key.toUpperCase(),
          leagueId: 'NBA',
          activeFrom: '',
          activeTo: '',
          nbaTeamId: '',
          sourceCount: 1,
        ),
    ],
    seasons: const [],
    firstSeason: '',
    lastSeason: '',
    declaredSeasonCount: null,
    declaredIdentityCount: teamKeys.length,
  );
}
