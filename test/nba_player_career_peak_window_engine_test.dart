import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';
import 'package:sports_terminal/services/nba_player_career_peak_window_engine.dart';

void main() {
  test('finds each player best complete contiguous peak window', () {
    final result = const NbaPlayerCareerPeakWindowEngine().build(
      left: _career('left', [10, 20, 30, 5]),
      right: _career('right', [8, 18, 22, 24]),
      window: 2,
    );

    expect(result.left!.seasonRangeLabel, '2001-02 → 2002-03');
    expect(result.left!.mean, 25);
    expect(result.right!.seasonRangeLabel, '2002-03 → 2003-04');
    expect(result.right!.mean, 23);
    expect(result.delta, 2);
  });

  test('missing metric row invalidates only windows containing that gap', () {
    final result = const NbaPlayerCareerPeakWindowEngine().build(
      left: _career('left', [10, null, 30, 40]),
      right: _career('right', [8, 9, 10, 11]),
      window: 2,
    );

    expect(result.left!.seasonRangeLabel, '2002-03 → 2003-04');
    expect(result.left!.mean, 35);
  });

  test('insufficient complete history returns unavailable instead of shrinking window', () {
    final result = const NbaPlayerCareerPeakWindowEngine().build(
      left: _career('left', [10, 20]),
      right: _career('right', [8, 9, 10]),
      window: 3,
    );

    expect(result.left, isNull);
    expect(result.right, isNotNull);
    expect(result.delta, isNull);
  });

  test('percentage metrics remain percentage-point observations', () {
    final left = _careerWithTs('left', [.55, .60, .65]);
    final right = _careerWithTs('right', [.50, .55, .60]);
    final result = const NbaPlayerCareerPeakWindowEngine().build(
      left: left,
      right: right,
      metric: NbaPlayerCareerMetric.trueShootingPct,
      window: 2,
    );

    expect(result.left!.mean, 62.5);
    expect(result.right!.mean, 57.5);
    expect(result.delta, 5);
  });
}

NbaPlayerCareerSnapshot _career(String key, List<double?> ppg) => _snapshot(
      key,
      [
        for (var i = 0; i < ppg.length; i++)
          _season('200$i-0${i + 1}', ppg: ppg[i]),
      ],
    );

NbaPlayerCareerSnapshot _careerWithTs(String key, List<double> values) => _snapshot(
      key,
      [
        for (var i = 0; i < values.length; i++)
          _season('200$i-0${i + 1}', ppg: 10, ts: values[i]),
      ],
    );

NbaPlayerCareerSnapshot _snapshot(String key, List<NbaPlayerCareerSeason> seasons) =>
    NbaPlayerCareerSnapshot(
      playerKey: key,
      playerName: key.toUpperCase(),
      primaryPosition: '',
      activeFrom: '',
      activeTo: '',
      nbaId: '',
      brefId: '',
      identityConfidence: null,
      sourceCount: null,
      seasons: seasons,
      tenures: const [],
      missingTeamDossierKeys: const [],
      multiTeamAggregateSeasons: const [],
      declaredFirstSeason: seasons.first.seasonId,
      declaredLastSeason: seasons.last.seasonId,
      declaredSeasonRows: seasons.length,
      materialConflictCount: 0,
    );

NbaPlayerCareerSeason _season(
  String season, {
  required double? ppg,
  double ts = .6,
}) =>
    NbaPlayerCareerSeason(
      seasonId: season,
      seasonType: 'regular',
      leagueId: 'NBA',
      teamKey: 'team',
      teamName: 'Team',
      teamAbbreviation: 'TM',
      franchiseKey: 'franchise',
      franchiseName: 'Franchise',
      games: 10,
      gamesStarted: 10,
      minutes: 300,
      points: ppg == null ? null : ppg * 10,
      rebounds: 50,
      assists: 40,
      steals: 10,
      blocks: 5,
      turnovers: 20,
      trueShootingPct: ts,
      playerEfficiencyRating: 20,
      winShares: 5,
      boxPlusMinus: 2,
      valueOverReplacement: 1,
      syntheticAggregate: false,
      source: 'test',
    );
