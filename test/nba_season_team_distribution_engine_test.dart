import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_team_distribution_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('derives ordered team differential distribution from scored games', () {
    final result = const NbaSeasonTeamDistributionEngine().build(
      _seed(),
      seasonId: '2025-26',
    );

    expect(result.teamCount, 3);
    expect(result.observations.map((row) => row.teamId), ['CCC', 'BBB', 'AAA']);
    expect(result.minimum, closeTo(-4, 0.001));
    expect(result.maximum, closeTo(7.5, 0.001));
    expect(result.mean, closeTo(0, 0.001));
    expect(result.median, closeTo(-3.5, 0.001));
  });

  test('supports points-for and win-percentage views over same season scope', () {
    final pf = const NbaSeasonTeamDistributionEngine().build(
      _seed(),
      seasonId: '2025-26',
      metric: NbaSeasonTeamDistributionMetric.pointsFor,
    );
    final winPct = const NbaSeasonTeamDistributionEngine().build(
      _seed(),
      seasonId: '2025-26',
      metric: NbaSeasonTeamDistributionMetric.winPct,
    );

    expect(pf.observations.last.teamId, 'AAA');
    expect(pf.observations.last.value, 105);
    expect(winPct.observations.last.teamId, 'AAA');
    expect(winPct.observations.last.value, 1);
  });

  test('scheduled games never enter team distribution statistics', () {
    final result = const NbaSeasonTeamDistributionEngine().build(
      _seed(),
      seasonId: '2025-26',
    );

    final gamma = result.observations.firstWhere((row) => row.teamId == 'CCC');
    expect(gamma.games, 2);
  });

  test('playoff distributions remain separate from regular season', () {
    final result = const NbaSeasonTeamDistributionEngine().build(
      _seed(includePlayoff: true),
      seasonId: '2025-26',
      seasonType: 'Playoffs',
    );

    expect(result.teamCount, 2);
    expect(result.observations.last.teamId, 'AAA');
    expect(result.observations.last.value, 7);
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
      'season_type': 'Regular Season', 'home_team_id': 'CCC', 'away_team_id': 'AAA',
      'home_score': 95, 'away_score': 100, 'status': 'Final',
    },
    {
      'game_id': 'g3', 'season_id': '2025-26', 'game_date': '2026-01-08',
      'season_type': 'Regular Season', 'home_team_id': 'BBB', 'away_team_id': 'CCC',
      'home_score': 102, 'away_score': 99, 'status': 'Final',
    },
    {
      'game_id': 'g4', 'season_id': '2025-26', 'game_date': '2026-02-01',
      'season_type': 'Regular Season', 'home_team_id': 'AAA', 'away_team_id': 'CCC',
      'status': 'Scheduled',
    },
  ];
  if (includePlayoff) {
    games.add({
      'game_id': 'p1', 'season_id': '2025-26', 'game_date': '2026-04-20',
      'season_type': 'Playoffs', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 107, 'away_score': 100, 'status': 'Final',
    });
  }
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': [
      {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
      {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      {'team_id': 'CCC', 'team_name': 'Gamma', 'abbreviation': 'CCC'},
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
    'asset_path': 'test://season-team-distribution',
    'used_fallback': false,
  });
}
