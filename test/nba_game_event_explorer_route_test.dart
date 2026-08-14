import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/controllers/route_payload_controller.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/widgets/nba_game_navigation.dart';

void main() {
  testWidgets('permanent game route mounts event explorer, profiles and segment visualization', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RoutePayloadController();
    await tester.pumpWidget(
      RoutePayloadScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => openNbaGamePage(
                  context,
                  gameId: 'g1',
                  gameLabel: 'BBB @ AAA',
                  loadSeed: () async => _seed(),
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

    expect(find.byKey(const ValueKey('game-segment-visualization')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-team-event-profiles')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-player-event-profiles')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-segment-observed-points-chart')), findsOneWidget);

    final explorer = find.byKey(const ValueKey('game-event-explorer-g1'));
    expect(explorer, findsOneWidget);
    await tester.ensureVisible(explorer);
    await tester.pumpAndSettle();
    expect(find.text('EVENT EXPLORER'), findsOneWidget);
  });

  testWidgets('event explorer searches, drills into an event and routes exact event to Python Lab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RoutePayloadController();
    await tester.pumpWidget(
      RoutePayloadScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => openNbaGamePage(
                  context,
                  gameId: 'g1',
                  loadSeed: () async => _seed(),
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

    final search = find.byKey(const ValueKey('event-explorer-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'corner three');
    await tester.pumpAndSettle();

    final openEvent = find.byKey(const ValueKey('event-explorer-open-3'));
    expect(openEvent, findsOneWidget);
    await tester.ensureVisible(openEvent);
    await tester.tap(openEvent);
    await tester.pumpAndSettle();

    final inspector = find.byKey(const ValueKey('event-explorer-inspector-3'));
    expect(inspector, findsOneWidget);
    expect(find.textContaining('Alpha Guard corner three'), findsWidgets);

    final python = find.byKey(const ValueKey('event-route-python-lab-3'));
    await tester.ensureVisible(python);
    await tester.tap(python);
    await tester.pump();

    expect(controller.hasActivePayload, isTrue);
    expect(controller.activePayload!.sourceObjectType, 'NBA Game Event');
    expect(controller.activePayload!.sourceObjectId, 'g1:3');
    expect(controller.activePayload!.targetRoute, 'Python Lab');
    expect(controller.activePayload!.rows.single['sequence'], 3);
    expect(controller.activePayload!.rows.single['player_id'], 'p1');
    expect(controller.lastOrigin, contains('NBA Game Event Explorer'));
  });

  testWidgets('event profile entity links preserve canonical player and team callbacks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? openedTeam;
    (String, String)? openedPlayer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaGamePage(
                context,
                gameId: 'g1',
                loadSeed: () async => _seed(),
                onOpenTeam: (teamId) => openedTeam = teamId,
                onOpenPlayer: (playerId, playerName) => openedPlayer = (playerId, playerName),
              ),
              child: const Text('Open game'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();

    final team = find.byKey(const ValueKey('team-event-profile-AAA'));
    await tester.ensureVisible(team);
    await tester.tap(team);
    await tester.pump();
    expect(openedTeam, 'AAA');

    final player = find.byKey(const ValueKey('player-event-profile-p1'));
    await tester.ensureVisible(player);
    await tester.tap(player);
    await tester.pump();
    expect(openedPlayer, ('p1', 'Alpha Guard'));
  });
}

NbaTerminalSeedSnapshot _seed() => NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': [
        {'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA'},
        {'player_id': 'p2', 'player_name': 'Beta Wing', 'team_id': 'BBB'},
        {'player_id': 'p3', 'player_name': 'Alpha Bench', 'team_id': 'AAA'},
      ],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-15',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 103,
          'away_score': 101,
          'status': 'Final',
          'source_id': 'games',
        },
      ],
      'team_records': const [],
      'team_game_logs': [
        {'game_id': 'g1', 'team_id': 'AAA', 'points': 103},
        {'game_id': 'g1', 'team_id': 'BBB', 'points': 101},
      ],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': [
        {
          'game_id': 'g1',
          'player_id': 'p1',
          'player_name': 'Alpha Guard',
          'team_id': 'AAA',
          'points': 5,
          'rebounds': 2,
          'assists': 1,
        },
      ],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'id': 'event-explorer-test-release', 'status': 'test'},
      'standings': const [],
      'play_by_play': [
        {
          'game_id': 'g1',
          'event_num': 1,
          'period': 4,
          'clock': '5:00',
          'event_type': '12',
          'description': 'Start observed window',
          'home_score': 96,
          'away_score': 94,
          'source_id': 'pbp-v3',
        },
        {
          'game_id': 'g1',
          'event_num': 2,
          'period': 4,
          'clock': '4:40',
          'event_type': '5',
          'description': 'Beta Wing turnover',
          'team_id': 'BBB',
          'player_id': 'p2',
          'home_score': 96,
          'away_score': 94,
          'source_id': 'pbp-v3',
        },
        {
          'game_id': 'g1',
          'event_num': 3,
          'period': 4,
          'clock': '4:15',
          'event_type': '1',
          'description': 'Alpha Guard corner three',
          'team_id': 'AAA',
          'player_id': 'p1',
          'home_score': 99,
          'away_score': 94,
          'source_id': 'pbp-v3',
        },
        {
          'game_id': 'g1',
          'event_num': 4,
          'period': 4,
          'clock': '2:30',
          'event_type': '8',
          'description': 'SUB: Alpha Bench FOR Alpha Guard',
          'team_id': 'AAA',
          'player1_id': 'p1',
          'player1_name': 'Alpha Guard',
          'player2_id': 'p3',
          'player2_name': 'Alpha Bench',
          'home_score': 99,
          'away_score': 97,
          'source_id': 'pbp-v3',
        },
        {
          'game_id': 'g1',
          'event_num': 5,
          'period': 4,
          'clock': '0:45',
          'event_type': '1',
          'description': 'Alpha Guard layup',
          'team_id': 'AAA',
          'player_id': 'p1',
          'home_score': 101,
          'away_score': 99,
          'source_id': 'pbp-v3',
        },
        {
          'game_id': 'g1',
          'event_num': 6,
          'period': 4,
          'clock': '0:00',
          'event_type': '13',
          'description': 'End game',
          'home_score': 103,
          'away_score': 101,
          'source_id': 'pbp-v3',
        },
      ],
      'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
      'asset_path': 'test://event-explorer-route',
      'used_fallback': false,
    });
