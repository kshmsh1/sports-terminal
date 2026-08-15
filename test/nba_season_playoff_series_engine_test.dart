import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_playoff_series_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('groups canonical playoff games by observed team matchup only', () {
    final result = const NbaSeasonPlayoffSeriesEngine().build(
      _seed(),
      seasonId: '2025-26',
    );

    expect(result.observedMatchups, 2);
    final aaaBbb = result.series.firstWhere(
      (series) => series.matchupLabel == 'AAA vs BBB',
    );
    expect(aaaBbb.completedGames, 2);
    expect(aaaBbb.teamAWins, 2);
    expect(aaaBbb.teamBWins, 0);
    expect(aaaBbb.leaderLabel, 'AAA leads observed games 2-0');
  });

  test('scheduled playoff games remain visible but never alter observed wins', () {
    final result = const NbaSeasonPlayoffSeriesEngine().build(
      _seed(),
      seasonId: '2025-26',
    );
    final aaaCcc = result.series.firstWhere(
      (series) => series.matchupLabel == 'AAA vs CCC',
    );

    expect(aaaCcc.completedGames, 1);
    expect(aaaCcc.scheduledGames, 1);
    expect(aaaCcc.observedRecordLabel, '0-1');
    expect(aaaCcc.leaderTeamId, 'CCC');
  });

  test('cross-season and regular-season games do not leak into playoff context', () {
    final result = const NbaSeasonPlayoffSeriesEngine().build(
      _seed(),
      seasonId: '2025-26',
    );

    expect(result.playoffGameCount, 4);
    expect(
      result.series.expand((series) => series.games).map((game) => game.gameId),
      isNot(contains('regular1')),
    );
    expect(
      result.series.expand((series) => series.games).map((game) => game.gameId),
      isNot(contains('old1')),
    );
  });

  test('no playoff rows produces an explicit unavailable result', () {
    final result = const NbaSeasonPlayoffSeriesEngine().build(
      _seed(includePlayoffs: false),
      seasonId: '2025-26',
    );

    expect(result.available, isFalse);
    expect(result.series, isEmpty);
    expect(
      result.methodologyLabel,
      contains('rounds and advancement are not inferred'),
    );
  });
}

NbaTerminalSeedSnapshot _seed({bool includePlayoffs = true}) {
  final games = <Map<String, dynamic>>[
    {
      'game_id': 'regular1', 'season_id': '2025-26', 'game_date': '2026-01-01',
      'season_type': 'Regular Season', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 120, 'away_score': 80, 'status': 'Final',
    },
    {
      'game_id': 'old1', 'season_id': '2024-25', 'game_date': '2025-04-20',
      'season_type': 'Playoffs', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 90, 'away_score': 100, 'status': 'Final',
    },
  ];
  if (includePlayoffs) {
    games.addAll([
      {
        'game_id': 'p1', 'season_id': '2025-26', 'game_date': '2026-04-20',
        'season_type': 'Playoffs', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
        'home_score': 105, 'away_score': 100, 'status': 'Final',
      },
      {
        'game_id': 'p2', 'season_id': '2025-26', 'game_date': '2026-04-22',
        'season_type': 'Playoffs', 'home_team_id': 'BBB', 'away_team_id': 'AAA',
        'home_score': 99, 'away_score': 102, 'status': 'Final',
      },
      {
        'game_id': 'p3', 'season_id': '2025-26', 'game_date': '2026-05-01',
        'season_type': 'Playoffs', 'home_team_id': 'CCC', 'away_team_id': 'AAA',
        'home_score': 110, 'away_score': 104, 'status': 'Final',
      },
      {
        'game_id': 'p4', 'season_id': '2025-26', 'game_date': '2026-05-03',
        'season_type': 'Playoffs', 'home_team_id': 'AAA', 'away_team_id': 'CCC',
        'status': 'Scheduled',
      },
    ]);
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
    'asset_path': 'test://season-playoffs',
    'used_fallback': false,
  });
}
