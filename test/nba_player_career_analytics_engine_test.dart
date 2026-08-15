import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

NbaPlayerCareerSnapshot _career() => const NbaPlayerCareerEngine().build(
      {
        'profile': {
          'player_key': 'p1',
          'canonical_name': 'Example Star',
        },
        'seasons': [
          {
            'season_id': '2018-19',
            'team_key': 'alpha',
            'games': 80,
            'pts': 1600,
            'reb': 400,
            'ast': 480,
            'ts_pct': 0.60,
            'bpm': 3.0,
          },
          {
            'season_id': '2019-20',
            'team_key': 'alpha',
            'games': 70,
            'pts': 1540,
            'reb': 350,
            'ast': 420,
            'ts_pct': 0.62,
            'bpm': 4.0,
          },
          {
            'season_id': '2020-21',
            'team_key': 'alpha',
            'games': 60,
            'pts': 1500,
            'reb': 360,
            'ast': 420,
            'ts_pct': 0.64,
            'bpm': 5.0,
          },
          {
            'season_id': '2021-22',
            'team_key': 'alpha',
            'games': 50,
            'reb': 300,
            'ast': 350,
            'ts_pct': 0.63,
          },
        ],
      },
      playerKey: 'p1',
      teamDossiers: const {
        'alpha': {
          'profile': {'canonical_name': 'Alpha'},
        },
      },
    );

void main() {
  test('builds observed career PPG trend and complete rolling windows', () {
    final result = const NbaPlayerCareerAnalyticsEngine().build(
      _career(),
      metric: NbaPlayerCareerMetric.pointsPerGame,
      rollingWindow: 3,
    );

    expect(result.points.map((point) => point.seasonId), [
      '2018-19',
      '2019-20',
      '2020-21',
      '2021-22',
    ]);
    expect(result.points[0].value, 20);
    expect(result.points[1].value, 22);
    expect(result.points[2].value, 25);
    expect(result.points[2].rollingValue, closeTo(22.333333, 0.00001));
    expect(result.points[3].value, isNull);
    expect(result.points[3].rollingValue, isNull);
  });

  test('missing values remain gaps and distribution counts them explicitly', () {
    final result = const NbaPlayerCareerAnalyticsEngine().build(
      _career(),
      metric: NbaPlayerCareerMetric.pointsPerGame,
    );

    expect(result.distribution.observed, 3);
    expect(result.distribution.missing, 1);
    expect(result.distribution.mean, closeTo(22.333333, 0.00001));
    expect(result.distribution.median, 22);
    expect(result.distribution.minimum, 20);
    expect(result.distribution.maximum, 25);
    expect(result.peakSeason?.seasonId, '2020-21');
    expect(result.lowSeason?.seasonId, '2018-19');
  });

  test('percentage metrics stay source-backed and render in percentage points', () {
    final result = const NbaPlayerCareerAnalyticsEngine().build(
      _career(),
      metric: NbaPlayerCareerMetric.trueShootingPct,
    );

    expect(result.points.first.value, 60);
    expect(result.points[2].value, 64);
    expect(result.distribution.maximum, 64);
  });

  test('advanced metrics are not backfilled when the season omits them', () {
    final result = const NbaPlayerCareerAnalyticsEngine().build(
      _career(),
      metric: NbaPlayerCareerMetric.boxPlusMinus,
    );

    expect(result.points.last.value, isNull);
    expect(result.distribution.observed, 3);
    expect(result.distribution.missing, 1);
  });

  test('empty career produces explicit unavailable analytics', () {
    final career = const NbaPlayerCareerEngine().build(
      {
        'profile': {
          'player_key': 'p1',
          'canonical_name': 'Example Star',
        },
      },
      playerKey: 'p1',
    );
    final result = const NbaPlayerCareerAnalyticsEngine().build(career);

    expect(result.available, isFalse);
    expect(result.points, isEmpty);
    expect(result.distribution.mean, isNull);
  });
}
