import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/widgets/nba_game_navigation.dart';

void main() {
  testWidgets('permanent game route mounts deep intelligence and related-game routing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                gameLabel: 'AAA @ BBB',
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
    expect(find.text('GAME FLOW INTELLIGENCE'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-score-margin-chart')), findsOneWidget);
    expect(find.text('PLAY-BY-PLAY TIMELINE'), findsOneWidget);
    expect(find.text('MATCHUP / ENTERING CONTEXT'), findsOneWidget);
    expect(find.text('PLAYER FORM ENTERING GAME'), findsOneWidget);
    expect(find.byKey(const ValueKey('pbp-event-1')), findsOneWidget);

    final related = find.byKey(const ValueKey('related-game-g2'));
    expect(related, findsOneWidget);
    await tester.ensureVisible(related);
    await tester.tap(related);
    await tester.pumpAndSettle();

    expect(observer.lastPushed?.settings.name, '/nba/games/g2');
  });

  testWidgets('permanent game route exposes missing row-level PBP state', (tester) async {
    tester.view.physicalSize = const Size(1440, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seed = _seed(includePbp: false, declaredPbp: 125);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaGamePage(
                context,
                gameId: 'g1',
                loadSeed: () async => seed,
              ),
              child: const Text('Open game'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();

    expect(find.text('EVENT ROWS NOT EXPOSED'), findsOneWidget);
    expect(
      find.textContaining('125 normalized events are declared by release metadata'),
      findsOneWidget,
    );
  });
}

class _RecordingObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    lastPushed = route;
  }
}

NbaTerminalSeedSnapshot _seed({
  bool includePbp = true,
  int declaredPbp = 0,
}) =>
    NbaTerminalSeedSnapshot.fromMap({
      'manifest': {
        if (declaredPbp > 0)
          'warehouseBuild': {'playByPlayEventsNormalized': declaredPbp},
      },
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': [
        {'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA'},
      ],
      'games': [
        {
          'game_id': 'g0',
          'season_id': '2025-26',
          'game_date': '2026-01-01',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 100,
          'away_score': 95,
          'status': 'Final',
        },
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-15',
          'season_type': 'Regular Season',
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
          'home_score': 5,
          'away_score': 4,
          'status': 'Final',
          'source_id': 'games',
        },
        {
          'game_id': 'g2',
          'season_id': '2025-26',
          'game_date': '2026-02-15',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 108,
          'away_score': 104,
          'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': [
        {'game_id': 'g1', 'team_id': 'AAA', 'points': 4},
        {'game_id': 'g1', 'team_id': 'BBB', 'points': 5},
      ],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': [
        {
          'game_id': 'g0',
          'player_id': 'p1',
          'player_name': 'Alpha Guard',
          'team_id': 'AAA',
          'points': 20,
          'rebounds': 4,
          'assists': 6,
        },
        {
          'game_id': 'g1',
          'player_id': 'p1',
          'player_name': 'Alpha Guard',
          'team_id': 'AAA',
          'points': 4,
          'rebounds': 2,
          'assists': 1,
        },
      ],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'status': 'test'},
      'standings': const [],
      'play_by_play': includePbp
          ? [
              {
                'game_id': 'g1',
                'event_num': 1,
                'period': 1,
                'clock': '12:00',
                'home_score': 0,
                'away_score': 0,
                'description': 'Start',
              },
              {
                'game_id': 'g1',
                'event_num': 2,
                'period': 1,
                'clock': '11:30',
                'home_score': 0,
                'away_score': 2,
                'team_id': 'AAA',
                'player_id': 'p1',
                'description': 'Alpha Guard jumper',
              },
              {
                'game_id': 'g1',
                'event_num': 3,
                'period': 1,
                'clock': '10:55',
                'home_score': 3,
                'away_score': 2,
                'team_id': 'BBB',
                'description': 'Beta three',
              },
              {
                'game_id': 'g1',
                'event_num': 4,
                'period': 1,
                'clock': '10:10',
                'home_score': 3,
                'away_score': 4,
                'team_id': 'AAA',
                'player_id': 'p1',
                'description': 'Alpha Guard layup',
              },
              {
                'game_id': 'g1',
                'event_num': 5,
                'period': 1,
                'clock': '9:40',
                'home_score': 5,
                'away_score': 4,
                'team_id': 'BBB',
                'description': 'Beta basket',
              },
            ]
          : const [],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://deep-route',
      'used_fallback': false,
    });
