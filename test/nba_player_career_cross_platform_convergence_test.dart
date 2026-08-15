import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/widgets/nba_player_career_navigation.dart';
import 'package:sports_terminal/widgets/nba_season_analytics_panel.dart';

void main() {
  testWidgets('Season leaders expose dedicated historical Career actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NbaSeasonAnalyticsPanel(
              seed: _seed(),
              seasonId: '2025-26',
              seasonType: 'regular',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('season-leader-career-p1')),
      findsOneWidget,
    );
    expect(
      tester.widget<IconButton>(
        find.byKey(const ValueKey('season-leader-career-p1')),
      ).tooltip,
      'Open canonical historical Player Career',
    );
  });

  testWidgets('Player Career app bar exposes compare modes and comparison history',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaPlayerCareerPage(
                context,
                playerKey: 'p1',
                playerName: 'Alpha Guard',
                loadPlayer: (_) async => _playerPayload(),
                loadTeamDossier: (_) async => _teamDossier(),
              ),
              child: const Text('Open Career'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Career'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player-career-open-comparison')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-career-comparison-modes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-career-comparison-history')),
      findsOneWidget,
    );
  });

  testWidgets('career-year mode opens comparison route with explicit route state',
      (tester) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaPlayerCareerPage(
                context,
                playerKey: 'p1',
                playerName: 'Alpha Guard',
                loadPlayer: (_) async => _playerPayload(),
                loadTeamDossier: (_) async => _teamDossier(),
              ),
              child: const Text('Open Career'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Career'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('player-career-comparison-modes')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare by career year'));
    await tester.pump();

    expect(observer.lastRouteName, '/nba/history/player-comparisons/p1');
    final route = observer.lastRoute;
    final arguments = route?.settings.arguments as Map<String, dynamic>?;
    expect(arguments?['alignment'], 'careerYear');
    expect(arguments?['metric'], 'pointsPerGame');
  });
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastRoute;
  String? get lastRouteName => lastRoute?.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRoute = route;
    super.didPush(route, previousRoute);
  }
}

NbaTerminalSeedSnapshot _seed() => NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': [
        {'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA'},
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
      ],
      'team_records': const [],
      'team_game_logs': const [],
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
      ],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': const [],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'status': 'test'},
      'standings': const [],
      'play_by_play': const [],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://career-convergence',
      'used_fallback': false,
    });

Map<String, dynamic> _playerPayload() => {
      'profile': {
        'player_key': 'p1',
        'canonical_name': 'Alpha Guard',
        'primary_position': 'G',
      },
      'summary': {
        'first_season': '2020-21',
        'last_season': '2021-22',
        'season_rows': 2,
      },
      'seasons': [
        {
          'season_id': '2020-21',
          'season_type': 'regular',
          'league_id': 'NBA',
          'team_key': 'team-p1',
          'team_name': 'Alpha',
          'team_abbreviation': 'AAA',
          'games': 10,
          'pts': 200,
          'reb': 50,
          'ast': 60,
          'ts_pct': .60,
          'primary_source': 'fixture',
        },
        {
          'season_id': '2021-22',
          'season_type': 'regular',
          'league_id': 'NBA',
          'team_key': 'team-p1',
          'team_name': 'Alpha',
          'team_abbreviation': 'AAA',
          'games': 10,
          'pts': 220,
          'reb': 55,
          'ast': 65,
          'ts_pct': .61,
          'primary_source': 'fixture',
        },
      ],
      'awards': const [],
      'all_star': const [],
      'draft': const [],
      'recent_games': const [],
      'identities': const [],
      'field_provenance': const [],
    };

Map<String, dynamic> _teamDossier() => {
      'profile': {
        'team_key': 'team-p1',
        'canonical_name': 'Alpha',
        'franchise_key': 'fr-alpha',
        'franchise_name': 'Alpha Franchise',
      },
    };
