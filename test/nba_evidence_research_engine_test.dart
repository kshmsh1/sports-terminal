import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_evidence_research_engine.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';

NbaStatsRow row(String id, String name, String team,
    {double gp = 65, double pts = 0, double ast = 0,
    double reb = 0, double three = .0}) => NbaStatsRow(
  playerId: id,
  player: name,
  team: team,
  position: 'G',
  values: {
    'gp': gp, 'pts': pts, 'ast': ast,
    'reb': reb, 'three_pct': three,
  },
  percentiles: const {},
  raw: const {},
  possessionsEstimated: false,
);

void main() {
  const engine = NbaEvidenceResearchEngine();

  test('plans supported season leaderboard with explicit scope', () {
    final plan = engine.parse(
      'Top 10 players in points per game in 2025-26',
      defaultSeason: '2024-25',
    );
    expect(plan.supported, isTrue);
    expect(plan.metric, 'pts');
    expect(plan.season, '2025-26');
    expect(plan.limit, 10);
    expect(plan.minGames, 10);
    expect(plan.sourcePath, 'seasons/2025-26/regular.json');
  });

  test('playoffs, rate basis, and minimum games are understood', () {
    final plan = engine.parse(
      'Top 5 players in rebounds per 36 in 2023-24 playoffs with at least 6 games',
      defaultSeason: '2025-26',
    );
    expect(plan.supported, isTrue);
    expect(plan.metric, 'reb');
    expect(plan.basis, NbaStatsBasis.per36);
    expect(plan.seasonType, NbaStatsSeasonType.playoffs);
    expect(plan.minGames, 6);
    expect(plan.limit, 5);
    expect(plan.sourcePath, 'seasons/2023-24/playoffs.json');
  });

  test('executes ranked results with sample thresholds and deduplicated players', () {
    final plan = engine.parse(
      'Top 3 players in points per game in 2025-26',
      defaultSeason: '2025-26',
    );
    final answer = engine.execute(plan, [
      row('a', 'Player A', 'ATL', gp: 40, pts: 28),
      row('b', 'Player B', 'BOS', gp: 42, pts: 31),
      row('a', 'Player A', '2TM', gp: 70, pts: 29),
      row('c', 'Player C', 'CHI', gp: 3, pts: 70),
      row('d', 'Player D', 'DEN', gp: 41, pts: 29),
    ]);
    expect(answer.evaluatedCount, 4);
    expect(answer.qualifiedCount, 3);
    expect(answer.findings.map((f) => f.row.player).toList(),
      ['Player B', 'Player A', 'Player D']);
    expect(answer.findings[1].row.team, '2TM');
  });

  test('minimum metric value limits qualifying population', () {
    final plan = engine.parse(
      'Top 5 in points with at least 25 points in 2025-26',
      defaultSeason: '2025-26',
    );
    expect(plan.minimumMetric, 25);
    final answer = engine.execute(plan, [
      row('a', 'A', 'ATL', pts: 24),
      row('b', 'B', 'BOS', pts: 31),
    ]);
    expect(answer.qualifiedCount, 1);
    expect(answer.findings.single.row.player, 'B');
  });

  test('unsupported tracking, live and cross-season questions abstain', () {
    final questions = [
      'Which defender held Anthony Edwards to the lowest FG%?',
      'What was the live score tonight?',
      'Top 10 career assist leaders since 2010',
      'What is Jokic\'s on/off net rating with Murray?',
      'Simulate the Knicks winning a championship',
    ];
    for (final question in questions) {
      final plan = engine.parse(question, defaultSeason: '2025-26');
      expect(plan.supported, isFalse, reason: question);
      expect(plan.explanation, isNotEmpty);
      expect(engine.execute(plan, [
        row('a', 'A', 'BOS', pts: 30),
      ]).findings, isEmpty);
    }
  });

  test('ambiguous requests do not default to invented leaderboard answers', () {
    final plan = engine.parse('How good are the Lakers?',
      defaultSeason: '2025-26');
    expect(plan.supported, isFalse);
    expect(plan.metric, isEmpty);
  });

  test('lowest ranking sorts in ascending order', () {
    final plan = engine.parse(
      'Top 3 lowest turnovers in 2024-25 with at least 20 games',
      defaultSeason: '2025-26',
    );
    expect(plan.descending, isFalse);
    expect(plan.minGames, 20);
  });
}
