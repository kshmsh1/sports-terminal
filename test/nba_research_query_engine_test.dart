import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  raw: {
    'points': name == 'Stephen Curry' ? 2375 : (pts * gp).round(),
    'ast_pct': .40, 'deflections_per_game': 3.6,
    'height_inches': 75, 'ortg': 120.3,
  },
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


class _FixtureArcsideApi extends WebsiteNbaApiService {
  const _FixtureArcsideApi();

  @override
  Future<List<Map<String, dynamic>>> draft() async => [
    {'draft_year': 2018, 'player_name': 'Player One',
      'pick_number': 1, 'drafting_team_text': 'Team Alpha'},
    {'draft_year': 2018, 'player_name': 'Player Two',
      'pick_number': 2, 'drafting_team_text': 'Team Beta'},
  ];

  @override
  Future<List<Map<String, dynamic>>> awards() async => [
    {'season_id': '2024-25', 'award': 'MVP',
      'player_name': 'MVP Player', 'winner': 1},
    {'season_id': '2024-25', 'award': 'MVP',
      'player_name': 'Runner Up', 'winner': 0},
  ];

  @override
  Future<List<Map<String, dynamic>>> allStar() async => [
    {'season_id': '2024-25', 'player_name': 'All Star', 'starter': 1},
  ];

  @override
  Future<List<Map<String, dynamic>>> games({
    String? season, String? seasonType, String? team,
  }) async => [
    {'game_date': '2023-06-12', 'away_team_name': 'Miami Heat',
      'home_team_name': 'Denver Nuggets',
      'away_score': 89, 'home_score': 94, 'season_type': 'playoffs'},
  ];
}

void main() {
  test('Leaderboards qualify players and support all available results', () {
    final answer = ArcsideResearchQueryEngine.answerFromRows(
      'Top 5 scorers in 2015-16', _sample,
      season: '2015-16', playoffs: false);
    expect(answer.supported, isTrue);
    expect(answer.title, '2 player results · Points Per Game');
    expect(answer.hits.map((hit) => hit.name).toList(),
        ['Stephen Curry', 'James Harden']);
    expect(answer.hits.first.value, '30.1');
    expect(answer.source, contains('2015-16'));
    expect(answer.message, contains('50+ GP'));

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
      'point ' * 700, _sample, season: '2015-16', playoffs: false);
    expect(tooLong.supported, isFalse);
  });


  test('Extended metric catalog resolves actual source-backed advanced stats', () {
    final ast = ArcsideResearchQueryEngine.answerFromRows(
      'Stephen Curry 2015-16 AST%', _sample,
      season: '2015-16', playoffs: false);
    expect(ast.supported, isTrue);
    expect(ast.hits.single.value, '40.0%');

    final deflections = ArcsideResearchQueryEngine.answerFromRows(
      'Top 100 deflections 2015-16 minimum 20 games', _sample,
      season: '2015-16', playoffs: false);
    expect(deflections.supported, isTrue);
    expect(deflections.hits.length, 2);
    expect(deflections.hits.first.value, '3.6');

    final profile = ArcsideResearchQueryEngine.answerFromRows(
      'Stephen Curry 2015-16 all stats', _sample,
      season: '2015-16', playoffs: false);
    expect(profile.hits.any((hit) => hit.name.contains('AST%')), isTrue);
    expect(profile.hits.any((hit) => hit.name.contains('ORTG')), isTrue);
  });

  test('Top results are no longer capped at 10 and can be filtered by team', () {
    final many = [
      for (var i = 0; i < 125; i++)
        _player('Player $i', i.isEven ? 'BOS' : 'NYK',
          gp: 75, pts: i.toDouble(), ast: 5, reb: 5, ts: .5),
    ];
    final ranking = ArcsideResearchQueryEngine.answerFromRows(
      'Top 120 points 2025-26', many,
      season: '2025-26', playoffs: false);
    expect(ranking.hits.length, 120);
    expect(ranking.hits.first.name, 'Player 124');

    final team = ArcsideResearchQueryEngine.answerFromRows(
      'All players PPG 2025-26 team:BOS min_gp:10', many,
      season: '2025-26', playoffs: false);
    expect(team.hits.length, 63);
    expect(team.hits.every((hit) => hit.team == 'BOS'), isTrue);
  });

  test('Player comparison stays inside one published season', () {
    final compare = ArcsideResearchQueryEngine.answerFromRows(
      'Compare Stephen Curry vs James Harden 2015-16 points',
      _sample, season: '2015-16', playoffs: false);
    expect(compare.supported, isTrue);
    expect(compare.hits.length, 2);
    expect(compare.hits.first.value, '30.1');

    final invalid = ArcsideResearchQueryEngine.answerFromRows(
      'What car does Stephen Curry drive?', _sample,
      season: '2015-16', playoffs: false);
    expect(invalid.supported, isFalse);
  });

  test('Published team standings and derived win percentages cite the source', () {
    const records = [
      {'team_key': 'a', 'season_type': 'regular', 'wins': 60, 'losses': 22},
      {'team_key': 'b', 'season_type': 'regular', 'wins': 45, 'losses': 37},
    ];
    const teams = [
      {'team_key': 'a', 'canonical_name': 'Team A'},
      {'team_key': 'b', 'canonical_name': 'Team B'},
    ];
    final result = ArcsideResearchQueryEngine.teamAnswerFromRecords(
      'team standings 2024-25', records, teams: teams,
      season: '2024-25', playoffs: false);
    expect(result.hits.length, 2);
    expect(result.hits.first.name, 'Team A');
    expect(result.hits.first.value, '60');
    final pct = ArcsideResearchQueryEngine.teamAnswerFromRecords(
      'team win percentage 2024-25', records, teams: teams,
      season: '2024-25', playoffs: false);
    expect(pct.hits.first.value, '73.2%');
  });

  test('Draft, awards, All-Star and game queries only use fixture Arcside data',
      () async {
    const engine = ArcsideResearchQueryEngine(api: _FixtureArcsideApi());
    final draft = await engine.ask('2018 NBA draft picks',
        defaultSeason: '2025-26', defaultPlayoffs: false);
    expect(draft.hits.length, 2);
    expect(draft.hits.first.name, 'Player One');
    final award = await engine.ask('MVP 2024-25',
        defaultSeason: '2025-26', defaultPlayoffs: false);
    expect(award.hits.single.name, 'MVP Player');
    final allStar = await engine.ask('All star selections 2024-25',
        defaultSeason: '2025-26', defaultPlayoffs: false);
    expect(allStar.hits.single.name, 'All Star');
    final game = await engine.ask('Games on 2023-06-12',
        defaultSeason: '2025-26', defaultPlayoffs: false);
    expect(game.hits.single.value, '89 – 94');
    expect(game.source, contains('Historical game index'));
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
    expect(panel, contains('No daily query limit'));
    expect(panel, contains('_pageSize = 40'));
    expect(panel, isNot(contains('SharedPreferences.getInstance()')));
    expect(panel, isNot(contains('_maxDaily')));
    expect(service, contains('maxQuestionChars = 4096'));
    expect(service, contains('nbaTerminalMetrics'));
    expect(service, isNot(contains('package:http/http.dart')));
    expect(page, contains('NbaResearchQueryPanel('));
  });

  testWidgets('Ask Arcside renders prompts and strict scope without a login',
      (tester) async {
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
    expect(find.text('No daily query limit'), findsOneWidget);
    expect(find.text('Top 50 scorers in 2025-26'), findsWidgets);
  });
}
