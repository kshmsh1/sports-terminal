import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sports_terminal/services/nba_with_without_repository.dart';

void main() {
  test('HTML SPA fallback is treated as unpublished lineup data', () async {
    final urls = <Uri>[];
    final repository = NbaWithWithoutRepository(
      client: MockClient((request) async {
        urls.add(request.url);
        return http.Response('<!DOCTYPE html><html><body>Sports Terminal</body></html>', 200,
          headers: {'content-type': 'text/html'});
      }),
    );
    final snapshot = await repository.load('2025-26', seasonType: 'regular');
    expect(snapshot.available, isFalse);
    expect(snapshot.rows, isEmpty);
    expect(snapshot.message, contains('not been published'));
    expect(snapshot.message, isNot(contains('SyntaxError')));
    expect(urls.single.path, contains('data/nba_static/lineups/2025-26/regular/with_without.json'));
  });

  test('valid lineup split data is returned with real observed stats', () async {
    final repository = NbaWithWithoutRepository(
      client: MockClient((request) async => http.Response('''
        {"source":"lineup stints","rows":[{
          "team":"BOS","player_id":"one","teammate_id":"two",
          "minutes_with":55,"minutes_without":67,
          "with":{"pts":28.4},"without":{"pts":25.6}
        }]}
      ''', 200)),
    );
    final data = await repository.load('2024-25', seasonType: 'playoffs');
    expect(data.available, isTrue);
    final split = data.find(team: 'BOS', playerId: 'one', teammateId: 'two');
    expect(split, isNotNull);
    expect(split!.minutesWith, 55);
    expect(split.withStats['pts'], 28.4);
    expect(split.withoutStats['pts'], 25.6);
  });

  test('404 lineup data does not fabricate results', () async {
    final repository = NbaWithWithoutRepository(
      client: MockClient((request) async => http.Response('Not Found', 404)),
    );
    final data = await repository.load('2025-26');
    expect(data.available, isFalse);
    expect(data.rows, isEmpty);
  });
}
