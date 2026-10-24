import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_team_stints.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  final aggregate = const NbaStatsWorkstationEngine().buildRows(
    NbaTerminalSeedSnapshot.fromMap({
      'players': [],
      'player_season_totals': [{
        'player_id': 'test_harden',
        'player_label': 'James Harden',
        'team_ids': '2TM',
        'teams_played_for': ['LAC', 'CLE'],
        'position': 'PG',
        'season_type': 'regular',
        'games': 70,
        'minutes': 2100,
        'points': 1750,
        'assists': 630,
      }],
    }),
  ).single;

  test('trade aggregate is a single season row and matches both team filters',
      () {
    expect(isMultiTeamStatsRow(aggregate), isTrue);
    expect(statsRowMatchesTeam(aggregate, 'LAC'), isTrue);
    expect(statsRowMatchesTeam(aggregate, 'CLE'), isTrue);
    expect(statsRowMatchesTeam(aggregate, 'BOS'), isFalse);
    expect(statsRowMatchesTeam(aggregate, '2TM'), isTrue);
    expect(aggregate.value('pts'), closeTo(25, .00001));
  });

  test('expands from canonical stint source without copying aggregate totals', () {
    final rows = sourceBackedTeamStints(
      dossier: {
        'profile': {'primary_position': 'PG'},
        'seasons': [
          {
            'season_id': '2025-26',
            'season_type': 'regular',
            'team_abbreviation': 'LAC',
            'games': 40, 'minutes': 1200, 'pts': 1000,
            'reb': 180, 'ast': 360, 'position': 'PG',
          },
          {
            'season_id': '2025-26',
            'season_type': 'regular',
            'team_abbreviation': 'CLE',
            'games': 30, 'minutes': 900, 'pts': 750,
            'reb': 120, 'ast': 270, 'position': 'PG',
          },
          {
            'season_id': '2025-26', 'season_type': 'regular',
            'team_abbreviation': '2TM',
            'games': 70, 'minutes': 2100, 'pts': 1750,
          },
          {
            'season_id': '2024-25', 'season_type': 'regular',
            'team_abbreviation': 'LAC',
            'games': 79, 'minutes': 2400, 'pts': 1200,
          },
          {
            'season_id': '2025-26', 'season_type': 'playoffs',
            'team_abbreviation': 'CLE',
            'games': 11, 'minutes': 300, 'pts': 400,
          },
        ],
      },
      playerId: aggregate.playerId,
      playerName: aggregate.player,
      seasonId: '2025-26',
      seasonType: NbaStatsSeasonType.regular,
    );
    expect(rows.map((row) => row.team), ['CLE', 'LAC']);
    expect(rows[0].value('gp'), 30);
    expect(rows[1].value('gp'), 40);
    expect(rows[0].value('pts'), 25);
    expect(rows[1].value('pts'), 25);
    expect(rows[0].value('ast'), 9);
    expect(rows[1].value('ast'), 9);
  });

  test('missing team source does not fabricate a per-team split', () {
    final rows = sourceBackedTeamStints(
      dossier: {'seasons': []},
      playerId: 'test_harden', playerName: 'James Harden',
      seasonId: '2025-26', seasonType: NbaStatsSeasonType.regular,
    );
    expect(rows, isEmpty);
  });
}
