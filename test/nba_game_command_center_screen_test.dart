import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/screens/product_nba_game_command_center_screen.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  testWidgets('renders scoreboard, coverage and player box score', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF090D12),
          body: SingleChildScrollView(
            child: ProductNbaGameCommandCenterScreen(
              gameId: 'game-1',
              loadSeed: () async => _seed(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NBA / GAME COMMAND CENTER'), findsOneWidget);
    expect(find.text('AWY'), findsWidgets);
    expect(find.text('HME'), findsWidgets);
    expect(find.text('101'), findsWidgets);
    expect(find.text('112'), findsWidgets);
    expect(find.text('PLAYER BOX SCORE'), findsOneWidget);
    expect(find.text('Away Star'), findsOneWidget);
    expect(find.text('Home Star'), findsOneWidget);
    expect(find.textContaining('AVAILABLE · SCOREBOARD'), findsOneWidget);
    expect(find.text('SOURCE & PROVENANCE'), findsOneWidget);
  });

  testWidgets('renders an explicit unavailable state for incomplete box data', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductNbaGameCommandCenterScreen(
              gameId: 'game-1',
              loadSeed: () async => _seed(includeLogs: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('UNAVAILABLE · TEAM BOX'), findsOneWidget);
    expect(
      find.text('A complete two-team box score is not available in the active dataset.'),
      findsOneWidget,
    );
    expect(
      find.text('Player game lines are not available for this game in the active dataset.'),
      findsOneWidget,
    );
  });

  testWidgets('renders game-outside-scope error without fabricating a record', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductNbaGameCommandCenterScreen(
            gameId: 'missing',
            loadSeed: () async => _seed(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Game outside active scope'), findsOneWidget);
    expect(find.textContaining('missing'), findsOneWidget);
  });
}

NbaTerminalSeedSnapshot _seed({bool includeLogs = true}) {
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': [
      {'team_id': 'AWY', 'team_name': 'Away Team', 'abbreviation': 'AWY'},
      {'team_id': 'HME', 'team_name': 'Home Team', 'abbreviation': 'HME'},
    ],
    'players': [
      {'player_id': 'p-away', 'player_name': 'Away Star'},
      {'player_id': 'p-home', 'player_name': 'Home Star'},
    ],
    'games': [
      {
        'game_id': 'game-1',
        'game_date': '2026-01-05',
        'season': '2025-26',
        'season_type': 'regular',
        'away_team_id': 'AWY',
        'home_team_id': 'HME',
        'away_score': 101,
        'home_score': 112,
        'status': 'Final',
        'arena': 'Test Arena',
        'source_id': 'test-source',
        'periods': [
          {'label': 'Q1', 'away_score': 22, 'home_score': 29},
          {'label': 'Q2', 'away_score': 30, 'home_score': 27},
        ],
      },
    ],
    'team_records': const [],
    'team_game_logs': includeLogs
        ? [
            {'game_id': 'game-1', 'team_id': 'AWY', 'points': 101, 'rebounds': 40, 'assists': 23},
            {'game_id': 'game-1', 'team_id': 'HME', 'points': 112, 'rebounds': 46, 'assists': 28},
          ]
        : const [],
    'player_season_totals': const [],
    'player_leaders': const {},
    'player_game_highs': const {},
    'player_game_logs_top': includeLogs
        ? [
            {
              'game_id': 'game-1',
              'team_id': 'AWY',
              'player_id': 'p-away',
              'player_name': 'Away Star',
              'minutes': '36:00',
              'points': 27,
            },
            {
              'game_id': 'game-1',
              'team_id': 'HME',
              'player_id': 'p-home',
              'player_name': 'Home Star',
              'minutes': '34:30',
              'points': 31,
            },
          ]
        : const [],
    'search_index': const [],
    'data_dictionary': const {},
    'validation_report': {'status': 'pass'},
    'release_manifest': {'id': 'release-test', 'version': '1', 'status': 'certified'},
    'standings': const [],
    'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'certified'},
    'asset_path': 'test://nba-2026',
    'used_fallback': false,
  });
}
