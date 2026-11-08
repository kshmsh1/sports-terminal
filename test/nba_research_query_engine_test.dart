import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_research_query_engine.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/services/website_nba_api_service.dart';
import 'package:sports_terminal/widgets/nba_research_query_panel.dart';

NbaStatsRow _player(
  String name, String team, {
  required double gp,
  required double pts,
  required double ast,
  required double reb,
  required double ts,
}) => NbaStatsRow(
  playerId: name.toLowerCase().replaceAll(' ', '_'),
  player: name,
  team: team,
  position: 'G',
  values: {
    'gp': gp, 'pts': pts, 'ast': ast, 'reb': reb,
    'ts_pct': ts, 'stl': 1.2, 'blk': .4, 'three_pct': .4,
  },
  percentiles: const {},
  raw: {'points': name == 'Stephen Curry' ? 2375 : (pts * gp).round()},
  possessionsEstimated: false,
);

final _sample = <NbaStatsRow>[
  _player('Stephen Curry', 'GSW',
      gp: 79, pts: 30.1, ast: 6.7, reb: 5.4, ts: .669),
  _player('James Harden', 'HOU',
      gp: 82, pts: 29, ast: 7.5, reb: 6.1, ts: .598),
  _player('Bench Player', 'CHI',
      gp: 2, pts: 50, ast: 1, reb: 1, ts: .95),
];

void main() {
  test('Leaderboards qualify players and cap answers at 10 records', () {
    final answer = ArcsideResearchQueryEngine.answerFromRows(
      'Top 5 scorers in 2015-16', _sample,
      season: '2015-16', playoffs: false);
    expect(answer.supported, isTrue);
    expect(answer.title, 'Top 2 · Points per game');
    expect(answer.hits.map((hit) => hit.name).toList(),
        ['Stephen Curry', 'James Harden']);
    expect(answer.hits.first.value, '30.1');
    expect(answer.source, contains('2015-16'));
    expect(answer.message, contains('Minimum 50 games'));

    final one = ArcsideResearchQueryEngine.answerFromRows(
      'Who led in assists in 2015-16?', _sample,
      season: '2015-16', playoffs: false);
    expect(one.hits.single.name, 'James Harden');
  });

  test('Player questions use exact full name and explicit season', () {
    final answer = ArcsideResearchQueryEngine.answerFromRows(
      'Stephen Curry 2015-16 points per game',
      _sample, season: '2015-16', playoffs: false);
    expect(answer.supported, isTrue);
    expect(answer.title, contains('Stephen Curry'));
    expect(answer.hits.single.value, '30.1');

    final totals = ArcsideResearchQueryEngine.answerFromRows(
      'Stephen Curry 2015-16 total points',
      _sample, season: '2015-16', playoffs: false);
    expect(totals.hits.single.value, '2375');
    expect(totals.title, contains('Total points'));

    final totalLeaders = ArcsideResearchQueryEngine.answerFromRows(
      'Top 2 total points in 2015-16',
      _sample, season: '2015-16', playoffs: false);
    expect(totalLeaders.hits.map((hit) => hit.name).toList(),
        ['James Harden', 'Stephen Curry']);
    expect(totalLeaders.hits.first.value, '2378');
  });

  test('Profile requests provide a sourced NBA season snapshot', () {
    final answer = ArcsideResearchQueryEngine.answerFromRows(
      'Stephen Curry 2015-16 stats',
      _sample, season: '2015-16', playoffs: false);
    expect(answer.hits.any((hit) => hit.name == 'PPG'), isTrue);
    expect(answer.hits.any((hit) => hit.name == 'TS%'), isTrue);
    expect(answer.source, contains('Regular Season'));
  });

  test('Unavailable, unsupported and under-qualified queries do not hallucinate', () {
    final unsupported = ArcsideResearchQueryEngine.answerFromRows(
      'Who won the 1979 NBA finals?', _sample,
      season: '2015-16', playoffs: false);
    expect(unsupported.supported, isFalse);
    expect(unsupported.hits, isEmpty);

    final noData = ArcsideResearchQueryEngine.answerFromRows(
      'Stephen Curry 2015-16 stats', const [],
      season: '2015-16', playoffs: false);
    expect(noData.supported, isFalse);

    final unqualified = ArcsideResearchQueryEngine.answerFromRows(
      'Top 5 scorers', [_sample.last], season: '2015-16', playoffs: false);
    expect(unqualified.supported, isFalse);

    final tooLong = ArcsideResearchQueryEngine.answerFromRows(
      'point ' * 40, _sample, season: '2015-16', playoffs: false);
    expect(tooLong.supported, isFalse);
  });

  test('Research integration never embeds ChatGPT or exposes an API key', () {
    final service = File('lib/services/nba_research_query_engine.dart')
        .readAsStringSync();
    final panel = File('lib/widgets/nba_research_query_panel.dart')
        .readAsStringSync();
    final page = File('lib/screens/website_nba_research_screen.dart')
        .readAsStringSync();
    expect(service, contains('_api.seasonSnapshot('));
    expect(service, isNot(contains('chatgpt.com')));
    expect(service, isNot(contains('api.openai.com')));
    expect(service, isNot(contains('sk-')));
    expect(panel, contains('_maxDaily = 8'));
    expect(panel, contains('Duration(seconds: 15)'));
    expect(panel, contains('_maxChars = 180'));
    expect(panel, contains('SharedPreferences.getInstance()'));
    expect(page, contains('NbaResearchQueryPanel('));
  });

  testWidgets('Ask Arcside renders prompts and strict scope without a login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: NbaResearchQueryPanel(seasons: const [
        WebsiteNbaSeason(
            id: '2025-26', label: '2025-26',
            startYear: 2025, rowCount: 100),
      ])),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Ask Arcside'), findsOneWidget);
    expect(find.text('Research question'), findsOneWidget);
    expect(find.text('8/8 today'), findsOneWidget);
    expect(find.text('Top 5 scorers in 2025-26'), findsWidgets);
  });
}
