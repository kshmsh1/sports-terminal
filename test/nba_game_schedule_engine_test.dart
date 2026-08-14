import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_schedule_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  const engine = NbaGameScheduleEngine();

  test('normalizes, sorts and summarizes canonical schedule rows', () {
    final result = engine.build(_seed());

    expect(result.rows, hasLength(3));
    expect(result.rows.first.gameId, 'g1');
    expect(result.rows.last.gameId, 'g3');
    expect(result.rows.first.matchupLabel, 'AWY @ HME');
    expect(result.completedGames, 2);
    expect(result.scheduledGames, 1);
    expect(result.uniqueTeams, 3);
    expect(result.statusOptions, containsAll(['All', 'Final', 'Scheduled']));
    expect(result.seasonTypeOptions, containsAll(['All', 'regular', 'playoffs']));
  });

  test('filters by team, status, season type and free-text query', () {
    final team = engine.build(_seed(), teamId: 'HME');
    expect(team.rows.map((row) => row.gameId), ['g1', 'g2']);

    final finalGames = engine.build(_seed(), status: 'Final');
    expect(finalGames.rows.map((row) => row.gameId), ['g1', 'g3']);

    final playoffs = engine.build(_seed(), seasonType: 'playoffs');
    expect(playoffs.rows.map((row) => row.gameId), ['g3']);

    final query = engine.build(_seed(), query: 'third team');
    expect(query.rows.map((row) => row.gameId), ['g2', 'g3']);
  });

  test('filters inclusively by calendar date range', () {
    final result = engine.build(
      _seed(),
      dateFrom: DateTime.utc(2026, 1, 6),
      dateTo: DateTime.utc(2026, 1, 7),
    );

    expect(result.rows.map((row) => row.gameId), ['g2', 'g3']);
  });

  test('supports reverse chronological ordering without inventing dates', () {
    final result = engine.build(_seed(), ascending: false);

    expect(result.rows.map((row) => row.gameId), ['g3', 'g2', 'g1']);
  });
}

NbaTerminalSeedSnapshot _seed() => NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AWY', 'team_name': 'Away Team', 'abbreviation': 'AWY'},
        {'team_id': 'HME', 'team_name': 'Home Team', 'abbreviation': 'HME'},
        {'team_id': 'THR', 'team_name': 'Third Team', 'abbreviation': 'THR'},
      ],
      'players': const [],
      'games': [
        {
          'game_id': 'g2',
          'game_date': '2026-01-06',
          'season': '2025-26',
          'season_type': 'regular',
          'away_team_id': 'HME',
          'home_team_id': 'THR',
          'status': 'Scheduled',
          'arena': 'Second Arena',
        },
        {
          'game_id': 'g1',
          'game_date': '2026-01-05',
          'season': '2025-26',
          'season_type': 'regular',
          'away_team_id': 'AWY',
          'home_team_id': 'HME',
          'away_score': 101,
          'home_score': 112,
          'status': 'Final',
        },
        {
          'game_id': 'g3',
          'game_date': '2026-01-07',
          'season': '2025-26',
          'season_type': 'playoffs',
          'away_team_id': 'THR',
          'home_team_id': 'AWY',
          'away_score': 98,
          'home_score': 104,
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
      'release_manifest': {'id': 'release-test', 'status': 'certified'},
      'standings': const [],
      'launch_config': {'supportedSeason': '2025-26'},
      'asset_path': 'test://schedule',
    });
