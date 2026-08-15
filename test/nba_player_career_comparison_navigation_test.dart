import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/nba_player_career_comparison_navigation.dart';
import 'package:sports_terminal/widgets/nba_player_career_navigation.dart';

void main() {
  testWidgets('permanent comparison route mounts aligned career research', (tester) async {
    final observer = _RouteObserver();
    String openedPlayer = '';
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaPlayerCareerComparisonPage(
                context,
                leftPlayerKey: 'p1',
                leftPlayerName: 'Alpha Player',
                rightPlayerKey: 'p2',
                rightPlayerName: 'Beta Player',
                loadPlayer: (key, _) async => _playerPayload(key),
                loadTeam: (key) async => _teamDossier(key),
                onOpenPlayer: (key, _) => openedPlayer = key,
              ),
              child: const Text('Open Compare'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Compare'));
    await tester.pumpAndSettle();

    expect(observer.lastRouteName, '/nba/history/player-comparisons/p1/p2');
    expect(
      find.byKey(const ValueKey('nba-player-career-comparison-p1-p2')),
      findsOneWidget,
    );
    expect(find.text('CAREER COMPARISON SNAPSHOT'), findsOneWidget);
    expect(find.textContaining('ALIGNED SEASON EVIDENCE'), findsOneWidget);
    expect(find.text('CAREER CONTEXT EVIDENCE'), findsOneWidget);

    final openAlpha = find.text('OPEN ALPHA PLAYER');
    await tester.ensureVisible(openAlpha);
    await tester.tap(openAlpha);
    expect(openedPlayer, 'p1');
  });

  testWidgets('comparison workspace resolves a second Player from canonical search',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaPlayerCareerComparisonPage(
                context,
                leftPlayerKey: 'p1',
                leftPlayerName: 'Alpha Player',
                loadPlayer: (key, _) async => _playerPayload(key),
                loadTeam: (key) async => _teamDossier(key),
                searchLoader: (query, league) async => {
                  'groups': {
                    'players': [
                      {
                        'player_key': 'p2',
                        'canonical_name': 'Beta Player',
                        'nba_id': '2002',
                        'league_id': league,
                        'last_stat_season': '2021-22',
                      },
                    ],
                  },
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('career-comparison-player-query')),
      'Beta',
    );
    await tester.tap(find.byKey(const ValueKey('career-comparison-player-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('career-comparison-select-p2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('nba-player-career-comparison-p1-p2')),
      findsOneWidget,
    );
    expect(find.text('Alpha Player vs Beta Player'), findsWidgets);
  });

  testWidgets('permanent Player Career app bar hands off to comparison route',
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
                playerName: 'Alpha Player',
                loadPlayer: (_) async => _playerPayload('p1'),
                loadTeamDossier: (key) async => _teamDossier(key),
              ),
              child: const Text('Open Career'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Career'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-career-open-comparison')));
    await tester.pumpAndSettle();

    expect(observer.lastRouteName, '/nba/history/player-comparisons/p1');
    expect(
      find.byKey(const ValueKey('career-comparison-player-query')),
      findsOneWidget,
    );
  });
}

class _RouteObserver extends NavigatorObserver {
  String? lastRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }
}

Map<String, dynamic> _playerPayload(String key) => {
      'profile': {
        'player_key': key,
        'canonical_name': key == 'p1' ? 'Alpha Player' : 'Beta Player',
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
          'team_key': 'team-$key',
          'team_name': 'Team $key',
          'team_abbreviation': 'TST',
          'games': 10,
          'pts': key == 'p1' ? 200 : 180,
          'reb': 50,
          'ast': 60,
          'ts_pct': .60,
          'primary_source': 'fixture',
        },
        {
          'season_id': '2021-22',
          'season_type': 'regular',
          'league_id': 'NBA',
          'team_key': 'team-$key',
          'team_name': 'Team $key',
          'team_abbreviation': 'TST',
          'games': 10,
          'pts': key == 'p1' ? 220 : 210,
          'reb': 55,
          'ast': 65,
          'ts_pct': .61,
          'primary_source': 'fixture',
        },
      ],
      'awards': [
        {'season_id': '2021-22', 'award': 'Example Award', 'source': 'fixture'},
      ],
      'all_star': [
        {'season_id': '2021-22', 'selection': 'All-Star', 'source': 'fixture'},
      ],
      'identities': [
        {'source_key': 'fixture'},
      ],
      'field_provenance': [
        {'field_name': 'canonical_name'},
      ],
    };

Map<String, dynamic> _teamDossier(String teamKey) => {
      'profile': {
        'team_key': teamKey,
        'canonical_name': 'Team $teamKey',
        'franchise_key': 'franchise-$teamKey',
        'franchise_name': 'Franchise $teamKey',
      },
    };
