import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

void main() {
  NbaPlayerCareerSeason season(String id, {double points = 100, bool aggregate = true}) =>
      NbaPlayerCareerSeason(
        seasonId: id,
        seasonType: 'regular',
        leagueId: 'NBA',
        teamKey: aggregate ? '' : 'team-$id',
        teamName: aggregate ? '' : 'Team $id',
        teamAbbreviation: aggregate ? 'TOT' : 'T$id',
        franchiseKey: '',
        franchiseName: '',
        games: 10,
        gamesStarted: null,
        minutes: null,
        points: points,
        rebounds: null,
        assists: null,
        steals: null,
        blocks: null,
        turnovers: null,
        trueShootingPct: null,
        playerEfficiencyRating: null,
        winShares: null,
        boxPlusMinus: null,
        valueOverReplacement: null,
        syntheticAggregate: aggregate,
        source: 'test',
      );

  NbaPlayerCareerSnapshot career(String key, List<NbaPlayerCareerSeason> seasons) =>
      NbaPlayerCareerSnapshot(
        playerKey: key,
        playerName: key == 'a' ? 'Alpha' : 'Beta',
        primaryPosition: 'G',
        activeFrom: '',
        activeTo: '',
        nbaId: '',
        brefId: '',
        identityConfidence: 1,
        sourceCount: 1,
        seasons: seasons,
        tenures: const [],
        missingTeamDossierKeys: const [],
        multiTeamAggregateSeasons: const [],
        declaredFirstSeason: seasons.isEmpty ? '' : seasons.first.seasonId,
        declaredLastSeason: seasons.isEmpty ? '' : seasons.last.seasonId,
        declaredSeasonRows: seasons.length,
        materialConflictCount: 0,
      );

  test('calendar alignment uses exact source season ids and preserves gaps', () {
    final result = const NbaPlayerCareerComparisonEngine().build(
      left: career('a', [season('2020-21'), season('2021-22')]),
      right: career('b', [season('2021-22'), season('2022-23')]),
    );

    expect(result.pairs.map((row) => row.axisLabel), [
      '2020-21',
      '2021-22',
      '2022-23',
    ]);
    expect(result.sharedCalendarSeasons, ['2021-22']);
    expect(result.pairs[0].leftOnly, isTrue);
    expect(result.pairs[1].bothObserved, isTrue);
    expect(result.pairs[2].rightOnly, isTrue);
  });

  test('career year alignment pairs observed ordinal rows without era claims', () {
    final result = const NbaPlayerCareerComparisonEngine().build(
      left: career('a', [season('1980-81'), season('1981-82')]),
      right: career('b', [season('2020-21'), season('2021-22'), season('2022-23')]),
      alignment: NbaPlayerCareerComparisonAlignment.careerYear,
    );

    expect(result.pairs.map((row) => row.axisLabel), ['YEAR 1', 'YEAR 2', 'YEAR 3']);
    expect(result.pairs[0].left?.seasonId, '1980-81');
    expect(result.pairs[0].right?.seasonId, '2020-21');
    expect(result.pairs[2].left, isNull);
    expect(result.hasCalendarOverlap, isFalse);
  });

  test('non-overlapping eras stay explicit under calendar alignment', () {
    final result = const NbaPlayerCareerComparisonEngine().build(
      left: career('a', [season('1980-81')]),
      right: career('b', [season('2020-21')]),
    );
    expect(result.coverageLabel, 'NON-OVERLAPPING CALENDAR ERAS');
    expect(result.pairedObservations, 0);
  });

  test('aggregate season is preferred over team stint without summing stints', () {
    final result = const NbaPlayerCareerComparisonEngine().build(
      left: career('a', [
        season('2021-22', points: 40, aggregate: false),
        season('2021-22', points: 100, aggregate: true),
      ]),
      right: career('b', [season('2021-22', points: 90)]),
    );
    expect(result.pairs.single.left?.points, 100);
  });

  test('same canonical player is visible rather than silently accepted', () {
    final same = career('a', [season('2021-22')]);
    final result = const NbaPlayerCareerComparisonEngine().build(left: same, right: same);
    expect(result.samePlayer, isTrue);
    expect(result.coverageLabel, 'SAME CANONICAL PLAYER');
  });
}
