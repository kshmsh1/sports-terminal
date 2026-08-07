import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_research_context_store.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/services/product_local_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('historical context synchronizes seed scope and selected player', () async {
    const store = NbaResearchContextStore();

    final context = await store.activateHistorical(
      season: '1995-96',
      league: 'nba',
      seasonType: 'regular',
      playerKey: 'player-michael-jordan',
      playerName: 'Michael Jordan',
    );

    expect(context.historical, isTrue);
    expect(context.season, '1995-96');
    expect(context.league, 'NBA');
    expect(context.playerName, 'Michael Jordan');

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(NbaTerminalSeedRepository.dataScopeKey),
      'historical',
    );
    expect(
      preferences.getString(NbaTerminalSeedRepository.historicalSeasonKey),
      '1995-96',
    );
    expect(
      preferences.getString(ProductLocalStore.nbaSelectedPlayerKey),
      'player-michael-jordan',
    );

    final loaded = await store.load();
    expect(loaded.scopeLabel, '1995-96 · NBA · Regular Season');
    expect(loaded.entityLabel, 'Michael Jordan');
  });

  test('recent contexts deduplicate exact scope and entity signatures', () async {
    const store = NbaResearchContextStore();

    await store.activateHistorical(
      season: '1985-86',
      playerKey: 'player-larry-bird',
      playerName: 'Larry Bird',
    );
    await store.activateHistorical(
      season: '1985-86',
      playerKey: 'player-larry-bird',
      playerName: 'Larry Bird',
    );
    await store.activateHistorical(
      season: '1999-00',
      teamKey: 'team-lal',
      teamName: 'Los Angeles Lakers',
    );

    final recent = await store.recent();
    expect(recent, hasLength(2));
    expect(recent.first.teamName, 'Los Angeles Lakers');
    expect(recent.last.playerName, 'Larry Bird');
  });

  test('restoring a recent context rewrites the shared NBA scope', () async {
    const store = NbaResearchContextStore();
    const historical = NbaResearchContext(
      scope: 'historical',
      season: '1979-80',
      league: 'NBA',
      seasonType: 'regular',
      playerKey: 'player-magic-johnson',
      playerName: 'Magic Johnson',
    );

    await store.restore(historical);
    await store.selectCurrent();
    expect((await store.load()).historical, isFalse);

    await store.restore(historical);
    final restored = await store.load();
    expect(restored.historical, isTrue);
    expect(restored.season, '1979-80');
    expect(restored.playerName, 'Magic Johnson');
  });
}
