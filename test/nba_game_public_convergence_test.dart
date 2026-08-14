import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/widgets/nba_game_discovery_panel.dart';
import 'package:sports_terminal/widgets/nba_game_navigation.dart';
import 'package:sports_terminal/widgets/nba_player_game_log_panel.dart';
import 'package:sports_terminal/widgets/nba_team_game_log_panel.dart';

void main() {
  testWidgets('player game log exposes canonical game and opponent identities', (
    tester,
  ) async {
    String? openedTeam;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NbaPlayerGameLogPanel(
              seed: _seed(),
              playerId: 'p1',
              playerName: 'Example Guard',
              seasonType: 'Regular Season',
              onOpenGame: (_, __) {},
              onOpenTeam: (teamId) => openedTeam = teamId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GAME LOG'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-open-game-g1')), findsOneWidget);
    final opponent = find.byKey(const ValueKey('player-game-opponent-BBB-g1'));
    expect(opponent, findsOneWidget);
    await tester.tap(opponent);
    await tester.pump();
    expect(openedTeam, 'BBB');
  });

  testWidgets('team game panel uses canonical schedule and exposes full schedule', (
    tester,
  ) async {
    var openedSchedule = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NbaTeamGameLogPanel(
              seed: _seed(),
              teamId: 'AAA',
              seasonType: 'Regular Season',
              onOpenGame: (_, __) {},
              onOpenTeam: (_) {},
              onOpenSchedule: () => openedSchedule = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEAM GAMES'), findsOneWidget);
    expect(find.byKey(const ValueKey('team-open-game-g1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team-open-schedule-AAA')));
    await tester.pump();
    expect(openedSchedule, isTrue);
  });

  testWidgets('Hub discovery query returns canonical game result', (tester) async {
    String? openedGame;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NbaGameDiscoveryPanel(
            seed: _seed(),
            query: 'Beta',
            seasonType: 'Regular Season',
            onOpenGame: (gameId, _) => openedGame = gameId,
            onOpenTeam: (_) {},
            onOpenSchedule: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GAME DISCOVERY'), findsOneWidget);
    final game = find.byKey(const ValueKey('hub-discovery-game-g1'));
    expect(game, findsOneWidget);
    await tester.ensureVisible(game);
    await tester.tap(game);
    await tester.pump();
    expect(openedGame, 'g1');
  });

  testWidgets('scoped schedule route preserves visible initial constraints', (
    tester,
  ) async {
    final observer = _RecordingObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaSchedulePage(
                context,
                loadSeed: () async => _seed(),
                initialTeamId: 'AAA',
                initialQuery: 'Beta',
                initialSeasonType: 'Regular Season',
                initialAscending: false,
              ),
              child: const Text('Open scoped schedule'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open scoped schedule'));
    await tester.pumpAndSettle();

    expect(observer.lastPushed?.settings.name, '/nba/schedule');
    expect(observer.lastPushed?.settings.arguments, {
      'teamId': 'AAA',
      'query': 'Beta',
      'seasonType': 'Regular Season',
      'ascending': false,
    });
    expect(find.text('AAA Schedule'), findsOneWidget);
    expect(find.text('TEAM AAA'), findsOneWidget);
    expect(find.text('REGULAR SEASON'), findsOneWidget);
    expect(find.text('QUERY Beta'), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-game-g1')), findsOneWidget);
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
          'season_type': 'Regular Season',
          'status': 'Final',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 110,
          'away_score': 105,
          'arena': 'Terminal Arena',
          'city': 'Chicago',
          'source_id': 'games',
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
          'rebounds': 5,
          'assists': 7,
          'source_id': 'box',
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
      'asset_path': 'test://public-game-convergence',
      'used_fallback': false,
    });
