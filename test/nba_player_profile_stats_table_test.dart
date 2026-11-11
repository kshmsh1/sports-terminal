import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';
import 'package:sports_terminal/widgets/nba_player_profile_stats_table.dart';

void main() {
  const season = <String, dynamic>{
    'season_id': '2025-26',
    'season_type': 'regular',
    'team_abbreviation': 'LAL',
    'positions': 'SF, PG',
    'games': 50,
    'minutes': 1500,
    'points': 1000,
    'rebounds': 500,
    'assists': 300,
    'field_goals_made': 400,
    'field_goal_attempts': 800,
    'three_pointers_made': 150,
    'three_point_attempts': 400,
    'free_throws_made': 50,
    'free_throw_attempts': 70,
    'deflections_pg': 3.3,
    'contested_shots_pg': 4.2,
  };

  testWidgets('profile career grid shares sticky columns and source-backed rates',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 1380,
            child: NbaPlayerProfileStatsTable(
              rows: [season],
              family: nbaTerminalStatFamilies[0],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Season'), findsOneWidget);
    expect(find.text('2025-26'), findsOneWidget);
    expect(find.text('20.0'), findsWidgets);
    expect(find.text('10.0'), findsWidgets);
    expect(find.text('PG, SF'), findsOneWidget);
  });

  testWidgets('profile advanced grid reads native metrics from season payload',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 1380,
            child: NbaPlayerProfileStatsTable(
              rows: [season],
              family: nbaTerminalStatFamilies[1],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('3.3'), findsWidgets);
    expect(find.text('4.2'), findsWidgets);
  });
}
