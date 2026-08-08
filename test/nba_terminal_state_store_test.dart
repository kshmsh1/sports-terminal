import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_terminal_state_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('terminal state persists favorites recents and queries', () async {
    const store = NbaTerminalStateStore();

    await store.toggleFavorite('stats');
    await store.recordCommand('history');
    await store.recordCommand('stats');
    await store.recordQuery('Michael Jordan');

    final state = await store.load();
    expect(state.favoriteCommandIds, contains('stats'));
    expect(state.recentCommandIds.first, 'stats');
    expect(state.recentCommandIds, contains('history'));
    expect(state.recentQueries.first, 'Michael Jordan');
  });

  test('terminal state deduplicates and bounds recents', () async {
    const store = NbaTerminalStateStore();

    for (var index = 0; index < 20; index++) {
      await store.recordCommand('command-$index');
      await store.recordQuery('query-$index');
    }
    await store.recordCommand('command-15');
    await store.recordQuery('QUERY-15');

    final state = await store.load();
    expect(state.recentCommandIds.length, 12);
    expect(state.recentQueries.length, 12);
    expect(state.recentCommandIds.first, 'command-15');
    expect(state.recentQueries.first, 'QUERY-15');
    expect(state.recentCommandIds.where((value) => value == 'command-15').length, 1);
    expect(state.recentQueries.where((value) => value.toLowerCase() == 'query-15').length, 1);
  });

  test('favorite toggle removes an existing favorite', () async {
    const store = NbaTerminalStateStore();

    await store.toggleFavorite('analytics');
    expect((await store.load()).favoriteCommandIds, contains('analytics'));

    await store.toggleFavorite('analytics');
    expect((await store.load()).favoriteCommandIds, isNot(contains('analytics')));
  });
}
