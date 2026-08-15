import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_watch_service.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('watch identity preserves directional players and analyst scope', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left'),
      right: _career('right'),
    );
    final item = const NbaPlayerCareerComparisonWatchService().buildItem(
      comparison: comparison,
      seasonType: 'playoffs',
      sharedOnly: true,
    );

    expect(item.kind, 'player-career-comparison');
    expect(item.key, contains('left__right__calendarSeason__shared'));
    expect(item.seasonType, 'playoffs');
    expect(item.subtitle, contains('SHARED SEASONS'));
  });

  test('toggle persists and removes exact comparison watch', () async {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left'),
      right: _career('right'),
    );
    const service = NbaPlayerCareerComparisonWatchService();

    await service.toggle(comparison: comparison);
    expect(await service.isWatched(comparison: comparison), isTrue);

    await service.toggle(comparison: comparison);
    expect(await service.isWatched(comparison: comparison), isFalse);
  });

  test('shared and all-season watches are distinct', () async {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left'),
      right: _career('right'),
    );
    const service = NbaPlayerCareerComparisonWatchService();

    await service.toggle(comparison: comparison, sharedOnly: true);
    expect(
      await service.isWatched(comparison: comparison, sharedOnly: true),
      isTrue,
    );
    expect(await service.isWatched(comparison: comparison), isFalse);
  });

  test('reversing players creates a distinct directional comparison watch', () async {
    const service = NbaPlayerCareerComparisonWatchService();
    final forward = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left'),
      right: _career('right'),
    );
    final reverse = const NbaPlayerCareerComparisonEngine().build(
      left: _career('right'),
      right: _career('left'),
    );

    await service.toggle(comparison: forward);
    expect(await service.isWatched(comparison: forward), isTrue);
    expect(await service.isWatched(comparison: reverse), isFalse);
  });
}

NbaPlayerCareerSnapshot _career(String key) => NbaPlayerCareerSnapshot(
      playerKey: key,
      playerName: key.toUpperCase(),
      primaryPosition: '',
      activeFrom: '',
      activeTo: '',
      nbaId: '',
      brefId: '',
      identityConfidence: null,
      sourceCount: null,
      seasons: [_season('2020-21')],
      tenures: const [],
      missingTeamDossierKeys: const [],
      multiTeamAggregateSeasons: const [],
      declaredFirstSeason: '2020-21',
      declaredLastSeason: '2020-21',
      declaredSeasonRows: 1,
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
