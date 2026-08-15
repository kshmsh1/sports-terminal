import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_state_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records comparison recents with exact analyst configuration', () async {
    const store = NbaPlayerCareerComparisonStateStore();
    final next = await store.record(_item('a', 'b', sharedOnly: true));

    expect(next.recents, hasLength(1));
    expect(next.recents.single.leftPlayerKey, 'a');
    expect(next.recents.single.rightPlayerKey, 'b');
    expect(next.recents.single.sharedOnly, isTrue);
    expect(next.recents.single.metric, NbaPlayerCareerMetric.pointsPerGame);
  });

  test('record deduplicates only exact comparison signatures', () async {
    const store = NbaPlayerCareerComparisonStateStore();
    await store.record(_item('a', 'b'));
    await store.record(_item('a', 'b'));
    await store.record(_item('a', 'b', sharedOnly: true));
    final state = await store.load();

    expect(state.recents, hasLength(2));
  });

  test('saved comparisons toggle independently from recents', () async {
    const store = NbaPlayerCareerComparisonStateStore();
    final item = _item('a', 'b');
    await store.record(item);
    var state = await store.toggleSaved(item);
    expect(state.saved, hasLength(1));
    expect(state.recents, hasLength(1));
    expect(await store.isSaved(item.signature), isTrue);

    state = await store.toggleSaved(item);
    expect(state.saved, isEmpty);
    expect(state.recents, hasLength(1));
  });

  test('round trip preserves alignment metric and preset identity', () async {
    const store = NbaPlayerCareerComparisonStateStore();
    final item = NbaPlayerCareerComparisonStateItem(
      leftPlayerKey: 'left',
      leftPlayerName: 'Left',
      rightPlayerKey: 'right',
      rightPlayerName: 'Right',
      seasonType: 'playoffs',
      alignment: NbaPlayerCareerComparisonAlignment.careerYear,
      metric: NbaPlayerCareerMetric.boxPlusMinus,
      sharedOnly: false,
      presetId: 'career-year',
    );
    await store.record(item);
    final loaded = await store.load();

    expect(loaded.recents.single.seasonType, 'playoffs');
    expect(
      loaded.recents.single.alignment,
      NbaPlayerCareerComparisonAlignment.careerYear,
    );
    expect(loaded.recents.single.metric, NbaPlayerCareerMetric.boxPlusMinus);
    expect(loaded.recents.single.presetId, 'career-year');
  });

  test('corrupt stored JSON safely falls back to empty state', () async {
    SharedPreferences.setMockInitialValues({
      NbaPlayerCareerComparisonStateStore.storageKey: '{bad json',
    });
    const store = NbaPlayerCareerComparisonStateStore();
    final state = await store.load();
    expect(state.recents, isEmpty);
    expect(state.saved, isEmpty);
  });
}

NbaPlayerCareerComparisonStateItem _item(
  String left,
  String right, {
  bool sharedOnly = false,
}) =>
    NbaPlayerCareerComparisonStateItem(
      leftPlayerKey: left,
      leftPlayerName: left.toUpperCase(),
      rightPlayerKey: right,
      rightPlayerName: right.toUpperCase(),
      seasonType: 'regular',
      alignment: NbaPlayerCareerComparisonAlignment.calendarSeason,
      metric: NbaPlayerCareerMetric.pointsPerGame,
      sharedOnly: sharedOnly,
    );
