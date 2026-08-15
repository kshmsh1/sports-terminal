import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_research_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('activates and reloads exact comparison research configuration', () async {
    const store = NbaPlayerCareerComparisonResearchStore();
    await store.activate(
      const NbaPlayerCareerComparisonResearchCheckpoint(
        leftPlayerKey: 'left',
        leftPlayerName: 'Left',
        rightPlayerKey: 'right',
        rightPlayerName: 'Right',
        league: 'nba',
        seasonType: 'playoffs',
        alignment: NbaPlayerCareerComparisonAlignment.careerYear,
        metric: NbaPlayerCareerMetric.boxPlusMinus,
        sharedOnly: false,
        presetId: 'career-year',
      ),
    );

    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.league, 'NBA');
    expect(loaded.seasonType, 'playoffs');
    expect(loaded.alignment, NbaPlayerCareerComparisonAlignment.careerYear);
    expect(loaded.metric, NbaPlayerCareerMetric.boxPlusMinus);
    expect(loaded.presetId, 'career-year');
    expect(loaded.activatedAt, isNotNull);
  });

  test('activation requires both canonical Player keys', () async {
    const store = NbaPlayerCareerComparisonResearchStore();
    expect(
      () => store.activate(
        const NbaPlayerCareerComparisonResearchCheckpoint(
          leftPlayerKey: 'left',
          leftPlayerName: 'Left',
          rightPlayerKey: '',
          rightPlayerName: '',
          league: 'NBA',
          seasonType: 'regular',
          alignment: NbaPlayerCareerComparisonAlignment.calendarSeason,
          metric: NbaPlayerCareerMetric.pointsPerGame,
          sharedOnly: false,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('clear removes active comparison research checkpoint', () async {
    const store = NbaPlayerCareerComparisonResearchStore();
    await store.activate(_checkpoint());
    expect(await store.load(), isNotNull);
    await store.clear();
    expect(await store.load(), isNull);
  });

  test('corrupt persisted checkpoint safely resolves unavailable', () async {
    SharedPreferences.setMockInitialValues({
      NbaPlayerCareerComparisonResearchStore.storageKey: '{oops',
    });
    expect(
      await const NbaPlayerCareerComparisonResearchStore().load(),
      isNull,
    );
  });
}

NbaPlayerCareerComparisonResearchCheckpoint _checkpoint() =>
    const NbaPlayerCareerComparisonResearchCheckpoint(
      leftPlayerKey: 'left',
      leftPlayerName: 'Left',
      rightPlayerKey: 'right',
      rightPlayerName: 'Right',
      league: 'NBA',
      seasonType: 'regular',
      alignment: NbaPlayerCareerComparisonAlignment.calendarSeason,
      metric: NbaPlayerCareerMetric.pointsPerGame,
      sharedOnly: true,
    );
