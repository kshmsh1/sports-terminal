import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/screens/product_nba_season_screen.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/widgets/nba_player_game_log_panel.dart';
import 'package:sports_terminal/widgets/nba_team_game_log_panel.dart';

void main() {
  testWidgets('permanent Season route mounts source-backed operations intelligence',
      (tester) async {
    final seed = _seed();
    var sourceLoads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductNbaSeasonScreen(
              seasonId: '2025-26',
              loadSeed: () async => seed,
              loadSourceContext: () async {
                sourceLoads += 1;
                return _sourceContext();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('season-operations-workbench')), findsOneWidget);
    expect(find.text('SEASON OPERATIONS INTELLIGENCE'), findsOneWidget);
    expect(find.text('MULTI-METRIC LEADER MATRIX'), findsOneWidget);
    expect(find.text('DATE-ONLY REST + SCHEDULE DENSITY'), findsOneWidget);
    expect(find.text('AWARDS + VOTING'), findsOneWidget);
    expect(find.text('ALL-STAR SELECTIONS'), findsOneWidget);
    expect(find.text('DRAFT CLASS CONTEXT'), findsOneWidget);
    expect(sourceLoads, 2);
  });

  testWidgets('Player game-log surface exposes exact active Season backlink',
      (tester) async {
    final seed = _seed();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NbaPlayerGameLogPanel(
              seed: seed,
              playerId: 'p1',
              playerName: 'Alpha Guard',
              seasonType: 'Regular Season',
              onOpenGame: (_, __) {},
              onOpenTeam: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-open-season-p1')), findsOneWidget);
    expect(find.text('OPEN 2025-26 SEASON'), findsOneWidget);
  });

  testWidgets('Team game-log surface exposes exact active Season backlink',
      (tester) async {
    final seed = _seed();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NbaTeamGameLogPanel(
              seed: seed,
              teamId: 'AAA',
              seasonType: 'Regular Season',
              onOpenGame: (_, __) {},
              onOpenTeam: (_) {},
              onOpenSchedule: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('team-open-season-AAA')), findsOneWidget);
    expect(find.text('2025-26 Season'), findsOneWidget);
  });
}

Map<String, dynamic> _sourceContext() => {
      'league': 'NBA',
      'season_type': 'regular',
      'awards': [
        {
          'award': 'Most Valuable Player',
          'player_key': 'p1',
          'player_name': 'Alpha Guard',
          'winner': true,
          'vote_points': 900,
          'source_key': 'awards-test',
        },
      ],
      'all_star': [
        {
          'player_key': 'p1',
          'player_name': 'Alpha Guard',
          'team_key': 'AAA',
          'team_name': 'Alpha',
          'starter': true,
        },
      ],
      'draft': [
        {
          'draft_year': 2025,
          'pick_number': 1,
          'round': 1,
          'player_key': 'p1',
          'player_name': 'Alpha Guard',
          'team_key': 'AAA',
          'team_name': 'Alpha',
        },
      ],
      'coverage': [
        {'domain': 'awards', 'status': 'available', 'rows': 1},
      ],
    };

NbaTerminalSeedSnapshot _seed() => NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': [
        {'player_id': 'p1', 'player_label': 'Alpha Guard', 'team_id': 'AAA'},
        {'player_id': 'p2', 'player_label': 'Beta Wing', 'team_id': 'BBB'},
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
          'game_date': '2026-01-02',
          'season_type': 'Regular Season',
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
          'status': 'Scheduled',
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
          'points': 250,
          'rebounds': 80,
          'assists': 90,
          'steals': 15,
          'blocks': 10,
          'field_goal_attempts': 180,
          'free_throw_attempts': 60,
        },
        {
          'season_id': '2025-26',
          'season_type': 'Regular Season',
          'player_id': 'p2',
          'player_label': 'Beta Wing',
          'team_id': 'BBB',
          'games': 10,
          'points': 220,
          'rebounds': 60,
          'assists': 40,
          'steals': 10,
          'blocks': 4,
          'field_goal_attempts': 170,
          'free_throw_attempts': 50,
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
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://season-operations-convergence',
      'used_fallback': false,
    });
