import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/nba_franchise_navigation.dart';

void main() {
  testWidgets('permanent Franchise route mounts lineage, performance and player history', (tester) async {
    String openedTeam = '';
    String openedPlayer = '';
    String openedPlayerName = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('open-franchise-test'),
                onPressed: () => openNbaFranchisePage(
                  context,
                  franchiseKey: 'fr_alpha',
                  franchiseName: 'Alpha Franchise',
                  loadFranchise: () async => _franchisePayload(),
                  loadTeamDossier: (teamKey) async => _teamDossier(teamKey),
                  onOpenTeam: (teamKey) => openedTeam = teamKey,
                  onOpenPlayer: (playerId, playerName) {
                    openedPlayer = playerId;
                    openedPlayerName = playerName;
                  },
                ),
                child: const Text('Open Franchise'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-franchise-test')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nba-franchise-fr_alpha')), findsOneWidget);
    expect(find.text('Alpha Franchise'), findsWidgets);
    expect(find.text('FRANCHISE WIN% HISTORY'), findsOneWidget);
    expect(find.text('CANONICAL TEAM IDENTITY LINEAGE'), findsOneWidget);
    expect(find.text('REGULAR-SEASON HISTORY'), findsOneWidget);
    expect(find.text('BOUNDED FRANCHISE PLAYER HISTORY'), findsOneWidget);
    expect(find.byKey(const ValueKey('franchise-source-boundary')), findsOneWidget);

    final teamButton = find.byKey(const ValueKey('franchise-team-alpha'));
    await tester.ensureVisible(teamButton);
    await tester.tap(teamButton);
    expect(openedTeam, 'alpha');

    final playerButton = find.byKey(const ValueKey('franchise-player-p1'));
    await tester.ensureVisible(playerButton);
    await tester.tap(playerButton);
    expect(openedPlayer, 'p1');
    expect(openedPlayerName, 'Player One');
  });

  testWidgets('partial Team dossier coverage remains visible on the Franchise route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => openNbaFranchisePage(
                context,
                franchiseKey: 'fr_alpha',
                loadFranchise: () async => {
                  ..._franchisePayload(),
                  'team_identities': [
                    ...(_franchisePayload()['team_identities'] as List),
                    {
                      'team_key': 'alpha_missing',
                      'canonical_name': 'Missing Alpha Era',
                      'abbreviation': 'MIS',
                      'league_id': 'NBA',
                      'active_from': '1980-81',
                      'active_to': '1989-90',
                    },
                  ],
                },
                loadTeamDossier: (teamKey) async {
                  if (teamKey == 'alpha_missing') throw StateError('fixture unavailable');
                  return _teamDossier(teamKey);
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

    final boundary = find.byKey(const ValueKey('franchise-source-boundary'));
    await tester.ensureVisible(boundary);
    expect(boundary, findsOneWidget);
    expect(find.textContaining('1 canonical Team dossier(s) did not load'), findsOneWidget);
  });
}

Map<String, dynamic> _franchisePayload() => {
      'profile': {
        'franchise_key': 'fr_alpha',
        'canonical_name': 'Alpha Franchise',
        'current_abbreviation': 'ALP',
        'source_count': 2,
      },
      'team_identities': [
        {
          'team_key': 'alpha',
          'canonical_name': 'Alpha',
          'abbreviation': 'ALP',
          'league_id': 'NBA',
          'active_from': '2020-21',
          'active_to': '2025-26',
          'nba_team_id': '100',
          'source_count': 2,
        },
      ],
      'seasons': [
        {
          'season_id': '2024-25',
          'season_type': 'regular',
          'team_key': 'alpha',
          'canonical_team_name': 'Alpha',
          'abbreviation': 'ALP',
          'league_id': 'NBA',
          'wins': 40,
          'losses': 42,
        },
        {
          'season_id': '2025-26',
          'season_type': 'regular',
          'team_key': 'alpha',
          'canonical_team_name': 'Alpha',
          'abbreviation': 'ALP',
          'league_id': 'NBA',
          'wins': 50,
          'losses': 32,
        },
      ],
      'summary': {
        'team_identities': 1,
        'seasons': 2,
        'first_season': '2024-25',
        'last_season': '2025-26',
      },
    };

Map<String, dynamic> _teamDossier(String teamKey) => {
      'profile': {
        'team_key': teamKey,
        'canonical_name': 'Alpha',
      },
      'notable_players': [
        {
          'player_key': 'p1',
          'player_name': 'Player One',
          'seasons': 2,
          'games': 150,
          'pts': 3300,
          'reb': 700,
          'ast': 900,
          'first_season': '2024-25',
          'last_season': '2025-26',
        },
      ],
    };
