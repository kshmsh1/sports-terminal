import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  const engine = NbaStatsWorkstationEngine();

  NbaTerminalSeedSnapshot snapshot() => NbaTerminalSeedSnapshot(
    manifest: const {},
    teams: const [],
    players: const [
      {'player_id': 'alpha', 'position': 'PG'},
      {'player_id': 'beta', 'position': 'C'},
    ],
    games: const [],
    teamRecords: const [],
    teamGameLogs: const [],
    playerSeasonTotals: const [
      {
        'player_id': 'alpha',
        'player_label': 'Alpha Guard',
        'team_ids': 'AAA',
        'age': 25,
        'games': 10,
        'minutes': 300,
        'points': 200,
        'assists': 80,
        'rebounds': 40,
        'offensive_rebounds': 5,
        'defensive_rebounds': 35,
        'steals': 20,
        'blocks': 2,
        'turnovers': 30,
        'personal_fouls': 18,
        'field_goals_made': 70,
        'field_goal_attempts': 140,
        'three_pointers_made': 20,
        'three_point_attempts': 50,
        'free_throws_made': 40,
        'free_throw_attempts': 50,
        'plus_minus': 50,
        'avg_bpm': 5.5,
      },
      {
        'player_id': 'beta',
        'player_label': 'Beta Center',
        'team_ids': 'BBB',
        'age': 29,
        'games': 10,
        'minutes': 250,
        'points': 120,
        'assists': 20,
        'rebounds': 100,
        'offensive_rebounds': 30,
        'defensive_rebounds': 70,
        'steals': 5,
        'blocks': 25,
        'turnovers': 20,
        'personal_fouls': 28,
        'field_goals_made': 50,
        'field_goal_attempts': 90,
        'three_pointers_made': 0,
        'three_point_attempts': 0,
        'free_throws_made': 20,
        'free_throw_attempts': 40,
        'plus_minus': 10,
        'avg_bpm': 2.0,
      },
    ],
    playerLeaders: const {},
    playerGameHighs: const {},
    playerGameLogsTop: const [],
    searchIndex: const [],
    dataDictionary: const {},
    validationReport: const {'status': 'pass'},
    assetManifest: const {},
  );

  test('builds per-game counting and derived efficiency fields', () {
    final rows = engine.buildRows(snapshot());
    final alpha = rows.firstWhere((row) => row.playerId == 'alpha');

    expect(alpha.position, 'PG');
    expect(alpha.value('pts'), 20);
    expect(alpha.value('ast'), 8);
    expect(alpha.value('fg_pct'), closeTo(.5, .0001));
    expect(alpha.value('three_pct'), closeTo(.4, .0001));
    expect(alpha.value('ft_pct'), closeTo(.8, .0001));
    expect(alpha.value('ts_pct'), closeTo(200 / (2 * (140 + .44 * 50)), .0001));
    expect(alpha.value('efg_pct'), closeTo((70 + .5 * 20) / 140, .0001));
    expect(alpha.possessionsEstimated, isTrue);
  });

  test('supports totals, per-36, per-48 and possession bases', () {
    final total = engine
        .buildRows(snapshot(), basis: NbaStatsBasis.totals)
        .firstWhere((row) => row.playerId == 'alpha');
    final per36 = engine
        .buildRows(snapshot(), basis: NbaStatsBasis.per36)
        .firstWhere((row) => row.playerId == 'alpha');
    final per48 = engine
        .buildRows(snapshot(), basis: NbaStatsBasis.per48)
        .firstWhere((row) => row.playerId == 'alpha');
    final per75 = engine
        .buildRows(snapshot(), basis: NbaStatsBasis.per75)
        .firstWhere((row) => row.playerId == 'alpha');
    final per100 = engine
        .buildRows(snapshot(), basis: NbaStatsBasis.per100)
        .firstWhere((row) => row.playerId == 'alpha');

    expect(total.value('pts'), 200);
    expect(per36.value('pts'), closeTo(24, .0001));
    expect(per48.value('pts'), closeTo(32, .0001));
    expect(per100.value('pts')! > per75.value('pts')!, isTrue);
  });

  test('filters team, position, favorites and numeric metric thresholds', () {
    final rows = engine.buildRows(snapshot());
    final filtered = engine.filterRows(
      rows,
      const NbaStatsFilters(
        team: 'AAA',
        position: 'PG',
        minGames: 5,
        minMinutes: 20,
        favoriteOnly: true,
        metricKey: 'pts',
        metricMinimum: 15,
      ),
      favorites: const {'alpha'},
    );

    expect(filtered, hasLength(1));
    expect(filtered.single.player, 'Alpha Guard');
  });

  test('computes direction-aware percentile ranks', () {
    final rows = engine.buildRows(snapshot());
    final alpha = rows.firstWhere((row) => row.playerId == 'alpha');
    final beta = rows.firstWhere((row) => row.playerId == 'beta');

    expect(alpha.percentiles['pts'], 100);
    expect(beta.percentiles['pts'], 0);
    expect(alpha.percentiles['tov'], 0);
    expect(beta.percentiles['tov'], 100);
  });
}
