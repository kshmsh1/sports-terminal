import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/nba_player_career_navigation.dart';

void main() {
  testWidgets(
      'permanent historical Player route mounts career analytics and linked context',
      (tester) async {
    String openedTeam = '';
    String openedFranchise = '';
    String openedSeason = '';
    String openedGame = '';
    String openedGameSeason = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const ValueKey('open-player-career-test'),
              onPressed: () => openNbaPlayerCareerPage(
                context,
                playerKey: 'p1',
                playerName: 'Example Star',
                loadPlayer: (_) async => _playerPayload(),
                loadTeamDossier: (teamKey) async => _teamDossier(teamKey),
                onOpenTeam: (teamKey) => openedTeam = teamKey,
                onOpenFranchise: (franchiseKey) =>
                    openedFranchise = franchiseKey,
                onOpenSeason: (seasonId) => openedSeason = seasonId,
                onOpenGame: (gameKey, _, seasonId) {
                  openedGame = gameKey;
                  openedGameSeason = seasonId;
                },
              ),
              child: const Text('Open Player Career'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-player-career-test')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('nba-player-career-p1')),
      findsOneWidget,
    );
    expect(find.text('Example Star'), findsWidgets);
    expect(find.text('CAREER TREND & DISTRIBUTION'), findsOneWidget);
    expect(find.text('TEAM / FRANCHISE TENURE'), findsOneWidget);
    expect(find.text('SEASON-BY-SEASON CAREER'), findsOneWidget);
    expect(find.text('AWARDS & ALL-STAR EVIDENCE'), findsOneWidget);
    expect(find.text('DRAFT PROVENANCE'), findsOneWidget);
    expect(find.text('RECENT SOURCE-BACKED GAMES'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player-career-source-boundary')),
      findsOneWidget,
    );

    final team = find.byKey(const ValueKey('career-team-alpha'));
    await tester.ensureVisible(team);
    await tester.tap(team);
    expect(openedTeam, 'alpha');

    final franchise =
        find.byKey(const ValueKey('career-franchise-fr_alpha'));
    await tester.ensureVisible(franchise);
    await tester.tap(franchise);
    expect(openedFranchise, 'fr_alpha');

    final season = find.byKey(const ValueKey('career-season-2020-21'));
    await tester.ensureVisible(season);
    await tester.tap(season);
    expect(openedSeason, '2020-21');

    final game = find.byKey(const ValueKey('career-game-g1'));
    await tester.ensureVisible(game);
    await tester.tap(game);
    expect(openedGame, 'g1');
    expect(openedGameSeason, '2020-21');
  });

  testWidgets('missing Team dossier remains visible as tenure coverage gap',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaPlayerCareerPage(
                context,
                playerKey: 'p1',
                playerName: 'Example Star',
                loadPlayer: (_) async => _playerPayload(),
                loadTeamDossier: (_) async => throw StateError('fixture unavailable'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final boundary =
        find.byKey(const ValueKey('player-career-source-boundary'));
    await tester.ensureVisible(boundary);
    expect(boundary, findsOneWidget);
    expect(find.textContaining('TEAM DOSSIER GAP'), findsWidgets);
  });

  testWidgets('permanent historical Player route has stable canonical path',
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
                playerName: 'Example Star',
                loadPlayer: (_) async => _playerPayload(),
                loadTeamDossier: (teamKey) async => _teamDossier(teamKey),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(observer.lastRouteName, '/nba/history/players/p1');
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

Map<String, dynamic> _playerPayload() => {
      'profile': {
        'player_key': 'p1',
        'canonical_name': 'Example Star',
        'primary_position': 'G',
        'active_from': '2019-20',
        'active_to': '2020-21',
        'nba_id': '1001',
        'source_count': 2,
      },
      'seasons': [
        {
          'season_id': '2019-20',
          'season_type': 'regular',
          'league_id': 'NBA',
          'team_key': 'alpha',
          'team_name': 'Alpha',
          'team_abbreviation': 'ALP',
          'games': 80,
          'pts': 1600,
          'reb': 400,
          'ast': 480,
          'ts_pct': 0.60,
          'per': 20.0,
          'ws': 8.0,
          'bpm': 3.0,
          'vorp': 3.5,
        },
        {
          'season_id': '2020-21',
          'season_type': 'regular',
          'league_id': 'NBA',
          'team_key': 'alpha',
          'team_name': 'Alpha',
          'team_abbreviation': 'ALP',
          'games': 82,
          'pts': 1722,
          'reb': 410,
          'ast': 492,
          'ts_pct': 0.62,
          'per': 21.0,
          'ws': 9.0,
          'bpm': 4.0,
          'vorp': 4.0,
        },
      ],
      'awards': [
        {
          'season_id': '2020-21',
          'award': 'Example Award',
          'rank': 1,
        },
      ],
      'all_star': [
        {
          'season_id': '2020-21',
          'selection': 'All-Star',
          'starter': true,
        },
      ],
      'draft': [
        {
          'draft_year': 2019,
          'round': 1,
          'pick_number': 5,
          'team_key': 'alpha',
          'team_abbreviation': 'ALP',
        },
      ],
      'recent_games': [
        {
          'game_key': 'g1',
          'season_id': '2020-21',
          'game_date': '2021-01-01',
          'team_key': 'alpha',
          'team_name': 'Alpha',
          'opponent_team_key': 'beta',
          'opponent_name': 'Beta',
          'pts': 25,
          'reb': 7,
          'ast': 8,
        },
      ],
      'identities': [
        {'source_key': 'nba'},
      ],
      'field_provenance': [
        {'field_name': 'canonical_name'},
      ],
      'conflicts': const [],
      'summary': {
        'first_season': '2019-20',
        'last_season': '2020-21',
        'season_rows': 2,
        'material_conflicts': 0,
      },
    };

Map<String, dynamic> _teamDossier(String teamKey) => {
      'profile': {
        'team_key': teamKey,
        'canonical_name': teamKey == 'alpha' ? 'Alpha' : 'Beta',
        'franchise_key': teamKey == 'alpha' ? 'fr_alpha' : 'fr_beta',
        'franchise_name':
            teamKey == 'alpha' ? 'Alpha Franchise' : 'Beta Franchise',
      },
    };
