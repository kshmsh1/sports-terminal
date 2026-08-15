import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_analytics_engine.dart';
import 'package:sports_terminal/services/nba_game_context_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('game analytics derives transparent score flow from explicit states', () {
    final result = const NbaGameAnalyticsEngine().build(
      _seed(),
      gameId: 'g3',
    );

    expect(result.scoreStateCount, 7);
    expect(result.leadChanges, 2);
    expect(result.ties, 1);
    expect(result.largestHomeLead, 4);
    expect(result.largestAwayLead, 1);
    expect(result.largestScoringRun?.points, 5);
    expect(result.largestScoringRun?.side, NbaGameScoringSide.away);
    expect(result.startsAtKnownBaseline, isTrue);
    expect(result.matchesFinalScore, isTrue);
    expect(result.completeObservedTimeline, isTrue);
  });

  test('game analytics marks a mid-game feed as observed but incomplete', () {
    final seed = _seed(
      playByPlay: [
        {
          'game_id': 'g3',
          'event_num': 50,
          'period': 4,
          'clock': '1:00',
          'home_score': 101,
          'away_score': 99,
        },
        {
          'game_id': 'g3',
          'event_num': 51,
          'period': 4,
          'clock': '0:00',
          'home_score': 105,
          'away_score': 101,
        },
      ],
      focalHomeScore: 105,
      focalAwayScore: 101,
    );

    final result = const NbaGameAnalyticsEngine().build(seed, gameId: 'g3');
    expect(result.hasScoreProgression, isTrue);
    expect(result.startsAtKnownBaseline, isFalse);
    expect(result.matchesFinalScore, isTrue);
    expect(result.completeObservedTimeline, isFalse);
  });

  test('context exposes same-matchup games and only pre-tip series record', () {
    final result = const NbaGameContextEngine().build(
      _seed(),
      gameId: 'g3',
      teamWindow: 2,
      playerWindow: 2,
    );

    expect(result.relatedGames.map((game) => game.gameId), ['g1', 'g4']);
    expect(result.priorMeetings, 1);
    expect(result.homePriorWins, 1);
    expect(result.awayPriorWins, 0);
    expect(result.priorRelatedGames.single.gameId, 'g1');
    expect(result.relatedGames.last.beforeFocalGame, isFalse);
  });

  test('team entering form uses completed games strictly before focal date', () {
    final result = const NbaGameContextEngine().build(
      _seed(),
      gameId: 'g3',
      teamWindow: 2,
    );

    final home = result.homeEnteringForm;
    expect(home.games, 2);
    expect(home.recordLabel, '2–0');
    expect(home.pointsForPerGame, 108);
    expect(home.pointsAgainstPerGame, 100);
    expect(home.marginPerGame, 8);
    expect(home.streakLabel, 'W2');
    expect(home.lastGameId, 'g2');

    final away = result.awayEnteringForm;
    expect(away.games, 2);
    expect(away.recordLabel, '0–2');
    expect(away.streakLabel, 'L2');
  });

  test('player entering form averages only prior canonical player logs', () {
    final result = const NbaGameContextEngine().build(
      _seed(),
      gameId: 'g3',
      playerWindow: 2,
    );

    final guard = result.playerEnteringForms.singleWhere(
      (form) => form.playerId == 'p1',
    );
    expect(guard.games, 2);
    expect(guard.pointsPerGame, 22);
    expect(guard.reboundsPerGame, 5);
    expect(guard.assistsPerGame, 7);
    expect(guard.plusMinusPerGame, 5);
    expect(guard.lastGameId, 'g2');

    final wing = result.playerEnteringForms.singleWhere(
      (form) => form.playerId == 'p2',
    );
    expect(wing.games, 2);
    expect(wing.pointsPerGame, 18);
  });

  test('missing focal date leaves entering form unavailable instead of leaking', () {
    final seed = _seed(focalDate: '');
    final result = const NbaGameContextEngine().build(seed, gameId: 'g3');

    expect(result.focalDate, isNull);
    expect(result.homeEnteringForm.games, 0);
    expect(result.awayEnteringForm.games, 0);
    expect(result.playerEnteringForms.every((form) => form.games == 0), isTrue);
  });
}

NbaTerminalSeedSnapshot _seed({
  List<Map<String, dynamic>>? playByPlay,
  String focalDate = '2026-01-20',
  int focalHomeScore = 7,
  int focalAwayScore = 5,
}) =>
    NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
        {'team_id': 'CCC', 'team_name': 'Gamma', 'abbreviation': 'CCC'},
        {'team_id': 'DDD', 'team_name': 'Delta', 'abbreviation': 'DDD'},
      ],
      'players': [
        {'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA'},
        {'player_id': 'p2', 'player_name': 'Beta Wing', 'team_id': 'BBB'},
      ],
      'games': [
        {
          'game_id': 'g0',
          'season_id': '2025-26',
          'game_date': '2026-01-05',
          'season_type': 'Regular Season',
          'home_team_id': 'DDD',
          'away_team_id': 'BBB',
          'home_score': 109,
          'away_score': 100,
          'status': 'Final',
        },
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-10',
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
          'game_date': '2026-01-15',
          'season_type': 'Regular Season',
          'home_team_id': 'CCC',
          'away_team_id': 'AAA',
          'home_score': 100,
          'away_score': 106,
          'status': 'Final',
        },
        {
          'game_id': 'g3',
          'season_id': '2025-26',
          'game_date': focalDate,
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': focalHomeScore,
          'away_score': focalAwayScore,
          'status': 'Final',
        },
        {
          'game_id': 'g4',
          'season_id': '2025-26',
          'game_date': '2026-02-10',
          'season_type': 'Regular Season',
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
          'home_score': 120,
          'away_score': 118,
          'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': const [],
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
          'rebounds': 4,
          'assists': 6,
          'plus_minus': 3,
        },
        {
          'game_id': 'g2',
          'player_id': 'p1',
          'player_name': 'Alpha Guard',
          'team_id': 'AAA',
          'points': 24,
          'rebounds': 6,
          'assists': 8,
          'plus_minus': 7,
        },
        {
          'game_id': 'g3',
          'player_id': 'p1',
          'player_name': 'Alpha Guard',
          'team_id': 'AAA',
          'points': 26,
          'rebounds': 5,
          'assists': 9,
          'plus_minus': 2,
        },
        {
          'game_id': 'g0',
          'player_id': 'p2',
          'player_name': 'Beta Wing',
          'team_id': 'BBB',
          'points': 16,
          'rebounds': 7,
          'assists': 2,
          'plus_minus': -4,
        },
        {
          'game_id': 'g1',
          'player_id': 'p2',
          'player_name': 'Beta Wing',
          'team_id': 'BBB',
          'points': 20,
          'rebounds': 6,
          'assists': 3,
          'plus_minus': -5,
        },
        {
          'game_id': 'g3',
          'player_id': 'p2',
          'player_name': 'Beta Wing',
          'team_id': 'BBB',
          'points': 21,
          'rebounds': 8,
          'assists': 4,
          'plus_minus': -2,
        },
      ],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'status': 'test'},
      'standings': const [],
      'play_by_play': playByPlay ??
          [
            {
              'game_id': 'g3',
              'event_num': 1,
              'period': 1,
              'clock': '12:00',
              'home_score': 0,
              'away_score': 0,
              'description': 'Start of game',
            },
            {
              'game_id': 'g3',
              'event_num': 2,
              'period': 1,
              'clock': '11:40',
              'home_score': 2,
              'away_score': 0,
              'team_id': 'AAA',
            },
            {
              'game_id': 'g3',
              'event_num': 3,
              'period': 1,
              'clock': '11:10',
              'home_score': 4,
              'away_score': 0,
              'team_id': 'AAA',
            },
            {
              'game_id': 'g3',
              'event_num': 4,
              'period': 1,
              'clock': '10:45',
              'home_score': 4,
              'away_score': 3,
              'team_id': 'BBB',
            },
            {
              'game_id': 'g3',
              'event_num': 5,
              'period': 1,
              'clock': '10:15',
              'home_score': 4,
              'away_score': 5,
              'team_id': 'BBB',
            },
            {
              'game_id': 'g3',
              'event_num': 6,
              'period': 1,
              'clock': '9:40',
              'home_score': 5,
              'away_score': 5,
              'team_id': 'AAA',
            },
            {
              'game_id': 'g3',
              'event_num': 7,
              'period': 1,
              'clock': '9:05',
              'home_score': 7,
              'away_score': 5,
              'team_id': 'AAA',
            },
          ],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://deep-intelligence',
      'used_fallback': false,
    });
