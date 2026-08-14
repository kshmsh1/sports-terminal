import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_benchmark_engine.dart';
import 'package:sports_terminal/services/nba_season_team_distribution_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('ranks differential from explicit scored-game observations', () {
    final result = const NbaSeasonBenchmarkEngine().build(
      _seed(),
      seasonId: '2025-26',
      metric: NbaSeasonTeamDistributionMetric.differential,
    );

    expect(result.teamCount, 4);
    expect(result.rows.first.teamId, 'AAA');
    expect(result.rows.first.rank, 1);
    expect(result.rows.first.percentile, 100);
    expect(result.rows.last.percentile, 0);
  });

  test('points against correctly treats lower values as better', () {
    final result = const NbaSeasonBenchmarkEngine().build(
      _seed(),
      seasonId: '2025-26',
      metric: NbaSeasonTeamDistributionMetric.pointsAgainst,
    );

    expect(result.higherIsBetter, isFalse);
    final best = result.rows.first;
    expect(best.value, result.rows.map((row) => row.value).reduce((a, b) => a < b ? a : b));
    expect(best.percentile, 100);
  });

  test('tied observations share rank and percentile without arbitrary separation', () {
    final result = const NbaSeasonBenchmarkEngine().build(
      _tieSeed(),
      seasonId: '2025-26',
      metric: NbaSeasonTeamDistributionMetric.winPct,
    );
    final alpha = result.team('AAA')!;
    final gamma = result.team('CCC')!;

    expect(alpha.value, gamma.value);
    expect(alpha.rank, gamma.rank);
    expect(alpha.percentile, gamma.percentile);
    expect(alpha.tiedTeams, 2);
    expect(alpha.rankLabel, startsWith('T'));
  });

  test('scheduled rows cannot change sample size or benchmark values', () {
    final result = const NbaSeasonBenchmarkEngine().build(
      _seed(includeScheduled: true),
      seasonId: '2025-26',
    );

    expect(result.teamCount, 4);
    expect(result.rows.every((row) => row.games > 0), isTrue);
  });

  test('team lookup is canonical-id case insensitive and missing stays absent', () {
    final result = const NbaSeasonBenchmarkEngine().build(
      _seed(),
      seasonId: '2025-26',
    );

    expect(result.team('aaa')?.teamId, 'AAA');
    expect(result.team('NOT-A-TEAM'), isNull);
  });
}

NbaTerminalSeedSnapshot _seed({bool includeScheduled = false}) {
  final games = <Map<String, dynamic>>[
    _game('g1', 'AAA', 'BBB', 120, 100, '2026-01-01'),
    _game('g2', 'CCC', 'DDD', 105, 100, '2026-01-02'),
    _game('g3', 'AAA', 'CCC', 110, 100, '2026-01-03'),
    _game('g4', 'BBB', 'DDD', 102, 101, '2026-01-04'),
  ];
  if (includeScheduled) {
    games.add({
      'game_id': 'g5',
      'season_id': '2025-26',
      'game_date': '2026-02-01',
      'season_type': 'Regular Season',
      'home_team_id': 'DDD',
      'away_team_id': 'AAA',
      'status': 'Scheduled',
    });
  }
  return _snapshot(games);
}

NbaTerminalSeedSnapshot _tieSeed() => _snapshot([
      _game('g1', 'AAA', 'BBB', 100, 90, '2026-01-01'),
      _game('g2', 'CCC', 'DDD', 100, 90, '2026-01-02'),
    ]);

Map<String, dynamic> _game(
  String id,
  String home,
  String away,
  int homeScore,
  int awayScore,
  String date,
) =>
    {
      'game_id': id,
      'season_id': '2025-26',
      'game_date': date,
      'season_type': 'Regular Season',
      'home_team_id': home,
      'away_team_id': away,
      'home_score': homeScore,
      'away_score': awayScore,
      'status': 'Final',
    };

NbaTerminalSeedSnapshot _snapshot(List<Map<String, dynamic>> games) =>
    NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': const [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
        {'team_id': 'CCC', 'team_name': 'Gamma', 'abbreviation': 'CCC'},
        {'team_id': 'DDD', 'team_name': 'Delta', 'abbreviation': 'DDD'},
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
      'asset_path': 'test://benchmark',
      'used_fallback': false,
    });
