import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/screens/product_nba_season_screen.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/widgets/nba_game_navigation.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opens canonical season route with standings and game inventory',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-season-test'),
              onPressed: () => openNbaSeasonPage(
                context,
                seasonId: '2025-26',
                loadSeed: () async => _seed(),
                loadComparisonSeason: (_) async => _comparisonSeed(),
                loadSourceContext: () async => _sourceContext(),
              ),
              child: const Text('Season'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-season-test')));
    await tester.pumpAndSettle();

    expect(find.byType(ProductNbaSeasonScreen), findsOneWidget);
    expect(find.text('2025-26 NBA Season'), findsWidgets);
    expect(find.text('SEASON STANDINGS'), findsOneWidget);
    expect(find.text('SEASON GAME INVENTORY'), findsOneWidget);
    expect(find.byKey(const ValueKey('season-cross-season-workbench')), findsOneWidget);
    expect(find.byKey(const ValueKey('season-source-context-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('season-transactions-not-exposed')), findsOneWidget);
    final route = ModalRoute.of(
      tester.element(find.byType(ProductNbaSeasonScreen)),
    );
    expect(route?.settings.name, '/nba/seasons/2025-26');
    expect(route?.settings.arguments, {'seasonId': '2025-26'});
  });

  testWidgets('season team links preserve canonical team callback',
      (tester) async {
    String? openedTeam;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-season-team-test'),
              onPressed: () => openNbaSeasonPage(
                context,
                seasonId: '2025-26',
                loadSeed: () async => _seed(),
                loadComparisonSeason: (_) async => _comparisonSeed(),
                loadSourceContext: () async => _sourceContext(),
                onOpenTeam: (teamId) => openedTeam = teamId,
              ),
              child: const Text('Season'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-season-team-test')));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('season-team-AAA'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();

    expect(openedTeam, 'AAA');
  });

  testWidgets('season game inventory reopens canonical permanent game route',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-season-game-test'),
              onPressed: () => openNbaSeasonPage(
                context,
                seasonId: '2025-26',
                loadSeed: () async => _seed(),
                loadComparisonSeason: (_) async => _comparisonSeed(),
                loadSourceContext: () async => _sourceContext(),
              ),
              child: const Text('Season'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-season-game-test')));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('season-game-g1'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    final route = ModalRoute.of(
      tester.element(find.byKey(const ValueKey('game-event-batch-panel-g1'))),
    );
    expect(route?.settings.name, '/nba/games/g1');
    expect(route?.settings.arguments, {'gameId': 'g1'});
  });

  testWidgets('season can hand off to full NBA schedule', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-season-schedule-test'),
              onPressed: () => openNbaSeasonPage(
                context,
                seasonId: '2025-26',
                loadSeed: () async => _seed(),
                loadComparisonSeason: (_) async => _comparisonSeed(),
                loadSourceContext: () async => _sourceContext(),
              ),
              child: const Text('Season'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-season-schedule-test')));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('season-open-schedule'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    final route = ModalRoute.of(tester.element(find.text('Canonical game calendar')));
    expect(route?.settings.name, '/nba/schedule');
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
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
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
          'game_id': 'g2',
          'season_id': '2025-26',
          'game_date': '2026-02-01',
          'season_type': 'Regular Season',
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
          'status': 'Scheduled',
        },
      ],
      'team_records': const [],
      'team_game_logs': [
        {'game_id': 'g1', 'team_id': 'AAA', 'points': 110},
        {'game_id': 'g1', 'team_id': 'BBB', 'points': 100},
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
          'points': 20,
        },
      ],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'status': 'test'},
      'standings': const [],
      'play_by_play': const [],
      'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
      'asset_path': 'test://season-route',
      'used_fallback': false,
    });
