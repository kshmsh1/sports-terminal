import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_rest_density_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('derives back-to-back and rest intervals from explicit calendar dates', () {
    final result = const NbaSeasonRestDensityEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Regular Season',
    );
    final alpha = result.teams.firstWhere((team) => team.teamId == 'AAA');

    expect(alpha.datedGames, 5);
    expect(alpha.undatedGames, 1);
    expect(alpha.backToBacks, 2);
    expect(alpha.oneDayRestOccurrences, 2);
    expect(alpha.minimumRestDays, 0);
    expect(alpha.maximumRestDays, 1);
    expect(alpha.averageRestDays, 0.5);
    expect(alpha.maxGamesInSevenDays, 5);
    expect(alpha.fourPlusInSixDayWindows, greaterThanOrEqualTo(1));
  });

  test('scheduled dated games count toward density without becoming results', () {
    final result = const NbaSeasonRestDensityEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Regular Season',
    );
    final alpha = result.teams.firstWhere((team) => team.teamId == 'AAA');

    expect(alpha.totalGames, 6);
    expect(alpha.datedGames, 5);
    expect(result.datedGamesAcrossTeamSchedules, greaterThan(0));
  });

  test('undated games remain coverage gaps and never create rest intervals', () {
    final result = const NbaSeasonRestDensityEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Regular Season',
    );
    final alpha = result.teams.firstWhere((team) => team.teamId == 'AAA');

    expect(alpha.undatedGames, 1);
    expect(alpha.datedGames, 5);
    expect(alpha.totalGames, 6);
  });

  test('season and postseason scopes stay isolated', () {
    final regular = const NbaSeasonRestDensityEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Regular Season',
    );
    final playoffs = const NbaSeasonRestDensityEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Playoffs',
    );
    final prior = const NbaSeasonRestDensityEngine().build(
      _seed(),
      seasonId: '2024-25',
      seasonType: 'Regular Season',
    );

    expect(regular.teams.firstWhere((team) => team.teamId == 'AAA').totalGames, 6);
    expect(playoffs.teams.firstWhere((team) => team.teamId == 'AAA').totalGames, 1);
    expect(prior.teams.firstWhere((team) => team.teamId == 'AAA').totalGames, 1);
  });

  test('date-only model does not invent rest when fewer than two dates exist', () {
    final result = const NbaSeasonRestDensityEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Playoffs',
    );
    final alpha = result.teams.firstWhere((team) => team.teamId == 'AAA');

    expect(alpha.averageRestDays, isNull);
    expect(alpha.minimumRestDays, isNull);
    expect(alpha.maximumRestDays, isNull);
    expect(alpha.backToBacks, 0);
  });
}

NbaTerminalSeedSnapshot _seed() => NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
        {'team_id': 'CCC', 'team_name': 'Gamma', 'abbreviation': 'CCC'},
      ],
      'players': const [],
      'games': [
        {
          'game_id': 'old',
          'season_id': '2024-25',
          'game_date': '2025-03-01',
          'season_type': 'Regular Season',
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
          'home_score': 100,
          'away_score': 90,
          'status': 'Final',
        },
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-01',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 110,
          'away_score': 100,
          'status': 'Final',
        },
        {
          'game_id': 'g2',
          'season_id': '2025-26',
          'game_date': '2026-01-02',
          'season_type': 'Regular Season',
          'home_team_id': 'CCC',
          'away_team_id': 'AAA',
          'home_score': 95,
          'away_score': 100,
          'status': 'Final',
        },
        {
          'game_id': 'g3',
          'season_id': '2025-26',
          'game_date': '2026-01-04',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'CCC',
          'home_score': 105,
          'away_score': 99,
          'status': 'Final',
        },
        {
          'game_id': 'g4',
          'season_id': '2025-26',
          'game_date': '2026-01-06',
          'season_type': 'Regular Season',
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
          'status': 'Scheduled',
        },
        {
          'game_id': 'g5',
          'season_id': '2025-26',
          'game_date': '2026-01-07',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'status': 'Scheduled',
        },
        {
          'game_id': 'g-undated',
          'season_id': '2025-26',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'CCC',
          'status': 'Scheduled',
        },
        {
          'game_id': 'gp1',
          'season_id': '2025-26',
          'game_date': '2026-04-20',
          'season_type': 'Playoffs',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 115,
          'away_score': 108,
          'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': const [],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': const [],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'status': 'test'},
      'standings': const [],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://season-rest-density',
      'used_fallback': false,
    });
