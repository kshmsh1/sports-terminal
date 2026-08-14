import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/widgets/nba_game_navigation.dart';

void main() {
  testWidgets('opens permanent game route and preserves team/player callbacks', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    String? openedTeam;
    (String, String)? openedPlayer;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => openNbaGamePage(
                  context,
                  gameId: 'g1',
                  gameLabel: 'Beta @ Alpha',
                  loadSeed: () async => _seed(),
                  onOpenTeam: (teamId) => openedTeam = teamId,
                  onOpenPlayer: (playerId, playerName) =>
                      openedPlayer = (playerId, playerName),
                ),
                child: const Text('Open game'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();

    expect(observer.lastPushed?.settings.name, '/nba/games/g1');
    expect(observer.lastPushed?.settings.arguments, {'gameId': 'g1'});
    expect(find.text('NBA / GAME COMMAND CENTER'), findsOneWidget);
    expect(find.text('Beta @ Alpha'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Example Guard'), findsOneWidget);
    expect(find.text('GAME WORKFLOWS'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    expect(openedTeam, 'AAA');

    final player = find.text('Example Guard');
    await tester.ensureVisible(player);
    await tester.pumpAndSettle();
    await tester.tap(player);
    await tester.pump();
    expect(openedPlayer, ('p1', 'Example Guard'));
  });

  testWidgets('game route opens canonical schedule and schedule reopens game', (
    tester,
  ) async {
    final observer = _RecordingObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaGamePage(
                context,
                gameId: 'g1',
                gameLabel: 'Beta @ Alpha',
                loadSeed: () async => _seed(),
              ),
              child: const Text('Open game'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();
    expect(observer.lastPushed?.settings.name, '/nba/games/g1');

    final scheduleButton = find.byKey(const ValueKey('open-nba-schedule'));
    await tester.ensureVisible(scheduleButton);
    await tester.pumpAndSettle();
    await tester.tap(scheduleButton);
    await tester.pumpAndSettle();

    expect(observer.lastPushed?.settings.name, '/nba/schedule');
    expect(find.text('Canonical game calendar'), findsOneWidget);
    expect(find.text('AAA'), findsWidgets);
    expect(find.text('BBB'), findsWidgets);

    final gameLink = find.byKey(const ValueKey('schedule-game-g1'));
    expect(gameLink, findsOneWidget);
    await tester.ensureVisible(gameLink);
    await tester.pumpAndSettle();
    await tester.tap(gameLink);
    await tester.pumpAndSettle();

    expect(observer.lastPushed?.settings.name, '/nba/games/g1');
    expect(find.text('NBA / GAME COMMAND CENTER'), findsOneWidget);
  });

  testWidgets('empty game identifiers are a navigation no-op', (tester) async {
    final observer = _RecordingObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNbaGamePage(context, gameId: '   '),
              child: const Text('No route'),
            ),
          ),
        ),
      ),
    );

    final pushesBefore = observer.pushCount;
    await tester.tap(find.text('No route'));
    await tester.pump();
    expect(observer.pushCount, pushesBefore);
  });
}

class _RecordingObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    lastPushed = route;
    pushCount += 1;
  }
}

NbaTerminalSeedSnapshot _seed() => NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': [
        {'player_id': 'p1', 'player_name': 'Example Guard', 'team_id': 'AAA'},
      ],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-15',
          'season_type': 'regular',
          'status': 'Final',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 110,
          'away_score': 105,
          'source_id': 'games',
          'periods': [
            {'label': 'Q1', 'home_score': 28, 'away_score': 25},
          ],
        },
      ],
      'team_records': const [],
      'team_game_logs': [
        {'game_id': 'g1', 'team_id': 'AAA', 'points': 110},
        {'game_id': 'g1', 'team_id': 'BBB', 'points': 105},
      ],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': [
        {
          'game_id': 'g1',
          'player_id': 'p1',
          'player_name': 'Example Guard',
          'team_id': 'AAA',
          'minutes': '34:12',
          'points': 24,
        },
      ],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'id': 'test-release'},
      'standings': const [],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://game-navigation',
      'used_fallback': false,
    });
