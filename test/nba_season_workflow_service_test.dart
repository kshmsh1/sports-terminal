import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_workflow_service.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('packages canonical season standings into shared RoutePayload state', () {
    final payload = const NbaSeasonWorkflowService().package(
      _seed(),
      seasonId: '2025-26',
      targetRoute: 'Workspace',
    );

    expect(payload.sourceObjectType, 'NBA Season');
    expect(payload.sourceObjectId, '2025-26');
    expect(payload.targetRoute, 'Workspace');
    expect(payload.readinessState, 'Ready');
    expect(payload.rowCount, 2);
    expect(payload.rows.first['team_id'], 'AAA');
    expect(payload.rows.first['wins'], 1);
    expect(payload.metadata['gameCount'], 2);
    expect(payload.metadata['completedGames'], 1);
    expect(payload.metadata['scheduledGames'], 1);
  });

  test('season type remains an explicit workflow filter', () {
    final payload = const NbaSeasonWorkflowService().package(
      _seed(includePlayoff: true),
      seasonId: '2025-26',
      seasonType: 'Playoffs',
      targetRoute: 'Python Lab',
    );

    expect(payload.targetRoute, 'Python Lab');
    expect(payload.filterSummary, contains('season_type=Playoffs'));
    expect(payload.metadata['playoffGames'], 1);
    expect(payload.rows.first['season_type'], 'Playoffs');
  });

  test('empty season scope is partial instead of fabricating standings', () {
    final payload = const NbaSeasonWorkflowService().package(
      _seed(),
      seasonId: '2099-00',
      targetRoute: 'Source Audit',
    );

    expect(payload.readinessState, 'Partial');
    expect(payload.rows, isEmpty);
    expect(payload.metadata['gameCount'], 0);
    expect(payload.metadata['teamCount'], 0);
  });
}

NbaTerminalSeedSnapshot _seed({bool includePlayoff = false}) {
  final games = <Map<String, dynamic>>[
    {
      'game_id': 'g1', 'season_id': '2025-26', 'game_date': '2026-01-01',
      'season_type': 'Regular Season', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 110, 'away_score': 100, 'status': 'Final',
    },
    {
      'game_id': 'g2', 'season_id': '2025-26', 'game_date': '2026-01-05',
      'season_type': 'Regular Season', 'home_team_id': 'BBB', 'away_team_id': 'AAA',
      'status': 'Scheduled',
    },
  ];
  if (includePlayoff) {
    games.add({
      'game_id': 'p1', 'season_id': '2025-26', 'game_date': '2026-04-20',
      'season_type': 'Playoffs', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 108, 'away_score': 101, 'status': 'Final',
    });
  }
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': [
      {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
      {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
    ],
    'players': const [],
    'games': games,
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
    'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
    'asset_path': 'test://season-workflow',
    'used_fallback': false,
  });
}
