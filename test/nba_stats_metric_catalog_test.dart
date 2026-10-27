import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';

void main() {
  test('stats workstation exposes the required professional stat families', () {
    final ids = nbaTerminalStatFamilies.map((family) => family.id).toSet();
    expect(ids, containsAll(<String>{
      'basic',
      'defense_hustle',
      'hustle_detail',
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

  test('expanded stats expose requested component columns', () {
    expect(nbaTerminalMetricByKey['two_pct']?.children, ['two_pm', 'two_pa']);
    expect(nbaTerminalMetricByKey['ws']?.children, ['ows', 'dws']);
    expect(nbaTerminalMetricByKey['bpm']?.children, ['obpm', 'dbpm']);
    expect(nbaTerminalMetricByKey['rim_dfg_pct']?.children, ['rim_dfgm', 'rim_dfga']);
    expect(nbaTerminalMetricByKey['three_dfg_pct']?.children, ['three_dfgm', 'three_dfga']);
    expect(nbaTerminalMetricByKey['box_outs_pg']?.children, ['box_out_pct']);
    expect(nbaTerminalMetricByKey['clutch_fg_pct']?.children, ['clutch_fgm', 'clutch_fga']);
    expect(
      nbaTerminalMetricByKey['clutch_three_pct']?.children,
      ['clutch_three_pm', 'clutch_three_pa'],
    );
    expect(nbaTerminalMetricByKey['clutch_ft_pct']?.children, ['clutch_ftm', 'clutch_fta']);
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

  test('Hustle Breakdown exposes every NBA.com tracking split', () {
    final family = nbaTerminalFamily('hustle_detail');
    expect(
      nbaVisibleMetricKeys(family, {'contested_shots_pg'}),
      containsAllInOrder([
        'contested_shots_pg', 'contested_twos_pg', 'contested_threes_pg',
      ]),
    );
    expect(
      nbaVisibleMetricKeys(family, {'loose_balls_recovered_pg'}),
      containsAllInOrder([
        'loose_balls_recovered_pg', 'off_loose_balls_recovered_pg',
        'def_loose_balls_recovered_pg', 'loose_ball_off_pct',
        'loose_ball_def_pct',
      ]),
    );
    expect(
      nbaVisibleMetricKeys(family, {'box_outs_pg'}),
      containsAllInOrder([
        'box_outs_pg', 'off_box_outs_pg', 'def_box_outs_pg',
        'box_out_team_rebounds_pg', 'box_out_player_rebounds_pg',
        'off_box_out_pct', 'def_box_out_pct',
        'box_out_team_reb_pct', 'box_out_pct',
      ]),
    );
    expect(
      nbaTerminalFamily('physical').metrics,
      containsAll(['age', 'height', 'weight', 'draft_year', 'draft_round', 'draft_number']),
    );
  });

  test('source-backed bio and hustle fields retain their native definitions', () {
    const resolver = NbaTerminalMetricResolver();
    const row = NbaStatsRow(
      playerId: 'nba_1',
      player: 'Fixture',
      team: 'FIX',
      position: 'F',
      values: <String, double?>{'age': 26},
      percentiles: <String, double>{},
      raw: <String, dynamic>{
        'height_inches': 80,
        'weight_lbs': 225,
        'draft_year': 2021,
        'draft_number': 14,
        'hustle_gp': 10,
        'contested_twos_pg': 4.0,
        'contested_threes_pg': 2.0,
        'screen_assist_points_pg': 2.1,
        'box_out_team_reb_pct': .667,
        'box_out_pct': .433,
      },
      possessionsEstimated: false,
    );
    expect(resolver.value(row, 'age'), 26);
    expect(resolver.value(row, 'height'), 80);
    expect(resolver.value(row, 'weight'), 225);
    expect(resolver.value(row, 'draft_year'), 2021);
    expect(resolver.value(row, 'draft_number'), 14);
    expect(resolver.value(row, 'contested_twos_pg'), 4);
    expect(resolver.value(row, 'screen_assist_points_pg'), 2.1);
    expect(resolver.value(row, 'box_out_team_reb_pct'), closeTo(.667, .0001));
    expect(resolver.value(row, 'box_out_pct'), closeTo(.433, .0001));
    expect(resolver.value(row, 'off_box_out_pct'), isNull);
    expect(resolver.format(row, 'box_out_team_reb_pct'), '66.7%');
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
