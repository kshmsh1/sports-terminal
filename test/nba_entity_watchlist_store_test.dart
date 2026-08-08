import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_entity_watchlist_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('watchlist toggles canonical objects and preserves context metadata', () async {
    const store = NbaEntityWatchlistStore();
    const item = NbaEntityWatchItem(
      kind: 'player',
      key: 'p_example',
      label: 'Example Player',
      subtitle: 'G · 1995-96–2009-10',
      season: '1995-96',
      league: 'NBA',
      seasonType: 'regular',
    );

    expect(await store.load(), isEmpty);

    final added = await store.toggle(item);
    expect(added, hasLength(1));
    expect(added.single.kind, 'player');
    expect(added.single.key, 'p_example');
    expect(added.single.season, '1995-96');
    expect(added.single.league, 'NBA');
    expect(await store.contains(item.signature), isTrue);

    final removed = await store.toggle(item);
    expect(removed, isEmpty);
    expect(await store.contains(item.signature), isFalse);
  });

  test('watchlist deduplicates by canonical signature and supports explicit remove', () async {
    const store = NbaEntityWatchlistStore();
    const season = NbaEntityWatchItem(
      kind: 'season',
      key: '2023-24',
      label: '2023-24',
      season: '2023-24',
      league: 'NBA',
      seasonType: 'regular',
    );
    const game = NbaEntityWatchItem(
      kind: 'game',
      key: 'g1',
      label: 'Away @ Home',
      season: '2023-24',
      league: 'NBA',
      seasonType: 'regular',
    );

    await store.toggle(season);
    await store.toggle(game);
    final items = await store.load();
    expect(items, hasLength(2));
    expect(items.first.key, 'g1');

    final afterRemove = await store.remove(season.signature);
    expect(afterRemove, hasLength(1));
    expect(afterRemove.single.key, 'g1');

    await store.clear();
    expect(await store.load(), isEmpty);
  });
}
