import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_scope_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

void main() {
  test('shared calendar scope keeps only exact overlapping seasons', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', ['2019-20', '2020-21', '2021-22']),
      right: _career('right', ['2020-21', '2021-22', '2022-23']),
    );

    final result = const NbaPlayerCareerComparisonScopeEngine().build(
      comparison,
      sharedOnly: true,
    );

    expect(result.pairs.map((pair) => pair.axisLabel), ['2020-21', '2021-22']);
    expect(result.paired, 2);
    expect(result.excludedLeftOnly, 1);
    expect(result.excludedRightOnly, 1);
  });

  test('unscoped comparison preserves one-sided calendar evidence', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', ['2019-20', '2020-21']),
      right: _career('right', ['2020-21', '2021-22']),
    );
    final result = const NbaPlayerCareerComparisonScopeEngine().build(comparison);

    expect(result.pairs.length, 3);
    expect(result.leftOnly, 1);
    expect(result.rightOnly, 1);
  });

  test('shared-season scope never reinterprets career-year alignment', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', ['1999-00', '2000-01']),
      right: _career('right', ['2020-21', '2021-22']),
      alignment: NbaPlayerCareerComparisonAlignment.careerYear,
    );
    final result = const NbaPlayerCareerComparisonScopeEngine().build(
      comparison,
      sharedOnly: true,
    );

    expect(result.pairs.length, 2);
    expect(
      result.coverageLabel,
      'SHARED-SEASON FILTER REQUIRES CALENDAR ALIGNMENT',
    );
  });

  test('no shared seasons stays explicitly empty', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', ['1999-00']),
      right: _career('right', ['2020-21']),
    );
    final result = const NbaPlayerCareerComparisonScopeEngine().build(
      comparison,
      sharedOnly: true,
    );

    expect(result.pairs, isEmpty);
    expect(result.coverageLabel, 'NO SHARED CALENDAR SEASONS');
  });
}

NbaPlayerCareerSnapshot _career(String key, List<String> seasons) =>
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
      seasons: [for (final season in seasons) _season(season)],
      tenures: const [],
      missingTeamDossierKeys: const [],
      multiTeamAggregateSeasons: const [],
      declaredFirstSeason: seasons.isEmpty ? '' : seasons.first,
      declaredLastSeason: seasons.isEmpty ? '' : seasons.last,
      declaredSeasonRows: seasons.length,
      materialConflictCount: 0,
    );

NbaPlayerCareerSeason _season(String season) => NbaPlayerCareerSeason(
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
      points: 200,
      rebounds: 50,
      assists: 40,
      steals: 10,
      blocks: 5,
      turnovers: 20,
      trueShootingPct: .6,
      playerEfficiencyRating: 20,
      winShares: 5,
      boxPlusMinus: 2,
      valueOverReplacement: 1,
      syntheticAggregate: false,
      source: 'test',
    );
