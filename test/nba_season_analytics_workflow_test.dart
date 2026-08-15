import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/controllers/route_payload_controller.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/widgets/nba_game_navigation.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('permanent season route exposes analytics and canonical entity drilldowns',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? openedTeam;
    (String, String)? openedPlayer;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNbaSeasonPage(
                context,
                seasonId: '2025-26',
                loadSeed: () async => _seed(),
                loadComparisonSeason: (_) async => _comparisonSeed(),
                loadSourceContext: () async => _sourceContext(),
                onOpenTeam: (teamId) => openedTeam = teamId,
                onOpenPlayer: (playerId, playerName) =>
                    openedPlayer = (playerId, playerName),
              ),
              child: const Text('Open season'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open season'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('season-analytics-workbench')), findsOneWidget);
    expect(find.byKey(const ValueKey('season-cross-season-workbench')), findsOneWidget);
    expect(find.byKey(const ValueKey('season-source-context-panel')), findsOneWidget);
    expect(find.text('PLAYER LEADERS'), findsOneWidget);
    expect(find.text('TEAM DISTRIBUTION'), findsOneWidget);
    expect(find.text('OBSERVED PLAYOFF MATCHUPS'), findsOneWidget);
    expect(find.text('CROSS-SEASON INTELLIGENCE'), findsOneWidget);
    expect(find.text('SEASON SOURCE CONTEXT'), findsOneWidget);
    expect(find.byKey(const ValueKey('nba-terminal-distribution-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('season-transactions-not-exposed')), findsOneWidget);

    final player = find.byKey(const ValueKey('season-leader-p1'));
    await tester.ensureVisible(player);
    await tester.tap(player);
    await tester.pump();
    expect(openedPlayer, ('p1', 'Alpha Guard'));

    final team = find.byKey(const ValueKey('season-distribution-team-AAA'));
    await tester.ensureVisible(team);
    await tester.tap(team);
    await tester.pump();
    expect(openedTeam, 'AAA');
  });

  testWidgets('explicit season comparison uses only the requested comparison loader',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? requestedSeason;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNbaSeasonPage(
                context,
                seasonId: '2025-26',
                loadSeed: () async => _seed(),
                loadComparisonSeason: (seasonId) async {
                  requestedSeason = seasonId;
                  return _comparisonSeed();
                },
                loadSourceContext: () async => _sourceContext(),
              ),
              child: const Text('Open season'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open season'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('season-comparison-id'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '2024-25');
    await tester.tap(find.byKey(const ValueKey('season-run-comparison')));
    await tester.pumpAndSettle();

    expect(requestedSeason, '2024-25');
    expect(find.textContaining('COMMON TEAMS'), findsWidgets);
    expect(find.byKey(const ValueKey('season-comparison-team-AAA')), findsOneWidget);
  });

  testWidgets('season workflows write canonical package into shared RoutePayload state',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 2200);
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
              body: TextButton(
                onPressed: () => openNbaSeasonPage(
                  context,
                  seasonId: '2025-26',
                  loadSeed: () async => _seed(),
                  loadComparisonSeason: (_) async => _comparisonSeed(),
                  loadSourceContext: () async => _sourceContext(),
                ),
                child: const Text('Open season'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open season'));
    await tester.pumpAndSettle();
    final route = find.byKey(const ValueKey('season-route-python'));
    await tester.ensureVisible(route);
    await tester.tap(route);
    await tester.pump();

    expect(controller.activePayload, isNotNull);
    expect(controller.activePayload!.sourceObjectType, 'NBA Season');
    expect(controller.activePayload!.sourceObjectId, '2025-26');
    expect(controller.activePayload!.targetRoute, 'Python Lab');
    expect(controller.activePayload!.rows.first['team_id'], 'AAA');
    expect(controller.lastOrigin, contains('NBA Season · 2025-26'));
  });

  testWidgets('season watch control persists and toggles canonical Season identity',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNbaSeasonPage(
                context,
                seasonId: '2025-26',
                loadSeed: () async => _seed(),
                loadComparisonSeason: (_) async => _comparisonSeed(),
                loadSourceContext: () async => _sourceContext(),
              ),
              child: const Text('Open season'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open season'));
    await tester.pumpAndSettle();
    final watch = find.byKey(const ValueKey('season-toggle-watch'));
    await tester.ensureVisible(watch);
    expect(find.text('WATCH SEASON'), findsOneWidget);
    await tester.tap(watch);
    await tester.pumpAndSettle();
    expect(find.text('UNWATCH SEASON'), findsOneWidget);
  });

  testWidgets('observed playoff matchup links reopen canonical game routes',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNbaSeasonPage(
                context,
                seasonId: '2025-26',
                loadSeed: () async => _seed(),
                loadComparisonSeason: (_) async => _comparisonSeed(),
                loadSourceContext: () async => _sourceContext(),
              ),
              child: const Text('Open season'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open season'));
    await tester.pumpAndSettle();
    final playoffGame = find.byKey(const ValueKey('season-playoff-game-p1'));
    await tester.ensureVisible(playoffGame);
    await tester.tap(playoffGame);
    await tester.pumpAndSettle();

    final gamePanel = find.byKey(const ValueKey('game-event-batch-panel-p1'));
    expect(gamePanel, findsOneWidget);
    final route = ModalRoute.of(tester.element(gamePanel));
    expect(route?.settings.name, '/nba/games/p1');
  });
}

Map<String, dynamic> _sourceContext() => const {
      'league': 'NBA',
      'season_type': 'regular',
      'awards': [
        {
          'award': 'Most Valuable Player',
          'player_key': 'p1',
          'player_name': 'Alpha Guard',
          'winner': true,
        },
      ],
      'all_star': [],
      'draft': [],
      'coverage': [
        {'domain': 'awards', 'status': 'available', 'rows': 1},
      ],
    };

NbaTerminalSeedSnapshot _comparisonSeed() => NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': const [],
      'games': [
        {
          'game_id': 'c1',
          'season_id': '2024-25',
          'game_date': '2025-01-01',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 100,
          'away_score': 95,
          'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': const [],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': const [],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'status': 'historical-canonical'},
      'standings': const [],
      'play_by_play': const [],
      'launch_config': {'supportedSeason': '2024-25', 'datasetStatus': 'historical-canonical'},
      'asset_path': 'backend://v2/nba/history/2024-25',
      'used_fallback': false,
    });

NbaTerminalSeedSnapshot _seed() => NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': [
        {'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA'},
        {'player_id': 'p2', 'player_name': 'Beta Wing', 'team_id': 'BBB'},
      ],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-01',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 110,
          'away_score': 100,
          'status': 'Final',
        },
        {
          'game_id': 'p1',
          'season_id': '2025-26',
          'game_date': '2026-04-20',
          'season_type': 'Playoffs',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 108,
          'away_score': 101,
          'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': [
        {'game_id': 'g1', 'team_id': 'AAA', 'points': 110},
        {'game_id': 'g1', 'team_id': 'BBB', 'points': 100},
        {'game_id': 'p1', 'team_id': 'AAA', 'points': 108},
        {'game_id': 'p1', 'team_id': 'BBB', 'points': 101},
      ],
      'player_season_totals': [
        {
          'season_id': '2025-26',
          'season_type': 'Regular Season',
          'player_id': 'p1',
          'player_label': 'Alpha Guard',
          'team_id': 'AAA',
          'games': 10,
          'points': 260,
          'rebounds': 50,
          'assists': 80,
        },
        {
          'season_id': '2025-26',
          'season_type': 'Regular Season',
          'player_id': 'p2',
          'player_label': 'Beta Wing',
          'team_id': 'BBB',
          'games': 10,
          'points': 200,
          'rebounds': 70,
          'assists': 30,
        },
      ],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': [
        {
          'game_id': 'g1',
          'player_id': 'p1',
          'player_name': 'Alpha Guard',
          'team_id': 'AAA',
          'points': 26,
        },
      ],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'status': 'test'},
      'standings': const [],
      'play_by_play': const [],
      'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
      'asset_path': 'test://season-analytics-route',
      'used_fallback': false,
    });
