import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';

void main() {
  test('stats workstation exposes the required professional stat families', () {
    final ids = nbaTerminalStatFamilies.map((family) => family.id).toSet();
    expect(ids, containsAll(<String>{
      'basic',
      'defense_hustle',
      'playmaking',
      'rebounding',
      'efficiency',
      'impact',
      'aggregate',
      'movement',
      'clutch',
      'shot_profile',
      'play_type',
      'gravity_creation',
      'physical',
      'discipline',
      'availability',
    }));
  });

  test('every family metric resolves to a glossary definition', () {
    final keys = nbaTerminalMetrics.map((metric) => metric.key).toList();
    expect(keys.toSet().length, keys.length, reason: 'Metric keys must be unique.');
    for (final family in nbaTerminalStatFamilies) {
      for (final key in family.metrics) {
        expect(
          nbaTerminalMetricByKey.containsKey(key),
          isTrue,
          reason: '${family.label} references undefined metric $key',
        );
      }
      for (final children in family.expansionOverrides.values) {
        for (final key in children) {
          expect(
            nbaTerminalMetricByKey.containsKey(key),
            isTrue,
            reason: '${family.label} expansion references undefined metric $key',
          );
        }
      }
    }
  });

  test('basic stat parents expand into requested component columns', () {
    final basic = nbaTerminalFamily('basic');
    expect(
      nbaVisibleMetricKeys(basic, {'rpg'}),
      containsAllInOrder(['rpg', 'oreb', 'dreb']),
    );
    expect(
      nbaVisibleMetricKeys(basic, {'fg_pct'}),
      containsAllInOrder(['fg_pct', 'fgm', 'fga']),
    );
    expect(
      nbaVisibleMetricKeys(basic, {'three_pct'}),
      containsAllInOrder(['three_pct', 'three_pm', 'three_pa']),
    );
    expect(
      nbaVisibleMetricKeys(basic, {'ft_pct'}),
      containsAllInOrder(['ft_pct', 'ftm', 'fta']),
    );
  });

  test('rebounding RPG uses family-specific contest and rate expansion', () {
    final rebounding = nbaTerminalFamily('rebounding');
    expect(
      nbaVisibleMetricKeys(rebounding, {'rpg'}),
      containsAllInOrder(['rpg', 'contested_rpg', 'uncontested_rpg', 'trb_pct']),
    );
    expect(
      nbaVisibleMetricKeys(rebounding, {'oreb'}),
      containsAllInOrder(['oreb', 'contested_orb_pg', 'uncontested_orb_pg', 'orb_pct']),
    );
    expect(
      nbaVisibleMetricKeys(rebounding, {'dreb'}),
      containsAllInOrder(['dreb', 'contested_dreb_pg', 'uncontested_dreb_pg', 'drb_pct']),
    );
  });

  test('advanced catalog includes requested source-gated models and tracking', () {
    expect(
      nbaTerminalMetricByKey.keys,
      containsAll(<String>{
        'epm',
        'lebron',
        'darko',
        'rapm',
        'la_rapm',
        'warv',
        'offensive_gravity',
        'drive_gravity',
        'blitz_trap_escape_rate',
        'panic_turnover_rate',
        'anticipation',
        'availability_pct',
        'games_missed_injury',
      }),
    );
  });

  test('resolver uses engine metrics, source aliases and transparent derivations', () {
    const resolver = NbaTerminalMetricResolver();
    const row = NbaStatsRow(
      playerId: '1',
      player: 'Example Player',
      team: 'EX',
      position: 'G',
      values: <String, double?>{
        'pts': 20,
        'fga': 10,
        'reb': 8,
        'oreb': 2,
        'dreb': 6,
        'fg_pct': .5,
      },
      percentiles: <String, double>{},
      raw: <String, dynamic>{
        'OFFENSIVE_RATING': 118.4,
        'defensive_rating': 111.2,
        'rim_fg_pct': 72.5,
        'contested_orb_pg': 1.1,
        'contested_dreb_pg': 3.4,
      },
      possessionsEstimated: false,
    );

    expect(resolver.value(row, 'ppg'), 20);
    expect(resolver.value(row, 'rim_fg_pct'), .725);
    expect(resolver.value(row, 'net_rating'), closeTo(7.2, .0001));
    expect(resolver.value(row, 'pps'), 2.0);
    expect(resolver.value(row, 'contested_rpg'), 4.5);
    expect(resolver.format(row, 'rim_fg_pct'), '72.5%');
  });
}
