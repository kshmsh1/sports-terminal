import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stat_display_format.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('NBA heights display in feet and inches, while other dimensions remain inches', () {
    expect(nbaFormatFeetInches(88), '7\'4"');
    expect(nbaFormatFeetInches(72), '6\'0"');
    expect(nbaFormatFeetInches(83), '6\'11"');
    expect(nbaFormatFeetInches(double.nan), '—');
    const resolver = NbaTerminalMetricResolver();
    const player = NbaStatsRow(
      playerId: 'p', player: 'Test', team: 'LAC', position: 'G',
      values: <String, double?>{}, percentiles: <String, double>{},
      raw: <String, dynamic>{'height_inches': 88, 'wingspan_inches': 92},
      possessionsEstimated: false,
    );
    expect(resolver.format(player, 'height'), '7\'4"');
    expect(resolver.format(player, 'wingspan'), '92.0 in');
  });

  test('stat headers title-case words but preserve established acronyms', () {
    expect(nbaTitleCaseStatLabel('HEIGHT'), 'Height');
    expect(nbaTitleCaseStatLabel('MAX VERT'), 'Max Vert');
    expect(nbaTitleCaseStatLabel('DRAFT YR'), 'Draft Yr');
    expect(nbaTitleCaseStatLabel('OFF BOX PG'), 'Off Box PG');
    expect(nbaTitleCaseStatLabel('PACE'), 'Pace');
    expect(nbaTitleCaseStatLabel('APG'), 'APG');
    expect(nbaTitleCaseStatLabel('FG%'), 'FG%');
    expect(nbaTitleCaseStatLabel('eFG%'), 'eFG%');
  });

  test('Harden-style 2TM rows expand into actual per-team source data', () {
    final snapshot = NbaTerminalSeedSnapshot.fromMap({
      'players': [
        {'player_id': 'nba_201935', 'player_name': 'James Harden', 'position': 'PG'},
      ],
      'player_season_totals': [
        {
          'player_id': 'nba_201935', 'player_label': 'James Harden',
          'team_ids': '2TM', 'position': 'PG', 'season_type': 'regular',
          'games': 60, 'minutes': 2100, 'points': 1200,
          'teams_played_for': ['LAC', 'CLE'],
          'team_stints': [
            {
              'player_id': 'nba_201935', 'player_label': 'James Harden',
              'team_ids': 'LAC', 'position': 'PG', 'season_type': 'regular',
              'games': 40, 'minutes': 1400, 'points': 880, 'avg_bpm': 5.5,
            },
            {
              'player_id': 'nba_201935', 'player_label': 'James Harden',
              'team_ids': 'CLE', 'position': 'PG', 'season_type': 'regular',
              'games': 20, 'minutes': 700, 'points': 320, 'avg_bpm': 1.2,
            },
          ],
        },
      ],
    });
    const engine = NbaStatsWorkstationEngine();
    final parent = engine.buildRows(snapshot).single;
    expect(parent.team, '2TM');
    expect(parent.value('pts'), 20);
    final stints = engine.teamStintRows(parent);
    expect(stints.map((row) => row.team).toList(), ['LAC', 'CLE']);
    expect(stints.map((row) => row.value('pts')).toList(), [22, 16]);
    expect(stints.map((row) => row.value('bpm')).toList(), [5.5, 1.2]);
    final totalStints = engine.teamStintRows(parent, basis: NbaStatsBasis.totals);
    expect(totalStints.map((row) => row.value('pts')).toList(), [880, 320]);
    expect(engine.teamStintRows(parent, basis: NbaStatsBasis.per36)
        .map((row) => row.value('pts')).toList(), [880 * 36 / 1400, 320 * 36 / 700]);
    // The parent is not replaced or double-counted when team children exist.
    expect(engine.buildRows(snapshot).length, 1);
  });

  test('missing or partial team splits do not create fake child rows', () {
    const engine = NbaStatsWorkstationEngine();
    const parent = NbaStatsRow(
      playerId: 'p', player: 'Trade', team: '2TM', position: 'F',
      values: <String, double?>{}, percentiles: <String, double>{},
      raw: <String, dynamic>{
        'team_stints': [
          {'player_id': 'p', 'player_label': 'Trade', 'team_ids': 'AAA',
           'games': 10, 'points': 200},
        ],
      },
      possessionsEstimated: false,
    );
    expect(engine.teamStintRows(parent), isEmpty);
  });

  test('every Advanced Stats family shares the same multi-team expansion table', () {
    final source = File('lib/screens/website_nba_advanced_stats_v4_screen.dart')
        .readAsStringSync();
    expect(source, contains('for (final entry in visibleRows)'));
    expect(source, contains('rowBackgrounds: rowBackgrounds'));
    expect(source, contains('_engine.teamStintRows(parent, basis: _basis)'));
    expect(source, contains('_expandedPlayers'));
  });
}
