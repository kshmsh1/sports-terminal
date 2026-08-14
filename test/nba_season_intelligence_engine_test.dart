import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('isolates one canonical season and derives scored-game standings', () {
    final result = const NbaSeasonIntelligenceEngine().build(
      _seed(),
      seasonId: '2025-26',
    );

    expect(result.gameCount, 4);
    expect(result.completedGames, 3);
    expect(result.scheduledGames, 1);
    expect(result.teamCount, 3);
    expect(result.games.map((game) => game.gameId), ['g1', 'g2', 'g3', 'g4']);
    expect(result.standings.first.teamId, 'AAA');
    expect(result.standings.first.recordLabel, '2-0');
    expect(result.standings.first.averageDifferential, 7.5);
  });

  test('scheduled games never alter derived records', () {
    final result = const NbaSeasonIntelligenceEngine().build(
      _seed(),
      seasonId: '2025-26',
    );
    final gamma = result.standings.firstWhere((row) => row.teamId == 'CCC');

    expect(gamma.games, 1);
    expect(gamma.recordLabel, '0-1');
    expect(result.games.last.gameId, 'g4');
    expect(result.games.last.hasScore, isFalse);
  });

  test('season id prevents cross-season game leakage', () {
    final current = const NbaSeasonIntelligenceEngine().build(
      _seed(),
      seasonId: '2025-26',
    );
    final prior = const NbaSeasonIntelligenceEngine().build(
      _seed(),
      seasonId: '2024-25',
    );

    expect(current.games.map((game) => game.gameId), isNot(contains('old1')));
    expect(prior.games.map((game) => game.gameId), ['old1']);
    expect(prior.completedGames, 1);
  });

  test('regular season and playoffs can be selected independently', () {
    final regular = const NbaSeasonIntelligenceEngine().build(
      _seed(includePlayoff: true),
      seasonId: '2025-26',
      seasonType: 'Regular Season',
    );
    final playoffs = const NbaSeasonIntelligenceEngine().build(
      _seed(includePlayoff: true),
      seasonId: '2025-26',
      seasonType: 'Playoffs',
    );

    expect(regular.games.map((game) => game.gameId), ['g1', 'g2', 'g3', 'g4']);
    expect(playoffs.games.map((game) => game.gameId), ['gp1']);
    expect(playoffs.standings.first.recordLabel, '1-0');
  });

  test('date range reflects only dated games in the selected season scope', () {
    final result = const NbaSeasonIntelligenceEngine().build(
      _seed(),
      seasonId: '2025-26',
    );

    expect(result.dateRangeLabel, '2026-01-01 → 2026-02-01');
  });
}

NbaTerminalSeedSnapshot _seed({bool includePlayoff = false}) {
  final games = <Map<String, dynamic>>[
    {
      'game_id': 'old1', 'season_id': '2024-25', 'game_date': '2025-03-01',
      'season_type': 'Regular Season', 'home_team_id': 'BBB', 'away_team_id': 'AAA',
      'home_score': 90, 'away_score': 80, 'status': 'Final',
    },
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
      'game_id': 'gp1', 'season_id': '2025-26', 'game_date': '2026-04-20',
      'season_type': 'Playoffs', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 115, 'away_score': 108, 'status': 'Final',
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
    'asset_path': 'test://season-intelligence',
    'used_fallback': false,
  });
}
