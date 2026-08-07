import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('historical compatibility payload uses original seed snapshot contract', () {
    final snapshot = NbaTerminalSeedSnapshot.fromMap({
      'manifest': {
        'source': 'Sports Terminal canonical historical NBA warehouse',
        'warehouseBuild': {
          'generatedAt': '2026-08-07T00:00:00Z',
          'playByPlayEventsNormalized': 250000,
        },
      },
      'teams': [
        {'team_id': 't_a', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
      ],
      'players': [
        {
          'player_id': 'p_star',
          'player_name': 'Example Star',
          'position': 'PG',
          'team_abbreviation': 'AAA',
        },
      ],
      'games': [
        {
          'game_id': 'g1',
          'game_date': '2024-01-01',
          'home_team': 'AAA',
          'away_team': 'BBB',
        },
      ],
      'team_records': [
        {'team_id': 't_a', 'team_abbreviation': 'AAA', 'wins': 58, 'losses': 24},
      ],
      'team_game_logs': const [],
      'player_season_totals': [
        {
          'player_id': 'p_star',
          'player_label': 'Example Star',
          'team_ids': 'AAA',
          'position': 'PG',
          'age': 28,
          'games': 75,
          'minutes': 2700,
          'points': 1900,
          'assists': 620,
          'rebounds': 450,
          'offensive_rebounds': 60,
          'defensive_rebounds': 390,
          'steals': 110,
          'blocks': 35,
          'turnovers': 190,
          'personal_fouls': 150,
          'field_goals_made': 700,
          'field_goal_attempts': 1400,
          'three_pointers_made': 180,
          'three_point_attempts': 480,
          'free_throws_made': 320,
          'free_throw_attempts': 390,
          'avg_bpm': 6.7,
          'season_type': 'regular',
        },
      ],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': [
        {
          'player_id': 'p_star',
          'game_id': 'g1',
          'game_date': '2024-01-01',
          'points': 32,
          'rebounds': 8,
          'assists': 10,
        },
      ],
      'search_index': const [],
      'data_dictionary': {
        'source': 'canonical historical warehouse',
      },
      'validation_report': {
        'status': 'pass',
        'dataset': 'historical-canonical',
      },
      'release_manifest': {
        'status': 'historical-canonical',
        'season': '2023-24',
      },
      'standings': const [],
      'launch_config': {
        'supportedSeason': '2023-24',
        'datasetStatus': 'historical-canonical',
      },
      'asset_path': 'backend://v2/nba/history/seed/2023-24',
      'used_fallback': false,
    });

    expect(snapshot.isHistorical, isTrue);
    expect(snapshot.supportedSeason, '2023-24');
    expect(snapshot.datasetStatus, 'historical-canonical');
    expect(snapshot.playByPlayEvents, 250000);
    expect(snapshot.playerGameLogsTop.single['points'], 32);

    const engine = NbaStatsWorkstationEngine();
    final rows = engine.buildRows(snapshot, basis: NbaStatsBasis.perGame);
    expect(rows, hasLength(1));
    final player = rows.single;
    expect(player.playerId, 'p_star');
    expect(player.player, 'Example Star');
    expect(player.team, 'AAA');
    expect(player.position, 'PG');
    expect(player.value('pts'), closeTo(1900 / 75, .0001));
    expect(player.value('ast'), closeTo(620 / 75, .0001));
    expect(player.value('reb'), closeTo(6, .0001));
    expect(player.value('bpm'), closeTo(6.7, .0001));
  });
}
