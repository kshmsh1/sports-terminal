import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';
import 'package:sports_terminal/services/nba_player_career_season_type_delta_engine.dart';

void main() {
  test('reports independent observed regular and playoff means', () {
    final result = const NbaPlayerCareerSeasonTypeDeltaEngine().build(
      leftRegular: _career('left', 'regular', [20, 22]),
      leftPlayoffs: _career('left', 'playoffs', [24, 26]),
      rightRegular: _career('right', 'regular', [18, 20]),
      rightPlayoffs: _career('right', 'playoffs', [19, 21]),
    );

    expect(result.left.regularMean, 21);
    expect(result.left.playoffMean, 25);
    expect(result.left.playoffMinusRegular, 4);
    expect(result.right.playoffMinusRegular, 1);
    expect(result.deltaDifference, 3);
  });

  test('missing playoff sample remains unavailable rather than zero', () {
    final result = const NbaPlayerCareerSeasonTypeDeltaEngine().build(
      leftRegular: _career('left', 'regular', [20]),
      leftPlayoffs: _career('left', 'playoffs', [null]),
      rightRegular: _career('right', 'regular', [18]),
      rightPlayoffs: _career('right', 'playoffs', [19]),
    );

    expect(result.left.playoffObserved, 0);
    expect(result.left.playoffMean, isNull);
    expect(result.left.playoffMinusRegular, isNull);
    expect(result.deltaDifference, isNull);
  });

  test('season samples are not required to share calendar years', () {
    final leftRegular = _careerWithSeasons('left', 'regular', {'1999-00': 20, '2000-01': 22});
    final leftPlayoffs = _careerWithSeasons('left', 'playoffs', {'2005-06': 24});
    final rightRegular = _careerWithSeasons('right', 'regular', {'2020-21': 18});
    final rightPlayoffs = _careerWithSeasons('right', 'playoffs', {'2023-24': 19});
    final result = const NbaPlayerCareerSeasonTypeDeltaEngine().build(
      leftRegular: leftRegular,
      leftPlayoffs: leftPlayoffs,
      rightRegular: rightRegular,
      rightPlayoffs: rightPlayoffs,
    );

    expect(result.left.regularObserved, 2);
    expect(result.left.playoffObserved, 1);
    expect(result.right.regularObserved, 1);
    expect(result.right.playoffObserved, 1);
  });

  test('TS percent deltas remain percentage points', () {
    final result = const NbaPlayerCareerSeasonTypeDeltaEngine().build(
      leftRegular: _career('left', 'regular', [20], ts: .60),
      leftPlayoffs: _career('left', 'playoffs', [20], ts: .65),
      rightRegular: _career('right', 'regular', [20], ts: .55),
      rightPlayoffs: _career('right', 'playoffs', [20], ts: .57),
      metric: NbaPlayerCareerMetric.trueShootingPct,
    );

    expect(result.left.playoffMinusRegular, closeTo(5, 1e-9));
    expect(result.right.playoffMinusRegular, closeTo(2, 1e-9));
  });
}

NbaPlayerCareerSnapshot _career(
  String key,
  String type,
  List<double?> ppg, {
  double ts = .6,
}) =>
    _careerWithSeasons(
      key,
      type,
      {
        for (var i = 0; i < ppg.length; i++) '200$i-0${i + 1}': ppg[i],
      },
      ts: ts,
    );

NbaPlayerCareerSnapshot _careerWithSeasons(
  String key,
  String type,
  Map<String, double?> ppg, {
  double ts = .6,
}) {
  final seasons = [
    for (final entry in ppg.entries)
      NbaPlayerCareerSeason(
        seasonId: entry.key,
        seasonType: type,
        leagueId: 'NBA',
        teamKey: 'team',
        teamName: 'Team',
        teamAbbreviation: 'TM',
        franchiseKey: 'franchise',
        franchiseName: 'Franchise',
        games: 10,
        gamesStarted: 10,
        minutes: 300,
        points: entry.value == null ? null : entry.value! * 10,
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
      ),
  ];
  return NbaPlayerCareerSnapshot(
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
    declaredFirstSeason: seasons.isEmpty ? '' : seasons.first.seasonId,
    declaredLastSeason: seasons.isEmpty ? '' : seasons.last.seasonId,
    declaredSeasonRows: seasons.length,
    materialConflictCount: 0,
  );
}
